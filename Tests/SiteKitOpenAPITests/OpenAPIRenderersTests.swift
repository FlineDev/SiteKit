import Foundation
import SiteKit
import Testing

@testable import SiteKitOpenAPI

/// HTML-structure and sample-site tests for the OpenAPI page renderers. The fixtures
/// are the bundled Petstore specs; the assertions check the semantic output (classes,
/// `data-` attributes, paths, names) the stylesheet targets, plus the expected
/// `OutputFile` set for a full sample build.
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

/// Slug collision-guard tests: distinct tag names and distinct operation ids that
/// pre-fold to the same slug must still resolve to distinct output paths (suffixed
/// `-2`), never silently overwriting one another, and accented names must fold to
/// ASCII slugs.
@Suite("OpenAPI slug collisions")
struct OpenAPISlugCollisionTests {
   private func collisionsSpec() throws -> OpenAPISpec {
      let url = try #require(
         Bundle.module.url(forResource: "slug-collisions-3.1", withExtension: "yaml", subdirectory: "Fixtures")
      )
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Collisions",
            baseURL: "https://example.com",
            description: "Slug collision docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPICollisionsSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func allOutputPaths() throws -> [String] {
      let spec = try self.collisionsSpec()
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
      return paths
   }

   @Test("No two pages resolve to the same output path")
   func noSilentOverwrite() throws {
      let paths = try self.allOutputPaths()
      // The guard's core promise: every page has a unique output file, so nothing is
      // silently overwritten.
      #expect(Set(paths).count == paths.count)
   }

   @Test("Two tags that fold to the same slug get distinct tag pages")
   func collidingTagsAreDistinct() throws {
      let paths = try self.allOutputPaths()
      // "Pets" and "pets" both fold to "pets"; the second is suffixed to "pets-2".
      #expect(paths.contains("/tmp/_OpenAPICollisionsSite/api/pets/index.html"))
      #expect(paths.contains("/tmp/_OpenAPICollisionsSite/api/pets-2/index.html"))
   }

   @Test("Two operations that fold to the same slug get distinct operation pages")
   func collidingOperationsAreDistinct() throws {
      let paths = try self.allOutputPaths()
      // operationIds "listItems" and "ListItems" both fold to "listitems" under the
      // same tag; the second is suffixed to "listitems-2".
      #expect(paths.contains("/tmp/_OpenAPICollisionsSite/api/pets/listitems/index.html"))
      #expect(paths.contains("/tmp/_OpenAPICollisionsSite/api/pets/listitems-2/index.html"))
   }

   @Test("An accented tag name folds to an ASCII slug")
   func accentedTagFoldsToASCII() throws {
      let paths = try self.allOutputPaths()
      // "Café" folds to the ASCII slug "cafe".
      #expect(paths.contains("/tmp/_OpenAPICollisionsSite/api/cafe/index.html"))
   }
}

/// Cross-listing tests: an operation tagged `[pets, admin]` keeps one canonical
/// page under its first tag but is listed on both tag pages (each link pointing at
/// the canonical page), and both landing cards count it.
@Suite("OpenAPI multi-tag cross-listing")
struct OpenAPIMultiTagTests {
   private func multiTagSpec() throws -> OpenAPISpec {
      let url = try #require(
         Bundle.module.url(forResource: "multi-tag-3.1", withExtension: "yaml", subdirectory: "Fixtures")
      )
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "MultiTag",
            baseURL: "https://example.com",
            description: "Cross-listing docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIMultiTagSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func tagPageHTML(slugFragment: String) throws -> String {
      let spec = try self.multiTagSpec()
      let files = try OpenAPITagPage(spec: spec).render(context: self.makeContext())
      return try #require(files.first { $0.outputPath.path.contains("/api/\(slugFragment)/index.html") }?.content)
   }

   @Test("A multi-tagged operation is listed on every tag page, linking to its canonical page")
   func crossListedOnBothTags() throws {
      let petsPage = try self.tagPageHTML(slugFragment: "pets")
      let adminPage = try self.tagPageHTML(slugFragment: "admin")

      // banPet is tagged [pets, admin]; its canonical page lives under the first tag.
      // Both tag pages link to that one canonical URL, never a per-tag duplicate.
      #expect(petsPage.contains("href=\"/api/pets/banpet/\""))
      #expect(adminPage.contains("href=\"/api/pets/banpet/\""))
      // The admin page must NOT mint an admin-scoped URL for it.
      #expect(!adminPage.contains("href=\"/api/admin/banpet/\""))
   }

   @Test("The canonical operation page exists exactly once, under the first tag")
   func oneCanonicalPage() throws {
      let spec = try self.multiTagSpec()
      let files = try OpenAPIOperationPage(spec: spec).render(context: self.makeContext())
      let banPages = files.filter { $0.outputPath.path.contains("banpet") }

      #expect(banPages.count == 1)
      #expect(banPages.first?.outputPath.path == "/tmp/_OpenAPIMultiTagSite/api/pets/banpet/index.html")
   }

   @Test("Both landing cards count the multi-tagged operation")
   func landingCardsCountUnderEveryTag() throws {
      let spec = try self.multiTagSpec()
      let html = try #require(try OpenAPILandingPage(spec: spec).render(context: self.makeContext()).first?.content)

      // pets owns listPets + banPet (2); admin lists the cross-listed banPet (1).
      #expect(html.contains(">2 endpoints<"))
      #expect(html.contains(">1 endpoint<"))
   }
}

