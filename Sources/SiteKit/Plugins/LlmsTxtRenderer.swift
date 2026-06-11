import Foundation
import Logging

/// Generates `/llms.txt` at the site root following the
/// [llmstxt.org](https://llmstxt.org) specification.
///
/// Gives AI agents (and other automated readers) a curated directory of the
/// site's content, feeds, machine-readable indexes, and navigation
/// structure – the AI counterpart to `sitemap.xml`. Always `.global`
/// scope: one llms.txt at the root, even on multilingual sites. Part of the
/// AI-friendliness cross-cutting concern.
public struct LlmsTxtRenderer: Renderer {
   public var scope: RenderScope { .global }

   private let logger = Logger(label: "SiteKit.LlmsTxtRenderer")

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let config = context.config
      let baseURL = config.baseURL

      var lines: [String] = []

      // H1: Site name (required by spec)
      lines.append("# \(config.name)")
      lines.append("")

      // Blockquote: Site description
      if !config.description.isEmpty {
         lines.append("> \(config.description)")
         lines.append("")
      }

      // Content Feeds
      lines.append("## Content Feeds")
      lines.append("")
      lines.append("- [RSS Feed (all sections)](\(baseURL)/feed.xml): Full-text feed of all articles")

      for section in context.sections {
         let sectionURL = "\(baseURL)/\(section.config.urlPrefix)/feed.xml"
         lines.append("- [\(section.config.name) RSS](\(sectionURL)): \(section.config.name) only")
      }

      lines.append("- [Sitemap](\(baseURL)/sitemap.xml): Complete page index with last-modified dates")
      lines.append("")

      // Machine-Readable Indexes
      lines.append("## Machine-Readable Indexes")
      lines.append("")
      lines.append("- [Navigation Index](\(baseURL)/assets/nav-index.json): Structured metadata for all articles (title, summary, tags, URL, section) plus tag display names and app catalog")
      lines.append("- [Full-Text Search Index](\(baseURL)/assets/search-index.json): Plain text content of all articles for search and analysis")
      lines.append("")

      // Sections with article counts
      lines.append("## Sections")
      lines.append("")
      for section in context.sections {
         let count = section.pages.count
         lines.append("- [\(section.config.name)](\(baseURL)/\(section.config.urlPrefix)/): \(count) posts")
      }
      lines.append("")

      // Static pages
      let navPages = context.staticPages.filter { !["home"].contains($0.slug) }
      if !navPages.isEmpty {
         lines.append("## Pages")
         lines.append("")
         for page in navPages {
            let url = "\(baseURL)/\(page.slug)/"
            let desc = page.description ?? page.title
            lines.append("- [\(page.title)](\(url)): \(desc)")
         }
         lines.append("")
      }

      // Languages
      if config.isMultilingual {
         let allLangs = config.allLanguages
         let defaultLang = config.effectiveDefaultLanguage
         let langList = allLangs.map { $0 == defaultLang ? "\($0) (default)" : $0 }.joined(separator: ", ")

         lines.append("## Languages")
         lines.append("")
         lines.append("Available in: \(langList)")
         lines.append("Locale-specific content at: /{locale}/...")
         lines.append("Locale-specific feeds and indexes at: /{locale}/feed.xml, /{locale}/assets/nav-index.json")
         lines.append("")
      }

      let content = lines.joined(separator: "\n")
      let path = context.outputDirectory.appendingPathComponent("llms.txt")

      self.logger.info("Generated llms.txt (\(lines.count) lines)")
      return [OutputFile(outputPath: path, content: content)]
   }
}
