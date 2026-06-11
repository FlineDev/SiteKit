import Foundation
import Logging

/// Post-processor that rewrites CSS `background-image: url(...)` declarations to
/// use responsive `image-set()` with generated variants – the CSS counterpart to
/// the `ImageResizer` that handles `<img>` tags.
///
/// ### Why
///
/// `ImageResizer` only touches `<img>` markup. A full-bleed hero background like
/// AST's `.sk-home-hero { background: url('/assets/hero-bg.webp') … }` stays at
/// its full source resolution on every page view – for a 1600×1069 WebP that's
/// ~370 KB on every first visit, mobile included. Lighthouse flags this as
/// "Properly size images" with 80+ KB potential savings per image.
///
/// ### How
///
/// 1. Scan every `.css` file in the output for `background-image: url("/local-path.ext")`
///    (and the `background:` shorthand with a `url(...)` inside).
/// 2. For each matched URL, resolve a role from `ImageManifest.yaml` – either a
///    `"css:<selector>"` manifest role (preferred) or a heuristic based on the
///    source dimensions. Generate variants via the shared `ImageResizer` tooling.
/// 3. Rewrite the `url("…")` to `image-set(url("…-Nw.ext") 1x, url("…-2Nw.ext") 2x)`
///    for density control. When the role's mobile width is meaningfully smaller
///    than desktop, append an `@media (max-width: Mbp)` override at the END of
///    the CSS file with a mobile-tuned `image-set()`.
///
/// `image-set()` is supported by Safari 17+, Chrome 88+, Firefox 88+ – essentially
/// every browser in use today. Older browsers fall back to the unmodified
/// declaration (we keep the first `url(...)` form intact inside the `image-set()`).
///
/// ### Scope / safety
///
/// Only rewrites when:
/// - URL starts with `/` (local asset).
/// - URL points to an existing resizable file (`.webp`, `.jpg`, `.jpeg`, `.png`).
/// - The rule sits at top level (not inside `@media`, `@keyframes`, or
///   `@supports`) – nested contexts are left untouched to avoid interaction
///   with existing viewport overrides.
/// - The declaration's `url(...)` hasn't already been wrapped in `image-set()`.
///
/// Anything outside this safe set is passed through verbatim. Themes retain
/// full control over complex cases.
public struct CSSBackgroundImageProcessor: OutputProcessor {
   public init() {}

   public func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws {
      guard themeConfig?.resizeImages != false else { return }

      let logger = Logger(label: "SiteKit.CSSBackgroundImageProcessor")

      guard let tool = ImageToolResolver.find() else {
         logger.warning("No image resize tool on PATH; skipping CSS background resize.")
         return
      }

      let manifest: ImageManifest?
      do {
         manifest = try ImageManifest.load(fromProjectDirectory: projectDirectory)
      } catch {
         manifest = nil
      }
      let mobileBreakpoint = manifest?.effectiveMobileBreakpoint ?? 768

      let cacheDir = projectDirectory.appendingPathComponent(".sitekit-cache/images")
      try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

      var dimensionsCache: [String: (Int, Int)] = [:]
      var filesRewritten = 0
      var declarationsRewritten = 0
      var variantsGenerated = 0
      var cacheHits = 0

      guard let enumerator = FileManager.default.enumerator(
         at: outputDirectory,
         includingPropertiesForKeys: [.isRegularFileKey]
      ) else { return }

      for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "css" {
         guard var css = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
         // Cheap pre-filter so we don't pay the full scan for CSS that doesn't reference images.
         guard css.contains("url(") else { continue }

         let result = Self.rewriteBackgroundImages(
            css: css,
            cssFileURL: fileURL,
            outputDirectory: outputDirectory,
            cacheDir: cacheDir,
            tool: tool,
            manifest: manifest,
            mobileBreakpoint: mobileBreakpoint,
            dimensionsCache: &dimensionsCache,
            logger: logger
         )
         if result.css != css {
            css = result.css
            try css.write(to: fileURL, atomically: true, encoding: .utf8)
            filesRewritten += 1
         }
         declarationsRewritten += result.declarationsRewritten
         variantsGenerated += result.variantsGenerated
         cacheHits += result.cacheHits
      }

      if declarationsRewritten > 0 {
         logger.info(
            "CSS backgrounds: \(declarationsRewritten) declaration(s) rewritten in \(filesRewritten) file(s), \(variantsGenerated) variant(s) generated, \(cacheHits) cache hit(s)."
         )
      }
   }

