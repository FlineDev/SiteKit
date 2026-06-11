import Foundation
import Testing

@testable import SiteKit

/// Tests for the DocC app-shell: appbar (brand + search pill) and the shared footer
/// (call-to-action cards + legal block rendered from config on every DocC page).
@Suite("DocCShell")
struct DocCShellTests {

   // MARK: - Helpers

   private func makeConfig(
      name: String = "Docs",
      brand: DocCBrandConfig? = nil,
      footerCards: [DocCFooterCardConfig]? = nil,
      footerDisclaimer: String? = nil,
      footerLegalNotice: String? = nil
   ) -> SiteConfig {
      SiteConfig(
         name: name,
         baseURL: "https://example.com",
         sections: [SectionConfig(
            name: "Documentation",
            slug: "documentation",
            contentDirectory: "Docs",
            urlPrefix: "documentation"
         )],
         docc: DocCConfig(
            footerCards: footerCards,
            footerDisclaimer: footerDisclaimer,
            footerLegalNotice: footerLegalNotice,
            brand: brand
         )
      )
   }

   private func makeContext(config: SiteConfig) -> BuildContext {
      BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   // MARK: - Brand: plain fallback

   @Test("Plain site name rendered when no DocCBrandConfig is set")
   func plainBrandFallback() {
      let context = makeContext(config: makeConfig(name: "MyDocs"))
      let html = DocCShell.appbar(context: context)

      // The brand anchor must contain the site name as plain text (no span split).
      #expect(html.contains(">MyDocs<"))
      #expect(!html.contains("sk-docc-brand-1"))
      #expect(!html.contains("sk-docc-brand-2"))
      #expect(!html.contains("sk-docc-wordmark"))
   }

   // MARK: - Brand: 2-tone split

   @Test("2-tone brand renders prefix in sk-docc-brand-1 and accent in sk-docc-brand-2")
   func twoToneBrandSplit() {
      let brand = DocCBrandConfig(prefix: "WWDC", accent: "Notes")
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      #expect(html.contains("class=\"sk-docc-brand-1\">WWDC<"))
      #expect(html.contains("class=\"sk-docc-brand-2\">Notes<"))
      #expect(html.contains("sk-docc-wordmark"))
      // The plain site name must NOT appear as a bare text node next to the spans.
      #expect(!html.contains(">Docs<"))
   }

   @Test("2-tone brand with logo emits an img before the wordmark")
   func twoToneBrandWithLogo() {
      let brand = DocCBrandConfig(prefix: "WWDC", accent: "Notes", logoPath: "logo.svg")
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      #expect(html.contains("class=\"sk-docc-brand-logo\""))
      #expect(html.contains("src=\"/assets/logo.svg\""))
      // Logo comes before the wordmark spans.
      let logoIdx = html.range(of: "sk-docc-brand-logo")?.lowerBound
      let wordmarkIdx = html.range(of: "sk-docc-wordmark")?.lowerBound
      if let l = logoIdx, let w = wordmarkIdx {
         #expect(l < w)
      } else {
         Issue.record("Expected both logo and wordmark elements in the appbar HTML")
      }
   }

   @Test("Configured logoWidth/logoHeight win over the stylesheet via inline size")
   func twoToneBrandLogoSizeOverride() {
      let brand = DocCBrandConfig(
         prefix: "WWDC",
         accent: "Notes",
         logoPath: "logo.svg",
         logoWidth: 36,
         logoHeight: 36
      )
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      // HTML width/height attributes alone do NOT beat a CSS width/height rule, so the
      // override must ride on an inline style (highest cascade origin below !important).
      #expect(html.contains("style=\"width: 36px; height: 36px;\""))
      // The attributes still ship for the browser's intrinsic-size/aspect-ratio hint.
      #expect(html.contains("width=\"36\""))
      #expect(html.contains("height=\"36\""))
   }

   @Test("A single configured logo dimension emits only that dimension, CSS keeps the other")
   func twoToneBrandLogoPartialOverride() {
      let brand = DocCBrandConfig(
         prefix: "WWDC",
         accent: "Notes",
         logoPath: "logo.svg",
         logoWidth: 40
      )
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      #expect(html.contains("style=\"width: 40px;\""))
      #expect(html.contains("width=\"40\""))
      // Scoped to the logo img – the appbar's inline SVG icons carry height attributes too.
      let imgTag = html.components(separatedBy: "<img").dropFirst().first?
         .components(separatedBy: "/>").first ?? ""
      #expect(!imgTag.contains("height=\""))
   }

   @Test("Without configured logo size the img carries no inline size – the stylesheet owns it")
   func twoToneBrandLogoDefaultHasNoInlineSize() {
      let brand = DocCBrandConfig(prefix: "WWDC", accent: "Notes", logoPath: "logo.svg")
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      let imgTag = html.components(separatedBy: "<img").dropFirst().first?
         .components(separatedBy: "/>").first ?? ""
      #expect(!imgTag.contains("style="))
      #expect(!imgTag.contains("width="))
      #expect(!imgTag.contains("height="))
   }

   @Test("Logo dimensions of zero or below are ignored like nil – the stylesheet keeps both axes")
   func twoToneBrandLogoNonPositiveSizeIgnored() {
      let brand = DocCBrandConfig(
         prefix: "WWDC",
         accent: "Notes",
         logoPath: "logo.svg",
         logoWidth: 0,
         logoHeight: -12
      )
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      let imgTag = html.components(separatedBy: "<img").dropFirst().first?
         .components(separatedBy: "/>").first ?? ""
      #expect(!imgTag.contains("style="))
      #expect(!imgTag.contains("width="))
      #expect(!imgTag.contains("height="))
   }

   @Test("A non-positive logo dimension is dropped while the valid one still applies")
   func twoToneBrandLogoMixedValidityKeepsValidAxis() {
      let brand = DocCBrandConfig(
         prefix: "WWDC",
         accent: "Notes",
         logoPath: "logo.svg",
         logoWidth: -1,
         logoHeight: 36
      )
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)

      #expect(html.contains("style=\"height: 36px;\""))
      let imgTag = html.components(separatedBy: "<img").dropFirst().first?
         .components(separatedBy: "/>").first ?? ""
      #expect(!imgTag.contains("width=\""))
   }

