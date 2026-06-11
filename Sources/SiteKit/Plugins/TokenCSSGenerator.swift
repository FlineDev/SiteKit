import Foundation
import Yams

enum TokenCSSGenerator {
   /// Available built-in preset names
   static let availablePresets = ["default", "warm", "minimal", "bold"]

   /// Available built-in color scheme names
   static let availableColorSchemes = [
      "teal", "orange", "violet", "indigo", "rose", "stone",
      "ocean", "forest", "sunset", "lavender", "amber", "emerald",
      "slate", "coral", "midnight",
   ]

   /// Available built-in font pairing names
   static let availableFontPairings = [
      "system", "modern", "editorial", "geometric", "friendly", "professional",
   ]

   /// Preset descriptions for CLI display
   static let presetDescriptions: [(name: String, description: String)] = [
      ("default", "Clean modern, system fonts, indigo accent"),
      ("warm", "Warm ivory, Sora + Nunito Sans, teal accent"),
      ("minimal", "Editorial, serif headings, stone accent"),
      ("bold", "High contrast, Space Grotesk + Inter, rose accent"),
   ]

   /// Generates CSS from theme tokens, preset, color scheme, and/or font pairing.
   /// Resolution order: layout defaults → preset → colorScheme → fontPairing → token overrides.
   /// Returns nil if the theme has no tokens, preset, color scheme, or font pairing.
   static func generate(themeConfig: ThemeConfig?) -> String? {
      guard let resolvedTokens = self.resolveTokens(themeConfig: themeConfig) else { return nil }
      // `@font-face` rules are emitted separately (see `selfHostedFontFaceCSS`) so they can
      // be loaded async – inlining them in critical CSS causes the browser to start font
      // downloads before FCP, competing with HTML for bandwidth on slow connections.
      return self.generateCSS(from: resolvedTokens, selfHostedFonts: false)
   }

   /// Returns the `@font-face` CSS for self-hosted woff2 fonts, or nil if not self-hosting.
   /// Meant to be emitted as a separate stylesheet and loaded async (preload+onload pattern)
   /// – inlining it in critical CSS would start font downloads before FCP.
   static func selfHostedFontFaceCSS(themeConfig: ThemeConfig?) -> String? {
      guard let themeConfig, themeConfig.selfHostedFonts == true else { return nil }
      guard let tokens = self.resolveTokens(themeConfig: themeConfig) else { return nil }
      let css = self.generateFontFaceRules(from: tokens)
      return css.isEmpty ? nil : css
   }

   /// Returns the Google Fonts stylesheet URL for the resolved theme tokens, or nil if no web fonts are needed.
   ///
   /// Use this to emit a `<link rel="stylesheet">` tag in the HTML `<head>` instead of an `@import`
   /// in CSS, which avoids an extra round-trip in the critical rendering path (HTML → CSS → @import → fonts
   /// becomes HTML → [CSS + fonts in parallel]).
   ///
   /// Returns nil when `themeConfig.selfHostedFonts == true` – in that mode SiteKit generates
   /// `@font-face` rules (see `generateCSS`) referencing local woff2 files in `Theme/fonts/`.
   static func fontsLinkURL(themeConfig: ThemeConfig?) -> String? {
      guard let themeConfig else { return nil }
      if themeConfig.selfHostedFonts == true { return nil }
      guard let resolvedTokens = self.resolveTokens(themeConfig: themeConfig) else { return nil }
      return self.generateFontsURL(from: resolvedTokens)
   }

   /// Returns the list of preload URLs for self-hosted woff2 fonts, or empty if not self-hosting.
   /// Callers emit `<link rel="preload" as="font" type="font/woff2" crossorigin href="...">` for each.
   static func selfHostedFontPreloadURLs(themeConfig: ThemeConfig?) -> [String] {
      guard let themeConfig, themeConfig.selfHostedFonts == true else { return [] }
      guard let tokens = self.resolveTokens(themeConfig: themeConfig) else { return [] }
      // Preload only the body and heading regular (400) weights – these cover most above-the-fold
      // text. Other weights load on-demand from @font-face.
      var urls: [String] = []
      for font in [tokens.fontBody, tokens.fontHeading].compactMap({ $0 }) where font.requiresImport {
         let familyClean = font.family.replacing(" ", with: "")
         urls.append("/assets/theme/fonts/\(familyClean)-400.woff2")
      }
      return Array(Set(urls)).sorted()
   }

