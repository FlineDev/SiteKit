import Foundation

/// Generates a podcast RSS 2.0 feed with iTunes, Podlove, and Podcast Index namespace support.
///
/// Reads podcast configuration from `config.podcast` and episode data from the `"podcast"` section.
/// Supports legacy feed paths for URL migration.
///
/// Each episode page may have these frontmatter extension fields:
/// - `episode` (Int): Episode number
/// - `duration` (String): Duration in `HH:MM:SS` format
/// - `audioURL` (String): URL to the MP3 file
/// - `audioSize` (Int): File size in bytes
/// - `guid` (String): Persistent unique identifier (falls back to episode URL)
/// - `episodeType` (String): iTunes episode type (defaults to `"full"`)
/// - `chapters` ([[String: Any]]): Array of `{"start": "HH:MM:SS", "title": "..."}`
public struct PodcastRSSRenderer: Renderer {
   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard let section = context.sections.first(where: { $0.config.slug == "podcast" }) else {
         return []
      }

      let pages = section.pages.sortedByDate()
      let xml = self.buildPodcastRSS(pages: pages, section: section.config, context: context)

      let feedPath = context.config.podcast?.feedPath ?? "/podcast.xml"
      let feedRelativePath = feedPath.hasPrefix("/") ? String(feedPath.dropFirst()) : feedPath

      var files: [OutputFile] = []

      // Main feed
      let mainFeed = OutputFile(
         outputPath: context.outputDirectory.appendingPathComponent(feedRelativePath),
         content: xml
      )
      files.append(mainFeed)

      // Legacy feed paths
      if let legacyPaths = context.config.podcast?.legacyFeedPaths {
         for legacyPath in legacyPaths {
            let relativePath = legacyPath.hasPrefix("/") ? String(legacyPath.dropFirst()) : legacyPath
            let legacyFeed = OutputFile(
               outputPath: context.outputDirectory.appendingPathComponent(relativePath),
               content: xml
            )
            files.append(legacyFeed)
         }
      }