   @Test("2-tone brand without logo emits no img element")
   func twoToneBrandNoLogo() {
      let brand = DocCBrandConfig(prefix: "WWDC", accent: "Notes")
      let context = makeContext(config: makeConfig(brand: brand))
      let html = DocCShell.appbar(context: context)
      #expect(!html.contains("sk-docc-brand-logo"))
      #expect(!html.contains("<img"))
   }

   // MARK: - Search pill

   @Test("Appbar emits the search trigger pill with the data-docc-search-open hook")
   func searchPillPresent() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      #expect(html.contains("data-docc-search-open"))
      #expect(html.contains("sk-docc-search-pill"))
   }

   @Test("Search pill contains the localized search label")
   func searchPillHasLabel() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      // The UIStrings default for doccSearch in English is "Search".
      #expect(html.contains("sk-docc-search-pill-label"))
      #expect(html.contains(">Search<"))
   }

   @Test("Search pill contains the keyboard shortcut hint element with data-docc-kbd")
   func searchPillHasKbd() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      #expect(html.contains("sk-docc-kbd"))
      #expect(html.contains("data-docc-kbd"))
      // The static fallback is ⌘K; JS swaps to Ctrl+K on non-Mac at runtime.
      #expect(html.contains("⌘K"))
   }

   // MARK: - Structural invariants

   @Test("Appbar always contains the hamburger burger button with sidebar hooks")
   func appbarHasBurger() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      #expect(html.contains("sk-docc-burger"))
      #expect(html.contains("data-docc-sidebar-open"))
      #expect(html.contains("aria-expanded=\"false\""))
      #expect(html.contains("aria-controls=\"sk-docc-sidebar\""))
   }

   @Test("Brand link href uses the section URL prefix")
   func brandLinkHref() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      #expect(html.contains("href=\"/documentation/\""))
   }

   @Test("renderHTML (via DocCArticlePage) includes search pill and 2-tone brand when configured")
   func renderHTMLIncludesB2Chrome() {
      let brand = DocCBrandConfig(prefix: "WWDC", accent: "Notes")
      let config = makeConfig(name: "WWDCNotes", brand: brand)
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Meet Swift Testing",
         slug: "wwdc25-10188-meet-swift-testing",
         htmlContent: "<h2>Overview</h2><p>x</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/note.md"),
         extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )

      let html = DocCArticlePage().renderHTML(note, context: context)

      // Brand split is present.
      #expect(html.contains("sk-docc-brand-1"))
      #expect(html.contains("sk-docc-brand-2"))
      // Search pill is present.
      #expect(html.contains("sk-docc-search-pill"))
      #expect(html.contains("data-docc-search-open"))
      #expect(html.contains("sk-docc-kbd"))
      // The single search lives in the appbar-triggered overlay (input + results moved
      // out of the sidebar); the single theme toggle sits in the appbar beside the pill.
      #expect(html.contains("data-docc-search-overlay"))
      #expect(html.contains("class=\"sk-docc-search-input\""))
      // The overlay is a two-pane modal: a rich results list (reusing the session-row
      // visual language) beside a preview panel the script hydrates from the focused row.
      #expect(html.contains("class=\"sk-docc-search-results sk-docc-sesslist\""))
      #expect(html.contains("data-docc-search-preview"))
      // Preview labels ride on data-* attributes so the client stays locale-agnostic.
      #expect(html.contains("data-docc-search-watch=\"Watch Video\""))
      #expect(html.contains("data-docc-search-more=\"View more\""))
      #expect(html.contains("sk-docc-theme-toggle"))
   }

   // MARK: - Appbar theme toggle

   @Test("Appbar renders a single theme toggle button beside the search pill")
   func appbarHasThemeToggle() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.appbar(context: context)
      // A single toggle button, not the old 3-way segmented radiogroup.
      #expect(html.contains("class=\"sk-docc-theme-toggle\""))
      #expect(html.contains("data-docc-theme-toggle"))
      #expect(!html.contains("sk-docc-themeswitch"))
      #expect(!html.contains("role=\"radiogroup\""))
      #expect(!html.contains("data-docc-theme=\"light\""))
      // Exactly one toggle button is emitted.
      #expect(html.components(separatedBy: "sk-docc-theme-toggle").count - 1 == 1)
      // The toggle sits after the search pill in the appbar's right cluster.
      let pillIdx = html.range(of: "sk-docc-search-pill")?.lowerBound
      let toggleIdx = html.range(of: "sk-docc-theme-toggle")?.lowerBound
      if let p = pillIdx, let t = toggleIdx {
         #expect(p < t)
      } else {
         Issue.record("Expected both the search pill and theme toggle in the appbar HTML")
      }
   }

   @Test("Theme toggle carries a localized aria-label")
   func appbarThemeToggleLocalizedLabel() {
      let de = UIStrings(locale: "de")
      let context = BuildContext(
         config: makeConfig(),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         uiStrings: de,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCShell.appbar(context: context)
      // The aria-label comes from the locale's UIStrings, compared against the same bundle.
      #expect(html.contains("aria-label=\"\(de.string(for: .doccThemeToggle))\""))
   }

   // MARK: - Footer: no config → no footer

   @Test("footerHTML returns empty string when no footerCards and no footerDisclaimer are configured")
   func footerHTMLAbsentWhenUnconfigured() {
      let context = makeContext(config: makeConfig())
      let html = DocCShell.footerHTML(context: context)
      #expect(html.isEmpty)
   }

   // MARK: - Footer: cards only

   @Test("footerHTML renders cards from SiteConfig.docc.footerCards")
   func footerHTMLCardsFromConfig() {
      let config = makeConfig(
         footerCards: [
            DocCFooterCardConfig(heading: "Contribute", body: "Help needed.", ctaLabel: "Open a PR", href: "https://github.com/example/repo"),
            DocCFooterCardConfig(heading: "Missing Sessions", body: "Stubs waiting.", ctaLabel: "See all", href: "/missing/")
         ]
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("<footer class=\"sk-docc-footer\">"))
      #expect(html.contains("sk-docc-footer-cols"))
      // Both cards present.
      #expect(html.contains("Contribute"))
      #expect(html.contains("Help needed."))
      #expect(html.contains("Open a PR"))
      #expect(html.contains("Missing Sessions"))
      #expect(html.contains("See all"))
      // No legal block when no disclaimer is configured.
      #expect(!html.contains("sk-docc-footer-legal"))
   }

   // MARK: - Footer: disclaimer only

   @Test("footerHTML renders legal block when only footerDisclaimer is configured")
   func footerHTMLDisclaimerOnly() {
      let config = makeConfig(
         name: "WWDCNotes",
         footerDisclaimer: "Not affiliated with Apple Inc. WWDC is a trademark of Apple Inc."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("<footer class=\"sk-docc-footer\">"))
      #expect(html.contains("sk-docc-footer-legal"))
      #expect(html.contains("sk-docc-footer-brand"))
      // Brand name (from config.name) must appear in the brand mark.
      #expect(html.contains("WWDCNotes"))
      // Disclaimer text must be HTML-escaped and present.
      #expect(html.contains("Not affiliated with Apple Inc."))
      // No cards block when no cards are configured.
      #expect(!html.contains("sk-docc-footer-cols"))
   }

   // MARK: - Footer: cards + disclaimer

   @Test("footerHTML renders both cards and legal block when both are configured")
   func footerHTMLCardsAndDisclaimer() {
      let config = makeConfig(
         name: "MyDocs",
         footerCards: [
            DocCFooterCardConfig(heading: "Card A", body: "Body A.", ctaLabel: "Go", href: "/a/")
         ],
         footerDisclaimer: "Trademark notice."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      // Both sections present.
      #expect(html.contains("sk-docc-footer-cols"))
      #expect(html.contains("Card A"))
      #expect(html.contains("sk-docc-footer-legal"))
      #expect(html.contains("Trademark notice."))
      // Brand name appears in the legal block.
      #expect(html.contains("MyDocs"))
   }

   // MARK: - Footer: legal notice

   @Test("footerHTML renders the legal notice as paragraphs below the disclaimer")
   func footerHTMLLegalNoticeBelowDisclaimer() {
      let config = makeConfig(
         name: "WWDCNotes",
         footerDisclaimer: "An independent, community-run archive of session notes.",
         footerLegalNotice: "All content copyright Apple Inc. All rights reserved.\n\nThis website is not made by, affiliated with, nor endorsed by Apple."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("sk-docc-footer-notice"))
      // Each non-empty line becomes its own paragraph; blank separator lines produce none.
      #expect(html.contains("<p>All content copyright Apple Inc. All rights reserved.</p>"))
      #expect(html.contains("<p>This website is not made by, affiliated with, nor endorsed by Apple.</p>"))
      #expect(!html.contains("<p></p>"))

      // Hierarchy: brand mark, then disclaimer, then the legal small print.
      let brandIdx = html.range(of: "sk-docc-footer-brand")?.lowerBound
      let disclaimerIdx = html.range(of: "An independent, community-run archive")?.lowerBound
      let noticeIdx = html.range(of: "sk-docc-footer-notice")?.lowerBound
      if let b = brandIdx, let d = disclaimerIdx, let n = noticeIdx {
         #expect(b < d)
         #expect(d < n)
      } else {
         Issue.record("Expected brand, disclaimer, and notice to all be present in the footer HTML")
      }
   }

   @Test("footerHTML renders the legal block when only footerLegalNotice is configured")
   func footerHTMLLegalNoticeOnly() {
      let config = makeConfig(
         name: "WWDCNotes",
         footerLegalNotice: "All content copyright Apple Inc."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("<footer class=\"sk-docc-footer\">"))
      #expect(html.contains("sk-docc-footer-legal"))
      #expect(html.contains("sk-docc-footer-brand"))
      #expect(html.contains("WWDCNotes"))
      #expect(html.contains("<p>All content copyright Apple Inc.</p>"))
      #expect(!html.contains("sk-docc-footer-cols"))
   }

   @Test("footerHTML emits no notice element when footerLegalNotice is absent (existing sites unchanged)")
   func footerHTMLNoNoticeWhenUnconfigured() {
      let config = makeConfig(
         name: "WWDCNotes",
         footerDisclaimer: "Not affiliated with Apple Inc."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("sk-docc-footer-legal"))
      #expect(!html.contains("sk-docc-footer-notice"))
   }

   @Test("footerHTML HTML-escapes the legal notice lines")
   func footerHTMLEscapesLegalNotice() {
      let config = makeConfig(
         name: "Docs",
         footerLegalNotice: "Copyright <Apple> & \"friends\"."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      #expect(html.contains("Copyright &lt;Apple&gt; &amp; &quot;friends&quot;."))
      #expect(!html.contains("<Apple>"))
   }

   // MARK: - Footer: HTML escaping

   @Test("footerHTML HTML-escapes all config strings")
   func footerHTMLEscapesStrings() {
      let config = makeConfig(
         name: "A & B",
         footerCards: [
            DocCFooterCardConfig(heading: "<Bold>", body: "\"quoted\"", ctaLabel: "Go", href: "/go/")
         ],
         footerDisclaimer: "All <rights> reserved & more."
      )
      let context = makeContext(config: config)
      let html = DocCShell.footerHTML(context: context)

      // Injected strings must be escaped.
      #expect(html.contains("&lt;Bold&gt;"))
      #expect(html.contains("&quot;quoted&quot;"))
      #expect(html.contains("All &lt;rights&gt; reserved &amp; more."))
      // Raw dangerous characters must not appear as-is.
      #expect(!html.contains("<Bold>"))
      #expect(!html.contains("\"quoted\""))
   }

   // MARK: - Footer: placement in the shell

   @Test("wrap places the footer inside .sk-docc-scroll after .sk-docc-page when cards are configured")
   func wrapPlacesFooterInsideScroll() {
      let config = makeConfig(
         footerCards: [
            DocCFooterCardConfig(heading: "Help", body: "b", ctaLabel: "Go", href: "/h/")
         ]
      )
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Demo",
         slug: "wwdc25-1-demo",
         htmlContent: "<p>body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/demo.md"),
         extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCArticlePage().renderHTML(note, context: context)

      // Footer must be inside .sk-docc-scroll (after .sk-docc-page, before </main>).
      let scrollStart = html.range(of: "class=\"sk-docc-scroll\"")?.lowerBound
      let footerStart = html.range(of: "class=\"sk-docc-footer\"")?.lowerBound
      let mainClose = html.range(of: "</main>")?.lowerBound
      if let s = scrollStart, let f = footerStart, let m = mainClose {
         #expect(s < f, "Footer should appear after the scroll region opens")
         #expect(f < m, "Footer should appear before </main>")
      } else {
         Issue.record("Expected sk-docc-scroll, sk-docc-footer, and </main> in rendered HTML")
      }
   }

   @Test("wrap emits no footer element on an article page when no footer is configured")
   func wrapNoFooterWhenUnconfigured() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Demo",
         slug: "wwdc25-1-demo",
         htmlContent: "<p>body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/demo.md"),
         extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCArticlePage().renderHTML(note, context: context)
      #expect(!html.contains("sk-docc-footer"))
   }

   // MARK: - Shell-owned scripts present on non-article pages

   /// Regression guard: the search, sidebar, filter, and theme scripts must appear in
   /// the final HTML of every DocC page type – not just article pages. Previously these
   /// were wired per-page and were absent from year, contributors, contributor, and
   /// missing-notes pages, breaking the appbar ⌘K search overlay on those pages.
   /// `DocCShell.wrap` now injects them once for all page types.

   @Test("Contributors page HTML contains all shell scripts via DocCShell.wrap")
   func contributorsPageHasShellScripts() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Session A",
         slug: "wwdc24-100-a",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/a.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice"]] as [String: any Sendable]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCContributorsPage().pages(in: context).first!
      let html = DocCContributorsPage().renderHTML(page, context: context)

      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
      #expect(html.contains(DocCSidebarScriptRenderer.scriptURL))
      #expect(html.contains(DocCFilterScriptRenderer.scriptURL))
      #expect(html.contains(DocCThemeScriptRenderer.scriptURL))
   }

   @Test("Year listing page HTML contains all shell scripts via DocCShell.wrap")
   func yearListingPageHasShellScripts() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Meet Something",
         slug: "wwdc24-100-meet-something",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/session.md"),
         extensions: ["doccNote": true] as [String: any Sendable]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCYearListingPage().pages(in: context).first!
      let html = DocCYearListingPage().renderHTML(page, context: context)

      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
      #expect(html.contains(DocCSidebarScriptRenderer.scriptURL))
      #expect(html.contains(DocCFilterScriptRenderer.scriptURL))
      #expect(html.contains(DocCThemeScriptRenderer.scriptURL))
   }

   @Test("Contributor detail page HTML contains all shell scripts via DocCShell.wrap")
   func contributorDetailPageHasShellScripts() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Session A",
         slug: "wwdc24-100-a",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/a.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice"]] as [String: any Sendable]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let page = DocCContributorPage().pages(in: context).first!
      let html = DocCContributorPage().renderHTML(page, context: context)

      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
      #expect(html.contains(DocCSidebarScriptRenderer.scriptURL))
      #expect(html.contains(DocCFilterScriptRenderer.scriptURL))
      #expect(html.contains(DocCThemeScriptRenderer.scriptURL))
   }

   @Test("Article page HTML still contains all shell scripts after centralization")
   func articlePageHasShellScriptsAfterCentralization() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Meet Something",
         slug: "wwdc24-100-meet-something",
         htmlContent: "<h2>Intro</h2><p>body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/session.md"),
         extensions: ["doccNote": true] as [String: any Sendable]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCArticlePage().renderHTML(note, context: context)

      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
      #expect(html.contains(DocCSidebarScriptRenderer.scriptURL))
      #expect(html.contains(DocCFilterScriptRenderer.scriptURL))
      #expect(html.contains(DocCThemeScriptRenderer.scriptURL))
   }

   @Test("TOC script present on article page that renders a TOC, absent on contributors page with no TOC")
   func tocScriptPresentOnlyWhenTocRendered() {
      let config = makeConfig()
      let docSection = config.effectiveSections[0]

      // Article with enough headings to trigger a TOC rail.
      let articleNote = PageModel(
         title: "Meet Something",
         slug: "wwdc24-100-meet-something",
         htmlContent: "<h2>Overview</h2><p>x</p><h2>Details</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/session.md"),
         extensions: ["doccNote": true] as [String: any Sendable]
      )
      let contextWithArticle = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [articleNote])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let articleHTML = DocCArticlePage().renderHTML(articleNote, context: contextWithArticle)
      #expect(articleHTML.contains(DocCTocScriptRenderer.scriptURL))

      // Contributors page has no TOC, so the TOC script must NOT be included.
      let sessionNote = PageModel(
         title: "Session A",
         slug: "wwdc24-100-a",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/a.md"),
         extensions: ["doccNote": true, "doccContributors": ["alice"]] as [String: any Sendable]
      )
      let contextWithContributors = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [sessionNote])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let contributorsPage = DocCContributorsPage().pages(in: contextWithContributors).first!
      let contributorsHTML = DocCContributorsPage().renderHTML(contributorsPage, context: contextWithContributors)
      #expect(!contributorsHTML.contains(DocCTocScriptRenderer.scriptURL))
   }
}