/// Sidebar navigation-tree tests: the persistent rail on every page has a group per
/// tag (each operation under it with the right method hook), a Schemas group listing
/// every schema, a deprecated hook on deprecated operations, the active item marked
/// on the page being rendered, and cross-listing consistency (a multi-tag operation
/// appears under every tag it carries, matching the page lists).
@Suite("OpenAPI sidebar nav")
struct OpenAPINavTests {
   private func spec(_ name: String) throws -> OpenAPISpec {
      let url = try #require(Bundle.module.url(forResource: name, withExtension: "yaml", subdirectory: "Fixtures"))
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Nav",
            baseURL: "https://example.com",
            description: "Nav docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPINavSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   /// The `<nav class="sk-openapi-nav">…</nav>` slice of a rendered page, so an
   /// assertion targets the rail and not the page body (which shares many hooks).
   private func navSlice(_ html: String) throws -> String {
      let start = try #require(html.range(of: "<nav class=\"sk-openapi-nav\""))
      let end = try #require(html.range(of: "</nav>", range: start.lowerBound..<html.endIndex))
      return String(html[start.lowerBound..<end.upperBound])
   }

   private func landingNav(_ specName: String) throws -> String {
      let spec = try self.spec(specName)
      let html = try #require(try OpenAPILandingPage(spec: spec).render(context: self.makeContext()).first?.content)
      return try self.navSlice(html)
   }

   @Test("The rail has a group per tag, each listing its operations with method hooks")
   func groupPerTagWithOperations() throws {
      let nav = try self.landingNav("petstore-3.1")

      #expect(nav.contains("aria-label=\"API navigation\""))
      #expect(nav.contains("class=\"sk-openapi-nav-group\""))
      // The single petstore tag and one of its operations, with the method hook + link.
      #expect(nav.contains(">pets<"))
      #expect(nav.contains("data-method=\"get\""))
      // LOW-4: the nav label is the operation summary (matching the page H1), not the id.
      #expect(nav.contains(">Info for a specific pet<"))
      #expect(nav.contains("href=\"/api/pets/showpetbyid/\""))
   }

   @Test("The rail has a Schemas group listing every schema")
   func schemasGroupListsEverySchema() throws {
      let nav = try self.landingNav("petstore-3.1")

      #expect(nav.contains(">Schemas<"))
      #expect(nav.contains(">Pet<"))
      #expect(nav.contains(">Pets<"))
      #expect(nav.contains(">Error<"))
      #expect(nav.contains("href=\"/api/schemas/pet/\""))
      #expect(nav.contains("href=\"/api/schemas/error/\""))
   }

   @Test("A deprecated operation carries the deprecated hook in the rail")
   func deprecatedOperationHasHook() throws {
      let nav = try self.landingNav("nav-deprecated-3.1")

      // LOW-4: label is the summary; the deprecated hook rides on the item.
      #expect(nav.contains(">Old endpoint<"))
      #expect(nav.contains("data-deprecated=\"true\""))
   }

   @Test("The active nav item is marked on the page being rendered")
   func activeItemMarkedOnItsPage() throws {
      let spec = try self.spec("petstore-3.1")

      // On the showPetById operation page, that item is active; another op is not.
      let opFiles = try OpenAPIOperationPage(spec: spec).render(context: self.makeContext())
      let opHTML = try #require(opFiles.first { $0.outputPath.path.contains("showpetbyid") }?.content)
      let opNav = try self.navSlice(opHTML)
      // The is-active class is on the showPetById link, and that link carries aria-current.
      #expect(opNav.contains("sk-openapi-nav-link is-active\" href=\"/api/pets/showpetbyid/\""))
      #expect(opNav.contains("title=\"Info for a specific pet\" aria-current=\"page\""))
      #expect(!opNav.contains("href=\"/api/pets/listpets/\" aria-current=\"page\""))

      // On the landing page, the home link is the active one instead.
      let landingNav = try self.landingNav("petstore-3.1")
      #expect(landingNav.contains("sk-openapi-nav-home is-active"))
      #expect(!landingNav.contains("href=\"/api/pets/showpetbyid/\" aria-current=\"page\""))
   }

   @Test("A multi-tag operation appears under every one of its tags in the rail")
   func crossListedUnderEveryTagInNav() throws {
      let nav = try self.landingNav("multi-tag-3.1")

      // Both tag groups are present.
      #expect(nav.contains(">pets<"))
      #expect(nav.contains(">admin<"))
      // banPet (tagged [pets, admin]) is listed twice – once per tag – both links
      // pointing at its single canonical page, matching the page-list cross-listing.
      let canonicalLinks = nav.components(separatedBy: "href=\"/api/pets/banpet/\"").count - 1
      #expect(canonicalLinks == 2)
      #expect(!nav.contains("href=\"/api/admin/banpet/\""))
   }

   @Test("The rail is emitted on every page type")
   func navOnEveryPageType() throws {
      let spec = try self.spec("petstore-3.1")
      let context = self.makeContext()
      let renderers: [any Renderer] = [
         OpenAPILandingPage(spec: spec),
         OpenAPITagPage(spec: spec),
         OpenAPIOperationPage(spec: spec),
         OpenAPISchemaPage(spec: spec),
      ]
      for renderer in renderers {
         for file in try renderer.render(context: context) {
            #expect(file.content.contains("<nav class=\"sk-openapi-nav\""))
         }
      }
   }
}

/// Styling tests: the stylesheet and script render as output files, the CSS carries a
/// generated color rule per HTTP verb, the shell links the stylesheet and defers the
/// script, and the three nav follow-ups (single aria-current, summary labels, explicit
/// landing path) hold.
@Suite("OpenAPI styling")
struct OpenAPIStylingTests {
   private func spec(_ name: String) throws -> OpenAPISpec {
      let url = try #require(Bundle.module.url(forResource: name, withExtension: "yaml", subdirectory: "Fixtures"))
      return try OpenAPISpecLoader().load(source: url)
   }

   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Styling",
            baseURL: "https://example.com",
            description: "Styling docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIStylingSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func navSlice(_ html: String) throws -> String {
      let start = try #require(html.range(of: "<nav class=\"sk-openapi-nav\""))
      let end = try #require(html.range(of: "</nav>", range: start.lowerBound..<html.endIndex))
      return String(html[start.lowerBound..<end.upperBound])
   }

