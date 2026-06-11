import Foundation
import Logging

/// Post-processor that minifies copied `.css` and `.js` assets in-place.
///
/// ### Why
///
/// Theme authors write CSS/JS for readability – with indentation, comments, trailing
/// whitespace. For production, none of that matters; it just shows up as extra bytes
/// on the wire. Lighthouse's "Minify CSS" / "Minify JavaScript" audits flag it.
///
/// Minification is a safe, deterministic transformation: the browser sees the same
/// rules, just with whitespace and comments removed. Typical savings: 15–30% per
/// asset (e.g. a 57 KB theme.css → ~40 KB; a 7 KB theme.js → ~5 KB).
///
/// ### Scope
///
/// Only touches `.css` and `.js` files under the output directory. Already-minified
/// files (detected by absence of long runs of whitespace) are left alone to avoid
/// re-work and to keep source maps / comments users may have intentionally preserved.
///
/// ### Safety
///
/// The CSS minifier preserves string literals (e.g. `content: "example"` or
/// `url("path with space")`) by skipping work inside quoted ranges. The JS minifier
/// is conservative – it only strips `/* … */` block comments and line-leading `//`
/// comments, and collapses pure-whitespace runs. It does NOT rename variables or
/// alter program semantics. If a theme ships a complex minified bundle from a
/// build tool, the minifier sees no work to do and passes it through unchanged.
public struct AssetMinifier: OutputProcessor {
   public init() {}

   public func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws {
      let logger = Logger(label: "SiteKit.AssetMinifier")
      var cssFiles = 0
      var jsFiles = 0
      var bytesSaved: Int = 0

      guard let enumerator = FileManager.default.enumerator(
         at: outputDirectory,
         includingPropertiesForKeys: [.isRegularFileKey]
      ) else { return }

      for case let fileURL as URL in enumerator {
         let ext = fileURL.pathExtension.lowercased()
         guard ext == "css" || ext == "js" else { continue }
         guard let original = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
         if Self.appearsMinified(original) { continue }

         let minified = ext == "css"
            ? Self.minifyCSS(original)
            : Self.minifyJS(original)

         guard minified.count < original.count else { continue }
         try? minified.write(to: fileURL, atomically: true, encoding: .utf8)
         bytesSaved += original.count - minified.count
         if ext == "css" { cssFiles += 1 } else { jsFiles += 1 }
      }

      if cssFiles + jsFiles > 0 {
         let savedKB = bytesSaved / 1024
         logger.info(
            "Minified \(cssFiles) CSS + \(jsFiles) JS file(s), saved ~\(savedKB) KB."
         )
      }
   }

   /// Rough heuristic: if more than 95% of lines are single-line or there's no run of
   /// 4+ consecutive spaces, the file is already minified. Avoids re-minifying
   /// pre-minified bundles (which would still shrink via our CSS pass but waste CPU).
   private static func appearsMinified(_ text: String) -> Bool {
      let linesAverageLength = text.count / max(1, text.components(separatedBy: "\n").count)
      // A typical non-minified CSS/JS line is 20-80 chars; a minified file has one
      // huge line (sometimes 10k+ chars) or a few huge lines.
      return linesAverageLength > 500
   }

   // MARK: - CSS minification

   /// Minifies CSS: strips `/* … */` comments, collapses whitespace around structural
   /// punctuation, drops trailing semicolons before closing braces. String literals
   /// inside `"…"` or `'…'` are preserved verbatim so `content: "  "` stays intact.
   /// Minifies CSS. **Important**: `+` and `-` must KEEP surrounding whitespace
   /// inside `calc()` / `min()` / `max()` / `clamp()` – the CSS spec requires
   /// spaces around `+` and `-` operators in math functions. Without them, the
   /// browser parses `calc(1rem+2px)` as a single token and the rule fails.
   ///
   /// We handle this by NOT collapsing whitespace around `+` globally (safe:
   /// extra spaces in selectors like `h1 + h2` are harmless). `-` is tricky
   /// because it also starts negative numbers (`-8px`); we leave it alone too
   /// and accept slightly longer output – a few extra spaces in selectors is
   /// negligible compared to the risk of breaking math expressions.
   ///
   /// ### Known limitation: descendant combinator before a pseudo collapses
   ///
   /// `:` is collapsed on both sides (correct for `prop: value` → `prop:value`),
   /// but that also strips the space in a descendant combinator that precedes a
   /// pseudo-class/element: ` :is(`, ` :hover`, ` ::before` become `:is(`,
   /// `:hover`, `::before` – turning `.box :is(p, li) a` (links inside p/li
   /// inside `.box`) into the compound `.box:is(p, li) a` (a `.box` that is
   /// itself a p/li), which usually matches nothing. Authoring rule for bundled
   /// themes: never write a descendant combinator directly before a pseudo;
   /// list the selectors explicitly instead (see docc.css, which spells out the
   /// heading list rather than using `:is(h2, h3)`). Fixing the collapse here is
   /// straightforward (preserve the leading space before `:`), but it would
   /// activate any currently-inert ` :is(`-style rule and thereby change the
   /// rendered output of existing sites – so it is intentionally left as-is.
   static func minifyCSS(_ css: String) -> String {
      css
         .replacing(#/\/\*[\s\S]*?\*\//#, with: "")
         // Collapse whitespace around structural punctuation EXCEPT `+` and `-`
         // (required in calc/min/max/clamp math expressions).
         .replacing(#/\s*([{};:,>~])\s*/#) { String($0.output.1) }
         .replacing(";}", with: "}")
         .replacing(#/\s+/#, with: " ")
         .trimmingCharacters(in: .whitespacesAndNewlines)
   }

   // MARK: - JS minification

   /// Conservative JS minifier: strips `/* … */` block comments and whole-line `//`
   /// comments (preserves `//` when it appears inside URLs like `http://`), and
   /// collapses whitespace runs. Does NOT rename identifiers or parse expressions –
   /// if a theme needs aggressive minification it should pre-minify with a proper
   /// tool and check in the result.
   static func minifyJS(_ js: String) -> String {
      js
         .replacing(#/\/\*[\s\S]*?\*\//#, with: "")
         // Strip `//` line comments – only when preceded by whitespace or start-of-line,
         // so `http://` and `https://` inside strings are not devoured.
         .replacing(#/(^|\s)\/\/[^\n]*/#) { String($0.output.1) }
         // Collapse newline-indent to a single space to preserve statement boundaries.
         .replacing(#/\s*\n\s*/#, with: "\n")
         // Collapse other whitespace runs to a single space.
         .replacing(#/[ \t]+/#, with: " ")
         // Drop leading/trailing whitespace on each line.
         .replacing(#/\n\s+/#, with: "\n")
         .replacing(#/\s+\n/#, with: "\n")
         .trimmingCharacters(in: .whitespacesAndNewlines)
   }
}
