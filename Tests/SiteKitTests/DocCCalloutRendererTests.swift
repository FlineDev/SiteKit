import Foundation
import Markdown
import Testing

@testable import SiteKit

@Suite("DocCCalloutRenderer")
struct DocCCalloutRendererTests {
   private func firstBlockQuote(_ markdown: String) -> BlockQuote? {
      Document(parsing: markdown).children.compactMap { $0 as? BlockQuote }.first
   }

   @Test("Recognises each of the five callout kinds")
   func recognisesAllKinds() {
      for kind in DocCCalloutRenderer.Kind.allCases {
         let capitalised = kind.rawValue.prefix(1).uppercased() + kind.rawValue.dropFirst()
         let markdown = "> \(capitalised): Some content here."
         guard let quote = self.firstBlockQuote(markdown) else {
            Issue.record("No blockquote parsed for kind '\(kind.rawValue)'")
            continue
         }
         let html = DocCCalloutRenderer().render(quote)
         #expect(html != nil, "Expected callout HTML for kind '\(kind.rawValue)'")
         #expect(html?.contains("sk-docc-callout--\(kind.rawValue)") == true)
         #expect(html?.contains("sk-docc-callout-label") == true)
      }
   }

   @Test("Renders a Tip callout with the correct modifier class and label")
   func tipCallout() throws {
      let quote = try #require(self.firstBlockQuote("> Tip: Enable dark mode in Settings."))
      let html = try #require(DocCCalloutRenderer().render(quote))
      #expect(html.contains("sk-docc-callout--tip"))
      #expect(html.contains("sk-docc-callout-label"))
      #expect(html.contains("Enable dark mode in Settings."))
      #expect(!html.contains("<blockquote>"))
   }

   @Test("Renders a Note callout and strips the 'Note:' prefix from the body")
   func noteCalloutStripsPrefix() throws {
      let quote = try #require(self.firstBlockQuote("> Note: This API requires iOS 17."))
      let html = try #require(DocCCalloutRenderer().render(quote))
      #expect(html.contains("sk-docc-callout--note"))
      // The prefix "Note:" must not appear inside the body div.
      let withoutLabel = html.replacing("<span class=\"sk-docc-callout-label\">Note</span>", with: "")
      let lower = withoutLabel.lowercased()
      #expect(!lower.contains("note:"))
   }

   @Test("Returns nil for a plain blockquote with no recognised prefix")
   func ignoresPlainBlockquote() throws {
      let quote = try #require(self.firstBlockQuote("> Just a regular quoted paragraph."))
      #expect(DocCCalloutRenderer().render(quote) == nil)
   }

   @Test("Case-insensitive detection: lowercase 'tip:' works")
   func caseInsensitiveTip() throws {
      let quote = try #require(self.firstBlockQuote("> tip: Use lowercase too."))
      let html = DocCCalloutRenderer().render(quote)
      #expect(html != nil)
      #expect(html?.contains("sk-docc-callout--tip") == true)
   }

   @Test("Multi-paragraph callout body is fully rendered")
   func multiParagraphBody() throws {
      let markdown = """
      > Important: First point.
      >
      > Second paragraph follows here.
      """
      let quote = try #require(self.firstBlockQuote(markdown))
      let html = try #require(DocCCalloutRenderer().render(quote))
      #expect(html.contains("First point."))
      #expect(html.contains("Second paragraph follows here."))
   }

   @Test("calloutKind detects each kind by plain-text prefix")
   func calloutKindDetection() {
      let cases: [(String, DocCCalloutRenderer.Kind?)] = [
         ("Tip: foo", .tip),
         ("Note: bar", .note),
         ("Important: baz", .important),
         ("Warning: danger", .warning),
         ("Experiment: try this", .experiment),
         ("tip: lowercase", .tip),
         ("Regular text here", nil),
         ("quick read: not a callout", nil),
      ]
      for (input, expected) in cases {
         let result = DocCCalloutRenderer.calloutKind(from: input)
         #expect(result == expected, "For input '\(input)': expected \(String(describing: expected)), got \(String(describing: result))")
      }
   }

   @Test("Space-only prefix does NOT trigger a callout (colon required)")
   func spaceOnlyPrefixIsNotACallout() throws {
      // These must render as plain blockquotes, not callout boxes.
      let cases = [
         "> Note something here",
         "> Experiment with care",
         "> Tip toe dancing",
      ]
      for markdown in cases {
         let quote = try #require(self.firstBlockQuote(markdown), "No blockquote parsed for '\(markdown)'")
         let html = DocCCalloutRenderer().render(quote)
         #expect(html == nil, "Expected nil (plain blockquote) for '\(markdown)', got: \(html ?? "nil")")
      }
   }

   @Test("Colon form still triggers a callout after removing space-variant leniency")
   func colonFormStillMatches() throws {
      let quote = try #require(self.firstBlockQuote("> Note: real callout content"))
      let html = try #require(DocCCalloutRenderer().render(quote))
      #expect(html.contains("sk-docc-callout--note"))
      #expect(html.contains("real callout content"))
   }
}