   @Test("The stylesheet renders to /assets/css/openapi.css with a color rule per verb")
   func stylesheetEmitsCSSWithVerbRules() throws {
      let files = try OpenAPIStylesheetRenderer().render(context: self.makeContext())
      let css = try #require(files.first)
      #expect(css.outputPath.path.hasSuffix("/assets/css/openapi.css"))

      // One generated rule per semantic verb (the [data-method] palette).
      for verb in ["get", "post", "put", "patch", "delete", "head", "options"] {
         #expect(css.content.contains(".sk-openapi-method[data-method=\"\(verb)\"]"))
      }
   }

   @Test("The nav script renders to /assets/js/openapi-nav.js")
   func scriptEmitsJS() throws {
      let files = try OpenAPINavScriptRenderer().render(context: self.makeContext())
      let js = try #require(files.first)
      #expect(js.outputPath.path.hasSuffix("/assets/js/openapi-nav.js"))
      #expect(!js.content.isEmpty)
   }

   @Test("The shell head links the stylesheet and defers the script")
   func shellLinksAssets() throws {
      let spec = try self.spec("petstore-3.1")
      let html = try #require(try OpenAPILandingPage(spec: spec).render(context: self.makeContext()).first?.content)

      #expect(html.contains("<link rel=\"stylesheet\" href=\"/assets/css/openapi.css\"/>"))
      #expect(html.contains("<script defer src=\"/assets/js/openapi-nav.js\"></script>"))
   }

