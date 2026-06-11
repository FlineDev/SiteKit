import Foundation

/// Result of promotion selection – separate slot lists for end-of-article and
/// inline placements. Stored on a page as
/// `page.extensions["promotion"]: PromotionSelection` and read by renderers
/// to emit the actual cards.
public struct PromotionSelection: Sendable {
   public let endPromos: [PromotionItemConfig]
   public let inlinePromos: [PromotionItemConfig]
}

/// Enricher that picks promotional cards for an article and stores the result
/// in `page.extensions["promotion"]: PromotionSelection`.
///
/// Skips and returns the page unchanged when:
/// - `pageType != .article` (only article-style pages render promotions)
/// - `page.draft == true` (drafts never show promotions)
/// - `config.promotions` is `nil` or has no items
///
/// Eligibility rules:
/// 1. If a promo has `targetTags` that match the article → eligible (overrides audience)
/// 2. If a promo has no `targetTags` → eligible only if audience matches
/// 3. `excludeTags` always block regardless
/// 4. Max 1 OSS-style promo per article (variety enforcement)
///
/// Slot count by article length (max 2 total):
/// - ≤4 min: 1 end promo
/// - 5+ min: 1 end + 1 inline
/// - Snippets / `style: "short"` sections: always 1 end, no inline
public struct PromotionEnricher: Enricher {
   private let config: SiteConfig

   public init(config: SiteConfig) {
      self.config = config
   }

   public func enrich(_ page: PageModel) throws -> PageModel {
      guard page.pageType == .article, !page.draft else { return page }
      guard let promoConfig = self.config.promotions, !promoConfig.items.isEmpty else { return page }

      // Resolve section style from sectionSlug extension (set by BuildPipeline).
      let sectionSlug: String? = page.extensionValue("sectionSlug")
      let sectionStyle = sectionSlug
         .flatMap { slug in self.config.effectiveSections.first(where: { $0.slug == slug }) }?
         .style

      let selection = self.select(
         config: promoConfig,
         articleSlug: page.slug,
         articleTags: page.tags,
         articleCategory: page.category,
         readTimeMinutes: page.readTimeMinutes,
         sectionStyle: sectionStyle,
         audienceMapping: promoConfig.audienceMapping
      )

      var extensions = page.extensions
      extensions["promotion"] = selection

      return PageModel(
         id: page.id,
         title: page.title,
         date: page.date,
         slug: page.slug,
         htmlContent: page.htmlContent,
         sourcePath: page.sourcePath,
         category: page.category,
         tags: page.tags,
         summary: page.summary,
         description: page.description,
         author: page.author,
         image: page.image,
         imageAlt: page.imageAlt,
         draft: page.draft,
         pageType: page.pageType,
         locale: page.locale,
         originalLanguage: page.originalLanguage,
         legalDocument: page.legalDocument,
         extensions: extensions
      )
   }

   // MARK: - Selection

