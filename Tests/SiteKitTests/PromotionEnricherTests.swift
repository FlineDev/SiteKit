import Foundation
import Testing
@testable import SiteKit

@Suite("PromotionEnricher")
struct PromotionEnricherTests {
   private func makeItem(
      id: String,
      audience: String? = nil,
      weight: Int = 1,
      style: String = "highlight",
      targetTags: [String]? = nil,
      excludeTags: [String]? = nil
   ) -> PromotionItemConfig {
      PromotionItemConfig(
         id: id,
         audience: audience,
         weight: weight,
         style: style,
         title: "Title \(id)",
         text: "Text \(id)",
         targetTags: targetTags,
         excludeTags: excludeTags
      )
   }

   private func makeConfig(
      promotions: PromotionsConfig?
   ) -> SiteConfig {
      SiteConfig(
         name: "Test",
         baseURL: "https://example.com",
         language: "en",
         promotions: promotions
      )
   }

   private func makePage(
      slug: String = "test",
      tags: [String] = [],
      category: String = "developer",
      pageType: PageType = .article,
      draft: Bool = false,
      readTimeMinutes _: Int = 5
   ) -> PageModel {
      // Build htmlContent that yields ~5 min read time (≈1190 prose words at 238 wpm).
      // Tests that need a different read time pass htmlContent explicitly via the
      // PageModel initializer in the test body.
      let words = Array(repeating: "word", count: 1190).joined(separator: " ")
      return PageModel(
         id: "preview-\(slug)",
         title: "Test Article",
         date: Date(),
         slug: slug,
         htmlContent: "<p>\(words)</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         category: category,
         tags: tags,
         draft: draft,
         pageType: pageType,
         locale: "en"
      )
   }

   private func enrich(
      page: PageModel,
      promotions: PromotionsConfig?
   ) throws -> PromotionSelection? {
      let config = self.makeConfig(promotions: promotions)
      let enricher = PromotionEnricher(config: config)
      let enriched = try enricher.enrich(page)
      return enriched.extensionValue("promotion")
   }

   // MARK: - Early-exit cases

   @Test("Returns page unchanged when promotions config is nil")
   func noPromotionsConfig() throws {
      let page = self.makePage()
      let selection = try self.enrich(page: page, promotions: nil)
      #expect(selection == nil, "No promotion extension should be set when promotions are unconfigured")
   }

   @Test("Returns page unchanged when items list is empty")
   func emptyItems() throws {
      let config = PromotionsConfig(items: [])
      let page = self.makePage()
      let selection = try self.enrich(page: page, promotions: config)
      #expect(selection == nil, "No promotion extension should be set when items list is empty")
   }

   @Test("Returns page unchanged for draft pages")
   func draftPage() throws {
      let config = PromotionsConfig(items: [self.makeItem(id: "a")])
      let page = self.makePage(draft: true)
      let selection = try self.enrich(page: page, promotions: config)
      #expect(selection == nil, "Drafts should never receive promotion data")
   }

   @Test("Returns page unchanged for static pages")
   func staticPage() throws {
      let config = PromotionsConfig(items: [self.makeItem(id: "a")])
      let page = self.makePage(pageType: .staticPage)
      let selection = try self.enrich(page: page, promotions: config)
      #expect(selection == nil, "Static pages should never receive promotion data")
   }

   // MARK: - Slot count behavior

   @Test("Returns empty selection when no items configured (eligible run)")
   func noItems() throws {
      // PromotionEnricher returns the page unchanged when items.isEmpty (early exit).
      // To test the eligible-but-empty path, supply at least one item that's filtered out.
      let item = self.makeItem(id: "a", audience: "consumer")
      let config = PromotionsConfig(items: [item])
      let page = self.makePage(category: "developer")
      let selection = try self.enrich(page: page, promotions: config)
      #expect(selection != nil, "When items exist, an extension is set even if no eligible match")
      #expect(selection?.endPromos.isEmpty == true)
      #expect(selection?.inlinePromos.isEmpty == true)
   }