   // MARK: - Rewrite engine

   struct RewriteResult {
      var css: String
      var declarationsRewritten: Int
      var variantsGenerated: Int
      var cacheHits: Int
   }

   /// Walks the CSS character by character, tracking `{}` nesting and `@`-context
   /// so only top-level `background(-image)?:` declarations with a single local
   /// `url(...)` are rewritten. Append mobile `@media` overrides at the end.
   static func rewriteBackgroundImages(
      css: String,
      cssFileURL: URL,
      outputDirectory: URL,
      cacheDir: URL,
      tool: ImageToolResolver.Tool,
      manifest: ImageManifest?,
      mobileBreakpoint: Int,
      dimensionsCache: inout [String: (Int, Int)],
      logger: Logger
   ) -> RewriteResult {
      // Parse into top-level rules. Skip any rule inside `@media`, `@supports`,
      // `@keyframes`, etc. – they often have their own viewport semantics and
      // we don't want to fight them.
      let topLevelRules = Self.scanTopLevelRules(css)
      guard !topLevelRules.isEmpty else {
         return RewriteResult(css: css, declarationsRewritten: 0, variantsGenerated: 0, cacheHits: 0)
      }

      var result = css
      var responsiveOverrides: [ResponsiveOverride] = []
      var declarationsRewritten = 0
      var variantsGenerated = 0
      var cacheHits = 0

      // Process in REVERSE order so earlier rule ranges remain valid while we
      // mutate later ones.
      for rule in topLevelRules.reversed() {
         let bodyRange = rule.bodyRange
         let body = String(result[bodyRange])
         guard let (newBody, rewrittenCount, responsive, generatedCount, hitCount) = Self.rewriteRuleBody(
            body: body,
            ruleSelector: rule.selector,
            outputDirectory: outputDirectory,
            cacheDir: cacheDir,
            tool: tool,
            manifest: manifest,
            mobileBreakpoint: mobileBreakpoint,
            dimensionsCache: &dimensionsCache,
            logger: logger
         ) else { continue }

         declarationsRewritten += rewrittenCount
         variantsGenerated += generatedCount
         cacheHits += hitCount
         if let responsive { responsiveOverrides.append(responsive) }
         result.replaceSubrange(bodyRange, with: newBody)
      }

      // Append mobile overrides once, at end of file, each wrapped in its own
      // `@media (max-width: Npx)` block.
      if !responsiveOverrides.isEmpty {
         var appended = "\n\n/* SiteKit responsive background-image overrides for narrow viewports */\n"
         // Group consecutive overrides by breakpoint to reduce the number of
         // @media blocks (all current roles share one breakpoint anyway).
         let grouped = Dictionary(grouping: responsiveOverrides, by: { $0.breakpoint })
         for (bp, items) in grouped.sorted(by: { $0.key < $1.key }) {
            appended += "@media (max-width: \(bp)px) {\n"
            for item in items {
               appended += "   \(item.selector) { \(item.property): \(item.value); }\n"
            }
            appended += "}\n"
         }
         result += appended
      }

      return RewriteResult(
         css: result,
         declarationsRewritten: declarationsRewritten,
         variantsGenerated: variantsGenerated,
         cacheHits: cacheHits
      )
   }

