import Foundation

extension OutputFileRenderer {
   /// Generic section listing – supports topic-grouped, category-grouped, and flat layouts.
   public func renderSectionListing(section: ContentSection) -> OutputFile {
      let sortedPages = section.pages.sortedByDate()
      let sectionName = section.config.name
      let title = "\(sectionName) – \(self.config.name)"
      let listingPath = self.router.sectionListingPath(for: section.config)
      let rssFeedPath = "\(self.router.sectionListingPath(for: section.config))feed.xml"

      // Title row with RSS link
      let headerHTML = "<div class=\"sk-listing-title-row\"><h1 class=\"sk-listing-title\">\(sectionName.htmlEscaped)</h1><a class=\"sk-listing-rss\" href=\"\(rssFeedPath)\"><i class=\"fa-solid fa-rss\"></i> RSS</a></div>"

      let hreflang = self.buildHreflangForAllLanguages { $0.sectionListingPath(for: section.config) }
      let head = self.buildHead(
         title: title,
         description: section.config.description ?? self.config.description,
         canonicalURL: "\(self.config.baseURL)\(listingPath)",
         ogType: "website",
         rssFeedURL: rssFeedPath,
         rssFeedTitle: "\(sectionName) – \(self.config.name)",
         hreflang: hreflang
      )

      var listingParts: [String] = [
         "<header class=\"sk-listing-header\">\(headerHTML)</header>"
      ]

      // Topic-grouped, category-grouped, or flat layout
      if let topics = section.config.topics, !topics.isEmpty {
         // Grouped by topics (e.g., Snippets)
         let sortedTopics = topics.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
         var groups: [(label: String, anchor: String, count: Int)] = []
         var allMatchedSlugs = Set<String>()

         for topic in sortedTopics {
            let topicPages = sortedPages.filter { page in
               page.tags.contains(where: { topic.tags.contains($0) })
            }
            guard !topicPages.isEmpty else { continue }
            for page in topicPages { allMatchedSlugs.insert(page.slug) }

            let anchor = topic.title.slugified(language: self.config.language)
            groups.append((label: topic.title, anchor: anchor, count: topicPages.count))
            listingParts.append("<h2 class=\"sk-listing-group-title\" id=\"\(anchor)\">\(topic.title.htmlEscaped)</h2>")
            listingParts.append(self.sectionCardList(topicPages, section: section.config))
         }

         // Pages that don't match any topic
         let uncategorized = sortedPages.filter { !allMatchedSlugs.contains($0.slug) }
         if !uncategorized.isEmpty {
            let anchor = "other"
            groups.append((label: "Other", anchor: anchor, count: uncategorized.count))
            listingParts.append("<h2 class=\"sk-listing-group-title\" id=\"\(anchor)\">Other</h2>")
            listingParts.append(self.sectionCardList(uncategorized, section: section.config))
         }

         // Insert jump nav after header
         if let jumpNav = self.sectionJumpNav(groups: groups) {
            listingParts.insert(jumpNav, at: 1)
         }
      } else {
         // Flat layout
         listingParts.append(self.sectionCardList(sortedPages, section: section.config))
      }

      let mainContent = "<main class=\"sk-main\"><div class=\"sk-listing\">\(listingParts.joined())</div></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-\(section.config.slug)",
         content: mainContent
      )

