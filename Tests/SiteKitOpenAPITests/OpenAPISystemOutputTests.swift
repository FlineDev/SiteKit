import Foundation
import SiteKit
import Testing

@testable import SiteKitOpenAPI

/// S4b proof: the spec-derived OpenAPI pages, once registered into `BuildContext.sections`
/// via ``OpenAPIContentProvider``, are enumerated by every machine-index renderer – sitemap,
/// nav-index, search-index, and llms.txt. The headline keystone test is a red-green showing the
/// sitemap goes from missing the pages to containing them; a full pipeline build proves the
/// whole registration cascade end-to-end.
@Suite("OpenAPI system outputs")
struct OpenAPISystemOutputTests {
   /// Every operation and schema page the Petstore spec must surface in each machine index.
   static let operationPaths = ["/api/pets/listpets/", "/api/pets/createpets/", "/api/pets/showpetbyid/"]
   static let schemaPaths = ["/api/schemas/pet/", "/api/schemas/pets/", "/api/schemas/error/"]
   static var requiredPaths: [String] { operationPaths + schemaPaths }

   private func petstoreSpec() throws -> OpenAPISpec {
      let url = try #require(Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures"))
      return try OpenAPISpecLoader().load(source: url)
   }

   private func config() -> SiteConfig {
      SiteConfig(
         name: "Petstore",
         baseURL: "https://example.com",
         description: "Petstore API docs.",
         sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
      )
   }

