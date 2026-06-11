import Foundation

/// Renders one HTML listing page per declared `CategoryConfig`, at the
/// category's router-derived path.
///
/// Skipped (returns no pages) when `SiteConfig.blogURLPrefix` is set, because
/// that mode flattens every article URL under a single prefix and the
/// per-category page becomes meaningless. Outside that case, categories
/// surface a curated subset of the legacy `blog` section's articles.
public struct CategoryListingRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      // Skip category pages when blogURLPrefix flattens all URLs.
      guard context.config.blogURLPrefix == nil else { return [] }
      return context.config.categories.map { Self.marker(forCategorySlug: $0.slug) }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let categoryConfig = context.config.categories.first(where: { $0.slug == page.slug }) else {
         return ""
      }
      let pagesByCategory = Dictionary(grouping: context.articles) { $0.category }
      let categoryPages = pagesByCategory[categoryConfig.slug] ?? []
      return OutputFileRenderer(context: context)
         .renderCategoryListing(category: categoryConfig, pages: categoryPages)
         .content
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      guard let categoryConfig = context.config.categories.first(where: { $0.slug == page.slug }) else {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      let catPath = context.router.categoryPath(for: categoryConfig)
      let relative = String(catPath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func marker(forCategorySlug slug: String) -> PageModel {
      PageModel(
         title: "",
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
