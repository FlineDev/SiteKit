import Foundation
import Testing
import Yams
@testable import SiteKit

@Suite("SiteConfig")
struct SiteConfigTests {
   private static func decodeYAML(_ yaml: String) throws -> SiteConfig {
      try YAMLDecoder().decode(SiteConfig.self, from: yaml)
   }

   @Test("Decodes minimal YAML with all optional fields omitted")
   func decodeMinimalYAML() throws {
      let yaml = """
      name: "Minimal Site"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      """
      let config = try Self.decodeYAML(yaml)
      #expect(config.name == "Minimal Site")
      #expect(config.baseURL == "https://example.com")
      #expect(config.language == "en")
      #expect(config.description == "")
      #expect(config.assetsDirectory == "Content/Assets")
      #expect(config.categories.isEmpty)
   }

   @Test("Accepts legacy `defaultLanguage` key as alias for `language`")
   func decodeDefaultLanguageAlias() throws {
      let yaml = """
      name: "Blog"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      defaultLanguage: "de"
      """
      let config = try Self.decodeYAML(yaml)
      #expect(config.language == "de")
   }

   @Test("`language` wins when both `language` and `defaultLanguage` are present")
   func decodeLanguageWinsOverDefaultLanguage() throws {
      let yaml = """
      name: "Blog"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      language: "en"
      defaultLanguage: "de"
      """
      let config = try Self.decodeYAML(yaml)
      #expect(config.language == "en")
   }

   @Test("Strict-shaped YAML continues to decode identically")
   func decodeStrictShapedYAMLUnchanged() throws {
      let yaml = """
      name: "Strict Site"
      baseURL: "https://example.com"
      language: "fr"
      description: "A strict-shaped site"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      assetsDirectory: "Static/Assets"
      categories:
        - name: "Dev"
          slug: "dev"
      """
      let config = try Self.decodeYAML(yaml)
      #expect(config.language == "fr")
      #expect(config.description == "A strict-shaped site")
      #expect(config.assetsDirectory == "Static/Assets")
      #expect(config.categories.count == 1)
      #expect(config.categories.first?.slug == "dev")
   }

   @Test("Default values are applied")
   func defaultValues() {
      let config = SiteConfig(name: "Test", baseURL: "https://example.com")
      #expect(config.language == "en")
      #expect(config.author == nil)
      #expect(config.contentDirectory == "Content")
      #expect(config.outputDirectory == "_Site")
      #expect(config.categories.isEmpty)
      #expect(config.blogURLPrefix == nil)
      #expect(config.promotions == nil)
   }

   @Test("All fields can be set")
   func allFields() {
      let config = SiteConfig(
         name: "My Site",
         baseURL: "https://example.com",
         language: "de",
         author: Person(name: "Author"),
         description: "A test site",
         categories: [CategoryConfig(name: "Blog", slug: "blog")],
         blogURLPrefix: "articles",
         promotions: PromotionsConfig(endSlots: 2, inlineSlots: 0, items: [])
      )
      #expect(config.name == "My Site")
      #expect(config.language == "de")
      #expect(config.blogURLPrefix == "articles")
      #expect(config.promotions?.endSlots == 2)
      #expect(config.categories.count == 1)
   }

   @Test("PromotionItemConfig defaults")
   func promoItemDefaults() {
      let item = PromotionItemConfig(id: "test", title: "Title", text: "Text")
      #expect(item.weight == 1)
      #expect(item.style == "highlight")
      #expect(item.emoji == nil)
      #expect(item.linkURL == nil)
      #expect(item.targetTags == nil)
      #expect(item.excludeTags == nil)
   }

   @Test("PromotionsConfig defaults")
   func promoConfigDefaults() {
      let config = PromotionsConfig()
      #expect(config.endSlots == nil)
      #expect(config.inlineSlots == nil)
      #expect(config.items.isEmpty)
   }

   @Test("CategoryConfig stores all fields")
   func categoryConfig() {
      let cat = CategoryConfig(name: "Developer", slug: "developer", description: "Dev stuff")
      #expect(cat.name == "Developer")
      #expect(cat.slug == "developer")
      #expect(cat.description == "Dev stuff")
   }

   @Test("ThemeConfig externalJS defaults to empty")
   func themeConfigExternalJSDefault() {
      let theme = ThemeConfig(name: "Test")
      #expect(theme.externalJS.isEmpty)
      #expect(theme.externalCSS.isEmpty)
   }

   @Test("ThemeConfig externalJS can be set")
   func themeConfigExternalJS() {
      let theme = ThemeConfig(
         name: "Test",
         externalCSS: ["https://cdn.example.com/style.css"],
         externalJS: ["https://cdn.example.com/highlight.js"]
      )
      #expect(theme.externalJS == ["https://cdn.example.com/highlight.js"])
      #expect(theme.externalCSS == ["https://cdn.example.com/style.css"])
   }

   // MARK: - DocC feature flags