      let relPath = String(listingPath.dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(relPath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   /// Generates a jump navigation bar for grouped listings.
   /// Shows when: 3+ groups, OR 2 groups where the first has 3+ entries.
   func sectionJumpNav(groups: [(label: String, anchor: String, count: Int)]) -> String? {
      guard !groups.isEmpty else { return nil }

      let shouldShow = groups.count >= 3 || (groups.count == 2 && (groups.first?.count ?? 0) >= 3)
      guard shouldShow else { return nil }

      let links = groups.map { group in
         "<a class=\"sk-jump-link\" href=\"#\(group.anchor)\">\(group.label.htmlEscaped) (\(group.count))</a>"
      }.joined()

      return "<nav class=\"sk-section-jump-nav\" aria-label=\"Jump to section\">\(links)</nav>"
   }

   /// Renders a list of cards for pages in a content section.
   func sectionCardList(_ pages: [PageModel], section: SectionConfig) -> String {
      if pages.isEmpty {
         return "<p class=\"sk-empty\">\(self.uiStrings.string(for: .noPostsYet).htmlEscaped)</p>"
      }

      let items = pages.enumerated().map { index, page -> String in
         let pageURL = self.router.pagePath(for: page, in: section)

         var cardParts: [String] = []

         // Image preview. The first card is typically above the fold – prioritize it as
         // the likely LCP. Rest are lazy to save bandwidth for critical resources.
         if let image = page.image, !image.isEmpty {
            let loadAttrs = index == 0 ? " fetchpriority=\"high\"" : " loading=\"lazy\""
            cardParts.append("<div class=\"sk-post-image-container\"><img class=\"sk-post-image\" src=\"\(image)\" alt=\"\(page.title.htmlEscaped)\"\(loadAttrs)/></div>")
         }

         var contentParts: [String] = [
            "<h2 class=\"sk-post-title\">\(page.title.htmlEscaped)</h2>",
            "<time class=\"sk-post-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time>",
         ]

         if let summary = page.summary, !summary.isEmpty {
            contentParts.append("<p class=\"sk-post-summary\">\(summary.htmlEscaped)</p>")
         }

         cardParts.append("<div class=\"sk-post-content\">\(contentParts.joined())</div>")

         var footerParts: [String] = []
         if !page.tags.isEmpty {
            let tagLinks = page.tags.prefix(3).map { tag in
               "<li class=\"sk-tag\"><a class=\"sk-tag-link\" href=\"\(self.router.tagPath(for: tag))\">\(self.tagDisplayName(for: tag).htmlEscaped)</a></li>"
            }.joined()
            footerParts.append("<ul class=\"sk-tag-list sk-tag-list-inline\">\(tagLinks)</ul>")
         }

         let footerHTML = footerParts.isEmpty ? "" : "<div class=\"sk-post-footer\">\(footerParts.joined())</div>"

         // The sk-post-link is an invisible overlay making the whole card clickable; give it
         // an accessible name so screen readers + Lighthouse can identify the destination.
         return "<li class=\"sk-post-card\"><a class=\"sk-post-link\" href=\"\(pageURL)\" aria-label=\"\(page.title.htmlEscaped)\"></a><article>\(cardParts.joined())</article>\(footerHTML)</li>"
      }.joined()

      return "<ul class=\"sk-post-list\">\(items)</ul>"
   }

   public func renderCategoryListing(category: CategoryConfig, pages: [PageModel]) -> OutputFile {
      let sortedPages = pages.sortedByDate()
      let title = "\(category.name) – \(self.config.name)"

      var headerParts: [String] = [
         "<h1 class=\"sk-listing-title\">\(category.name.htmlEscaped)</h1>"
      ]

      if let description = category.description {
         headerParts.append("<p class=\"sk-listing-description\">\(description.htmlEscaped)</p>")
      }

      headerParts.append("<p class=\"sk-back-link\"><a href=\"\(self.router.blogListingPath())\">← \(self.uiStrings.string(for: .allPosts).htmlEscaped)</a></p>")

      let hreflang = self.buildHreflangForAllLanguages { $0.categoryPath(for: category) }
      let head = self.buildHead(
         title: title,
         description: category.description,
         canonicalURL: "\(self.config.baseURL)\(self.router.categoryPath(for: category))",
         ogType: "website",
         rssFeedURL: "\(self.router.categoryPath(for: category))feed.xml",
         rssFeedTitle: "\(category.name) – \(self.config.name)",
         hreflang: hreflang
      )

      let mainContent = "<main class=\"sk-main\"><div class=\"sk-listing\" data-category=\"\(category.slug)\"><header class=\"sk-listing-header\">\(headerParts.joined())</header>\(self.articleList(sortedPages))</div></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-category",
         dataAttributes: ["data-category": category.slug],
         content: mainContent
      )

      let catPath = String(self.router.categoryPath(for: category).dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(catPath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   public func renderTagListing(tag: String, pages: [PageModel], sections: [ContentSection] = []) -> OutputFile {
      let displayName = self.tagDisplayName(for: tag)
      let sortedPages = pages.sortedByDate()
      let title = "\(displayName) – \(self.config.name)"

      let tagPath = self.router.tagPath(for: tag)
      let tagSlug = tag.slugified(language: self.config.language)

      let hreflang = self.buildHreflangForAllLanguages { $0.tagPath(for: tag) }
      let head = self.buildHead(
         title: title,
         description: self.uiStrings.string(for: .postsTaggedWith, args: displayName),
         canonicalURL: "\(self.config.baseURL)\(tagPath)",
         ogType: "website",
         hreflang: hreflang
      )

      // Build section-grouped content if there are multiple sections with matching pages
      var listingParts: [String] = [
         "<header class=\"sk-listing-header\"><h1 class=\"sk-listing-title\">\(displayName.htmlEscaped)</h1><p class=\"sk-listing-count\">\(self.uiStrings.string(for: .postCount, args: sortedPages.count).htmlEscaped)</p><p class=\"sk-back-link\"><a href=\"\(self.router.tagsIndexPath())\">← \(self.uiStrings.string(for: .allTags).htmlEscaped)</a></p></header>"
      ]

      // Check if pages span multiple sections
      let sectionSlugs = Set(sections.filter { section in
         section.pages.contains(where: { page in pages.contains(where: { $0.slug == page.slug }) })
      }.map(\.config.slug))

      if sectionSlugs.count > 1 {
         // Show pages grouped by section with jump nav
         var groups: [(label: String, anchor: String, count: Int)] = []
         var sectionData: [(config: SectionConfig, pages: [PageModel])] = []

         for section in sections {
            let sectionPages = sortedPages.filter { page in
               section.pages.contains(where: { $0.slug == page.slug })
            }
            guard !sectionPages.isEmpty else { continue }
            groups.append((label: section.config.name, anchor: section.config.slug, count: sectionPages.count))
            sectionData.append((config: section.config, pages: sectionPages))
         }

         if let jumpNav = self.sectionJumpNav(groups: groups) {
            listingParts.append(jumpNav)
         }

         for data in sectionData {
            listingParts.append("<h2 class=\"sk-listing-group-title\" id=\"\(data.config.slug)\">\(data.config.name.htmlEscaped)</h2>")
            listingParts.append(self.sectionCardList(data.pages, section: data.config))
         }
      } else {
         // Single section or no section info – use standard article list
         listingParts.append(self.articleList(sortedPages, tagContext: tagSlug))
      }

      let mainContent = "<main class=\"sk-main\"><div class=\"sk-listing\" data-tag=\"\(tagSlug)\">\(listingParts.joined())</div></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-tag",
         content: mainContent
      )

      let tagRelPath = String(tagPath.dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(tagRelPath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   public func renderTagsIndex(tags: [String: [PageModel]]) -> OutputFile {
      let title = "Tags – \(self.config.name)"
      let sortedTags = tags.sorted { $0.key < $1.key }

      let tagItems = sortedTags.map { tag, pages in
         let displayName = self.tagDisplayName(for: tag)
         return "<li class=\"sk-tag\"><a class=\"sk-tag-link\" href=\"\(self.router.tagPath(for: tag))\">\(displayName.htmlEscaped)</a><span class=\"sk-tag-count\"> (\(pages.count))</span></li>"
      }.joined()

      let hreflang = self.buildHreflangForAllLanguages { $0.tagsIndexPath() }
      let head = self.buildHead(
         title: title,
         description: "All tags",
         canonicalURL: "\(self.config.baseURL)\(self.router.tagsIndexPath())",
         ogType: "website",
         hreflang: hreflang
      )

      let mainContent = "<main class=\"sk-main\"><div class=\"sk-listing\"><header class=\"sk-listing-header\"><h1 class=\"sk-listing-title\">\(self.uiStrings.string(for: .tags).htmlEscaped)</h1><p class=\"sk-back-link\"><a href=\"\(self.router.blogListingPath())\">← \(self.uiStrings.string(for: .backToBlog).htmlEscaped)</a></p></header><ul class=\"sk-tag-list sk-tag-index\">\(tagItems)</ul></div></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-tags",
         content: mainContent
      )

      let tagsRelPath = String(self.router.tagsIndexPath().dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(tagsRelPath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }
}
