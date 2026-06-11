import Foundation
import Logging

// URLSession lives in `FoundationNetworking` on Linux (swift-corelibs-foundation). On Darwin
// it's part of the umbrella Foundation module. Without this import, CI Linux builds fail
// with "URLSessionConfiguration (aka AnyObject) has no member 'ephemeral'" because the
// typed interface isn't exposed from the base Foundation module on Linux.
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Post-processor that inlines Font Awesome icons as `<svg>` elements.
///
/// ### Why
///
/// Loading Font Awesome from CDN costs ~90 KB of CSS + ~200–500 KB of webfont data for
/// ~1,700 icons, even when a site only uses 10–15. Inlining the SVGs actually referenced
/// in the generated HTML avoids that entire payload.
///
/// ### How it works
///
/// 1. Walks all `.html` files under `outputDirectory`.
/// 2. Finds every `<i class="fa-solid fa-user">…</i>` reference (also accepts legacy
///    `fas`/`far`/`fab` aliases and `fa-regular`/`fa-brands`).
/// 3. For each unique `(family, name)` pair, resolves the SVG:
///    - Checks the local cache: `<projectDirectory>/.sitekit-cache/fa-icons/<family>-<name>.svg`
///    - If missing, fetches from `cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@<version>/svgs/<family>/<name>.svg`
///      and writes to cache. Subsequent builds are fully offline.
/// 4. Substitutes each `<i>` element with the inline SVG (preserving any extra classes).
/// 5. When every FA icon on a page has been inlined AND the theme JavaScript does not
///    reference `fa-*` (heuristic for runtime FA usage), strips the Font Awesome `<link>`
///    tag too – freeing the browser from loading a now-unused stylesheet.
///
/// ### Cache location
///
/// The SVG cache lives at `<project>/.sitekit-cache/fa-icons/`. Small (~10–30 KB for a
/// typical site). Gitignore or commit – both work. Committing makes CI fully offline.
///
/// ### Opt-out
///
/// Set `inlineFontAwesome: false` in `theme.yaml` to restore CDN-only behavior (useful
/// when a site adds FA icons dynamically via JavaScript in unusual ways, or during
/// rapid icon experimentation if the cache-fetch overhead becomes annoying).
///
/// ### License
///
/// Font Awesome Free is distributed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
/// (icons – the SVGs this processor embeds) + [SIL Open Font License 1.1](https://scripts.sil.org/OFL)
/// (fonts) + [MIT](https://opensource.org/licenses/MIT) (code, including CSS); brand icons are
/// additionally trademark-restricted. Self-hosting / inlining is explicitly permitted, and the
/// attribution comment embedded in every fetched SVG survives inlining, which satisfies CC BY.
public struct FontAwesomeInliner: OutputProcessor {
   public static let defaultVersion = "6.7.2"

   /// Font Awesome version pin. Must match the CDN version the theme references, to avoid
   /// visual drift if FA updates an icon between versions.
   public let version: String

   /// HTTP fetch timeout for the initial SVG download (per icon).
   public let fetchTimeout: TimeInterval

   public init(version: String = FontAwesomeInliner.defaultVersion, fetchTimeout: TimeInterval = 10) {
      self.version = version
      self.fetchTimeout = fetchTimeout
   }

