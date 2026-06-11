import Foundation
import Testing

@testable import SiteKit

@Suite("DocCContributorsPage")
struct DocCContributorsPageTests {
   private static let docSection = SectionConfig(
      name: "Documentation",
      slug: "documentation",
      contentDirectory: "Documentation.docc",
      urlPrefix: "documentation"
   )

   private func note(
      title: String,
      slug: String,
      contributors: [String] = []
   ) -> PageModel {
      var extensions: [String: any Sendable] = ["doccNote": true]
      if !contributors.isEmpty { extensions["doccContributors"] = contributors }
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: nil,
         pageType: .article,
         extensions: extensions
      )
   }

   private func context(notes: [PageModel]) -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection]
         ),
         themeConfig: nil,
         sections: [ContentSection(config: Self.docSection, pages: notes)],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   // MARK: - pages(in:)

   @Test("Returns one page when at least one contributor handle exists")
   func returnsOnePageWhenContributorsExist() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let pages = DocCContributorsPage().pages(in: ctx)
      #expect(pages.count == 1)
      #expect(pages.first?.slug == "contributors")
   }

   @Test("Returns empty array when no contributor handles exist")
   func returnsEmptyWhenNoContributors() {
      let ctx = context(notes: [
         note(title: "Stub", slug: "wwdc24-200-stub"),
      ])
      let pages = DocCContributorsPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   @Test("Returns empty array when catalog has no notes at all")
   func returnsEmptyForEmptyCatalog() {
      let ctx = context(notes: [])
      let pages = DocCContributorsPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   // MARK: - contributorCounts aggregation

   @Test("Aggregates handle counts across multiple notes correctly")
   func aggregatesCountsAcrossNotes() {
      let counts = DocCContributorsPage.contributorCounts(from: [
         note(title: "A", slug: "wwdc24-100-a", contributors: ["alice", "bob"]),
         note(title: "B", slug: "wwdc24-101-b", contributors: ["alice"]),
         note(title: "C", slug: "wwdc24-102-c", contributors: ["carol"]),
      ])
      let map = Dictionary(uniqueKeysWithValues: counts.map { ($0.handle, $0.count) })
      #expect(map["alice"] == 2)
      #expect(map["bob"] == 1)
      #expect(map["carol"] == 1)
   }

   @Test("Sorts contributors by count descending then handle ascending")
   func sortsByCountDescThenHandleAsc() {
      let counts = DocCContributorsPage.contributorCounts(from: [
         note(title: "A", slug: "wwdc24-100-a", contributors: ["zara", "alice"]),
         note(title: "B", slug: "wwdc24-101-b", contributors: ["alice"]),
         note(title: "C", slug: "wwdc24-102-c", contributors: ["bob"]),
      ])
      // alice has 2, bob and zara have 1 each → alice first, then bob < zara alphabetically
      #expect(counts.map(\.handle) == ["alice", "bob", "zara"])
   }

   @Test("Deduplicates the same handle within a single note's contributor list")
   func deduplicatesHandleWithinSingleNote() {
      let counts = DocCContributorsPage.contributorCounts(from: [
         note(title: "A", slug: "wwdc24-100-a", contributors: ["alice", "alice"]),
      ])
      let map = Dictionary(uniqueKeysWithValues: counts.map { ($0.handle, $0.count) })
      // alice appears twice in the same note's list but should count as 1 contribution
      #expect(map["alice"] == 1)
   }

   // MARK: - renderHTML

   @Test("Renders grid, stats, and prism markup")
   func rendersGridStatsAndPrism() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-contrib-grid"))
      #expect(html.contains("sk-docc-contrib-stats"))
      #expect(html.contains("sk-docc-hero-prism"))
      #expect(html.contains("sk-docc-hero--compact"))
   }

   @Test("Compact hero emits both sk-docc-hero--compact and is-compact")
   func compactHeroEmitsBothClasses() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)
      #expect(html.contains("sk-docc-hero--compact"))
      #expect(html.contains("is-compact"))
   }

   @Test("hero helper with showPrism false adds noprism modifier and omits prism art")
   func heroShowPrismFalse() {
      let ui = UIStrings(locale: "en")
      let html = DocCContributorsPage().hero(title: "Contributors", ui: ui, showPrism: false)
      #expect(html.contains("sk-docc-hero--noprism"))
      #expect(!html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-hero-art"))
      #expect(html.contains("sk-docc-hero--compact"))
      #expect(html.contains("is-compact"))
   }

   @Test("hero helper with showPrism true (default) emits prism art")
   func heroShowPrismTrue() {
      let ui = UIStrings(locale: "en")
      let html = DocCContributorsPage().hero(title: "Contributors", ui: ui)
      #expect(html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-hero--noprism"))
   }

   @Test("Contributors hero markup is byte-stable")
   func heroMarkupByteStable() {
      // Exact-markup guard: the contributors hero is an explicitly approved design
      // surface. Article-hero work (card/band styles, prism expansion) must never
      // change a byte of this output – if this test fails, the hero changed shape.
      let ui = UIStrings(locale: "en")
      let html = DocCContributorsPage().hero(title: "Contributors", ui: ui)
      let eyebrow = ui.string(for: .doccContributorsEyebrow)
      let subtitle = ui.string(for: .doccContributorsSubtitle)
      #expect(html ==
         "<div class=\"sk-docc-hero sk-docc-hero--compact is-compact\">"
         + "<div class=\"sk-docc-hero-inner\">"
         + "<div class=\"sk-docc-hero-eyebrow\">\(eyebrow)</div>"
         + "<h1 class=\"sk-docc-hero-title\">Contributors</h1>"
         + "<p class=\"sk-docc-hero-sub\">\(subtitle)</p>"
         + "</div>"
         + "<div class=\"sk-docc-hero-art\" aria-hidden=\"true\"><div class=\"sk-docc-hero-prism\"></div></div>"
         + "</div>"
      )
   }

   @Test("Renders the DocC sidebar chrome")
   func rendersChrome() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
   }

   @Test("GitHub avatar URL present for each contributor")
   func gitHubAvatarPresent() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)

      // Grid cards request a 112px source for a 56px retina avatar (sized up from the former
      // 40px/80px thumbnail so the sub-profile links carry a recognisable face).
      #expect(html.contains("https://github.com/alice.png?size=112"))
      #expect(html.contains("width=\"56\" height=\"56\""))
   }

   @Test("Grid items link to contributor detail pages rather than GitHub profiles")
   func gridItemsLinkToDetailPages() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)

      // Cards must point at the detail page, not directly at the GitHub profile.
      #expect(html.contains("href=\"/documentation/contributors/alice/\""))
      #expect(!html.contains("href=\"https://github.com/alice\""))
   }

   @Test("Handle appearing in 2 notes shows '2 notes' sub-label")
   func twoNoteCountLabel() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
         note(title: "Session B", slug: "wwdc24-101-b", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)
      #expect(html.contains("2 notes"))
   }

   @Test("Handle appearing in exactly 1 note shows '1 note' (singular)")
   func oneNoteCountSingular() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let html = DocCContributorsPage().renderHTML(page, context: ctx)
      #expect(html.contains("1 note"))
   }

   // MARK: - HTML escaping

   @Test("HTML-escapes GitHub handles containing special characters")
   func htmlEscapesHandle() {
      // Ampersands and angle brackets in handles are pathological but the escaper
      // must still produce valid HTML rather than injection vectors.
      let counts: [(handle: String, count: Int)] = [("a&b", 1)]
      let html = DocCContributorsPage().contributorGrid(counts: counts)
      #expect(html.contains("a&amp;b"))
      #expect(!html.contains("a&b"))
   }

   // MARK: - Hero from catalog note

   @Test("Hero title and sub-label come from the catalog contributors note when present")
   func heroTitleFromCatalogNote() {
      // When the catalog ships a Contributors.md (slug == "contributors"), pages(in:)
      // should adopt its title and summary for the synthetic page – and renderHTML
      // should pass that title straight through to the hero <h1>.
      let catalogNote = PageModel(
         title: "Our Contributors",
         slug: "contributors",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/contributors.md"),
         summary: "The humans behind the notes.",
         pageType: .article,
         extensions: ["doccNote": true]
      )
      let sessionNote = self.note(
         title: "Session A",
         slug: "wwdc24-100-a",
         contributors: ["alice", "bob"]
      )
      let ctx = self.context(notes: [catalogNote, sessionNote])

      // pages(in:) should adopt the catalog note's title and summary.
      let pages = DocCContributorsPage().pages(in: ctx)
      #expect(pages.count == 1)
      let page = pages[0]
      #expect(page.title == "Our Contributors")
      #expect(page.summary == "The humans behind the notes.")

      // renderHTML passes the page title to the hero – the catalog note title
      // must appear in the rendered <h1>.
      let html = DocCContributorsPage().renderHTML(page, context: ctx)
      #expect(html.contains("Our Contributors"))
      // The hero h1 uses the sk-docc-hero-title class.
      #expect(html.contains("sk-docc-hero-title"))
   }

   @Test("Hero title falls back to 'Contributors' when no catalog note is present")
   func heroTitleFallbackWhenNoCatalogNote() {
      // Without a contributors catalog note the synthesized default title is used.
      let ctx = self.context(notes: [
         self.note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      #expect(page.title == "Contributors")
   }

   // MARK: - outputURL

   @Test("outputURL ends with /<prefix>/contributors/index.html")
   func outputURLPath() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorsPage().pages(in: ctx).first!
      let url = DocCContributorsPage().outputURL(for: page, context: ctx)
      #expect(url.path.hasSuffix("/documentation/contributors/index.html"))
   }
}
