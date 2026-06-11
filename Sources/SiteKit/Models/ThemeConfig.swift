import Foundation
import Yams

/// Failures while loading `Theme/theme.yaml`.
public enum ThemeConfigError: Error {
   /// No `theme.yaml` exists at the given URL.
   case fileNotFound(URL)
   /// The file exists but does not decode; the payload is the decoder's error
   /// description.
   case invalidYAML(String)
   /// `preset:` names a token bundle that is not shipped with SiteKit.
   case presetNotFound(String)
}

// MARK: - Font Configuration

/// One font slot (heading, body, or mono) in the theme tokens.
public struct FontConfig: Codable, Sendable, Equatable {
   /// CSS `font-family` value – a web font name (`"Inter"`) or a system stack
   /// (`"system-ui, sans-serif"`).
   public let family: String

   /// The numeric weights to load for a web font; nil falls back to
   /// `defaultWeights` (400/600/700). Irrelevant for system stacks.
   public let weights: [Int]?

   /// Memberwise initializer.
   public init(family: String, weights: [Int]? = nil) {
      self.family = family
      self.weights = weights
   }

   /// Default weights used when none specified
   public static let defaultWeights = [400, 600, 700]

   /// Whether this font requires a web font import (not a system font stack)
   public var requiresImport: Bool {
      let systemFonts = ["-apple-system", "BlinkMacSystemFont", "system-ui", "sans-serif", "serif", "monospace"]
      return !systemFonts.contains(where: { self.family.lowercased().contains($0.lowercased()) })
   }
}

// MARK: - Token Value (Appearance Variants)

/// A design token value with appearance variants, inspired by Apple's Asset Catalog.
/// - `any`: The fallback value, used in light mode or any non-specified mode.
/// - `dark`: The dark mode value. If nil, the `any` value is used in dark mode too.
/// - Future: additional modes (e.g., `highContrast`, `sepia`) can be added by plugins.
public struct TokenValue: Codable, Sendable, Equatable {
   /// The fallback CSS value – used in light mode and any unspecified mode.
   public let any: String

   /// The dark-mode CSS value; nil reuses `any` in dark mode.
   public let dark: String?

   /// Memberwise initializer.
   public init(any: String, dark: String? = nil) {
      self.any = any
      self.dark = dark
   }

   /// Merges another TokenValue on top. The other's values override self's.
   public func merging(with other: TokenValue) -> TokenValue {
      TokenValue(
         any: other.any,
         dark: other.dark ?? self.dark
      )
   }
}

// MARK: - Theme Tokens

/// The design-token vocabulary behind the generated `tokens.css`.
///
/// Every non-nil token becomes a CSS custom property on `:root` – camelCase
/// name to kebab-case variable (`colorBg` → `--color-bg`). Tokens resolve in
/// layers: layout defaults → `preset` → `colorScheme` → `fontPairing` →
/// explicit `tokens:` overrides (see `TokenValue.merging(with:)`).
public struct ThemeTokens: Codable, Sendable, Equatable {
   // Colors (each with any/dark appearance variants)

   /// Page background color.
   public let colorBg: TokenValue?
   /// Alternate background for visually separated bands (e.g. alternating
   /// sections).
   public let colorBgAlt: TokenValue?
   /// Background of card surfaces (listing tiles, promo boxes).
   public let colorBgCard: TokenValue?
   /// Primary body text color.
   public let colorText: TokenValue?
   /// Secondary text color for supporting copy.
   public let colorTextSecondary: TokenValue?
   /// Muted text color for meta information (dates, counts).
   public let colorTextMuted: TokenValue?
   /// Brand accent color – links, buttons, active states.
   public let colorAccent: TokenValue?
   /// Accent color in hovered/pressed states.
   public let colorAccentHover: TokenValue?
   /// Light accent tint for subtle accent-colored surfaces (badges,
   /// highlights).
   public let colorAccentLight: TokenValue?
   /// Text/icon color that sits ON an accent-filled surface (button fill, active nav row).
   /// Must meet WCAG AA against `colorAccent`: typically white in light mode (accents are dark)
   /// and a near-black ink in dark mode (accents are light pastels). Components read it as
   /// `var(--color-accent-contrast, #fff)`, so a missing token still falls back to white.
   public let colorAccentContrast: TokenValue?
   /// Standard border/divider color.
   public let colorBorder: TokenValue?
   /// Lighter border variant for subtle separation.
   public let colorBorderLight: TokenValue?
   /// Background of code blocks and inline code.
   public let colorCodeBg: TokenValue?
   /// Text color inside code blocks and inline code.
   public let colorCodeText: TokenValue?
   /// Positive/confirmation state color.
   public let colorSuccess: TokenValue?
   /// CSS `box-shadow` value for standard elevation.
   public let colorShadow: TokenValue?
   /// CSS `box-shadow` value for large elevation (modals, popovers).
   public let colorShadowLg: TokenValue?
   /// Site header background; when unset, the theme CSS's own fallback value
   /// applies (the templates read `var(--color-header-bg, <fallback>)`).
   public let colorHeaderBg: TokenValue?
   /// Site footer background; when unset, the theme CSS's own fallback value
   /// applies.
   public let colorFooterBg: TokenValue?
   /// Informational state color (info callouts).
   public let colorInfo: TokenValue?
   /// Warning state color (warning callouts).
   public let colorWarning: TokenValue?

