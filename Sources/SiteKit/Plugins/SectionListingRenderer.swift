import Foundation

/// Renders one HTML listing page per non-empty `ContentSection`, at the
/// section's router-derived path (e.g. `/blog/`, `/snippets/`).
///
/// Supports both flat listings (date-sorted card grid) and topic-grouped
/// listings – the renderer chooses based on whether
/// `SectionConfig.topics` is set. Title row links to the per-section RSS
/// feed (`/<section.urlPrefix>/feed.xml`), so `RSSFeedRenderer` should be
/// registered alongside this renderer to make that link resolve.
public struct SectionListingRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      // Synthesize one marker `PageModel` per non-empty section. The marker carries
      // the section slug in `slug` so `renderHTML` / `outputURL` can find the
      // matching `ContentSection` in `context.sections`.
      context.sections
         .filter { !$0.pages.isEmpty }
         .map { Self.marker(forSectionSlug: $0.config.slug) }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let section = context.sections.first(where: { $0.config.slug == page.slug }) else {
         return ""
      }
      return OutputFileRenderer(context: context).renderSectionListing(section: section).content
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      guard let section = context.sections.first(where: { $0.config.slug == page.slug }) else {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      let listingPath = context.router.sectionListingPath(for: section.config)
      let relative = String(listingPath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func marker(forSectionSlug slug: String) -> PageModel {
      PageModel(
         title: "",
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
