import Foundation
import Markdown
import Testing

@testable import SiteKit

@Suite("DocCCrossReferenceEnricher")
struct DocCCrossReferenceEnricherTests {
   private func page(html: String) -> PageModel {
      PageModel(
         title: "T",
         slug: "t",
         htmlContent: html,
         sourcePath: URL(fileURLWithPath: "/tmp/t.md")
      )
   }

   @Test("swift-markdown renders <doc:Id> as a doc: autolink (assumption check)")
   func renderFormatAssumption() {
      let html = MarkdownRenderer().render("See <doc:WWDC25-304-Explore-Foo> for more.")
      #expect(html.contains("href=\"doc:WWDC25-304-Explore-Foo\""))
   }

   @Test("Resolves a bare autolink to an internal URL with a readable label")
   func resolvesBareAutolink() throws {
      let input = self.page(html: "<p><a href=\"doc:WWDC24-10132-Foo-Bar\">doc:WWDC24-10132-Foo-Bar</a></p>")
      let out = try DocCCrossReferenceEnricher(urlPrefix: "documentation").enrich(input)
      #expect(out.htmlContent.contains("href=\"/documentation/wwdc24-10132-foo-bar/\""))
      #expect(out.htmlContent.contains(">Foo Bar</a>"))
      #expect(!out.htmlContent.contains("doc:WWDC24-10132-Foo-Bar"))
   }

   @Test("Keeps an author-written link label, only rewrites the href")
   func keepsAuthorLabel() throws {
      let input = self.page(html: "<a href=\"doc:WWDC24-1-X\">Custom Label</a>")
      let out = try DocCCrossReferenceEnricher(urlPrefix: "documentation").enrich(input)
      #expect(out.htmlContent.contains("href=\"/documentation/wwdc24-1-x/\""))
      #expect(out.htmlContent.contains(">Custom Label</a>"))
   }

   @Test("Year-overview identifier passes through as its own label")
   func yearOverview() throws {
      let input = self.page(html: "<a href=\"doc:WWDC25\">doc:WWDC25</a>")
      let out = try DocCCrossReferenceEnricher(urlPrefix: "documentation").enrich(input)
      #expect(out.htmlContent.contains("href=\"/documentation/wwdc25/\""))
      #expect(out.htmlContent.contains(">WWDC25</a>"))
   }

   @Test("Leaves content without doc: links untouched")
   func noDocLinks() throws {
      let input = self.page(html: "<p>Just <a href=\"https://example.com\">a link</a>.</p>")
      let out = try DocCCrossReferenceEnricher(urlPrefix: "documentation").enrich(input)
      #expect(out.htmlContent == input.htmlContent)
   }
}