   public func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws {
      guard themeConfig?.inlineFontAwesome != false else { return }

      let logger = Logger(label: "SiteKit.FontAwesomeInliner")

      // Decision: if theme JavaScript references `fa-*`, FA icons are added dynamically at
      // runtime and we CANNOT safely strip the FA stylesheet. In that case, inlining static
      // icons is also wrong – we'd render each icon twice (once via our inline SVG, once via
      // FA's ::before pseudo-element). So we do nothing: the FA stylesheet stays, icons
      // render as before. This is the reliable behavior. No half-way state.
      if Self.hasDynamicFAUsage(outputDirectory: outputDirectory, themeConfig: themeConfig) {
         logger.info("Font Awesome icons used dynamically in theme JS – keeping FA stylesheet, not inlining.")
         return
      }

      let cacheDir = projectDirectory.appendingPathComponent(".sitekit-cache/fa-icons")
      try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

      var inlinedIcons: Set<String> = []
      var failedIcons: Set<String> = []
      var filesModified = 0
      var svgResolver = SVGResolver(cacheDir: cacheDir, version: self.version, fetchTimeout: self.fetchTimeout, logger: logger)

      // Walk output directory for .html files
      guard let enumerator = FileManager.default.enumerator(
         at: outputDirectory,
         includingPropertiesForKeys: [.isRegularFileKey]
      ) else {
         return
      }

      for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "html" {
         var html = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
         guard html.contains("fa-") else { continue }

         let originalHTML = html
         let result = Self.inline(
            html: html,
            svgResolver: &svgResolver,
            inlinedIcons: &inlinedIcons,
            failedIcons: &failedIcons
         )
         html = result.html

         // Strip FA CSS link when every icon on this page was successfully inlined.
         // (We already bailed out above if any dynamic usage was detected.)
         if result.allInlined && result.replacementCount > 0 {
            html = Self.stripFontAwesomeLinks(from: html)
            // Also strip any preconnect to hosts whose only listed use was serving the
            // FA stylesheet (e.g. `cdnjs.cloudflare.com` when no other CDN CSS remains).
            // Lighthouse flags these as "unused preconnect" and they waste a TCP+TLS
            // handshake per pageview.
            html = Self.stripUnusedFAPreconnects(from: html)
         }

         if html != originalHTML {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            filesModified += 1
         }
      }

      if !inlinedIcons.isEmpty {
         logger.info(
            "Inlined \(inlinedIcons.count) unique Font Awesome icon(s) across \(filesModified) page(s): \(inlinedIcons.sorted().joined(separator: ", "))"
         )
      }
      if !failedIcons.isEmpty {
         logger.warning(
            "Could not inline \(failedIcons.count) Font Awesome icon(s) – kept as <i> (CDN fallback still works): \(failedIcons.sorted().joined(separator: ", "))"
         )
      }
   }

