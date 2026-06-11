import Foundation
import Testing

@testable import SiteKit

/// Coverage for the dedicated `/<prefix>/search/` page renderer: page synthesis,
/// output path, route reservation, and the rendered scaffold (three-column shape,
/// data-driven facet chips, suggestion chips, deep-link hooks, and the client script).
@Suite("DocCSearchPage")
struct DocCSearchPageTests {
   private func note(
      _ slug: String,
      title: String = "Note",
      summary: String? = "A note.",
      framework: String? = nil,
      isStub: Bool = false,
      aiOnly: Bool = false
   ) -> PageModel {
      var ext: [String: any Sendable] = ["doccNote": true]
      if let framework { ext["doccFramework"] = framework }
      if isStub { ext["doccIsStub"] = true }
      if aiOnly { ext["doccAIOnly"] = true }
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: "<p>body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: summary,
         pageType: .article,
         extensions: ext
      )
   }

   private func context(notes: [PageModel], docc: DocCConfig? = nil) -> BuildContext {
      let section = SectionConfig(name: "Docs", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation")
      let config = SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [section], docc: docc)
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: notes)],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   @Test("Synthesizes one search page when the catalog has notes")
   func pagesWhenNotesExist() {
      let pages = DocCSearchPage().pages(in: self.context(notes: [self.note("wwdc25-1-a")]))
      #expect(pages.count == 1)
      #expect(pages[0].slug == "search")
   }

   @Test("Emits no search page when there are no DocC notes")
   func noPagesWhenEmpty() {
      #expect(DocCSearchPage().pages(in: self.context(notes: [])).isEmpty)
   }

   @Test("Output URL is /<prefix>/search/index.html")
   func outputURLIsUnderPrefix() {
      let ctx = self.context(notes: [self.note("wwdc25-1-a")])
      let page = DocCSearchPage().pages(in: ctx)[0]
      let url = DocCSearchPage().outputURL(for: page, context: ctx)
      #expect(url.path.hasSuffix("/documentation/search/index.html"))
   }

   @Test("Reserves the `search` slug only when a real catalog note claims it (search on by default)")
   func reservesSearchSlugWhenNotePresent() {
      let withSearchNote = [self.note("wwdc25-1-a"), self.note("search", title: "Search")]
      // Search defaults on, so a nil docc config still reserves the slug when a `search.md` exists.
      #expect(DocCReservedRoutes.reservedSlugs(in: withSearchNote, docc: nil).contains("search"))
      // No `search.md` note → nothing to reserve (the synthetic page owns the URL anyway).
      #expect(!DocCReservedRoutes.reservedSlugs(in: [self.note("wwdc25-1-a")], docc: nil).contains("search"))
   }

   @Test("Rendered page carries the three-column scaffold, data-driven facets, and deep-link hooks")
   func renderedStructure() {
      let notes = [
         self.note("wwdc25-101-a", framework: "swiftui"),
         self.note("wwdc24-1-b", isStub: true),
         self.note("wwdc25-2-c", aiOnly: true),
      ]
      let docc = DocCConfig(
         frameworks: ["swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#111", "#222"])],
         searchSuggestions: ["Liquid Glass"],
         searchNoteTypeFilter: true
      )
      let ctx = self.context(notes: notes, docc: docc)
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)

      // Page root + the two inner columns (the shell supplies the third, nav, column).
      #expect(html.contains("data-docc-search-page"))
      #expect(html.contains("sk-docc-search-aside"))
      #expect(html.contains("sk-docc-search-main"))

      // All three facet groups present and data-driven (years newest-first, framework key, types).
      #expect(html.contains("data-docc-facet-group=\"year\""))
      #expect(html.contains("data-docc-facet-group=\"type\""))
      #expect(html.contains("data-docc-facet-group=\"framework\""))
      #expect(html.contains("data-docc-facet=\"year\" data-docc-facet-value=\"wwdc25\""))
      #expect(html.contains("data-docc-facet=\"year\" data-docc-facet-value=\"wwdc24\""))
      #expect(html.contains("data-docc-facet=\"framework\" data-docc-facet-value=\"swiftui\""))
      #expect(html.contains("data-docc-facet=\"type\" data-docc-facet-value=\"ai\""))
      #expect(html.contains("data-docc-facet=\"type\" data-docc-facet-value=\"stub\""))

      // Suggestion chip, framework color registry, and the client script.
      #expect(html.contains("data-docc-search-suggest=\"Liquid Glass\""))
      #expect(html.contains("data-docc-search-frameworks"))
      #expect(html.contains(DocCSearchPageScriptRenderer.scriptURL))

      // Deep-link param vocabulary on the input (count/empty/prompt/loading strings).
      #expect(html.contains("data-docc-search-prompt"))
      #expect(html.contains("data-docc-label-ai"))
   }

   @Test("Framework chip label uses the configured displayName; the chip value stays the raw key")
   func frameworkChipUsesDisplayName() {
      let docc = DocCConfig(frameworks: [
         "appintents": DocCFrameworkIcon(glyph: "fa-solid fa-bolt", colors: ["#111"], displayName: "App Intents")
      ])
      let ctx = self.context(notes: [self.note("wwdc25-1-a", framework: "appintents")], docc: docc)
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      // Friendly label on the chip, raw key on the value attribute (URL param + JS filtering).
      #expect(html.contains(
         "data-docc-facet=\"framework\" data-docc-facet-value=\"appintents\" aria-pressed=\"false\">"
            + "<span class=\"sk-docc-facet-chip-label\">App Intents</span>"
      ))
      #expect(!html.contains("sk-docc-facet-chip-label\">appintents</span>"))
   }

   @Test("Framework chip label falls back to the raw key when no displayName is configured")
   func frameworkChipFallsBackToRawKey() {
      // "swiftui" has a registry entry without displayName; "metal" has no entry at all –
      // both fallback paths must label the chip with the raw key.
      let docc = DocCConfig(frameworks: [
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#111", "#222"])
      ])
      let notes = [self.note("wwdc25-1-a", framework: "swiftui"), self.note("wwdc25-2-b", framework: "metal")]
      let ctx = self.context(notes: notes, docc: docc)
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      #expect(html.contains("sk-docc-facet-chip-label\">swiftui</span>"))
      #expect(html.contains("sk-docc-facet-chip-label\">metal</span>"))
   }

   @Test("Framework facet group is labeled Topic – its values mix frameworks with topic buckets")
   func frameworkFacetGroupLabeledTopic() {
      let ctx = self.context(notes: [self.note("wwdc25-1-a", framework: "swiftui")])
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      #expect(html.contains("<span class=\"sk-docc-search-facet-label\">Topic</span>"))
   }

   @Test("Note-type facet group renders when searchNoteTypeFilter opts in")
   func noteTypeGroupRendersWhenEnabled() {
      let notes = [self.note("wwdc25-1-a"), self.note("wwdc25-2-b", isStub: true)]
      let ctx = self.context(notes: notes, docc: DocCConfig(searchNoteTypeFilter: true))
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      #expect(html.contains("data-docc-facet-group=\"type\""))
      #expect(html.contains("data-docc-facet=\"type\" data-docc-facet-value=\"stub\""))
   }

   @Test("Note-type facet group is omitted by default; the result-row badge labels stay on the page root")
   func noteTypeGroupOmittedByDefault() {
      let notes = [self.note("wwdc25-1-a"), self.note("wwdc25-2-b", isStub: true)]
      let ctx = self.context(notes: notes)
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      #expect(!html.contains("data-docc-facet-group=\"type\""))
      // Only the filter group is gated – the badge labels for client-rendered result rows remain.
      #expect(html.contains("data-docc-label-stub"))
   }

   @Test("Search-page script only honors URL params for facet groups present in the DOM")
   func scriptGatesFacetParamsOnRenderedGroups() throws {
      let js = try DocCSearchPageScriptRenderer.loadScript()
      // GROUPS must be derived from the groups the server actually rendered, so a `?type=…`
      // deep link stays inert (never silently narrows results) while the note-type group is
      // hidden via config – same for any other dimension the catalog does not carry.
      #expect(js.contains(#"ALL_GROUPS.filter"#))
      #expect(js.contains(#"root.querySelector("[data-docc-facet-group=\"" + group + "\"]")"#))
   }

   @Test("Omits a facet group entirely when no note supplies that dimension")
   func omitsEmptyFacetGroups() {
      // Notes with no framework anywhere → the Framework group must not render.
      let ctx = self.context(notes: [self.note("wwdc25-1-a"), self.note("wwdc25-2-b")])
      let page = DocCSearchPage().pages(in: ctx)[0]
      let html = DocCSearchPage().renderHTML(page, context: ctx)
      #expect(html.contains("data-docc-facet-group=\"year\""))
      #expect(!html.contains("data-docc-facet-group=\"framework\""))
   }
}