   @Test("docc feature flags default to contributors off, missing off, search on when omitted")
   func doccFeatureFlagDefaults() throws {
      let yaml = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        homeEyebrow: "Docs"
      """
      let config = try Self.decodeYAML(yaml)
      let docc = try #require(config.docc)
      #expect(docc.contributorsEnabled == false)
      #expect(docc.missingSessionsEnabled == false)
      #expect(docc.searchEnabled == true)
      #expect(docc.searchNoteTypeFilterEnabled == false)
   }

   @Test("docc feature flags decode from the exact YAML keys (WWDCNotes opt-in)")
   func doccFeatureFlagsDecode() throws {
      let yaml = """
      name: "WWDCNotes"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        contributors: true
        missingSessions: true
        search: false
        searchNoteTypeFilter: true
      """
      let config = try Self.decodeYAML(yaml)
      let docc = try #require(config.docc)
      #expect(docc.contributorsEnabled == true)
      #expect(docc.missingSessionsEnabled == true)
      #expect(docc.searchEnabled == false)
      #expect(docc.searchNoteTypeFilterEnabled == true)
   }

   @Test("docc.frameworks displayName decodes when present and stays nil when absent")
   func doccFrameworkDisplayNameDecode() throws {
      let yaml = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        frameworks:
          swiftui:
            glyph: fa-solid fa-layer-group
            colors: ["#1e88e5", "#42a5f5"]
            displayName: SwiftUI
          appintents:
            glyph: fa-solid fa-bolt
            colors: ["#111"]
      """
      let docc = try #require(Self.decodeYAML(yaml).docc)
      #expect(docc.frameworks?["swiftui"]?.displayName == "SwiftUI")
      #expect(docc.frameworks?["appintents"]?.displayName == nil)
   }

   @Test("docc.articleHero decodes both styles and defaults to card when absent")
   func doccArticleHeroDecode() throws {
      let bandYAML = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        articleHero: band
      """
      let band = try #require(Self.decodeYAML(bandYAML).docc)
      #expect(band.articleHeroStyle == .band)

      let cardYAML = bandYAML.replacingOccurrences(of: "articleHero: band", with: "articleHero: card")
      let card = try #require(Self.decodeYAML(cardYAML).docc)
      #expect(card.articleHeroStyle == .card)

      let absentYAML = bandYAML.replacingOccurrences(of: "articleHero: band", with: "homeEyebrow: \"Docs\"")
      let absent = try #require(Self.decodeYAML(absentYAML).docc)
      #expect(absent.articleHeroStyle == .card)
   }

   @Test("docc.footerLegalNotice decodes a multiline block scalar and stays nil when absent")
   func doccFooterLegalNoticeDecode() throws {
      let yaml = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        footerLegalNotice: |
          All content copyright Apple Inc. All rights reserved.

          This website is not made by, affiliated with, nor endorsed by Apple.
      """
      let docc = try #require(Self.decodeYAML(yaml).docc)
      let notice = try #require(docc.footerLegalNotice)
      // The block scalar keeps its line structure so the renderer can split paragraphs.
      #expect(notice.contains("All content copyright Apple Inc."))
      #expect(notice.contains("\n"))
      #expect(notice.contains("not made by, affiliated with"))

      let absentYAML = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        homeEyebrow: "Docs"
      """
      let absent = try #require(Self.decodeYAML(absentYAML).docc)
      #expect(absent.footerLegalNotice == nil)
   }

   @Test("docc.brand.logoWidth/logoHeight decode when present")
   func doccBrandLogoSizeDecode() throws {
      let yaml = """
      name: "WWDCNotes"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        brand:
          prefix: "WWDC"
          accent: "Notes"
          logoPath: "logo.svg"
          logoWidth: 30
          logoHeight: 30
      """
      let brand = try #require(Self.decodeYAML(yaml).docc?.brand)
      #expect(brand.logoWidth == 30)
      #expect(brand.logoHeight == 30)
   }

   @Test("docc.brand without logoWidth/logoHeight decodes with nil sizes (existing sites unchanged)")
   func doccBrandLogoSizeAbsentDecode() throws {
      let yaml = """
      name: "WWDCNotes"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        brand:
          prefix: "WWDC"
          accent: "Notes"
          logoPath: "logo.svg"
      """
      let brand = try #require(Self.decodeYAML(yaml).docc?.brand)
      #expect(brand.logoWidth == nil)
      #expect(brand.logoHeight == nil)
      #expect(brand.prefix == "WWDC")
      #expect(brand.logoPath == "logo.svg")
   }

   @Test("docc.articleHero rejects unknown values instead of silently falling back")
   func doccArticleHeroRejectsTypo() {
      let yaml = """
      name: "Docs"
      baseURL: "https://example.com"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      docc:
        articleHero: banner
      """
      #expect(throws: (any Error).self) {
         try Self.decodeYAML(yaml)
      }
   }
}
