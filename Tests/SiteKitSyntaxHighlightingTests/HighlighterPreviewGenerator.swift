import Testing
import Foundation
import SiteKit
@testable import SiteKitSyntaxHighlighting

/// Generates a self-contained HTML preview of the SwiftSyntax highlighter, for eyeballing the token
/// classification and the palette. It renders a representative SwiftUI snippet three ways: BEFORE
/// (the regex highlighter), AFTER with one DISTINCT debug color per role (proves the classification
/// independent of the palette), and AFTER with the shipped Apple/Xcode palette (light + dark, the
/// look that core `docc.css` applies).
///
/// Not an assertion test – it only writes a file, and only when `SITEKIT_HIGHLIGHTER_PREVIEW_OUT`
/// points at an output path, so a plain `swift test` stays fast. Run it with:
///
/// ```
/// SITEKIT_HIGHLIGHTER_PREVIEW_OUT=/tmp/highlighter-preview.html swift test --filter HighlighterPreview
/// ```
@Suite("HighlighterPreview")
struct HighlighterPreviewGenerator {
   /// A representative SwiftUI example exercising every role: types, a green variable reference, a
   /// parameter binding, member accesses, argument labels, a boolean, a string, a number, an
   /// attribute, an operator, and a comment.
   static let sample = """
   struct StickerList: View {
      @State private var stickers: [Sticker] = []

      var body: some View {
         ScrollView {
            LazyVStack(spacing: 12) {
               // Each row keeps its own swipe actions.
               ForEach(stickers) { sticker in
                  StickerListItemView(sticker: sticker)
                     .swipeActions(edge: .trailing) {
                        DeleteButton(title: "Delete", isDestructive: true) {
                           stickers.removeAll { $0.id == sticker.id }
                        }
                     }
               }
            }
            .swipeActionsContainer()
         }
      }
   }
   """

   @Test("generate the highlighter preview HTML")
   func generate() throws {
      guard let outPath = ProcessInfo.processInfo.environment["SITEKIT_HIGHLIGHTER_PREVIEW_OUT"] else {
         return
      }
      let before = CodeHighlighter().highlight(code: Self.sample, language: "swift")
      let after = SwiftSyntaxHighlighter().highlight(code: Self.sample, language: "swift")
      try Self.document(before: before, after: after).write(toFile: outPath, atomically: true, encoding: .utf8)
      print("HIGHLIGHTER_PREVIEW_WROTE \(outPath)")
   }

   // MARK: - HTML assembly

   private static func document(before: String, after: String) -> String {
      """
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>SiteKit SwiftSyntax highlighter preview</title>
      <style>
      \(Self.css)
      </style>
      </head>
      <body>
      <h1>SwiftSyntax Swift highlighter preview</h1>
      <p class="note">Each syntactic role is a separate <code>sk-tok-*</code> class, so the palette is a
      pure-CSS concern. Variable references (<code>stickers</code>, the <code>sticker</code> usage)
      classify as <b>variable</b> and render <span class="legend-var">green</span>. Capitalized types
      are split by a committed framework allowlist: framework types (<code>ScrollView</code>,
      <code>View</code>) stay <b>type</b> (purple), project types (<code>StickerListItemView</code>,
      <code>DeleteButton</code>, <code>Sticker</code>) become <b>projecttype</b>
      (<span class="legend-var">green</span>), as in Xcode.</p>

      <h2>1 · Classification – each role in a distinct debug color</h2>
      <p class="note">Arbitrary, deliberately-distinct colors so every role is visible; proves the
      classification, not the final look. BEFORE is the regex highlighter (capitalized = type only).</p>
      \(Self.legend)
      <div class="grid">
        <figure><figcaption>BEFORE – regex highlighter</figcaption>
          <pre class="sk-docc-highlight debug light"><code class="language-swift">\(before)</code></pre></figure>
        <figure><figcaption>AFTER – SwiftSyntax roles</figcaption>
          <pre class="sk-docc-highlight debug light"><code class="language-swift">\(after)</code></pre></figure>
      </div>

      <h2>2 · Shipped Apple/Xcode palette (call = green; alternative is call = type)</h2>
      <div class="grid">
        <figure><figcaption>AFTER – light</figcaption>
          <pre class="sk-docc-highlight palette light"><code class="language-swift">\(after)</code></pre></figure>
        <figure><figcaption>AFTER – dark</figcaption>
          <pre class="sk-docc-highlight palette dark" data-theme="dark"><code class="language-swift">\(after)</code></pre></figure>
      </div>
      </body>
      </html>
      """
   }

