import Foundation
import SiteKit
import Testing

@testable import SiteKitOpenAPI

/// HTML-structure and sample-site tests for the OpenAPI page renderers. The fixtures
/// are the S1 Petstore specs; the assertions check the semantic output (classes,
/// `data-` attributes, paths, names) that the stylesheet slice will target, plus the
/// expected `OutputFile` set for a full sample build.
@Suite("OpenAPI renderers")
struct OpenAPIRenderersTests {
   private func petstoreSpec() throws -> OpenAPISpec {
      let url = try #require(
         Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures")
      )
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Petstore",
            baseURL: "https://example.com",
            description: "Sample API docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPISite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   // MARK: - Sample site: the OutputFile set

   @Test("The four renderers produce one landing + one per tag + one per operation + one per schema")
   func sampleSiteOutputFiles() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()

      var paths: [String] = []
      for renderer: any Renderer in [
         OpenAPILandingPage(spec: spec),
         OpenAPITagPage(spec: spec),
         OpenAPIOperationPage(spec: spec),
         OpenAPISchemaPage(spec: spec),
      ] {
         paths += try renderer.render(context: context).map(\.outputPath.path)
      }

      let expected = [
         "/tmp/_OpenAPISite/api/index.html",
         "/tmp/_OpenAPISite/api/pets/index.html",
         "/tmp/_OpenAPISite/api/pets/listpets/index.html",
         "/tmp/_OpenAPISite/api/pets/createpets/index.html",
         "/tmp/_OpenAPISite/api/pets/showpetbyid/index.html",
         "/tmp/_OpenAPISite/api/schemas/pet/index.html",
         "/tmp/_OpenAPISite/api/schemas/pets/index.html",
         "/tmp/_OpenAPISite/api/schemas/error/index.html",
      ]
      #expect(Set(paths) == Set(expected))
      #expect(paths.count == expected.count)
   }

   // MARK: - Landing

   @Test("Landing page has a tag card linking to each tag page")
   func landingHasTagCards() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()
      let html = try #require(try OpenAPILandingPage(spec: spec).render(context: context).first?.content)

      #expect(html.contains("Swagger Petstore"))
      #expect(html.contains("class=\"sk-openapi-tag-card\""))
      #expect(html.contains("href=\"/api/pets/\""))
      #expect(html.contains(">pets<"))
   }

   // MARK: - Tag page

   @Test("Tag page lists its operations with method badges linking to operation pages")
   func tagPageListsOperations() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()
      let html = try #require(try OpenAPITagPage(spec: spec).render(context: context).first?.content)

      #expect(html.contains("data-method=\"get\""))
      #expect(html.contains("data-method=\"post\""))
      #expect(html.contains("href=\"/api/pets/showpetbyid/\""))
      #expect(html.contains("/pets/{petId}"))
   }

   // MARK: - Operation page

   @Test("Operation page renders method, path, parameters, responses, schema link, and the try-it seam")
   func operationPageStructure() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()
      let files = try OpenAPIOperationPage(spec: spec).render(context: context)
      let html = try #require(files.first { $0.outputPath.path.contains("showpetbyid") }?.content)

      #expect(html.contains("data-method=\"get\""))
      #expect(html.contains("/pets/{petId}"))
      // Parameter table: the petId path parameter.
      #expect(html.contains("petId"))
      #expect(html.contains("data-in=\"path\""))
      // Responses keyed by status.
      #expect(html.contains("data-status=\"200\""))
      #expect(html.contains("data-status=\"default\""))
      // The 200 response body is the Pet schema, linked (not expanded inline).
      #expect(html.contains("href=\"/api/schemas/pet/\""))
      // Static-first: the try-it widget seam is present, no request-sending code.
      #expect(html.contains("<!-- v1.2.0: try-it widget mounts here -->"))
   }

   @Test("Operation page renders the request body for POST")
   func operationPageRequestBody() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()
      let files = try OpenAPIOperationPage(spec: spec).render(context: context)
      let html = try #require(files.first { $0.outputPath.path.contains("createpets") }?.content)

      #expect(html.contains("data-method=\"post\""))
      #expect(html.contains("sk-openapi-request-body"))
      #expect(html.contains("application/json"))
      #expect(html.contains("href=\"/api/schemas/pet/\""))
   }

   // MARK: - Schema page

   @Test("Schema page lists properties with required markers and types")
   func schemaPageProperties() throws {
      let spec = try self.petstoreSpec()
      let context = self.makeContext()
      let files = try OpenAPISchemaPage(spec: spec).render(context: context)
      let html = try #require(files.first { $0.outputPath.path.contains("schemas/pet") }?.content)

      #expect(html.contains("data-schema=\"Pet\""))
      // Property names.
      #expect(html.contains(">id<"))
      #expect(html.contains(">name<"))
      #expect(html.contains(">tag<"))
      // Required marker on the required properties.
      #expect(html.contains("data-required=\"true\""))
      // The format of the id property carries through.
      #expect(html.contains("int64"))
   }
}

