import Foundation

/// Intermediate data for RSS feed generation – one value per emitted feed.
/// `RSSFeedRenderer` shapes the site's page sets (site-wide feed plus
/// per-section and per-category feeds) into `FeedData` before serializing XML.
public struct FeedData {
   /// Channel title, e.g. the site or section name.
   public let title: String

   /// Channel description shown by feed readers.
   public let description: String

   /// Absolute URL of the site (or section listing) this feed belongs to.
   public let siteURL: String

   /// Absolute URL where this feed itself is served – becomes the
   /// `atom:link rel="self"` element.
   public let feedURL: String

   /// BCP 47 language code of the feed content, e.g. `"en"`.
   public let language: String

   /// The feed entries, expected newest first.
   public let items: [FeedItem]

   /// Relative output path (e.g. "feed.xml" or "developer/feed.xml")
   public let outputRelativePath: String

   /// Memberwise initializer.
   public init(
      title: String,
      description: String,
      siteURL: String,
      feedURL: String,
      language: String,
      items: [FeedItem],
      outputRelativePath: String
   ) {
      self.title = title
      self.description = description
      self.siteURL = siteURL
      self.feedURL = feedURL
      self.language = language
      self.items = items
      self.outputRelativePath = outputRelativePath
   }
}

/// One entry in a generated feed – the feed-side projection of a `PageModel`.
public struct FeedItem {
   /// Entry title.
   public let title: String

   /// Absolute URL of the page this entry links to.
   public let url: String

   /// Publication date; entries without one omit `<pubDate>`.
   public let date: Date?

   /// Plain-text teaser for the entry's `<description>`.
   public let summary: String

   /// Full rendered HTML body, emitted as `<content:encoded>` so readers can
   /// show the complete article.
   public let htmlContent: String

   /// Entry author; nil for site-attributed content.
   public let author: Person?
   /// Absolute URL of the article's hero image, if any. Used by RSS readers to render
   /// a list thumbnail (via `<media:thumbnail>`) without having to parse `htmlContent`.
   public let imageURL: String?

   /// Alt text for `imageURL`.
   public let imageAlt: String?

   /// Memberwise initializer.
   public init(
      title: String,
      url: String,
      date: Date?,
      summary: String,
      htmlContent: String,
      author: Person? = nil,
      imageURL: String? = nil,
      imageAlt: String? = nil
   ) {
      self.title = title
      self.url = url
      self.date = date
      self.summary = summary
      self.htmlContent = htmlContent
      self.author = author
      self.imageURL = imageURL
      self.imageAlt = imageAlt
   }
}