   // Typography (no appearance variants)

   /// Font for headings (h1–h6).
   public let fontHeading: FontConfig?
   /// Font for body copy – the default text font.
   public let fontBody: FontConfig?
   /// Monospace font for code.
   public let fontMono: FontConfig?

   // Layout (no appearance variants)

   /// Maximum width of the overall page shell (CSS length).
   public let maxWidth: String?
   /// Maximum width of the readable content column (CSS length).
   public let contentWidth: String?
   /// Maximum width of wide content blocks that break out of the column
   /// (CSS length).
   public let wideContentWidth: String?
   /// Height of the site header (CSS length).
   public let headerHeight: String?
   /// Standard corner radius (CSS length).
   public let radius: String?
   /// Large corner radius for cards and prominent surfaces (CSS length).
   public let radiusLg: String?
   /// CSS `transition` shorthand applied to interactive elements.
   public let transition: String?
   /// Maximum width of static pages (CSS length); themes may want prose pages
   /// narrower than listings.
   public let staticPageWidth: String?
   /// Rendered size of the site logo (CSS length).
   public let logoSize: String?
   /// Corner radius of the site logo (CSS length).
   public let logoRadius: String?
   /// Top margin separating the footer from the page content (CSS length).
   public let footerMarginTop: String?

   /// Memberwise initializer; every token defaults to nil (= not overridden in
   /// this layer).
   public init(
      colorBg: TokenValue? = nil, colorBgAlt: TokenValue? = nil, colorBgCard: TokenValue? = nil,
      colorText: TokenValue? = nil, colorTextSecondary: TokenValue? = nil, colorTextMuted: TokenValue? = nil,
      colorAccent: TokenValue? = nil, colorAccentHover: TokenValue? = nil, colorAccentLight: TokenValue? = nil,
      colorAccentContrast: TokenValue? = nil,
      colorBorder: TokenValue? = nil, colorBorderLight: TokenValue? = nil,
      colorCodeBg: TokenValue? = nil, colorCodeText: TokenValue? = nil,
      colorSuccess: TokenValue? = nil, colorShadow: TokenValue? = nil, colorShadowLg: TokenValue? = nil,
      colorHeaderBg: TokenValue? = nil, colorFooterBg: TokenValue? = nil,
      colorInfo: TokenValue? = nil, colorWarning: TokenValue? = nil,
      fontHeading: FontConfig? = nil, fontBody: FontConfig? = nil, fontMono: FontConfig? = nil,
      maxWidth: String? = nil, contentWidth: String? = nil, wideContentWidth: String? = nil,
      headerHeight: String? = nil, radius: String? = nil, radiusLg: String? = nil,
      transition: String? = nil,
      staticPageWidth: String? = nil, logoSize: String? = nil, logoRadius: String? = nil,
      footerMarginTop: String? = nil
   ) {
      self.colorBg = colorBg
      self.colorBgAlt = colorBgAlt
      self.colorBgCard = colorBgCard
      self.colorText = colorText
      self.colorTextSecondary = colorTextSecondary
      self.colorTextMuted = colorTextMuted
      self.colorAccent = colorAccent
      self.colorAccentHover = colorAccentHover
      self.colorAccentLight = colorAccentLight
      self.colorAccentContrast = colorAccentContrast
      self.colorBorder = colorBorder
      self.colorBorderLight = colorBorderLight
      self.colorCodeBg = colorCodeBg
      self.colorCodeText = colorCodeText
      self.colorSuccess = colorSuccess
      self.colorShadow = colorShadow
      self.colorShadowLg = colorShadowLg
      self.colorHeaderBg = colorHeaderBg
      self.colorFooterBg = colorFooterBg
      self.colorInfo = colorInfo
      self.colorWarning = colorWarning
      self.fontHeading = fontHeading
      self.fontBody = fontBody
      self.fontMono = fontMono
      self.maxWidth = maxWidth
      self.contentWidth = contentWidth
      self.wideContentWidth = wideContentWidth
      self.headerHeight = headerHeight
      self.radius = radius
      self.radiusLg = radiusLg
      self.transition = transition
      self.staticPageWidth = staticPageWidth
      self.logoSize = logoSize
      self.logoRadius = logoRadius
      self.footerMarginTop = footerMarginTop
   }

