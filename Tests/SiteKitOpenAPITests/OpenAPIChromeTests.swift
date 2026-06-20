import Foundation
import SiteKit
import Testing

@testable import SiteKitOpenAPI

/// Chrome tests for the finishing slice: the config-driven footer, the 404 + redirect
/// renderers, and the three accessibility polish items (skip-link focus reveal, mobile drawer
/// backdrop + close handlers, and the theme toggle made consistent with base SiteKit).
@Suite("OpenAPI chrome")
struct OpenAPIChromeTests {
   private func petstoreSpec() throws -> OpenAPISpec {
      let url = try #require(Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures"))
      return try OpenAPISpecLoader().load(source: url)
   }

   private func config(footer: FooterConfig? = nil, redirectsFile: String? = nil) -> SiteConfig {
      SiteConfig(
         name: "Petstore",
         baseURL: "https://example.com",
         description: "Petstore API docs.",
         footer: footer,
         sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")],
         redirectsFile: redirectsFile
      )
   }

   private func context(footer: FooterConfig? = nil) -> BuildContext {
      BuildContext(
         config: self.config(footer: footer),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIChromeSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func landingHTML(footer: FooterConfig? = nil) throws -> String {
      try #require(try OpenAPILandingPage(spec: try self.petstoreSpec()).render(context: self.context(footer: footer)).first?.content)
   }

   private func stylesheet() throws -> String {
      try #require(try OpenAPIStylesheetRenderer().render(context: self.context()).first?.content)
   }

   // MARK: - Footer

   @Test("The footer renders from config and is omitted when nothing is configured")
   func footerFromConfig() throws {
      let footer = FooterConfig(
         links: [NavigationItemConfig(title: "Privacy", url: "/privacy/")],
         copyright: "© 2026 Example"
      )
      let withFooter = try self.landingHTML(footer: footer)
      #expect(withFooter.contains("<footer class=\"sk-openapi-footer\">"))
      #expect(withFooter.contains(">Privacy</a>"))
      #expect(withFooter.contains("© 2026 Example"))

      // No footer config -> no footer element at all.
      let withoutFooter = try self.landingHTML(footer: nil)
      #expect(!withoutFooter.contains("sk-openapi-footer"))
   }

   // MARK: - 404 (rendered through the full shell)

   @Test("The 404 page renders through the full shell with a way back into the docs")
   func notFoundRendersFullShell() throws {
      let footer = FooterConfig(links: [NavigationItemConfig(title: "Privacy", url: "/privacy/")], copyright: "© 2026 Example")
      let files = try OpenAPIMissingPage(spec: try self.petstoreSpec()).render(context: self.context(footer: footer))
      let notFound = try #require(files.first { $0.outputPath.lastPathComponent == "404.html" })
      let html = notFound.content

      // Appbar (brand link back to the landing), the nav rail, and the footer – the full shell.
      #expect(html.contains("sk-openapi-brand"))
      #expect(html.contains("<nav class=\"sk-openapi-nav\""))
      #expect(html.contains("sk-openapi-footer"))
      // The not-found message and the explicit link back to the API landing.
      #expect(html.contains("Page not found"))
      #expect(html.contains("sk-openapi-notfound-home"))
      #expect(html.contains("href=\"/api/\""))
   }

   // MARK: - F2 skip link

   @Test("The skip link is hidden until focus on the OpenAPI surface")
   func skipLinkHiddenUntilFocus() throws {
      let css = try self.stylesheet()
      #expect(css.contains(".sk-openapi-shell-body .sk-skip-link {"))
      #expect(css.contains(".sk-openapi-shell-body .sk-skip-link:focus {"))
   }

   // MARK: - F3 drawer backdrop + close

   @Test("The mobile drawer has a backdrop element and close handlers")
   func drawerBackdropAndClose() throws {
      // The shell renders the scrim element.
      #expect(try self.landingHTML().contains("data-openapi-nav-scrim"))

      // The stylesheet shows the scrim behind the open drawer, gated by html.js.
      let css = try self.stylesheet()
      #expect(css.contains("html.js .sk-openapi-layout.is-nav-open .sk-openapi-scrim"))

      // The nav script wires the scrim click and the Escape key to close the drawer.
      let js = try #require(try OpenAPINavScriptRenderer().render(context: self.context()).first?.content)
      #expect(js.contains("data-openapi-nav-scrim"))
      #expect(js.contains("\"Escape\""))
   }

   @Test("The open drawer contains focus: background inert, scroll locked, rail aria-modal")
   func drawerContainsFocus() throws {
      let js = try #require(try OpenAPINavScriptRenderer().render(context: self.context()).first?.content)
      // The mechanism mirrors docc-sidebar.js: inert the background content, lock body scroll,
      // and mark the rail a modal dialog – all driven by the open flag, so they clear on close.
      #expect(js.contains("mainEl.inert = open"))
      #expect(js.contains("documentElement.style.overflow = open ?"))
      #expect(js.contains("\"aria-modal\""))
      #expect(js.contains("removeAttribute(\"aria-modal\")"))
   }

   // MARK: - F4 theme toggle (consistent with base SiteKit)

   @Test("The theme toggle, head-init, and theme script are wired consistently with base")
   func themeToggleConsistentWithBase() throws {
      let html = try self.landingHTML()
      // The appbar toggle button.
      #expect(html.contains("data-openapi-theme-toggle"))
      // The flash-free inline init reads the shared localStorage "theme" key + OS preference.
      #expect(html.contains("localStorage.getItem('theme')"))
      #expect(html.contains("prefers-color-scheme:dark"))
      // The deferred toggle script is linked.
      #expect(html.contains("<script defer src=\"/assets/js/openapi-theme.js\"></script>"))

      // The script renders and uses the same storage key + data-theme contract.
      let js = try #require(try OpenAPIThemeScriptRenderer().render(context: self.context()).first?.content)
      #expect(js.contains("\"theme\""))
      #expect(js.contains("data-theme"))
   }

   @Test("The head-init defers to the theme's own headInlineScript when one is configured")
   func headInitDefersToThemeConfig() throws {
      let themed = BuildContext(
         config: self.config(),
         themeConfig: ThemeConfig(name: "Custom", headInlineScript: "/* author init */"),
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIChromeThemed"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = try #require(try OpenAPILandingPage(spec: try self.petstoreSpec()).render(context: themed).first?.content)
      // The shell does not emit its default init (the author's headInlineScript owns init).
      #expect(!html.contains("localStorage.getItem('theme')"))
   }

   // MARK: - Provider does not silently drop pages (CR followup C)

   @Test("The content provider still registers the pages when no section is explicitly configured")
   func providerRegistersWithSynthesizedSection() throws {
      // A config with no explicit sections: effectiveSections synthesizes a default, so the
      // provider attaches the pages there rather than silently dropping every API page.
      let bareConfig = SiteConfig(name: "Petstore", baseURL: "https://example.com", sections: nil)
      let bareContext = BuildContext(
         config: bareConfig,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIChromeBare"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let section = try #require(OpenAPIContentProvider(spec: try self.petstoreSpec()).contentSection(in: bareContext))
      #expect(!section.pages.isEmpty)
   }

   // MARK: - Full build: footer + 404 + redirects all ship

   @Test("A full .openAPI build emits the footer, the 404 page, and the redirect outputs")
   func chromeFullBuild() throws {
      let projectDirectory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-openapi-chrome-\(UUID().uuidString)")
      let contentDirectory = projectDirectory.appendingPathComponent("Content")
      try FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: projectDirectory) }

      let fixture = try #require(Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures"))
      try FileManager.default.copyItem(at: fixture, to: contentDirectory.appendingPathComponent("openapi.yaml"))
      try """
      redirects:
        - from: /old-endpoint/
          to: /api/pets/showpetbyid/
      """.write(to: projectDirectory.appendingPathComponent("redirects.yaml"), atomically: true, encoding: .utf8)

      let footer = FooterConfig(
         links: [NavigationItemConfig(title: "Imprint", url: "/imprint/")],
         copyright: "© 2026 Example"
      )

      try SiteBuilder
         .openAPI(config: self.config(footer: footer, redirectsFile: "redirects.yaml"), projectDirectory: projectDirectory)
         .buildPipeline()
         .build()

      let output = projectDirectory.appendingPathComponent("_Site")
      func exists(_ relativePath: String) -> Bool {
         FileManager.default.fileExists(atPath: output.appendingPathComponent(relativePath).path)
      }
      func read(_ relativePath: String) throws -> String {
         try String(contentsOf: output.appendingPathComponent(relativePath), encoding: .utf8)
      }

      // 404 page shipped, through the full shell (appbar + nav rail + back-to-landing link).
      #expect(exists("404.html"))
      let notFound = try read("404.html")
      #expect(notFound.contains("sk-openapi-brand"))
      #expect(notFound.contains("<nav class=\"sk-openapi-nav\""))
      #expect(notFound.contains("sk-openapi-notfound-home"))
      // Redirect outputs: the Cloudflare `_redirects` map and the HTML stub.
      #expect(exists("_redirects"))
      #expect(exists("old-endpoint/index.html"))
      // Footer on a rendered API page.
      #expect(try read("api/index.html").contains("sk-openapi-footer"))
   }
}