   @Test("Short-style section gets 1 end promo, no inline")
   func shortSectionSlots() throws {
      let items = [self.makeItem(id: "a"), self.makeItem(id: "b")]
      let config = PromotionsConfig(items: items)
      let sectionConfig = SectionConfig(
         name: "Snippets", slug: "snippets", contentDirectory: "Snippets",
         urlPrefix: "snippets", style: "short"
      )
      var page = self.makePage()
      var ext = page.extensions
      ext["sectionSlug"] = "snippets"
      page = PageModel(
         id: page.id, title: page.title, date: page.date, slug: page.slug,
         htmlContent: page.htmlContent, sourcePath: page.sourcePath,
         category: page.category, tags: page.tags, summary: page.summary,
         description: page.description, author: page.author, image: page.image,
         imageAlt: page.imageAlt, draft: page.draft, pageType: page.pageType,
         locale: page.locale, originalLanguage: page.originalLanguage,
         legalDocument: page.legalDocument, extensions: ext
      )
      let siteConfig = SiteConfig(
         name: "Test",
         baseURL: "https://example.com",
         language: "en",
         sections: [sectionConfig],
         promotions: config
      )
      let enricher = PromotionEnricher(config: siteConfig)
      let enriched = try enricher.enrich(page)
      let selection: PromotionSelection? = enriched.extensionValue("promotion")
      #expect(selection?.endPromos.count == 1)
      #expect(selection?.inlinePromos.isEmpty == true)
   }

   @Test("Explicit endSlots override overrides length-based calculation")
   func explicitSlotOverride() throws {
      let items = [self.makeItem(id: "a"), self.makeItem(id: "b"), self.makeItem(id: "c")]
      let config = PromotionsConfig(endSlots: 2, inlineSlots: 0, items: items)
      let page = self.makePage()
      let selection = try self.enrich(page: page, promotions: config)
      #expect(selection?.endPromos.count == 2)
      #expect(selection?.inlinePromos.isEmpty == true)
   }

   @Test("No promos repeat within the same article")
   func noRepeats() throws {
      let items = [self.makeItem(id: "a"), self.makeItem(id: "b"), self.makeItem(id: "c"), self.makeItem(id: "d")]
      let config = PromotionsConfig(items: items)
      let page = self.makePage(category: "developer")
      let selection = try self.enrich(page: page, promotions: config)
      let allIds = (selection?.endPromos.map(\.id) ?? []) + (selection?.inlinePromos.map(\.id) ?? [])
      #expect(Set(allIds).count == allIds.count, "Promos should not repeat")
   }

   @Test("Deterministic: same slug always produces same result")
   func deterministic() throws {
      let items = [
         self.makeItem(id: "a", weight: 2),
         self.makeItem(id: "b", weight: 2),
         self.makeItem(id: "c", weight: 2),
      ]
      let config = PromotionsConfig(items: items)
      let page1 = self.makePage(slug: "my-article")
      let page2 = self.makePage(slug: "my-article")
      let s1 = try self.enrich(page: page1, promotions: config)
      let s2 = try self.enrich(page: page2, promotions: config)
      #expect(s1?.endPromos.map(\.id) == s2?.endPromos.map(\.id))
      #expect(s1?.inlinePromos.map(\.id) == s2?.inlinePromos.map(\.id))
   }

   // MARK: - Audience / tag filtering

   @Test("Audience filtering: developer items shown on developer articles")
   func audienceFiltering() throws {
      let items = [
         self.makeItem(id: "dev-app", audience: "developer"),
         self.makeItem(id: "consumer-app", audience: "consumer"),
         self.makeItem(id: "general", audience: "general"),
      ]
      let promos = PromotionsConfig(audienceMapping: ["developer": "developer", "indie": "consumer"], items: items)

      let devPage = self.makePage(category: "developer")
      let dev = try self.enrich(page: devPage, promotions: promos)
      let devIds = Set((dev?.endPromos.map(\.id) ?? []) + (dev?.inlinePromos.map(\.id) ?? []))
      #expect(!devIds.contains("consumer-app"))

      let consumerPage = self.makePage(category: "indie")
      let consumer = try self.enrich(page: consumerPage, promotions: promos)
      let consumerIds = Set((consumer?.endPromos.map(\.id) ?? []) + (consumer?.inlinePromos.map(\.id) ?? []))
      #expect(!consumerIds.contains("dev-app"))
   }

