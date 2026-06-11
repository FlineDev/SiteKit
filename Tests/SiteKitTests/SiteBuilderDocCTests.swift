import Foundation
import Testing

@testable import SiteKit

@Suite("SiteBuilder.docc")
struct SiteBuilderDocCTests {
   /// Composes the DocC factory and assembles its pipeline. If the DocC stack
   /// (discovery → loader → cross-reference enricher → article page + system
   /// renderers) failed to wire up, this would throw or trap. The end-to-end
   /// render proof over a real corpus is the consuming site's staging build.
   @Test("docc(config:projectDirectory:) composes a build pipeline")
   func composesPipeline() {
      let config = SiteConfig(name: "Docs", baseURL: "https://example.com")
      let builder = SiteBuilder.docc(
         config: config,
         projectDirectory: URL(fileURLWithPath: "/tmp/sitekit-docc-test")
      )
      _ = builder.buildPipeline()
   }

   @Test("docc cross-reference prefix defaults to the first section's URL prefix")
   func crossReferencePrefixDefault() throws {
      // With no explicit sections, the enricher falls back to "documentation";
      // a doc: link therefore resolves under /documentation/.
      let enricher = DocCCrossReferenceEnricher(urlPrefix: "documentation")
      let page = PageModel(
         title: "T",
         slug: "t",
         htmlContent: "<a href=\"doc:WWDC24-1-X\">doc:WWDC24-1-X</a>",
         sourcePath: URL(fileURLWithPath: "/tmp/t.md")
      )
      let out = try enricher.enrich(page)
      #expect(out.htmlContent.contains("href=\"/documentation/wwdc24-1-x/\""))
   }

   // MARK: - Feature flag gating of renderer registration

   private func doccBuilder(docc: DocCConfig?) -> SiteBuilder {
      let config = SiteConfig(name: "Docs", baseURL: "https://example.com", docc: docc)
      return SiteBuilder.docc(config: config, projectDirectory: URL(fileURLWithPath: "/tmp/sitekit-docc-flags-test"))
   }

   @Test("Default flags: no contributor/missing pages register, but search does (search on by default)")
   func defaultFlagsRegistration() {
      // nil docc ⇒ clean generic-docs default: contributors + missing off, search on.
      let types = self.doccBuilder(docc: nil).registeredRendererTypeNames
      #expect(!types.contains("DocCContributorsPage"))
      #expect(!types.contains("DocCContributorPage"))
      #expect(!types.contains("DocCMissingPage"))
      // Search ships by default.
      #expect(types.contains("DocCSearchPage"))
      #expect(types.contains("DocCSearchIndexRenderer"))
      #expect(types.contains("DocCSearchScriptRenderer"))
      #expect(types.contains("DocCSearchPageScriptRenderer"))
   }

   @Test("contributors: true registers the contributors overview + profile pages")
   func contributorsFlagRegistersPages() {
      let off = self.doccBuilder(docc: DocCConfig(contributors: false)).registeredRendererTypeNames
      #expect(!off.contains("DocCContributorsPage"))
      #expect(!off.contains("DocCContributorPage"))
      let on = self.doccBuilder(docc: DocCConfig(contributors: true)).registeredRendererTypeNames
      #expect(on.contains("DocCContributorsPage"))
      #expect(on.contains("DocCContributorPage"))
   }

   @Test("missingSessions: true registers the missing-sessions page")
   func missingSessionsFlagRegistersPage() {
      let off = self.doccBuilder(docc: DocCConfig(missingSessions: false)).registeredRendererTypeNames
      #expect(!off.contains("DocCMissingPage"))
      let on = self.doccBuilder(docc: DocCConfig(missingSessions: true)).registeredRendererTypeNames
      #expect(on.contains("DocCMissingPage"))
   }

   @Test("search: false drops the search page, index, and client scripts")
   func searchFlagOffDropsSearchRenderers() {
      let types = self.doccBuilder(docc: DocCConfig(search: false)).registeredRendererTypeNames
      #expect(!types.contains("DocCSearchPage"))
      #expect(!types.contains("DocCSearchIndexRenderer"))
      #expect(!types.contains("DocCSearchScriptRenderer"))
      #expect(!types.contains("DocCSearchPageScriptRenderer"))
      // Unconditional DocC chrome still ships (sanity check the gate did not over-reach).
      #expect(types.contains("DocCArticlePage"))
      #expect(types.contains("DocCFilterScriptRenderer"))
   }

   @Test("All flags on registers every specialized DocC page (WWDCNotes configuration)")
   func allFlagsOnRegistersEverything() {
      let types = self.doccBuilder(
         docc: DocCConfig(contributors: true, missingSessions: true, search: true)
      ).registeredRendererTypeNames
      #expect(types.contains("DocCContributorsPage"))
      #expect(types.contains("DocCContributorPage"))
      #expect(types.contains("DocCMissingPage"))
      #expect(types.contains("DocCSearchPage"))
   }

   // MARK: - Path resolver wiring

   /// With contributors enabled, sitemap + nav index + search index must receive
   /// `DocCContributorPage` as path authority – it re-homes the consumed profile notes
   /// under `/contributors/<handle>/` and only it knows that final path. With the feature
   /// off, no resolver is wired (no contributor pages exist, so there is no override to
   /// consult).
   @Test("contributors: true hands the contributor path resolver to sitemap, nav index, and search index")
   func contributorsFlagWiresPathResolvers() throws {
      let on = self.doccBuilder(docc: DocCConfig(contributors: true)).registeredRenderers
      let onSitemap = try #require(on.compactMap { $0 as? SitemapRenderer }.first)
      #expect(onSitemap.pathResolvers.contains { $0 is DocCContributorPage })
      let onNavIndex = try #require(on.compactMap { $0 as? NavIndexRenderer }.first)
      #expect(onNavIndex.pathResolvers.contains { $0 is DocCContributorPage })
      let onSearchIndex = try #require(on.compactMap { $0 as? DocCSearchIndexRenderer }.first)
      #expect(onSearchIndex.pathResolvers.contains { $0 is DocCContributorPage })

      let off = self.doccBuilder(docc: DocCConfig(contributors: false)).registeredRenderers
      let offSitemap = try #require(off.compactMap { $0 as? SitemapRenderer }.first)
      #expect(offSitemap.pathResolvers.isEmpty)
      let offNavIndex = try #require(off.compactMap { $0 as? NavIndexRenderer }.first)
      #expect(offNavIndex.pathResolvers.isEmpty)
      let offSearchIndex = try #require(off.compactMap { $0 as? DocCSearchIndexRenderer }.first)
      #expect(offSearchIndex.pathResolvers.isEmpty)
   }

   // MARK: - Redirect renderers

   /// A `redirectsFile:` in a DocC SiteConfig must reach both redirect renderers. Without
   /// this registration the setting is silently ignored: no `_redirects` for Cloudflare
   /// Pages and no HTML fallback stubs, regardless of what the YAML declares.
   @Test("docc registers both redirect renderers so redirectsFile is honored")
   func registersRedirectRenderers() {
      let types = self.doccBuilder(docc: nil).registeredRendererTypeNames
      #expect(types.contains("HTMLRedirectPageRenderer"))
      #expect(types.contains("CloudflareRedirectsRenderer"))
   }
}
