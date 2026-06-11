import Foundation
import Testing

@testable import SiteKit

@Suite("DocCThemeScriptRenderer")
struct DocCThemeScriptRendererTests {
   private let context = BuildContext(
      config: SiteConfig(name: "Docs", baseURL: "https://example.com"),
      themeConfig: nil,
      sections: [],
      staticPages: [],
      tags: [:],
      homeContent: nil,
      outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
      projectDirectory: URL(fileURLWithPath: "/tmp")
   )

   @Test("Emits the theme-switch script to /assets/js/docc-theme.js")
   func emitsScript() throws {
      let files = try DocCThemeScriptRenderer().render(context: self.context)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("/assets/js/docc-theme.js"))
      #expect(!file.content.isEmpty)
   }

   @Test("Bundled docc-theme.js resource is loadable")
   func resourceLoads() throws {
      #expect(try !DocCThemeScriptRenderer.loadScript().isEmpty)
   }

   @Test("Script uses the 'theme' localStorage key")
   func usesCorrectStorageKey() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      // The key must match the site's headInlineScript (localStorage.getItem('theme')).
      #expect(js.contains("\"theme\""))
   }

   @Test("Script stores 'light' and 'dark' values matching the headInlineScript contract")
   func storesCorrectValues() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      // Light sets localStorage to 'light'; dark sets it to 'dark'.
      #expect(js.contains("\"light\""))
      #expect(js.contains("\"dark\""))
   }

   @Test("Toggle is a plain light/dark flip that stores the opposite value, never 'auto'")
   func toggleFlipsAppliedTheme() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      // The toggle reads the currently-applied data-theme to compute the opposite.
      #expect(js.contains("getAttribute(\"data-theme\")"))
      // It persists the chosen value rather than storing an 'auto' literal.
      #expect(js.contains("setItem"))
      #expect(!js.contains("\"auto\""))
   }

   @Test("Script sets data-theme on documentElement")
   func setsDataThemeOnHtml() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      #expect(js.contains("data-theme"))
      #expect(js.contains("documentElement"))
   }

   @Test("Auto mode registers a matchMedia listener for live OS-preference following")
   func autoModeRegistersMediaQueryListener() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      // Auto keeps following the OS preference while active.
      #expect(js.contains("addEventListener(\"change\""))
      #expect(js.contains("prefers-color-scheme"))
   }

   @Test("Script is scoped to the .sk-docc-layout element")
   func scopedToDocCLayout() throws {
      let js = try DocCThemeScriptRenderer.loadScript()
      #expect(js.contains(".sk-docc-layout"))
      // Early return when the DocC shell is not present (non-DocC pages load no switch).
      #expect(js.contains("if (!layout) return"))
   }

   @Test("Appbar renders a single theme toggle button (no 3-way segmented control)")
   func appbarRendersSingleToggle() {
      // The theme toggle lives in the appbar (beside the search pill), so it appears
      // in any fully-wrapped DocC page rather than in the bare sidebar.
      let html = Self.renderDocCArticle(uiStrings: nil)
      #expect(html.contains("sk-docc-theme-toggle"))
      #expect(html.contains("data-docc-theme-toggle"))
      // The old 3-way segmented control markup is gone.
      #expect(!html.contains("sk-docc-themeswitch"))
      #expect(!html.contains("role=\"radiogroup\""))
      #expect(!html.contains("data-docc-theme=\"light\""))
      // Default English aria-label.
      #expect(html.contains("Toggle appearance"))
   }

   @Test("Appbar theme-toggle aria-label is localized via UIStrings")
   func appbarToggleLabelLocalized() {
      // The aria-label comes from the locale's UIStrings; compare against the strings the
      // same bundle resolves, so the test stays correct if the German value is retuned.
      let de = UIStrings(locale: "de")
      let html = Self.renderDocCArticle(uiStrings: de)
      #expect(html.contains(de.string(for: .doccThemeToggle)))
   }

   /// Renders a sample DocC article through the full shell (which includes the appbar
   /// theme switch), optionally with an explicit `UIStrings` locale bundle.
   private static func renderDocCArticle(uiStrings: UIStrings?) -> String {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let note = PageModel(
         title: "Meet X",
         slug: "wwdc25-101-meet-x",
         htmlContent: "<p>Hello</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/meet-x.md"),
         extensions: ["doccNote": true]
      )
      let ctx = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         uiStrings: uiStrings,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      return DocCArticlePage().renderHTML(note, context: ctx)
   }

   @Test("Article head links docc-theme.js")
   func articleHeadLinksThemeScript() {
      let docSection = SectionConfig(
         name: "Documentation", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation"
      )
      let note = PageModel(
         title: "Meet X",
         slug: "wwdc25-101-meet-x",
         htmlContent: "<p>Hello</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/meet-x.md"),
         extensions: ["doccNote": true]
      )
      let ctx = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [docSection]),
         themeConfig: nil,
         sections: [ContentSection(config: docSection, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCArticlePage().renderHTML(note, context: ctx)
      #expect(html.contains("/assets/js/docc-theme.js"))
   }
}