   /// Captures everything the `@media` mobile override needs to rebuild the
   /// ENTIRE declaration – property name + full value (gradient layers, position,
   /// size, repeat, …) with only the `url(...)` swapped. Without the full value
   /// the override would drop the gradient overlay layer that the shorthand
   /// `background: linear-gradient(...), url(...)` composes – giving mobile a
   /// bare image while desktop has a tinted/dimmed version.
   private struct ResponsiveOverride {
      let selector: String
      let property: String
      let value: String
      let breakpoint: Int
   }

   /// Rewrites `url("/…")` inside `background(-image)?:` declarations within a
   /// single rule body. Returns the rewritten body and optionally a mobile
   /// `ResponsiveOverride` to append at end of file.
   private static func rewriteRuleBody(
      body: String,
      ruleSelector: String,
      outputDirectory: URL,
      cacheDir: URL,
      tool: ImageToolResolver.Tool,
      manifest: ImageManifest?,
      mobileBreakpoint: Int,
      dimensionsCache: inout [String: (Int, Int)],
      logger: Logger
   ) -> (newBody: String, rewrittenCount: Int, responsive: ResponsiveOverride?, variants: Int, cacheHits: Int)? {
      // Match `background-image: …url("/path"); or `background: … url("/path") …;`
      // where `…` contains the url(...). Capture 1 = the url() opening through path.
      let pattern = #/(?<prop>background(?:-image)?)\s*:\s*(?<value>[^;}]*?url\(\s*['"]?(?<path>\/[^'")\s]+)['"]?\s*\)[^;}]*)[;}]/#

      var newBody = ""
      newBody.reserveCapacity(body.count)
      var cursor = body.startIndex
      var rewrittenCount = 0
      var responsive: ResponsiveOverride?
      var variants = 0
      var cacheHits = 0

      for match in body.matches(of: pattern) {
         let property = String(match.output.prop)
         let value = String(match.output.value)
         let path = String(match.output.path)

         // Already rewritten? Skip.
         if value.contains("image-set(") {
            continue
         }
         // Only handle resizable extensions.
         let ext = (path as NSString).pathExtension.lowercased()
         guard ["webp", "jpg", "jpeg", "png"].contains(ext) else { continue }

         // Source file must exist on disk under outputDirectory.
         let srcPath = outputDirectory.appendingPathComponent(String(path.dropFirst()))
         guard FileManager.default.fileExists(atPath: srcPath.path) else { continue }

         // Probe source dimensions (cached).
         let sourceWidth: Int
         let sourceHeight: Int
         if let cached = dimensionsCache[path] {
            (sourceWidth, sourceHeight) = cached
         } else if let probed = ImageToolResolver.identifyDimensions(of: srcPath, tool: tool) {
            dimensionsCache[path] = probed
            (sourceWidth, sourceHeight) = probed
         } else {
            continue
         }
         _ = sourceHeight

         // Resolve a role – first by `css:selector` match against manifest, else
         // by source-size heuristic.
         let role = Self.resolveRole(
            forSelector: ruleSelector,
            manifest: manifest,
            sourceWidth: sourceWidth
         )

         let desktopBase = min(role.desktopWidth, sourceWidth)
         let desktopRetina = min(role.desktopWidth * 2, sourceWidth)
         let mobileRetina = min(role.mobileWidth * 3, sourceWidth)

         // Generate variants – reuse shared tooling.
         func makeVariant(width: Int) -> String? {
            if width >= sourceWidth { return path }
            let result = ImageToolResolver.ensureVariant(
               originalSrc: path,
               outputDirectory: outputDirectory,
               cacheDir: cacheDir,
               targetWidth: width,
               fileExtension: ext,
               tool: tool,
               logger: logger
            )
            switch result {
            case .generated(let url):
               variants += 1
               return url
            case .cacheHit(let url):
               cacheHits += 1
               return url
            case .failed:
               return nil
            }
         }

         guard let desktopBasePath = makeVariant(width: desktopBase),
               let desktopRetinaPath = makeVariant(width: desktopRetina) else {
            continue
         }

         // Build desktop `image-set()`.
         let desktopImageSet = Self.imageSet(pairs: [
            (desktopBasePath, "1x"),
            (desktopRetinaPath, "2x"),
         ])
         // Replace the original `url(...)` with `image-set(...)` in the declaration value.
         // We rewrite just the `url(...)` portion so any surrounding properties
         // (position, size, gradient layering) stay intact.
         let newValue = Self.replaceFirstURL(in: value, with: desktopImageSet)
         let replacement = "\(property): \(newValue);"

         // Append preceding content + rewritten declaration.
         newBody.append(contentsOf: body[cursor..<match.range.lowerBound])
         newBody.append(replacement)
         cursor = match.range.upperBound
         rewrittenCount += 1

         // If mobile is meaningfully narrower, emit a mobile override that
         // re-declares the FULL original value with only the `url(...)` swapped
         // to a mobile-sized `image-set()`. Preserving the value keeps gradient
         // layers, position, size, and repeat rules intact – otherwise a mobile
         // visitor loses the overlay gradient the desktop rule stacked on top.
         if role.mobileWidth * 2 < role.desktopWidth,
            let mobileBasePath = makeVariant(width: role.mobileWidth),
            let mobileRetinaPath = makeVariant(width: mobileRetina) {
            let mobileImageSet = Self.imageSet(pairs: [
               (mobileBasePath, "1x"),
               (mobileRetinaPath, "3x"),
            ])
            let mobileValue = Self.replaceFirstURL(in: value, with: mobileImageSet)
            responsive = ResponsiveOverride(
               selector: ruleSelector,
               property: property,
               value: mobileValue,
               breakpoint: mobileBreakpoint
            )
         }
      }

      if cursor == body.startIndex {
         return nil
      }
      newBody.append(contentsOf: body[cursor..<body.endIndex])
      return (newBody, rewrittenCount, responsive, variants, cacheHits)
   }

