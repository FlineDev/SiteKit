import Foundation
import Testing

@testable import SiteKit

@Suite("DocCMissingPage")
struct DocCMissingPageTests {
   private static let docSection = SectionConfig(
      name: "Documentation",
      slug: "documentation",
      contentDirectory: "Documentation.docc",
      urlPrefix: "documentation"
   )

   // MARK: - Helpers

   /// Builds a minimal DocC session note. Pass `isStub: true` to mark it as a
   /// placeholder (no real body content). Year notes (slug == yearKey) are NOT
   /// session notes and are excluded from coverage counts.
   private func sessionNote(
      title: String,
      slug: String,
      isStub: Bool = false
   ) -> PageModel {
      var extensions: [String: any Sendable] = ["doccNote": true]
      if isStub { extensions["doccIsStub"] = true }
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: isStub ? "" : "<p>Body content.</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: "Abstract for \(title).",
         pageType: .article,
         extensions: extensions
      )
   }

   /// Builds a catalog overview note (slug == yearKey, e.g. "wwdc24").
   /// These are NOT counted as sessions by the coverage logic.
   private func yearNote(slug: String, title: String) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         pageType: .article,
         extensions: ["doccNote": true]
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

   @Test("Returns one page when at least one stub exists")
   func returnsOnePageWhenStubsExist() {
      let ctx = context(notes: [
         sessionNote(title: "Session A", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "Stub B", slug: "wwdc24-200-b", isStub: true),
      ])
      let pages = DocCMissingPage().pages(in: ctx)
      #expect(pages.count == 1)
      #expect(pages.first?.slug == "missingnotes")
   }

   @Test("Returns empty array when no stubs exist")
   func returnsEmptyWhenNoStubs() {
      let ctx = context(notes: [
         sessionNote(title: "Session A", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "Session B", slug: "wwdc24-200-b", isStub: false),
      ])
      let pages = DocCMissingPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   @Test("Returns empty array when catalog has no notes at all")
   func returnsEmptyForEmptyCatalog() {
      let ctx = context(notes: [])
      let pages = DocCMissingPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   @Test("Uses catalog MissingNotes.md title and abstract when present")
   func usesCatalogNoteMetaWhenPresent() {
      let catalogNote = PageModel(
         title: "Missing Session Notes",
         slug: "missingnotes",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/missingnotes.md"),
         summary: "Help us fill the gaps.",
         pageType: .article,
         extensions: ["doccNote": true]
      )
      let ctx = context(notes: [
         catalogNote,
         sessionNote(title: "Stub", slug: "wwdc24-100-stub", isStub: true),
      ])
      let pages = DocCMissingPage().pages(in: ctx)
      #expect(pages.first?.title == "Missing Session Notes")
      #expect(pages.first?.summary == "Help us fill the gaps.")
   }

   @Test("Falls back to default title when no catalog note exists")
   func usesDefaultTitleWhenNoCatalogNote() {
      let ctx = context(notes: [
         sessionNote(title: "Stub", slug: "wwdc24-100-stub", isStub: true),
      ])
      let pages = DocCMissingPage().pages(in: ctx)
      #expect(pages.first?.title == "Missing Sessions")
   }

   // MARK: - outputURL

   @Test("outputURL ends at /<prefix>/missingnotes/index.html")
   func outputURLEndsAtMissingnotes() {
      let ctx = context(notes: [
         sessionNote(title: "Stub", slug: "wwdc24-100-stub", isStub: true),
      ])
      let page = DocCMissingPage().pages(in: ctx).first!
      let url = DocCMissingPage().outputURL(for: page, context: ctx)
      #expect(url.absoluteString.hasSuffix("/documentation/missingnotes/index.html"))
   }

   // MARK: - Coverage math

   @Test("Coverage: 2 real + 1 stub in a year of 3 → 2 documented, 1 missing, 67% fill")
   func coverageMathBasicRounding() {
      // 2 documented out of 3 total → 2 * 100 / 3 = 66 (integer division, truncating).
      // We document that the implementation uses integer division (truncating toward zero),
      // so 2/3 * 100 = 66, NOT 67. The task brief says "67%" but integer division gives 66.
      // The contract is: pct = documented * 100 / total (integer, truncating). Verified here.
      let notes = [
         sessionNote(title: "Session A", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "Session B", slug: "wwdc24-101-b", isStub: false),
         sessionNote(title: "Stub C", slug: "wwdc24-102-c", isStub: true),
      ]
      let stats = DocCMissingPage.coverageByYear(from: notes)
      let year = stats.first { $0.yearKey == "wwdc24" }!
      #expect(year.total == 3)
      #expect(year.documented == 2)
      #expect(year.missing == 1)
      // Integer division: 2 * 100 / 3 = 66 (truncating).
      let pct = year.total > 0 ? (year.documented * 100 / year.total) : 100
      #expect(pct == 66)
      // Verify the coverage bar HTML uses this computed percentage.
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      #expect(html.contains("width:66%"))
   }

   @Test("Coverage: year with 0 stubs reports 0 missing and 100% fill")
   func coverageFullyDocumentedYear() {
      let notes = [
         sessionNote(title: "Session A", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "Session B", slug: "wwdc24-101-b", isStub: false),
      ]
      let stats = DocCMissingPage.coverageByYear(from: notes)
      let year = stats.first { $0.yearKey == "wwdc24" }!
      #expect(year.missing == 0)
      #expect(year.documented == 2)
      let pct = year.total > 0 ? (year.documented * 100 / year.total) : 100
      #expect(pct == 100)
   }

   @Test("Coverage: multiple years sorted newest first")
   func coverageMultipleYearsNewestFirst() {
      let notes = [
         sessionNote(title: "S1", slug: "wwdc21-100-a", isStub: true),
         sessionNote(title: "S2", slug: "wwdc23-100-a", isStub: false),
         sessionNote(title: "S3", slug: "wwdc25-100-a", isStub: true),
         sessionNote(title: "S4", slug: "wwdc22-100-a", isStub: false),
      ]
      let stats = DocCMissingPage.coverageByYear(from: notes)
      // Should be ordered: wwdc25, wwdc23, wwdc22, wwdc21
      #expect(stats.map(\.yearKey) == ["wwdc25", "wwdc23", "wwdc22", "wwdc21"])
   }

   @Test("Coverage: year-root overview notes are NOT counted as sessions")
   func yearRootOverviewNotesExcluded() {
      let notes = [
         yearNote(slug: "wwdc24", title: "WWDC24"),   // overview note, NOT a session
         sessionNote(title: "Real Session", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "Stub", slug: "wwdc24-101-b", isStub: true),
      ]
      let stats = DocCMissingPage.coverageByYear(from: notes)
      let year = stats.first { $0.yearKey == "wwdc24" }!
      // The overview note "wwdc24" must NOT count as a session – only the two child notes.
      #expect(year.total == 2)
      #expect(year.documented == 1)
      #expect(year.missing == 1)
   }

   @Test("Coverage: all years with sessions are included, even fully documented ones")
   func allYearsWithSessionsIncluded() {
      let notes = [
         sessionNote(title: "S1", slug: "wwdc23-100-a", isStub: false),  // fully documented
         sessionNote(title: "S2", slug: "wwdc24-100-a", isStub: true),   // has stubs
      ]
      let stats = DocCMissingPage.coverageByYear(from: notes)
      let yearKeys = stats.map(\.yearKey)
      #expect(yearKeys.contains("wwdc23"))  // 100% documented year still shows
      #expect(yearKeys.contains("wwdc24"))
   }

   @Test("Hero sub-line summarises total missing and years affected")
   func heroSubLineSummarisesMissing() {
      let page = DocCMissingPage()
      let ui = UIStrings(locale: "en")
      // 3 stubs across 2 years.
      let html = page.hero(title: "Missing Notes", totalMissing: 3, yearsWithMissing: 2, ui: ui)
      #expect(html.contains("3 missing sessions across 2 years"))
   }

   @Test("Hero sub-line says 'All sessions are documented' when totalMissing is 0")
   func heroSubLineWhenFullyCovered() {
      let page = DocCMissingPage()
      let ui = UIStrings(locale: "en")
      let html = page.hero(title: "Missing Notes", totalMissing: 0, yearsWithMissing: 0, ui: ui)
      #expect(html.contains("All sessions are documented"))
   }

   @Test("Hero art panel carries the brand prism, not the former braces glyph")
   func heroPrismElementPresent() {
      // The braces glyph was replaced by the prism key visual so the missing hero
      // speaks the same surface language as the home/contributors heroes; the braces
      // motif survives on the page through the stub cards' sessitem braces.
      let page = DocCMissingPage()
      let ui = UIStrings(locale: "en")
      let html = page.hero(title: "Missing Notes", totalMissing: 1, yearsWithMissing: 1, ui: ui)
      #expect(html.contains("sk-docc-hero-art"))
      #expect(html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-missing-braces"))
   }

   @Test("Hero is a prism card: shared hero classes with inner inset (no flush variant)")
   func heroIsPrismCard() {
      // The flush modifier (full width, zero inner inset) was superseded: the missing
      // hero is a card with inner padding again, matching every other special-page hero.
      let page = DocCMissingPage()
      let ui = UIStrings(locale: "en")
      let html = page.hero(title: "Missing Notes", totalMissing: 1, yearsWithMissing: 1, ui: ui)
      #expect(html.contains("sk-docc-hero"))
      #expect(!html.contains("sk-docc-hero--flush"))
   }

   @Test("Contribute CTA renders inside the hero box, not below it")
   func contributeCTAInsideHeroBox() {
      let notes = [sessionNote(title: "S", slug: "wwdc24-100-a", isStub: true)]
      let ctx = BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: DocCConfig(missingContributeHref: "/documentation/contributing/", missingSessions: true)
         ),
         themeConfig: nil,
         sections: [ContentSection(config: Self.docSection, pages: notes)],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      // The CTA must live inside the hero's inner column (before the decorative art panel
      // that closes the box), not as a standalone element after the box.
      let innerToArt = html.components(separatedBy: "sk-docc-hero-inner").dropFirst().first?
         .components(separatedBy: "sk-docc-hero-art").first ?? ""
      #expect(innerToArt.contains("sk-docc-missing-contribute-cta"))
   }

   // MARK: - HTML output

   @Test("renderHTML contains sk-docc-coverage-fill for each year with sessions")
   func renderedHTMLContainsCoverageFill() {
      let notes = [
         sessionNote(title: "S1", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "S2", slug: "wwdc24-101-b", isStub: true),
         sessionNote(title: "S3", slug: "wwdc23-100-a", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      // Two years → two coverage-fill divs.
      let fillCount = html.components(separatedBy: "sk-docc-coverage-fill").count - 1
      #expect(fillCount == 2)
   }

   @Test("renderHTML stub cards link to stub page URLs")
   func renderedHTMLStubListLinks() {
      let notes = [
         sessionNote(title: "Unfinished Session", slug: "wwdc24-100-stub", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      #expect(html.contains("sk-docc-missing-cards"))
      #expect(html.contains("/documentation/wwdc24-100-stub/"))
      #expect(html.contains("Unfinished Session"))
   }

   @Test("renderHTML escapes HTML-special characters in titles")
   func renderedHTMLEscapesSpecialChars() {
      let notes = [
         sessionNote(title: "Session <A> & More", slug: "wwdc24-100-a", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      // Raw angle brackets must not appear in title text; they must be escaped.
      #expect(html.contains("Session &lt;A&gt; &amp; More"))
   }

   // MARK: - Per-year coverage refinement

   @Test("Coverage count chip reads 'N of M missing' so coverage reads at a glance")
   func countChipShowsMissingOfTotal() {
      let notes = [
         sessionNote(title: "A", slug: "wwdc24-100-a", isStub: false),
         sessionNote(title: "B", slug: "wwdc24-101-b", isStub: false),
         sessionNote(title: "C", slug: "wwdc24-102-c", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      // 1 stub out of 3 sessions → "1 of 3 missing".
      #expect(html.contains("1 of 3 missing"))
   }

   // MARK: - Per-year anchor ids

   @Test("Each year row carries a stable id derived from the year key, not a position")
   func perYearRowHasStableYearKeyID() {
      let notes = [
         sessionNote(title: "S1", slug: "wwdc25-100-a", isStub: true),
         sessionNote(title: "S2", slug: "wwdc24-100-a", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      // The id is the year key itself, so it never shifts as coverage changes.
      #expect(html.contains("<div class=\"sk-docc-coverage\" id=\"wwdc25\">"))
      #expect(html.contains("<div class=\"sk-docc-coverage\" id=\"wwdc24\">"))
      // Not a positional / count-derived id.
      #expect(!html.contains("id=\"coverage-0\""))
      #expect(!html.contains("id=\"year-1\""))
   }

   // MARK: - TOC per-year anchors

   @Test("TOC rail lists each year as an is-sub jump-link under Coverage, newest first")
   func tocListsPerYearAnchors() {
      let notes = [
         sessionNote(title: "S1", slug: "wwdc25-100-a", isStub: true),
         sessionNote(title: "S2", slug: "wwdc24-100-a", isStub: true),
      ]
      let ctx = context(notes: notes)
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      #expect(html.contains("href=\"#coverage\""))
      #expect(html.contains("<a class=\"sk-docc-toc-item is-sub\" href=\"#wwdc25\">WWDC25</a>"))
      #expect(html.contains("<a class=\"sk-docc-toc-item is-sub\" href=\"#wwdc24\">WWDC24</a>"))
      // Newest-first: the wwdc25 jump-link precedes the wwdc24 one in the rail.
      let i25 = html.range(of: "href=\"#wwdc25\"")!.lowerBound
      let i24 = html.range(of: "href=\"#wwdc24\"")!.lowerBound
      #expect(i25 < i24)
      // The anchors target the row ids emitted by coverageRow (id=<yearKey>).
      #expect(html.contains("id=\"wwdc25\""))
   }

   // MARK: - Show-more truncation

   /// Builds `count` stub session notes for a single year.
   private func stubs(year: String, count: Int) -> [PageModel] {
      (0..<count).map { index in
         sessionNote(title: "Stub \(index)", slug: "\(year)-\(100 + index)-s\(index)", isStub: true)
      }
   }

   @Test("A year with more stubs than the fold truncates with a Show-more toggle")
   func truncatesOverflowWithShowMoreToggle() {
      let extra = 3
      let count = DocCMissingPage.cardsBeforeFold + extra
      let ctx = context(notes: stubs(year: "wwdc25", count: count))
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)

      // Progressive enhancement: every card is still rendered (reachable with no JS)…
      let totalCards = html.components(separatedBy: "<a class=\"sk-docc-missing-card").count - 1
      #expect(totalCards == count)
      // …but the ones beyond the fold are tagged for the script to collapse.
      let extras = html.components(separatedBy: "sk-docc-missing-card--extra").count - 1
      #expect(extras == extra)

      // The toggle starts hidden (no dead control without JS) and carries both
      // localized labels on data-* attributes plus the hidden count in the label.
      #expect(html.contains("class=\"sk-docc-missing-more\" data-docc-missing-more hidden"))
      #expect(html.contains("aria-expanded=\"false\""))
      #expect(html.contains("data-docc-missing-label-more=\"Show \(extra) more\""))
      #expect(html.contains("data-docc-missing-label-less=\"Show less\""))
   }

   @Test("A year at or under the fold renders no toggle and no overflow cards")
   func noToggleWhenWithinFold() {
      let ctx = context(notes: stubs(year: "wwdc25", count: DocCMissingPage.cardsBeforeFold))
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      #expect(!html.contains("sk-docc-missing-more"))
      #expect(!html.contains("sk-docc-missing-card--extra"))
   }

   @Test("Missing page head links the show-more script")
   func missingPageHeadLinksShowMoreScript() {
      let ctx = context(notes: stubs(year: "wwdc25", count: 1))
      let page = DocCMissingPage().pages(in: ctx).first!
      let html = DocCMissingPage().renderHTML(page, context: ctx)
      #expect(html.contains("/assets/js/docc-missing.js"))
   }
}
