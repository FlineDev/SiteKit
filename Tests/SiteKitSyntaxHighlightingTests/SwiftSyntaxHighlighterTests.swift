import Testing
import SiteKit
@testable import SiteKitSyntaxHighlighting

@Suite("SwiftSyntaxHighlighter")
struct SwiftSyntaxHighlighterTests {

   private let highlighter = SwiftSyntaxHighlighter()

   /// Convenience: assert that `text` is wrapped in exactly the `sk-tok-<role>` span.
   private func expectSpan(_ html: String, role: String, text: String, sourceLocation: SourceLocation = #_sourceLocation) {
      #expect(html.contains("<span class=\"sk-tok-\(role)\">\(text)</span>"), "expected \(text) as sk-tok-\(role)", sourceLocation: sourceLocation)
   }

   // MARK: - Role classification (the semantic-near roles the regex highlighter cannot produce)

   @Test("A value reference is classified variable (the green-variables headline)")
   func variableReferenceIsGreen() {
      // `stickers` is a DeclReferenceExpr that is neither a callee nor a member base, so it must be
      // classified `variable` (rendered green) – the headline requirement of this whole change.
      let code = "ForEach(stickers) { sticker in row(sticker) }"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "variable", text: "stickers")
   }

   @Test("A capitalized callee is classified type (one class for all type refs)")
   func capitalizedCalleeIsType() {
      let code = "ScrollView { Text(title) }"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "type", text: "ScrollView")
      self.expectSpan(result, role: "type", text: "Text")
   }

   @Test("A lowercase free-function callee is classified call")
   func lowercaseCalleeIsCall() {
      let code = "print(message)"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "call", text: "print")
   }

   @Test("A member access name is classified member")
   func memberAccessIsMember() {
      let code = "view.swipeActions(edge: .trailing) { }"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "member", text: "swipeActions")
      self.expectSpan(result, role: "member", text: "trailing")
   }

   @Test("A closure parameter binding is classified param")
   func closureParameterIsParam() {
      // The binding `sticker` (declaration) is `param`; its later use is `variable`. Both occur, at
      // different offsets, so the same name carries two roles depending on position.
      let code = "ForEach(stickers) { sticker in StickerRow(sticker) }"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "param", text: "sticker")
      self.expectSpan(result, role: "variable", text: "sticker")
   }

   @Test("Boolean and nil literals are classified boolean")
   func booleanAndNilAreBoolean() {
      let code = "let flag = true\nlet value = nil"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "boolean", text: "true")
      self.expectSpan(result, role: "boolean", text: "nil")
   }

   @Test("An argument label is classified label")
   func argumentLabelIsLabel() {
      let code = "LazyVStack(spacing: 12) { }"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "label", text: "spacing")
   }

   @Test("A let-binding name is classified variable")
   func letBindingIsVariable() {
      let code = "let count = 3"
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "variable", text: "count")
   }

   // MARK: - Roles taken straight from the base SwiftIDEUtils classification

   @Test("Keywords, strings, numbers, comments, and attributes use the base classification")
   func baseClassificationRoles() {
      let code = """
      // a leading comment
      @State private var amount = 42
      let label = "hello"
      """
      let result = self.highlighter.highlight(code: code, language: "swift")
      self.expectSpan(result, role: "keyword", text: "var")
      self.expectSpan(result, role: "keyword", text: "let")
      self.expectSpan(result, role: "number", text: "42")
      self.expectSpan(result, role: "string", text: "&quot;hello&quot;")
      self.expectSpan(result, role: "comment", text: "// a leading comment")
      self.expectSpan(result, role: "attribute", text: "@State")
   }

   // MARK: - Fragment tolerance

   @Test("A partial fragment (no enclosing type) is classified without crashing")
   func fragmentToleranceDegradesGracefully() {
      // DocC code blocks are routinely partial – a bare statement list, an elided body. SwiftParser
      // is error-tolerant and still yields a tree, so classification must produce best-effort roles
      // (here the green variable) rather than throwing or returning empty.
      let code = "ForEach(stickers) { sticker in\n   StickerListItemView(sticker)\n      .swipeActions"
      let result = self.highlighter.highlight(code: code, language: "swift")
      #expect(!result.isEmpty)
      self.expectSpan(result, role: "variable", text: "stickers")
      self.expectSpan(result, role: "type", text: "StickerListItemView")
   }

   @Test("Empty input returns empty output")
   func emptyInput() {
      #expect(self.highlighter.highlight(code: "", language: "swift") == "")
   }

   // MARK: - HTML escaping safety

   @Test("Angle brackets and ampersands are escaped exactly once")
   func htmlEscaping() {
      let code = "let a: Array<Int> = []\nlet b = x && y"
      let result = self.highlighter.highlight(code: code, language: "swift")
      #expect(result.contains("&lt;"))
      #expect(result.contains("&gt;"))
      #expect(result.contains("&amp;"))
      #expect(!result.contains("&amp;amp;"))
      #expect(!result.contains("&amp;lt;"))
   }

   @Test("Reproduces the full source text once spans are stripped")
   func reproducesSourceExactly() {
      // No byte of the source may be dropped or duplicated: stripping every span tag and unescaping
      // must return the original code verbatim (the gap-fill emits untouched regions as plain text).
      let code = "struct S {\n   var n = 1 // note\n   func f() { print(n) }\n}"
      let result = self.highlighter.highlight(code: code, language: "swift")
      let stripped = result
         .replacing(try! Regex("<span class=\"sk-tok-[a-z]+\">"), with: "")
         .replacing("</span>", with: "")
      #expect(HTMLEscaping.unescape(stripped) == code)
   }

   // MARK: - Non-Swift fallback

   @Test("Non-Swift languages delegate to the regex fallback")
   func nonSwiftDelegatesToFallback() {
      let code = "def greet():\n    return None"
      let viaSyntax = self.highlighter.highlight(code: code, language: "python")
      let viaRegex = CodeHighlighter().highlight(code: code, language: "python")
      #expect(viaSyntax == viaRegex)
   }

   @Test("A nil language delegates to the fallback (plain escaped text)")
   func nilLanguageDelegatesToFallback() {
      let code = "let x = 1"
      let viaSyntax = self.highlighter.highlight(code: code, language: nil)
      let viaRegex = CodeHighlighter().highlight(code: code, language: nil)
      #expect(viaSyntax == viaRegex)
      #expect(!viaSyntax.contains("<span"))
   }

   // MARK: - applyToBodyHTML integration (the DocC entry point, via the shared protocol plumbing)

   @Test("applyToBodyHTML highlights a Swift block with semantic roles")
   func applyToBodyHTMLHighlightsRoles() {
      let html = "<pre><code class=\"language-swift\">ForEach(stickers) { s in row(s) }</code></pre>"
      let result = self.highlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("sk-docc-highlight"))
      self.expectSpan(result, role: "variable", text: "stickers")
   }

   @Test("applyToBodyHTML keeps a // inside a pre-escaped string out of comments")
   func applyToBodyHTMLStringWithSlashes() {
      // DocC hands already-escaped content; the parser must treat the URL's // as part of the string.
      let html = "<pre><code class=\"language-swift\">let u = &quot;https://x&quot;</code></pre>"
      let result = self.highlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("sk-tok-string"))
      #expect(!result.contains("sk-tok-comment"))
   }
}