   private static func resolveRole(forSelector selector: String, manifest: ImageManifest?, sourceWidth: Int) -> ImageRole {
      if let manifest {
         for role in manifest.roles {
            guard role.selector.hasPrefix("css:") else { continue }
            let cssSelector = String(role.selector.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            if Self.cssSelectorMatches(rule: selector, query: cssSelector) {
               return role
            }
         }
      }
      // Heuristic fallback: assume the background covers the whole viewport at
      // a desktop size around min(source, 1400).
      let desktop = min(sourceWidth, 1400)
      return ImageRole(name: "background-heuristic", selector: "css:*", desktopWidth: desktop, mobileWidth: desktop)
   }

   /// Matches a manifest `css:` selector against a rule selector – very
   /// permissive: checks if any comma-separated part of the rule contains the
   /// query (e.g., `.sk-home-hero, .x` rule matches query `.sk-home-hero`).
   private static func cssSelectorMatches(rule: String, query: String) -> Bool {
      let parts = rule.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      let queryTrimmed = query.trimmingCharacters(in: .whitespaces)
      for part in parts {
         if part == queryTrimmed || part.contains(queryTrimmed) {
            return true
         }
      }
      return false
   }

   /// Serializes an `image-set()` expression, `url()`-quoted, comma-separated
   /// density descriptors. Using double quotes so paths with parentheses are safe.
   private static func imageSet(pairs: [(String, String)]) -> String {
      let parts = pairs.map { "url(\"\($0.0)\") \($0.1)" }
      return "image-set(\(parts.joined(separator: ", ")))"
   }

   /// Replaces the first `url(...)` occurrence in `value` with `replacement`.
   /// Preserves surrounding tokens (gradients, positions, sizes).
   private static func replaceFirstURL(in value: String, with replacement: String) -> String {
      let pattern = #/url\(\s*['"]?\/[^'")\s]+['"]?\s*\)/#
      return value.replacing(pattern, with: replacement, maxReplacements: 1)
   }

   // MARK: - Top-level rule scanner

   struct TopLevelRule {
      let selector: String
      let bodyRange: Range<String.Index>  // the characters BETWEEN the `{` and `}` (exclusive)
   }

   /// Returns the ranges of every rule body that sits at the OUTER level of the
   /// stylesheet (i.e. not nested inside `@media`, `@supports`, `@keyframes`,
   /// etc.). Ignores comments. Keeps it simple – character-by-character scan
   /// with a `{}` depth counter and an `@`-block flag.
   static func scanTopLevelRules(_ css: String) -> [TopLevelRule] {
      var rules: [TopLevelRule] = []
      var depth = 0
      var atBlockDepth: Int? = nil   // when non-nil, we're inside an @-block; rules nested here are skipped
      var selectorStart = css.startIndex
      var index = css.startIndex
      var inComment = false
      var inString: Character? = nil

      while index < css.endIndex {
         let character = css[index]

         if inComment {
            if character == "*",
               let next = css.index(index, offsetBy: 1, limitedBy: css.endIndex),
               next < css.endIndex,
               css[next] == "/" {
               inComment = false
               index = css.index(after: next)
               continue
            }
            index = css.index(after: index)
            continue
         }
         if let q = inString {
            if character == q { inString = nil }
            index = css.index(after: index)
            continue
         }
         if character == "/",
            let next = css.index(index, offsetBy: 1, limitedBy: css.endIndex),
            next < css.endIndex,
            css[next] == "*" {
            inComment = true
            index = css.index(after: next)
            continue
         }
         if character == "\"" || character == "'" {
            inString = character
            index = css.index(after: index)
            continue
         }

         if character == "{" {
            // Determine if this opening brace belongs to an @-block.
            let rawSelector = String(css[selectorStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            let isAtBlock = rawSelector.hasPrefix("@")
            depth += 1
            if isAtBlock {
               if atBlockDepth == nil { atBlockDepth = depth }
            } else if atBlockDepth == nil {
               // Outer-level rule.
               let bodyStart = css.index(after: index)
               // Find matching close to form the body range.
               if let bodyEnd = Self.matchingCloseBrace(in: css, openAt: index) {
                  rules.append(TopLevelRule(selector: rawSelector, bodyRange: bodyStart..<bodyEnd))
                  // Skip ahead past the close brace.
                  depth -= 1
                  index = css.index(after: bodyEnd)
                  selectorStart = index
                  continue
               }
            }
            index = css.index(after: index)
            continue
         }
         if character == "}" {
            depth -= 1
            if let atDepth = atBlockDepth, depth < atDepth {
               atBlockDepth = nil
            }
            index = css.index(after: index)
            selectorStart = index
            continue
         }
         if character == ";" && depth == 0 {
            // Top-level declaration like @import, @charset – reset selector start.
            index = css.index(after: index)
            selectorStart = index
            continue
         }
         index = css.index(after: index)
      }
      return rules
   }

   /// Returns the index of the `}` that matches the `{` at `openAt`. Balances
   /// braces (ignoring those inside strings/comments). Returns nil if mismatched.
   private static func matchingCloseBrace(in css: String, openAt: String.Index) -> String.Index? {
      var depth = 0
      var index = openAt
      var inComment = false
      var inString: Character? = nil
      while index < css.endIndex {
         let character = css[index]
         if inComment {
            if character == "*",
               let next = css.index(index, offsetBy: 1, limitedBy: css.endIndex),
               next < css.endIndex,
               css[next] == "/" {
               inComment = false
               index = css.index(after: next)
               continue
            }
            index = css.index(after: index)
            continue
         }
         if let q = inString {
            if character == q { inString = nil }
            index = css.index(after: index)
            continue
         }
         if character == "/",
            let next = css.index(index, offsetBy: 1, limitedBy: css.endIndex),
            next < css.endIndex,
            css[next] == "*" {
            inComment = true
            index = css.index(after: next)
            continue
         }
         if character == "\"" || character == "'" {
            inString = character
            index = css.index(after: index)
            continue
         }
         if character == "{" { depth += 1 }
         if character == "}" {
            depth -= 1
            if depth == 0 { return index }
         }
         index = css.index(after: index)
      }
      return nil
   }
}
