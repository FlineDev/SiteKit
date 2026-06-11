import Foundation

/// Whether a `PageModel` represents a blog-style article (under a section's
/// URL prefix) or a top-level static page (under the site root).
///
/// `Page.outputURL(for:context:)` dispatches by this value, so adding a new
/// kind of page means adding a case here AND extending the router.
public enum PageType: String, Codable, Sendable {
   /// Section content (blog post, podcast episode, note) routed under the
   /// section's URL prefix, e.g. `/blog/<slug>/`.
   case article
   /// Top-level page (about, privacy, …) routed directly under the site root,
   /// e.g. `/<slug>/`.
   case staticPage
}

/// One renderable piece of content – the result of loading + enriching a
/// single source file.
///
/// `PageModel` is the universal intermediate that flows from `Loader` through
/// `Enricher` chains to `Page`/`Renderer` consumers. Every Markdown article,
/// every static page, every podcast episode page is a `PageModel`; the
/// `pageType` and `extensions` fields carry kind-specific data without
/// fragmenting into many model types. `extensions` is a typed-key dictionary
/// (`extensionValue(_:)`) so enrichers can attach computed fields
/// (`readingTime`, `hreflang`, promotion slots) without modifying the public
/// signature.
public struct PageModel {
   /// Stable identity from `id:` frontmatter, kept identical across a page's
   /// translations to link them together. The build warns when it is missing;
   /// core renderers only pass it through.
   public let id: String?

   /// Page title from `title:` frontmatter – required on every page.
   public let title: String

   /// Publication date from `date:` frontmatter. Articles require it (it drives
   /// `sortedByDate()` and RSS); static pages may omit it.
   public let date: Date?

   /// URL path segment identifying this page, from `slug:` frontmatter or
   /// derived from the filename. On translated files the locale suffix is
   /// already stripped (`my-post.de` → `my-post`).
   public let slug: String

   /// The Markdown body rendered to HTML – everything below the frontmatter.
   public let htmlContent: String

   /// Absolute file URL of the source file this model was loaded from. Used in
   /// build diagnostics and translation-status reporting.
   public let sourcePath: URL

   /// Single category from `category:` frontmatter; empty string when none.
   /// Drives the per-category listing pages on blog sites.
   public let category: String

   /// Tags from `tags:` frontmatter; empty when none. Drive the `/tags/<slug>/`
   /// listing pages and feed into the machine-readable indexes.
   public let tags: [String]

   /// Short teaser from `summary:` frontmatter. Takes precedence over
   /// `description` for the meta description and social-card text.
   public let summary: String?

   /// Meta description from `description:` frontmatter – the fallback when
   /// `summary` is absent.
   public let description: String?

   /// Author from `author:` frontmatter; nil for site-attributed pages.
   public let author: Person?

   /// Path or URL of the page's primary image from `image:` frontmatter. Feeds
   /// the OG/Twitter card, the LCP preload, and responsive variant generation.
   public let image: String?

   /// Alt text for `image` from `imageAlt:` frontmatter – the accessibility
   /// contract for the primary image (include `imageAlt` in a loader's
   /// `requiredFields` to fail the build when missing).
   public let imageAlt: String?

   /// Draft flag from `draft:` frontmatter. Draft pages are excluded from the
   /// published site and only surfaced via `BuildContext.draftPages` (e.g. for
   /// the draft-preview output).
   public let draft: Bool

   /// Whether this page routes like section content (`.article`) or a top-level
   /// static page (`.staticPage`).
   public let pageType: PageType

   /// BCP 47 code of the locale this model was built for (e.g. `"en"`, `"de"`).
   public let locale: String

   /// For translated content: the language the original was written in, from
   /// `originalLanguage:` frontmatter. Drives the machine-translation notice on
   /// article pages; nil on untranslated content.
   public let originalLanguage: String?

