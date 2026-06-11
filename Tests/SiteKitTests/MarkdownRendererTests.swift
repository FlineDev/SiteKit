import Testing
@testable import SiteKit

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
   let renderer = MarkdownRenderer()

   @Test("Renders heading")
   func heading() {
      let html = renderer.render("## Hello World")
      #expect(html.contains("<h2"))
      #expect(html.contains("Hello World"))
   }

   @Test("Renders paragraph")
   func paragraph() {
      let html = renderer.render("This is a paragraph.")
      #expect(html.contains("<p>This is a paragraph.</p>"))
   }

   @Test("Renders bold text")
   func boldText() {
      let html = renderer.render("This is **bold** text.")
      #expect(html.contains("<strong>bold</strong>"))
   }

   @Test("Renders italic text")
   func italicText() {
      let html = renderer.render("This is *italic* text.")
      #expect(html.contains("<em>italic</em>"))
   }

   @Test("Renders inline code")
   func inlineCode() {
      let html = renderer.render("Use `swift build` to compile.")
      #expect(html.contains("<code>swift build</code>"))
   }

   @Test("Renders links")
   func links() {
      let html = renderer.render("[Click here](https://example.com)")
      #expect(html.contains("<a href=\"https://example.com\">Click here</a>"))
   }

   @Test("Renders unordered list")
   func unorderedList() {
      let html = renderer.render("- Item 1\n- Item 2\n- Item 3")
      #expect(html.contains("<ul>"))
      #expect(html.contains("<li>"))
      #expect(html.contains("Item 1"))
   }

   @Test("Renders ordered list")
   func orderedList() {
      let html = renderer.render("1. First\n2. Second\n3. Third")
      #expect(html.contains("<ol>"))
      #expect(html.contains("<li>"))
   }

   @Test("Renders code block with language class")
   func codeBlock() {
      let html = renderer.render("```swift\nlet x = 42\n```")
      #expect(html.contains("<pre><code class=\"language-swift\">"))
      #expect(html.contains("let x = 42"))
      #expect(!html.contains("<span"))
   }

   @Test("Renders code block without language")
   func codeBlockNoLanguage() {
      let html = renderer.render("```\nsome code\n```")
      #expect(html.contains("<pre><code>"))
      #expect(html.contains("some code"))
   }

   @Test("Renders blockquote")
   func blockquote() {
      let html = renderer.render("> This is a quote")
      #expect(html.contains("<blockquote>"))
   }

   @Test("Passes through raw HTML")
   func htmlPassthrough() {
      let html = renderer.render("<div class=\"custom\">Content</div>")
      #expect(html.contains("<div class=\"custom\">Content</div>"))
   }

   @Test("Renders horizontal rule")
   func horizontalRule() {
      let html = renderer.render("Above\n\n---\n\nBelow")
      #expect(html.contains("<hr"))
   }

   @Test("Renders image")
   func image() {
      let html = renderer.render("![Alt text](https://example.com/image.png)")
      #expect(html.contains("<img"))
      #expect(html.contains("src=\"https://example.com/image.png\""))
   }

   @Test("Strips matching H1 title when specified")
   func stripMatchingTitle() {
      let html = renderer.render("# My Title\n\nParagraph", strippingTitleMatching: "My Title")
      #expect(!html.contains("<h1"))
      #expect(html.contains("<p>Paragraph</p>"))
   }

   @Test("Keeps non-matching H1")
   func keepNonMatchingTitle() {
      let html = renderer.render("# Different Title\n\nParagraph", strippingTitleMatching: "My Title")
      #expect(html.contains("<h1"))
   }

   @Test("Renders table")
   func table() {
      let markdown = """
      | Column A | Column B |
      |----------|----------|
      | Cell 1   | Cell 2   |
      """
      let html = renderer.render(markdown)
      #expect(html.contains("<table"))
      #expect(html.contains("<th"))
      #expect(html.contains("<td"))
   }

   @Test("Renders strikethrough")
   func strikethrough() {
      let html = renderer.render("This is ~~deleted~~ text.")
      #expect(html.contains("<del>deleted</del>"))
   }

   @Test("Renders nested inline formatting")
   func nestedInline() {
      let html = renderer.render("**[bold link](https://example.com)**")
      #expect(html.contains("<strong><a href=\"https://example.com\">bold link</a></strong>"))
   }

   @Test("Renders table with column alignment")
   func tableAlignment() {
      let markdown = """
      | Left | Center | Right |
      |:-----|:------:|------:|
      | A    | B      | C     |
      """
      let html = renderer.render(markdown)
      #expect(html.contains("text-align: left"))
      #expect(html.contains("text-align: center"))
      #expect(html.contains("text-align: right"))
   }

   @Test("Renders image with title attribute")
   func imageWithTitle() {
      let html = renderer.render("![Alt text](image.png \"My Title\")")
      #expect(html.contains("title=\"My Title\""))
      #expect(html.contains("alt=\"Alt text\""))
      #expect(html.contains("loading=\"lazy\""))
   }

   @Test("Renders empty content")
   func emptyContent() {
      let html = renderer.render("")
      #expect(html.isEmpty)
   }

   @Test("Generates heading IDs from text")
   func headingIDs() {
      let html = renderer.render("## Hello World")
      #expect(html.contains("id=\"hello-world\""))
   }

   @Test("Escapes HTML in code blocks")
   func codeBlockEscaping() {
      let html = renderer.render("```\n<div>test</div>\n```")
      #expect(html.contains("&lt;div&gt;"))
      #expect(!html.contains("<div>test</div>"))
   }

   @Test("Renders nested list")
   func nestedList() {
      let html = renderer.render("- Item 1\n  - Sub-item A\n  - Sub-item B\n- Item 2")
      #expect(html.contains("<ul>"))
      #expect(html.contains("Sub-item A"))
      #expect(html.contains("Item 2"))
   }

   @Test("Renders inline code with special characters")
   func inlineCodeEscaping() {
      let html = renderer.render("Use `<String>` type.")
      #expect(html.contains("<code>&lt;String&gt;</code>"))
   }
}
