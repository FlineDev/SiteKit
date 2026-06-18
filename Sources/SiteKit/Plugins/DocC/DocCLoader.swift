import Foundation
import Logging
import Markdown

/// Loads a DocC note (`.docc` Markdown) into a `PageModel`.
///
/// Unlike `MarkdownLoader`, DocC notes carry no YAML frontmatter. Structure is:
/// a leading `# Title`, an abstract paragraph, a `@Metadata { … }` block
/// (`@TitleHeading`, `@PageKind`, `@CallToAction`, `@Contributors`), then the
/// body. This loader walks the swift-markdown AST, lifts the title/abstract/
/// metadata out, and renders the remaining body through `MarkdownRenderer`
/// (standard Markdown) and `DocCDirectiveRenderer` (DocC body directives, with
/// the graceful-degradation guarantee). DocC-specific metadata lands in
/// `PageModel.extensions` under `docc…` keys for the page renderer to consume.
public struct DocCLoader: Loader {
   public typealias Source = MarkdownSource
   public typealias Output = PageModel

   private static let logger = Logger(label: "SiteKit.DocCLoader")

   private let language: String
   private let markdownRenderer = MarkdownRenderer()
   private let directiveRenderer = DocCDirectiveRenderer()
   private let quickReadRenderer = DocCQuickReadRenderer()
   private let calloutRenderer = DocCCalloutRenderer()
   /// Fallback language for fenced code blocks that carry no language tag. When non-nil,
   /// untagged blocks are highlighted as if they were tagged with this language. Nil means
   /// plain escaped text. Does not override an explicitly tagged block's language.
   private let defaultCodeLanguage: String?
   /// The code highlighter applied to fenced code blocks. Defaults to the zero-dependency
   /// regex `CodeHighlighter`; a DocC site can inject `SwiftSyntaxHighlighter` (from the
   /// `SiteKitSyntaxHighlighting` product) for semantic-near Swift token roles.
   private let highlighter: any CodeHighlighting

   /// Creates a DocC loader.
   ///
   /// - Parameters:
   ///   - language: The locale this loader produces pages for.
   ///   - defaultCodeLanguage: Fallback language for untagged fenced code blocks.
   ///   - highlighter: The code highlighter for fenced blocks. Pass nil (the default) to use the
   ///     zero-dependency regex `CodeHighlighter`; inject `SwiftSyntaxHighlighter` for the richer
   ///     SwiftSyntax-based Swift roles. The default is resolved internally so callers depending
   ///     only on `SiteKit` never reference the swift-syntax product.
   public init(
      language: String = "en",
      defaultCodeLanguage: String? = nil,
      highlighter: (any CodeHighlighting)? = nil
   ) {
      self.language = language
      self.defaultCodeLanguage = defaultCodeLanguage
      self.highlighter = highlighter ?? CodeHighlighter()
   }

