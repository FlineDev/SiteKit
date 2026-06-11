import Foundation
import Testing

@testable import SiteKit

/// Tests for the search-feature gate in the DocC app-shell: with `search: false` the shell
/// must emit none of the search chrome (appbar pill, overlay modal, search script link,
/// framework-registry JSON) because the builder skips the renderers that back it – the
/// script and index files would 404. With `search: true` (or no flag at all, the default)
/// every piece must be present and byte-identical to the ungated output.
@Suite("DocCShellSearchGating")
struct DocCShellSearchGatingTests {

   // MARK: - Helpers

   /// A config whose docc block exercises every search-related emission: a framework
   /// registry (so the JSON block is non-empty) and suggestion chips (overlay extras).
   private func makeConfig(search: Bool?) -> SiteConfig {
      SiteConfig(
         name: "Docs",
         baseURL: "https://example.com",
         sections: [SectionConfig(
            name: "Documentation",
            slug: "documentation",
            contentDirectory: "Docs",
            urlPrefix: "documentation"
         )],
         docc: DocCConfig(
            frameworks: [
               "SwiftUI": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#0af", "#08c"])
            ],
            searchSuggestions: ["SwiftUI"],
            search: search
         )
      )
   }

   private func renderArticleHTML(config: SiteConfig) -> String {
      let docSection = config.effectiveSections[0]
      let note = PageModel(
         title: "Meet Swift Testing",
         slug: "wwdc25-10188-meet-swift-testing",
         htmlContent: "<h2>Overview</h2><p>x</p><h2>Details</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/note.md"),
         extensions: ["doccNote": true] as [String: any Sendable]
      )
      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      return DocCArticlePage().renderHTML(note, context: context)
   }

   // MARK: - search: false omits all search chrome

   @Test("search:false renders no search pill in the appbar")
   func searchOffOmitsPill() {
      let html = renderArticleHTML(config: makeConfig(search: false))
      #expect(!html.contains("sk-docc-search-pill"))
      #expect(!html.contains("data-docc-search-open"))
      #expect(!html.contains("sk-docc-kbd"))
   }

   @Test("search:false renders no search overlay modal")
   func searchOffOmitsOverlay() {
      let html = renderArticleHTML(config: makeConfig(search: false))
      #expect(!html.contains("sk-docc-search-overlay"))
      #expect(!html.contains("data-docc-search-overlay"))
      #expect(!html.contains("sk-docc-search-input"))
      #expect(!html.contains("sk-docc-search-results"))
   }

   @Test("search:false links no search script")
   func searchOffOmitsScriptLink() {
      let html = renderArticleHTML(config: makeConfig(search: false))
      #expect(!html.contains(DocCSearchScriptRenderer.scriptURL))
      // The unrelated shell scripts must survive the gate.
      #expect(html.contains(DocCSidebarScriptRenderer.scriptURL))
      #expect(html.contains(DocCFilterScriptRenderer.scriptURL))
      #expect(html.contains(DocCThemeScriptRenderer.scriptURL))
      #expect(html.contains(DocCTocScriptRenderer.scriptURL))
   }

   @Test("search:false emits no framework-registry JSON block")
   func searchOffOmitsFrameworkJSON() {
      let html = renderArticleHTML(config: makeConfig(search: false))
      #expect(!html.contains("data-docc-search-frameworks"))
   }

   @Test("search:false keeps the appbar-right cluster well-formed with only the theme toggle")
   func searchOffAppbarStillWellFormed() {
      let html = renderArticleHTML(config: makeConfig(search: false))
      #expect(html.contains("<div class=\"sk-docc-appbar-right\"><button type=\"button\" class=\"sk-docc-theme-toggle\""))
      #expect(html.contains("sk-docc-burger"))
   }

   // MARK: - search: true / absent keeps all search chrome (guards against over-gating)

   @Test("search:true renders pill, overlay, script link, and framework JSON", arguments: [true, nil] as [Bool?])
   func searchOnKeepsAllChrome(search: Bool?) {
      let html = renderArticleHTML(config: makeConfig(search: search))
      #expect(html.contains("sk-docc-search-pill"))
      #expect(html.contains("data-docc-search-open"))
      #expect(html.contains("data-docc-search-overlay"))
      #expect(html.contains("class=\"sk-docc-search-input\""))
      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
      #expect(html.contains("data-docc-search-frameworks"))
   }

   @Test("nil docc config defaults to search on, mirroring the builder's default")
   func nilDoccDefaultsToSearchOn() {
      let config = SiteConfig(
         name: "Docs",
         baseURL: "https://example.com",
         sections: [SectionConfig(
            name: "Documentation",
            slug: "documentation",
            contentDirectory: "Docs",
            urlPrefix: "documentation"
         )]
      )
      let html = renderArticleHTML(config: config)
      #expect(html.contains("sk-docc-search-pill"))
      #expect(html.contains("data-docc-search-overlay"))
      #expect(html.contains(DocCSearchScriptRenderer.scriptURL))
   }

   @Test("search:true output is byte-identical to the search:nil default output")
   func searchTrueMatchesDefaultByteForByte() {
      let explicit = renderArticleHTML(config: makeConfig(search: true))
      let implicit = renderArticleHTML(config: makeConfig(search: nil))
      #expect(explicit == implicit)
   }
}
