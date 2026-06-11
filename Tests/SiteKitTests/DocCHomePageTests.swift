import Foundation
import Testing

@testable import SiteKit

@Suite("DocCHomePage")
struct DocCHomePageTests {
   private static let docSection = SectionConfig(
      name: "Documentation",
      slug: "documentation",
      contentDirectory: "Documentation.docc",
      urlPrefix: "documentation"
   )

   private func makeContext(sections: [ContentSection] = [], docc: DocCConfig? = nil) -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: docc
         ),
         themeConfig: nil,
         sections: sections,
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   // MARK: - pages(in:)

   @Test("pages(in:) returns exactly one synthetic page for the home URL")
   func pagesInReturnsSinglePage() {
      let context = self.makeContext()
      let pages = DocCHomePage().pages(in: context)
      #expect(pages.count == 1)
      #expect(pages.first?.slug == "documentation")
      #expect(pages.first?.title == "My Docs")
   }

   // MARK: - Hero

   @Test("renderHTML emits sk-docc-hero with title and subtitle")
   func emitsHero() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-hero"))
      #expect(html.contains("sk-docc-hero-title"))
      #expect(html.contains("My Docs"))
      #expect(html.contains("sk-docc-hero-sub"))
      #expect(html.contains("A documentation catalog."))
      #expect(html.contains("sk-docc-hero-prism"))
   }

   @Test("showPrism false adds noprism modifier and omits the prism art")
   func showPrismFalse() {
      let context = self.makeContext()
      let page = DocCHomePage(showPrism: false).pages(in: context).first!
      let html = DocCHomePage(showPrism: false).renderHTML(page, context: context)
      #expect(html.contains("sk-docc-hero--noprism"))
      #expect(!html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-hero-art"))
   }

   @Test("showPrism true (default) emits prism art and no noprism modifier")
   func showPrismTrue() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-hero--noprism"))
   }

   @Test("Hero eyebrow is emitted only when supplied")
   func heroEyebrowOptional() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!

      let withEyebrow = DocCHomePage(heroEyebrow: "Documentation").renderHTML(page, context: context)
      #expect(withEyebrow.contains("sk-docc-hero-eyebrow"))
      #expect(withEyebrow.contains("Documentation"))

      let noEyebrow = DocCHomePage().renderHTML(page, context: context)
      #expect(!noEyebrow.contains("sk-docc-hero-eyebrow"))
   }

   @Test("Hero title renders 2-tone accent span when docc.brand is configured")
   func heroTwoToneAccent() {
      let context = self.makeContext(docc: DocCConfig(
         brand: DocCBrandConfig(prefix: "My", accent: "Docs")
      ))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-hero-title-accent"))
      // Accent half must contain the accent word.
      #expect(html.contains("class=\"sk-docc-hero-title-accent\">Docs<"))
   }

   @Test("Hero title renders plain site name when no brand is configured")
   func heroPlainTitleWithoutBrand() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // No accent span emitted without a brand.
      #expect(!html.contains("sk-docc-hero-title-accent"))
      #expect(html.contains("My Docs"))
   }

   @Test("Home hero markup is byte-stable")
   func heroMarkupByteStable() {
      // Exact-markup guard: the home hero is an explicitly approved design surface.
      // Article-hero work (card/band styles, prism expansion) must never change a
      // byte of this output – if this test fails, the home hero changed shape.
      let html = DocCHomePage().hero(siteName: "WWDCNotes", subtitle: "Community notes.", eyebrow: "Community")
      #expect(html ==
         "<div class=\"sk-docc-hero\">"
         + "<div class=\"sk-docc-hero-inner\">"
         + "<span class=\"sk-docc-hero-eyebrow\">Community</span>"
         + "<h1 class=\"sk-docc-hero-title\">WWDCNotes</h1>"
         + "<p class=\"sk-docc-hero-sub\">Community notes.</p>"
         + "</div>"
         + "<div class=\"sk-docc-hero-art\" aria-hidden=\"true\"><div class=\"sk-docc-hero-prism\"></div></div>"
         + "</div>"
      )
   }

   // MARK: - Overview section

   @Test("Overview section is omitted when homeWays is nil")
   func overviewSectionOmittedWhenNoWays() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("id=\"overview\""))
      #expect(!html.contains("sk-docc-ways"))
   }

   @Test("Overview section renders with correct way count and auto-numbering")
   func overviewSectionWithWays() {
      let context = self.makeContext(docc: DocCConfig(
         homeWays: [
            DocCHomeWayConfig(title: "Search", body: "Use the search bar."),
            DocCHomeWayConfig(title: "Browse", body: "Browse by year."),
            DocCHomeWayConfig(title: "Filter", body: "Filter by framework."),
         ]
      ))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("id=\"overview\""))
      #expect(html.contains("sk-docc-ways"))
      // Three way blocks present.
      let wayCount = html.components(separatedBy: "sk-docc-way\"").count - 1
      #expect(wayCount == 3)
      // Auto-numbering produces 1, 2, 3.
      #expect(html.contains("sk-docc-way-n\">1<"))
      #expect(html.contains("sk-docc-way-n\">2<"))
      #expect(html.contains("sk-docc-way-n\">3<"))
      // Content from way items is present.
      #expect(html.contains("Search"))
      #expect(html.contains("Browse by year."))
   }

   @Test("Overview section is omitted when homeWays is an empty array")
   func overviewSectionOmittedWhenEmptyWays() {
      let context = self.makeContext(docc: DocCConfig(homeWays: []))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("id=\"overview\""))
   }

   // MARK: - Contributing section

   @Test("Contributing section is omitted when homeContributing is nil")
   func contributingSectionOmittedWhenNil() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("id=\"contributing\""))
   }

   @Test("Contributing section renders lead and link href when configured")
   func contributingSectionRendered() {
      let context = self.makeContext(docc: DocCConfig(
         homeContributing: DocCHomeContributingConfig(
            lead: "Missing something?",
            linkText: "Open a PR",
            linkHref: "https://github.com/example/repo"
         )
      ))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("id=\"contributing\""))
      #expect(html.contains("Missing something?"))
      #expect(html.contains("Open a PR"))
      #expect(html.contains("href=\"https://github.com/example/repo\""))
   }

   // MARK: - Topics section / year cards

   @Test("Topics section renders a card grid with year nodes")
   func topicsSectionRendered() {
      let wwdc24Overview = PageModel(
         title: "WWDC24",
         slug: "wwdc24",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"),
         extensions: ["doccNote": true]
      )
      let session = PageModel(
         title: "Meet FinanceKit",
         slug: "wwdc24-2023-meet-financekit",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/session.md"),
         extensions: ["doccNote": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24Overview, session])
      ])
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)

      #expect(html.contains("id=\"topics\""))
      #expect(html.contains("sk-docc-cardgrid"))
      #expect(html.contains("sk-docc-card"))
      #expect(html.contains("sk-docc-card-head"))
      #expect(html.contains("sk-docc-card-title"))
      #expect(html.contains("WWDC24"))
      #expect(html.contains("sk-docc-card-count"))
      #expect(html.contains("sk-docc-card-link"))
   }

   @Test("Year card note count is derived from non-stub children (2 notes)")
   func yearCardNoteCountReflectsNonStubChildren() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let s1 = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"), extensions: ["doccNote": true]
      )
      let s2 = PageModel(
         title: "S2", slug: "wwdc24-2-s2", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s2.md"), extensions: ["doccNote": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, s1, s2])
      ])
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // 2 non-stub sessions → "2 notes"
      #expect(html.contains("2 notes"))
   }

   @Test("Year card note count is singular for one non-stub session")
   func yearCardNoteCountSingular() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let s1 = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"), extensions: ["doccNote": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, s1])
      ])
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("1 note<"))
      #expect(!html.contains("1 notes"))
   }

   @Test("Year card note count span is omitted when all children are stubs")
   func yearCardCountHiddenWhenAllStubs() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let stub = PageModel(
         title: "Stub", slug: "wwdc24-99-stub", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, stub])
      ])
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // 0 non-stub notes → no count span emitted.
      #expect(!html.contains("sk-docc-card-count\">0"))
      #expect(!html.contains("sk-docc-card-count\">1"))
   }

   @Test("Year card renders the framework list as individual badges")
   func yearCardRendersFrameworkBadges() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let s1 = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"), extensions: ["doccNote": true]
      )
      let yearCfg = DocCYearCardConfig(apis: "Foundation Models, AlarmKit, PermissionKit")
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, s1])
      ], docc: DocCConfig(years: ["WWDC24": yearCfg]))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)

      // One badge per comma-separated framework, inside the badge-row wrapper.
      #expect(html.contains("sk-docc-api-badges"))
      #expect(html.components(separatedBy: "sk-docc-api-badge\"").count - 1 == 3)
      #expect(html.contains(">Foundation Models<"))
      #expect(html.contains(">AlarmKit<"))
      #expect(html.contains(">PermissionKit<"))
      // The comma-joined plain-text line is replaced, not kept alongside.
      #expect(!html.contains("sk-docc-card-apis"))
      #expect(!html.contains("Foundation Models, AlarmKit"))
   }

   @Test("Year card skips blank metadata blocks entirely")
   func yearCardSkipsBlankMetadata() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let s1 = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"), extensions: ["doccNote": true]
      )
      // Whitespace-only values must not produce empty elements (and their spacing).
      let yearCfg = DocCYearCardConfig(stack: "  ", blurb: " ", apis: " , ")
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, s1])
      ], docc: DocCConfig(years: ["WWDC24": yearCfg]))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)

      #expect(!html.contains("sk-docc-card-stack"))
      #expect(!html.contains("sk-docc-card-blurb"))
      #expect(!html.contains("sk-docc-api-badge"))
   }

   @Test("Stub-only year card keeps its metadata but hides the zero note count")
   func yearCardStubOnlyKeepsMetadataWithoutCount() {
      // The WWDC26 shape: real stack/apis metadata from config, but every child
      // session is still a stub – the metadata renders, the count badge does not.
      let wwdc26 = PageModel(
         title: "WWDC26", slug: "wwdc26", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc26.md"), extensions: ["doccNote": true]
      )
      let stub = PageModel(
         title: "Stub", slug: "wwdc26-1-stub", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let yearCfg = DocCYearCardConfig(stack: "Xcode 27 · iOS 27", apis: "Core AI, Evaluations")
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc26, stub])
      ], docc: DocCConfig(years: ["WWDC26": yearCfg]))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)

      #expect(html.contains("sk-docc-card-stack"))
      #expect(html.contains("Xcode 27 · iOS 27"))
      #expect(html.contains(">Core AI<"))
      #expect(!html.contains("sk-docc-card-count"))
   }

   // MARK: - Contributors mosaic card

   @Test("Contributors mosaic card is first in the grid when contributors exist")
   func contributorsMosaicCardIsFirst() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let session = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice", "bob"]]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, session])
      ], docc: DocCConfig(contributors: true))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-mosaic"))
      // The mosaic card must appear BEFORE the first year card in the source order.
      let mosaicIdx = html.range(of: "sk-docc-mosaic")!.lowerBound
      let yearCardIdx = html.range(of: "sk-docc-card-kv")!.lowerBound
      #expect(mosaicIdx < yearCardIdx, "Mosaic card must precede year cards in DOM order")
   }

   @Test("Contributors mosaic has up to 24 tiles")
   func contributorsMosaicTileCount() {
      // Two contributors → each has one note → 2 tiles.
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let session = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice", "bob"]]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, session])
      ], docc: DocCConfig(contributors: true))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      let tileCount = html.components(separatedBy: "sk-docc-mosaic-tile").count - 1
      // 2 contributors → 2 tiles (always ≤ 24).
      #expect(tileCount == 2)
   }

   @Test("Contributors mosaic is capped at 24 tiles even when more than 24 contributors exist")
   func contributorsMosaicCappedAt24() {
      // Distribute 30 distinct contributors across 30 session notes so each handle
      // appears exactly once. The mosaic should still emit exactly 24 tiles.
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let handles = (1...30).map { "contributor\($0)" }
      let sessions = handles.enumerated().map { idx, handle in
         PageModel(
            title: "Session \(idx + 1)",
            slug: "wwdc24-\(idx + 1)-session\(idx + 1)",
            htmlContent: "",
            sourcePath: URL(fileURLWithPath: "/tmp/s\(idx + 1).md"),
            extensions: ["doccNote": true, "doccContributors": [handle]]
         )
      }
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24] + sessions)
      ], docc: DocCConfig(contributors: true))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // prefix(24) must clamp the mosaic to exactly 24 tiles regardless of contributor count.
      let tileCount = html.components(separatedBy: "sk-docc-mosaic-tile").count - 1
      #expect(tileCount == 24, "Expected 24 mosaic tiles for 30 contributors, got \(tileCount)")
   }

   @Test("Contributors mosaic card is omitted when there are no contributors (feature on, no data)")
   func contributorsMosaicOmittedWhenEmpty() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24])
      ], docc: DocCConfig(contributors: true))
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("sk-docc-mosaic"))
   }

   @Test("Contributors mosaic card is suppressed on the home page when the contributors feature is off")
   func contributorsMosaicGatedOffByFeatureFlag() {
      // Contributor data present but the feature is off (default) ⇒ no mosaic and no dead
      // /contributors/ link on the home page, mirroring the gated sidebar subtree.
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let session = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice", "bob"]]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24, session])
      ])  // docc: nil ⇒ contributors off by default
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("sk-docc-mosaic"))
   }

   // MARK: - TOC rail

   @Test("TOC rail is absent when no sections are rendered")
   func tocRailAbsentWithNoSections() {
      // Empty docc: no ways, no contributing, no year notes → no Topics section.
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("sk-docc-toc"))
      // Page must not get --with-toc modifier either.
      #expect(!html.contains("sk-docc-page--with-toc"))
   }

   @Test("TOC rail contains exactly the rendered section items")
   func tocRailMatchesRenderedSections() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let session = PageModel(
         title: "S1", slug: "wwdc24-1-s1", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"), extensions: ["doccNote": true]
      )
      let context = self.makeContext(
         sections: [ContentSection(config: Self.docSection, pages: [wwdc24, session])],
         docc: DocCConfig(
            homeWays: [DocCHomeWayConfig(title: "A", body: "B")],
            homeContributing: DocCHomeContributingConfig(lead: "L", linkText: "T", linkHref: "/c/")
         )
      )
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)

      // All three sections rendered → three TOC items.
      #expect(html.contains("sk-docc-toc"))
      #expect(html.contains("href=\"#overview\""))
      #expect(html.contains("href=\"#contributing\""))
      #expect(html.contains("href=\"#topics\""))
   }

   @Test("TOC rail only includes topics when Overview and Contributing are absent")
   func tocRailTopicsOnlyWhenOthersAbsent() {
      let wwdc24 = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"), extensions: ["doccNote": true]
      )
      let context = self.makeContext(sections: [
         ContentSection(config: Self.docSection, pages: [wwdc24])
      ])
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-toc"))
      #expect(html.contains("href=\"#topics\""))
      #expect(!html.contains("href=\"#overview\""))
      #expect(!html.contains("href=\"#contributing\""))
   }

   // MARK: - Reusability invariant (empty docc)

   @Test("Empty docc block still renders a valid home with hero only – no crash, no empty sections")
   func emptyDoccRendersValidHome() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // Hero always present.
      #expect(html.contains("sk-docc-hero"))
      #expect(html.contains("My Docs"))
      // No empty section elements; optional sections completely absent.
      #expect(!html.contains("id=\"overview\""))
      #expect(!html.contains("id=\"contributing\""))
      #expect(!html.contains("id=\"topics\""))
      // No empty cardgrid.
      #expect(!html.contains("sk-docc-cardgrid"))
      // No TOC when no sections rendered.
      #expect(!html.contains("sk-docc-toc"))
      // Valid app shell still present.
      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
      #expect(html.contains("sk-docc-appbar"))
   }

   // MARK: - Sidebar chrome

   @Test("renderHTML includes app-shell, sidebar, appbar burger, and scrim chrome")
   func emitsSidebarChrome() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
      #expect(html.contains("sk-docc-appbar"))
      #expect(html.contains("sk-docc-burger"))
      #expect(html.contains("sk-docc-scrim"))
      // The DocC app shell renders its own chrome, so the generic site nav/footer
      // must NOT appear (PageShell chrome: .appShell).
      #expect(!html.contains("sk-site-header"))
      #expect(!html.contains("sk-site-footer"))
   }

   // MARK: - Footer (shell-rendered, from config)

   // The footer is rendered by DocCShell from SiteConfig.docc.footerCards /
   // docc.footerDisclaimer, so it appears on every DocC page uniformly. These tests
   // verify it is present on the home page via the shell and absent when unconfigured.

   @Test("Footer is omitted from the home page when no footerCards and no footerDisclaimer are configured")
   func footerOmittedWhenUnconfigured() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(!html.contains("sk-docc-footer"))
   }

   @Test("Footer appears on home page when footerCards are configured in SiteConfig.docc")
   func footerEmittedFromConfig() {
      let context = BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: DocCConfig(
               footerCards: [
                  DocCFooterCardConfig(
                     heading: "Contribute",
                     body: "All notes are community-maintained.",
                     ctaLabel: "Open a PR",
                     href: "https://github.com/example/repo"
                  )
               ]
            )
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-footer"))
      #expect(html.contains("sk-docc-footer-cols"))
      #expect(html.contains("sk-docc-footer-card"))
      #expect(html.contains("Contribute"))
      #expect(html.contains("All notes are community-maintained."))
      #expect(html.contains("Open a PR"))
   }

   @Test("Footer appears on home page when footerDisclaimer is configured")
   func footerEmittedFromDisclaimer() {
      let context = BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: DocCConfig(
               footerDisclaimer: "Not affiliated with any company."
            )
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-footer"))
      #expect(html.contains("sk-docc-footer-legal"))
      #expect(html.contains("sk-docc-footer-brand"))
      // Disclaimer text must appear, brand name must appear.
      #expect(html.contains("Not affiliated with any company."))
      #expect(html.contains("My Docs"))
   }

   @Test("Footer eyebrow config still flows into the hero eyebrow slot")
   func homeEyebrowFromConfig() {
      let context = BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: DocCConfig(
               homeEyebrow: "Documentation",
               footerCards: [
                  DocCFooterCardConfig(
                     heading: "Missing Sessions",
                     body: "Help us fill the gaps.",
                     ctaLabel: "See coverage",
                     href: "/missing/"
                  )
               ]
            )
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // Footer cards render via the shell.
      #expect(html.contains("sk-docc-footer-card"))
      #expect(html.contains("Missing Sessions"))
      #expect(html.contains("See coverage"))
      // The config eyebrow flows into the hero.
      #expect(html.contains("sk-docc-hero-eyebrow"))
      #expect(html.contains(">Documentation</span>"))
   }

   @Test("Home page content does not duplicate footer when both cards and disclaimer are configured")
   func footerNotDuplicatedOnHomePage() {
      let context = BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            sections: [Self.docSection],
            docc: DocCConfig(
               footerCards: [
                  DocCFooterCardConfig(heading: "Card A", body: "b", ctaLabel: "c", href: "/a/")
               ],
               footerDisclaimer: "Trademark notice."
            )
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      // Exactly one footer element in the output.
      let footerCount = html.components(separatedBy: "sk-docc-footer\"").count - 1
      #expect(footerCount == 1, "Expected exactly one footer, found \(footerCount)")
      // Both cards and legal block present.
      #expect(html.contains("Card A"))
      #expect(html.contains("sk-docc-footer-legal"))
      #expect(html.contains("Trademark notice."))
   }

   // MARK: - Output URL

   @Test("outputURL writes to /<urlPrefix>/index.html")
   func outputURLUnderPrefix() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let url = DocCHomePage().outputURL(for: page, context: context)
      #expect(url.path.hasSuffix("/documentation/index.html"))
   }

   @Test("Canonical URL in head points at the section root")
   func canonicalURL() {
      let context = self.makeContext()
      let page = DocCHomePage().pages(in: context).first!
      let html = DocCHomePage().renderHTML(page, context: context)
      #expect(html.contains("https://example.com/documentation/"))
   }
}