   private static let legend: String = {
      let roles: [(String, String)] = [
         ("keyword", "struct, var, in"), ("type", "ScrollView, View (framework)"),
         ("projecttype", "StickerListItemView (project)"), ("call", "lowercase callee"),
         ("variable", "stickers, sticker (use)"), ("member", ".swipeActions, .id"), ("param", "sticker binding"),
         ("string", "\"Delete\""), ("number", "12"), ("boolean", "true / nil"),
         ("attribute", "@State"), ("comment", "// …"), ("operator", "=="), ("label", "spacing:, edge:"),
      ]
      let items = roles.map { role, example in
         "<span class=\"chip\"><span class=\"sw sk-tok-\(role)\">\(role)</span> <small>\(example)</small></span>"
      }.joined(separator: "\n")
      return "<div class=\"legend debug light\">\(items)</div>"
   }()

   private static let css = """
   body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; color: #1d1d1f; background: #fff; }
   h1 { font-size: 1.4rem; } h2 { font-size: 1.1rem; margin-top: 2rem; }
   .note { color: #555; max-width: 70ch; line-height: 1.5; }
   .legend-var { color: #3C7D3C; font-weight: 700; }
   .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; align-items: start; }
   @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
   figure { margin: 0; } figcaption { font-size: .8rem; color: #666; margin-bottom: .3rem; }
   pre { margin: 0; padding: 1rem 1.2rem; border-radius: 10px; overflow-x: auto;
         font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace; font-size: 13px; line-height: 1.6; }
   pre code { display: block; background: none; border: 0; padding: 0; }
   .light { background: #f5f5f7; color: #1d1d1f; border: 1px solid #e2e2e6; }
   .dark { background: #1f1f24; color: #e6e6ea; border: 1px solid #34343a; }
   .legend { display: flex; flex-wrap: wrap; gap: .5rem; padding: .8rem; border-radius: 10px; margin: .6rem 0 1rem; }
   .chip { display: inline-flex; align-items: center; gap: .3rem; background: #fff; border: 1px solid #e2e2e6; border-radius: 6px; padding: .15rem .45rem; }
   .chip .sw { font-family: ui-monospace, monospace; font-weight: 700; font-size: 12px; }
   .chip small { color: #777; }

   /* Panel 1 – distinct debug colors (one per role). */
   .debug .sk-tok-keyword     { color: #C026D3; font-weight: 700; }
   .debug .sk-tok-type        { color: #2563EB; }
   .debug .sk-tok-projecttype { color: #059669; font-weight: 600; }
   .debug .sk-tok-call        { color: #EA580C; }
   .debug .sk-tok-variable    { color: #16A34A; font-weight: 600; }
   .debug .sk-tok-member    { color: #0D9488; }
   .debug .sk-tok-param     { color: #CA8A04; }
   .debug .sk-tok-string    { color: #DC2626; }
   .debug .sk-tok-number    { color: #7C3AED; }
   .debug .sk-tok-boolean   { color: #DB2777; }
   .debug .sk-tok-attribute { color: #65A30D; }
   .debug .sk-tok-comment   { color: #6B7280; font-style: italic; }
   .debug .sk-tok-operator  { color: #0891B2; }
   .debug .sk-tok-label     { color: #9333EA; }

   /* Panel 2 – the Apple/Xcode palette that core docc.css ships. call = green. */
   .palette.light .sk-tok-keyword     { color: #AD3DA4; font-weight: 600; }
   .palette.light .sk-tok-type        { color: #703DAA; }
   .palette.light .sk-tok-projecttype { color: #3C7D3C; }
   .palette.light .sk-tok-call        { color: #3C7D3C; }
   .palette.light .sk-tok-variable    { color: #3C7D3C; }
   .palette.light .sk-tok-string    { color: #D12F1B; }
   .palette.light .sk-tok-number    { color: #272AD8; }
   .palette.light .sk-tok-boolean   { color: #AD3DA4; }
   .palette.light .sk-tok-attribute { color: #947100; }
   .palette.light .sk-tok-comment   { color: #707F8C; font-style: italic; }
   /* member / param / operator / label inherit the default text color. */

   .palette.dark .sk-tok-keyword     { color: #FF7AB2; font-weight: 600; }
   .palette.dark .sk-tok-type        { color: #DABAFF; }
   .palette.dark .sk-tok-projecttype { color: #7FD98A; }
   .palette.dark .sk-tok-call        { color: #7FD98A; }
   .palette.dark .sk-tok-variable    { color: #7FD98A; }
   .palette.dark .sk-tok-string    { color: #FF8170; }
   .palette.dark .sk-tok-number    { color: #D9C97C; }
   .palette.dark .sk-tok-boolean   { color: #FF7AB2; }
   .palette.dark .sk-tok-attribute { color: #CC9768; }
   .palette.dark .sk-tok-comment   { color: #7F8C98; font-style: italic; }
   """
}
