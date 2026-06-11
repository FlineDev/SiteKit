import Foundation
import Testing
import Yams
@testable import SiteKit

@Suite("ThemeTokens")
struct ThemeTokensTests {
   // MARK: - FontConfig

   @Test("FontConfig requiresImport for web fonts")
   func fontConfigRequiresImportWeb() {
      let sora = FontConfig(family: "Sora")
      #expect(sora.requiresImport == true)

      let inter = FontConfig(family: "Inter")
      #expect(inter.requiresImport == true)
   }

   @Test("FontConfig requiresImport false for system fonts")
   func fontConfigRequiresImportSystem() {
      let system = FontConfig(family: "-apple-system, BlinkMacSystemFont, sans-serif")
      #expect(system.requiresImport == false)

      let mono = FontConfig(family: "monospace")
      #expect(mono.requiresImport == false)

      let serif = FontConfig(family: "serif")
      #expect(serif.requiresImport == false)
   }

   @Test("FontConfig default weights")
   func fontConfigDefaultWeights() {
      #expect(FontConfig.defaultWeights == [400, 600, 700])
   }

   // MARK: - TokenValue

   @Test("TokenValue with only any (no dark mode)")
   func tokenValueAnyOnly() {
      let token = TokenValue(any: "#fff")
      #expect(token.any == "#fff")
      #expect(token.dark == nil)
   }

   @Test("TokenValue with both any and dark")
   func tokenValueBothModes() {
      let token = TokenValue(any: "#fff", dark: "#000")
      #expect(token.any == "#fff")
      #expect(token.dark == "#000")
   }

   @Test("TokenValue merging overlays values")
   func tokenValueMerging() {
      let base = TokenValue(any: "#fff", dark: "#111")
      let overlay = TokenValue(any: "#fafafa", dark: "#222")
      let merged = base.merging(with: overlay)
      #expect(merged.any == "#fafafa")
      #expect(merged.dark == "#222")
   }

   @Test("TokenValue merging preserves base dark when overlay has no dark")
   func tokenValueMergingPreservesDark() {
      let base = TokenValue(any: "#fff", dark: "#111")
      let overlay = TokenValue(any: "#fafafa")
      let merged = base.merging(with: overlay)
      #expect(merged.any == "#fafafa")
      #expect(merged.dark == "#111")
   }

   // MARK: - ThemeTokens Merging

   @Test("Merging overlays non-nil TokenValue fields")
   func mergingOverlays() {
      let base = ThemeTokens(
         colorBg: TokenValue(any: "#fff"),
         colorAccent: TokenValue(any: "#111")
      )
      let overlay = ThemeTokens(
         colorAccent: TokenValue(any: "#222")
      )

      let merged = base.merging(with: overlay)
      #expect(merged.colorAccent?.any == "#222")
      #expect(merged.colorBg?.any == "#fff")
   }

   @Test("Merging preserves base when overlay is nil")
   func mergingPreservesBase() {
      let base = ThemeTokens(
         colorBg: TokenValue(any: "#fafaf8", dark: "#1a1917"),
         colorText: TokenValue(any: "#1c1917"),
         fontHeading: FontConfig(family: "Sora"),
         maxWidth: "1200px"
      )
      let overlay = ThemeTokens()

      let merged = base.merging(with: overlay)
      #expect(merged.colorBg?.any == "#fafaf8")
      #expect(merged.colorBg?.dark == "#1a1917")
      #expect(merged.colorText?.any == "#1c1917")
      #expect(merged.fontHeading?.family == "Sora")
      #expect(merged.maxWidth == "1200px")
   }

   @Test("Merging replaces fonts entirely")
   func mergingReplacesFonts() {
      let base = ThemeTokens(fontHeading: FontConfig(family: "Sora", weights: [400, 700]))
      let overlay = ThemeTokens(fontHeading: FontConfig(family: "Inter", weights: [400, 500]))

      let merged = base.merging(with: overlay)
      #expect(merged.fontHeading?.family == "Inter")
      #expect(merged.fontHeading?.weights == [400, 500])
   }