   public func load(source: MarkdownSource) throws -> PageModel {
      // Strip an optional YAML frontmatter block (`---` … `---`) before passing to the
      // DocC parser. DocC notes do not formally carry YAML frontmatter, but authors may
      // prepend a thin block with catalogue-specific fields such as `tags:` so that the
      // loader can populate `PageModel.tags` for the meta row's platform-badge display.
      let (frontmatterTags, markdownForParsing) = Self.stripFrontmatter(from: source.content)
      let parsed = self.parse(markdownForParsing, sourcePath: source.filePath)

      // Marker so DocCArticlePage can select notes this loader produced.
      var extensions: [String: any Sendable] = ["doccNote": true]
      if let metadata = parsed.metadata {
         self.extractMetadata(metadata, into: &extensions)
      }

      // @PageImage extension resolution: the loader stores a bare source name like
      // "WWDC25", but the teleported asset lands at "/assets/WWDC25.svg". Resolve the
      // actual file extension by searching common image subdirectories of the catalog
      // (Images/ is the DocC convention; the source file's directory is also checked as
      // a fallback). Without the extension the browser gets a 404.
      if let rawURL = extensions["doccNavIconURL"] as? String {
         let resolved = Self.resolveNavIconURL(rawURL, relativeTo: source.filePath)
         extensions["doccNavIconURL"] = resolved
      }

      // Framework tag: read from an HTML comment anywhere in the raw source, e.g.
      // <!-- framework: swiftui -->
      // This is the lightest-weight author contract: a single comment line, no
      // DocC directive syntax required. Takes precedence over a @CustomAttribute
      // if both are present (last-writer-wins via sequential assignment).
      if let frameworkKey = Self.parseFrameworkComment(from: source.content) {
         extensions["doccFramework"] = frameworkKey
      }

      // Topic groups from the year-overview `## Topics` section: each `### Heading` + its
      // `@Links` block becomes a `DocCTopicGroup`. Only set when ≥1 non-empty group is found.
      let groups = Self.parseTopicGroups(from: parsed.bodyNodes, language: self.language)
      if !groups.isEmpty {
         extensions["doccTopicGroups"] = groups
      }

      // Contributor profile note: `generate-metadata` writes one per contributor to
      // `<catalog>.docc/Contributors/<handle>.md`, carrying the real full name (title),
      // the GitHub bio (abstract), and a `## Links` section (Blog + X/Twitter). Detect it by
      // the parent directory name so `DocCContributorPage` can consume the rich data instead
      // of synthesising a handle-only page, and so the navigation tree and reserved routes can
      // keep the bare-handle slug out of the flat article list and the standalone-URL space.
      if source.filePath.deletingLastPathComponent().lastPathComponent.lowercased() == "contributors" {
         extensions["doccContributorProfile"] = true
         let links = Self.parseContributorLinks(from: parsed.bodyNodes)
         if !links.isEmpty {
            extensions["doccContributorLinks"] = links
         }
      }

      // Reading time: WWDCNotes encodes it in the @CallToAction label, e.g.
      // "Watch the video (14 min)". Lift the integer so listing pages can show it
      // without re-parsing the label downstream.
      if let label = extensions["doccCTALabel"] as? String, let minutes = Self.parseMinutes(from: label) {
         extensions["doccMinutes"] = minutes
      }

      // Stub detection: a note with an abstract but no real body is a placeholder
      // (the session exists but nobody has written notes yet). Listing pages dim
      // these and tag them "STUB". The placeholder GitHub-handle string that ships
      // in the DocC note template also marks an untouched stub.
      //
      // Content/guide articles (@PageKind(article)) are explicitly not session notes,
      // so they are never stubs – even when their body is sparse. Skip detection for them.
      let isContentArticle = (extensions["doccPageKind"] as? String) == "article"
      if !isContentArticle, Self.isStub(bodyHTML: parsed.bodyHTML, rawMarkdown: source.content) {
         extensions["doccIsStub"] = true
      }

      // Pair an AI-variant sibling (`<base>.ai.md`) into a community note so the
      // page can render a Community↔AI switcher. An AI-only note (loaded directly
      // from `<base>.ai.md` because no community sibling exists) carries no variant
      // and renders its own body without a switcher.
      let isAIVariantFile = source.filePath.lastPathComponent.hasSuffix(".ai.md")
      if isAIVariantFile {
         // Discovery only yields a `.ai.md` file as its own page when no community
         // `.md` sibling exists, so this note is AI-authored with no human variant.
         // Record that so the search index can classify the note's type without
         // re-reading the file system in a later phase.
         extensions["doccAIOnly"] = true
      } else if let aiBody = self.aiVariantBodyHTML(communityPath: source.filePath) {
         // Apply syntax highlighting to the AI-variant body as well.
         let highlightedAI = self.highlighter.applyToBodyHTML(aiBody, defaultLanguage: self.defaultCodeLanguage)
         extensions["doccAIVariant"] = highlightedAI
      }

      // Apply build-time syntax highlighting to the community body. This is scoped to
      // DocC notes only: the MarkdownRenderer is shared across all site types and must
      // not be changed. Highlighting is applied here (post-rendering, pre-PageModel) so
      // it is cleanly isolated and does not affect non-DocC pages.
      let highlightedBodyHTML = self.highlighter.applyToBodyHTML(
         parsed.bodyHTML,
         defaultLanguage: self.defaultCodeLanguage
      )

      // Strip a trailing `.ai` so an AI-only note keeps its session slug/URL.
      var stem = source.filePath.deletingPathExtension().lastPathComponent
      if stem.hasSuffix(".ai") { stem = String(stem.dropLast(3)) }
      let slug = stem.slugified(language: self.language)

      return PageModel(
         title: parsed.title,
         slug: slug,
         htmlContent: highlightedBodyHTML,
         sourcePath: source.filePath,
         tags: frontmatterTags,
         summary: parsed.abstract,
         pageType: .article,
         locale: self.language,
         extensions: extensions
      )
   }

   /// Parses a DocC note into its title (leading H1), abstract (lead paragraph),
   /// `@Metadata` directive, the raw body AST nodes, and rendered body HTML.
   ///
   /// When `sourcePath` is provided, bare-name image sources in the rendered body
   /// HTML (from `@Image` directives and reference/inline Markdown images) are
   /// resolved to `/assets/<name>.<ext>` via `resolveImageName`. Pass nil only in
   /// contexts where no file-system lookup is possible (e.g. tests without real files).
   private func parse(_ markdown: String, sourcePath: URL? = nil) -> (title: String, abstract: String?, metadata: BlockDirective?, bodyNodes: [any Markup], bodyHTML: String) {
      // Repair "headerless" GFM pseudo-tables before parsing. Old hand-written notes laid images
      // and captions out side by side with a pipe row that lacks the `| --- |` delimiter row GFM
      // requires. Without that row cmark-gfm parses the line as a plain paragraph and the pipes
      // survive as literal `|` text in the body. Injecting a synthetic delimiter turns each block
      // back into a real table so the standard table renderer handles it (no stray pipes).
      let normalizedMarkdown = Self.normalizePseudoTables(markdown)
      let document = Document(parsing: normalizedMarkdown, options: [.parseBlockDirectives])
      var title = ""
      var abstract: String?
      var metadata: BlockDirective?
      var bodyNodes: [any Markup] = []

      for child in document.children {
         if title.isEmpty, let heading = child as? Heading, heading.level == 1 {
            title = Self.headingTitleText(heading)
            continue
         }
         if let directive = child as? BlockDirective, directive.name == "Metadata" {
            metadata = directive
            continue
         }
         if abstract == nil, let paragraph = child as? Paragraph {
            abstract = paragraph.plainText
            continue
         }
         bodyNodes.append(child)
      }

      let directiveRenderer = sourcePath.map { DocCDirectiveRenderer(sourcePath: $0) } ?? self.directiveRenderer
      var bodyHTML = bodyNodes.map { node -> String in
         if let directive = node as? BlockDirective {
            return directiveRenderer.render(directive)
         }
         if let blockQuote = node as? BlockQuote {
            // Quick Read is checked first; it is the named summary convention and takes
            // priority. Callout detection runs second (also blockquote-based but identified
            // by a Tip:/Note:/Important:/Warning:/Experiment: prefix instead).
            if let quickRead = self.quickReadRenderer.render(blockQuote, uiStrings: UIStrings(locale: self.language)) { return quickRead }
            if let callout = self.calloutRenderer.render(blockQuote) { return callout }
         }
         return self.markdownRenderer.renderNode(node)
      }.joined()

      // Post-process: rewrite any remaining bare-name img src values that slipped through
      // the directive renderer (e.g. reference-style Markdown images `![][ref]` where the
      // MarkdownRenderer emits the raw reference target as the src). This is scoped to
      // the DocC loader only and never touches MarkdownRenderer's shared behaviour.
      // Unresolvable references are dropped from the output (a raw bare name is a
      // guaranteed 404) and surfaced as build warnings; the build itself goes on – one
      // missing image must never stop a community-content site from publishing.
      if let path = sourcePath {
         let rewrite = Self.rewriteBodyImageSrcs(bodyHTML, relativeTo: path)
         bodyHTML = rewrite.html
         for ref in rewrite.unresolvedRefs {
            Self.logger.warning("Unresolved image reference '\(ref)' in \(path.path) – <img> dropped from output.")
         }
      }

      return (title, abstract, metadata, bodyNodes, bodyHTML)
   }

