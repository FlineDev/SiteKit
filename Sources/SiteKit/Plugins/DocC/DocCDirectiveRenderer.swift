import Foundation
import Markdown

/// Renders DocC block directives that appear in a note's body to HTML.
///
/// The v1 contract is **graceful degradation**: a directive that is unknown, or
/// recognized but not yet fully styled, renders its inner block content as
/// degraded-but-readable HTML – it never emits a raw `@Name` and never throws.
/// This guarantees every note in a catalog renders without leaking directive
/// syntax, even for directives this renderer does not specifically handle.
///
/// Parser gotcha handled by construction: this only ever receives `BlockDirective`
/// nodes from swift-markdown's block-directive parsing. Swift attributes like
/// `@State` inside a ```swift fence live in a `CodeBlock` node and are never
/// passed here, so code examples stay intact.
///
/// When a `sourcePath` is supplied at init time, `@Image(source:)` directives are
/// resolved via `DocCLoader.resolveImageName` which searches the catalog `Images/`
/// directory, the note's own directory, and the per-note sibling subfolder (the
/// WWDCNotes convention for body images). This covers all three DocC image
/// locations and eliminates the former `/images/<name>` 404 path.
public struct DocCDirectiveRenderer {
   private let markdown = MarkdownRenderer()
   /// The source file URL of the note being rendered. When set, `@Image(source:)`
   /// bare names are resolved to `/assets/<name>.<ext>` via `DocCLoader.resolveImageName`.
   private let sourcePath: URL?

   /// Creates a renderer without source-path resolution (unit tests, contexts without
   /// real files on disk). `@Image` sources will pass through unchanged for absolute /
   /// already-resolved URLs and produce `/assets/<name>` for bare names.
   public init() {
      self.sourcePath = nil
   }

   /// Creates a renderer whose `@Image(source:)` bare names are resolved against the
   /// note's catalog using `DocCLoader.resolveImageName`. Pass the note's source file URL.
   public init(sourcePath: URL) {
      self.sourcePath = sourcePath
   }

   /// Renders a body block directive. Unknown or not-yet-styled directives degrade
   /// to their readable inner content rather than leaking `@Name`.
   public func render(_ directive: BlockDirective) -> String {
      switch directive.name {
      case "Image":
         return self.renderImage(directive)
      case "Row":
         return self.renderRow(directive)
      case "Column":
         return self.renderColumn(directive)
      case "TabNavigator":
         return self.renderTabNavigator(directive)
      case "Video":
         return self.renderVideo(directive)
      case "Comment":
         // DocC comments are authoring notes (e.g. the "auto-generated below" marker) – never rendered.
         return ""
      case "Small":
         // @Small wraps ancillary content (legal notices, attribution footnotes) in a
         // visually de-emphasised block. The inner content is rendered normally and wrapped
         // in an sk-docc-small container so CSS can apply reduced size + muted color.
         return "<div class=\"sk-docc-small\">\(self.renderChildren(of: directive))</div>"
      default:
         // Graceful degradation (the v1 gate): keep the readable inner content, drop the
         // wrapper. For arg-only directives that carry no inner block content (e.g. a future
         // @Video(source:) / @PageImage(source:)), fall back to a link to the source/url so
         // the content is never silently lost – a vanished video is worse than an unstyled link.
         let inner = self.renderChildren(of: directive)
         if !inner.isEmpty { return inner }
         return self.fallbackLink(for: directive) ?? ""
      }
   }

   /// Last-resort degradation for an arg-only directive with no inner content: link to its
   /// `source` or `url` argument so the content stays reachable. Returns nil if neither exists.
   private func fallbackLink(for directive: BlockDirective) -> String? {
      var args: [String: String] = [:]
      for arg in directive.argumentText.parseNameValueArguments() {
         args[arg.name] = arg.value
      }
      if let url = args["url"], !url.isEmpty {
         let label = args["label"] ?? url
         return "<p><a href=\"\(Self.escapeAttribute(url))\">\(Self.escapeAttribute(label))</a></p>"
      }
      if let source = args["source"], !source.isEmpty {
         let href = self.resolveImageSource(source)
         return "<p><a href=\"\(Self.escapeAttribute(href))\">\(Self.escapeAttribute(source))</a></p>"
      }
      return nil
   }

   /// Renders a directive's block children to HTML. Nested directives recurse through
   /// `self` (so a nested unknown directive also degrades instead of being dropped);
   /// everything else flows through the standard Markdown node renderer.
   private func renderChildren(of directive: BlockDirective) -> String {
      directive.children.map { child -> String in
         if let nested = child as? BlockDirective {
            return self.render(nested)
         }
         return self.markdown.renderNode(child)
      }.joined()
   }

