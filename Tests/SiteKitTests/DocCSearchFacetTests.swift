import Foundation
import Testing

@testable import SiteKit

/// Facet-field coverage for the dedicated search page: year/framework/note-type
/// population in `DocCSearchIndex.build`, the extended record's JSON round-trip, and
/// the facet-value extraction helpers.
///
/// Real red-green proof for `noteTypeClassification`: commenting out the two early
/// returns in `DocCSearchIndex.noteType(for:)` (the stub and AI branches) makes every
/// note classify as `.community`, so the stub/ai expectations below go red; restoring
/// them goes green. Verified locally.
@Suite("DocCSearchIndex facets")
struct DocCSearchFacetTests {
   private func page(
      _ slug: String,
      title: String = "Note",
      html: String = "<p>body</p>",
      summary: String? = nil,
      extensions: [String: any Sendable] = [:]
   ) -> PageModel {
      var ext = extensions
      ext["doccNote"] = true
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: html,
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: summary,
         extensions: ext
      )
   }

   @Test("Year facet derives from the slug; non-WWDC slugs carry no year")
   func yearFromSlug() {
      let records = DocCSearchIndex.build(
         from: [self.page("wwdc25-101-keynote"), self.page("getting-started")],
         urlPrefix: "documentation"
      )
      #expect(records[0].year == "wwdc25")
      #expect(records[1].year == nil)
   }

   @Test("Framework facet reads doccFramework from the note's extensions")
   func frameworkFromExtensions() {
      let records = DocCSearchIndex.build(
         from: [
            self.page("wwdc25-101-x", extensions: ["doccFramework": "swiftui"]),
            self.page("wwdc25-102-y"),
         ],
         urlPrefix: "documentation"
      )
      #expect(records[0].framework == "swiftui")
      #expect(records[1].framework == nil)
   }

   @Test("Note type: stub wins, then AI-only, else community")
   func noteTypeClassification() {
      let records = DocCSearchIndex.build(
         from: [
            self.page("wwdc25-1-a", extensions: ["doccIsStub": true]),
            self.page("wwdc25-2-b", extensions: ["doccAIOnly": true]),
            self.page("wwdc25-3-c"),
            // Stub + AI flags together still classify as stub – stub takes priority.
            self.page("wwdc25-4-d", extensions: ["doccIsStub": true, "doccAIOnly": true]),
         ],
         urlPrefix: "documentation"
      )
      #expect(records[0].noteType == .stub)
      #expect(records[1].noteType == .ai)
      #expect(records[2].noteType == .community)
      #expect(records[3].noteType == .stub)
   }

   @Test("Record round-trips through JSON; note type serializes under the `type` key")
   func recordCodableRoundTrip() throws {
      let record = DocCSearchRecord(
         title: "Meet X",
         url: "/documentation/wwdc25-101-x/",
         text: "body",
         year: "wwdc25",
         framework: "swiftui",
         noteType: .community
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let data = try encoder.encode(record)
      let json = String(decoding: data, as: UTF8.self)
      #expect(json.contains("\"type\":\"community\""))
      #expect(json.contains("\"year\":\"wwdc25\""))
      #expect(json.contains("\"framework\":\"swiftui\""))
      // The page's deep-link param uses `type`, never `noteType` – guard the wire name.
      #expect(!json.contains("noteType"))

      let decoded = try JSONDecoder().decode(DocCSearchRecord.self, from: data)
      #expect(decoded == record)
   }

   @Test("Nil year/framework are omitted from the encoded record")
   func nilFacetsOmitted() throws {
      let record = DocCSearchRecord(title: "T", url: "/u/", text: "b", year: nil, framework: nil, noteType: .ai)
      let data = try JSONEncoder().encode(record)
      let json = String(decoding: data, as: UTF8.self)
      #expect(!json.contains("year"))
      #expect(!json.contains("framework"))
      #expect(json.contains("\"type\":\"ai\""))
   }

   @Test("Distinct years are newest-first; frameworks alphabetical; note types in AI→Community→Stub order")
   func distinctFacetValues() {
      let records = DocCSearchIndex.build(
         from: [
            self.page("wwdc24-1-a", extensions: ["doccFramework": "swiftui"]),
            self.page("wwdc25-1-b", extensions: ["doccFramework": "design", "doccAIOnly": true]),
            self.page("wwdc23-1-c", extensions: ["doccIsStub": true]),
            self.page("getting-started"),
         ],
         urlPrefix: "documentation"
      )
      #expect(DocCSearchPage.distinctYears(in: records) == ["wwdc25", "wwdc24", "wwdc23"])
      #expect(DocCSearchPage.distinctFrameworks(in: records) == ["design", "swiftui"])
      #expect(DocCSearchPage.distinctNoteTypes(in: records) == [.ai, .community, .stub])
   }
}