   /// All color tokens as (name, value) pairs for iteration
   public var colorTokens: [(name: String, value: TokenValue)] {
      var result: [(String, TokenValue)] = []
      if let v = self.colorBg { result.append(("colorBg", v)) }
      if let v = self.colorBgAlt { result.append(("colorBgAlt", v)) }
      if let v = self.colorBgCard { result.append(("colorBgCard", v)) }
      if let v = self.colorText { result.append(("colorText", v)) }
      if let v = self.colorTextSecondary { result.append(("colorTextSecondary", v)) }
      if let v = self.colorTextMuted { result.append(("colorTextMuted", v)) }
      if let v = self.colorAccent { result.append(("colorAccent", v)) }
      if let v = self.colorAccentHover { result.append(("colorAccentHover", v)) }
      if let v = self.colorAccentLight { result.append(("colorAccentLight", v)) }
      if let v = self.colorAccentContrast { result.append(("colorAccentContrast", v)) }
      if let v = self.colorBorder { result.append(("colorBorder", v)) }
      if let v = self.colorBorderLight { result.append(("colorBorderLight", v)) }
      if let v = self.colorCodeBg { result.append(("colorCodeBg", v)) }
      if let v = self.colorCodeText { result.append(("colorCodeText", v)) }
      if let v = self.colorSuccess { result.append(("colorSuccess", v)) }
      if let v = self.colorShadow { result.append(("colorShadow", v)) }
      if let v = self.colorShadowLg { result.append(("colorShadowLg", v)) }
      if let v = self.colorHeaderBg { result.append(("colorHeaderBg", v)) }
      if let v = self.colorFooterBg { result.append(("colorFooterBg", v)) }
      if let v = self.colorInfo { result.append(("colorInfo", v)) }
      if let v = self.colorWarning { result.append(("colorWarning", v)) }
      return result
   }

   /// Merges another ThemeTokens on top, with the other's non-nil values overriding self.
   public func merging(with other: ThemeTokens) -> ThemeTokens {
      ThemeTokens(
         colorBg: Self.mergeToken(self.colorBg, other.colorBg),
         colorBgAlt: Self.mergeToken(self.colorBgAlt, other.colorBgAlt),
         colorBgCard: Self.mergeToken(self.colorBgCard, other.colorBgCard),
         colorText: Self.mergeToken(self.colorText, other.colorText),
         colorTextSecondary: Self.mergeToken(self.colorTextSecondary, other.colorTextSecondary),
         colorTextMuted: Self.mergeToken(self.colorTextMuted, other.colorTextMuted),
         colorAccent: Self.mergeToken(self.colorAccent, other.colorAccent),
         colorAccentHover: Self.mergeToken(self.colorAccentHover, other.colorAccentHover),
         colorAccentLight: Self.mergeToken(self.colorAccentLight, other.colorAccentLight),
         colorAccentContrast: Self.mergeToken(self.colorAccentContrast, other.colorAccentContrast),
         colorBorder: Self.mergeToken(self.colorBorder, other.colorBorder),
         colorBorderLight: Self.mergeToken(self.colorBorderLight, other.colorBorderLight),
         colorCodeBg: Self.mergeToken(self.colorCodeBg, other.colorCodeBg),
         colorCodeText: Self.mergeToken(self.colorCodeText, other.colorCodeText),
         colorSuccess: Self.mergeToken(self.colorSuccess, other.colorSuccess),
         colorShadow: Self.mergeToken(self.colorShadow, other.colorShadow),
         colorShadowLg: Self.mergeToken(self.colorShadowLg, other.colorShadowLg),
         colorHeaderBg: Self.mergeToken(self.colorHeaderBg, other.colorHeaderBg),
         colorFooterBg: Self.mergeToken(self.colorFooterBg, other.colorFooterBg),
         colorInfo: Self.mergeToken(self.colorInfo, other.colorInfo),
         colorWarning: Self.mergeToken(self.colorWarning, other.colorWarning),
         fontHeading: other.fontHeading ?? self.fontHeading,
         fontBody: other.fontBody ?? self.fontBody,
         fontMono: other.fontMono ?? self.fontMono,
         maxWidth: other.maxWidth ?? self.maxWidth,
         contentWidth: other.contentWidth ?? self.contentWidth,
         wideContentWidth: other.wideContentWidth ?? self.wideContentWidth,
         headerHeight: other.headerHeight ?? self.headerHeight,
         radius: other.radius ?? self.radius,
         radiusLg: other.radiusLg ?? self.radiusLg,
         transition: other.transition ?? self.transition,
         staticPageWidth: other.staticPageWidth ?? self.staticPageWidth,
         logoSize: other.logoSize ?? self.logoSize,
         logoRadius: other.logoRadius ?? self.logoRadius,
         footerMarginTop: other.footerMarginTop ?? self.footerMarginTop
      )
   }

