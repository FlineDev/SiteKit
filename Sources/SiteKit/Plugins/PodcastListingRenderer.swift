import Foundation

/// Renders the podcast episode listing page with episode cards showing number, title,
/// date, summary, tags, and duration.
///
/// Filters out episodes with `episode == 0` (e.g., trailer or bonus content).
public struct PodcastListingRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      guard context.sections.contains(where: { $0.config.slug == "podcast" }) else { return [] }
      return [Self.marker()]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return ""
      }
      let helper = OutputFileRenderer(context: context)

      let pages = section.pages
         .sortedByDate()
         .filter { (page: PageModel) -> Bool in
            let num: Int? = page.extensionValue("episode")
            return num != 0
         }

      let feedPath = context.config.podcast?.feedPath ?? "/podcast.xml"
      let listingPath = context.router.sectionListingPath(for: section.config)

      let pageTitle = "\(section.config.name) \u{2014} \(context.config.name)"

      let head = helper.buildHead(
         title: pageTitle,
         description: context.config.description,
         canonicalURL: "\(context.config.baseURL)\(listingPath)",
         rssFeedURL: feedPath,
         rssFeedTitle: context.config.name
      )

      var contentParts: [String] = []

      let episodesLabel = context.uiStrings.string(for: .podcastEpisodes)
      let subscribeFeedLabel = context.uiStrings.string(for: .podcastSubscribeFeed)

      contentParts.append("<header class=\"listing-header\">")
      contentParts.append("<div class=\"listing-title-row\">")
      contentParts.append("<h1>\(episodesLabel.htmlEscaped)</h1>")
      contentParts.append("<a class=\"subscribe-podcast\" href=\"\(feedPath)\" title=\"\(subscribeFeedLabel.htmlEscaped)\"><i class=\"fa-solid fa-podcast\"></i> Podcast Feed</a>")
      contentParts.append("</div>")
      contentParts.append("</header>")

      contentParts.append("<ul class=\"episode-list\">")

      for page in pages {
         let episodeNumber: Int? = page.extensionValue("episode")
         let duration: String? = page.extensionValue("duration")
         let episodePath = context.router.pagePath(for: page, in: section.config)

         var cardParts: [String] = []
         cardParts.append("<div class=\"episode-card\">")

         if let num = episodeNumber {
            cardParts.append("<span class=\"episode-card-number\">#\(num)</span>")
         }

         cardParts.append("<div class=\"episode-card-content\">")
         cardParts.append("<h2 class=\"episode-card-title\"><a class=\"episode-card-link\" href=\"\(episodePath)\">\(page.title.strippedEpisodePrefix.htmlEscaped)</a></h2>")

         cardParts.append("<div class=\"episode-card-meta\"><time datetime=\"\(helper.isoDate(page.date))\">\(helper.formatDate(page.date).htmlEscaped)</time></div>")

         if let summary = page.summary, !summary.isEmpty {
            cardParts.append("<p class=\"episode-card-summary\">\(summary.htmlEscaped)</p>")
         }

         if !page.tags.isEmpty {
            let tagNames = context.config.tagDisplayNames ?? [:]
            let tags = page.tags.prefix(4).map { tag in
               "<a class=\"sk-tag-link\" href=\"\(context.router.tagPath(for: tag))\">\((tagNames[tag] ?? tag).htmlEscaped)</a>"
            }.joined()
            cardParts.append("<div class=\"episode-card-tags\">\(tags)</div>")
         }

         cardParts.append("</div>")

         if let duration {
            cardParts.append("<span class=\"episode-card-duration\">\(duration.formattedDuration.htmlEscaped)</span>")
         }

         cardParts.append("</div>")

         contentParts.append("<li>\(cardParts.joined())</li>")
      }

      contentParts.append("</ul>")

      let mainContent = "<main class=\"sk-main\">\(contentParts.joined())</main>"

      return helper.renderPageShell(
         head: head,
         bodyClass: "sk-page-listing sk-section-podcast",
         content: mainContent
      )
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      let listingPath = context.router.sectionListingPath(for: section.config)
      let relative = String(listingPath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func marker() -> PageModel {
      PageModel(
         title: "",
         slug: "podcast",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