   private func renderImage(_ directive: BlockDirective) -> String {
      var args: [String: String] = [:]
      for arg in directive.argumentText.parseNameValueArguments() {
         args[arg.name] = arg.value
      }
      guard let source = args["source"], !source.isEmpty else {
         // Malformed @Image (no source) → degrade rather than emit a broken tag.
         return self.renderChildren(of: directive)
      }
      let alt = args["alt"] ?? ""
      let src = self.resolveImageSource(source)
      return "<figure class=\"sk-docc-image\"><img src=\"\(Self.escapeAttribute(src))\" alt=\"\(Self.escapeAttribute(alt))\" loading=\"lazy\" /></figure>"
   }

   /// Renders a `@Row` flex container. `numberOfColumns:` is carried as a `data-columns`
   /// hint (DocC uses it to size the grid; the visual that matters is the per-column `size`
   /// ratio, applied in `renderColumn`). The stylesheet keeps `flex-wrap` on the row so the
   /// columns still stack on narrow viewports.
   private func renderRow(_ directive: BlockDirective) -> String {
      let args = self.namedArguments(of: directive)
      var attributes = " class=\"sk-docc-row\""
      if let columns = args["numberOfColumns"], !columns.isEmpty {
         attributes += " data-columns=\"\(Self.escapeAttribute(columns))\""
      }
      return "<div\(attributes)>\(self.renderChildren(of: directive))</div>"
   }

   /// Renders a `@Column`. A `size:` weight is emitted as an inline `flex-grow`, so a
   /// `@Column(size: 2)` next to a `@Column(size: 1)` renders ~2:1 (DocC's behaviour); the
   /// inline style overrides the stylesheet's `flex-grow: 1`. A size-less column emits no
   /// `style` attribute and therefore renders byte-identically to a plain column, leaving
   /// existing rows untouched.
   private func renderColumn(_ directive: BlockDirective) -> String {
      let args = self.namedArguments(of: directive)
      if let sizeText = args["size"], let size = Int(sizeText), size > 0 {
         return "<div class=\"sk-docc-column\" style=\"flex-grow: \(size)\">\(self.renderChildren(of: directive))</div>"
      }
      return "<div class=\"sk-docc-column\">\(self.renderChildren(of: directive))</div>"
   }

   /// Renders a `@TabNavigator` as an interactive, no-JS CSS tab UI – mirroring
   /// `DocCVariantSwitcher`: visually-hidden radio inputs whose `:checked` state reveals the
   /// matching panel. Each child `@Tab(label)` becomes one radio (the first is `checked`), a
   /// tab-bar `<label>`, and a panel holding the tab's rendered children. Only the checked
   /// tab's panel is shown (via CSS); native radios keep it keyboard-operable.
   ///
   /// The radio `name`/`id` are derived from a deterministic FNV-1a hash of the tab labels
   /// and rendered panel content, so two tab groups on one page never share a radio group
   /// (selecting a tab in one would otherwise flip the other). This avoids randomness, which
   /// is unavailable here and would break build determinism.
   private func renderTabNavigator(_ directive: BlockDirective) -> String {
      let tabs = directive.children
         .compactMap { $0 as? BlockDirective }
         .filter { $0.name == "Tab" }
         .map { (label: self.positionalArgument(of: $0), content: self.renderChildren(of: $0)) }

      // No @Tab children → degrade to the inner content so nothing is lost.
      guard !tabs.isEmpty else { return self.renderChildren(of: directive) }

      let seed = tabs.map { "\($0.label)\u{1F}\($0.content)" }.joined(separator: "\u{1E}")
      let group = "sk-docc-tabs-\(Self.stableID(for: seed))"
      let ariaLabel = Self.escapeAttribute(tabs.map(\.label).joined(separator: ", "))

      var radios = ""
      var bar = ""
      var panels = ""
      for (index, tab) in tabs.enumerated() {
         let id = "\(group)-\(index)"
         let checked = index == 0 ? " checked" : ""
         let label = Self.escapeAttribute(tab.label)
         radios += "<input class=\"sk-docc-tab-radio\" type=\"radio\" name=\"\(group)\" id=\"\(id)\" aria-label=\"\(label)\"\(checked)/>"
         bar += "<label class=\"sk-docc-tab-label\" for=\"\(id)\">\(label)</label>"
         panels += "<div class=\"sk-docc-tab-panel\">\(tab.content)</div>"
      }

      return "<div class=\"sk-docc-tabs\">"
         + radios
         + "<div class=\"sk-docc-tab-bar\" role=\"tablist\" aria-label=\"\(ariaLabel)\">\(bar)</div>"
         + "<div class=\"sk-docc-tab-panels\">\(panels)</div>"
         + "</div>"
   }