   @Test("excludeTags removes items for matching articles")
   func excludeTagsFiltering() throws {
      let items = [
         self.makeItem(id: "translatekit-promo", audience: "developer", excludeTags: ["translatekit"]),
         self.makeItem(id: "general", audience: "developer"),
      ]
      let config = PromotionsConfig(audienceMapping: ["developer": "developer"], items: items)
      // 3-min article so we get exactly 1 end slot
      let page = PageModel(
         title: "T", slug: "test",
         htmlContent: "<p>" + Array(repeating: "w", count: 600).joined(separator: " ") + "</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         category: "developer",
         tags: ["translatekit", "localization"],
         pageType: .article,
         locale: "en"
      )
      let siteConfig = self.makeConfig(promotions: config)
      let enriched = try PromotionEnricher(config: siteConfig).enrich(page)
      let selection: PromotionSelection? = enriched.extensionValue("promotion")
      #expect(selection?.endPromos.count == 1)
      #expect(selection?.endPromos.first?.id == "general")
   }

   @Test("Tag matching is case-insensitive")
   func caseInsensitiveMatching() throws {
      let items = [self.makeItem(id: "dev", audience: "developer", targetTags: ["Developer"])]
      let config = PromotionsConfig(items: items)
      let page = PageModel(
         title: "T", slug: "test",
         htmlContent: "<p>" + Array(repeating: "w", count: 600).joined(separator: " ") + "</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         category: "developer",
         pageType: .article,
         locale: "en"
      )
      let siteConfig = self.makeConfig(promotions: config)
      let enriched = try PromotionEnricher(config: siteConfig).enrich(page)
      let selection: PromotionSelection? = enriched.extensionValue("promotion")
      #expect(selection?.endPromos.count == 1)
   }

   @Test("targetTags override audience: consumer promo on developer article via tag match")
   func targetTagsOverrideAudience() throws {
      let items = [
         PromotionItemConfig(
            id: "posters", audience: "consumer", weight: 3,
            title: "T", text: "T", targetTags: ["visionos", "apple-vision-pro"]
         ),
         self.makeItem(id: "dev-general", audience: "developer"),
      ]
      let config = PromotionsConfig(items: items)
      let page = self.makePage(tags: ["visionos", "apple-vision-pro"], category: "developer")
      let selection = try self.enrich(page: page, promotions: config)
      let allIds = Set((selection?.endPromos.map(\.id) ?? []) + (selection?.inlinePromos.map(\.id) ?? []))
      #expect(allIds.contains("posters"), "Consumer promo with matching targetTags should appear on developer article")
   }

   @Test("Max 1 OSS-style promo per article (variety enforcement)")
   func maxOneOssPromo() throws {
      let items = [
         PromotionItemConfig(id: "oss-a", audience: "developer", weight: 3, style: "oss", title: "T", text: "T"),
         PromotionItemConfig(id: "oss-b", audience: "developer", weight: 3, style: "oss", title: "T", text: "T"),
         self.makeItem(id: "highlight-a", audience: "developer", weight: 1),
      ]
      let config = PromotionsConfig(audienceMapping: ["developer": "developer"], items: items)
      let page = self.makePage(category: "developer")
      let selection = try self.enrich(page: page, promotions: config)
      let allPromos = (selection?.endPromos ?? []) + (selection?.inlinePromos ?? [])
      let ossCount = allPromos.filter { $0.style == "oss" }.count
      #expect(ossCount <= 1, "Should never have more than 1 OSS promo per article")
      #expect(allPromos.count == 2, "Should still fill both slots")
   }

   @Test("Consumer promos not shown on developer articles without matching tags")
   func consumerNotOnDeveloperWithoutTags() throws {
      let items = [
         PromotionItemConfig(id: "focusbeats", audience: "consumer", weight: 2, title: "T", text: "T"),
         self.makeItem(id: "dev-tool", audience: "developer"),
      ]
      let config = PromotionsConfig(audienceMapping: ["developer": "developer"], items: items)
      let page = PageModel(
         title: "T", slug: "test",
         htmlContent: "<p>" + Array(repeating: "w", count: 600).joined(separator: " ") + "</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
         category: "developer",
         tags: ["swift"],
         pageType: .article,
         locale: "en"
      )
      let siteConfig = self.makeConfig(promotions: config)
      let enriched = try PromotionEnricher(config: siteConfig).enrich(page)
      let selection: PromotionSelection? = enriched.extensionValue("promotion")
      #expect(selection?.endPromos.count == 1)
      #expect(selection?.endPromos.first?.id == "dev-tool")
   }
}