   /// A context whose only section is the one ``OpenAPIContentProvider`` builds – exactly what
   /// the pipeline merges in. `sections` empty reproduces the pre-keystone state.
   private func context(withOpenAPISection: Bool) throws -> BuildContext {
      let base = BuildContext(
         config: self.config(),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPISystemSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      guard withOpenAPISection else { return base }
      let section = try #require(OpenAPIContentProvider(spec: try self.petstoreSpec()).contentSection(in: base))
      return BuildContext(
         config: self.config(),
         themeConfig: nil,
         sections: [section],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: base.outputDirectory,
         projectDirectory: base.projectDirectory
      )
   }

   private func render(_ renderer: any Renderer, _ context: BuildContext) throws -> String {
      try #require(try renderer.render(context: context).first?.content)
   }

   /// JSON escapes `/` as `\/` (the nav-index uses `JSONSerialization`, which always does);
   /// both decode to the same path, so normalize before substring-checking URLs.
   private func unescapingSlashes(_ string: String) -> String {
      string.replacingOccurrences(of: "\\/", with: "/")
   }

   private var resolvers: [any PagePathResolving] { [OpenAPIPagePathResolver()] }

   // MARK: - Keystone red-green

   @Test("Keystone: the sitemap gains every operation + schema page only once the pages are registered")
   func sitemapKeystoneRedGreen() throws {
      // RED: without the registered section the synthetic pages are absent from the sitemap.
      let before = try self.render(SitemapRenderer(pathResolvers: self.resolvers), try self.context(withOpenAPISection: false))
      for path in Self.requiredPaths {
         #expect(!before.contains(path), "pre-registration sitemap must not contain \(path)")
      }

      // GREEN: registering the provider's section makes every page appear.
      let after = try self.render(SitemapRenderer(pathResolvers: self.resolvers), try self.context(withOpenAPISection: true))
      for path in Self.requiredPaths {
         #expect(after.contains(path), "post-registration sitemap must contain \(path)")
      }
   }

   // MARK: - Per-renderer inclusion (direct, no fingerprint noise)

   @Test("Nav-index includes every operation + schema page")
   func navIndexInclusion() throws {
      let json = self.unescapingSlashes(
         try self.render(NavIndexRenderer(pathResolvers: self.resolvers), try self.context(withOpenAPISection: true))
      )
      for path in Self.requiredPaths {
         #expect(json.contains(path), "nav-index missing \(path)")
      }
   }

   @Test("Search-index has a record per operation + schema page, with method facets")
   func searchIndexInclusion() throws {
      let json = self.unescapingSlashes(
         try self.render(OpenAPISearchIndexRenderer(pathResolvers: self.resolvers), try self.context(withOpenAPISection: true))
      )
      for path in Self.requiredPaths {
         #expect(json.contains(path), "search-index missing \(path)")
      }
      // Operations carry a method facet (the GET/POST verbs from the Petstore spec).
      #expect(json.contains("\"method\""))
      #expect(json.contains("\"GET\""))
      #expect(json.contains("\"POST\""))
   }

   @Test("llms.txt lists every operation + schema page")
   func llmsTxtInclusion() throws {
      let txt = try self.render(OpenAPILlmsTxtRenderer(), try self.context(withOpenAPISection: true))
      for path in Self.requiredPaths {
         #expect(txt.contains(path), "llms.txt missing \(path)")
      }
      #expect(txt.contains("## Endpoints"))
      #expect(txt.contains("## Schemas"))
   }

   // MARK: - Search script + shell wiring

   @Test("The search script renders and the shell links it plus the search input")
   func searchScriptAndShellWiring() throws {
      let context = try self.context(withOpenAPISection: false)

      let scriptFiles = try OpenAPISearchScriptRenderer().render(context: context)
      let script = try #require(scriptFiles.first)
      #expect(script.outputPath.path.hasSuffix("/assets/js/openapi-search.js"))
      #expect(script.content.contains("/assets/search-index.json"))

      // The shell renders the appbar search input and defers the search script.
      let html = try #require(try OpenAPILandingPage(spec: try self.petstoreSpec()).render(context: context).first?.content)
      #expect(html.contains("data-openapi-search"))
      #expect(html.contains("<script defer src=\"/assets/js/openapi-search.js\"></script>"))
   }

   // MARK: - Per-page SEO (AC-5)

   @Test("Operation and schema pages carry per-page, non-blank title/description/canonical")
   func perPageSEO() throws {
      let context = try self.context(withOpenAPISection: false)
      let spec = try self.petstoreSpec()

      let opFiles = try OpenAPIOperationPage(spec: spec).render(context: context)
      let opHTML = try #require(opFiles.first { $0.outputPath.path.contains("showpetbyid") }?.content)
      #expect(opHTML.contains("<title>Info for a specific pet – Petstore</title>"))
      #expect(opHTML.contains("<meta name=\"description\" content=\"Info for a specific pet"))
      #expect(opHTML.contains("<link rel=\"canonical\" href=\"https://example.com/api/pets/showpetbyid/\"/>"))

      let schemaFiles = try OpenAPISchemaPage(spec: spec).render(context: context)
      let petHTML = try #require(schemaFiles.first { $0.outputPath.path.contains("/schemas/pet/") }?.content)
      #expect(petHTML.contains("<title>Pet – Petstore</title>"))
      // Pet has no description in the spec, so the meaningful fallback fills the meta tag.
      #expect(petHTML.contains("<meta name=\"description\" content=\"The Pet schema.\"/>"))
      #expect(petHTML.contains("<link rel=\"canonical\" href=\"https://example.com/api/schemas/pet/\"/>"))

      // Page-specific, not a shared/generic title.
      #expect(!opHTML.contains("<title>Pet – Petstore</title>"))
   }

   // MARK: - End-to-end cascade (one full pipeline build)

   @Test("A full .openAPI build registers the pages so all four machine indexes include them")
   func fullBuildCascade() throws {
      let projectDirectory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-openapi-system-\(UUID().uuidString)")
      let contentDirectory = projectDirectory.appendingPathComponent("Content")
      try FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: projectDirectory) }

      // The Petstore fixture as the site's spec.
      let fixture = try #require(Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures"))
      try FileManager.default.copyItem(at: fixture, to: contentDirectory.appendingPathComponent("openapi.yaml"))

      try SiteBuilder
         .openAPI(config: self.config(), projectDirectory: projectDirectory)
         .buildPipeline()
         .build()

      let output = projectDirectory.appendingPathComponent("_Site")
      func read(_ relativePath: String) throws -> String {
         try String(contentsOf: output.appendingPathComponent(relativePath), encoding: .utf8)
      }

      let sitemap = try read("sitemap.xml")
      let navIndex = self.unescapingSlashes(try read("assets/nav-index.json"))
      let searchIndex = self.unescapingSlashes(try read("assets/search-index.json"))
      let llms = try read("llms.txt")

      for path in Self.requiredPaths {
         #expect(sitemap.contains(path), "sitemap.xml missing \(path)")
         #expect(navIndex.contains(path), "nav-index.json missing \(path)")
         #expect(searchIndex.contains(path), "search-index.json missing \(path)")
         #expect(llms.contains(path), "llms.txt missing \(path)")
      }
   }
}