   /// Returns a heading's text with inline-code delimiters stripped. `plainText` keeps the
   /// literal backticks of a symbol-style heading (`` # `Symbol` ``), which would leak into
   /// the page title and every navigation label derived from it. Only the delimiters fall
   /// away – the code span's own text is preserved verbatim.
   static func headingTitleText(_ heading: Heading) -> String {
      func text(of markup: any Markup) -> String {
         if let code = markup as? InlineCode { return code.code }
         guard markup.childCount > 0 else { return (markup as? InlineMarkup)?.plainText ?? "" }
         return markup.children.map { text(of: $0) }.joined()
      }
      return text(of: heading)
   }

   /// Reads and renders the AI-variant sibling body (`<base>.ai.md`) for a community
   /// note path (`<base>.md`), or nil if there is none.
   private func aiVariantBodyHTML(communityPath: URL) -> String? {
      let base = communityPath.deletingPathExtension().lastPathComponent
      let aiPath = communityPath.deletingLastPathComponent().appendingPathComponent("\(base).ai.md")
      guard FileManager.default.fileExists(atPath: aiPath.path),
         let content = try? String(contentsOf: aiPath, encoding: .utf8)
      else {
         return nil
      }
      let (_, markdownForParsing) = Self.stripFrontmatter(from: content)
      let body = self.parse(markdownForParsing, sourcePath: aiPath).bodyHTML
      return body.isEmpty ? nil : body
   }

