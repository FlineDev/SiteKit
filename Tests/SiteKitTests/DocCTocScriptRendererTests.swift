import Foundation
import Testing

@testable import SiteKit

@Suite("DocCTocScriptRenderer")
struct DocCTocScriptRendererTests {
   @Test("Emits the TOC scroll-spy script to /assets/js/docc-toc.js")
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
      let files = try DocCTocScriptRenderer().render(context: context)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/js/docc-toc.js"))
      // The script targets the scroll container and the TOC rail.
      #expect(file.content.contains("sk-docc-scroll"))
      #expect(file.content.contains("sk-docc-toc"))
      #expect(file.content.contains("is-active"))
   }

   @Test("Bundled docc-toc.js resource is loadable")
   func resourceLoads() throws {
      #expect(try DocCTocScriptRenderer.loadScript().contains("sk-docc-toc-item"))
   }

   @Test("Script guards against pages with no TOC rail (no-op when absent)")
   func guardsAgainstMissingTOC() throws {
      let js = try DocCTocScriptRenderer.loadScript()
      // The script exits early when `.sk-docc-toc` is absent, protecting pages
      // where the note has fewer than two headings and no rail is rendered.
      #expect(js.contains("if (!toc) return"))
   }

   @Test("Script targets the independently-scrolling .sk-docc-scroll container, not window")
   func targetsScrollContainer() throws {
      let js = try DocCTocScriptRenderer.loadScript()
      // Scroll-spy must listen on the inner container, not the document, because
      // the DocC shell fixes the app viewport and only .sk-docc-scroll scrolls.
      #expect(js.contains("scroller.addEventListener"))
      #expect(!js.contains("window.addEventListener(\"scroll\""))
      #expect(!js.contains("document.addEventListener(\"scroll\""))
   }

   @Test("Article head links docc-toc.js when the note has multiple headings")
   func articleHeadLinksScript() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let note = PageModel(
         title: "Meet X",
         slug: "wwdc25-101-meet-x",
         htmlContent: "<h2>Overview</h2><p>x</p><h2>Details</h2><p>y</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/meet-x.md"),
         extensions: ["doccNote": true]
      )
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCArticlePage().renderHTML(note, context: context)
      #expect(html.contains("/assets/js/docc-toc.js"))
   }
}
