import Foundation
import Testing

@testable import SiteKit

@Suite("DocCYearListingPage")
struct DocCYearListingPageTests {
   private static let docSection = SectionConfig(
      name: "Documentation",
      slug: "documentation",
      contentDirectory: "Documentation.docc",
      urlPrefix: "documentation"
   )

   private func note(
      title: String,
      slug: String,
      summary: String? = nil,
      extras: [String: any Sendable] = [:]
   ) -> PageModel {
      var extensions: [String: any Sendable] = ["doccNote": true]
      for (key, value) in extras { extensions[key] = value }
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: summary,
         pageType: .article,
         extensions: extensions
      )
   }

   private func context(notes: [PageModel], doccConfig: DocCConfig? = nil) -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            docc: doccConfig
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

   @Test("One year page per year that has sessions but no overview note")
   func oneYearPagePerYear() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
         self.note(title: "What's New", slug: "wwdc24-101-whats-new"),
         self.note(title: "Older", slug: "wwdc23-50-older"),
      ])
      let pages = DocCYearListingPage().pages(in: ctx)
      // Two distinct years, newest-first.
      #expect(pages.map(\.slug) == ["wwdc24", "wwdc23"])
   }

   @Test("Years with an overview note are owned and use the note's title")
   func ownsYearsWithOverviewNote() {
      let ctx = self.context(notes: [
         self.note(title: "WWDC24 Highlights", slug: "wwdc24"),  // overview catalog note
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
         self.note(title: "Older", slug: "wwdc23-50-older"),
      ])
      let pages = DocCYearListingPage().pages(in: ctx)
      // Both years are owned by this renderer; the overview note no longer cedes the
      // URL to DocCArticlePage (which now excludes claimed year roots).
      #expect(pages.map(\.slug) == ["wwdc24", "wwdc23"])
      // The wwdc24 page adopts the overview note's title (not the synthesized key).
      let wwdc24 = pages.first { $0.slug == "wwdc24" }
      #expect(wwdc24?.title == "WWDC24 Highlights")
      // A year without an overview note falls back to the uppercased key.
      let wwdc23 = pages.first { $0.slug == "wwdc23" }
      #expect(wwdc23?.title == "WWDC23")
   }

   @Test("Loose (non-WWDC) pages do not produce year listings")
   func ignoresLoosePages() {
      let ctx = self.context(notes: [
         self.note(title: "Contributing", slug: "contributing"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let pages = DocCYearListingPage().pages(in: ctx)
      #expect(pages.map(\.slug) == ["wwdc24"])
   }

   // MARK: - renderHTML – new page shape

   @Test("Year page title block emits eyebrow, h1, and stack when docc.years entry exists")
   func yearTitleBlock() {
      let yearCfg = DocCYearCardConfig(stack: "Swift 6 · iOS 18", blurb: nil, apis: nil, keyVisual: nil)
      let docc = DocCConfig(years: ["WWDC24": yearCfg])
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ], doccConfig: docc)
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Eyebrow "Year overview" must appear somewhere in the title block.
      #expect(html.contains("Year overview"))
      // h1 carries the year title.
      #expect(html.contains("sk-docc-yeartitle-h"))
      #expect(html.contains("WWDC24"))
      // Stack subtitle rendered from docc.years.
      #expect(html.contains("sk-docc-yeartitle-sub"))
      #expect(html.contains("Swift 6 · iOS 18"))
   }

   @Test("Year page emits yearstats with derived note, session, and topic counts")
   func yearStats() {
      // Distinct counts (1 note, 2 sessions, 3 topic groups) so each <b>N</b>
      // assertion uniquely pins one stat to its label and cannot pass by coincidence.
      let groups: [DocCTopicGroup] = [
         DocCTopicGroup(title: "Day One", slugs: ["wwdc24-101-keynote"]),
         DocCTopicGroup(title: "New Tools", slugs: ["wwdc24-100-meet-x"]),
         DocCTopicGroup(title: "Labs", slugs: ["wwdc24-102-lab"]),
      ]
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24", extras: ["doccTopicGroups": groups]),
         self.note(title: "Keynote", slug: "wwdc24-101-keynote"),
         // Stub: counts as a session but not a note.
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x", extras: ["doccIsStub": true]),
         // Stub: counts as a session but not a note.
         self.note(title: "Lab: SwiftUI", slug: "wwdc24-102-lab", extras: ["doccIsStub": true]),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Stats block is present.
      #expect(html.contains("sk-docc-yearstats"))
      // 1 real note, 3 sessions, 3 topic groups – each count is distinct.
      let notesLabel = UIStrings(locale: "en").string(for: .doccYearStatsNotes)
      let sessLabel = UIStrings(locale: "en").string(for: .doccYearStatsSessions)
      let topicsLabel = UIStrings(locale: "en").string(for: .doccYearStatsTopics)
      #expect(html.contains("<b>1</b> \(notesLabel)"))
      #expect(html.contains("<b>3</b> \(sessLabel)"))
      #expect(html.contains("<b>3</b> \(topicsLabel)"))
   }

   @Test("Year detail intro renders the framework list as badges between lead and stats")
   func yearDetailRendersFrameworkBadges() throws {
      let yearCfg = DocCYearCardConfig(
         stack: "Xcode 16 · Swift 6",
         blurb: "Swift 6 data-race safety and more.",
         apis: "Swift Testing, FinanceKit, TabletopKit"
      )
      let docc = DocCConfig(years: ["WWDC24": yearCfg])
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ], doccConfig: docc)
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Badges match the card grid's framework-badge markup, one per entry.
      #expect(html.contains("sk-docc-api-badges"))
      #expect(html.components(separatedBy: "sk-docc-api-badge\"").count - 1 == 3)
      #expect(html.contains(">Swift Testing<"))
      #expect(html.contains(">FinanceKit<"))
      #expect(html.contains(">TabletopKit<"))
      // The badge row sits inside the intro section: after the lead, before the stats.
      let leadIdx = try #require(html.range(of: "sk-docc-home-lead")).lowerBound
      let badgesIdx = try #require(html.range(of: "sk-docc-api-badges")).lowerBound
      let statsIdx = try #require(html.range(of: "sk-docc-yearstats")).lowerBound
      #expect(leadIdx < badgesIdx && badgesIdx < statsIdx)
   }

   @Test("Year detail emits no badge row when apis is missing or blank")
   func yearDetailSkipsBlankApis() {
      let yearCfg = DocCYearCardConfig(stack: "Xcode 16", blurb: "A year.", apis: "  ,  ")
      let docc = DocCConfig(years: ["WWDC24": yearCfg])
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ], doccConfig: docc)
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)
      #expect(!html.contains("sk-docc-api-badges"))
      #expect(!html.contains("sk-docc-api-badge"))
   }

   @Test("Year banner img is present when docc.years[label].keyVisual is set")
   func bannerWithExplicitKeyVisual() {
      let yearCfg = DocCYearCardConfig(stack: nil, blurb: nil, apis: nil, keyVisual: "/assets/MyYear.jpeg")
      let docc = DocCConfig(years: ["WWDC24": yearCfg])
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ], doccConfig: docc)
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-yearbanner"))
      #expect(html.contains("/assets/MyYear.jpeg"))
   }

   @Test("Year banner uses convention path /assets/<label>.jpeg when no explicit keyVisual")
   func bannerConventionPath() {
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Banner block is always emitted; the onerror handler removes it at runtime if 404.
      #expect(html.contains("sk-docc-yearbanner"))
      // Convention path uses the page title as the label.
      #expect(html.contains("/assets/WWDC24.jpeg"))
   }

   @Test("Topic-group sections carry ids matching their slugified title")
   func topicGroupSectionIds() {
      let groups: [DocCTopicGroup] = [
         DocCTopicGroup(title: "First Day Events", slugs: ["wwdc24-101-keynote"]),
         DocCTopicGroup(title: "New Tools", slugs: ["wwdc24-100-meet-x"]),
      ]
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24", extras: ["doccTopicGroups": groups]),
         self.note(title: "Keynote", slug: "wwdc24-101-keynote"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Sections carry slugified ids derived from the group title.
      #expect(html.contains("id=\"first-day-events\""))
      #expect(html.contains("id=\"new-tools\""))
   }

   @Test("TOC rail lists exactly the rendered topic-group sections")
   func tocRailMatchesGroups() {
      let groups: [DocCTopicGroup] = [
         DocCTopicGroup(title: "First Day Events", slugs: ["wwdc24-101-keynote"]),
         DocCTopicGroup(title: "New Tools", slugs: ["wwdc24-100-meet-x"]),
      ]
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24", extras: ["doccTopicGroups": groups]),
         self.note(title: "Keynote", slug: "wwdc24-101-keynote"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first { $0.slug == "wwdc24" }!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // TOC rail is present and carries both group anchors.
      #expect(html.contains("sk-docc-toc"))
      #expect(html.contains("href=\"#first-day-events\""))
      #expect(html.contains("href=\"#new-tools\""))
      // Title of the TOC rail is the year label.
      #expect(html.contains("sk-docc-toc-title"))
   }

   @Test("No TOC rail when the year has no topic groups")
   func noTocRailWithoutGroups() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
         self.note(title: "What's New", slug: "wwdc24-101-whats-new"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      #expect(!html.contains("sk-docc-toc"))
   }

   @Test("Session row renders the framework icon slot (data-framework attribute)")
   func sessionRowFrameworkIcon() {
      let icon = DocCFrameworkIcon(glyph: "fa-brands fa-swift", colors: ["#f05138", "#c03120"])
      let docc = DocCConfig(frameworks: ["swift": icon])
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x", extras: ["doccFramework": "swift"]),
      ], doccConfig: docc)
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Framework icon slot carries the data-framework attribute.
      #expect(html.contains("data-framework=\"swift\""))
      #expect(html.contains("sk-docc-sessitem-icon"))
   }

   @Test("Session row with no framework gets neutral icon placeholder")
   func sessionRowNeutralIcon() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Icon slot is still present but carries no data-framework attribute.
      #expect(html.contains("sk-docc-sessitem-icon"))
      #expect(!html.contains("data-framework="))
   }

   @Test("Stub session row has is-stub class, Needs notes pill, and duration")
   func stubSessionRow() {
      let ctx = self.context(notes: [
         self.note(
            title: "Placeholder",
            slug: "wwdc24-200-placeholder",
            extras: ["doccIsStub": true, "doccMinutes": 45]
         ),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-sessitem is-stub"))
      #expect(html.contains("sk-docc-stub-pill"))
      #expect(html.contains("Needs notes"))
      #expect(html.contains("45 min"))
   }

   @Test("Renders a session list with rows for each session of the year")
   func rendersSessionList() {
      let ctx = self.context(notes: [
         self.note(
            title: "Meet X",
            slug: "wwdc24-100-meet-x",
            summary: "Learn about X.",
            extras: ["doccTitleHeading": "WWDC24", "doccMinutes": 14]
         ),
         self.note(title: "What's New", slug: "wwdc24-101-whats-new", summary: "The new stuff."),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-sesslist"))
      #expect(html.contains("sk-docc-sessitem"))
      #expect(html.contains("sk-docc-sessitem-title"))
      #expect(html.contains("Meet X"))
      #expect(html.contains("What's New"))
      // Eyebrow combines the title heading and the session id parsed from the slug.
      #expect(html.contains("WWDC24 · 100"))
      // Reading time renders when present.
      #expect(html.contains("14 min"))
      // Abstract becomes the blurb.
      #expect(html.contains("Learn about X."))
      // Links point at the session note URLs.
      #expect(html.contains("href=\"/documentation/wwdc24-100-meet-x/\""))
   }

   @Test("Year page carries the DocC sidebar chrome")
   func rendersChrome() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)
      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
      // New year page uses yeartitle block instead of compact hero.
      #expect(html.contains("sk-docc-yeartitle"))
   }

   @Test("Empty year renders graceful state with no TOC rail")
   func emptyYearGracefulState() {
      // A year page is only generated when sessions exist, so we simulate a year where
      // session notes are absent by calling emptyYearPage directly.
      let ctx = self.context(notes: [])
      let fakePage = PageModel(
         title: "WWDC23",
         slug: "wwdc23",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc23.docc"),
         pageType: .staticPage
      )
      let allNotes = DocCYearListingPage.doccNotes(in: ctx)
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: "documentation")
      let sidebar = DocCSidebarRenderer.make(from: ctx).render(tree: tree, currentSlug: "wwdc23")
      let html = DocCYearListingPage().emptyYearPage(
         page: fakePage,
         yearLabel: "WWDC23",
         sidebar: sidebar,
         prefix: "documentation",
         context: ctx
      )
      // Eyebrow present, no TOC rail.
      #expect(html.contains("Year overview"))
      #expect(html.contains("WWDC23"))
      #expect(!html.contains("sk-docc-toc"))
   }

   @Test("Year with no docc.years entry still renders a valid page")
   func yearWithNoDocCYearsEntry() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Page must render without crashing, contain the title, and the yearstats block.
      #expect(html.contains("sk-docc-yeartitle-h"))
      #expect(html.contains("WWDC24"))
      #expect(html.contains("sk-docc-yearstats"))
   }

   // MARK: - outputURL

   @Test("outputURL writes the year page under /<prefix>/<year>/index.html")
   func outputURLPath() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let url = DocCYearListingPage().outputURL(for: page, context: ctx)
      #expect(url.path.hasSuffix("/documentation/wwdc24/index.html"))
   }

   // MARK: - Topic grouping

   @Test("Renders grouped sections when the overview note has topic groups")
   func rendersTopicGroups() {
      let groups: [DocCTopicGroup] = [
         DocCTopicGroup(title: "First Day Events", slugs: ["wwdc24-101-keynote"]),
         DocCTopicGroup(title: "New Tools", slugs: ["wwdc24-100-meet-x"]),
      ]
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24", extras: ["doccTopicGroups": groups]),
         self.note(title: "Keynote", slug: "wwdc24-101-keynote"),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Grouped layout: topic group containers and their titles are present.
      #expect(html.contains("sk-docc-topicgroup"))
      #expect(html.contains("sk-docc-topicgroup-title"))
      #expect(html.contains("First Day Events"))
      #expect(html.contains("New Tools"))
      // Individual sessions appear inside their groups.
      #expect(html.contains("Keynote"))
      #expect(html.contains("Meet X"))
   }

   @Test("Year without topic groups renders a flat session list")
   func rendersFlatListWithoutGroups() {
      let ctx = self.context(notes: [
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
         self.note(title: "What's New", slug: "wwdc24-101-whats-new"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      let html = DocCYearListingPage().renderHTML(page, context: ctx)

      // Flat list: the main sesslist wrapper is present, but no topic group structure.
      #expect(html.contains("sk-docc-sesslist"))
      #expect(!html.contains("sk-docc-topicgroup"))
      #expect(!html.contains("sk-docc-topicgroup-title"))
   }

   @Test("Unknown slug in a topic group is tolerated (skipped, no crash)")
   func unknownSlugTolerated() {
      let groups: [DocCTopicGroup] = [
         DocCTopicGroup(title: "First Day Events", slugs: ["wwdc24-999-nonexistent", "wwdc24-100-meet-x"]),
      ]
      let ctx = self.context(notes: [
         self.note(title: "WWDC24", slug: "wwdc24", extras: ["doccTopicGroups": groups]),
         self.note(title: "Meet X", slug: "wwdc24-100-meet-x"),
      ])
      let page = DocCYearListingPage().pages(in: ctx).first!
      // Must not crash; the unknown slug is skipped gracefully.
      let html = DocCYearListingPage().renderHTML(page, context: ctx)
      #expect(html.contains("First Day Events"))
      #expect(html.contains("Meet X"))
      // The non-existent session slug produces no broken link.
      #expect(!html.contains("wwdc24-999-nonexistent"))
   }

   // MARK: - eyebrow / session id helpers

   @Test("sessionID parses the id segment after the year prefix")
   func sessionIDParsing() {
      #expect(DocCYearListingPage.sessionID(from: "wwdc24-10060-meet-x") == "10060")
      #expect(DocCYearListingPage.sessionID(from: "wwdc24") == nil)
      #expect(DocCYearListingPage.sessionID(from: "contributing") == nil)
   }

   // MARK: - groupAnchorID helper

   @Test("groupAnchorID converts group titles to stable lowercase anchor ids")
   func groupAnchorID() {
      #expect(DocCYearListingPage.groupAnchorID("First Day Events") == "first-day-events")
      #expect(DocCYearListingPage.groupAnchorID("New Tools & Frameworks") == "new-tools-frameworks")
      #expect(DocCYearListingPage.groupAnchorID("SwiftUI") == "swiftui")
   }
}