   /// Resolves tokens through the 4-layer cascade (layout defaults → preset → colorScheme → fontPairing → overrides).
   private static func resolveTokens(themeConfig: ThemeConfig?) -> ThemeTokens? {
      guard let themeConfig, themeConfig.hasTokens else { return nil }

      // Start with layout defaults
      var resolvedTokens = Self.layoutDefaults

      // Layer 1: preset (all tokens – backward compatible)
      if let presetName = themeConfig.preset, let presetTokens = self.loadPreset(named: presetName) {
         resolvedTokens = resolvedTokens.merging(with: presetTokens)
      }

      // Layer 2: color scheme (colors only)
      if let schemeName = themeConfig.colorScheme, let schemeTokens = self.loadColorScheme(named: schemeName) {
         resolvedTokens = resolvedTokens.merging(with: schemeTokens)
      }

      // Layer 3: font pairing (fonts only)
      if let pairingName = themeConfig.fontPairing, let pairingTokens = self.loadFontPairing(named: pairingName) {
         resolvedTokens = resolvedTokens.merging(with: pairingTokens)
      }

      // Layer 4: explicit token overrides (always last)
      if let userTokens = themeConfig.tokens {
         resolvedTokens = resolvedTokens.merging(with: userTokens)
      }

      return resolvedTokens
   }

   /// Loads a built-in preset by name from bundled resources
   static func loadPreset(named name: String) -> ThemeTokens? {
      self.loadYAMLResource(named: name)
   }

   /// Loads a built-in color scheme by name from bundled resources
   static func loadColorScheme(named name: String) -> ThemeTokens? {
      self.loadYAMLResource(named: name)
   }

   /// Loads a built-in font pairing by name from bundled resources
   static func loadFontPairing(named name: String) -> ThemeTokens? {
      self.loadYAMLResource(named: name)
   }

   /// Sensible layout defaults so sites using only colorScheme + fontPairing still get layout tokens
   private static let layoutDefaults = ThemeTokens(
      maxWidth: "1200px",
      contentWidth: "720px",
      wideContentWidth: "900px",
      headerHeight: "64px",
      radius: "8px",
      radiusLg: "12px",
      transition: "0.2s ease"
   )

   private static func loadYAMLResource(named name: String) -> ThemeTokens? {
      guard let url = Bundle.module.url(forResource: name, withExtension: "yaml") else {
         return nil
      }

      guard let yamlString = try? String(contentsOf: url, encoding: .utf8) else { return nil }

      let decoder = YAMLDecoder()
      return try? decoder.decode(ThemeTokens.self, from: yamlString)
   }

   // MARK: - CSS Generation

   private static func generateCSS(from tokens: ThemeTokens, selfHostedFonts: Bool = false) -> String {
      var css = "/* Generated by SiteKit from theme tokens – do not edit */\n"

      // @font-face rules for self-hosted fonts. For non-self-hosted, Google Fonts CSS
      // is loaded separately via `<link>` in HTML (see `fontsLinkURL(themeConfig:)`).
      if selfHostedFonts {
         let faceCSS = self.generateFontFaceRules(from: tokens)
         if !faceCSS.isEmpty {
            css += faceCSS + "\n"
         }
      }

      // :root light mode variables
      css += ":root {\n"
      css += self.lightModeVariables(from: tokens)
      css += self.fontVariables(from: tokens)
      css += self.layoutVariables(from: tokens)
      css += "}\n"

      // [data-theme="dark"] variables
      let darkVars = self.darkModeVariables(from: tokens)
      if !darkVars.isEmpty {
         css += "\n[data-theme=\"dark\"] {\n"
         css += darkVars
         css += "}\n"
      }

      return css
   }

   private static func lightModeVariables(from tokens: ThemeTokens) -> String {
      let lines = tokens.colorTokens.map { name, value in
         "   \(self.cssVariableName(for: name)): \(value.any);"
      }
      return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
   }

   private static func darkModeVariables(from tokens: ThemeTokens) -> String {
      let lines = tokens.colorTokens.compactMap { name, value -> String? in
         guard let dark = value.dark else { return nil }
         return "   \(self.cssVariableName(for: name)): \(dark);"
      }
      return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
   }

   /// Converts a camelCase token name to a CSS variable name.
   /// e.g., "colorBg" → "--color-bg", "colorBgAlt" → "--color-bg-alt"
   private static func cssVariableName(for camelCase: String) -> String {
      var result = "--"
      for char in camelCase {
         if char.isUppercase {
            result += "-" + char.lowercased()
         } else {
            result += String(char)
         }
      }
      return result
   }