   private static func mergeToken(_ base: TokenValue?, _ overlay: TokenValue?) -> TokenValue? {
      guard let overlay else { return base }
      guard let base else { return overlay }
      return base.merging(with: overlay)
   }
}

// MARK: - Theme Config

/// The decoded `Theme/theme.yaml` – a site's visual identity: token layers,
/// stylesheets, scripts, favicons, and the post-processor toggles.
/// `PageShell` reads it to assemble the `<head>` in FCP/LCP-friendly order.
public struct ThemeConfig: Codable, Sendable {
   /// Human-readable theme name – informational, not used for resolution.
   public let name: String

   /// Name of a built-in token bundle covering all token groups
   /// (`default`, `warm`, `minimal`, `bold`) – the first token layer.
   public let preset: String?

   /// Name of one of the 15 built-in color schemes (colors-only token layer,
   /// applied over `preset`).
   public let colorScheme: String?

   /// Name of one of the 6 built-in font pairings (fonts-only token layer,
   /// applied over `colorScheme`).
   public let fontPairing: String?

   /// Explicit token overrides – the last layer, wins over preset, color
   /// scheme, and font pairing.
   public let tokens: ThemeTokens?

   /// Theme-local stylesheet filenames, served from `/assets/theme/` and
   /// linked render-blocking (critical ones get a `preload` hint; known
   /// non-critical names like `syntax.css` are deferred).
   public let css: [String]

   /// Theme-local script filenames, served from `/assets/theme/` and loaded
   /// with `defer`.
   public let js: [String]

   /// Absolute stylesheet URLs (CDNs); each unique host also gets a
   /// `preconnect` hint.
   public let externalCSS: [String]

   /// Absolute script URLs, loaded with `defer`; hosts get `preconnect` hints.
   public let externalJS: [String]

   /// Theme-local favicon files (e.g. an SVG in `Theme/images/`), emitted as
   /// `<link rel="icon">` – independent of the pre-generated PNG set that
   /// `FaviconRenderer` copies from `Content/Assets/Favicons/`.
   public let favicons: [String]

   /// Site-relative path of the fallback social-card image used when a page
   /// declares no `image:` of its own.
   public let defaultImage: String?

   /// Raw JavaScript inlined as a `<script>` in the `<head>` – for tiny
   /// must-run-before-paint snippets like a theme-mode toggle.
   public let headInlineScript: String?

   /// Opt-in (`true`) to inject the Font Awesome CDN stylesheet when
   /// `externalCSS` doesn't already include one. The `FontAwesomeInliner`
   /// post-processor later replaces used icons with inline SVGs and strips
   /// the CDN link again.
   public let includesFontAwesome: Bool?

   /// When true, SiteKit generates `@font-face` rules referencing local woff2 files in
   /// `Theme/fonts/{Family}-{weight}.woff2` instead of loading from Google Fonts.
   /// Keeps all font data on your own origin – faster (no DNS/TLS to Google),
   /// privacy-friendly (no requests to fonts.gstatic.com), and fully offline-testable.
   ///
   /// Naming convention: the filename must be `{FamilyNameNoSpaces}-{weight}.woff2`.
   /// Example: `Inter-400.woff2`, `JetBrainsMono-500.woff2`.
   public let selfHostedFonts: Bool?

   /// Controls the `FontAwesomeInliner` post-processor (default: `true`).
   ///
   /// When true (default), SiteKit scans the rendered HTML for every `<i class="fa-...">`,
   /// resolves its SVG (cached at `.sitekit-cache/fa-icons/`, fetched once from jsdelivr),
   /// and inlines it as an `<svg>` element. Once all icons are inlined, the Font Awesome
   /// `<link>` tag is stripped from the HTML so the ~90 KB CSS + ~200 KB webfont payload
   /// is never downloaded.
   ///
   /// Set to `false` to restore the CDN-only behavior – useful for sites that inject
   /// FA icons dynamically at runtime in ways the inliner can't statically detect.
   public let inlineFontAwesome: Bool?

