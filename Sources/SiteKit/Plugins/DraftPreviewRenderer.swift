import Foundation
import Logging

/// Generates preview pages for draft content at `/blog/<slug>/preview-<id>/`.
/// Draft pages are unlisted: not included in sitemaps, RSS feeds, or any listing pages.
/// They are only accessible via their direct preview URL.
public struct DraftPreviewRenderer: Page {
   private let logger = Logger(label: "SiteKit.DraftPreviewRenderer")

   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      // Only drafts with an `id` (preview token) produce preview pages.
      context.draftPages.filter { $0.id != nil }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let renderer = OutputFileRenderer(context: context)
      let section = self.section(for: page, in: context)
      return renderer.renderPreviewArticle(page: page, section: section)?.content ?? ""
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      // Output: /<articlePath or sectionPagePath>/preview-<token>/index.html
      let section = self.section(for: page, in: context)
      let articlePath: String
      if let section {
         articlePath = context.router.pagePath(for: page, in: section)
      } else {
         articlePath = context.router.articlePath(for: page)
      }
      let relative = String(articlePath.dropFirst())
      let token = page.id ?? ""
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("preview-\(token)")
         .appendingPathComponent("index.html")
   }

   /// Resolves the section a draft belongs to via its `category`.
   private func section(for page: PageModel, in context: BuildContext) -> SectionConfig? {
      let sectionsByCategory = Dictionary(
         context.sections.flatMap { section in
            section.config.categories?.map { ($0.slug, section.config) } ?? []
         },
         uniquingKeysWith: { first, _ in first }
      )
      return sectionsByCategory[page.category] ?? context.sections.first?.config
   }
}