   private static func fontVariables(from tokens: ThemeTokens) -> String {
      var lines: [String] = []

      if let font = tokens.fontHeading {
         let stack = self.fontStack(for: font, fallback: "sans-serif")
         lines.append("   --font-heading: \(stack);")
      }
      if let font = tokens.fontBody {
         let stack = self.fontStack(for: font, fallback: "sans-serif")
         lines.append("   --font-sans: \(stack);")
      }
      if let font = tokens.fontMono {
         let stack = self.fontStack(for: font, fallback: "monospace")
         lines.append("   --font-mono: \(stack);")
      }

      return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
   }

   private static func layoutVariables(from tokens: ThemeTokens) -> String {
      var lines: [String] = []
      if let v = tokens.maxWidth { lines.append("   --max-width: \(v);") }
      if let v = tokens.contentWidth { lines.append("   --content-width: \(v);") }
      if let v = tokens.wideContentWidth { lines.append("   --wide-content-width: \(v);") }
      if let v = tokens.headerHeight { lines.append("   --header-height: \(v);") }
      if let v = tokens.radius { lines.append("   --radius: \(v);") }
      if let v = tokens.radiusLg { lines.append("   --radius-lg: \(v);") }
      if let v = tokens.transition { lines.append("   --transition: \(v);") }
      if let v = tokens.staticPageWidth { lines.append("   --static-page-width: \(v);") }
      if let v = tokens.logoSize { lines.append("   --logo-size: \(v);") }
      if let v = tokens.logoRadius { lines.append("   --logo-radius: \(v);") }
      if let v = tokens.footerMarginTop { lines.append("   --footer-margin-top: \(v);") }
      return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
   }

   // MARK: - Font Helpers

   private static func fontStack(for font: FontConfig, fallback: String) -> String {
      if font.requiresImport {
         let quoted = "\"\(font.family)\""
         switch fallback {
         case "monospace":
            return "\(quoted), \"SF Mono\", \"Fira Code\", Menlo, Monaco, \(fallback)"
         case "serif":
            return "\(quoted), Georgia, \"Times New Roman\", \(fallback)"
         default:
            return "\(quoted), -apple-system, BlinkMacSystemFont, \"Segoe UI\", \(fallback)"
         }
      } else {
         return font.family
      }
   }

   /// Generates `@font-face` rules for self-hosted woff2 fonts. Expects files at
   /// `/assets/theme/fonts/{FamilyNoSpaces}-{weight}.woff2`. Uses `font-display: swap`
   /// so text renders immediately with fallback and upgrades when the web font arrives.
   private static func generateFontFaceRules(from tokens: ThemeTokens) -> String {
      var out: [String] = []
      var seen = Set<String>()
      for font in [tokens.fontHeading, tokens.fontBody, tokens.fontMono].compactMap({ $0 }) {
         guard font.requiresImport else { continue }
         let familyClean = font.family.replacing(" ", with: "")
         let weights = font.weights ?? FontConfig.defaultWeights
         for weight in weights.sorted() {
            let key = "\(familyClean)-\(weight)"
            guard seen.insert(key).inserted else { continue }
            out.append(
               "@font-face { font-family: '\(font.family)'; font-style: normal; font-weight: \(weight); font-display: swap; src: url('/assets/theme/fonts/\(familyClean)-\(weight).woff2') format('woff2'); }"
            )
         }
      }
      return out.joined(separator: "\n")
   }

   /// Returns the Google Fonts stylesheet URL for all non-system fonts, or nil if no web fonts needed.
   private static func generateFontsURL(from tokens: ThemeTokens) -> String? {
      var families: [String] = []

      for font in [tokens.fontHeading, tokens.fontBody, tokens.fontMono].compactMap({ $0 }) {
         guard font.requiresImport else { continue }

         let weights = font.weights ?? FontConfig.defaultWeights
         let encodedFamily = font.family.replacing(" ", with: "+")

         if weights.count == 1, weights[0] == 400 {
            families.append("family=\(encodedFamily)")
         } else {
            let weightStr = weights.sorted().map(String.init).joined(separator: ";")
            families.append("family=\(encodedFamily):wght@\(weightStr)")
         }
      }

      guard !families.isEmpty else { return nil }

      // Deduplicate (e.g., same mono font in heading and mono)
      let uniqueFamilies = Array(Set(families)).sorted()
      return "https://fonts.googleapis.com/css2?\(uniqueFamilies.joined(separator: "&"))&display=swap"
   }
}
