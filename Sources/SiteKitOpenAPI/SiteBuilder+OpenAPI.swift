import Foundation
import SiteKit

extension SiteBuilder {
   /// OpenAPI documentation site: renders an OpenAPI 3.0/3.1 spec (YAML or JSON)
   /// into a multi-page, style-conforming API-documentation site.
   ///
   /// The spec is discovered by convention at `Content/openapi.yaml` (falling
   /// back to `openapi.yml` / `openapi.json`), or pointed at explicitly with
   /// `specPath`. It is loaded up front and any discovery/decoding problem is
   /// logged as a warning – the build then continues (warn-and-continue), so a
   /// missing or malformed spec yields a site without the API pages rather than
   /// aborting the build.
   /// S2: once the page renderers consume the loaded spec, decide real fail-fast
   /// (a build-phase error surface fits better than a throwing factory, since
   /// SiteKit factories are non-throwing by convention like `.docc(...)`).
   ///
   /// Like `.docc(...)`, the blueprint brings its own shell and reads the token
   /// CSS variables, so all color schemes work and no layout is touched. When the
   /// spec loads, the landing, tag, operation, and schema page renderers consume it
   /// and produce the multi-page docs site; alongside them this factory wires the
   /// content-independent system renderers (sitemap, robots, CSS, favicons, llms.txt).
   ///
   /// - Parameters:
   ///   - config: The site configuration.
   ///   - projectDirectory: The site's root directory (holds `Content/`).
   ///   - cleanBeforeBuild: Whether to wipe the output directory first.
   ///   - specPath: An explicit spec location relative to `projectDirectory`,
   ///     overriding the conventional `Content/openapi.yaml` discovery.
   public static func openAPI(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      specPath: String? = nil
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)

      // Discover and load the spec now; on any problem log a warning and continue
      // (warn-and-continue), so a missing or malformed spec yields a site without the
      // API pages rather than aborting the build. The loaded model is injected into
      // each page renderer (the renderers are OpenAPIKit-free and read only OpenAPISpec).
      // S2: a real fail-fast surface (build-phase error) may fit better than a silently
      // empty site once consumers rely on the API pages – factories are non-throwing by
      // convention like `.docc(...)`, so revisit then.
      if let specURL = Self.resolveSpecURL(specPath: specPath, config: config, projectDirectory: projectDirectory) {
         do {
            let spec = try OpenAPISpecLoader().load(source: specURL)
            builder =
               builder
               .openAPIPageRenderers(for: spec)
               // Register the spec-derived pages into the build context so sitemap, nav-index,
               // search index, and llms.txt all enumerate them (they walk context.sections).
               .contentSectionProvider(OpenAPIContentProvider(spec: spec))
         } catch {
            print("[SiteKit] Warning: OpenAPI spec at '\(specURL.path)' could not be loaded – \(error)")
         }
      } else {
         print(
            "[SiteKit] Warning: no OpenAPI spec found (looked for '\(config.contentDirectory)/openapi.yaml', '.yml', '.json'). The OpenAPI blueprint needs a spec file."
         )
      }

      // The OpenAPI pages live at nested paths the URL router cannot derive, so the
      // machine-index renderers resolve each page to its real OpenAPIRoutes URL via the
      // page's stamped `openAPIPath`. One resolver, shared by sitemap, nav-index, search.
      let pathResolvers: [any PagePathResolving] = [OpenAPIPagePathResolver()]

      return
         builder
         .renderer(SitemapRenderer(pathResolvers: pathResolvers))
         .renderer(RobotsTxtRenderer())
         .renderer(NavIndexRenderer(pathResolvers: pathResolvers))
         .renderer(OpenAPISearchIndexRenderer(pathResolvers: pathResolvers))
         .renderer(OpenAPISearchScriptRenderer())
         .renderer(TokenCSSOutputRenderer())
         .renderer(BaseCSSOutputRenderer())
         .renderer(FontsFaceCSSRenderer())
         .renderer(OpenAPIStylesheetRenderer())
         .renderer(OpenAPINavScriptRenderer())
         .renderer(CloudflareHeadersRenderer())
         .renderer(FaviconRenderer())
         .renderer(OpenAPILlmsTxtRenderer())
   }

   /// Registers the OpenAPI page renderers (landing, tag, operation, schema) for a
   /// loaded `spec`. Each renderer captures the spec and produces its pages from it.
   func openAPIPageRenderers(for spec: OpenAPISpec) -> SiteBuilder {
      self
         .renderer(OpenAPILandingPage(spec: spec))
         .renderer(OpenAPITagPage(spec: spec))
         .renderer(OpenAPIOperationPage(spec: spec))
         .renderer(OpenAPISchemaPage(spec: spec))
   }

   /// Resolves the spec file URL: the explicit `specPath` (relative to the
   /// project root) when given, otherwise the first existing conventional
   /// candidate under the content directory. Returns `nil` when no spec exists.
   private static func resolveSpecURL(specPath: String?, config: SiteConfig, projectDirectory: URL) -> URL? {
      if let specPath {
         return projectDirectory.appendingPathComponent(specPath)
      }

      let contentDirectory = projectDirectory.appendingPathComponent(config.contentDirectory)
      let candidates = ["openapi.yaml", "openapi.yml", "openapi.json"]
         .map { contentDirectory.appendingPathComponent($0) }
      return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
   }
}
