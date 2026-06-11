import Foundation

/// Generates RSS 2.0 feed files for all configured sections.
///
/// Uses a lightweight custom XML builder – no Plot dependency – so podcast namespaces
/// and other RSS extensions can be added cleanly in future renderers.
///
/// Add to SiteBuilder via `.renderer(RSSFeedRenderer())` or it's included in `.defaultBlogRenderers()`.
public struct RSSFeedRenderer: Renderer {
   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let feeds = try DefaultFeedDataAdapter().adapt(context)
      return feeds.map { feed in
         let xml = Self.buildRSS(feed: feed)
         let outputPath = context.outputDirectory.appendingPathComponent(feed.outputRelativePath)
         return OutputFile(outputPath: outputPath, content: xml)
      }
   }

   internal static func buildRSS(feed: FeedData) -> String {
      let rfc822Formatter = DateFormatter()
      rfc822Formatter.locale = Locale(identifier: "en_US_POSIX")
      rfc822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
      rfc822Formatter.timeZone = TimeZone(secondsFromGMT: 0)

      var xml = """
         <?xml version="1.0" encoding="UTF-8"?>
         <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:media="http://search.yahoo.com/mrss/">
         <channel>
         <title>\(xmlEscape(feed.title))</title>
         <description>\(xmlEscape(feed.description))</description>
         <link>\(xmlEscape(feed.siteURL))</link>
         <language>\(xmlEscape(feed.language))</language>
         <atom:link href="\(xmlEscape(feed.feedURL))" rel="self" type="application/rss+xml"/>
         """

      for item in feed.items {
         xml += "\n<item>"
         xml += "\n<title>\(xmlEscape(item.title))</title>"
         xml += "\n<link>\(xmlEscape(item.url))</link>"
         xml += "\n<guid isPermaLink=\"true\">\(xmlEscape(item.url))</guid>"
         if let date = item.date {
            xml += "\n<pubDate>\(rfc822Formatter.string(from: date))</pubDate>"
         }
         if let author = item.author {
            xml += "\n<author>\(xmlEscape(author.name))</author>"
         }
         xml += "\n<description><![CDATA[\(item.summary)]]></description>"
         xml += "\n<content:encoded><![CDATA[\(item.htmlContent)]]></content:encoded>"
         if let imageURL = item.imageURL {
            xml += "\n<media:thumbnail url=\"\(xmlEscape(imageURL))\"/>"
         }
         xml += "\n</item>"
      }

      xml += "\n</channel>\n</rss>"
      return xml
   }

   private static func xmlEscape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
         .replacing("'", with: "&apos;")
   }

   /// Absolutize all root-relative `<img src="...">` and `<a href="...">` URLs in an HTML
   /// fragment against the given site baseURL. Leaves already-absolute URLs (`http://`,
   /// `https://`, `//`), data URIs, mailto: links, and in-page anchors (`#foo`) untouched.
   /// Exposed at internal access for testing.
   internal static func absolutizeHTMLURLs(in html: String, baseURL: String) -> String {
      var output = html
      for attribute in ["src", "href"] {
         output = output.replacing(
            try! Regex(#"(\#(attribute))=(['"])(/[^'"]*)\2"#),
            with: { match in
               let attr = match.output[1].substring ?? ""
               let quote = match.output[2].substring ?? "\""
               let path = match.output[3].substring ?? ""
               return "\(attr)=\(quote)\(Self.absolutize(url: String(path), baseURL: baseURL))\(quote)"
            }
         )
      }
      return output
   }

   /// Resolve a single URL against the site's baseURL. Pass-through for absolute URLs,
   /// protocol-relative (`//`) URLs, data URIs, mailto: links, and anchors.
   internal static func absolutize(url: String, baseURL: String) -> String {
      if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
      if url.hasPrefix("//") { return url }
      if url.hasPrefix("data:") || url.hasPrefix("mailto:") || url.hasPrefix("tel:") { return url }
      if url.hasPrefix("#") { return url }
      let trimmedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
      if url.hasPrefix("/") { return trimmedBase + url }
      return trimmedBase + "/" + url
   }
}