   @Test("Merging deep-merges TokenValue dark variant")
   func mergingDeepMergesTokenValue() {
      let base = ThemeTokens(
         colorAccent: TokenValue(any: "#0891b2", dark: "#22d3ee")
      )
      let overlay = ThemeTokens(
         colorAccent: TokenValue(any: "#e11d48")  // Only overrides any, keeps dark
      )

      let merged = base.merging(with: overlay)
      #expect(merged.colorAccent?.any == "#e11d48")
      #expect(merged.colorAccent?.dark == "#22d3ee")  // Preserved from base
   }

   // MARK: - Preset Loading

   @Test("All built-in presets load without errors", arguments: TokenCSSGenerator.availablePresets)
   func presetLoads(presetName: String) {
      let tokens = TokenCSSGenerator.loadPreset(named: presetName)
      #expect(tokens != nil, "Preset '\(presetName)' failed to load")
   }

   @Test("All presets have both any and dark color values", arguments: TokenCSSGenerator.availablePresets)
   func presetHasBothModes(presetName: String) {
      guard let tokens = TokenCSSGenerator.loadPreset(named: presetName) else {
         Issue.record("Preset '\(presetName)' failed to load")
         return
      }

      // Must have any (fallback)
      #expect(tokens.colorBg?.any != nil, "\(presetName): missing colorBg.any")
      #expect(tokens.colorText?.any != nil, "\(presetName): missing colorText.any")
      #expect(tokens.colorAccent?.any != nil, "\(presetName): missing colorAccent.any")

      // Must have dark variants
      #expect(tokens.colorBg?.dark != nil, "\(presetName): missing colorBg.dark")
      #expect(tokens.colorText?.dark != nil, "\(presetName): missing colorText.dark")
      #expect(tokens.colorAccent?.dark != nil, "\(presetName): missing colorAccent.dark")
   }

   @Test("Non-existent preset returns nil")
   func nonExistentPreset() {
      let tokens = TokenCSSGenerator.loadPreset(named: "nonexistent")
      #expect(tokens == nil)
   }

   // MARK: - CSS Generation

   @Test("CSS generation includes :root block")
   func cssGenerationRoot() {
      let config = ThemeConfig(name: "Test", preset: "default")
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(css!.contains(":root {"))
      #expect(css!.contains("--color-accent:"))
   }

   @Test("CSS generation includes dark mode block")
   func cssGenerationDarkMode() {
      let config = ThemeConfig(name: "Test", preset: "default")
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(css!.contains("[data-theme=\"dark\"]"))
   }

   @Test("Chrome + layout tokens emit their CSS custom properties")
   func cssGenerationChromeLayoutTokens() {
      let config = ThemeConfig(
         name: "Test",
         tokens: ThemeTokens(
            colorHeaderBg: TokenValue(any: "#ffffff", dark: "#101010"),
            colorFooterBg: TokenValue(any: "#f0f0f0"),
            staticPageWidth: "640px",
            logoSize: "40px",
            logoRadius: "10px",
            footerMarginTop: "0"
         )
      )
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      // Layout tokens emit in :root
      #expect(css!.contains("--static-page-width: 640px;"))
      #expect(css!.contains("--logo-size: 40px;"))
      #expect(css!.contains("--logo-radius: 10px;"))
      #expect(css!.contains("--footer-margin-top: 0;"))
      // Chrome color tokens emit light + dark variants
      #expect(css!.contains("--color-header-bg: #ffffff;"))
      #expect(css!.contains("--color-footer-bg: #f0f0f0;"))
      #expect(css!.contains("--color-header-bg: #101010;"))
   }

   @Test("Semantic promo color tokens (info/warning) emit CSS custom properties")
   func cssGenerationSemanticColorTokens() {
      let config = ThemeConfig(
         name: "Test",
         tokens: ThemeTokens(
            colorInfo: TokenValue(any: "#2563eb", dark: "#60a5fa"),
            colorWarning: TokenValue(any: "#d97706")
         )
      )
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(css!.contains("--color-info: #2563eb;"))
      #expect(css!.contains("--color-warning: #d97706;"))
      // Dark-mode variant of info emits in the [data-theme="dark"] block.
      #expect(css!.contains("--color-info: #60a5fa;"))
   }