      return files
   }

   private func buildPodcastRSS(pages: [PageModel], section: SectionConfig, context: BuildContext) -> String {
      let config = context.config
      let podcastConfig = config.podcast
      let feedPath = podcastConfig?.feedPath ?? "/podcast.xml"
      let feedURL = "\(config.baseURL)\(feedPath)"
      let siteURL = config.baseURL
      let authorName = config.author?.name ?? ""
      let authorEmail = config.author?.email ?? ""
      let artworkPath = podcastConfig?.artworkPath ?? "/assets/artwork.jpg"
      let itunesCategory = podcastConfig?.itunesCategory ?? "Technology"
      let itunesExplicit = (podcastConfig?.explicit ?? false) ? "true" : "false"
      let itunesType = podcastConfig?.itunesType ?? "episodic"

      let categoryXML: String
      if let subcategory = podcastConfig?.itunesSubcategory {
         categoryXML = "<itunes:category text=\"\(itunesCategory.xmlEscaped)\">\n<itunes:category text=\"\(subcategory.xmlEscaped)\"/>\n</itunes:category>"
      } else {
         categoryXML = "<itunes:category text=\"\(itunesCategory.xmlEscaped)\"/>"
      }

      var xml = """
         <?xml version="1.0" encoding="UTF-8"?>
         <rss version="2.0"
            xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
            xmlns:atom="http://www.w3.org/2005/Atom"
            xmlns:psc="http://podlove.org/simple-chapters"
            xmlns:content="http://purl.org/rss/1.0/modules/content/"
            xmlns:podcast="https://podcastindex.org/namespace/1.0">
         <channel>
         <title>\(config.name.xmlEscaped)</title>
         <description>\(config.description.xmlEscaped)</description>
         <link>\(siteURL.xmlEscaped)</link>
         <language>\(config.language.xmlEscaped)</language>
         <copyright>\(config.footer?.copyrightName ?? config.name)</copyright>
         <atom:link href="\(feedURL.xmlEscaped)" rel="self" type="application/rss+xml"/>
         <itunes:author>\(authorName.xmlEscaped)</itunes:author>
         <itunes:summary>\(config.description.xmlEscaped)</itunes:summary>
         \(categoryXML)
         <itunes:type>\(itunesType)</itunes:type>
         <itunes:explicit>\(itunesExplicit)</itunes:explicit>
         <lastBuildDate>\(Self.rfc2822String(Date()))</lastBuildDate>
         <itunes:image href="\(siteURL)\(artworkPath)"/>
         <itunes:owner>
         <itunes:name>\(authorName.xmlEscaped)</itunes:name>
         <itunes:email>\(authorEmail.xmlEscaped)</itunes:email>
         </itunes:owner>
         """

      // Channel-level podcast:guid
      if let podcastGuid = podcastConfig?.podcastGuid {
         xml += "\n<podcast:guid>\(podcastGuid.xmlEscaped)</podcast:guid>"
      }

      // Channel-level podcast:person for hosts
      if let hosts = podcastConfig?.hosts {
         for host in hosts {
            xml += "\n" + Self.podcastPersonTag(name: host.name, role: host.role ?? "host", image: host.image, href: host.href)
         }
      }

      for page in pages {
         xml += self.buildItem(page: page, section: section, context: context)
      }

      xml += "\n</channel>\n</rss>"
      return xml
   }

   private func buildItem(page: PageModel, section: SectionConfig, context: BuildContext) -> String {
      let episodePath = context.router.pagePath(for: page, in: section)
      let episodeURL = "\(context.config.baseURL)\(episodePath)"

      let episodeNumber: Int? = page.extensionValue("episode")
      let duration: String? = page.extensionValue("duration")
      let audioURL: String? = page.extensionValue("audioURL")
      let audioSize: Int? = page.extensionValue("audioSize")
      let guid: String? = page.extensionValue("guid")
      let episodeType: String? = page.extensionValue("episodeType")

      var item = "\n<item>"
      item += "\n<title>\(page.title.xmlEscaped)</title>"
      item += "\n<link>\(episodeURL.xmlEscaped)</link>"
      item += "\n<pubDate>\(Self.rfc2822String(page.date))</pubDate>"

      if let guid {
         item += "\n<guid isPermaLink=\"false\">\(guid.xmlEscaped)</guid>"
      } else {
         item += "\n<guid isPermaLink=\"true\">\(episodeURL.xmlEscaped)</guid>"
      }

      if let audioURL {
         let sizeStr = audioSize.map { String($0) } ?? "0"
         item += "\n<enclosure url=\"\(audioURL.xmlEscaped)\" length=\"\(sizeStr)\" type=\"audio/mpeg\"/>"
      }

      if let duration {
         item += "\n<itunes:duration>\(duration.xmlEscaped)</itunes:duration>"
      }

      if let episodeNumber {
         item += "\n<itunes:episode>\(episodeNumber)</itunes:episode>"
      }

      item += "\n<itunes:episodeType>\((episodeType ?? "full").xmlEscaped)</itunes:episodeType>"
      item += "\n<itunes:author>\(context.config.author?.name.xmlEscaped ?? "")</itunes:author>"

      if let summary = page.summary {
         item += "\n<itunes:summary>\(summary.xmlEscaped)</itunes:summary>"
         item += "\n<description><![CDATA[\(summary)]]></description>"
      }

      item += "\n<content:encoded><![CDATA[\(page.htmlContent)]]></content:encoded>"

      // Per-episode podcast:person – hosts from config + guests from frontmatter
      if let hosts = context.config.podcast?.hosts {
         for host in hosts {
            item += "\n" + Self.podcastPersonTag(name: host.name, role: host.role ?? "host", image: host.image, href: host.href)
         }
      }

      let guests = self.parseGuests(from: page)
      for guest in guests {
         item += "\n" + Self.podcastPersonTag(name: guest.name, role: guest.role ?? "guest", image: guest.image, href: guest.href)
      }

      // Chapters
      let chapters = self.parseChapters(from: page)
      if !chapters.isEmpty {
         item += "\n<psc:chapters version=\"1.2\">"
         for chapter in chapters {
            item += "\n<psc:chapter start=\"\(chapter.start.xmlEscaped)\" title=\"\(chapter.title.xmlEscaped)\"/>"
         }
         item += "\n</psc:chapters>"
      }

      item += "\n</item>"
      return item
   }

   private func parseChapters(from page: PageModel) -> [(start: String, title: String)] {
      guard let rawChapters: [Any] = page.extensionValue("chapters") else {
         return []
      }

      var result: [(start: String, title: String)] = []
      for element in rawChapters {
         guard let dict = element as? [String: Any],
               let start = dict["start"] as? String,
               let title = dict["title"] as? String
         else { continue }
         result.append((start: start, title: title))
      }
      return result
   }

   // MARK: - Guests

   private func parseGuests(from page: PageModel) -> [(name: String, role: String?, image: String?, href: String?)] {
      guard let rawGuests: [Any] = page.extensionValue("guests") else { return [] }

      var result: [(name: String, role: String?, image: String?, href: String?)] = []
      for element in rawGuests {
         guard let dict = element as? [String: Any],
               let name = dict["name"] as? String
         else { continue }
         result.append((
            name: name,
            role: dict["role"] as? String,
            image: dict["image"] as? String,
            href: dict["href"] as? String
         ))
      }
      return result
   }

   // MARK: - Podcast Person

   /// Builds a `<podcast:person>` tag with optional role, img, and href attributes.
   private static func podcastPersonTag(name: String, role: String, image: String? = nil, href: String? = nil) -> String {
      var attrs = " role=\"\(role.xmlEscaped)\""
      if let image { attrs += " img=\"\(image.xmlEscaped)\"" }
      if let href { attrs += " href=\"\(href.xmlEscaped)\"" }
      return "<podcast:person\(attrs)>\(name.xmlEscaped)</podcast:person>"
   }

   // MARK: - Date Formatting

   private static let rfc2822Formatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      return formatter
   }()

   private static func rfc2822String(_ date: Date?) -> String {
      guard let date else { return "" }
      return self.rfc2822Formatter.string(from: date)
   }
}
