import Foundation

/// Inlines every locally-referenced `<link rel="stylesheet">`, `<script src>`, and
/// `<img src>` in a SiteKit-built HTML page into a single self-contained document
/// that loads correctly from a `file://` URL inside an iframe. External CDN
/// references (Google Fonts, jsdelivr, cdnjs) are left untouched – they degrade
/// gracefully when the preview is opened offline.
public enum PreviewInliner {
   /// Inlines all `_Site/`-relative assets referenced in `html`.
   ///
   /// - Parameters:
   ///   - html: The raw HTML of `_Site/index.html`.
   ///   - siteDirectory: The directory `_Site/` was written to. Used to resolve
   ///     `/assets/...` references against the filesystem.
   /// - Returns: A standalone HTML string with `<link>` → `<style>`, `<script src>` →
   ///   inlined `<script>`, and `<img src>` → `data:` URI for local references.
   ///   External URLs (http/https/data/protocol-relative `//`) are preserved.
   public static func inline(html: String, siteDirectory: URL) -> String {
      var output = html
      output = self.stripLanguageRedirect(in: output)
      output = self.inlineStylesheets(in: output, siteDirectory: siteDirectory)
      output = self.inlineScripts(in: output, siteDirectory: siteDirectory)
      output = self.inlineImages(in: output, siteDirectory: siteDirectory)
      output = self.stripCacheBustingQueryStrings(in: output)
      return output
   }

   // MARK: - Language redirect

   /// Strips the inline `LanguageRedirectRenderer` script from rendered output.
   /// In a production site the script redirects visitors with a non-default
   /// browser language to `/<locale>/<path>`. In a preview file that script
   /// rewrites `file:///…/Sidebar-…html` into `file:///de/…/Sidebar-…html` –
   /// which doesn't exist – and lands the user on Chrome's `chrome-error://`
   /// page. The script is recognisable by its `var LANGS = [...]; var DEFAULT`
   /// declaration; removing it preserves every other inline `<script>` (theme
   /// toggle bootstrap, JSON-LD, etc.).
   public static func stripLanguageRedirect(in html: String) -> String {
      // Each `(?:(?!</script>).)*?` consumes any character (with the dotall flag)
      // EXCEPT the start of a `</script>` literal – so a stray inline script
      // emitted before the LANGS one can no longer be silently swallowed when the
      // outer match closes on the LANGS script's `</script>`.
      let pattern = #"<script(?:\s[^>]*)?>(?:(?!</script>).)*?var\s+LANGS\s*=\s*\[(?:(?!</script>).)*?</script>"#
      return html.replacingMatches(of: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) { _ in "" }
   }

   // MARK: - Stylesheets

   /// Replaces every `<link rel="stylesheet" href="…">` with `<style>` containing the
   /// referenced CSS when `href` is a local `_Site/`-relative path. External hrefs
   /// (http/https/data/protocol-relative) and unresolved paths are left as-is.
   ///
   /// Whitespace between attributes, attribute order, and self-closing `/>` vs `>` are
   /// all tolerated.
   public static func inlineStylesheets(in html: String, siteDirectory: URL) -> String {
      let pattern = #"<link\b[^>]*\brel\s*=\s*["']stylesheet["'][^>]*>"#
      return html.replacingMatches(of: pattern, options: [.caseInsensitive]) { match in
         guard let href = self.attribute(named: "href", in: match) else { return match }
         guard self.isLocalAsset(href) else { return match }
         guard let cssURL = self.resolve(href: href, inside: siteDirectory),
               let css = try? String(contentsOf: cssURL, encoding: .utf8)
         else {
            return match
         }
         return "<style>\(css)</style>"
      }
   }

   // MARK: - Scripts

   /// Replaces every `<script src="…">…</script>` with `<script>…</script>` containing
   /// the file contents when `src` is a local `_Site/`-relative path. External `src`
   /// values are left as-is. Inline `<script>` blocks (no `src`) are not touched.
   public static func inlineScripts(in html: String, siteDirectory: URL) -> String {
      let pattern = #"<script\b[^>]*\bsrc\s*=\s*["'][^"']*["'][^>]*>\s*</script>"#
      return html.replacingMatches(of: pattern, options: [.caseInsensitive]) { match in
         guard let src = self.attribute(named: "src", in: match) else { return match }
         guard self.isLocalAsset(src) else { return match }
         guard let jsURL = self.resolve(href: src, inside: siteDirectory),
               let js = try? String(contentsOf: jsURL, encoding: .utf8)
         else {
            return match
         }
         return "<script>\(js)</script>"
      }
   }

   // MARK: - Images