   private func select(
      config: PromotionsConfig,
      articleSlug: String,
      articleTags: [String],
      articleCategory: String,
      readTimeMinutes: Int,
      sectionStyle: String? = nil,
      audienceMapping: [String: String]? = nil
   ) -> PromotionSelection {
      // Determine slot counts
      let endSlotCount: Int
      let inlineSlotCount: Int

      if sectionStyle == "short" {
         endSlotCount = 1
         inlineSlotCount = 0
      } else if let overrideEnd = config.endSlots {
         endSlotCount = overrideEnd
         inlineSlotCount = config.inlineSlots ?? 0
      } else {
         endSlotCount = 1
         inlineSlotCount = readTimeMinutes <= 4 ? 0 : 1
      }

      let totalSlots = endSlotCount + inlineSlotCount
      guard totalSlots > 0 else { return PromotionSelection(endPromos: [], inlinePromos: []) }

      let audience = Self.audienceForCategory(articleCategory, mapping: audienceMapping)

      // Combine tags and category for matching
      var articleIdentifiers = Set(articleTags.map { $0.lowercased() })
      if !articleCategory.isEmpty {
         articleIdentifiers.insert(articleCategory.lowercased())
      }

      // Filter items by eligibility
      let eligible = config.items.filter { item in
         // excludeTags always block
         if let excludeTags = item.excludeTags, !excludeTags.isEmpty {
            let excluded = Set(excludeTags.map { $0.lowercased() })
            if !excluded.isDisjoint(with: articleIdentifiers) {
               return false
            }
         }

         // A promo is eligible if EITHER path matches:
         // Option 1: targetTags match (overrides audience – e.g., visionOS promo on developer article)
         // Option 2: audience matches (for promos without specific tag targeting)
         let hasTargetTags = !(item.targetTags ?? []).isEmpty
         let targetTagsMatch: Bool
         if hasTargetTags {
            let targets = Set(item.targetTags!.map { $0.lowercased() })
            targetTagsMatch = !targets.isDisjoint(with: articleIdentifiers)
         } else {
            targetTagsMatch = false
         }

         let audienceMatches: Bool
         if let itemAudience = item.audience, !itemAudience.isEmpty {
            audienceMatches = itemAudience == "general" || itemAudience == audience
         } else {
            audienceMatches = true  // No audience = always matches
         }

         // Eligible if either path works
         return targetTagsMatch || audienceMatches
      }

      guard !eligible.isEmpty else {
         return PromotionSelection(endPromos: [], inlinePromos: [])
      }

      // Deterministic selection with variety enforcement
      let selected = Self.weightedSelectWithVariety(
         items: eligible,
         count: totalSlots,
         articleSlug: articleSlug,
         articleIdentifiers: articleIdentifiers
      )

      let endPromos = Array(selected.prefix(endSlotCount))
      let inlinePromos = Array(selected.dropFirst(endSlotCount).prefix(inlineSlotCount))

      return PromotionSelection(endPromos: endPromos, inlinePromos: inlinePromos)
   }

   /// Determine the target audience from article category.
   private static func audienceForCategory(_ category: String, mapping: [String: String]?) -> String {
      if let mapping, let audience = mapping[category.lowercased()] {
         return audience
      }
      return "general"
   }

   /// Simple stable hash for deterministic ordering across builds.
   private static func stableHash(_ string: String) -> UInt64 {
      var hash: UInt64 = 5381
      for byte in string.utf8 {
         hash = hash &* 33 &+ UInt64(byte)
      }
      return hash
   }

   /// Deterministically select items with variety enforcement:
   /// 1. Boosted items (boostTags match) are prioritized first
   /// 2. Max 1 item per non-highlight style (e.g., max 1 "oss" promo)
   /// 3. Remaining slots filled by weighted random selection
   private static func weightedSelectWithVariety(
      items: [PromotionItemConfig],
      count: Int,
      articleSlug: String,
      articleIdentifiers: Set<String>
   ) -> [PromotionItemConfig] {
      // Separate boosted items from regular items
      var boosted: [PromotionItemConfig] = []
      var regular: [(item: PromotionItemConfig, score: UInt64)] = []

      for item in items {
         var isBoosted = false
         if let boostTags = item.boostTags, !boostTags.isEmpty {
            let boosts = Set(boostTags.map { $0.lowercased() })
            if !boosts.isDisjoint(with: articleIdentifiers) {
               isBoosted = true
            }
         }

         if isBoosted {
            boosted.append(item)
         } else {
            // Hash slug+itemId for truly independent per-item randomization
            let score = Self.stableHash("\(articleSlug):\(item.id)") &* UInt64(item.weight)
            regular.append((item, score))
         }
      }

      // Sort regular items by score descending
      regular.sort { $0.score > $1.score }

      // Build final selection: boosted items first, then fill remaining with regular
      var selected: [PromotionItemConfig] = []
      var usedStyles: Set<String> = []
      var usedIds: Set<String> = []

      // Add boosted items first (they always win)
      for item in boosted {
         guard selected.count < count else { break }
         if item.style != "highlight" {
            if usedStyles.contains(item.style) { continue }
            usedStyles.insert(item.style)
         }
         selected.append(item)
         usedIds.insert(item.id)
      }

      // Fill remaining slots with regular items
      for (item, _) in regular {
         guard selected.count < count else { break }
         if usedIds.contains(item.id) { continue }
         if item.style != "highlight" {
            if usedStyles.contains(item.style) { continue }
            usedStyles.insert(item.style)
         }
         selected.append(item)
         usedIds.insert(item.id)
      }

      return selected
   }
}