   /// Strips an optional YAML frontmatter block (`---` … `---`) from the top of a
   /// DocC note and returns the extracted `tags:` values (empty when absent) plus
   /// the remaining Markdown without the frontmatter delimiters.
   ///
   /// DocC notes do not formally use YAML frontmatter, but authors may prepend a thin
   /// block with `tags:` (YAML array or comma-separated string) to populate the
   /// `PageModel.tags` field for the meta row's platform-badge display. Every other
   /// frontmatter key is ignored – only `tags` is read.
   static func stripFrontmatter(from content: String) -> (tags: [String], markdown: String) {
      let lines = content.components(separatedBy: .newlines)
      guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
         return ([], content)
      }
      guard let endIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
         return ([], content)
      }
      let frontmatterLines = lines[1..<endIndex]
      let remaining = lines[(endIndex + 1)...].joined(separator: "\n")
      let tags = Self.parseTags(from: Array(frontmatterLines))
      return (tags, remaining)
   }

   /// Parses a `tags:` value from YAML frontmatter lines, mirroring `MarkdownLoader.parseTags`.
   ///
   /// Supports two authoring styles:
   /// - YAML array: `tags: [iOS, macOS]` or `tags:\n  - iOS\n  - macOS`
   /// - Comma-separated string: `tags: iOS, macOS`
   private static func parseTags(from frontmatterLines: [String]) -> [String] {
      var inTagBlock = false
      var blockTags: [String] = []

      for line in frontmatterLines {
         let trimmed = line.trimmingCharacters(in: .whitespaces)
         if trimmed.hasPrefix("tags:") {
            let after = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if after.hasPrefix("[") && after.hasSuffix("]") {
               // Inline array: tags: [iOS, macOS]
               let inner = String(after.dropFirst().dropLast())
               return inner.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else if !after.isEmpty {
               // Comma-separated string: tags: iOS, macOS
               return after.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else {
               // Block sequence – collect following `- item` lines
               inTagBlock = true
            }
            continue
         }
         if inTagBlock {
            if trimmed.hasPrefix("- ") {
               blockTags.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else if !trimmed.isEmpty {
               // Non-list, non-empty line ends the block sequence
               inTagBlock = false
            }
         }
      }
      return blockTags
   }

   /// Extracts `@Metadata` children into `docc…` extension keys.
   private func extractMetadata(_ metadata: BlockDirective, into extensions: inout [String: any Sendable]) {
      for child in metadata.children {
         guard let directive = child as? BlockDirective else { continue }
         switch directive.name {
         case "TitleHeading":
            extensions["doccTitleHeading"] = self.positionalArgument(of: directive)
         case "PageKind":
            extensions["doccPageKind"] = self.positionalArgument(of: directive)
         case "CustomAttribute":
            // Supports @CustomAttribute(name: "framework", value: "swiftui") so any DocC note
            // can declare its framework without a non-standard syntax. Stored as "doccFramework".
            let args = self.namedArguments(of: directive)
            if args["name"] == "framework", let value = args["value"] {
               let cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
               if !cleanValue.isEmpty { extensions["doccFramework"] = cleanValue }
            }
         case "CallToAction":
            let args = self.namedArguments(of: directive)
            if let url = args["url"] { extensions["doccCTAURL"] = url }
            if let label = args["label"] { extensions["doccCTALabel"] = label }
         case "Contributors":
            let handles = directive.children
               .compactMap { $0 as? BlockDirective }
               .filter { $0.name == "GitHubUser" }
               .map { self.positionalArgument(of: $0) }
               .filter { Self.isValidContributorHandle($0) }
            if !handles.isEmpty { extensions["doccContributors"] = handles }
         case "PageImage":
            // @PageImage(purpose: icon, source: "ImageName") declares the icon glyph for a
            // year-overview page. Core reads the purpose and source args, then stores the
            // resolved asset URL so the navigation tree can render the year glyph without
            // re-parsing frontmatter at render time.
            let args = self.namedArguments(of: directive)
            if args["purpose"] == "icon", let source = args["source"] {
               // The source is an asset name (e.g. "WWDC25") – resolve to /assets/<source>.
               // Drop surrounding quotes that the DocC argument parser may leave in.
               let cleanSource = source.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
               extensions["doccNavIconURL"] = "/assets/\(cleanSource)"
            }
         default:
            continue
         }
      }
   }

   /// Parses the reading-time minutes out of a CallToAction label such as
   /// "Watch the video (14 min)" → 14. Returns nil when no "<n> min" appears.
   static func parseMinutes(from label: String) -> Int? {
      let lower = label.lowercased()
      guard let minRange = lower.range(of: "min") else { return nil }
      // Walk back from "min" over optional whitespace, then collect the digit run.
      var index = minRange.lowerBound
      while index > lower.startIndex {
         let prev = lower.index(before: index)
         if lower[prev] == " " { index = prev } else { break }
      }
      var digits = ""
      while index > lower.startIndex {
         let prev = lower.index(before: index)
         guard lower[prev].isNumber else { break }
         digits.insert(lower[prev], at: digits.startIndex)
         index = prev
      }
      return digits.isEmpty ? nil : Int(digits)
   }

   /// Resolves a bare resource name to `/assets/<name>.<ext>` by searching candidate
   /// directories for the matching image file. Returns nil when no file is found so
   /// callers can degrade gracefully without crashing.
   ///
   /// Search order (mirrors the DocC authoring convention):
   ///   (a) `<catalog>.docc/Images/` – the shared catalog image directory.
   ///   (b) The source file's own directory (notes at the catalog root use this).
   ///   (c) The per-note sibling subfolder: `<sourceDir>/<sourceBasenameWithoutExtension>/`
   ///       – the WWDCNotes convention for body images (e.g. session 361 body images live
   ///       in `WWDC25/WWDC25-361-Create-icons-with-Icon-Composer/`).
   ///
   /// Bare names (no leading `/`, no `://`) are resolved; absolute paths and full URLs are
   /// returned unchanged. A name is treated as already-qualified – and returned as nil so the
   /// caller uses it verbatim – only when its trailing dot-component is a real image extension
   /// (e.g. `diagram.png`). A name with incidental dots but no image extension (a screenshot
   /// stamp `…_at_18.39.10`, a stem `TermsOfAddress.neutral`) is still a bare name and resolves
   /// to `<name>.<ext>`.
   static func resolveImageName(_ name: String, relativeTo sourcePath: URL) -> String? {
      Self.resolveAsset(name, extensions: Self.imageExtensions, relativeTo: sourcePath)
   }

   /// Image file extensions the resolvers and the body-src rewrite recognize, in lookup
   /// priority order (vector first, then the smaller raster formats).
   private static let imageExtensions = ["svg", "png", "webp", "jpg", "jpeg", "gif"]

   /// Resolves a bare video name to `/assets/<name>.<ext>` by searching the same catalog
   /// directories as `resolveImageName` for a matching `.mp4`/`.mov` file. Returns nil when
   /// no file is found so the `@Video` renderer can degrade gracefully.
   ///
   /// This is a sibling of `resolveImageName` rather than a widening of it: the image resolver
   /// feeds `<img>` rewrite paths too, and an `<img>` must never resolve to a video file. A
   /// dedicated resolver keeps the image call sites byte-identical (their behaviour is pinned
   /// by existing tests) while letting only the `@Video` case opt into video extensions.
   static func resolveVideoName(_ name: String, relativeTo sourcePath: URL) -> String? {
      Self.resolveAsset(name, extensions: ["mp4", "mov"], relativeTo: sourcePath)
   }

   /// Shared resolution core for `resolveImageName` / `resolveVideoName`: searches the DocC
   /// catalog's candidate directories for `<name>.<ext>` over the supplied extension list and
   /// returns the first hit as `/assets/<name>.<ext>`, or nil on miss. Extension matching is
   /// case-insensitive (`.JPG` is found for `jpg`) and the returned URL carries the file's
   /// actual on-disk name so it survives case-sensitive web servers.
   ///
   /// Search order (mirrors the DocC authoring convention):
   ///   (a) `<catalog>.docc/Images/` – the shared catalog image directory.
   ///   (b) The source file's own directory (notes at the catalog root use this).
   ///   (c) The per-note sibling subfolder: `<sourceDir>/<sourceBasenameWithoutExtension>/`
   ///       – the WWDCNotes convention for body assets.
   ///
   /// Only bare names (no extension, no leading `/`, no `://`) are resolved; callers must
   /// strip a known extension before calling so a `@Video(source: "clip.mp4")` resolves.
   private static func resolveAsset(_ name: String, extensions: [String], relativeTo sourcePath: URL) -> String? {
      // Reject absolute paths and full URLs outright. A name counts as "bare" (and is resolved)
      // unless its trailing dot-component is itself a known asset extension – that marks an
      // already-qualified filename such as "diagram.png" that the caller uses as-is. Names whose
      // dots are incidental still resolve: a screenshot stamp "WWDC23-10248-…_at_13.43.22" (the
      // trailing ".22" is not an extension) or a stem like "WWDC23-…-TermsOfAddress.neutral"
      // (".neutral" is not an extension) are bare names whose file lands at "<name>.<ext>".
      guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("://") else {
         return nil
      }
      let trailingComponent = name.split(separator: ".").last.map { String($0).lowercased() } ?? ""
      guard !extensions.contains(trailingComponent) else {
         return nil
      }

      // Build the three candidate directories.
      var searchDirs: [URL] = []

      // (a) Catalog Images/ directory: walk up to find the .docc ancestor.
      var dir = sourcePath.deletingLastPathComponent()
      while dir.path != "/" {
         if dir.pathExtension == "docc" {
            searchDirs.append(dir.appendingPathComponent("Images"))
            break
         }
         dir = dir.deletingLastPathComponent()
      }

      // (b) The source file's own directory.
      let sourceDir = sourcePath.deletingLastPathComponent()
      searchDirs.append(sourceDir)

      // (c) Per-note sibling subfolder: same parent, named after the note without extension.
      let noteBasename = sourcePath.deletingPathExtension().lastPathComponent
      searchDirs.append(sourceDir.appendingPathComponent(noteBasename))

      // Match the extension case-insensitively against the real directory listing (a
      // hand-saved screenshot often carries ".JPG"), and return the file's ACTUAL on-disk
      // name: the teleporter copies the asset verbatim, so a URL with a downcased
      // extension would 404 on a case-sensitive web server even though the local
      // (case-insensitive APFS) lookup succeeded. Deterministic pick per directory and
      // extension: the exact lowercase name wins when both casings coexist (only possible
      // on a case-sensitive file system, e.g. Linux CI); among other case variants the
      // lexicographically first one is chosen.
      let fileManager = FileManager.default
      for dir in searchDirs {
         guard let entries = try? fileManager.contentsOfDirectory(atPath: dir.path) else { continue }
         for ext in extensions {
            let exactName = "\(name).\(ext)"
            if entries.contains(exactName) {
               return "/assets/\(exactName)"
            }
            let prefix = "\(name)."
            let caseVariants = entries.filter { entry in
               entry.hasPrefix(prefix) && entry.dropFirst(prefix.count).lowercased() == ext
            }
            if let variant = caseVariants.sorted().first {
               return "/assets/\(variant)"
            }
         }
      }

      return nil
   }

   /// Resolves a raw `/assets/<name>` URL to `/assets/<name>.<ext>` by searching for the
   /// image file in the DocC catalog's `Images/` directory (DocC convention) and then in
   /// the same directory as the source file. Tries svg, png, webp, jpg, jpeg, gif in order.
   ///
   /// When `rawURL` already contains a `.` in the final path component (i.e. already has
   /// an extension), it is returned as-is. When no matching file is found, the bare URL
   /// is returned so the build degrades gracefully instead of crashing.
   ///
   /// For new callers prefer `resolveImageName(_:relativeTo:)` which also checks the
   /// per-note sibling subfolder and returns nil on miss (safer degradation).
   static func resolveNavIconURL(_ rawURL: String, relativeTo sourcePath: URL) -> String {
      // If the source name already carries an extension, nothing to do.
      let name = rawURL.split(separator: "/").last.map(String.init) ?? ""
      guard !name.contains(".") else { return rawURL }

      // Delegate to the shared resolver; fall back to the bare URL on miss.
      if let resolved = resolveImageName(name, relativeTo: sourcePath) {
         return resolved
      }

      // No file found – return the bare URL so the build does not crash.
      return rawURL
   }

   /// Post-processes rendered DocC body HTML and rewrites every `<img src="VALUE">` whose
   /// VALUE is a bare resource name (no leading `/`, no `://`, not a data: URI) to
   /// `/assets/<name>.<ext>` using `resolveImageName`. A VALUE that already carries a real
   /// trailing extension (`diagram.png`) is left as-is, while incidental dots (a screenshot
   /// stamp `…_at_18.39.10`, a stem `TermsOfAddress.neutral`) still resolve. Absolute paths
   /// and full URLs are left untouched.
   ///
   /// A bare name the resolver cannot find on disk is a dead reference: the raw name as a
   /// relative URL is a guaranteed 404 in the browser. Such an `<img>` tag is removed from
   /// the output and its name is returned in `unresolvedRefs` so the caller can surface a
   /// build warning instead of shipping silent 404 noise.
   ///
   /// This is intentionally scoped to the DocC loader only: `MarkdownRenderer` is shared
   /// across all site types and must not be modified. Reference-style images (`![][ref]`)
   /// and inline images (`![](X)`) both produce `<img src="VALUE">` after Markdown parsing
   /// where VALUE is the bare reference target – the resource name without path or extension.
   static func rewriteBodyImageSrcs(_ html: String, relativeTo sourcePath: URL) -> (html: String, unresolvedRefs: [String]) {
      // Match src attributes that may need rewriting: a value that does not start with `/`, `"`,
      // or `:` and contains no `:` (so absolute paths and `http:`/`data:` URLs never match). Dots
      // are allowed inside the value so a dotted bare name (a screenshot timestamp) reaches the
      // resolver, which is the gatekeeper that leaves real-extension filenames unchanged. The
      // pattern captures everything before src="VALUE" (group 1) + VALUE (group 2) + the closing
      // quote and remaining tag (group 3). Only group 2 is replaced.
      guard let regex = try? NSRegularExpression(
         pattern: #"(<img\b[^>]*\bsrc=")([^":/][^":/]*)("[^>]*>)"#,
         options: []
      ) else { return (html, []) }

      let ns = html as NSString
      var result = ""
      var cursor = 0
      var unresolvedRefs: [String] = []

      let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
      for match in matches {
         let wholeRange = match.range
         let prefixRange = match.range(at: 1)
         let valueRange = match.range(at: 2)
         let suffixRange = match.range(at: 3)

         guard prefixRange.location != NSNotFound,
               valueRange.location != NSNotFound,
               suffixRange.location != NSNotFound else { continue }

         let value = ns.substring(with: valueRange)

         // Skip data: URIs (the pattern already excludes leading slash and colon, but
         // "data" without a colon would slip through – guard explicitly).
         guard !value.hasPrefix("data:") else { continue }

         // Append everything up to this match verbatim.
         result += ns.substring(with: NSRange(location: cursor, length: wholeRange.location - cursor))

         let trailingComponent = value.split(separator: ".").last.map { String($0).lowercased() } ?? ""
         if let resolved = resolveImageName(value, relativeTo: sourcePath) {
            result += ns.substring(with: prefixRange) + resolved + ns.substring(with: suffixRange)
         } else if Self.imageExtensions.contains(trailingComponent) {
            // Already-qualified filename (real trailing extension): the resolver declines
            // these by design and the author-provided value is used verbatim.
            result += ns.substring(with: wholeRange)
         } else {
            // Bare name with no file on disk: a dead reference that would 404. Drop the
            // tag from the output and report it so the caller can emit a build warning.
            unresolvedRefs.append(value)
         }

         cursor = wholeRange.location + wholeRange.length
      }

      result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
      return (result, unresolvedRefs)
   }

   /// Repairs "headerless" GFM pseudo-tables so they render as real HTML tables instead of
   /// leaking literal `|` pipes into the body text.
   ///
   /// GitHub-flavored Markdown only recognizes a table when the header row is immediately
   /// followed by a delimiter row (`| --- | --- |`). Old hand-written WWDCNotes routinely used a
   /// single- or multi-row pipe block to lay images and their captions out side by side, e.g.
   ///
   ///     | ![][shotA] | ![][shotB] |
   ///
   /// without that delimiter. cmark-gfm then parses the line as an ordinary paragraph and the
   /// pipes survive as visible `|` characters. This pass walks the source line by line, finds each
   /// run of consecutive pipe-rows that is not already a valid table, and injects a synthetic
   /// delimiter row after the first line of the run. The first row becomes the table header; any
   /// following rows become the body. Genuinely valid tables (delimiter already present) and pipes
   /// inside fenced or indented code blocks are left untouched.
   static func normalizePseudoTables(_ markdown: String) -> String {
      let lines = markdown.components(separatedBy: "\n")
      var output: [String] = []
      output.reserveCapacity(lines.count + 8)
      // Tracks the active fenced-code-block marker (the backtick or tilde character). Pipes inside
      // a code fence are literal and must never be reinterpreted as table cells.
      var fenceMarker: Character? = nil

      var index = 0
      while index < lines.count {
         let line = lines[index]
         let trimmed = line.trimmingCharacters(in: .whitespaces)

         // Inside a fence: emit verbatim and watch for the closing fence of the same kind.
         if let marker = fenceMarker {
            output.append(line)
            if trimmed.hasPrefix(String(repeating: marker, count: 3)) { fenceMarker = nil }
            index += 1
            continue
         }
         // Opening fence (``` or ~~~): remember the marker and emit verbatim.
         if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            fenceMarker = trimmed.first
            output.append(line)
            index += 1
            continue
         }

         // Indented code block: a raw leading indent of 4+ columns (any tab in the leading
         // run already reaches column 4) makes the line literal code in CommonMark, so its
         // pipes are never table cells. A genuine GFM table row indents at most 3 spaces.
         // Emit verbatim so no synthetic delimiter gets injected after code.
         let leadingIndentWidth = line.prefix { $0 == " " || $0 == "\t" }
            .reduce(0) { width, char in width + (char == "\t" ? 4 : 1) }
         if leadingIndentWidth >= 4 {
            output.append(line)
            index += 1
            continue
         }

         // A candidate pseudo-table header: a pipe-row whose own line is not itself a delimiter.
         if Self.isTableRowLine(trimmed), !Self.isTableDelimiterLine(trimmed) {
            output.append(line)
            let next = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""
            if Self.isTableDelimiterLine(next) {
               // Already a valid table: keep the delimiter and the body rows untouched.
               output.append(lines[index + 1])
               index += 2
               while index < lines.count, Self.isTableRowLine(lines[index].trimmingCharacters(in: .whitespaces)) {
                  output.append(lines[index])
                  index += 1
               }
            } else {
               // Headerless pseudo-table: inject a delimiter sized to the header, then consume the
               // remaining pipe-rows of the block verbatim as the table body.
               output.append(Self.syntheticDelimiterRow(columnCount: Self.tableColumnCount(trimmed)))
               index += 1
               while index < lines.count {
                  let bodyTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                  guard Self.isTableRowLine(bodyTrimmed), !Self.isTableDelimiterLine(bodyTrimmed) else { break }
                  output.append(lines[index])
                  index += 1
               }
               // Close the synthesized table with a blank line so a directly following
               // paragraph is not absorbed as a GFM table-continuation row.
               if index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                  output.append("")
               }
            }
            continue
         }

         output.append(line)
         index += 1
      }

      return output.joined(separator: "\n")
   }

   /// A GFM table-row line: trimmed, starts and ends with `|`, and carries at least two pipes (so
   /// at least one cell). Requiring both edge pipes is deliberately conservative – it avoids
   /// reinterpreting prose or code that merely contains a stray `|`.
   private static func isTableRowLine(_ trimmed: String) -> Bool {
      guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else { return false }
      return trimmed.filter { $0 == "|" }.count >= 2
   }

   /// A GFM delimiter row: contains a `|` and a `-`, and consists solely of `|`, `-`, `:`, and
   /// whitespace (e.g. `|---|---|`, `| :--- | ---: |`). Distinguishes a real table from a
   /// pseudo-table and prevents double-injecting a delimiter into an already-valid table.
   private static func isTableDelimiterLine(_ trimmed: String) -> Bool {
      guard trimmed.contains("|"), trimmed.contains("-") else { return false }
      return trimmed.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " || $0 == "\t" }
   }

   /// Counts the cells in a table-row line so the synthetic delimiter matches the header's column
   /// count (cmark-gfm rejects a table whose header and delimiter rows disagree on cell count).
   /// Inline code spans and escaped `\|` are neutralized first so their pipes are not miscounted.
   private static func tableColumnCount(_ trimmed: String) -> Int {
      // Drop escaped pipes and the contents of inline code spans, whose pipes are not cell
      // separators. The real catalog has no such pipes in a pseudo-table header, but neutralizing
      // them keeps the count correct if future content does.
      var sanitized = trimmed.replacingOccurrences(of: "\\|", with: "")
      sanitized = sanitized.replacing(/`[^`]*`/, with: "")
      var inner = sanitized
      if inner.hasPrefix("|") { inner.removeFirst() }
      if inner.hasSuffix("|") { inner.removeLast() }
      return inner.components(separatedBy: "|").count
   }

   /// Builds a synthetic GFM delimiter row with `columnCount` columns, e.g. `| --- | --- |`.
   private static func syntheticDelimiterRow(columnCount: Int) -> String {
      let cells = Array(repeating: " --- ", count: max(columnCount, 1))
      return "|" + cells.joined(separator: "|") + "|"
   }

   /// A note is a stub when it has no real body (abstract-only) or still carries the
   /// DocC template's placeholder GitHub-handle string.
   static func isStub(bodyHTML: String, rawMarkdown: String) -> Bool {
      let trimmedBody = bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmedBody.isEmpty { return true }
      if rawMarkdown.contains("<replace this with your GitHub handle>") { return true }
      return false
   }

   /// Extracts the framework key from an HTML comment of the form `<!-- framework: <key> -->`.
   /// Only alphanumeric + hyphen + underscore keys are accepted to avoid injecting arbitrary strings.
   /// Returns nil when no such comment is present in the raw Markdown.
   static func parseFrameworkComment(from markdown: String) -> String? {
      // Use NSRegularExpression to avoid Swift regex literal parser issues with HTML comment
      // delimiters (<!-- contains < which confuses the #/…/# parser).
      let pattern = "<!--\\s*framework:\\s*([a-zA-Z0-9_-]+)\\s*-->"
      guard let regex = try? NSRegularExpression(pattern: pattern),
            let nsMatch = regex.firstMatch(in: markdown, range: NSRange(markdown.startIndex..., in: markdown)),
            nsMatch.numberOfRanges >= 2,
            let keyRange = Range(nsMatch.range(at: 1), in: markdown)
      else {
         return nil
      }
      return String(markdown[keyRange])
   }

   /// Returns `true` when a GitHub handle extracted by `@GitHubUser(…)` is usable.
   ///
   /// The rule mirrors the exclusion that WWDCNotes' `generate-metadata` tool applies
   /// via its regex `@GitHubUser\(([^\n<>]+)\)` – its `[^<>]` character class already
   /// rejects any `<…>` bracket placeholder. To stay congruent with that source-of-truth
   /// tool we use a denylist (reject `<`, `>`, whitespace, or empty) rather than a strict
   /// allowlist. An allowlist like `[A-Za-z0-9-]` could silently drop a handle that
   /// generate-metadata would keep; the denylist only removes what the regex forbids.
   ///
   /// This cleanly eliminates the template stub `<replace this with your GitHub handle>`
   /// (and any future `<…>`-style placeholder) while keeping every real handle.
   static func isValidContributorHandle(_ handle: String) -> Bool {
      guard !handle.isEmpty else { return false }
      for char in handle {
         if char == "<" || char == ">" || char.isWhitespace { return false }
      }
      return true
   }

   /// Scans the body AST nodes for a level-2 heading "Topics" and collects each
   /// following level-3 heading as a `DocCTopicGroup` containing the session slugs
   /// extracted from the immediately-following `@Links` block directive.
   ///
   /// Strategy: walk nodes in document order. When a level-2 heading "Topics" is
   /// found, enter collection mode. Each level-3 heading starts a new group. A
   /// `BlockDirective` named "Links" immediately after a group heading supplies its
   /// slugs – first via AST traversal of `<doc:…>` link destinations, then via a
   /// regex over the directive's plain text as a fallback for any structure we miss.
   /// An encountered level-2 heading ends collection.
   ///
   /// Empty groups (0 slugs after resolution) are dropped. The result preserves
   /// document order.
   static func parseTopicGroups(from bodyNodes: [any Markup], language: String) -> [DocCTopicGroup] {
      var groups: [DocCTopicGroup] = []
      var inTopics = false
      var pendingGroupTitle: String? = nil
      var pendingGroupSlugs: [String] = []

      func commitPending() {
         guard let title = pendingGroupTitle, !pendingGroupSlugs.isEmpty else {
            pendingGroupTitle = nil
            pendingGroupSlugs = []
            return
         }
         groups.append(DocCTopicGroup(title: title, slugs: pendingGroupSlugs))
         pendingGroupTitle = nil
         pendingGroupSlugs = []
      }

      for node in bodyNodes {
         if let heading = node as? Heading {
            if heading.level == 2 {
               if heading.plainText == "Topics" {
                  inTopics = true
               } else {
                  // A different level-2 heading ends the Topics section.
                  commitPending()
                  inTopics = false
               }
               continue
            }
            if inTopics, heading.level == 3 {
               commitPending()
               pendingGroupTitle = heading.plainText
               continue
            }
         }

         if inTopics, pendingGroupTitle != nil, let directive = node as? BlockDirective, directive.name == "Links" {
            let slugs = Self.extractDocSlugs(from: directive, language: language)
            pendingGroupSlugs.append(contentsOf: slugs)
         }

         // Also accept a plain Markdown list of `<doc:…>` autolinks under a `### Heading`
         // (no `@Links` wrapper). This lets a catalog's root/index page curate loose guide
         // articles into a named group with the lightest possible authoring – a bare list –
         // while the year overviews keep using `@Links`. Both nest identically downstream.
         if inTopics, pendingGroupTitle != nil, node is UnorderedList || node is OrderedList {
            pendingGroupSlugs.append(contentsOf: Self.docSlugs(in: node, language: language))
         }
      }
      // Commit any group still open at end-of-document.
      commitPending()

      return groups
   }

   /// Parses a contributor profile note's `## Links` section into structured links.
   ///
   /// The section is a level-2 heading "Links" followed by a Markdown list whose items are
   /// `[Label](url)` links (e.g. `* [Blog](https://example.com)`) – exactly the shape
   /// `generate-metadata` writes. Returns the links in document order; an empty array when no
   /// `## Links` section or no qualifying link items are present. `<doc:…>` cross-reference
   /// autolinks (used by the per-year `## Contributions` lists) are ignored – only real
   /// external URLs become contributor links.
   static func parseContributorLinks(from bodyNodes: [any Markup]) -> [DocCContributorLink] {
      var links: [DocCContributorLink] = []
      var inLinks = false

      for node in bodyNodes {
         if let heading = node as? Heading, heading.level == 2 {
            // Any new level-2 heading ends the Links section (e.g. "## Contributions" follows).
            inLinks = heading.plainText == "Links"
            continue
         }
         guard inLinks, node is UnorderedList || node is OrderedList else { continue }

         func walk(_ markup: any Markup) {
            if let link = markup as? Link {
               let label = link.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
               let dest = (link.destination ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
               if !label.isEmpty, !dest.isEmpty, !dest.hasPrefix("doc:") {
                  links.append(DocCContributorLink(label: label, url: dest))
               }
            }
            for child in markup.children { walk(child) }
         }
         walk(node)
      }

      return links
   }

   /// Walks any markup subtree and returns the slugs of every `<doc:…>` link destination it
   /// contains, slugified the same way `DocCLoader` slugifies note filenames. Shared by the
   /// `## Topics` plain-list path and any other place that needs to resolve `<doc:>` targets.
   private static func docSlugs(in markup: any Markup, language: String) -> [String] {
      var slugs: [String] = []
      func walk(_ node: any Markup) {
         if let link = node as? Link, let dest = link.destination, dest.hasPrefix("doc:") {
            slugs.append(String(dest.dropFirst(4)).slugified(language: language))
         }
         for child in node.children { walk(child) }
      }
      walk(markup)
      return slugs
   }

   /// Extracts `doc:FileName` targets from an `@Links` block directive, converting
   /// each target filename to a session slug that matches what `DocCLoader` produces.
   ///
   /// Primary path: walk the directive's AST children looking for `Link` nodes whose
   /// destination starts with `doc:`. Fallback: regex over the directive's plain text
   /// to catch any list-item text structures the AST walker doesn't surface directly.
   private static func extractDocSlugs(from directive: BlockDirective, language: String) -> [String] {
      var slugs: [String] = []

      // Primary: walk all descendant inline nodes looking for Link destinations.
      func walkChildren(_ markup: any Markup) {
         if let link = markup as? Link, let dest = link.destination, dest.hasPrefix("doc:") {
            let filename = String(dest.dropFirst(4))  // drop "doc:" prefix
            slugs.append(filename.slugified(language: language))
         }
         for child in markup.children {
            walkChildren(child)
         }
      }
      for child in directive.children {
         walkChildren(child)
      }

      // Fallback: if the AST walk found nothing, scan the directive's plain text for
      // `doc:Identifier` patterns. This handles unusual list-item structures where the
      // link appears as raw text rather than a parsed Link node.
      if slugs.isEmpty {
         let plainText = directive.children.map { $0.format() }.joined()
         let matches = plainText.matches(of: #/doc:[A-Za-z0-9._-]+/#)
         for match in matches {
            let target = String(plainText[match.range])
            let filename = String(target.dropFirst(4))  // drop "doc:" prefix
            slugs.append(filename.slugified(language: language))
         }
      }

      return slugs
   }

   private func namedArguments(of directive: BlockDirective) -> [String: String] {
      var result: [String: String] = [:]
      for arg in directive.argumentText.parseNameValueArguments() {
         result[arg.name] = arg.value
      }
      return result
   }

   /// Returns the raw positional argument of a directive (e.g. `WWDC24` from
   /// `@TitleHeading("WWDC24")`), trimmed and unquoted.
   private func positionalArgument(of directive: BlockDirective) -> String {
      let raw = directive.argumentText.segments.map(\.trimmedText).joined()
      var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
         value = String(value.dropFirst().dropLast())
      }
      return value
   }
}
