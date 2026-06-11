import Foundation
import Testing

@testable import SiteKit

@Suite("DocCStylesheetRenderer")
struct DocCStylesheetRendererTests {
   @Test("Emits the DocC component CSS to /assets/css/docc.css")
   func emitsStylesheet() throws {
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com"),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let files = try DocCStylesheetRenderer().render(context: context)
      #expect(files.count == 1)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/css/docc.css"))
      #expect(file.content.contains(".sk-docc-layout"))
      #expect(file.content.contains(".sk-docc-quickread"))
      #expect(file.content.contains("var(--color-accent"))
   }

   @Test("Bundled docc.css resource is loadable")
   func resourceLoads() throws {
      #expect(try DocCStylesheetRenderer.loadDocCCSS().contains(".sk-docc-sidebar"))
   }

   @Test("docc.css ships the band hero modifier and dropped the superseded flush modifier")
   func bandHeroModifierPresent() throws {
      // The flush modifier (zero inner inset on every header box) glued the hero text to
      // the gradient edge and was superseded by the card/band style pair: cards keep the
      // inner inset, the band paints the pane edge-to-edge via border-image ink instead.
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      #expect(css.contains(".sk-docc-hero--band"))
      #expect(css.contains("border-image-outset"))
      // The TOC-page mirror grid keeps the band's inner column aligned with the article column.
      #expect(css.contains(".sk-docc-page--with-toc .sk-docc-hero--band"))
      #expect(!css.contains(".sk-docc-hero--flush"))
   }

