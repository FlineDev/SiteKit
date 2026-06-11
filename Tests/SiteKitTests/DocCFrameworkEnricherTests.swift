import Foundation
import Testing

@testable import SiteKit

@Suite("DocCFrameworkEnricher")
struct DocCFrameworkEnricherTests {
   private let dummyURL = URL(fileURLWithPath: "/tmp/dummy.md")

   private func makeNote(slug: String, existingFramework: String? = nil) -> PageModel {
      var ext: [String: any Sendable] = ["doccNote": true]
      if let fw = existingFramework { ext["doccFramework"] = fw }
      return PageModel(title: "T", slug: slug, htmlContent: "", sourcePath: dummyURL, extensions: ext)
   }

   private func makeNonNote(slug: String) -> PageModel {
      PageModel(title: "T", slug: slug, htmlContent: "", sourcePath: dummyURL)
   }

   // MARK: – sessionKey helper

   @Test("sessionKey derives the first two dash-segments from a session slug")
   func sessionKeyDerivation() {
      #expect(DocCFrameworkEnricher.sessionKey(from: "wwdc25-101-keynote") == "wwdc25-101")
      #expect(DocCFrameworkEnricher.sessionKey(from: "wwdc24-10094-foo-bar") == "wwdc24-10094")
   }

   @Test("sessionKey returns the slug unchanged when fewer than two segments")
   func sessionKeyShortSlug() {
      #expect(DocCFrameworkEnricher.sessionKey(from: "wwdc25") == "wwdc25")
   }

   @Test("sessionKey returns empty string for non-WWDC two-segment slugs")
   func sessionKeyNonWWDCSlug() {
      // Non-WWDC slugs like "getting-started" must not produce a key – they
      // would match the two-segment pattern but have no entry in the WWDC map.
      #expect(DocCFrameworkEnricher.sessionKey(from: "getting-started") == "")
      #expect(DocCFrameworkEnricher.sessionKey(from: "hello-world") == "")
   }

   @Test("Non-WWDC note slug with two segments does not acquire doccFramework")
   func nonWWDCSlugNotEnriched() throws {
      // A non-WWDC note whose two-segment key happens to match a map entry must
      // NOT get the framework assigned – only WWDC sessions use the central map.
      let map = ["getting-started": "swift"]  // even with an explicit map entry…
      let enricher = DocCFrameworkEnricher(map: map)
      let note = makeNote(slug: "getting-started")
      let out = try enricher.enrich(note)
      // …the non-WWDC slug returns an empty key, so no match → unchanged.
      #expect(out.extensions["doccFramework"] == nil)
   }

   // MARK: – enrich

   @Test("Central map assigns framework key from the session id")
   func assignsFromMap() throws {
      let map = ["wwdc25-101": "design", "wwdc25-210": "swiftui"]
      let enricher = DocCFrameworkEnricher(map: map)

      let note = makeNote(slug: "wwdc25-101-keynote")
      let out = try enricher.enrich(note)
      #expect(out.extensions["doccFramework"] as? String == "design")
   }

   @Test("Per-note framework wins over the central map")
   func perNoteWins() throws {
      let map = ["wwdc25-101": "design"]
      let enricher = DocCFrameworkEnricher(map: map)

      // Note already carries its own framework (e.g. from <!-- framework: swift -->).
      let note = makeNote(slug: "wwdc25-101-keynote", existingFramework: "swift")
      let out = try enricher.enrich(note)
      // Must stay "swift", not "design".
      #expect(out.extensions["doccFramework"] as? String == "swift")
   }

   @Test("Slug not in the map leaves doccFramework unset")
   func unmappedSlugUntouched() throws {
      let enricher = DocCFrameworkEnricher(map: [:])

      let note = makeNote(slug: "wwdc25-999-unknown")
      let out = try enricher.enrich(note)
      #expect(out.extensions["doccFramework"] == nil)
   }

   @Test("Non-DocC pages pass through unchanged")
   func nonDocCPagePassthrough() throws {
      let map = ["wwdc25-101": "design"]
      let enricher = DocCFrameworkEnricher(map: map)

      // A plain PageModel with no doccNote: true extension.
      let page = makeNonNote(slug: "wwdc25-101-keynote")
      let out = try enricher.enrich(page)
      #expect(out.extensions["doccFramework"] == nil)
   }
}
