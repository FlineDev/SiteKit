import Foundation
import Testing

@testable import SiteKit

/// Tests for the core `ContentSectionProviding` seam, in particular the multilingual contract:
/// a provider's pages are merged into the build's *global* pass (where the locale-independent,
/// site-wide outputs are produced) and never into the per-locale passes – an unlocalized
/// synthetic page must not be minted at a locale-prefixed URL it has no content for. The single
/// merge means the pages are seen once, not duplicated once per locale.
@Suite("ContentSectionProvider")
struct ContentSectionProviderTests {
   /// Records the page slugs each scope's renderers observed in `context.sections`.
   private final class Recorder: @unchecked Sendable {
      var globalSlugs: [String] = []
      var perLocaleSlugs: [String] = []
   }

   /// A minimal provider contributing one synthetic page in its own section.
   private struct MarkerProvider: ContentSectionProviding {
      func contentSection(in context: BuildContext) -> ContentSection? {
         let page = PageModel(
            title: "Synthetic Marker",
            slug: "providermarker",
            htmlContent: "<p>Generated, not loaded from a file.</p>",
            sourcePath: URL(fileURLWithPath: "/tmp/synthetic/providermarker"),
            pageType: .staticPage
         )
         let section = SectionConfig(name: "Synthetic", slug: "synthetic", contentDirectory: "Synthetic", urlPrefix: "synthetic")
         return ContentSection(config: section, pages: [page])
      }
   }

   /// A spy renderer that records, per scope, the page slugs it sees in the context.
   private struct SpyRenderer: Renderer {
      let recorder: Recorder
      let isGlobal: Bool
      var scope: RenderScope { self.isGlobal ? .global : .perLocale }
      func render(context: BuildContext) throws -> [OutputFile] {
         let slugs = context.sections.flatMap(\.pages).map(\.slug)
         if self.isGlobal {
            self.recorder.globalSlugs.append(contentsOf: slugs)
         } else {
            self.recorder.perLocaleSlugs.append(contentsOf: slugs)
         }
         return []
      }
   }

   /// Writes a tiny multilingual site (one article in en + de) so a full build exercises both
   /// the per-locale passes and the single global pass.
   private func makeMultilingualSite() throws -> (config: SiteConfig, projectDirectory: URL) {
      let projectDirectory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-provider-ml-\(UUID().uuidString)")
      let blogDirectory = projectDirectory.appendingPathComponent("Content/Blog")
      try FileManager.default.createDirectory(at: blogDirectory, withIntermediateDirectories: true)

      try """
      ---
      title: Hello
      date: 2024-01-15
      ---
      A first article.
      """.write(to: blogDirectory.appendingPathComponent("2024-01-15-hello.md"), atomically: true, encoding: .utf8)
      try """
      ---
      title: Hallo
      date: 2024-01-15
      ---
      Ein erster Artikel.
      """.write(to: blogDirectory.appendingPathComponent("2024-01-15-hello.de.md"), atomically: true, encoding: .utf8)

      let config = SiteConfig(
         name: "Provider Fixture",
         baseURL: "https://example.com",
         description: "Provider seam fixture",
         sections: [SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog")],
         localization: LocalizationConfig(defaultLanguage: "en", languages: ["de"])
      )
      return (config, projectDirectory)
   }

   @Test("A provider's pages reach the global pass once, and never the per-locale passes")
   func providedPagesReachGlobalPassOnce() throws {
      let (config, projectDirectory) = try self.makeMultilingualSite()
      defer { try? FileManager.default.removeItem(at: projectDirectory) }

      let recorder = Recorder()
      try SiteBuilder
         .blog(config: config, projectDirectory: projectDirectory)
         .contentSectionProvider(MarkerProvider())
         .renderer(SpyRenderer(recorder: recorder, isGlobal: true))
         .renderer(SpyRenderer(recorder: recorder, isGlobal: false))
         .buildPipeline()
         .build()

      // The global pass sees the synthetic page exactly once (en + de share one global pass).
      let globalHits = recorder.globalSlugs.filter { $0 == "providermarker" }.count
      #expect(globalHits == 1, "expected the provided page once in the global pass, saw \(globalHits)")

      // The per-locale passes never see it (no locale-prefixed, content-less URL is minted).
      #expect(!recorder.perLocaleSlugs.contains("providermarker"))
   }
}
