import Foundation
import Markdown
import Testing

@testable import SiteKit

@Suite("DocCQuickReadRenderer")
struct DocCQuickReadRendererTests {
   private func firstBlockQuote(_ markdown: String) -> BlockQuote? {
      Document(parsing: markdown).children.compactMap { $0 as? BlockQuote }.first
   }

   @Test("Renders a Quick Read blockquote as a semantic aside with both CSS classes")
   func rendersQuickReadAside() throws {
      let markdown = """
      > **Quick Read** (AI):
      > _A short summary._
      > - 🎭 A highlight bullet
      """
      let quote = try #require(self.firstBlockQuote(markdown))
      let html = try #require(DocCQuickReadRenderer().render(quote))

      // Both class names must be present so existing CSS hooks and new TLDR styles both apply.
      #expect(html.contains("sk-docc-quickread"))
      #expect(html.contains("sk-docc-tldr"))
      // The aside carries id="quick-read" so the TOC "Quick Read" anchor resolves without
      // colliding with an authored ## Overview section that also slugifies to "overview".
      #expect(html.hasPrefix("<aside class=\"sk-docc-quickread sk-docc-tldr\" id=\"quick-read\">"))

      // The tag pill replaces the raw label text – it must appear exactly once as a span.
      #expect(html.contains("<span class=\"sk-docc-tldr-tag\">Quick Read</span>"))

      // The lead sentence must be wrapped in the lead paragraph class.
      #expect(html.contains("class=\"sk-docc-tldr-lead\""))

      // Summary content and highlight bullet must be preserved.
      #expect(html.contains("A short summary."))
      #expect(html.contains("A highlight bullet"))

      // No raw blockquote element must appear.
      #expect(!html.contains("<blockquote>"))
   }

   @Test("Strips the duplicate Quick Read prefix from the rendered lead text")
   func stripsQuickReadPrefixFromLead() throws {
      let markdown = """
      > **Quick Read** (AI): The key takeaway is here.
      """
      let quote = try #require(self.firstBlockQuote(markdown))
      let html = try #require(DocCQuickReadRenderer().render(quote))

      // The lead text must not start with the label again after the tag pill.
      #expect(html.contains("The key takeaway is here."))

      // The raw text "Quick Read" must only appear inside the tag span, not in the lead body.
      // Strip the tag span, then check no further "Quick Read" substring remains.
      let withoutTag = html.replacing("<span class=\"sk-docc-tldr-tag\">Quick Read</span>", with: "")
      #expect(!withoutTag.lowercased().contains("quick read"))
   }

   @Test("Returns nil for a normal blockquote (falls back to default rendering)")
   func ignoresNormalBlockQuote() throws {
      let quote = try #require(self.firstBlockQuote("> Just a normal quote."))
      #expect(DocCQuickReadRenderer().render(quote) == nil)
   }

   @Test("DocCLoader renders a note's Quick Read as the component, not a blockquote")
   func loaderUsesQuickReadComponent() throws {
      let note = """
      # A Note

      Abstract here.

      > **Quick Read** (AI):
      > _The gist._

      ## Body

      Regular content.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/A.md"), content: note)
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("sk-docc-quickread"))
      #expect(page.htmlContent.contains("sk-docc-tldr"))
      #expect(page.htmlContent.contains("The gist."))
      #expect(!page.htmlContent.contains("<blockquote>"))
   }
}