   /// Rewrites every `<img src="…">` whose `src` points at a local file inside
   /// `_Site/` to a `data:` URI. External URLs and SVG-`data:` URIs are preserved.
   public static func inlineImages(in html: String, siteDirectory: URL) -> String {
      let pattern = #"<img\b[^>]*\bsrc\s*=\s*["'][^"']*["'][^>]*>"#
      return html.replacingMatches(of: pattern, options: [.caseInsensitive]) { match in
         guard let src = self.attribute(named: "src", in: match) else { return match }
         guard self.isLocalAsset(src) else { return match }
         guard let imageURL = self.resolve(href: src, inside: siteDirectory),
               let data = try? Data(contentsOf: imageURL)
         else {
            return match
         }
         let mime = self.mimeType(for: imageURL.pathExtension.lowercased())
         let encoded = data.base64EncodedString()
         let dataURI = "data:\(mime);base64,\(encoded)"
         return match.replacing(src, with: dataURI)
      }
   }

   // MARK: - Cache-busting query strings

   /// Removes `?v=…` cache-busting suffixes that PageShell appends to theme asset URLs.
   /// After inlining the assets no URL survives, but any remaining external reference
   /// (e.g. a CDN font CSS where we kept the link tag) is cleaner without the random
   /// query string in the committed output diff.
   public static func stripCacheBustingQueryStrings(in html: String) -> String {
      html.replacingMatches(of: #"\?v=[a-f0-9]{6,16}"#, options: [.caseInsensitive]) { _ in "" }
   }

   // MARK: - Helpers

   /// Returns true when `value` looks like a `_Site/`-relative reference rather than
   /// an external URL. Treats protocol-relative `//host/...`, absolute `http(s)://`,
   /// and `data:` / `blob:` / `mailto:` schemes as external.
   public static func isLocalAsset(_ value: String) -> Bool {
      let trimmed = value.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { return false }
      if trimmed.hasPrefix("//") { return false }
      if trimmed.hasPrefix("data:") { return false }
      if trimmed.hasPrefix("blob:") { return false }
      if trimmed.hasPrefix("mailto:") { return false }
      if trimmed.hasPrefix("#") { return false }
      if let scheme = URLComponents(string: trimmed)?.scheme, !scheme.isEmpty { return false }
      return true
   }

   /// Resolves a local href like `/assets/css/syntax.css` (or `assets/foo.png`) to a
   /// concrete file URL inside `siteDirectory`. Strips any leading `/` and discards
   /// `?query` / `#fragment` before joining.
   public static func resolve(href: String, inside siteDirectory: URL) -> URL? {
      var path = href
      if let queryIndex = path.firstIndex(of: "?") { path = String(path[..<queryIndex]) }
      if let fragmentIndex = path.firstIndex(of: "#") { path = String(path[..<fragmentIndex]) }
      if path.hasPrefix("/") { path.removeFirst() }
      if path.isEmpty { return nil }
      let url = siteDirectory.appendingPathComponent(path)
      return FileManager.default.fileExists(atPath: url.path) ? url : nil
   }

   /// Extracts the value of a named attribute from a tag string. Returns nil when the
   /// attribute is absent or has no quoted value.
   public static func attribute(named name: String, in tag: String) -> String? {
      let pattern = #"\b\#(name)\s*=\s*("([^"]*)"|'([^']*)')"#
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
         return nil
      }
      let range = NSRange(tag.startIndex..., in: tag)
      guard let match = regex.firstMatch(in: tag, range: range) else { return nil }
      for groupIndex in 2...3 {
         let groupRange = match.range(at: groupIndex)
         if groupRange.location != NSNotFound, let range = Range(groupRange, in: tag) {
            return String(tag[range])
         }
      }
      return nil
   }

   private static func mimeType(for fileExtension: String) -> String {
      switch fileExtension {
      case "png": return "image/png"
      case "jpg", "jpeg": return "image/jpeg"
      case "gif": return "image/gif"
      case "webp": return "image/webp"
      case "svg": return "image/svg+xml"
      case "ico": return "image/x-icon"
      case "avif": return "image/avif"
      default: return "application/octet-stream"
      }
   }
}

extension String {
   /// Replaces every regex match with the result of `transform` applied to that match.
   /// Iterates back-to-front so earlier replacements don't shift later ranges.
   fileprivate func replacingMatches(
      of pattern: String,
      options: NSRegularExpression.Options = [],
      using transform: (String) -> String
   ) -> String {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
         return self
      }
      let nsRange = NSRange(self.startIndex..., in: self)
      let matches = regex.matches(in: self, range: nsRange)
      guard !matches.isEmpty else { return self }
      var output = self
      for match in matches.reversed() {
         guard let range = Range(match.range, in: output) else { continue }
         let original = String(output[range])
         let replacement = transform(original)
         output.replaceSubrange(range, with: replacement)
      }
      return output
   }
}