   @Test("LOW-3: a cross-listed op's page marks exactly one aria-current, both occurrences active")
   func singleAriaCurrentOnCrossListedOpPage() throws {
      let spec = try self.spec("multi-tag-3.1")
      let files = try OpenAPIOperationPage(spec: spec).render(context: self.makeContext())
      let html = try #require(files.first { $0.outputPath.path.contains("banpet") }?.content)
      let nav = try self.navSlice(html)

      // banPet is listed under both pets and admin; on its own page both occurrences
      // read as active, but only the canonical (pets) one advertises aria-current.
      let ariaCurrentCount = nav.components(separatedBy: "aria-current=\"page\"").count - 1
      let activeCount = nav.components(separatedBy: "sk-openapi-nav-link is-active").count - 1
      #expect(ariaCurrentCount == 1)
      #expect(activeCount == 2)
   }

   @Test("LOW-4: the nav label uses the operation summary, not the operationId")
   func navLabelPrefersSummary() throws {
      let spec = try self.spec("multi-tag-3.1")
      let html = try #require(try OpenAPILandingPage(spec: spec).render(context: self.makeContext()).first?.content)
      let nav = try self.navSlice(html)

      // banPet's summary is "Ban a pet"; the id "banPet" must not be the label.
      #expect(nav.contains(">Ban a pet<"))
      #expect(!nav.contains(">banPet<"))
   }

   @Test("LOW-5: the landing page stashes its openAPIPath explicitly")
   func landingStashesOpenAPIPath() throws {
      let spec = try self.spec("petstore-3.1")
      let context = self.makeContext()
      let page = try #require(OpenAPILandingPage(spec: spec).pages(in: context).first)
      let stashed: String? = page.extensionValue("openAPIPath")
      #expect(stashed == "/api/")
   }
}