   /// Scans theme JS files for `fa-` usage – a rough but effective heuristic for runtime
   /// icon injection. We'd rather keep the CSS link and waste bandwidth than strip it and
   /// silently break dynamically-added icons.
   private static func hasDynamicFAUsage(outputDirectory: URL, themeConfig: ThemeConfig?) -> Bool {
      guard let themeConfig else { return false }
      for jsFile in themeConfig.js {
         let path = outputDirectory
            .appendingPathComponent("assets")
            .appendingPathComponent("theme")
            .appendingPathComponent(jsFile)
         guard let content = try? String(contentsOf: path, encoding: .utf8) else { continue }
         if content.range(of: #"['"]fa-(solid|regular|brands|light|thin|duotone|sharp)"#, options: .regularExpression) != nil
            || content.range(of: #"['"]fa[sbr]\s+fa-"#, options: .regularExpression) != nil
         {
            return true
         }
      }
      return false
   }

   private struct InlineResult {
      var html: String
      var replacementCount: Int
      var allInlined: Bool
   }

   /// Scans `html` for `<i class="…fa-solid fa-user">…</i>` references and replaces each
   /// with the same `<i>` wrapping an inline `<svg>` of the corresponding icon.
   private static func inline(
      html: String,
      svgResolver: inout SVGResolver,
      inlinedIcons: inout Set<String>,
      failedIcons: inout Set<String>
   ) -> InlineResult {
      // Regex literal: `<i class="…"></i>`, with `.output.1` = class list.
      let iTagRegex = #/<i\s+class="([^"]+)"([^>]*)>\s*</i>/#

      var replacementCount = 0
      var allInlined = true

      // Build result forward by stitching [prefix, replacement, …, suffix]. Simpler than
      // mutating in place and avoids any String.Index validity concerns across splices.
      var rebuilt = ""
      rebuilt.reserveCapacity(html.count)
      var cursor = html.startIndex

      for match in html.matches(of: iTagRegex) {
         rebuilt.append(contentsOf: html[cursor..<match.range.lowerBound])
         cursor = match.range.upperBound

         let originalMatch = String(match.output.0)
         let classString = String(match.output.1)

         let (family, iconName) = Self.parseFaClasses(classString)
         guard let family, let iconName else {
            allInlined = false
            rebuilt.append(originalMatch)
            continue
         }

         let key = "\(family):\(iconName)"
         guard let svgMarkup = svgResolver.svg(family: family, name: iconName) else {
            failedIcons.insert(key)
            allInlined = false
            rebuilt.append(originalMatch)
            continue
         }

         inlinedIcons.insert(key)

         // Wrap the SVG INSIDE the original <i> rather than replacing it – this way every
         // existing theme CSS rule targeting `<i>` (e.g. `.podcast-subscribe-link i { font-size: 0.8rem }`)
         // keeps matching and keeps sizing/coloring the icon correctly. The inner SVG fills
         // the <i>'s box and inherits currentColor via the `.fa-icon` rules in base.css.
         //
         // The `data-fa-inlined="svg"` marker lets base.css neutralize any `::before` glyph
         // (belt-and-braces if the FA stylesheet ever loads from cache / an extension).
         let svgInner = Self.injectAttributes(intoSVG: svgMarkup, classList: "fa-icon")
         rebuilt.append(#"<i class="\#(classString)" data-fa-inlined="svg" aria-hidden="true">\#(svgInner)</i>"#)
         replacementCount += 1
      }
      rebuilt.append(contentsOf: html[cursor..<html.endIndex])

      return InlineResult(html: rebuilt, replacementCount: replacementCount, allInlined: allInlined)
   }

   /// Pulls the `(family, iconName)` pair out of a Font Awesome class list, accepting
   /// both modern (`fa-solid`, `fa-regular`, `fa-brands`) and legacy (`fas`, `far`, `fab`)
   /// family aliases. Size/rotation modifiers like `fa-xl`, `fa-2x`, `fa-rotate-90` are
   /// ignored – the first `fa-<name>` class that isn't a family alias wins as the icon.
   private static func parseFaClasses(_ classList: String) -> (family: String?, iconName: String?) {
      var family: String?
      var iconName: String?
      for cls in classList.split(whereSeparator: \.isWhitespace) {
         switch cls {
         case "fa-solid", "fas": family = "solid"
         case "fa-regular", "far": family = "regular"
         case "fa-brands", "fab": family = "brands"
         default:
            if cls.hasPrefix("fa-"), iconName == nil {
               iconName = String(cls.dropFirst(3))
            }
         }
      }
      return (family, iconName)
   }

   /// Normalizes a raw Font Awesome SVG for embedding as a child of `<i class="fa-…">`:
   /// drops inline size/fill/class/aria attributes (we set our own), preserves `viewBox`
   /// and `xmlns`, and injects `fill="currentColor"` on the root `<svg>` so every
   /// descendant `<path>` without its own fill inherits the parent text color.
   private static func injectAttributes(intoSVG svg: String, classList: String) -> String {
      var trimmed = svg.trimmingCharacters(in: .whitespacesAndNewlines)
      // Strip XML declaration if present.
      if trimmed.hasPrefix("<?xml"), let end = trimmed.range(of: "?>") {
         trimmed = String(trimmed[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
      }
      guard trimmed.hasPrefix("<svg"), let gt = trimmed.range(of: ">") else { return trimmed }

      let openingTag = String(trimmed[trimmed.startIndex..<gt.upperBound])
      let rest = String(trimmed[gt.upperBound...])

      // Drop any existing size/fill/class/aria attributes on the opening <svg> tag so
      // ours win uncontested.
      var strippedOpeningTag = openingTag
         .replacing(#/ (?:height|width|fill|aria-hidden|class)="[^"]*"/#, with: "")

      // Insert our attributes immediately after `<svg`.
      let insertionIndex = strippedOpeningTag.index(strippedOpeningTag.startIndex, offsetBy: 4)
      strippedOpeningTag.insert(
         contentsOf: #" class="\#(classList)" fill="currentColor" aria-hidden="true""#,
         at: insertionIndex
      )
      return strippedOpeningTag + rest
   }

   /// Removes Font Awesome `<link rel="stylesheet">` tags (and their `<noscript>` fallback)
   /// from the HTML. Used when every icon has been inlined and no dynamic usage is detected.
   private static func stripFontAwesomeLinks(from html: String) -> String {
      html
         .replacing(#/<link[^>]*font(?:-)?awesome[^>]*>/#, with: "")
         .replacing(#/<noscript>\s*<link[^>]*font(?:-)?awesome[^>]*>\s*</noscript>/#, with: "")
   }

   /// Removes `<link rel="preconnect">` tags whose host is no longer referenced by any
   /// remaining `<link rel="stylesheet">` or `<script src>` on the page. Run after
   /// `stripFontAwesomeLinks` so the FA stylesheet is already gone.
   ///
   /// Narrow by design – only considers preconnects, only checks stylesheet/script uses.
   /// If a theme template references the host from `<img src>` or inline JS, the
   /// preconnect stays. False negatives (keeping a truly unused preconnect) are fine;
   /// false positives (stripping a still-needed one) would regress LCP.
   private static func stripUnusedFAPreconnects(from html: String) -> String {
      var result = html
      let preconnectPattern = #/<link\s+rel="preconnect"\s+href="(https?:\/\/[^"\/]+)[^"]*"[^>]*>/#
      for match in html.matches(of: preconnectPattern) {
         let originalTag = String(match.output.0)
         let host = String(match.output.1)
         // Count total occurrences of the host in the HTML. If it appears only once,
         // that occurrence IS the preconnect we're considering – nothing else links
         // to it, so the preconnect is safe to strip.
         let totalOccurrences = result.components(separatedBy: host).count - 1
         if totalOccurrences <= 1 {
            result = result.replacing(originalTag, with: "")
         }
      }
      return result
   }
}

/// Resolves `(family, name)` → SVG markup. Checks the local cache first; on miss, fetches
/// from jsdelivr's Font Awesome Free mirror and writes to cache.
private struct SVGResolver {
   let cacheDir: URL
   let version: String
   let fetchTimeout: TimeInterval
   let logger: Logger

   /// Cached SVG strings keyed by "family:name", so each unique icon is fetched once per build.
   private var memo: [String: String?] = [:]

   init(cacheDir: URL, version: String, fetchTimeout: TimeInterval, logger: Logger) {
      self.cacheDir = cacheDir
      self.version = version
      self.fetchTimeout = fetchTimeout
      self.logger = logger
   }

   mutating func svg(family: String, name: String) -> String? {
      let key = "\(family):\(name)"
      if let cached = memo[key] {
         return cached
      }
      let value = self.resolve(family: family, name: name)
      memo[key] = value
      return value
   }

   private func resolve(family: String, name: String) -> String? {
      let cacheFile = self.cacheDir.appendingPathComponent("\(family)-\(name).svg")
      if FileManager.default.fileExists(atPath: cacheFile.path),
         let cached = try? String(contentsOf: cacheFile, encoding: .utf8),
         cached.hasPrefix("<svg") || cached.contains("<svg ")
      {
         return cached
      }

      // Fetch from jsdelivr (Font Awesome Free mirror)
      guard let url = URL(string: "https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@\(self.version)/svgs/\(family)/\(name).svg") else {
         return nil
      }

      // Box the result so we can mutate it from the completion handler without tripping
      // Swift 6's strict Sendable checking. The semaphore gates access – no races in practice.
      final class Box: @unchecked Sendable { var value: String? }
      let box = Box()
      let semaphore = DispatchSemaphore(value: 0)
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = self.fetchTimeout
      let session = URLSession(configuration: config)
      let task = session.dataTask(with: url) { data, response, _ in
         defer { semaphore.signal() }
         guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200,
            let data,
            let text = String(data: data, encoding: .utf8),
            text.contains("<svg")
         else { return }
         box.value = text
      }
      task.resume()
      semaphore.wait()
      let result = box.value

      if let svg = result {
         try? svg.write(to: cacheFile, atomically: true, encoding: .utf8)
      } else {
         logger.warning("Failed to fetch FA icon \(family)/\(name).svg from \(url.absoluteString)")
      }
      return result
   }
}