fileprivate struct DefaultFeedDataAdapter {
   func adapt(_ context: BuildContext) throws -> [FeedData] {
      let config = context.config
      let router = context.router
      var feeds: [FeedData] = []

      // Derive locale-aware prefix from router's home path
      let homePrefix = String(router.homePath().dropFirst()) // "de/" or ""
      let feedLanguage = context.uiStrings.locale

      // Main feed (all sections combined)
      let allPages = context.sections.flatMap(\.pages)
         .sortedByDate()
      feeds.append(
         FeedData(
            title: config.name,
            description: config.description,
            siteURL: "\(config.baseURL)\(router.homePath())",
            feedURL: "\(config.baseURL)/\(homePrefix)feed.xml",
            language: feedLanguage,
            items: allPages.map { self.feedItem(for: $0, config: config, router: router, sections: context.sections) },
            outputRelativePath: "\(homePrefix)feed.xml"
         )
      )

      // Per-section feeds
      for section in context.sections {
         let sorted = section.pages.sortedByDate()
         guard !sorted.isEmpty else { continue }
         let sectionPath = router.sectionListingPath(for: section.config)
         feeds.append(
            FeedData(
               title: "\(section.config.name) – \(config.name)",
               description: config.description,
               siteURL: "\(config.baseURL)\(sectionPath)",
               feedURL: "\(config.baseURL)/\(homePrefix)\(section.config.urlPrefix)/feed.xml",
               language: feedLanguage,
               items: sorted.map { self.feedItem(for: $0, config: config, router: router, section: section.config) },
               outputRelativePath: "\(homePrefix)\(section.config.urlPrefix)/feed.xml"
            )
         )

         // Per-category feeds (if section has categories)
         if let categories = section.config.categories {
            let pagesByCategory = Dictionary(grouping: section.pages) { $0.category }
            for categoryConfig in categories {
               let categoryPages = pagesByCategory[categoryConfig.slug] ?? []
               if !categoryPages.isEmpty {
                  let catSorted = categoryPages.sortedByDate()
                  let catPath = router.categoryPath(for: categoryConfig)
                  feeds.append(
                     FeedData(
                        title: "\(categoryConfig.name) – \(config.name)",
                        description: categoryConfig.description ?? config.description,
                        siteURL: "\(config.baseURL)\(catPath)",
                        feedURL: "\(config.baseURL)\(catPath)feed.xml",
                        language: feedLanguage,
                        items: catSorted.map { self.feedItem(for: $0, config: config, router: router, section: section.config) },
                        outputRelativePath: "\(homePrefix)\(categoryConfig.slug)/feed.xml"
                     )
                  )
               }
            }
         }
      }

      return feeds
   }

   private func feedItem(for page: PageModel, config: SiteConfig, router: any URLRouter, sections: [ContentSection] = [], section: SectionConfig? = nil) -> FeedItem {
      let articleURL: String
      if let section {
         articleURL = "\(config.baseURL)\(router.pagePath(for: page, in: section))"
      } else if let matchingSection = sections.first(where: { $0.pages.contains(where: { $0.slug == page.slug }) }) {
         articleURL = "\(config.baseURL)\(router.pagePath(for: page, in: matchingSection.config))"
      } else {
         articleURL = "\(config.baseURL)\(router.articlePath(for: page))"
      }

      let absoluteImageURL = page.image.map { RSSFeedRenderer.absolutize(url: $0, baseURL: config.baseURL) }

      var contentHTML = RSSFeedRenderer.absolutizeHTMLURLs(in: page.htmlContent, baseURL: config.baseURL)
      if let absoluteImageURL {
         let alt = (page.imageAlt ?? page.title)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
         contentHTML = "<p><img src=\"\(absoluteImageURL)\" alt=\"\(alt)\" /></p>" + contentHTML
      }

      return FeedItem(
         title: page.title,
         url: articleURL,
         date: page.date,
         summary: page.summary ?? "",
         htmlContent: contentHTML,
         author: page.author,
         imageURL: absoluteImageURL,
         imageAlt: page.imageAlt
      )
   }
}
