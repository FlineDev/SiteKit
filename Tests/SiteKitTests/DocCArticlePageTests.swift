import Foundation
import Testing

@testable import SiteKit

@Suite("DocCArticlePage")
struct DocCArticlePageTests {
   private func doccPage() -> PageModel {
      PageModel(
         title: "Meet FinanceKit",
         slug: "wwdc24-2023-meet-financekit",
         htmlContent: "<h2>Overview</h2><p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/WWDC24/WWDC24-2023-Meet-FinanceKit.md"),
         summary: "Learn how FinanceKit works.",
         extensions: [
            "doccNote": true,
            "doccTitleHeading": "WWDC24",
            "doccCTAURL": "https://developer.apple.com/videos/play/wwdc2024/2023",
            "doccCTALabel": "Watch Video (23 min)",
            "doccContributors": ["Jeehut"],
         ]
      )
   }

   @Test("Assembles title, abstract, CTA, contributors, and body")
   func assemblesChrome() {
      let page = self.doccPage()
      let html = DocCArticlePage().articleContent(for: page, bodyHTML: page.htmlContent)
      // No eyebrow; the h1 is the bare title (the session number lives in the breadcrumb on the
      // full render path, which this overload does not produce).
      #expect(!html.contains("sk-docc-eyebrow"))
      #expect(html.contains("<h1 class=\"sk-docc-title\">Meet FinanceKit</h1>"))
      #expect(html.contains("sk-docc-abstract") && html.contains("Learn how FinanceKit works."))
      #expect(html.contains("sk-docc-cta") && html.contains("Watch Video (23 min)"))
      #expect(html.contains("github.com/Jeehut"))
      #expect(html.contains("<h2>Overview</h2><p>Body</p>"))
   }

   @Test("Renders the Community↔AI switcher when the note has an AI variant")
   func rendersVariantSwitcher() {
      let page = PageModel(
         title: "X", slug: "wwdc24-1-x", htmlContent: "<p>Community</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccAIVariant": "<p>AI variant</p>"]
      )
      let html = DocCArticlePage().articleContent(for: page, bodyHTML: page.htmlContent)
      #expect(html.contains("sk-docc-variants"))
      #expect(html.contains("<p>Community</p>"))
      #expect(html.contains("<p>AI variant</p>"))
   }

   @Test("Omits CTA and contributors when their metadata is absent")
   func omitsAbsentChrome() {
      let bare = PageModel(
         title: "Bare",
         slug: "bare",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/bare.md"),
         extensions: ["doccNote": true]
      )
      let html = DocCArticlePage().articleContent(for: bare, bodyHTML: bare.htmlContent)
      #expect(!html.contains("sk-docc-cta"))
      #expect(!html.contains("sk-docc-contributors"))
      #expect(html.contains("<h1 class=\"sk-docc-title\">Bare</h1>"))
   }

   @Test("Routes notes under the section URL prefix, matching doc: resolution")
   func routesUnderSectionPrefix() throws {
      let docSection = SectionConfig(
         name: "Documentation",
         slug: "documentation",
         contentDirectory: "Docs",
         urlPrefix: "documentation"
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = PageModel(
         title: "Foo",
         slug: "wwdc24-10132-foo",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true]
      )

      // The page is written under /documentation/, not the default /blog/.
      let url = DocCArticlePage().outputURL(for: page, context: context)
      #expect(url.path.hasSuffix("/documentation/wwdc24-10132-foo/index.html"))
      #expect(!url.path.contains("/blog/"))

      // The enricher resolves a <doc:> link to the SAME path → the link is live.
      let enriched = try DocCCrossReferenceEnricher(urlPrefix: "documentation").enrich(
         PageModel(
            title: "L",
            slug: "l",
            htmlContent: "<a href=\"doc:WWDC24-10132-Foo\">doc:WWDC24-10132-Foo</a>",
            sourcePath: URL(fileURLWithPath: "/tmp/l.md")
         )
      )
      #expect(enriched.htmlContent.contains("href=\"/documentation/wwdc24-10132-foo/\""))
   }

   @Test("renderHTML wires the doc-tree sidebar into the page, current page active")
   func wiresSidebar() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let session = PageModel(
         title: "Meet X", slug: "wwdc24-10060-meet-x", htmlContent: "<p>a</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/a.md"), extensions: ["doccNote": true]
      )
      let overview = PageModel(
         title: "WWDC24", slug: "wwdc24", htmlContent: "<p>b</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/b.md"), extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [session, overview])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let html = DocCArticlePage().renderHTML(session, context: context)
      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
      #expect(html.contains("sk-docc-article"))
      #expect(html.contains("WWDC24"))
      // The current session is the active page in the sidebar.
      #expect(html.contains("href=\"/documentation/wwdc24-10060-meet-x/\" aria-current=\"page\""))

      // Head: canonical points at the /documentation/ path (not the /blog/ default),
      // and the DocC stylesheet is linked.
      #expect(html.contains("https://example.com/documentation/wwdc24-10060-meet-x/"))
      #expect(!html.contains("/blog/"))
      #expect(html.contains("/assets/css/docc.css"))
      // The client search script is linked (deferred).
      #expect(html.contains("/assets/search/docc-search.js"))
      // The off-canvas sidebar toggle script is linked (deferred).
      #expect(html.contains("/assets/js/docc-sidebar.js"))

      // The mobile off-canvas chrome is in the DOM: a hamburger button, the scrim,
      // and the open/close hooks the toggle JS targets.
      #expect(html.contains("class=\"sk-docc-burger\""))
      #expect(html.contains("data-docc-sidebar-open"))
      #expect(html.contains("aria-expanded=\"false\""))
      #expect(html.contains("aria-controls=\"sk-docc-sidebar\""))
      #expect(html.contains("data-docc-sidebar-scrim"))
      #expect(html.contains("class=\"sk-docc-scrim\""))
   }

   @Test("Session note renders the corrections CTA between the body and Written By")
   func correctionsCTAOnSessionNote() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let session = PageModel(
         title: "Meet X", slug: "wwdc24-10060-meet-x", htmlContent: "<p>body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/a.md"),
         extensions: ["doccNote": true, "doccContributors": ["Jeehut"]]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [session])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let html = DocCArticlePage().renderHTML(session, context: context)
      #expect(html.contains("sk-docc-corrections"))
      // The exact production wording, the whole line acting as the link to the contributing guide.
      #expect(html.contains("Missing anything? Corrections? Contributions are welcome!"))
      #expect(html.contains("href=\"/documentation/contributing/\""))

      // Placement: after the article body, before the Written By section.
      let bodyIdx = html.range(of: "sk-article-body")?.lowerBound
      let ctaIdx = html.range(of: "sk-docc-corrections")?.lowerBound
      let writtenByIdx = html.range(of: "Written By")?.lowerBound
      if let b = bodyIdx, let c = ctaIdx, let w = writtenByIdx {
         #expect(b < c)
         #expect(c < w)
      } else {
         Issue.record("Expected body, corrections CTA, and Written By to all be present")
      }
   }

   @Test("Stub note renders no corrections CTA (the empty-state already carries the contribute path)")
   func noCorrectionsCTAOnStub() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let stub = PageModel(
         title: "Stub", slug: "wwdc24-10061-stub", htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/s.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [stub])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let html = DocCArticlePage().renderHTML(stub, context: context)
      #expect(html.contains("sk-docc-empty"))
      #expect(!html.contains("sk-docc-corrections"))
   }

   @Test("Guide article without a year key renders no corrections CTA")
   func noCorrectionsCTAOnGuide() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let guide = PageModel(
         title: "Getting Started", slug: "getting-started", htmlContent: "<p>guide</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/g.md"),
         extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [guide])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let html = DocCArticlePage().renderHTML(guide, context: context)
      #expect(!html.contains("sk-docc-corrections"))
   }

   @Test("pages(in:) selects only notes the DocC loader produced")
   func selectsDocCNotes() {
      let docc = self.doccPage()
      let blog = PageModel(
         title: "A blog post",
         slug: "post",
         htmlContent: "<p>p</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/post.md")
      )
      let section = ContentSection(
         config: SectionConfig(name: "Docs", slug: "docs", contentDirectory: "Docs", urlPrefix: "docs"),
         pages: [docc, blog]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Test", baseURL: "https://example.com"),
         themeConfig: nil,
         sections: [section],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let selected = DocCArticlePage().pages(in: context)
      #expect(selected.count == 1)
      #expect(selected.first?.slug == "wwdc24-2023-meet-financekit")
   }

   @Test("pages(in:) excludes year-root overview notes and contributors note claimed by specialized pages")
   func excludesReservedSpecialPageNotes() {
      // A mixed catalog: one year-root overview note, one session, one contributors
      // note, and one ordinary article-style note. DocCArticlePage must render the
      // session and the ordinary note, but NOT the year-root or contributors note –
      // those URLs are owned by DocCYearListingPage and DocCContributorsPage.
      let docSection = SectionConfig(
         name: "Documentation",
         slug: "documentation",
         contentDirectory: "Documentation.docc",
         urlPrefix: "documentation"
      )

      func doccNote(slug: String, title: String) -> PageModel {
         PageModel(
            title: title,
            slug: slug,
            htmlContent: "<p>body</p>",
            sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
            extensions: ["doccNote": true]
         )
      }

      let yearRoot    = doccNote(slug: "wwdc24",          title: "WWDC24 Overview")
      let session     = doccNote(slug: "wwdc24-100-meet-x", title: "Meet X")
      let contributors = doccNote(slug: "contributors",   title: "Contributors")
      let article     = doccNote(slug: "getting-started", title: "Getting Started")

      let section = ContentSection(config: docSection, pages: [yearRoot, session, contributors, article])
      let context = BuildContext(
         // Contributors feature on, so DocCContributorsPage claims the contributors note's URL.
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection], docc: DocCConfig(contributors: true)),
         themeConfig: nil,
         sections: [section],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let selected = DocCArticlePage().pages(in: context)
      let slugs = selected.map(\.slug)

      // Session and ordinary article notes are rendered by DocCArticlePage.
      #expect(slugs.contains("wwdc24-100-meet-x"))
      #expect(slugs.contains("getting-started"))

      // Year-root and contributors are claimed by specialized pages – must be excluded.
      #expect(!slugs.contains("wwdc24"))
      #expect(!slugs.contains("contributors"))
   }

   @Test("pages(in:) renders a contributors note as a plain article when the contributors feature is off")
   func rendersContributorsNoteWhenFeatureOff() {
      // Generic docs default (contributors off): no DocCContributorsPage is registered, so a
      // literal Contributors.md note must fall back to DocCArticlePage rather than vanish.
      let docSection = SectionConfig(
         name: "Documentation",
         slug: "documentation",
         contentDirectory: "Documentation.docc",
         urlPrefix: "documentation"
      )
      func doccNote(slug: String, title: String) -> PageModel {
         PageModel(
            title: title,
            slug: slug,
            htmlContent: "<p>body</p>",
            sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
            extensions: ["doccNote": true]
         )
      }
      let contributors = doccNote(slug: "contributors", title: "Contributors")
      let article = doccNote(slug: "getting-started", title: "Getting Started")
      let section = ContentSection(config: docSection, pages: [contributors, article])
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),  // docc: nil ⇒ contributors off
         themeConfig: nil,
         sections: [section],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let slugs = DocCArticlePage().pages(in: context).map(\.slug)
      #expect(slugs.contains("contributors"))
      #expect(slugs.contains("getting-started"))
   }

   // ── On-this-page TOC ──────────────────────────────────────────────────────

   @Test("onThisPageTOC builds a rail from h2/h3 headings and injects stable ids")
   func buildsTOC() throws {
      let body = "<h2>Overview</h2><p>x</p><h3>The @Test Macro</h3><h2>Suites</h2>"
      let (rebuilt, tocOptional) = DocCArticlePage().onThisPageTOC(fromBodyHTML: body)
      let toc = try #require(tocOptional)

      // One item per heading (3), the h3 marked as a sub-item.
      #expect(toc.components(separatedBy: "sk-docc-toc-item").count - 1 == 3)
      #expect(toc.contains("sk-docc-toc-item is-sub"))
      #expect(toc.contains("On this page"))
      // Anchors point at slugified ids.
      #expect(toc.contains("href=\"#overview\""))
      #expect(toc.contains("href=\"#the-test-macro\""))
      #expect(toc.contains("href=\"#suites\""))
      // The body gained matching ids on its headings (the TOC anchors resolve).
      #expect(rebuilt.contains("<h2 id=\"overview\">Overview</h2>"))
      #expect(rebuilt.contains("<h3 id=\"the-test-macro\">The @Test Macro</h3>"))
      #expect(rebuilt.contains("<h2 id=\"suites\">Suites</h2>"))
   }

   @Test("onThisPageTOC returns no rail (body untouched) for fewer than two headings")
   func shortNoteNoTOC() {
      let (rebuilt, toc) = DocCArticlePage().onThisPageTOC(fromBodyHTML: "<h2>Only</h2><p>x</p>")
      #expect(toc == nil)
      #expect(rebuilt == "<h2>Only</h2><p>x</p>")
   }

   @Test("onThisPageTOC ignores h1/h4 headings (only h2/h3 feed the rail)")
   func ignoresOtherHeadingLevels() {
      let body = "<h1>Top</h1><h4>Aside</h4><p>x</p>"
      let (rebuilt, toc) = DocCArticlePage().onThisPageTOC(fromBodyHTML: body)
      #expect(toc == nil)            // no h2/h3 → no rail
      #expect(rebuilt == body)        // body untouched, no ids injected into h1/h4
   }

   @Test("onThisPageTOC reuses existing heading ids and de-dupes repeated slugs")
   func reusesAndDedupes() throws {
      let body = "<h2 id=\"custom\">Alpha</h2><h2>Repeat</h2><h2>Repeat</h2>"
      let (rebuilt, tocOptional) = DocCArticlePage().onThisPageTOC(fromBodyHTML: body)
      let toc = try #require(tocOptional)

      #expect(toc.contains("href=\"#custom\""))   // existing id reused, not regenerated
      #expect(toc.contains("href=\"#repeat\""))
      #expect(toc.contains("href=\"#repeat-2\""))  // duplicate heading text → numeric suffix
      #expect(rebuilt.contains("<h2 id=\"custom\">Alpha</h2>"))
      #expect(rebuilt.contains("<h2 id=\"repeat\">Repeat</h2>"))
      #expect(rebuilt.contains("<h2 id=\"repeat-2\">Repeat</h2>"))
   }

   @Test("renderHTML adds the TOC rail + col-main for notes with multiple headings")
   func renderHTMLWithTOC() {
      let context = Self.singleNoteContext(
         slug: "wwdc25-101-multi",
         htmlContent: "<h2>One</h2><p>x</p><h2>Two</h2><h3>Two-A</h3>"
      )
      let note = context.sections[0].pages[0]
      let html = DocCArticlePage().renderHTML(note, context: context)
      #expect(html.contains("sk-docc-page--with-toc"))
      #expect(html.contains("sk-docc-toc"))
      #expect(html.contains("sk-docc-col-main"))
      #expect(html.contains("href=\"#one\""))
   }

   @Test("renderHTML includes a TOC rail for notes with one heading when contributors are present")
   func renderHTMLTOCWithSingleHeading() {
      // A note with one body heading and at least one contributor gets ≥2 TOC items
      // (body heading + Written By + Related), so the TOC rail is rendered.
      // Without contributors the heading extraction returns nil for <2 headings,
      // leaving only Related – 1 item – which suppresses the rail (correct behavior).
      let note = PageModel(
         title: "Note", slug: "wwdc25-102-short",
         htmlContent: "<h2>Solo</h2><p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc25-102-short.md"),
         extensions: ["doccNote": true, "doccContributors": ["Jeehut"]]
      )
      let context = Self.singleNoteContext(slug: note.slug, htmlContent: note.htmlContent, note: note)
      let html = DocCArticlePage().renderHTML(note, context: context)
      // Written By + Related are in the TOC when the note has contributors.
      #expect(html.contains("sk-docc-toc"))
      #expect(html.contains("href=\"#writtenby\""))
      #expect(html.contains("href=\"#related\""))
   }

   // MARK: Article-page sections

   // MARK: Breadcrumb

   @Test("Breadcrumb emits site name, year label, and session number (not the title) in order")
   func breadcrumbSegments() {
      let page = PageModel(
         title: "Meet FinanceKit",
         slug: "wwdc24-2023-meet-financekit",
         htmlContent: "<h2>Intro</h2><p>x</p><h2>Details</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC24 · Session 2023"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // Isolate the breadcrumb nav so the assertions test the crumbs, not the h1 or body.
      let crumb = Self.breadcrumbHTML(in: html)
      #expect(html.contains("sk-docc-breadcrumb"))
      #expect(crumb.contains("Docs"))        // site name
      #expect(crumb.contains("WWDC24"))      // year label extracted from doccTitleHeading
      #expect(crumb.contains("is-current"))  // current crumb marker
      // The trailing crumb is the session number "2023" (from the slug), not a repeat of the title.
      #expect(crumb.contains(">2023</span>"))
      #expect(!crumb.contains("Meet FinanceKit"))
   }

   @Test("Breadcrumb year href points at the year prefix path")
   func breadcrumbYearHref() {
      let page = PageModel(
         title: "Keynote",
         slug: "wwdc25-101-keynote",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25 · Session 101"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(html.contains("href=\"/documentation/wwdc25/\""))
   }

   // MARK: Meta row

   @Test("Meta row emits Watch Video button when doccCTAURL is present")
   func metaRowWatchButton() {
      let page = PageModel(
         title: "X", slug: "wwdc25-101-x",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: [
            "doccNote": true,
            "doccCTAURL": "https://developer.apple.com/videos/play/wwdc2025/101",
            "doccMinutes": 92,
         ]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-watch"))
      #expect(html.contains("Watch Video (92 min)"))
   }

   @Test("Meta row emits platform badges from page.tags")
   func metaRowBadges() {
      let page = PageModel(
         title: "X", slug: "wwdc25-200-x",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         tags: ["iOS", "macOS"],
         extensions: ["doccNote": true]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(html.contains("sk-docc-badge"))
      #expect(html.contains("iOS") && html.contains("macOS"))
   }

   @Test("Meta row includes read time for non-stub notes and omits it for stubs")
   func metaRowReadTime() {
      let nonStub = PageModel(
         title: "X", slug: "wwdc25-201-x",
         htmlContent: "<h2>A</h2><p>lots of content here to register a read time</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true]
      )
      let stub = PageModel(
         title: "Y", slug: "wwdc25-202-y",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/y.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let nonStubContext = Self.singleNoteContext(slug: nonStub.slug, htmlContent: nonStub.htmlContent, note: nonStub)
      let stubContext = Self.singleNoteContext(slug: stub.slug, htmlContent: stub.htmlContent, note: stub)

      let nonStubHTML = DocCArticlePage().renderHTML(nonStub, context: nonStubContext)
      let stubHTML = DocCArticlePage().renderHTML(stub, context: stubContext)

      #expect(nonStubHTML.contains("sk-docc-readtime"))
      #expect(!stubHTML.contains("sk-docc-readtime"))
   }

   // MARK: Quick Read jump pills

   @Test("Quick Read anchor bullets become sk-docc-tldr-jump pills in the rendered body")
   func quickReadJumpPills() throws {
      let md = """
      # Jump Pill Test

      Short abstract.

      > **Quick Read**: The lead sentence.
      > - [Design](#design)
      > - [Architecture](#architecture)

      ## Design

      Body content here.

      ## Architecture

      More content.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/JumpTest.md"), content: md)
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("sk-docc-tldr-jump"))
      #expect(page.htmlContent.contains("href=\"#design\""))
      #expect(page.htmlContent.contains("href=\"#architecture\""))
      // Pills must be anchors (not buttons) for no-JS scroll.
      #expect(page.htmlContent.contains("<a class=\"sk-docc-tldr-jump\""))
   }

   @Test("Non-anchor bullets in Quick Read render as a plain list, not pills")
   func quickReadNonAnchorBulletsAreNotPills() throws {
      let md = """
      # Plain Bullets

      Abstract.

      > **Quick Read**: The summary.
      > - A plain text bullet
      > - Another plain bullet

      ## Body

      Content.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/PlainBullets.md"), content: md)
      let page = try DocCLoader().load(source: source)
      #expect(!page.htmlContent.contains("sk-docc-tldr-jump"))
      // The bullets must still render as a list.
      #expect(page.htmlContent.contains("<ul>") || page.htmlContent.contains("<li>"))
   }

   // MARK: Callout rendering

   @Test("Tip callout blockquote renders as sk-docc-callout--tip with label badge")
   func calloutTipMapping() throws {
      let md = """
      # Callout Test

      Abstract.

      > Tip: Enable dark mode in Settings to reduce eye strain.

      ## Body

      Content.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/CalloutTip.md"), content: md)
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("sk-docc-callout--tip"))
      #expect(page.htmlContent.contains("sk-docc-callout-label"))
      #expect(!page.htmlContent.contains("<blockquote>"))
   }

   @Test("Note callout renders as sk-docc-callout--note")
   func calloutNoteMapping() throws {
      let md = """
      # Note Test

      Abstract.

      > Note: This API requires iOS 17.

      ## Body

      Content.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/CalloutNote.md"), content: md)
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("sk-docc-callout--note"))
   }

   @Test("Important, Warning, and Experiment callouts render with their respective modifier classes")
   func calloutKindMapping() throws {
      for (keyword, expected) in [("Important", "sk-docc-callout--important"), ("Warning", "sk-docc-callout--warning"), ("Experiment", "sk-docc-callout--experiment")] {
         let md = """
         # \(keyword) Test

         Abstract.

         > \(keyword): Something to note here.

         ## Body

         Content.
         """
         let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/\(keyword).md"), content: md)
         let page = try DocCLoader().load(source: source)
         #expect(page.htmlContent.contains(expected), "Expected \(expected) in output for keyword '\(keyword)'")
      }
   }

   // MARK: Written By

   @Test("Written By section is present for community non-stub notes with contributors")
   func writtenByPresentForCommunityNote() {
      let page = PageModel(
         title: "A Session",
         slug: "wwdc25-300-a-session",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: [
            "doccNote": true,
            "doccContributors": ["fbernutz", "Jeehut"],
         ]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(html.contains("id=\"writtenby\""))
      #expect(html.contains("sk-docc-writtenby"))
      // Avatar for each contributor.
      #expect(html.contains("github.com/fbernutz.png"))
      #expect(html.contains("github.com/Jeehut.png"))
      // Contributed Notes link and GitHub link per contributor.
      #expect(html.contains("/documentation/contributors/fbernutz/"))
      #expect(html.contains("https://github.com/fbernutz"))
   }

   @Test("Written By section is absent for stub notes")
   func writtenByAbsentForStub() {
      let page = PageModel(
         title: "Stub", slug: "wwdc25-301-stub",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: [
            "doccNote": true,
            "doccIsStub": true,
            "doccContributors": ["fbernutz"],
         ]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(!html.contains("id=\"writtenby\""))
   }

   @Test("Written By section is absent when note has no contributors")
   func writtenByAbsentWithNoContributors() {
      let page = PageModel(
         title: "Anon", slug: "wwdc25-302-anon",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(!html.contains("id=\"writtenby\""))
   }

   // MARK: Related Sessions auto-derive

   @Test("Related auto-derive returns same-year notes, excluding self, preferring non-stubs")
   func relatedAutoDeriveBasic() {
      let selfNote = PageModel(
         title: "Self", slug: "wwdc25-100-self",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/self.md"),
         extensions: ["doccNote": true]
      )
      let sibling1 = PageModel(
         title: "Sibling 1", slug: "wwdc25-200-sibling-one",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/s1.md"),
         extensions: ["doccNote": true]
      )
      let stubSibling = PageModel(
         title: "Stub", slug: "wwdc25-201-stub",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let allNotes = [selfNote, sibling1, stubSibling]
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: "documentation")
      let related = DocCArticlePage.relatedNotes(for: selfNote, allNotes: allNotes, navTree: tree)
      // Must not include self.
      #expect(!related.contains(where: { $0.slug == "wwdc25-100-self" }))
      // Non-stub must appear before stub.
      let slugs = related.map(\.slug)
      if let nonStubIdx = slugs.firstIndex(of: "wwdc25-200-sibling-one"),
         let stubIdx = slugs.firstIndex(of: "wwdc25-201-stub")
      {
         #expect(nonStubIdx < stubIdx)
      }
   }

   @Test("Related explicit doccRelated override returns those slugs")
   func relatedExplicitOverride() {
      let selfNote = PageModel(
         title: "Self", slug: "wwdc25-100-self",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/self.md"),
         extensions: ["doccNote": true, "doccRelated": ["wwdc25-999-explicit"]]
      )
      let explicitNote = PageModel(
         title: "Explicit", slug: "wwdc25-999-explicit",
         htmlContent: "<p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/e.md"),
         extensions: ["doccNote": true]
      )
      let allNotes = [selfNote, explicitNote]
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: "documentation")
      let related = DocCArticlePage.relatedNotes(for: selfNote, allNotes: allNotes, navTree: tree)
      #expect(related.count == 1)
      #expect(related.first?.slug == "wwdc25-999-explicit")
   }

   // MARK: TOC writtenby gating

   @Test("TOC omits #writtenby when the note has no contributors")
   func tocOmitsWrittenByWithNoContributors() {
      let page = PageModel(
         title: "No Contributors", slug: "wwdc25-700-no-contrib",
         htmlContent: "<h2>Section A</h2><p>x</p><h2>Section B</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/no-contrib.md"),
         extensions: ["doccNote": true]
         // no doccContributors key
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // The body must not contain the writtenby section anchor.
      #expect(!html.contains("id=\"writtenby\""))
      // The TOC must not link to #writtenby.
      #expect(!html.contains("href=\"#writtenby\""))
      // Related must still be present.
      #expect(html.contains("href=\"#related\""))
   }

   // MARK: Quick Read id="quick-read"

   @Test("Rendered article body contains id=\"quick-read\" on the Quick Read aside when one is present")
   func quickReadAsideHasQuickReadID() throws {
      let md = """
      # Overview Test

      Short abstract.

      > **Quick Read**: The lead sentence here.

      ## Body

      Content goes here.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/OverviewID.md"), content: md)
      let page = try DocCLoader().load(source: source)
      // The aside uses id="quick-read" to avoid colliding with an authored ## Overview section
      // that slugifies to the same id. The ## Overview heading still owns #overview.
      #expect(page.htmlContent.contains("id=\"quick-read\""))
      #expect(page.htmlContent.contains("sk-docc-quickread"))
      // Confirm the authored ## Overview section gets its own distinct id.
      #expect(page.htmlContent.contains("id=\"body\"") || !page.htmlContent.contains("<h2"))
   }

   @Test("Stub body carries id=\"quick-read\" on its empty-state section")
   func stubBodyHasQuickReadID() {
      let stub = PageModel(
         title: "Stub", slug: "wwdc25-stub-overview",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let context = Self.singleNoteContext(slug: stub.slug, htmlContent: stub.htmlContent, note: stub)
      let html = DocCArticlePage().renderHTML(stub, context: context)
      // The stub empty-state div carries id="quick-read" so the TOC "Quick Read" anchor resolves.
      #expect(html.contains("id=\"quick-read\""))
      #expect(html.contains("sk-docc-empty"))
   }

   // MARK: Stub empty-state

   @Test("Stub renders the empty-state and omits the variant switcher and Written By")
   func stubRendersEmptyState() {
      let stub = PageModel(
         title: "Stub Session", slug: "wwdc25-400-stub",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: [
            "doccNote": true,
            "doccIsStub": true,
            "doccContributors": ["fbernutz"],
         ]
      )
      let context = Self.singleNoteContext(slug: stub.slug, htmlContent: stub.htmlContent, note: stub)
      let html = DocCArticlePage().renderHTML(stub, context: context)
      // Empty state present.
      #expect(html.contains("sk-docc-empty"))
      #expect(html.contains("sk-docc-empty-title"))
      #expect(html.contains("sk-docc-btn"))
      // The variant switcher and article body must NOT appear for stubs.
      #expect(!html.contains("sk-docc-variants"))
      #expect(!html.contains("sk-article-body"))
      // Written By must NOT appear for stubs.
      #expect(!html.contains("id=\"writtenby\""))
      // Related Sessions must still appear.
      #expect(html.contains("id=\"related\""))
   }

   // MARK: Variant switcher faithful labels

   @Test("Variant switcher uses UIStrings labels in renderHTML context")
   func variantSwitcherFaithfulLabels() {
      let page = PageModel(
         title: "AI Note", slug: "wwdc25-500-ai",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/ai.md"),
         extensions: ["doccNote": true, "doccAIVariant": "<p>AI summary</p>"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // Faithful prototype labels from UIStrings defaults.
      #expect(html.contains("Community Notes"))
      #expect(html.contains("Written &amp; reviewed by people"))
      #expect(html.contains("AI Notes"))
      // The AI sub-label must use the corrected wording – NOT the old "on-device" phrasing.
      #expect(html.contains("AI-generated summary of the session"))
      #expect(!html.contains("On-device summary of the video"))
      // AI banner text must use the corrected full string (pipeline, not on-device).
      #expect(html.contains("sk-docc-ai-banner"))
      #expect(html.contains("AI Notes (beta) are generated by a build-pipeline model"))
   }

   // MARK: TOC completeness

   @Test("TOC includes Quick Read, body headings, Written By, and Related for community non-stub notes")
   func tocItemsComplete() {
      let page = PageModel(
         title: "Full Note", slug: "wwdc25-600-full",
         htmlContent: "<aside class=\"sk-docc-quickread sk-docc-tldr\"></aside><h2>Design</h2><p>x</p><h2>Impl</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/full.md"),
         extensions: [
            "doccNote": true,
            "doccContributors": ["Jeehut"],
         ]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let toc = html.components(separatedBy: "<aside class=\"sk-docc-toc\"").dropFirst().first ?? ""
      #expect(toc.contains("href=\"#quick-read\""))  // Quick Read (new reserved id, avoids #overview collision)
      #expect(toc.contains("href=\"#design\""))      // body h2
      #expect(toc.contains("href=\"#impl\""))        // body h2
      #expect(toc.contains("href=\"#writtenby\""))   // Written By
      #expect(toc.contains("href=\"#related\""))     // Related
   }

   // MARK: TOC dedup (Gap #9)

   @Test("TOC has no duplicate hrefs when Quick Read id and body Overview heading both slugify to the same anchor")
   func tocNoDuplicateHrefs() throws {
      // A note with a Quick Read card AND an authored ## Overview section: without the dedup
      // fix both would resolve to #overview – with the fix, quick-read uses #quick-read and
      // Overview keeps #overview, so the TOC has no duplicate hrefs.
      let md = """
      # Dedup Test

      Abstract.

      > **Quick Read**: The lead.
      > - [Overview](#overview)

      ## Overview

      Body text here.

      ## Design

      More text.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/DedupTest.md"), content: md)
      let page = try DocCLoader().load(source: source)
      let context = Self.singleNoteContext(slug: "wwdc25-999-dedup", htmlContent: page.htmlContent)
      let note = context.sections[0].pages[0]
      let noteWithQR = PageModel(
         title: note.title, slug: note.slug, htmlContent: page.htmlContent,
         sourcePath: note.sourcePath, extensions: ["doccNote": true]
      )
      let ctxWithQR = Self.singleNoteContext(slug: note.slug, htmlContent: page.htmlContent, note: noteWithQR)
      let html = DocCArticlePage().renderHTML(noteWithQR, context: ctxWithQR)

      // Collect all TOC hrefs and assert no duplicates.
      let tocBlock = html.components(separatedBy: "<aside class=\"sk-docc-toc\"").dropFirst().first ?? ""
      let hrefMatches = tocBlock.components(separatedBy: "href=\"#").dropFirst().map {
         String($0.prefix(while: { $0 != "\"" }))
      }
      let hrefSet = Set(hrefMatches)
      #expect(hrefSet.count == hrefMatches.count, "Duplicate hrefs found: \(hrefMatches)")
      // Quick Read must use #quick-read; Overview section keeps its own #overview.
      #expect(tocBlock.contains("href=\"#quick-read\""))
      #expect(tocBlock.contains("href=\"#overview\""))
      // Both must appear without duplication.
      let quickReadCount = hrefMatches.filter { $0 == "quick-read" }.count
      let overviewCount = hrefMatches.filter { $0 == "overview" }.count
      #expect(quickReadCount == 1)
      #expect(overviewCount == 1)
   }

   // MARK: Title (the session number lives in the breadcrumb, not the h1)

   @Test("Title is the bare note title; the session number moves to the breadcrumb tail")
   func titleHasNoSessionNumberPrefix() {
      let page = PageModel(
         title: "Create Icons", slug: "wwdc25-361-create-icons",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // The h1 is the title alone – no "361 · " number prefix, no eyebrow.
      #expect(html.contains("<h1 class=\"sk-docc-title\">Create Icons</h1>"))
      #expect(!html.contains("361 · Create Icons"))
      #expect(!html.contains("sk-docc-eyebrow"))
      // The session number lives in the breadcrumb's trailing crumb instead.
      let crumb = Self.breadcrumbHTML(in: html)
      #expect(crumb.contains("WWDC25"))
      #expect(crumb.contains(">361</span>"))
   }

   @Test("Session number appears once (breadcrumb) and the title once (h1), neither doubled")
   func titleAndNumberNotDoubled() {
      // doccTitleHeading "WWDC25 · Session 101" feeds only the breadcrumb year label ("WWDC25",
      // the part before the dot); the session number "101" is parsed from the slug for the
      // trailing crumb. The h1 is the title alone, so neither title nor number repeats.
      let page = PageModel(
         title: "Keynote", slug: "wwdc25-101-keynote",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25 · Session 101"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // The h1 is the bare title.
      #expect(html.contains("<h1 class=\"sk-docc-title\">Keynote</h1>"))
      #expect(!html.contains("101 · Keynote"))
      #expect(!html.contains("sk-docc-eyebrow"))
      // The breadcrumb tail is the bare number, shown once and never doubled.
      let crumb = Self.breadcrumbHTML(in: html)
      #expect(crumb.contains(">101</span>"))
      #expect(!html.contains("101 · 101"))
   }

   @Test("Title renders without a number prefix when the slug has no session code")
   func titlePlainWhenNoSessionCode() {
      // Slug "contributing" has no numeric session-code segment → plain title.
      let page = PageModel(
         title: "Contributing", slug: "contributing",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "Guides"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      // No session code → the h1 must show the plain title, no separator.
      #expect(html.contains("<h1 class=\"sk-docc-title\">Contributing</h1>"))
      #expect(!html.contains("sk-docc-eyebrow"))
      // The breadcrumb still has the WWDC year from doccTitleHeading when a year is
      // derivable from the slug – but "contributing" has no year prefix, so only the
      // site name and current title appear in the breadcrumb.
      #expect(!html.contains("· Session"))
   }

   // MARK: Content article vs stub empty-state

   @Test("Content article renders its body, not the stub empty-state")
   func contentArticleRendersBody() {
      // A guide page (@PageKind(article)) with a real body: must render the body and
      // must never show the sk-docc-empty empty-state, even when doccIsStub is also set
      // (defensive: the loader should not set it for articles, but the renderer guards too).
      let article = PageModel(
         title: "Contributing",
         slug: "contributing",
         htmlContent: "<p>This project is a community effort...</p><h2>How to Contribute</h2><p>Open a PR.</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributing.md"),
         extensions: [
            "doccNote": true,
            "doccPageKind": "article",
         ]
      )
      let context = Self.singleNoteContext(slug: article.slug, htmlContent: article.htmlContent, note: article)
      let html = DocCArticlePage().renderHTML(article, context: context)
      // Body text must appear.
      #expect(html.contains("This project is a community effort"))
      #expect(html.contains("How to Contribute"))
      // The stub empty-state must be absent.
      #expect(!html.contains("sk-docc-empty"))
      #expect(!html.contains("sk-docc-empty-title"))
      // The article body wrapper must be present.
      #expect(html.contains("sk-article-body"))
   }

   @Test("Content article is not stub-flagged even when doccIsStub is set alongside doccPageKind(article)")
   func contentArticleNotFlaggedStubByRenderer() {
      // Simulates the worst case: loader mistakenly set doccIsStub = true for a
      // @PageKind(article) page. The renderer must still render the body, not the empty-state.
      let article = PageModel(
         title: "Contributing",
         slug: "contributing",
         htmlContent: "<p>Guide body content here.</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributing.md"),
         extensions: [
            "doccNote": true,
            "doccPageKind": "article",
            "doccIsStub": true,  // must be overridden by doccPageKind
         ]
      )
      let context = Self.singleNoteContext(slug: article.slug, htmlContent: article.htmlContent, note: article)
      let html = DocCArticlePage().renderHTML(article, context: context)
      #expect(html.contains("Guide body content here."))
      #expect(!html.contains("sk-docc-empty"))
      #expect(html.contains("sk-article-body"))
   }

   @Test("Genuine session-note stub still shows the empty-state (regression guard)")
   func genuineStubStillShowsEmptyState() {
      // A session note with doccIsStub = true and no doccPageKind must keep showing the empty-state.
      let stub = PageModel(
         title: "Untouched Session", slug: "wwdc25-999-untouched",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/stub.md"),
         extensions: [
            "doccNote": true,
            "doccIsStub": true,
            // No doccPageKind – this is a genuine session stub.
         ]
      )
      let context = Self.singleNoteContext(slug: stub.slug, htmlContent: stub.htmlContent, note: stub)
      let html = DocCArticlePage().renderHTML(stub, context: context)
      #expect(html.contains("sk-docc-empty"))
      #expect(!html.contains("sk-article-body"))
   }

   @Test("Stub empty-state uses the help-wanted emoji (not the smiley face)")
   func stubEmptyStateEmoji() {
      let stub = PageModel(
         title: "Empty Session", slug: "wwdc25-888-empty",
         htmlContent: "<p>placeholder</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/empty.md"),
         extensions: ["doccNote": true, "doccIsStub": true]
      )
      let context = Self.singleNoteContext(slug: stub.slug, htmlContent: stub.htmlContent, note: stub)
      let html = DocCArticlePage().renderHTML(stub, context: context)
      // The empty-state mark must use ✍️ (help-wanted / not-written-yet), not 🙂.
      #expect(html.contains("✍️"))
      #expect(!html.contains("🙂"))
   }

   // MARK: Quick Read AI hint (#15)

   @Test("Quick Read card rendered by DocCLoader contains the AI-generated hint line")
   func quickReadBoxContainsAIHint() throws {
      let md = """
      # AI Hint Test

      Abstract sentence.

      > **Quick Read**: The lead summary sentence.

      ## Body

      Content here.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/AIHintTest.md"), content: md)
      let page = try DocCLoader().load(source: source)
      // The Quick Read card must carry the AI-generated hint element.
      #expect(page.htmlContent.contains("sk-docc-tldr-ai-hint"))
      // Verify the English default text is present (DocCLoader defaults to "en").
      #expect(page.htmlContent.contains("AI-generated quick summary"))
   }

   @Test("Quick Read box in locale 'de' renders the German AI hint translation")
   func quickReadAIHintLocalized() throws {
      // Verify the DE locale resolves from Localizable.json, confirming the
      // UIStrings wiring reaches the renderer (not just the EN default).
      let md = """
      # Lokalisierung

      Kurztext.

      > **Quick Read**: Die Zusammenfassung.

      ## Inhalt

      Text hier.
      """
      let source = MarkdownSource(filePath: URL(fileURLWithPath: "/tmp/Lokalisierung.md"), content: md)
      let page = try DocCLoader(language: "de").load(source: source)
      // German translation must be present in the Quick Read card.
      #expect(page.htmlContent.contains("sk-docc-tldr-ai-hint"))
      #expect(page.htmlContent.contains("KI-generierte Kurzübersicht"))
   }

   // MARK: Gradient header box (shared hero mechanic)

   @Test("Article header is a gradient hero card with inner inset, prism art, breadcrumb, title, abstract, and the Watch CTA")
   func articleHeaderIsGradientHeroBox() throws {
      let page = PageModel(
         title: "Meet X", slug: "wwdc25-101-meet-x",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         summary: "An abstract sentence.",
         extensions: [
            "doccNote": true,
            "doccTitleHeading": "WWDC25 · Session 101",
            "doccCTAURL": "https://developer.apple.com/videos/play/wwdc2025/101",
            "doccMinutes": 30,
         ]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let header = try #require(Self.headerBlock(in: html))
      // The header element carries the shared gradient hero surface in the default card
      // style: NO flush modifier (it removed the inner inset and glued the content to the
      // gradient edge) and NO band modifier (band is the opt-in alternative style). The
      // card carries the decorative prism panel like the home/contributors heroes.
      #expect(header.contains("sk-docc-hero"))
      #expect(!header.contains("sk-docc-hero--flush"))
      #expect(!header.contains("sk-docc-hero--band"))
      #expect(header.contains("sk-docc-hero-prism"))
      // Breadcrumb, h1, abstract, and the Watch CTA all live INSIDE the box.
      #expect(header.contains("sk-docc-breadcrumb"))
      #expect(header.contains("<h1 class=\"sk-docc-title\">Meet X</h1>"))
      #expect(header.contains("An abstract sentence."))
      #expect(header.contains("sk-docc-watch"))
   }

   @Test("Band style: the header box precedes the article element and spans without prism art")
   func articleHeaderBandStyle() throws {
      let page = PageModel(
         title: "Meet X", slug: "wwdc25-101-meet-x",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         summary: "An abstract sentence.",
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25 · Session 101"]
      )
      let context = Self.singleNoteContext(
         slug: page.slug, htmlContent: page.htmlContent, note: page,
         docc: DocCConfig(articleHero: .band)
      )
      let html = DocCArticlePage().renderHTML(page, context: context)
      let header = try #require(Self.headerBlock(in: html))
      // The band modifier replaces the card look; the band has no prism art panel –
      // its presence is the full-width color sweep itself.
      #expect(header.contains("sk-docc-hero--band"))
      #expect(!header.contains("sk-docc-hero-prism"))
      // The header must be emitted BEFORE the article element: only as a direct child
      // of the page container can it span the TOC grid's full width and bleed to the
      // pane edges. Inside the capped article column it could not.
      let headerStart = try #require(html.range(of: "<header class=\"sk-docc-header"))
      let articleStart = try #require(html.range(of: "<article class=\"sk-docc-article"))
      #expect(headerStart.lowerBound < articleStart.lowerBound)
      // Breadcrumb, title, and abstract still live inside the box.
      #expect(header.contains("sk-docc-breadcrumb"))
      #expect(header.contains("<h1 class=\"sk-docc-title\">Meet X</h1>"))
      #expect(header.contains("An abstract sentence."))
   }

   @Test("Card style keeps the header inside the article element")
   func articleHeaderCardStaysInsideArticle() throws {
      let page = PageModel(
         title: "Meet X", slug: "wwdc25-101-meet-x",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let headerStart = try #require(html.range(of: "<header class=\"sk-docc-header"))
      let articleStart = try #require(html.range(of: "<article class=\"sk-docc-article"))
      #expect(articleStart.lowerBound < headerStart.lowerBound)
   }

   @Test("Guide pages (no session slug) render the prism card header like articles")
   func guideHeaderIsPrismCard() throws {
      let page = PageModel(
         title: "Contributing", slug: "contributing",
         htmlContent: "<h2>How</h2><p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/contributing.md"),
         summary: "How to contribute.",
         extensions: ["doccNote": true, "doccPageKind": "article"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let header = try #require(Self.headerBlock(in: html))
      #expect(header.contains("sk-docc-hero-prism"))
      #expect(!header.contains("sk-docc-hero--flush"))
      #expect(!header.contains("sk-docc-hero--band"))
   }

   @Test("Header box without a CTA URL still renders breadcrumb, title, and abstract (no watch button)")
   func headerBoxWithoutCTA() throws {
      let page = PageModel(
         title: "No Video", slug: "wwdc25-102-no-video",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         summary: "Abstract here.",
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let header = try #require(Self.headerBlock(in: html))
      #expect(header.contains("sk-docc-hero"))
      #expect(header.contains("sk-docc-breadcrumb"))
      #expect(header.contains("<h1 class=\"sk-docc-title\">No Video</h1>"))
      #expect(!header.contains("sk-docc-watch"))
   }

   // MARK: Breadcrumb separator consistency

   @Test("Breadcrumb uses chevrons throughout: no middle-dot separator before the session number")
   func breadcrumbSingleSeparatorStyle() {
      let page = PageModel(
         title: "Keynote", slug: "wwdc25-101-keynote",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true, "doccTitleHeading": "WWDC25 · Session 101"]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      let crumb = Self.breadcrumbHTML(in: html)
      // Two separators (site › year › number), both chevrons, no middle dot.
      #expect(crumb.components(separatedBy: "sk-docc-bc-sep").count - 1 == 2)
      #expect(crumb.components(separatedBy: "›").count - 1 == 2)
      #expect(!crumb.contains("·"))
   }

   // MARK: Related Sessions suppression for guides

   @Test("Guides (loose pages without a year key) render no Related Sessions section and no TOC entry")
   func guideSuppressesRelatedSessions() {
      let article = PageModel(
         title: "Contributing", slug: "contributing",
         htmlContent: "<h2>How</h2><p>x</p><h2>Why</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributing.md"),
         extensions: ["doccNote": true, "doccPageKind": "article"]
      )
      let context = Self.singleNoteContext(slug: article.slug, htmlContent: article.htmlContent, note: article)
      let html = DocCArticlePage().renderHTML(article, context: context)
      #expect(!html.contains("id=\"related\""))
      #expect(!html.contains("href=\"#related\""))
   }

   @Test("Session notes (year-keyed slug) still render the Related Sessions section")
   func sessionNoteKeepsRelatedSessions() {
      let page = PageModel(
         title: "Session", slug: "wwdc25-103-session",
         htmlContent: "<h2>A</h2><p>x</p><h2>B</h2>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         extensions: ["doccNote": true]
      )
      let context = Self.singleNoteContext(slug: page.slug, htmlContent: page.htmlContent, note: page)
      let html = DocCArticlePage().renderHTML(page, context: context)
      #expect(html.contains("id=\"related\""))
      #expect(html.contains("href=\"#related\""))
   }

   /// Extracts the article's `<header class="sk-docc-header …">…</header>` block (the gradient
   /// hero box) so a test can assert what lives inside the box versus outside it. Targets the
   /// article header specifically – the shell's appbar is also a `<header>` element.
   private static func headerBlock(in html: String) -> String? {
      guard let block = html.components(separatedBy: "<header class=\"sk-docc-header").dropFirst().first?
         .components(separatedBy: "</header>").first else { return nil }
      return "<header class=\"sk-docc-header" + block + "</header>"
   }

   /// Extracts the inner HTML of the `<nav class="sk-docc-breadcrumb" …>…</nav>` element so a test
   /// can assert on the breadcrumb crumbs alone, isolated from the h1 and body markup.
   private static func breadcrumbHTML(in html: String) -> String {
      html.components(separatedBy: "<nav class=\"sk-docc-breadcrumb\"").dropFirst().first?
         .components(separatedBy: "</nav>").first ?? ""
   }

   /// A `BuildContext` holding exactly one DocC note, for exercising `renderHTML`.
   private static func singleNoteContext(slug: String, htmlContent: String) -> BuildContext {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let note = PageModel(
         title: "Note", slug: slug, htmlContent: htmlContent,
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"), extensions: ["doccNote": true]
      )
      return BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   /// A `BuildContext` variant that accepts a fully-constructed note `PageModel` and an
   /// optional `docc:` config block (e.g. to select the article hero style).
   private static func singleNoteContext(
      slug: String,
      htmlContent: String,
      note: PageModel,
      docc: DocCConfig? = nil
   ) -> BuildContext {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      return BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection], docc: docc),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }
}