   /// Marks a legally binding document (privacy policy, imprint) via
   /// `legalDocument:` frontmatter. Translated versions of such a page render a
   /// notice linking to the legally binding language version.
   public let legalDocument: Bool

   /// Untyped extension storage for enricher-attached computed fields
   /// (`sectionSlug`, `hreflang`, `promotion`, …). Read with
   /// `extensionValue(_:)`; replace the whole dictionary when enriching.
   public let extensions: [String: any Sendable]

   /// Memberwise initializer. `PageModel` is immutable, so enrichers construct a
   /// new instance, passing every existing field plus their changes (AGENTS.md §8
   /// shows the full-parameter-list pattern).
   public init(
      id: String? = nil,
      title: String,
      date: Date? = nil,
      slug: String,
      htmlContent: String,
      sourcePath: URL,
      category: String = "",
      tags: [String] = [],
      summary: String? = nil,
      description: String? = nil,
      author: Person? = nil,
      image: String? = nil,
      imageAlt: String? = nil,
      draft: Bool = false,
      pageType: PageType = .article,
      locale: String = "en",
      originalLanguage: String? = nil,
      legalDocument: Bool = false,
      extensions: [String: any Sendable] = [:]
   ) {
      self.id = id
      self.title = title
      self.date = date
      self.slug = slug
      self.htmlContent = htmlContent
      self.sourcePath = sourcePath
      self.category = category
      self.tags = tags
      self.summary = summary
      self.description = description
      self.author = author
      self.image = image
      self.imageAlt = imageAlt
      self.draft = draft
      self.pageType = pageType
      self.locale = locale
      self.originalLanguage = originalLanguage
      self.legalDocument = legalDocument
      self.extensions = extensions
   }

   /// Retrieve a typed value from the extensions dictionary.
   public func extensionValue<T>(_ key: String) -> T? {
      self.extensions[key] as? T
   }

   /// Estimated reading time in minutes, never below 1. Counts prose at
   /// 238 words/min and code-block content at 100 words/min, and adds
   /// per-image seconds (12s each for the first 10 images, 3s after).
   public var readTimeMinutes: Int {
      let html = self.htmlContent

      // Extract code block content separately (reduced reading rate)
      var codeText = ""
      var proseHTML = html
      let codePattern = /<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/
      while let match = proseHTML.firstMatch(of: codePattern) {
         codeText += " " + String(match.output.1)
         proseHTML.replaceSubrange(match.range, with: "")
      }

      // Count images
      let imageCount = proseHTML.matches(of: /<img\s/).count

      // Strip HTML tags for prose word count
      let proseText = proseHTML.replacing(/<[^>]+>/, with: " ")
      let proseWords = proseText.split(whereSeparator: { $0.isWhitespace }).count

      // Code word count (at reduced rate)
      let codeWords = codeText.split(whereSeparator: { $0.isWhitespace }).count

      // Calculate time: 238 wpm prose, 100 wpm code
      let proseSeconds = Double(proseWords) / 238.0 * 60.0
      let codeSeconds = Double(codeWords) / 100.0 * 60.0

      // Images: 12s each for first 10, 3s after
      let imageSeconds = Double(min(imageCount, 10)) * 12.0 + Double(max(imageCount - 10, 0)) * 3.0

      let totalMinutes = (proseSeconds + codeSeconds + imageSeconds) / 60.0
      return max(1, Int(totalMinutes.rounded()))
   }
}

extension Array where Element == PageModel {
   /// Sorts pages by date descending (newest first), with slug as secondary key for same-date pages.
   public func sortedByDate() -> [PageModel] {
      self.sorted { lhs, rhs in
         let lhsDate = lhs.date ?? .distantPast
         let rhsDate = rhs.date ?? .distantPast
         if lhsDate != rhsDate {
            return lhsDate > rhsDate
         }
         // Same date: reverse slug order (later alphabetically = first)
         return lhs.slug > rhs.slug
      }
   }
}
