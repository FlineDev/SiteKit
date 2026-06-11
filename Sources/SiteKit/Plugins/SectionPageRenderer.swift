import Foundation

/// Renders one HTML page per `PageModel` across every declared content
/// section, with prev/next navigation scoped to the page's own section.
///
/// Where `ArticlePageRenderer` handles only the legacy single-blog shape,
/// `SectionPageRenderer` works for arbitrary section layouts (multi-section
/// sites: blog + snippets + podcast). Display order honours
/// `SectionConfig.topics` when set – same ordering as the listing pages so
/// previous/next navigation matches the reader's mental sequence.
///
/// Output paths come from `context.router.pagePath(for:in:)`, so a custom
/// `URLRouter` rewrites every section page in one place.
public struct SectionPageRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      // Flatten the ordered pages of every non-empty section so each section page
      // becomes a `Page` iteration target. Stamp the owning section's slug into
      // `extensions["sectionSlug"]` so two sections that happen to share a page
      // slug (e.g. `/blog/index` and `/snippets/index`) are still disambiguated at
      // render time – without the stamp, `locate` returned the first matching
      // section regardless of which one the page actually belonged to.
      var all: [PageModel] = []
      for section in context.sections where !section.pages.isEmpty {
         let sectionSlug = section.config.slug
         for page in Self.orderedPages(for: section) {
            all.append(Self.stampingSectionSlug(sectionSlug, on: page))
         }
      }
      return all
   }

   private static func stampingSectionSlug(_ sectionSlug: String, on page: PageModel) -> PageModel {
      var extensions = page.extensions
      extensions["sectionSlug"] = sectionSlug
      return PageModel(
         id: page.id,
         title: page.title,
         date: page.date,
         slug: page.slug,
         htmlContent: page.htmlContent,
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
         extensions: extensions
      )
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let (section, ordered) = Self.locate(page: page, in: context) else {
         return ""
      }
      let index = ordered.firstIndex(where: { $0.slug == page.slug }) ?? 0
      let previousPage = index > 0 ? ordered[index - 1] : nil
      let nextPage = index < ordered.count - 1 ? ordered[index + 1] : nil
      let renderer = OutputFileRenderer(context: context)
      return renderer.renderArticle(
         page: page,
         previousPage: previousPage,
         nextPage: nextPage,
         section: section.config
      ).content
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String
      if let (section, _) = Self.locate(page: page, in: context) {
         path = context.router.pagePath(for: page, in: section.config)
      } else {
         path = context.router.articlePath(for: page)
      }
      let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func locate(page: PageModel, in context: BuildContext) -> (section: ContentSection, ordered: [PageModel])? {
      // Prefer the section stamped on the page during `pages(in:)` flattening so
      // slug collisions across sections do not silently route to the first
      // matching section. Fall back to the legacy slug-only search for pages
      // that bypassed the stamp (e.g. an enricher reconstructed the model
      // without preserving the stamp, or a custom caller invokes `outputURL`
      // directly with a hand-built `PageModel`).
      if let stampedSlug: String = page.extensionValue("sectionSlug"),
         let stamped = context.sections.first(where: { $0.config.slug == stampedSlug }),
         !stamped.pages.isEmpty
      {
         return (stamped, Self.orderedPages(for: stamped))
      }
      for section in context.sections where !section.pages.isEmpty {
         let ordered = Self.orderedPages(for: section)
         if ordered.contains(where: { $0.slug == page.slug }) {
            return (section, ordered)
         }
      }
      return nil
   }

   /// Returns pages in display order – topic-grouped for sections with topics,
   /// otherwise the default order (chronological by date, newest first).
   private static func orderedPages(for section: ContentSection) -> [PageModel] {
      guard let topics = section.config.topics, !topics.isEmpty else {
         return section.pages
      }

      // Match the listing display order: alphabetically sorted topics,
      // pages sorted by date within each topic, deduplicated.
      let sortedTopics = topics.sorted {
         $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
      let dateSorted = section.pages.sortedByDate()

      var ordered: [PageModel] = []
      var usedSlugs = Set<String>()

      for topic in sortedTopics {
         let topicPages = dateSorted.filter { page in
            page.tags.contains(where: { topic.tags.contains($0) })
         }
         for page in topicPages where !usedSlugs.contains(page.slug) {
            ordered.append(page)
            usedSlugs.insert(page.slug)
         }
      }

      // Uncategorized pages at the end
      for page in dateSorted where !usedSlugs.contains(page.slug) {
         ordered.append(page)
      }

      return ordered
   }
}