   @Test("Brand defaults: 30px logo box and 19px wordmark reach toward the 36px controls")
   func brandDefaultSizes() throws {
      // The appbar brand must read as one visual set with the 36px search pill and theme
      // toggle. A 30px logo plus the 19px wordmark inside the brand's 4px vertical padding
      // lands the block at ~38px – optically flush with the controls without inflating the
      // 48px appbar.
      let css = try DocCStylesheetRenderer.loadDocCCSS()

      let logo = try #require(
         css.components(separatedBy: ".sk-docc-brand-logo {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(logo.contains("width: 30px"))
      #expect(logo.contains("height: 30px"))

      let wordmark = try #require(
         css.components(separatedBy: ".sk-docc-wordmark {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(wordmark.contains("font-size: 19px"))
   }

   @Test("Year metadata hierarchy: small secondary stack, full-text blurb, badge chips")
   func yearMetadataHierarchyDeclarations() throws {
      // The platform/stack line must sit one clear step below the description in both
      // size and color. On cards the demotion is size-only plus a PROMOTED blurb
      // (full text color): --color-text-muted measures 4.16:1 on the dark card
      // background (#757e98 on #161d2e) and fails WCAG AA, so the muted token is
      // reserved for page-background surfaces like the year detail subtitle.
      let css = try DocCStylesheetRenderer.loadDocCCSS()

      let stack = try #require(
         css.components(separatedBy: ".sk-docc-card-stack {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(stack.contains("font-size: 11px"))
      #expect(stack.contains("var(--color-text-secondary)"))

      let blurb = try #require(
         css.components(separatedBy: ".sk-docc-card-blurb {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(blurb.contains("color: var(--color-text)"))

      // Detail-page stack subtitle: smaller than the 16px lead and muted (AA on the
      // page background in both themes: 4.81:1 light, 4.86:1 dark).
      let sub = try #require(
         css.components(separatedBy: ".sk-docc-yeartitle-sub {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(sub.contains("font-size: 0.9rem"))
      #expect(sub.contains("var(--color-text-muted"))

      // Framework badges reuse the chip language (pill radius, hairline border) with
      // secondary text for AA on the card background; the comma-text rule is gone.
      let badge = try #require(
         css.components(separatedBy: ".sk-docc-api-badge {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(badge.contains("border-radius: 999px"))
      #expect(badge.contains("var(--color-text-secondary)"))
      #expect(badge.contains("border: 1px solid var(--color-border)"))
      #expect(css.contains(".sk-docc-api-badges"))
      #expect(!css.contains(".sk-docc-card-apis"))
   }

   @Test("Compact card heroes keep horizontal air on mobile while the band stays flush")
   func mobileCompactCardAir() throws {
      // The generic mobile hero rule (one class) loses the cascade against the global
      // compact rule (two classes), so compact cards need their own mobile padding rule
      // with higher specificity – band heroes are excluded because their air comes from
      // the pane-wide paint and their text must stay on the column alignment.
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      let block = try #require(
         css.components(separatedBy: ".sk-docc-hero.is-compact:not(.sk-docc-hero--band)").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(block.contains("padding: 1.75rem 1rem 1.25rem"))
   }

   @Test("Breadcrumb trail and read time on the hero gradient use the secondary text token")
   func heroBreadcrumbAndReadtimeContrast() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // The muted token is tuned for the flat page background and falls under AA on the
      // gradient hero surface, so both elements must be lifted to the secondary token there.
      let block = try #require(
         css.components(separatedBy: ".sk-docc-hero .sk-docc-breadcrumb,").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(block.contains(".sk-docc-hero .sk-docc-readtime"))
      #expect(block.contains("var(--color-text-secondary)"))
   }

   @Test("Breadcrumb separator uses the secondary text token without an opacity fade")
   func breadcrumbSeparatorContrast() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      let block = try #require(
         css.components(separatedBy: ".sk-docc-bc-sep {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(block.contains("var(--color-text-secondary)"))
      #expect(!block.contains("opacity"))
   }

   @Test("Every .sk-docc-page padding declaration carries the top inset below the appbar")
   func pageTopInsetPresent() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // Rounded hero/search surfaces must not touch the sticky appbar edge-to-edge.
      // The shared inset lives on the page wrapper, and the responsive breakpoints
      // re-declare the padding shorthand, so every declaration must repeat it or
      // narrow viewports silently lose the air again.
      let blocks = css.components(separatedBy: ".sk-docc-page {").dropFirst()
         .compactMap { $0.components(separatedBy: "}").first }
      #expect(blocks.count == 3)
      for block in blocks {
         #expect(block.contains("padding: 1.25rem"))
      }
   }

   @Test("Hero art panel reserves at most a slim spacer so hero text keeps its line length")
   func heroArtReservationSlim() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // The prism art paints absolutely across the hero, so the art box is a pure
      // width reservation; at 180px it forced the home tagline to wrap one word early.
      let block = try #require(
         css.components(separatedBy: ".sk-docc-hero-art {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(block.contains("min-width: 120px"))
   }

   @Test("Search modal field rounds its top corners so the focus ring follows the modal curve")
   func searchFieldFocusRingRadius() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // The modal clips children at a 13px inner radius (14px outer minus 1px border).
      // A square field corner would clip the visible focus ring there (WCAG 2.4.7
      // needs the ring fully visible), so the field must match the curve up top.
      let block = try #require(
         css.components(separatedBy: ".sk-docc-search-field {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(block.contains("border-radius: 13px 13px 0 0"))
   }

   @Test("Search modal grows with the viewport on wide screens, keeping today's width on narrow ones")
   func searchModalWidthScalesOnWideViewports() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // clamp keeps 880px as the floor (the previous fixed cap, so viewports below
      // ~1222px render exactly as before), tracks the viewport from there, and stops
      // at 1400px so ultra-wide screens don't get an absurdly wide dialog.
      let modal = try #require(
         css.components(separatedBy: ".sk-docc-search-modal {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(modal.contains("max-width: clamp(880px, 72vw, 1400px)"))
   }

   @Test("Search preview pane takes ~40% of the modal body, never below its old fixed width")
   func searchPreviewPaneFortyPercent() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // 40% gives the preview real room once the modal widens (less text wrapping,
      // air around the Watch button); the 320px floor means narrow two-pane modals
      // keep exactly the old fixed-width preview.
      let preview = try #require(
         css.components(separatedBy: ".sk-docc-search-preview {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(preview.contains("flex: 0 0 40%"))
      #expect(preview.contains("min-width: 320px"))
   }

   @Test("Narrow search overlay keeps the 720px breakpoint with hidden preview and 560px cap")
   func searchModalNarrowBreakpointUnchanged() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // The single-column phone layout must not shift while the wide end grows.
      let media = try #require(
         css.components(separatedBy: "@media (max-width: 720px) {").dropFirst().first
      )
      let preview = try #require(
         media.components(separatedBy: ".sk-docc-search-preview {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(preview.contains("display: none"))
      let modal = try #require(
         media.components(separatedBy: ".sk-docc-search-modal {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(modal.contains("max-width: 560px"))
   }

   @Test("Modal width clamp and preview split survive CSS minification")
   func searchModalDeclarationsSurviveMinify() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      let minified = AssetMinifier.minifyCSS(css)
      // The minifier collapses whitespace around commas and colons; the math inside
      // clamp() and the space-separated flex shorthand values must stay intact.
      #expect(minified.contains("max-width:clamp(880px,72vw,1400px)"))
      #expect(minified.contains("flex:0 0 40%"))
      #expect(minified.contains("min-width:320px"))
   }

   // MARK: - B3: Framework color CSS generation

   @Test("frameworkColorCSS emits one solid-fill tile rule per framework key, single-color")
   func frameworkColorCSSSingleColor() {
      let frameworks: [String: DocCFrameworkIcon] = [
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      ]
      let css = DocCStylesheetRenderer.frameworkColorCSS(from: frameworks)
      #expect(css.contains("[data-framework=\"swiftui\"]"))
      // The rule paints the tile background; the glyph color (white) lives in docc.css.
      #expect(css.contains("background: #1e88e5"))
      #expect(!css.contains("color: #1e88e5"))
      // Single-color entry has no gradient.
      #expect(!css.contains("linear-gradient"))
   }

   @Test("frameworkColorCSS emits a gradient tile rule when 2 colors provided")
   func frameworkColorCSSGradient() {
      let frameworks: [String: DocCFrameworkIcon] = [
         "swift": DocCFrameworkIcon(glyph: "fa-brands fa-swift", colors: ["#f05138", "#ff8a3d"]),
      ]
      let css = DocCStylesheetRenderer.frameworkColorCSS(from: frameworks)
      #expect(css.contains("[data-framework=\"swift\"]"))
      #expect(css.contains("background: linear-gradient(145deg, #f05138, #ff8a3d)"))
      // The glyph color is no longer set per-framework (white comes from docc.css).
      #expect(!css.contains("color: #f05138"))
   }

   @Test("frameworkColorCSS output is sorted by key for determinism")
   func frameworkColorCSSSorted() {
      let frameworks: [String: DocCFrameworkIcon] = [
         "swift": DocCFrameworkIcon(glyph: "fa-brands fa-swift", colors: ["#f05138"]),
         "accessibility": DocCFrameworkIcon(glyph: "fa-solid fa-a", colors: ["#2e7d32"]),
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      ]
      let css = DocCStylesheetRenderer.frameworkColorCSS(from: frameworks)
      let accessibilityPos = css.range(of: "accessibility")?.lowerBound ?? css.endIndex
      let swiftPos = css.range(of: "\"swift\"")?.lowerBound ?? css.endIndex
      let swiftuiPos = css.range(of: "swiftui")?.lowerBound ?? css.endIndex
      // Keys sorted: accessibility < swift < swiftui.
      #expect(accessibilityPos < swiftPos)
      #expect(swiftPos < swiftuiPos)
   }

   @Test("Stylesheet renderer appends framework-color CSS when frameworks configured")
   func rendererAppendsFrameworkCSS() throws {
      let docc = DocCConfig(frameworks: [
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      ])
      let config = SiteConfig(name: "Docs", baseURL: "https://example.com", docc: docc)
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let files = try DocCStylesheetRenderer().render(context: context)
      let css = try #require(files.first?.content)
      #expect(css.contains("[data-framework=\"swiftui\"]"))
      #expect(css.contains("background: #1e88e5"))
   }

   @Test("Footer legal block ships the balance columns, the legal notice, and the corrections nudge")
   func footerLegalBalanceDeclarations() throws {
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      // Balance layout: brand column beside a flexible text area (wordmark left, text columns beside it).
      let legalBlock = try #require(
         css.components(separatedBy: ".sk-docc-footer-legal {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(legalBlock.contains("grid"))
      #expect(css.contains(".sk-docc-footer-legal-text"))
      // Legal small print paragraphs below/beside the disclaimer.
      #expect(css.contains(".sk-docc-footer-notice"))
      // The corrections nudge is a quiet line: no border/background box declarations.
      let corrections = try #require(
         css.components(separatedBy: ".sk-docc-corrections {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(!corrections.contains("border"))
      #expect(!corrections.contains("background"))
   }

   @Test("Footer responsive overrides come after the footer base rules so they win the cascade")
   func footerResponsiveOverridesWinCascade() throws {
      // A footer override inside the early global responsive blocks is dead: the footer
      // base rules come later in the file and win the same-specificity cascade (this was
      // the shipped mobile-footer-padding bug). The overrides must live after the base.
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      let baseRange = try #require(css.range(of: ".sk-docc-footer-legal {"))
      let afterBase = css[baseRange.upperBound...]
      let mediaRange = try #require(afterBase.range(of: "@media (max-width: 760px)"))
      let mediaTail = afterBase[mediaRange.upperBound...]
      // The mobile stacking + padding overrides are inside that trailing media block.
      #expect(mediaTail.contains(".sk-docc-footer-legal"))
      #expect(mediaTail.contains(".sk-docc-footer "))
   }

   @Test("Note badge collapses its line box so the uppercase label centers vertically")
   func noteBadgeUppercaseCentering() throws {
      // Uppercase-only text in a normal line box sits visually high: the line box
      // centers ascent+descent, but capitals have no descenders, so the descender
      // space below the baseline reads as extra air at the bottom (live-measured
      // at 1.6px top/bottom asymmetry on the rendered badge). line-height: 1
      // removes that leading; the vertical padding carries the box height instead.
      let css = try DocCStylesheetRenderer.loadDocCCSS()
      let badge = try #require(
         css.components(separatedBy: ".sk-docc-note-badge {").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(badge.contains("text-transform: uppercase"))
      #expect(badge.contains("line-height: 1;"))
      // Padding compensates the collapsed line box so the pill height stays ~22px.
      #expect(badge.contains("padding: 0.3rem 0.55rem"))

      // line-height: 1 alone still leaves ~1.4px asymmetry (the text fragment keeps
      // the font's descent share below the baseline), so engines with text-box
      // support trim the line box to the cap-height/baseline edges – measured at
      // 0.33px asymmetry vs 1.64px before. The block padding re-adds the trimmed
      // leading so the pill height stays put.
      let enhancement = try #require(
         css.components(separatedBy: "@supports (text-box: trim-both cap alphabetic)").dropFirst().first?
            .components(separatedBy: "}").first
      )
      #expect(enhancement.contains(".sk-docc-note-badge"))
      #expect(enhancement.contains("text-box: trim-both cap alphabetic;"))
      #expect(enhancement.contains("padding-block: 0.41rem"))
   }

   @Test("Stylesheet renderer emits no framework-color block when no frameworks")
   func rendererSkipsFrameworkCSSWhenNone() throws {
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com"),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let files = try DocCStylesheetRenderer().render(context: context)
      let css = try #require(files.first?.content)
      #expect(!css.contains("[data-framework="))
   }
}