   /// Controls the `ImageResizer` post-processor (default: `true`).
   ///
   /// When true (default), SiteKit scans every `<img width="X" height="Y" src="...">` with
   /// a local `src`, uses ImageMagick (`magick` / `convert` on PATH) to generate 1× and 2×
   /// variants sized to the declared width, and rewrites the tag to use `srcset`. Variants
   /// are cached at `.sitekit-cache/images/` so subsequent builds are fully offline.
   /// Requires ImageMagick to be installed – if missing, a warning is logged and no
   /// changes are made (the site still builds).
   ///
   /// Set to `false` to disable (e.g. if you prefer to pre-resize your images manually).
   public let resizeImages: Bool?

   /// Whether this config uses the token system (has a preset, color scheme, font pairing, or custom tokens)
   public var hasTokens: Bool {
      self.preset != nil || self.colorScheme != nil || self.fontPairing != nil || self.tokens != nil
   }

   /// Memberwise initializer – primarily for tests and programmatic builds;
   /// sites declare their theme in `Theme/theme.yaml` and use `load(from:)`.
   public init(
      name: String,
      preset: String? = nil,
      colorScheme: String? = nil,
      fontPairing: String? = nil,
      tokens: ThemeTokens? = nil,
      css: [String] = [],
      js: [String] = [],
      externalCSS: [String] = [],
      externalJS: [String] = [],
      favicons: [String] = [],
      defaultImage: String? = nil,
      headInlineScript: String? = nil,
      includesFontAwesome: Bool? = nil,
      selfHostedFonts: Bool? = nil,
      inlineFontAwesome: Bool? = nil,
      resizeImages: Bool? = nil
   ) {
      self.name = name
      self.preset = preset
      self.colorScheme = colorScheme
      self.fontPairing = fontPairing
      self.tokens = tokens
      self.css = css
      self.js = js
      self.externalCSS = externalCSS
      self.externalJS = externalJS
      self.favicons = favicons
      self.defaultImage = defaultImage
      self.headInlineScript = headInlineScript
      self.includesFontAwesome = includesFontAwesome
      self.selfHostedFonts = selfHostedFonts
      self.inlineFontAwesome = inlineFontAwesome
      self.resizeImages = resizeImages
   }

   /// Decodes `theme.yaml`, defaulting the list fields (`css`, `js`,
   /// `externalCSS`, `externalJS`, `favicons`) to empty when absent.
   public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.preset = try container.decodeIfPresent(String.self, forKey: .preset)
      self.colorScheme = try container.decodeIfPresent(String.self, forKey: .colorScheme)
      self.fontPairing = try container.decodeIfPresent(String.self, forKey: .fontPairing)
      self.tokens = try container.decodeIfPresent(ThemeTokens.self, forKey: .tokens)
      self.css = try container.decodeIfPresent([String].self, forKey: .css) ?? []
      self.js = try container.decodeIfPresent([String].self, forKey: .js) ?? []
      self.externalCSS = try container.decodeIfPresent([String].self, forKey: .externalCSS) ?? []
      self.externalJS = try container.decodeIfPresent([String].self, forKey: .externalJS) ?? []
      self.favicons = try container.decodeIfPresent([String].self, forKey: .favicons) ?? []
      self.defaultImage = try container.decodeIfPresent(String.self, forKey: .defaultImage)
      self.headInlineScript = try container.decodeIfPresent(String.self, forKey: .headInlineScript)
      self.includesFontAwesome = try container.decodeIfPresent(Bool.self, forKey: .includesFontAwesome)
      self.selfHostedFonts = try container.decodeIfPresent(Bool.self, forKey: .selfHostedFonts)
      self.inlineFontAwesome = try container.decodeIfPresent(Bool.self, forKey: .inlineFontAwesome)
      self.resizeImages = try container.decodeIfPresent(Bool.self, forKey: .resizeImages)
   }

   /// Loads and decodes `<directory>/theme.yaml`. Throws
   /// `ThemeConfigError.fileNotFound` when the file is absent and
   /// `.invalidYAML` when it does not decode.
   public static func load(from directory: URL) throws -> ThemeConfig {
      let configPath = directory.appendingPathComponent("theme.yaml")

      guard FileManager.default.fileExists(atPath: configPath.path) else {
         throw ThemeConfigError.fileNotFound(configPath)
      }

      let yamlString = try String(contentsOf: configPath, encoding: .utf8)
      let decoder = YAMLDecoder()

      do {
         return try decoder.decode(ThemeConfig.self, from: yamlString)
      } catch {
         throw ThemeConfigError.invalidYAML(error.localizedDescription)
      }
   }
}
