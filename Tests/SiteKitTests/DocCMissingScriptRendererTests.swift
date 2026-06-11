import Foundation
import Testing

@testable import SiteKit

@Suite("DocCMissingScriptRenderer")
struct DocCMissingScriptRendererTests {
   @Test("Emits the show-more script to /assets/js/docc-missing.js")
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
      let files = try DocCMissingScriptRenderer().render(context: context)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/js/docc-missing.js"))
      // The script keys off the toggle hook and the collapse class.
      #expect(file.content.contains("data-docc-missing-more"))
      #expect(file.content.contains("is-collapsed"))
   }

   @Test("Bundled docc-missing.js resource is loadable")
   func resourceLoads() throws {
      #expect(try DocCMissingScriptRenderer.loadScript().contains("sk-docc-missing-card--extra"))
   }

   @Test("Script reads its labels from data-* attributes and bakes in no English copy")
   func scriptIsLocaleAgnostic() throws {
      let js = try DocCMissingScriptRenderer.loadScript()
      #expect(js.contains("data-docc-missing-label-more"))
      #expect(js.contains("data-docc-missing-label-less"))
      // No hardcoded UI copy: the visible text comes only from the data-* labels.
      #expect(!js.contains("Show more"))
      #expect(!js.contains("Show less"))
   }

   @Test("Script no-ops on pages without a toggle button (guards early)")
   func guardsAgainstMissingButton() throws {
      let js = try DocCMissingScriptRenderer.loadScript()
      #expect(js.contains("if (!buttons.length) return"))
   }
}
