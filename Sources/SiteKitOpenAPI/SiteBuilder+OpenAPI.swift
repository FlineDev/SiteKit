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
   /// CSS variables, so all color schemes work and no layout is touched. The
   /// page renderers that turn the loaded ``OpenAPISpec`` into landing, tag,
   /// operation, and schema pages are composed in a later slice; this factory
   /// wires spec discovery, the loader, and the content-independent system
   /// renderers (sitemap, robots, CSS, favicons, llms.txt).
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
      // Discover and load the spec now so discovery + decoding are exercised at
      // compose time; a problem is logged and the build continues (warn-and-continue).
      // The loaded model is the contract the page renderers consume once they land
      // in a later slice, at which point S2 revisits whether to fail the build instead.
      if let specURL = Self.resolveSpecURL(specPath: specPath, config: config, projectDirectory: projectDirectory) {
         do {
            _ = try OpenAPISpecLoader().load(source: specURL)
         } catch {
            print("[SiteKit] Warning: OpenAPI spec at '\(specURL.path)' could not be loaded – \(error)")
         }
      } else {
         print(
            "[SiteKit] Warning: no OpenAPI spec found (looked for '\(config.contentDirectory)/openapi.yaml', '.yml', '.json'). The OpenAPI blueprint needs a spec file."
         )
      }

      return SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .renderer(SitemapRenderer())
         .renderer(RobotsTxtRenderer())
         .renderer(TokenCSSOutputRenderer())
         .renderer(BaseCSSOutputRenderer())
         .renderer(FontsFaceCSSRenderer())
         .renderer(CloudflareHeadersRenderer())
         .renderer(FaviconRenderer())
         .renderer(LlmsTxtRenderer())
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
