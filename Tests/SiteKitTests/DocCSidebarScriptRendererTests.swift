import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSidebarScriptRenderer")
struct DocCSidebarScriptRendererTests {
   @Test("Emits the sidebar toggle script to /assets/js/docc-sidebar.js")
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
      let files = try DocCSidebarScriptRenderer().render(context: context)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/js/docc-sidebar.js"))
      // The script wires the open hook and the off-canvas open attribute.
      #expect(file.content.contains("data-docc-sidebar-open"))
      #expect(file.content.contains("data-sidebar-open"))
   }

   @Test("Bundled docc-sidebar.js resource is loadable")
   func resourceLoads() throws {
      #expect(try DocCSidebarScriptRenderer.loadScript().contains("sk-docc-layout"))
   }
}
