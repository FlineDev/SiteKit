import Foundation

/// Writes two JSON indexes that power client-side search and navigation:
/// `/assets/nav-index.json` (compact section/category/tag map) and
/// `/assets/search-index.json` (per-page title, summary, and tags).
///
/// Both files are read by the theme's search/nav JavaScript at runtime; both
/// are emitted per-locale (default `Renderer` scope) so each locale carries
/// only its own pages. Empty when the site has no published pages.
public struct NavIndexRenderer: Renderer {
   /// Path authorities consulted per page: a `Page` plugin that writes a page somewhere
   /// the router cannot derive (or consumes it without an own URL) is handed in here by
   /// the blueprint so both indexes carry the URLs that actually exist.
   let pathResolvers: [any PagePathResolving]

   public init(pathResolvers: [any PagePathResolving] = []) {
      self.pathResolvers = pathResolvers
   }

   public func render(context: BuildContext) throws -> [OutputFile] {
      let allPages = context.sections.flatMap(\.pages)
      guard !allPages.isEmpty else { return [] }

      let router = context.router
      var navEntries: [[String: Any]] = []
      var searchEntries: [[String: Any]] = []

      for section in context.sections {
         // The router default only holds for pages no path resolver claims: a page
         // re-homed by its rendering plugin is indexed at the path that plugin actually
         // writes, a consumed page without an own URL is omitted from both indexes.
         for page in section.pages {
            let url: String
            switch self.pathResolvers.pathResolution(for: page, context: context) {
            case .unpublished:
               continue
            case .path(let overriddenPath):
               url = overriddenPath
            case .routerDefault:
               url = router.pagePath(for: page, in: section.config)
            }

            navEntries.append([
               "slug": page.slug,
               "section": section.config.slug,
               "category": page.category.slugified(language: context.config.language),
               "tags": page.tags.map { $0.slugified(language: context.config.language) },
               "url": url,
               "title": page.title,
               "summary": page.summary ?? page.description ?? "",
            ] as [String: Any])

            // Full-text search entry: slug + plain text content
            let plainText = Self.stripHTML(page.htmlContent)
            searchEntries.append([
               "slug": page.slug,
               "url": url,
               "title": page.title,
               "text": plainText,
            ] as [String: Any])
         }
      }

      // Collect unique tags with display names for search
      var allTags: [String: String] = [:]
      let displayNames = context.config.tagDisplayNames ?? [:]
      for section in context.sections {
         for page in section.pages {
            for tag in page.tags {
               let slug = tag.slugified(language: context.config.language)
               if allTags[slug] == nil {
                  allTags[slug] = displayNames[slug] ?? tag
               }
            }
         }
      }

      // Extract app data from the "apps" static page for search
      let apps = Self.extractApps(from: context.staticPages, router: router)

      // Wrap in object with articles, tags, and apps for search
      var wrapper: [String: Any] = [
         "articles": navEntries,
         "tags": allTags,
      ]
      if !apps.isEmpty {
         wrapper["apps"] = apps
      }

      let navJsonData = try JSONSerialization.data(withJSONObject: wrapper, options: [.sortedKeys])
      let navContent = String(data: navJsonData, encoding: .utf8) ?? "{}"

      let searchJsonData = try JSONSerialization.data(withJSONObject: searchEntries, options: [.sortedKeys])
      let searchContent = String(data: searchJsonData, encoding: .utf8) ?? "[]"

      // Write to locale-specific path for multilingual sites
      let locale = context.uiStrings.locale
      let defaultLang = context.config.effectiveDefaultLanguage
      let baseDir = locale == defaultLang
         ? context.outputDirectory
         : context.outputDirectory.appendingPathComponent(locale)
      let assetsDir = baseDir.appendingPathComponent("assets")

      return [
         OutputFile(outputPath: assetsDir.appendingPathComponent("nav-index.json"), content: navContent),
         OutputFile(outputPath: assetsDir.appendingPathComponent("search-index.json"), content: searchContent),
      ]
   }

   /// Extracts structured app data from the "apps" static page HTML.
   /// Parses `<div class="app-detail">` blocks for name, tagline, icon, and URLs.
   private static func extractApps(from staticPages: [PageModel], router: any URLRouter) -> [[String: Any]] {
      guard let appsPage = staticPages.first(where: { $0.slug == "apps" }) else { return [] }

      let html = appsPage.htmlContent
      var apps: [[String: Any]] = []

      // Match each app-detail block
      let detailPattern = /class="app-detail"[\s\S]*?<h3><a href="([^"]*)">(.*?)<\/a><\/h3>\s*<p class="app-detail-tagline">(.*?)<\/p>/
      for match in html.matches(of: detailPattern) {
         let externalURL = String(match.1)
         let name = Self.stripHTML(String(match.2))
         let tagline = Self.stripHTML(String(match.3))

         apps.append([
            "name": name,
            "tagline": tagline,
            "externalURL": externalURL,
         ] as [String: Any])
      }

      return apps
   }

   /// Strips HTML tags and decodes common entities to produce plain text.
   private static func stripHTML(_ html: String) -> String {
      html
         .replacing(#/<[^>]+>/#, with: " ")
         .replacing("&amp;", with: "&")
         .replacing("&lt;", with: "<")
         .replacing("&gt;", with: ">")
         .replacing("&quot;", with: "\"")
         .replacing("&#39;", with: "'")
         .replacing("&nbsp;", with: " ")
         .replacing(#/\s+/#, with: " ")
         .trimmingCharacters(in: .whitespaces)
   }
}