   /// Renders a `@Video` as a real inline player matching DocC: `<video autoplay loop muted
   /// playsinline>` wrapping a resolved `<source>` (its `type` derived from the extension). A
   /// `poster:` argument is resolved as an image. When the source cannot be resolved to a
   /// usable URL (a bare name whose extension we cannot determine), it degrades to the
   /// graceful link fallback rather than emitting a `<video>` with an empty/broken src.
   private func renderVideo(_ directive: BlockDirective) -> String {
      let args = self.namedArguments(of: directive)
      guard let source = args["source"], !source.isEmpty, let src = self.resolveVideoSource(source) else {
         let inner = self.renderChildren(of: directive)
         if !inner.isEmpty { return inner }
         return self.fallbackLink(for: directive) ?? ""
      }
      let type = Self.videoMimeType(forPath: src)
      var posterAttribute = ""
      if let poster = args["poster"], !poster.isEmpty {
         posterAttribute = " poster=\"\(Self.escapeAttribute(self.resolveImageSource(poster)))\""
      }
      return "<figure class=\"sk-docc-video\">"
         + "<video autoplay loop muted playsinline\(posterAttribute)>"
         + "<source src=\"\(Self.escapeAttribute(src))\" type=\"\(type)\">"
         + "</video></figure>"
   }

   /// Resolves a `@Video` source to a browser-usable URL. Absolute paths (`/…`) and full URLs
   /// pass through unchanged. A bare name (optionally carrying a `.mp4`/`.mov` extension)
   /// resolves via `DocCLoader.resolveVideoName` when a `sourcePath` is set. When unresolved
   /// but the source already carries a known video extension, it degrades to `/assets/<source>`
   /// (the teleported location), mirroring how `resolveImageSource` degrades. Returns nil for
   /// a bare extension-less name we cannot resolve, so the caller can fall back to a link.
   private func resolveVideoSource(_ source: String) -> String? {
      if source.hasPrefix("/") || source.contains("://") { return source }
      let bareName = Self.strippingVideoExtension(source)
      if let path = self.sourcePath, let resolved = DocCLoader.resolveVideoName(bareName, relativeTo: path) {
         return resolved
      }
      if Self.hasVideoExtension(source) { return "/assets/\(source)" }
      return nil
   }

   /// The video extensions SiteKit emits players for, mapped to their MIME types.
   private static let videoExtensions: [String: String] = ["mp4": "video/mp4", "mov": "video/quicktime"]

   private static func hasVideoExtension(_ source: String) -> Bool {
      self.videoExtensions[(source as NSString).pathExtension.lowercased()] != nil
   }

   private static func strippingVideoExtension(_ source: String) -> String {
      let ext = (source as NSString).pathExtension.lowercased()
      guard self.videoExtensions[ext] != nil else { return source }
      return (source as NSString).deletingPathExtension
   }

   private static func videoMimeType(forPath path: String) -> String {
      self.videoExtensions[(path as NSString).pathExtension.lowercased()] ?? "video/mp4"
   }

   /// Parses a directive's named arguments (`name: value`) into a dictionary.
   private func namedArguments(of directive: BlockDirective) -> [String: String] {
      var result: [String: String] = [:]
      for arg in directive.argumentText.parseNameValueArguments() {
         result[arg.name] = arg.value
      }
      return result
   }

   /// Returns the raw positional argument of a directive (e.g. `Declared` from
   /// `@Tab("Declared")`), trimmed and unquoted.
   private func positionalArgument(of directive: BlockDirective) -> String {
      let raw = directive.argumentText.segments.map(\.trimmedText).joined()
      var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
         value = String(value.dropFirst().dropLast())
      }
      return value
   }

   /// A deterministic FNV-1a 64-bit hash, rendered base-36. Used to derive collision-free
   /// radio-group names for tab groups across processes – Swift's built-in `Hasher` is seeded
   /// per process and would produce a different value every build.
   private static func stableID(for seed: String) -> String {
      var hash: UInt64 = 14695981039346656037
      for byte in seed.utf8 {
         hash ^= UInt64(byte)
         hash = hash &* 1099511628211
      }
      return String(hash, radix: 36)
   }

   /// Resolves a DocC image source to a browser-usable URL.
   ///
   /// Absolute paths (`/…`) and full URLs (`…://…`) pass through unchanged.
   /// Bare names (no leading slash, no scheme) are resolved via
   /// `DocCLoader.resolveImageName` when a `sourcePath` is set, which searches
   /// the catalog `Images/` directory, the note's own directory, and the per-note
   /// sibling subfolder. When no file is found, the bare name is returned prefixed
   /// with `/assets/` so the URL is at least plausible (never `/images/`).
   private func resolveImageSource(_ source: String) -> String {
      if source.hasPrefix("/") || source.contains("://") { return source }
      if let path = self.sourcePath, let resolved = DocCLoader.resolveImageName(source, relativeTo: path) {
         return resolved
      }
      // Degrade to /assets/<name> rather than the former broken /images/<name>.
      return "/assets/\(source)"
   }

   private static func escapeAttribute(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