/// Styling code-review follow-up tests: the two MEDIUM and four LOW findings from the
/// styling review. Each asserts on the served artifact (generated CSS, bundled JS, rendered
/// nav markup), so the fix is proven by the file a browser actually receives.
@Suite("OpenAPI styling fixes")
struct OpenAPIStylingFixTests {
   private func makeContext() -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "Fix",
            baseURL: "https://example.com",
            description: "Fix docs.",
            sections: [SectionConfig(name: "API", slug: "api", contentDirectory: "Content", urlPrefix: "api")]
         ),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_OpenAPIFixSite"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func stylesheet() throws -> String {
      try #require(try OpenAPIStylesheetRenderer().render(context: self.makeContext()).first?.content)
   }

   private func navScript() throws -> String {
      try #require(try OpenAPINavScriptRenderer().render(context: self.makeContext()).first?.content)
   }

   private func navSlice(_ html: String) throws -> String {
      let start = try #require(html.range(of: "<nav class=\"sk-openapi-nav\""))
      let end = try #require(html.range(of: "</nav>", range: start.lowerBound..<html.endIndex))
      return String(html[start.lowerBound..<end.upperBound])
   }

   private func landingHTML() throws -> String {
      let url = try #require(Bundle.module.url(forResource: "petstore-3.1", withExtension: "yaml", subdirectory: "Fixtures"))
      let spec = try OpenAPISpecLoader().load(source: url)
      return try #require(try OpenAPILandingPage(spec: spec).render(context: self.makeContext()).first?.content)
   }

   @Test("M1: each verb badge emits an AA label color, not a blanket white")
   func verbBadgesEmitPerVerbAALabelColor() throws {
      let css = try self.stylesheet()

      // Light verbs flip to near-black text (white failed AA on these hues); the two dark
      // verbs keep white. The label color now travels with the background in each rule.
      #expect(css.contains(".sk-openapi-method[data-method=\"get\"] { background: #61affe; color: #000; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"post\"] { background: #49cc90; color: #000; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"put\"] { background: #fca130; color: #000; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"patch\"] { background: #50e3c2; color: #000; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"delete\"] { background: #f93e3e; color: #000; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"head\"] { background: #9012fe; color: #fff; }"))
      #expect(css.contains(".sk-openapi-method[data-method=\"options\"] { background: #0d5aa7; color: #fff; }"))
   }

   @Test("M2: the mobile off-canvas drawer is gated behind html.js, with a JS-off fallback")
   func mobileDrawerGatedBehindJSClass() throws {
      let css = try self.stylesheet()

      // The off-canvas transform and the hamburger only apply when JS is on.
      #expect(css.contains("html.js .sk-openapi-nav-toggle"))
      #expect(css.contains("html.js .sk-openapi-layout.is-nav-open .sk-openapi-nav"))
      // JS off: the rail renders in normal document flow instead of off-canvas.
      #expect(css.contains("html:not(.js) .sk-openapi-nav"))
      #expect(css.contains("html:not(.js) .sk-openapi-body"))
      // The translateX(-100%) hide must live INSIDE the html.js-gated rule – that is what
      // keeps a JS-off narrow viewport from trapping the rail off-canvas.
      let gatedStart = try #require(css.range(of: "html.js .sk-openapi-nav {"))
      let gatedEnd = try #require(css.range(of: "}", range: gatedStart.upperBound..<css.endIndex))
      let gatedRule = String(css[gatedStart.upperBound..<gatedEnd.lowerBound])
      #expect(gatedRule.contains("transform: translateX(-100%)"))
   }

   @Test("M2: the nav script adds the html.js class as early as it runs")
   func navScriptAddsJSClassEarly() throws {
      let js = try self.navScript()
      #expect(js.contains("document.documentElement.classList.add(\"js\")"))
   }

   @Test("L1: the active-row pill derives from the active token, not a hard-coded white")
   func activePillDerivesFromActiveToken() throws {
      let css = try self.stylesheet()
      #expect(css.contains(".sk-openapi-nav-link.is-active .sk-openapi-method {"))
      #expect(css.contains("background: var(--sk-openapi-active-text);"))
      #expect(css.contains("color: var(--sk-openapi-active-bg);"))
      // The old assume-dark-accent translucent white is gone.
      #expect(!css.contains("rgba(255, 255, 255, 0.25)"))
   }

   @Test("L4: the nav row radius follows the theme --radius token")
   func rowRadiusFollowsThemeToken() throws {
      let css = try self.stylesheet()
      #expect(css.contains("--sk-openapi-row-radius: var(--radius, 8px);"))
   }

   @Test("L2: each group title sits in a header wrapper so the twist can be its sibling")
   func groupHeaderWrapsTitleForSiblingTwist() throws {
      let nav = try self.navSlice(try self.landingHTML())

      // The wrapper is present and holds the title link directly.
      #expect(nav.contains("<div class=\"sk-openapi-nav-group-header\"><a class=\"sk-openapi-nav-group-title"))
      // The twist is JS-injected, never server-rendered inside the anchor.
      #expect(!nav.contains("sk-openapi-nav-twist"))
   }

   @Test("L2/L3: the script inserts the twist into the header and wires section-named ARIA")
   func navScriptWiresAriaControlsAndSectionLabel() throws {
      let js = try self.navScript()

      // L2: the twist targets the header row (sibling of the title), not the anchor.
      #expect(js.contains(".sk-openapi-nav-group-header"))
      // L3: aria-controls on both the twist and the mobile toggle, plus a section-named
      // label rather than a generic "Toggle section".
      #expect(js.contains("twist.setAttribute(\"aria-controls\""))
      #expect(js.contains("toggle.setAttribute(\"aria-controls\""))
      #expect(js.contains("\"Toggle the \" + sectionName + \" section\""))
      #expect(!js.contains("\"Toggle section\""))
   }
}