   @Test("CSS generation does NOT include @import for Google Fonts (moved to HTML <link>)")
   func cssGenerationNoFontsImport() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      // @import has been moved out of tokens.css – emitted as <link> in HTML <head> instead
      #expect(!css!.contains("@import url("))
      #expect(!css!.contains("fonts.googleapis.com"))
   }

   @Test("fontsLinkURL returns Google Fonts URL for web font presets")
   func fontsLinkURLWebFonts() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      let url = TokenCSSGenerator.fontsLinkURL(themeConfig: config)

      #expect(url != nil)
      #expect(url!.contains("fonts.googleapis.com/css2"))
      #expect(url!.contains("Sora"))
      #expect(url!.contains("Nunito+Sans"))
      #expect(url!.contains("display=swap"))
   }

   @Test("fontsLinkURL returns nil for system font presets")
   func fontsLinkURLSystemFonts() {
      let config = ThemeConfig(name: "Test", preset: "default")
      let url = TokenCSSGenerator.fontsLinkURL(themeConfig: config)
      #expect(url == nil)
   }

   @Test("fontsLinkURL returns nil when no tokens or preset")
   func fontsLinkURLNoTokens() {
      let config = ThemeConfig(name: "Test")
      let url = TokenCSSGenerator.fontsLinkURL(themeConfig: config)
      #expect(url == nil)
   }

   @Test("fontsLinkURL respects font pairing override")
   func fontsLinkURLFontPairing() {
      let config = ThemeConfig(name: "Test", fontPairing: "modern")
      let url = TokenCSSGenerator.fontsLinkURL(themeConfig: config)
      #expect(url != nil)
   }

   @Test("fontsLinkURL returns nil when selfHostedFonts is true")
   func fontsLinkURLSelfHosted() {
      let config = ThemeConfig(name: "Test", preset: "warm", selfHostedFonts: true)
      let url = TokenCSSGenerator.fontsLinkURL(themeConfig: config)
      #expect(url == nil)
   }

   @Test("selfHostedFontFaceCSS generates @font-face rules when enabled")
   func selfHostedFontFaceCSSEnabled() {
      let config = ThemeConfig(name: "Test", preset: "warm", selfHostedFonts: true)
      let css = TokenCSSGenerator.selfHostedFontFaceCSS(themeConfig: config)
      #expect(css != nil)
      #expect(css!.contains("@font-face"))
      #expect(css!.contains("Sora"))
      #expect(css!.contains("font-display: swap"))
      #expect(css!.contains("/assets/theme/fonts/Sora-400.woff2"))
   }

   @Test("selfHostedFontFaceCSS returns nil when disabled")
   func selfHostedFontFaceCSSDisabled() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      let css = TokenCSSGenerator.selfHostedFontFaceCSS(themeConfig: config)
      #expect(css == nil)
   }

   @Test("selfHostedFontFaceCSS returns nil for system fonts")
   func selfHostedFontFaceCSSSystemFonts() {
      let config = ThemeConfig(name: "Test", preset: "default", selfHostedFonts: true)
      let css = TokenCSSGenerator.selfHostedFontFaceCSS(themeConfig: config)
      #expect(css == nil)
   }

   @Test("generate omits @font-face by default (emitted in separate fonts.css instead)")
   func generateOmitsFontFaceRules() {
      let config = ThemeConfig(name: "Test", preset: "warm", selfHostedFonts: true)
      let css = TokenCSSGenerator.generate(themeConfig: config)
      #expect(css != nil)
      #expect(!css!.contains("@font-face"))
   }

   @Test("ThemeConfig decodes inlineFontAwesome flag")
   func themeConfigDecodesInlineFontAwesome() throws {
      let yaml = """
      name: "Test"
      preset: "warm"
      inlineFontAwesome: false
      """
      let decoded = try YAMLDecoder().decode(ThemeConfig.self, from: yaml)
      #expect(decoded.inlineFontAwesome == false)
   }

   @Test("ThemeConfig defaults inlineFontAwesome to nil (treated as true by inliner)")
   func themeConfigDefaultsInlineFontAwesome() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      #expect(config.inlineFontAwesome == nil)
   }

   @Test("ThemeConfig decodes resizeImages flag")
   func themeConfigDecodesResizeImages() throws {
      let yaml = """
      name: "Test"
      preset: "warm"
      resizeImages: false
      """
      let decoded = try YAMLDecoder().decode(ThemeConfig.self, from: yaml)
      #expect(decoded.resizeImages == false)
   }

   @Test("ThemeConfig defaults resizeImages to nil (treated as true by ImageResizer)")
   func themeConfigDefaultsResizeImages() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      #expect(config.resizeImages == nil)
   }

   @Test("CSS generation skips Google Fonts for system fonts")
   func cssGenerationNoFontsForSystem() {
      let config = ThemeConfig(name: "Test", preset: "default")
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(!css!.contains("@import url("))
   }

   @Test("Returns nil when no tokens or preset")
   func noTokensReturnsNil() {
      let config = ThemeConfig(name: "Test")
      let css = TokenCSSGenerator.generate(themeConfig: config)
      #expect(css == nil)
   }

   @Test("Returns nil for nil config")
   func nilConfigReturnsNil() {
      let css = TokenCSSGenerator.generate(themeConfig: nil)
      #expect(css == nil)
   }

   @Test("Custom tokens override preset values")
   func customTokensOverridePreset() {
      let config = ThemeConfig(
         name: "Test",
         preset: "default",
         tokens: ThemeTokens(colorAccent: TokenValue(any: "#e11d48"))
      )
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(css!.contains("--color-accent: #e11d48;"))
   }

   @Test("Standalone tokens without preset generate CSS")
   func standaloneTokens() {
      let config = ThemeConfig(
         name: "Test",
         tokens: ThemeTokens(
            colorBg: TokenValue(any: "#ffffff"),
            colorAccent: TokenValue(any: "#ff0000")
         )
      )
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(css!.contains("--color-accent: #ff0000;"))
      #expect(css!.contains("--color-bg: #ffffff;"))
   }

   @Test("Tokens with only any value produce no dark mode entries")
   func anyOnlyNoDarkMode() {
      let config = ThemeConfig(
         name: "Test",
         tokens: ThemeTokens(
            colorBg: TokenValue(any: "#ffffff"),
            colorAccent: TokenValue(any: "#ff0000")
         )
      )
      let css = TokenCSSGenerator.generate(themeConfig: config)

      #expect(css != nil)
      #expect(!css!.contains("[data-theme=\"dark\"]"))
   }

   // MARK: - ThemeConfig

   @Test("hasTokens is true when preset is set")
   func hasTokensWithPreset() {
      let config = ThemeConfig(name: "Test", preset: "warm")
      #expect(config.hasTokens == true)
   }

   @Test("hasTokens is true when tokens are set")
   func hasTokensWithTokens() {
      let config = ThemeConfig(name: "Test", tokens: ThemeTokens(colorAccent: TokenValue(any: "#000")))
      #expect(config.hasTokens == true)
   }

   @Test("hasTokens is false when neither preset nor tokens")
   func hasTokensFalse() {
      let config = ThemeConfig(name: "Test")
      #expect(config.hasTokens == false)
   }

   // MARK: - colorTokens Iteration

   @Test("colorTokens returns all non-nil color tokens")
   func colorTokensIteration() {
      let tokens = ThemeTokens(
         colorBg: TokenValue(any: "#fff", dark: "#000"),
         colorAccent: TokenValue(any: "#f00")
      )

      let names = tokens.colorTokens.map(\.name)
      #expect(names.contains("colorBg"))
      #expect(names.contains("colorAccent"))
      #expect(names.count == 2)
   }

   // MARK: - WCAG AA contrast guarantees per ADR-009

   /// WCAG 2.x relative-luminance formula.
   private func relativeLuminance(_ hex: String) -> Double {
      let h = hex.trimmingPrefix("#")
      let n = Int(h, radix: 16) ?? 0
      let r = Double((n >> 16) & 0xFF) / 255.0
      let g = Double((n >> 8) & 0xFF) / 255.0
      let b = Double(n & 0xFF) / 255.0
      func linearize(_ c: Double) -> Double {
         c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
   }

   private func contrastRatio(_ foreground: String, _ background: String) -> Double {
      let lf = self.relativeLuminance(foreground)
      let lb = self.relativeLuminance(background)
      let (lighter, darker) = lf > lb ? (lf, lb) : (lb, lf)
      return (lighter + 0.05) / (darker + 0.05)
   }

   @Test("teal color scheme meets WCAG AA on accent (light) and secondary/muted text (dark)")
   func tealMeetsWCAGAA() {
      let lightBg = "#fafaf8"
      let darkBg = "#1a1917"
      // The DocC session-item eyebrow sits on the card surface, not the page bg, so the
      // muted token must clear AA on the (slightly lighter) dark card too.
      let darkCard = "#2a2825"

      // Light mode: accent and accent-hover on ivory background
      let lightAccent = "#155e75"
      let lightAccentHover = "#164e63"
      #expect(self.contrastRatio(lightAccent, lightBg) >= 4.5)
      #expect(self.contrastRatio(lightAccentHover, lightBg) >= 4.5)

      // Dark mode: secondary and muted text on dark background AND the dark card
      let darkSecondary = "#a8a29e"
      let darkMuted = "#9c958f"
      #expect(self.contrastRatio(darkSecondary, darkBg) >= 4.5)
      #expect(self.contrastRatio(darkMuted, darkBg) >= 4.5)
      #expect(self.contrastRatio(darkMuted, darkCard) >= 4.5)
   }

   /// Every bundled color scheme must clear WCAG AA on the surfaces the DocC chrome and the
   /// generic theme render: the success badge, muted eyebrow text, accent-as-link text, and the
   /// accent-contrast color used as button/active-row text on an accent fill – in light AND dark.
   /// Backs the AGENTS.md guarantee that "the 15 bundled color schemes pass WCAG AA contrast".
   @Test("All bundled color schemes meet WCAG AA on key surfaces", arguments: TokenCSSGenerator.availableColorSchemes)
   func allSchemesMeetWCAGAA(schemeName: String) throws {
      let t = try #require(TokenCSSGenerator.loadColorScheme(named: schemeName), "scheme \(schemeName) failed to load")

      // Resolve a token's light/dark value, falling back to `any` when no dark variant exists.
      func light(_ v: TokenValue?) -> String { v!.any }
      func dark(_ v: TokenValue?) -> String { v?.dark ?? v!.any }

      // Each shipped scheme defines all of these; a missing token force-unwraps to a crash,
      // which is itself the regression signal (a scheme dropped a required color).
      let bg = t.colorBg, bgAlt = t.colorBgAlt
      let bgCard = t.colorBgCard ?? t.colorBg
      let secondary = t.colorTextSecondary, muted = t.colorTextMuted, success = t.colorSuccess
      let accent = t.colorAccent, contrast = t.colorAccentContrast

      // Secondary and muted are body/caption text that can render on any of the three surfaces
      // (page, alt sections, cards), so both must clear AA on all three in both modes.
      let surfaces: [(String, TokenValue?)] = [("bg", bg), ("bgAlt", bgAlt), ("bgCard", bgCard)]
      for (label, surface) in surfaces {
         #expect(self.contrastRatio(light(secondary), light(surface)) >= 4.5, "\(schemeName) secondary/\(label) light")
         #expect(self.contrastRatio(dark(secondary), dark(surface)) >= 4.5, "\(schemeName) secondary/\(label) dark")
         #expect(self.contrastRatio(light(muted), light(surface)) >= 4.5, "\(schemeName) muted/\(label) light")
         #expect(self.contrastRatio(dark(muted), dark(surface)) >= 4.5, "\(schemeName) muted/\(label) dark")
      }
      // 1. Community badge: success text on the alt surface.
      #expect(self.contrastRatio(light(success), light(bgAlt)) >= 4.5, "\(schemeName) success/bgAlt light")
      #expect(self.contrastRatio(dark(success), dark(bgAlt)) >= 4.5, "\(schemeName) success/bgAlt dark")
      // 2. Accent as link text on the page background.
      #expect(self.contrastRatio(light(accent), light(bg)) >= 4.5, "\(schemeName) accent/bg light")
      #expect(self.contrastRatio(dark(accent), dark(bg)) >= 4.5, "\(schemeName) accent/bg dark")
      // 3. Accent-contrast as button/active-row text on an accent fill.
      #expect(self.contrastRatio(light(contrast), light(accent)) >= 4.5, "\(schemeName) contrast/accent light")
      #expect(self.contrastRatio(dark(contrast), dark(accent)) >= 4.5, "\(schemeName) contrast/accent dark")
   }
}