/// Operation-page tests for in-file component `$ref` resolution: a `$ref`'d
/// parameter, response, and request body must render identically to inline ones,
/// and an unresolvable `$ref` must surface a visible placeholder rather than
/// vanishing. These pin the regression closed (today the loader drops every
/// referenced node, so all four assertions below fail before resolution lands).
@Suite("OpenAPI component $ref resolution")
struct OpenAPIComponentRefTests {
   private func refsSpec() throws -> OpenAPISpec {
      let url = try #require(
         Bundle.module.url(forResource: "components-refs-3.1", withExtension: "yaml", subdirectory: "Fixtures")
      )
      return try OpenAPISpecLoader().load(source: url)
   }

   private func danglingSpec() throws -> OpenAPISpec {
      let url = try #require(
         Bundle.module.url(forResource: "dangling-ref-3.1", withExtension: "yaml", subdirectory: "Fixtures")
      )
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Refs",
            baseURL: "https://example.com",
            description: "Component-ref docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIRefsSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func operationHTML(_ spec: OpenAPISpec, slugFragment: String) throws -> String {
      let files = try OpenAPIOperationPage(spec: spec).render(context: self.makeContext())
      return try #require(files.first { $0.outputPath.path.contains(slugFragment) }?.content)
   }

   @Test("A component-$ref'd parameter resolves and renders like an inline parameter")
   func componentRefParameterResolves() throws {
      let html = try self.operationHTML(self.refsSpec(), slugFragment: "listitems")

      // The PageLimit parameter is declared as $ref'd; resolution gives it a real
      // name, location, and type on the operation page.
      #expect(html.contains("limit"))
      #expect(html.contains("data-in=\"query\""))
      #expect(html.contains("integer"))
   }

   @Test("A component-$ref'd response resolves with its status and schema link")
   func componentRefResponseResolves() throws {
      let html = try self.operationHTML(self.refsSpec(), slugFragment: "listitems")

      // The 401 Unauthorized response is declared as a $ref; resolution surfaces
      // its status and its content schema (Error), linked not inlined.
      #expect(html.contains("data-status=\"401\""))
      #expect(html.contains("href=\"/api/schemas/error/\""))
   }

   @Test("A component-$ref'd request body resolves with its content schema link")
   func componentRefRequestBodyResolves() throws {
      let html = try self.operationHTML(self.refsSpec(), slugFragment: "createitem")

      #expect(html.contains("sk-openapi-request-body"))
      #expect(html.contains("application/json"))
      #expect(html.contains("href=\"/api/schemas/item/\""))
   }

   @Test("An unresolvable $ref surfaces a visible placeholder instead of vanishing")
   func unresolvableRefIsVisible() throws {
      // Loading must not throw on dangling refs, and the operation page must still
      // exist and carry the missing reference name (not silently drop the section).
      let html = try self.operationHTML(self.danglingSpec(), slugFragment: "listthings")

      #expect(html.contains("DoesNotExist"))
      #expect(html.contains("data-status=\"200\""))
   }
}
