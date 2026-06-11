import Foundation

/// Renders static pages with template variable replacement.
///
/// Replaces placeholder tokens in static page HTML content before rendering:
/// - `{{EPISODE_COUNT}}` – total number of podcast episodes (excluding episode 0)
///
/// This renderer is extensible: add new entries to the `replacements` dictionary
/// to support additional template variables.
public struct TemplateStaticPageRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      context.staticPages
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let renderer = OutputFileRenderer(context: context)
      let replacements = self.replacements(for: context)

      var html = page.htmlContent
      for (placeholder, value) in replacements {
         html = html.replacing(placeholder, with: value)
      }

      if html != page.htmlContent {
         let updatedPage = PageModel(
            id: page.id,
            title: page.title,
            date: page.date,
            slug: page.slug,
            htmlContent: html,
            sourcePath: page.sourcePath,
            category: page.category,
            tags: page.tags,
            summary: page.summary,
            description: page.description,
            author: page.author,
            image: page.image,
            imageAlt: page.imageAlt,
            draft: page.draft,
            pageType: page.pageType,
            locale: page.locale,
            originalLanguage: page.originalLanguage,
            legalDocument: page.legalDocument,
            extensions: page.extensions
         )
         return renderer.renderStaticPage(updatedPage).content
      }

      return renderer.renderStaticPage(page).content
   }

   private func replacements(for context: BuildContext) -> [String: String] {
      let episodeCount = context.sections
         .first(where: { $0.config.slug == "podcast" })?
         .pages.filter { (page: PageModel) -> Bool in
            let num: Int? = page.extensionValue("episode")
            return num != 0
         }.count ?? 0
      return ["{{EPISODE_COUNT}}": "\(episodeCount)"]
   }
}
