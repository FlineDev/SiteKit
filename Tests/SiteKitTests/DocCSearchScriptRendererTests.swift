import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSearchScriptRenderer")
struct DocCSearchScriptRendererTests {
   @Test("Emits the search script to /assets/search/docc-search.js")
   func emitsScript() throws {
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com"),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let files = try DocCSearchScriptRenderer().render(context: context)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/search/docc-search.js"))
      #expect(file.content.contains("docc-search.json"))
      #expect(file.content.contains("sk-docc-search-input"))
   }

   @Test("Bundled docc-search.js resource is loadable")
   func resourceLoads() throws {
      #expect(try DocCSearchScriptRenderer.loadScript().contains("sk-docc-search-results"))
   }
}
