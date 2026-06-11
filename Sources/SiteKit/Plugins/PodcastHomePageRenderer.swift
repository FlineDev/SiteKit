import Foundation

/// Renders the podcast home page with an optional hero section (title, subtitle, host previews)
/// and a list of recent episodes.
///
/// Host previews are read from `config.podcast.hosts`. If no hosts are configured, the host
/// section is omitted.
public struct PodcastHomePageRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      // Render only when a `podcast` section is configured.
      guard context.sections.contains(where: { $0.config.slug == "podcast" }) else { return [] }
      return [Self.marker()]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return ""
      }
      let helper = OutputFileRenderer(context: context)

      let homeConfig = context.config.homePage
      let feedPath = context.config.podcast?.feedPath ?? "/podcast.xml"
      let title = homeConfig?.title ?? context.config.name
      let pageTitle: String
      if let homeTitle = homeConfig?.title, let subtitle = homeConfig?.subtitle {
         pageTitle = "\(homeTitle) \u{2014} \(subtitle)"
      } else {
         pageTitle = title
      }

      // LCP candidate on a podcast home page is the first host avatar in the hero
      // section. Preloading it (+ fetchpriority="high" on the img itself, added below)
      // lets the browser discover it during HTML head parsing instead of waiting for
      // <body> layout – typically cuts 300–800 ms off Largest Contentful Paint on
      // mobile networks.
      let lcpHostImage = context.config.podcast?.hosts?.first(where: { $0.image != nil })?.image

      let homePath = context.router.homePath()
      let head = helper.buildHead(
         title: pageTitle,
         description: context.config.description,
         canonicalURL: context.config.baseURL + homePath,
         ogType: "website",
         rssFeedURL: feedPath,
         rssFeedTitle: context.config.name,
         preloadImageURL: lcpHostImage
      )

      // Hero section with optional host previews
      var heroParts: [String] = [
         "<h1 class=\"sk-home-title\">\(title.htmlEscaped)</h1>",
      ]

      if let subtitle = homeConfig?.subtitle {
         heroParts.append("<p class=\"sk-home-subtitle\">\(subtitle.htmlEscaped)</p>")
      }

      // Host previews from config. The first host image carries fetchpriority="high"
      // – it's the LCP candidate and matches the <link rel="preload"> emitted in <head>.
      if let hosts = context.config.podcast?.hosts, !hosts.isEmpty {
         var hostHTML: [String] = ["<div class=\"host-previews\">"]
         var lcpAssigned = false
         for host in hosts {
            hostHTML.append("<div class=\"host-preview\">")
            if let image = host.image {
               let priorityAttr = (!lcpAssigned && image == lcpHostImage) ? " fetchpriority=\"high\"" : ""
               if !lcpAssigned && image == lcpHostImage { lcpAssigned = true }
               hostHTML.append("<img src=\"\(image)\" alt=\"\(host.name.htmlEscaped)\" width=\"64\" height=\"64\"\(priorityAttr)/>")
            }
            hostHTML.append("<span class=\"host-preview-name\">\(host.name.htmlEscaped)</span>")
            hostHTML.append("</div>")
         }
         hostHTML.append("</div>")
         heroParts.append(hostHTML.joined())
      }

      // Subscribe / listen links
      if let subscribeLinks = context.config.podcast?.subscribeLinks, !subscribeLinks.isEmpty {
         let subscribeLabel = context.uiStrings.string(for: .podcastSubscribeLabel)
         var subscribeParts: [String] = [
            "<div class=\"podcast-subscribe\">",
            "<div class=\"podcast-subscribe-label\">\(subscribeLabel.htmlEscaped)</div>",
         ]
         let baseURL = context.config.baseURL
         let rssFeedURL = "\(baseURL)\(feedPath)"

         for link in subscribeLinks {
            let platform = link.platform.lowercased()
            let iconClass: String
            let defaultLabel: String
            let shortLabel: String

            switch platform {
            case "apple":
               iconClass = "fa-brands fa-apple"
               defaultLabel = "Apple Podcasts"
               shortLabel = "Podcasts"
            case "spotify":
               iconClass = "fa-brands fa-spotify"
               defaultLabel = "Spotify"
               shortLabel = "Spotify"
            case "overcast":
               iconClass = "fa-solid fa-podcast"
               defaultLabel = "Overcast"
               shortLabel = "Overcast"
            case "pocketcasts":
               iconClass = "fa-solid fa-podcast"
               defaultLabel = "Pocket Casts"
               shortLabel = "Pocket"
            case "rss":
               iconClass = "fa-solid fa-rss"
               defaultLabel = "RSS-Feed"
               shortLabel = "RSS"
            default:
               iconClass = "fa-solid fa-link"
               defaultLabel = link.platform
               shortLabel = link.platform
            }

            let displayLabel = link.label ?? defaultLabel
            let labelSpans =
               "<span class=\"podcast-subscribe-label-full\">\(displayLabel.htmlEscaped)</span>"
               + "<span class=\"podcast-subscribe-label-short\">\(shortLabel.htmlEscaped)</span>"

            if platform == "rss" {
               let escapedURL = rssFeedURL
                  .replacing("'", with: "\\'")
                  .replacing("\"", with: "&quot;")
               subscribeParts.append(
                  "<button class=\"podcast-subscribe-link podcast-subscribe-rss\""
                  + " onclick=\"navigator.clipboard.writeText('\(escapedURL)');"
                  + "this.querySelectorAll('span').forEach(s=>s.textContent='Kopiert!');"
                  + "setTimeout(()=>{this.querySelector('.podcast-subscribe-label-full').textContent='\(defaultLabel)';"
                  + "this.querySelector('.podcast-subscribe-label-short').textContent='\(shortLabel)';},2000)\""
                  + " title=\"RSS-Feed-URL kopieren\">"
                  + "<i class=\"\(iconClass)\"></i>"
                  + labelSpans
                  + "</button>"
               )
            } else {
               subscribeParts.append(
                  "<a class=\"podcast-subscribe-link podcast-subscribe-\(platform)\""
                  + " href=\"\(link.url)\" target=\"_blank\" rel=\"noopener\">"
                  + "<i class=\"\(iconClass)\"></i>"
                  + labelSpans
                  + "</a>"
               )
            }
         }

         subscribeParts.append("</div>")
         heroParts.append(subscribeParts.joined())
      }

      var mainParts: [String] = [
         "<section class=\"sk-home-hero\">\(heroParts.joined())</section>",
      ]

      // Episode list (same card style as listing page)
      let pages = section.pages
         .sortedByDate()
         .filter { (page: PageModel) -> Bool in
            let num: Int? = page.extensionValue("episode")
            return num != 0
         }
      let recentCount = homeConfig?.recentPostsCount ?? 10
      let recentPages = Array(pages.prefix(recentCount))
      let tagNames = context.config.tagDisplayNames ?? [:]

      if !recentPages.isEmpty {
         let latestLabel = context.uiStrings.string(for: .podcastLatestEpisodes)
         let viewAllLabel = context.uiStrings.string(for: .podcastViewAllEpisodes)

         var listParts: [String] = []
         listParts.append("<h2 class=\"sk-home-section-title\">\(latestLabel.htmlEscaped)</h2>")
         listParts.append("<ul class=\"episode-list\">")

         for page in recentPages {
            let episodeNumber: Int? = page.extensionValue("episode")
            let duration: String? = page.extensionValue("duration")
            let episodePath = context.router.pagePath(for: page, in: section.config)
            let strippedTitle = page.title.strippedEpisodePrefix

            var cardParts: [String] = []
            cardParts.append("<div class=\"episode-card\">")

            if let num = episodeNumber {
               cardParts.append("<span class=\"episode-card-number\">#\(num)</span>")
            }

            cardParts.append("<div class=\"episode-card-content\">")
            cardParts.append("<h2 class=\"episode-card-title\"><a class=\"episode-card-link\" href=\"\(episodePath)\">\(strippedTitle.htmlEscaped)</a></h2>")
            cardParts.append("<div class=\"episode-card-meta\"><time datetime=\"\(helper.isoDate(page.date))\">\(helper.formatDate(page.date).htmlEscaped)</time></div>")

            if let summary = page.summary, !summary.isEmpty {
               cardParts.append("<p class=\"episode-card-summary\">\(summary.htmlEscaped)</p>")
            }

            if !page.tags.isEmpty {
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

            listParts.append("<li>\(cardParts.joined())</li>")
         }

         listParts.append("</ul>")
         listParts.append("<p class=\"sk-home-all-posts\"><a href=\"\(context.router.blogListingPath())\">\(viewAllLabel.htmlEscaped) \u{2192}</a></p>")

         mainParts.append("<section class=\"sk-home-recent\">\(listParts.joined())</section>")
      }

      let mainContent = "<main class=\"sk-main\">\(mainParts.joined())</main>"

      return helper.renderPageShell(
         head: head,
         bodyClass: "sk-page-home",
         content: mainContent
      )
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let homePath = context.router.homePath()
      let relative = String(homePath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func marker() -> PageModel {
      PageModel(
         title: "",
         slug: "",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
