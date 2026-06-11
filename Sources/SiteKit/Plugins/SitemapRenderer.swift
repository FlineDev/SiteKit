import Foundation

/// Generates a `sitemap.xml` listing all published pages for search engine crawlers.
public struct SitemapRenderer: Renderer {
   /// `.perLocale` – `render(context:)` derives the output path from
   /// `context.router.homePath()` so each locale gets its own `<lang>/sitemap.xml`,
   /// and the `sitemap_index.xml` (only emitted when `homePrefix.isEmpty`) lists
   /// every locale's sitemap. A `.global` scope would produce only the root
   /// sitemap and leave the index referencing missing per-locale files.
   public var scope: RenderScope { .perLocale }

   /// Path authorities consulted per page: a `Page` plugin that writes a page somewhere
   /// the router cannot derive (or consumes it without an own URL) is handed in here by
   /// the blueprint so the sitemap lists the URLs that actually exist.
   let pathResolvers: [any PagePathResolving]

   public init(pathResolvers: [any PagePathResolving] = []) {
      self.pathResolvers = pathResolvers
   }

   public func render(context: BuildContext) throws -> [OutputFile] {
      let entries = try DefaultSitemapDataAdapter(pathResolvers: self.pathResolvers).adapt(context)

      var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd"
      dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

      for entry in entries {
         xml += "<url><loc>\(context.config.baseURL)\(entry.path)</loc>"
         if let lastModified = entry.lastModified {
            xml += "<lastmod>\(dateFormatter.string(from: lastModified))</lastmod>"
         }
         xml += "</url>"
      }

      xml += "</urlset>"

      // Derive locale-aware output path from router's home path
      let homePrefix = String(context.router.homePath().dropFirst()) // "de/" or ""
      let outputPath = context.outputDirectory.appendingPathComponent("\(homePrefix)sitemap.xml")
      var files = [OutputFile(outputPath: outputPath, content: xml)]

      // Generate sitemap index for multilingual sites (only on default locale build)
      if context.config.isMultilingual && homePrefix.isEmpty {
         var indexXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><sitemapindex xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
         for lang in context.config.allLanguages {
            let prefix = lang == context.config.effectiveDefaultLanguage ? "" : "\(lang)/"
            indexXml += "<sitemap><loc>\(context.config.baseURL)/\(prefix)sitemap.xml</loc></sitemap>"
         }
         indexXml += "</sitemapindex>"

         let indexPath = context.outputDirectory.appendingPathComponent("sitemap_index.xml")
         files.append(OutputFile(outputPath: indexPath, content: indexXml))
      }

      return files
   }
}

public enum SitemapChangeFrequency: String {
   case always, hourly, daily, weekly, monthly, yearly, never
}

public struct SitemapEntry {
   public let path: String
   public let lastModified: Date?
   public let changeFrequency: SitemapChangeFrequency
   public let priority: Double

   public init(
      path: String,
      lastModified: Date? = nil,
      changeFrequency: SitemapChangeFrequency = .monthly,
      priority: Double = 0.5
   ) {
      self.path = path
      self.lastModified = lastModified
      self.changeFrequency = changeFrequency
      self.priority = priority
   }
}

fileprivate struct DefaultSitemapDataAdapter {
   let pathResolvers: [any PagePathResolving]

   func adapt(_ context: BuildContext) throws -> [SitemapEntry] {
      var entries: [SitemapEntry] = []
      let router = context.router

      // Home page
      let allPages = context.sections.flatMap(\.pages)
      let newestDate = allPages.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })?.date
      entries.append(
         SitemapEntry(
            path: router.homePath(),
            lastModified: newestDate,
            changeFrequency: .weekly,
            priority: 1.0
         )
      )

      // Section listings and pages
      for section in context.sections {
         let newestInSection = section.pages.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })?.date
         entries.append(
            SitemapEntry(
               path: router.sectionListingPath(for: section.config),
               lastModified: newestInSection,
               changeFrequency: .weekly,
               priority: 0.9
            )
         )

         // Category listings (if section has categories and no blogURLPrefix)
         if let categories = section.config.categories {
            let pagesByCategory = Dictionary(grouping: section.pages) { $0.category }
            for categoryConfig in categories {
               let categoryPages = pagesByCategory[categoryConfig.slug] ?? []
               let newestInCategory = categoryPages.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })?.date
               entries.append(
                  SitemapEntry(
                     path: router.categoryPath(for: categoryConfig),
                     lastModified: newestInCategory,
                     changeFrequency: .weekly,
                     priority: 0.8
                  )
               )
            }
         }

         // Individual pages in section. The router default only holds for pages no
         // path resolver claims: a page re-homed by its rendering plugin is listed at
         // the path that plugin actually writes, a consumed page without an own URL
         // is omitted (listing the router default would send crawlers to a 404).
         for page in section.pages {
            let path: String
            switch self.pathResolvers.pathResolution(for: page, context: context) {
            case .unpublished:
               continue
            case .path(let overriddenPath):
               path = overriddenPath
            case .routerDefault:
               path = router.pagePath(for: page, in: section.config)
            }
            entries.append(
               SitemapEntry(
                  path: path,
                  lastModified: page.date,
                  changeFrequency: .monthly,
                  priority: 0.7
               )
            )
         }
      }

      // Static pages
      for staticPage in context.staticPages {
         let path: String
         switch self.pathResolvers.pathResolution(for: staticPage, context: context) {
         case .unpublished:
            continue
         case .path(let overriddenPath):
            path = overriddenPath
         case .routerDefault:
            path = router.staticPagePath(for: staticPage)
         }
         entries.append(
            SitemapEntry(
               path: path,
               changeFrequency: .monthly,
               priority: 0.6
            )
         )
      }

      // Tags index
      if !context.tags.isEmpty {
         entries.append(
            SitemapEntry(
               path: router.tagsIndexPath(),
               lastModified: newestDate,
               changeFrequency: .weekly,
               priority: 0.4
            )
         )

         // Sort by tag name so the sitemap order is deterministic across builds –
         // Dictionary iteration order is hash-randomized per run otherwise.
         for tag in context.tags.keys.sorted() {
            entries.append(
               SitemapEntry(
                  path: router.tagPath(for: tag),
                  changeFrequency: .weekly,
                  priority: 0.3
               )
            )
         }
      }

      // Deduplicate entries by path. A page can appear twice when it exists
      // as both a section (e.g. urlPrefix "apps") AND a static page (slug "apps"),
      // or when a static page with slug "" produces the same "/" path as the
      // explicit home entry. First occurrence wins (higher priority, since home
      // and section listings are added before static pages).
      var seen = Set<String>()
      return entries.filter { seen.insert($0.path).inserted }
   }
}
