import Foundation

/// Renders one HTML page per article in the default (legacy `blog`) section,
/// with prev/next navigation derived from `context.articles` order.
///
/// `articles` is the date-sorted page list of the first declared section (or
/// the section with `slug: "blog"`). Use `SectionPageRenderer` to cover
/// articles in arbitrary sections; `ArticlePageRenderer` exists for the
/// legacy "single blog section" shape and is included automatically by
/// `SiteBuilder.blog(...)`.
///
/// HTML is assembled by delegating to `OutputFileRenderer.renderArticle`,
/// which wraps the article body in `PageShell` so the page picks up every
/// SEO/perf/i18n concern.
public struct ArticlePageRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      context.articles
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let articles = context.articles
      let index = articles.firstIndex(where: { $0.slug == page.slug }) ?? 0
      let previousPage = index > 0 ? articles[index - 1] : nil
      let nextPage = index < articles.count - 1 ? articles[index + 1] : nil
      let renderer = OutputFileRenderer(context: context)
      return renderer.renderArticle(
         page: page,
         previousPage: previousPage,
         nextPage: nextPage
      ).content
   }
}
