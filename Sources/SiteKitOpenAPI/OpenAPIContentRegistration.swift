import Foundation
import SiteKit

/// Registers the OpenAPI blueprint's spec-derived pages into `BuildContext.sections` so the
/// standard machine-index renderers (sitemap, nav-index, search, llms.txt) enumerate them.
///
/// The OpenAPI page renderers generate their pages from the spec inside `pages(in:)`; those
/// pages never pass through Discovery/Loading, so without this provider they are absent from
/// `context.sections` and every `context`-walking system renderer misses them. The provider
/// returns exactly the union of the four page renderers' `pages(in:)` – the same `PageModel`s
/// that get rendered, each already stamped with its `openAPIPath` – so the indexes and the
/// rendered pages stay in lockstep. Pair it with ``OpenAPIPagePathResolver`` so those indexes
/// resolve each page to its real ``OpenAPIRoutes`` URL.
public struct OpenAPIContentProvider: ContentSectionProviding {
   private let spec: OpenAPISpec

   /// Creates a provider for `spec`.
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func contentSection(in context: BuildContext) -> ContentSection? {
      let pages =
         OpenAPILandingPage(spec: self.spec).pages(in: context)
         + OpenAPITagPage(spec: self.spec).pages(in: context)
         + OpenAPIOperationPage(spec: self.spec).pages(in: context)
         + OpenAPISchemaPage(spec: self.spec).pages(in: context)

      guard !pages.isEmpty else { return nil }

      // Reuse the configured API section so llms.txt / nav-index group the pages under it and
      // the search index picks up its URL prefix. With no section configured there is nothing
      // to attach to – warn loudly (matching the factory's spec-missing warnings) rather than
      // silently dropping every API page from every machine index.
      guard let sectionConfig = context.config.effectiveSections.first else {
         print(
            "[SiteKit] Warning: \(pages.count) OpenAPI page(s) were generated but no content section is configured, so they are omitted from the sitemap, nav-index, search index, and llms.txt. Configure at least one section in SiteConfig."
         )
         return nil
      }
      return ContentSection(config: sectionConfig, pages: pages)
   }
}

/// Resolves every OpenAPI page to the `OpenAPIRoutes` path it actually ships at, for the
/// machine-index renderers (sitemap, nav-index, search) that otherwise trust the URL router.
///
/// The OpenAPI pages live at nested paths (`/api/pets/showpetbyid/`, `/api/schemas/pet/`, …)
/// the default router cannot derive from slug + section, so each page stamps its canonical
/// path into the `openAPIPath` extension at creation. This resolver reads that stamp – the
/// single ``OpenAPIRoutes`` source of truth, never a recomputed path – and returns it; pages
/// without the stamp fall through to the router default.
public struct OpenAPIPagePathResolver: PagePathResolving {
   public init() {}

   public func pathResolution(for page: PageModel, context: BuildContext) -> PagePathResolution {
      guard let path: String = page.extensionValue("openAPIPath") else {
         return .routerDefault
      }
      return .path(path)
   }
}
