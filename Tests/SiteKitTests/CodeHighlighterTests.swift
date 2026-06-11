import Testing
@testable import SiteKit

@Suite("CodeHighlighter")
struct CodeHighlighterTests {

   // MARK: - HTML escaping

   @Test("HTML-escapes special characters in the output")
   func htmlEscaping() {
      // Code containing < > & must be escaped in the output so the HTML is safe.
      let code = "let x = a & b"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      // The & must appear HTML-escaped in the output.
      #expect(result.contains("&amp;"))
      // The raw & must not appear unescaped.
      #expect(!result.contains(" & "))
   }

   @Test("Angle brackets in type parameters are HTML-escaped per-token")
   func angleEscaping() {
      // Array<Int> in Swift: < and > must appear as &lt; and &gt; somewhere.
      let code = "var x: Array<Int> = []"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("&lt;"))
      #expect(result.contains("&gt;"))
   }

   @Test("Plain text output for nil language does not contain span tags")
   func nilLanguagePlainOutput() {
      let code = "hello world"
      let result = CodeHighlighter.highlight(code: code, language: nil)
      #expect(!result.contains("<span"))
      #expect(result == CodeHighlighter.escapeHTML(code))
   }

   @Test("Empty language string degrades to plain escaped text")
   func emptyLanguagePlainOutput() {
      let code = "let x = 1"
      let result = CodeHighlighter.highlight(code: code, language: "")
      #expect(!result.contains("<span"))
      #expect(result == CodeHighlighter.escapeHTML(code))
   }

   // MARK: - Swift highlighting

   @Test("Swift keywords are wrapped in sk-tok-keyword spans")
   func swiftKeywords() {
      let code = "func greet(name: String) -> String { return name }"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-keyword\">func</span>"))
      #expect(result.contains("<span class=\"sk-tok-keyword\">return</span>"))
   }

   @Test("Swift string literals are wrapped in sk-tok-string spans")
   func swiftStrings() {
      let code = #"let s = "hello""#
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("sk-tok-string"))
      #expect(result.contains("&quot;hello&quot;"))
   }

   @Test("Swift line comments are wrapped in sk-tok-comment spans")
   func swiftLineComments() {
      let code = "// This is a comment\nlet x = 1"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-comment\">// This is a comment</span>"))
   }

   @Test("Swift block comments are wrapped in sk-tok-comment spans")
   func swiftBlockComments() {
      let code = "/* block */ let x = 1"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-comment\">/* block */</span>"))
   }

   @Test("Swift numeric literals are wrapped in sk-tok-number spans")
   func swiftNumbers() {
      let code = "let n = 42"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-number\">42</span>"))
   }

   @Test("Swift type names (Capitalized identifiers) are wrapped in sk-tok-type spans")
   func swiftTypeNames() {
      let code = "var items: [String] = []"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-type\">String</span>"))
   }

   @Test("Swift attributes are wrapped in sk-tok-attribute spans")
   func swiftAttributes() {
      let code = "@MainActor func update() {}"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      #expect(result.contains("<span class=\"sk-tok-attribute\">@MainActor</span>"))
   }

   @Test("Swift code does not double-escape HTML entities inside highlighted spans")
   func swiftNoDoubleEscape() {
      // Ampersands in code must appear as &amp; exactly once, not &amp;amp;
      let code = "let x: Bool = (a && b)"
      let result = CodeHighlighter.highlight(code: code, language: "swift")
      // && becomes &amp;&amp; – check one &amp; but not &amp;amp;
      #expect(result.contains("&amp;"))
      #expect(!result.contains("&amp;amp;"))
   }

   // MARK: - Generic fallback

   @Test("Unknown language gets basic coloring for comments and strings")
   func unknownLanguageFallback() {
      let code = "// comment\nlet x = \"value\""
      let result = CodeHighlighter.highlight(code: code, language: "cobol")
      // Comments and strings should still get colored.
      #expect(result.contains("sk-tok-comment"))
      #expect(result.contains("sk-tok-string"))
   }

   @Test("Python keywords are highlighted with generic rules")
   func pythonKeywords() {
      let code = "def hello():\n    return None"
      let result = CodeHighlighter.highlight(code: code, language: "python")
      #expect(result.contains("sk-tok-keyword"))
      // At least one keyword span must enclose a known Python keyword.
      let hasKeyword = result.contains(">def</span>")
         || result.contains(">return</span>")
         || result.contains(">None</span>")
      #expect(hasKeyword)
   }

   // MARK: - applyToBodyHTML

   @Test("applyToBodyHTML highlights a tagged Swift code block")
   func applyToBodyHTMLTagged() {
      let html = "<pre><code class=\"language-swift\">func foo() {}</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("sk-docc-highlight"))
      #expect(result.contains("sk-tok-keyword"))
   }

   @Test("applyToBodyHTML uses defaultLanguage for an untagged code block")
   func applyToBodyHTMLDefault() {
      let html = "<pre><code>func bar() {}</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: "swift")
      #expect(result.contains("sk-docc-highlight"))
      #expect(result.contains("sk-tok-keyword"))
   }

   @Test("applyToBodyHTML leaves an untagged block plain when no default language is set")
   func applyToBodyHTMLNoDefault() {
      let html = "<pre><code>just plain text</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      // Still gets the sk-docc-highlight class on the <pre>.
      #expect(result.contains("sk-docc-highlight"))
      // But no token spans should appear.
      #expect(!result.contains("sk-tok-"))
   }

   @Test("applyToBodyHTML passes through non-code HTML unchanged")
   func applyToBodyHTMLPassthrough() {
      let html = "<p>Some paragraph text with <em>emphasis</em>.</p>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: "swift")
      #expect(result == html)
   }

   // MARK: - String-vs-comment context lexing

   @Test("A // inside a string literal stays in the string, never a comment")
   func slashesInStringAreNotComment() {
      // Realistic DocC path: MarkdownRenderer hands applyToBodyHTML already-escaped
      // code, so the opening quote arrives as &quot;. The // inside the URL must stay
      // part of the string literal and must not open a line comment.
      let html = "<pre><code class=\"language-swift\">let u = &quot;https://x&quot;</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("sk-tok-string"))
      #expect(!result.contains("sk-tok-comment"))
      // The whole literal, including the URL and its closing quote, is one string span.
      #expect(result.contains("&quot;https://x&quot;"))
   }

   @Test("A /* inside a string literal stays in the string, never a block comment")
   func blockCommentMarkersInStringAreNotComment() {
      let html = "<pre><code class=\"language-swift\">let u = &quot;/* not a comment */&quot;</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("sk-tok-string"))
      #expect(!result.contains("sk-tok-comment"))
   }

   @Test("applyToBodyHTML HTML-escapes angle brackets inside code blocks")
   func applyToBodyHTMLEscapesCode() {
      // The rendered HTML from MarkdownRenderer already has &lt;/&gt; in the code;
      // applyToBodyHTML should unescape → re-highlight so entities appear in the output
      // without double-escaping (no &amp;lt; or &lt;Array&lt;).
      let html = "<pre><code class=\"language-swift\">let a: Array&lt;Int&gt; = []</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      // After round-trip, angle brackets must still be escaped in the output.
      #expect(result.contains("&lt;"))
      #expect(result.contains("&gt;"))
      // Must not double-escape: &lt; should not become &amp;lt;
      #expect(!result.contains("&amp;lt;"))
      #expect(!result.contains("&amp;gt;"))
   }

   @Test("Untagged block with no default round-trips to plain escaped text")
   func untaggedNoDefaultStaysEscapedPlain() {
      // No language class and no default: the block is re-escaped as plain text –
      // angle brackets round-trip to &lt;/&gt; without double-escaping, and no token
      // spans are emitted. The <pre> is still flagged as a processed block.
      let html = "<pre><code>let a: Array&lt;Int&gt; = []</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      #expect(result.contains("&lt;"))
      #expect(result.contains("&gt;"))
      #expect(!result.contains("&amp;lt;"))
      #expect(!result.contains("&amp;gt;"))
      #expect(!result.contains("sk-tok-"))
      #expect(result.contains("sk-docc-highlight"))
   }

   @Test("Inline <code> in prose is left byte-identical")
   func inlineCodeInProseUntouched() {
      // Only <pre><code> fences are processed; inline <code> in prose must be
      // returned verbatim even when a default language is supplied.
      let html = "<p>Call <code>foo()</code> to start.</p>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: "swift")
      #expect(result == html)
   }

   @Test("Multiple code blocks in one body are each highlighted, prose preserved")
   func multipleBlocksEachHighlighted() {
      let html = "<pre><code class=\"language-swift\">func a() {}</code></pre>"
         + "<p>between</p>"
         + "<pre><code class=\"language-swift\">func b() {}</code></pre>"
      let result = CodeHighlighter.applyToBodyHTML(html, defaultLanguage: nil)
      // Both <pre> blocks are processed (two sk-docc-highlight markers → three parts).
      #expect(result.components(separatedBy: "sk-docc-highlight").count == 3)
      #expect(result.contains("<span class=\"sk-tok-keyword\">func</span>"))
      // The prose between the two blocks is untouched.
      #expect(result.contains("<p>between</p>"))
   }
}
