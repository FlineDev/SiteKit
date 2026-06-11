import Foundation
import Testing
@testable import SiteKit

@Suite("SiteBuilder enricher operations")
struct SiteBuilderEnricherOpsTests {
   /// Reflects on a SiteBuilder's private `enrichers` array and returns the type
   /// names of its elements. Mirror is the right tool here: SiteBuilder's storage
   /// is intentionally private (callers compose via fluent methods), but the
   /// spec's M5 acceptance check requires that we round-trip remove and replace
   /// by type – verifying that requires inspecting the internal list.
   private func enricherTypeNames(of builder: SiteBuilder) -> [String] {
      let mirror = Mirror(reflecting: builder)
      for child in mirror.children where child.label == "enrichers" {
         if let enrichers = child.value as? [any Enricher] {
            return enrichers.map { String(describing: type(of: $0)) }
         }
      }
      return []
   }

   private func multilingualBlogConfig() -> SiteConfig {
      SiteConfig(
         name: "Test",
         baseURL: "https://example.com",
         language: "en",
         localization: LocalizationConfig(defaultLanguage: "en", languages: ["de"])
      )
   }

   private func tempDirectory() -> URL {
      URL(fileURLWithPath: NSTemporaryDirectory())
   }

   @Test("removingEnricher removes the named type from a preset factory")
   func removingEnricherRemovesByType() {
      let config = self.multilingualBlogConfig()
      let baseline = SiteBuilder.blog(config: config, projectDirectory: self.tempDirectory())
      let baselineNames = self.enricherTypeNames(of: baseline)
      // Sanity: the multilingual blog factory registers both PromotionEnricher and HreflangEnricher.
      #expect(baselineNames.contains("PromotionEnricher"))
      #expect(baselineNames.contains("HreflangEnricher"))

      let withoutHreflang = baseline.removingEnricher(HreflangEnricher.self)
      let trimmedNames = self.enricherTypeNames(of: withoutHreflang)
      #expect(!trimmedNames.contains("HreflangEnricher"))
      // PromotionEnricher must still be present – removal is type-targeted.
      #expect(trimmedNames.contains("PromotionEnricher"))
      #expect(trimmedNames.count == baselineNames.count - 1)
   }

   @Test("removingEnricher is a no-op when the type is not present")
   func removingEnricherNoOpWhenAbsent() {
      struct UnregisteredEnricher: Enricher {
         func enrich(_ page: PageModel) throws -> PageModel { page }
      }
      let config = self.multilingualBlogConfig()
      let builder = SiteBuilder.blog(config: config, projectDirectory: self.tempDirectory())
      let before = self.enricherTypeNames(of: builder)
      let after = self.enricherTypeNames(of: builder.removingEnricher(UnregisteredEnricher.self))
      #expect(after == before)
   }

   @Test("replacingEnricher swaps the named type in place")
   func replacingEnricherSwapsByType() {
      struct TestStubEnricher: Enricher {
         func enrich(_ page: PageModel) throws -> PageModel { page }
      }
      let config = self.multilingualBlogConfig()
      let baseline = SiteBuilder.blog(config: config, projectDirectory: self.tempDirectory())
      let baselineNames = self.enricherTypeNames(of: baseline)
      guard let hreflangIndex = baselineNames.firstIndex(of: "HreflangEnricher") else {
         Issue.record("Multilingual blog factory must register HreflangEnricher")
         return
      }

      let swapped = baseline.replacingEnricher(HreflangEnricher.self, with: TestStubEnricher())
      let swappedNames = self.enricherTypeNames(of: swapped)
      #expect(swappedNames.count == baselineNames.count, "Replacement must preserve the chain length")
      #expect(swappedNames[hreflangIndex] == "TestStubEnricher", "Replacement must occur at the original index")
      #expect(!swappedNames.contains("HreflangEnricher"))
   }

   @Test("replacingEnricher appends when the type is not already registered")
   func replacingEnricherAppendsWhenAbsent() {
      struct UnregisteredEnricher: Enricher {
         func enrich(_ page: PageModel) throws -> PageModel { page }
      }
      struct TestStubEnricher: Enricher {
         func enrich(_ page: PageModel) throws -> PageModel { page }
      }
      let config = self.multilingualBlogConfig()
      let builder = SiteBuilder.blog(config: config, projectDirectory: self.tempDirectory())
      let before = self.enricherTypeNames(of: builder)
      let after = self.enricherTypeNames(of: builder.replacingEnricher(UnregisteredEnricher.self, with: TestStubEnricher()))
      #expect(after.count == before.count + 1)
      #expect(after.last == "TestStubEnricher")
   }
}
