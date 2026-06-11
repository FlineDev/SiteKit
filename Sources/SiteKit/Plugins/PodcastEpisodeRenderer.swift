import Foundation

/// Renders individual podcast episode HTML pages with audio player, chapters, show notes,
/// and prev/next navigation.
///
/// Expects episode pages in a section with `slug == "podcast"`. Each page may have
/// these frontmatter extension fields:
/// - `episode` (Int): Episode number
/// - `duration` (String): Duration in `HH:MM:SS` format
/// - `audioURL` (String): URL to the MP3 file
/// - `chapters` ([[String: String]]): Array of `{"start": "HH:MM:SS", "title": "..."}`
public struct PodcastEpisodeRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return []
      }
      return section.pages.sortedByDate()
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return ""
      }
      let helper = OutputFileRenderer(context: context)
      let pages = section.pages.sortedByDate()
      let index = pages.firstIndex(where: { $0.slug == page.slug }) ?? 0
      let previousPage = index > 0 ? pages[index - 1] : nil
      let nextPage = index < pages.count - 1 ? pages[index + 1] : nil
      return self.renderEpisode(
         page: page,
         previousPage: previousPage,
         nextPage: nextPage,
         section: section.config,
         helper: helper,
         context: context
      )
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      let episodePath = context.router.pagePath(for: page, in: section.config)
      let relative = String(episodePath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private func renderEpisode(
      page: PageModel,
      previousPage: PageModel?,
      nextPage: PageModel?,
      section: SectionConfig,
      helper: OutputFileRenderer,
      context: BuildContext
   ) -> String {
      let episodeNumber: Int? = page.extensionValue("episode")
      let duration: String? = page.extensionValue("duration")
      let audioURL: String? = page.extensionValue("audioURL")

      let strippedTitle = page.title.strippedEpisodePrefix
      let pageTitle: String
      if let num = episodeNumber {
         pageTitle = "\(String(format: "%03d", num)) \u{2013} \(strippedTitle) \u{2014} \(context.config.name)"
      } else {
         pageTitle = "\(strippedTitle) \u{2014} \(context.config.name)"
      }

      let feedPath = context.config.podcast?.feedPath ?? "/podcast.xml"
      let artworkPath = context.config.podcast?.artworkPath ?? "/assets/artwork.jpg"
      let episodePath = context.router.pagePath(for: page, in: section)
      let canonicalURL = "\(context.config.baseURL)\(episodePath)"

      let head = helper.buildHead(
         title: pageTitle,
         description: page.summary,
         canonicalURL: canonicalURL,
         ogType: "article",
         rssFeedURL: feedPath,
         rssFeedTitle: context.config.name,
         articleDate: page.date
      )

      var contentParts: [String] = []

      // Player block: hero + chapters as one connected unit
      let chapters = self.parseChapters(from: page)
      contentParts.append("<div class=\"episode-player-block\">")

      // Episode hero box
      contentParts.append("<div class=\"episode-hero\">")

      // Top row: artwork | content
      contentParts.append("<div class=\"episode-hero-top\">")
      contentParts.append("<img class=\"episode-hero-artwork\" src=\"\(artworkPath)\" alt=\"\(context.config.name.htmlEscaped)\" width=\"120\" height=\"120\" />")
      contentParts.append("<div class=\"episode-hero-content\">")

      if let num = episodeNumber {
         contentParts.append("<span class=\"episode-number\">Episode \(num)</span>")
      }

      contentParts.append("<h1 class=\"episode-title\">\(strippedTitle.htmlEscaped)</h1>")

      // Meta row: date on left, download on right
      contentParts.append("<div class=\"episode-hero-meta-row\">")
      var metaText = "<time datetime=\"\(helper.isoDate(page.date))\">\(helper.formatDate(page.date).htmlEscaped)</time>"
      if let duration {
         metaText += " \u{00B7} \(duration.formattedDuration.htmlEscaped)"
      }
      contentParts.append("<div class=\"episode-meta\">\(metaText)</div>")
      if let audioURL {
         let downloadLabel = context.uiStrings.string(for: .podcastDownloadMP3)
         contentParts.append("<a class=\"episode-download\" href=\"\(audioURL.htmlEscaped)\" download>\(downloadLabel.htmlEscaped)</a>")
      }
      contentParts.append("</div>")

      contentParts.append("</div>") // close episode-hero-content
      contentParts.append("</div>") // close episode-hero-top

      // Full-width elements below the top row
      if let summary = page.summary, !summary.isEmpty {
         contentParts.append("<p class=\"episode-summary\">\(summary.htmlEscaped)</p>")
      }

      if let audioURL {
         let downloadLabel = context.uiStrings.string(for: .podcastDownloadMP3)
         contentParts.append("<audio controls preload=\"none\" src=\"\(audioURL.htmlEscaped)\">")
         contentParts.append("<a href=\"\(audioURL.htmlEscaped)\">\(downloadLabel.htmlEscaped)</a>")
         contentParts.append("</audio>")
      }

      contentParts.append("</div>") // close episode-hero

      // Chapters (connected to hero)
      if !chapters.isEmpty {
         let chaptersLabel = context.uiStrings.string(for: .podcastChapters)
         contentParts.append("<section class=\"episode-chapters\">")
         contentParts.append("<h2>\(chaptersLabel.htmlEscaped)</h2>")
         contentParts.append("<div class=\"chapters-grid\">")
         for chapter in chapters {
            let seconds = self.timeToSeconds(chapter.start)
            contentParts.append("<button class=\"chapter-item\" data-time=\"\(seconds)\" type=\"button\">")
            contentParts.append("<span class=\"chapter-time\">\(chapter.start.htmlEscaped)</span>")
            contentParts.append("<span class=\"chapter-title\">\(chapter.title.htmlEscaped)</span>")
            contentParts.append("</button>")
         }
         contentParts.append("</div>")
         contentParts.append("</section>")
      }

      contentParts.append("</div>") // close episode-player-block

      // Show notes
      if !page.htmlContent.isEmpty {
         let showNotesLabel = context.uiStrings.string(for: .podcastShowNotes)
         contentParts.append("<section class=\"episode-shownotes\">")
         contentParts.append("<h2>\(showNotesLabel.htmlEscaped)</h2>")
         contentParts.append("<div class=\"shownotes-body\">\(page.htmlContent)</div>")
         contentParts.append("</section>")
      }

      // Prev/next navigation
      if previousPage != nil || nextPage != nil {
         contentParts.append("<nav class=\"episode-nav\">")

         if let prev = previousPage {
            let prevPath = context.router.pagePath(for: prev, in: section)
            let prevNum: Int? = prev.extensionValue("episode")
            let prevLabel: String
            if let num = prevNum {
               prevLabel = "\u{2190} Episode \(num)"
            } else {
               prevLabel = "\u{2190} \(context.uiStrings.string(for: .podcastPreviousEpisode))"
            }
            contentParts.append("<a class=\"episode-nav-prev\" href=\"\(prevPath)\"><span class=\"episode-nav-label\">\(prevLabel.htmlEscaped)</span><span class=\"episode-nav-title\">\(prev.title.strippedEpisodePrefix.htmlEscaped)</span></a>")
         } else {
            contentParts.append("<div class=\"episode-nav-prev episode-nav-empty\"></div>")
         }

         if let next = nextPage {
            let nextPath = context.router.pagePath(for: next, in: section)
            let nextNum: Int? = next.extensionValue("episode")
            let nextLabel: String
            if let num = nextNum {
               nextLabel = "Episode \(num) \u{2192}"
            } else {
               nextLabel = "\(context.uiStrings.string(for: .podcastNextEpisode)) \u{2192}"
            }
            contentParts.append("<a class=\"episode-nav-next\" href=\"\(nextPath)\"><span class=\"episode-nav-label\">\(nextLabel.htmlEscaped)</span><span class=\"episode-nav-title\">\(next.title.strippedEpisodePrefix.htmlEscaped)</span></a>")
         } else {
            contentParts.append("<div class=\"episode-nav-next episode-nav-empty\"></div>")
         }

         contentParts.append("</nav>")
      }

      // Back link
      let listingPath = context.router.sectionListingPath(for: section)
      let allEpisodesLabel = context.uiStrings.string(for: .podcastAllEpisodes)
      contentParts.append("<p class=\"episode-back-link\"><a href=\"\(listingPath)\">\u{2190} \(allEpisodesLabel.htmlEscaped)</a></p>")

      let mainContent = "<main class=\"sk-main\"><article class=\"episode-detail\">\(contentParts.joined())</article></main>"

      return helper.renderPageShell(
         head: head,
         bodyClass: "sk-page-article sk-section-podcast",
         content: mainContent
      )
   }

   private func parseChapters(from page: PageModel) -> [(start: String, title: String)] {
      guard let rawChapters: [[String: String]] = page.extensionValue("chapters") else {
         return []
      }

      var result: [(start: String, title: String)] = []
      for dict in rawChapters {
         guard let start = dict["start"],
               let title = dict["title"]
         else { continue }
         result.append((start: start, title: title))
      }
      return result
   }

   private func timeToSeconds(_ time: String) -> Int {
      let parts = time.split(separator: ":").compactMap { Int($0) }
      guard parts.count == 3 else { return 0 }
      return parts[0] * 3600 + parts[1] * 60 + parts[2]
   }
}

// MARK: - Private String Helpers

extension String {
   /// Strips a leading episode number prefix like "042 – " or "15 – " from titles.
   var strippedEpisodePrefix: String {
      self.replacing(#/^\d{2,3}\s*[––\-]\s*/#, with: "")
   }

   /// Formats an `HH:MM:SS` duration string into a compact `02h 15m` display format.
   var formattedDuration: String {
      let parts = self.split(separator: ":").compactMap { Int($0) }
      guard parts.count == 3 else { return self }
      return String(format: "%02dh %02dm", parts[0], parts[1])
   }
}
