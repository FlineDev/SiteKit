import Foundation

extension OutputFileRenderer {
   public func renderArticle(page: PageModel, previousPage: PageModel? = nil, nextPage: PageModel? = nil, section: SectionConfig? = nil) -> OutputFile {
      let pageTitle = "\(page.title) – \(self.config.name)"
      let articlePath: String
      if let section {
         articlePath = self.router.pagePath(for: page, in: section)
      } else {
         articlePath = self.router.articlePath(for: page)
      }
      let canonicalURL = "\(self.config.baseURL)\(articlePath)"

      let effectiveAuthor = page.author ?? self.config.author

      var articleHeaderParts: [String] = [
         "<h1 class=\"sk-article-title\">\(page.title.htmlEscaped)</h1>",
      ]

      if let summary = page.summary, !summary.isEmpty {
         articleHeaderParts.append("<p class=\"sk-article-summary\">\(summary.htmlEscaped)</p>")
      }

      var metaParts: [String] = []

      // Author byline with profile image, name, date, read time
      if let author = effectiveAuthor {
         var bylineParts: [String] = []

         if let imageURL = author.imageURL {
            bylineParts.append("<img class=\"sk-article-author-image\" src=\"\(imageURL)\" alt=\"\(author.name.htmlEscaped)\"/>")
         }

         let authorNameHTML: String
         if let url = author.url {
            authorNameHTML = "<a class=\"sk-article-author\" href=\"\(url)\">\(author.name.htmlEscaped)</a>"
         } else {
            authorNameHTML = "<span class=\"sk-article-author\">\(author.name.htmlEscaped)</span>"
         }

         let detailsHTML = "<time class=\"sk-article-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time><span class=\"sk-article-read-time\">\(self.uiStrings.string(for: .minRead, args: page.readTimeMinutes).htmlEscaped)</span>"

         bylineParts.append("<div class=\"sk-article-byline-text\">\(authorNameHTML)<div class=\"sk-article-byline-details\">\(detailsHTML)</div></div>")

         metaParts.append("<div class=\"sk-article-byline\">\(bylineParts.joined())</div>")
      } else {
         // Fallback: no author – flat date + read time
         metaParts.append("<time class=\"sk-article-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time>")
         metaParts.append("<span class=\"sk-article-read-time\">\(self.uiStrings.string(for: .minRead, args: page.readTimeMinutes).htmlEscaped)</span>")
      }

      if !page.category.isEmpty {
         metaParts.append("<a class=\"sk-article-category\" href=\"\(self.router.blogListingPath())\">\(self.categoryDisplayName(for: page.category).htmlEscaped)</a>")
      }

      articleHeaderParts.append("<div class=\"sk-article-meta\">\(metaParts.joined())</div>")

      var articleFooterParts: [String] = []

      if !page.tags.isEmpty {
         let tagLinks = page.tags.map { tag in
            "<li class=\"sk-tag\"><a class=\"sk-tag-link\" href=\"\(self.router.tagPath(for: tag))\">\(self.tagDisplayName(for: tag).htmlEscaped)</a></li>"
         }.joined()
         articleFooterParts.append("<ul class=\"sk-tag-list\">\(tagLinks)</ul>")
      }

      // Prev/Next navigation
      if previousPage != nil || nextPage != nil {
         var navParts: [String] = []

         if let prev = previousPage {
            let prevPath = section.map { self.router.pagePath(for: prev, in: $0) } ?? self.router.articlePath(for: prev)
            navParts.append("<a class=\"sk-article-nav-prev\" href=\"\(prevPath)\"><span class=\"sk-article-nav-label\">← \(self.uiStrings.string(for: .previousArticle).htmlEscaped)</span><span class=\"sk-article-nav-title\">\(prev.title.htmlEscaped)</span></a>")
         } else {
            navParts.append("<div class=\"sk-article-nav-prev sk-article-nav-empty\"></div>")
         }

         if let next = nextPage {
            let nextPath = section.map { self.router.pagePath(for: next, in: $0) } ?? self.router.articlePath(for: next)
            navParts.append("<a class=\"sk-article-nav-next\" href=\"\(nextPath)\"><span class=\"sk-article-nav-label\">\(self.uiStrings.string(for: .nextArticle).htmlEscaped) →</span><span class=\"sk-article-nav-title\">\(next.title.htmlEscaped)</span></a>")
         } else {
            navParts.append("<div class=\"sk-article-nav-next sk-article-nav-empty\"></div>")
         }

         articleFooterParts.append("<nav class=\"sk-article-nav\">\(navParts.joined())</nav>")
      }

      // Back link – section-aware
      let backLinkPath: String
      let backLinkText: String
      if let section {
         backLinkPath = self.router.sectionListingPath(for: section)
         if let custom = section.backLinkText {
            backLinkText = custom
         } else if let sectionKey = UIStringKey(rawValue: "all_\(section.slug)"),
                   self.uiStrings.string(for: sectionKey) != sectionKey.rawValue {
            backLinkText = self.uiStrings.string(for: sectionKey)
         } else {
            backLinkText = self.uiStrings.string(for: .backToBlog)
         }
      } else {
         backLinkPath = self.router.blogListingPath()
         backLinkText = self.uiStrings.string(for: .backToBlog)
      }
      articleFooterParts.append("<p class=\"sk-back-link\"><a href=\"\(backLinkPath)\">← \(backLinkText.htmlEscaped)</a></p>")

      let hreflangMap: [String: String]? = page.extensionValue("hreflang")

      // Determine RSS feed URL based on section
      let rssFeedURL: String?
      if let section {
         rssFeedURL = "\(self.router.sectionListingPath(for: section))feed.xml"
      } else {
         rssFeedURL = "\(self.router.homePath())feed.xml"
      }

      let head = self.buildHead(
         title: pageTitle,
         description: page.summary,
         canonicalURL: canonicalURL,
         ogType: "article",
         image: page.image,
         imageAlt: page.imageAlt,
         rssFeedURL: rssFeedURL,
         rssFeedTitle: self.config.name,
         articleDate: page.date,
         articleAuthor: effectiveAuthor,
         articleCategory: self.categoryDisplayName(for: page.category),
         jsonLD: self.buildArticleJSONLD(page: page, canonicalURL: canonicalURL),
         hreflang: hreflangMap,
         preloadImageURL: page.image
      )

      var articleParts: [String] = [
         "<header class=\"sk-article-header\">\(articleHeaderParts.joined())</header>",
      ]

      // Hero image (feature image displayed visually) – often the LCP element.
      // Eager-loaded (no `loading="lazy"`) and marked `fetchpriority="high"` so the browser
      // prioritizes it in the network queue.
      if let heroImage = page.image {
         let altText = page.imageAlt ?? page.title
         articleParts.append("<figure class=\"sk-article-hero\"><img src=\"\(heroImage)\" alt=\"\(altText.htmlEscaped)\" fetchpriority=\"high\"/></figure>")
      }

      // Translation notice for AI-translated articles in unverified languages
      if let noticeHTML = self.renderTranslationNotice(for: page, hreflangMap: hreflangMap) {
         articleParts.append(noticeHTML)
      }

      // Article body with optional inline promotions.
      // Promotion data is set by PromotionEnricher during the build pipeline; the
      // renderer is a passive consumer here.
      let selection: PromotionSelection? = page.extensionValue("promotion")
      let bodyHTML = self.injectInlinePromotions(
         html: page.htmlContent,
         inlinePromos: selection?.inlinePromos ?? []
      )
      articleParts.append("<div class=\"sk-article-body\">\(bodyHTML)</div>")

      // End-of-article promotional boxes
      if let endHTML = self.renderEndPromotions(selection?.endPromos ?? []) {
         articleParts.append(endHTML)
      }

      // Subtle follow-me footer (always shown)
      let isShortStyle = section?.style == "short"
      articleParts.append(self.renderFollowMe(isSnippet: isShortStyle))

      articleParts.append("<footer class=\"sk-article-footer\">\(articleFooterParts.joined())</footer>")

      let mainContent = "<main class=\"sk-main\"><article class=\"sk-article\" data-slug=\"\(page.slug)\">\(articleParts.joined())</article></main>"

      let bodyClass = section.map { "sk-page-article sk-section-\($0.slug)" } ?? "sk-page-article"
      let html = self.renderPageShell(
         head: head,
         bodyClass: bodyClass,
         dataAttributes: page.category.isEmpty ? [:] : ["data-category": page.category.slugified(language: self.config.language)],
         content: mainContent
      )

      // Convert router path "/blog/slug/" to file path "blog/slug/index.html"
      let relativePath = String(articlePath.dropFirst()) // Remove leading /
      let outputPath = self.outputDirectory
         .appendingPathComponent(relativePath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   /// Renders a draft preview page at `/blog/<slug>/preview-<id>/`.
   /// Includes noindex meta, draft banner, no promotions, no prev/next navigation.
   public func renderPreviewArticle(page: PageModel, section: SectionConfig? = nil) -> OutputFile? {
      guard let previewToken = page.id else { return nil }

      let pageTitle = "DRAFT: \(page.title) – \(self.config.name)"
      let articlePath: String
      if let section {
         articlePath = self.router.pagePath(for: page, in: section)
      } else {
         articlePath = self.router.articlePath(for: page)
      }
      let canonicalURL = "\(self.config.baseURL)\(articlePath)"

      let effectiveAuthor = page.author ?? self.config.author

      var articleHeaderParts: [String] = [
         "<h1 class=\"sk-article-title\">\(page.title.htmlEscaped)</h1>",
      ]

      if let summary = page.summary, !summary.isEmpty {
         articleHeaderParts.append("<p class=\"sk-article-summary\">\(summary.htmlEscaped)</p>")
      }

      var metaParts: [String] = []

      if let author = effectiveAuthor {
         var bylineParts: [String] = []
         if let imageURL = author.imageURL {
            bylineParts.append("<img class=\"sk-article-author-image\" src=\"\(imageURL)\" alt=\"\(author.name.htmlEscaped)\"/>")
         }
         let authorNameHTML: String
         if let url = author.url {
            authorNameHTML = "<a class=\"sk-article-author\" href=\"\(url)\">\(author.name.htmlEscaped)</a>"
         } else {
            authorNameHTML = "<span class=\"sk-article-author\">\(author.name.htmlEscaped)</span>"
         }
         let detailsHTML = "<time class=\"sk-article-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time><span class=\"sk-article-read-time\">\(self.uiStrings.string(for: .minRead, args: page.readTimeMinutes).htmlEscaped)</span>"
         bylineParts.append("<div class=\"sk-article-byline-text\">\(authorNameHTML)<div class=\"sk-article-byline-details\">\(detailsHTML)</div></div>")
         metaParts.append("<div class=\"sk-article-byline\">\(bylineParts.joined())</div>")
      } else {
         metaParts.append("<time class=\"sk-article-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time>")
         metaParts.append("<span class=\"sk-article-read-time\">\(self.uiStrings.string(for: .minRead, args: page.readTimeMinutes).htmlEscaped)</span>")
      }

      if !page.category.isEmpty {
         metaParts.append("<a class=\"sk-article-category\" href=\"\(self.router.blogListingPath())\">\(self.categoryDisplayName(for: page.category).htmlEscaped)</a>")
      }

      articleHeaderParts.append("<div class=\"sk-article-meta\">\(metaParts.joined())</div>")

      var articleFooterParts: [String] = []

      if !page.tags.isEmpty {
         let tagLinks = page.tags.map { tag in
            "<li class=\"sk-tag\"><a class=\"sk-tag-link\" href=\"\(self.router.tagPath(for: tag))\">\(self.tagDisplayName(for: tag).htmlEscaped)</a></li>"
         }.joined()
         articleFooterParts.append("<ul class=\"sk-tag-list\">\(tagLinks)</ul>")
      }

      // Build hreflang map for sibling preview URLs. All locale variants share the same `id`
      // (= preview token), so the published-article URLs from HreflangEnricher can be suffixed
      // with `preview-<token>/` to point at each locale's draft preview.
      let publishedHreflang: [String: String]? = page.extensionValue("hreflang")
      let previewHreflang: [String: String]? = publishedHreflang.map { map in
         var rewritten: [String: String] = [:]
         for (locale, url) in map {
            let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
            rewritten[locale] = "\(trimmed)/preview-\(previewToken)/"
         }
         return rewritten
      }

      let head = self.buildHead(
         title: pageTitle,
         description: page.summary,
         canonicalURL: canonicalURL,
         ogType: "article",
         image: page.image,
         imageAlt: page.imageAlt,
         articleDate: page.date,
         articleAuthor: effectiveAuthor,
         articleCategory: self.categoryDisplayName(for: page.category),
         hreflang: previewHreflang,
         noindex: true,
         preloadImageURL: page.image
      )

      // Draft banner + article body (no promotions)
      var articleParts: [String] = [
         "<aside class=\"sk-draft-banner\"><strong>Draft Preview</strong> – This article is not yet published.</aside>",
         "<header class=\"sk-article-header\">\(articleHeaderParts.joined())</header>",
      ]

      if let heroImage = page.image {
         let altText = page.imageAlt ?? page.title
         articleParts.append("<figure class=\"sk-article-hero\"><img src=\"\(heroImage)\" alt=\"\(altText.htmlEscaped)\" fetchpriority=\"high\"/></figure>")
      }

      articleParts.append("<div class=\"sk-article-body\">\(page.htmlContent)</div>")
      articleParts.append("<footer class=\"sk-article-footer\">\(articleFooterParts.joined())</footer>")

      let mainContent = "<main class=\"sk-main\"><article class=\"sk-article sk-article-draft\" data-slug=\"\(page.slug)\">\(articleParts.joined())</article></main>"

      let bodyClass = section.map { "sk-page-article sk-section-\($0.slug) sk-draft-preview" } ?? "sk-page-article sk-draft-preview"
      let html = self.renderPageShell(
         head: head,
         bodyClass: bodyClass,
         dataAttributes: page.category.isEmpty ? [:] : ["data-category": page.category.slugified(language: self.config.language)],
         content: mainContent
      )

      // Output path: /blog/<slug>/preview-<token>/index.html
      let relativePath = String(articlePath.dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(relativePath)
         .appendingPathComponent("preview-\(previewToken)")
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   private func renderTranslationNotice(for page: PageModel, hreflangMap: [String: String]?) -> String? {
      let noticeConfig = self.config.localization?.translationNotice
      guard noticeConfig?.enabled != false else { return nil }

      let originalLang = page.originalLanguage ?? self.config.effectiveDefaultLanguage
      let verifiedLanguages = noticeConfig?.verifiedLanguages ?? [self.config.effectiveDefaultLanguage]

      // Only show if current locale is not the original AND not verified
      guard page.locale != originalLang, !verifiedLanguages.contains(page.locale) else { return nil }

      // Look up localized language name
      let langNameKey = "langName\(originalLang.prefix(1).uppercased())\(originalLang.dropFirst())"
      let langName = self.uiStrings.string(forRawKey: langNameKey) ?? originalLang

      // Build notice text
      let noticeText = self.uiStrings.string(for: .translationNotice, args: langName)
      let linkText = "\(self.uiStrings.string(for: .translationNoticeLink)) \u{2192}"

      // Find original article path from hreflang map (strip baseURL to keep paths relative)
      let absoluteURL = hreflangMap?[originalLang] ?? ""
      let relativePath = absoluteURL.hasPrefix(self.config.baseURL)
         ? String(absoluteURL.dropFirst(self.config.baseURL.count))
         : absoluteURL
      // Add noredirect param to prevent lang-redirect.js from bouncing back
      let originalURL = relativePath.isEmpty ? "" : "\(relativePath)?noredirect"

      var parts: [String] = [
         "<i class=\"fa-solid fa-robot\" aria-hidden=\"true\"></i>",
         "<span>\(noticeText.htmlEscaped)</span>",
      ]

      if !originalURL.isEmpty {
         parts.append("<a class=\"sk-translation-notice-link\" href=\"\(originalURL)\">\(linkText.htmlEscaped)</a>")
      }

      return "<aside class=\"sk-translation-notice\">\(parts.joined())</aside>"
   }

   // MARK: - Promotion System

   private func renderPromoCard(_ item: PromotionItemConfig, inline: Bool = false) -> String {
      let markdownRenderer = MarkdownRenderer()
      let locale = self.uiStrings.locale
      let localizedFields = item.localized?[locale]
      let effectiveTitle = localizedFields?.title ?? item.title
      let effectiveText = localizedFields?.text ?? item.text
      let renderedText = markdownRenderer.renderInline(effectiveText)

      var html = "<aside class=\"sk-promo sk-promo-\(item.style)\(inline ? " sk-promo-inline" : "")\">"

      if let emoji = item.emoji {
         html += "<div class=\"sk-promo-emoji\" aria-hidden=\"true\">\(emoji)</div>"
      }

      html += "<div class=\"sk-promo-text\"><strong>\(effectiveTitle)</strong><br>\(renderedText)"

      let effectiveLinkText = localizedFields?.linkText ?? item.linkText
      if let linkURL = item.linkURL, let linkText = effectiveLinkText {
         html += "<br><a class=\"sk-promo-link\" href=\"\(linkURL)\">\(linkText)</a>"
      }

      html += "</div></aside>"
      return html
   }

   private func renderEndPromotions(_ promos: [PromotionItemConfig]) -> String? {
      guard !promos.isEmpty else { return nil }

      let cards = promos.map { self.renderPromoCard($0) }.joined()
      return "<aside class=\"sk-promo-container\">\(cards)</aside>"
   }

   /// Injects inline promotions between sections (before `<h2` headings) near the middle of the article.
   private func injectInlinePromotions(html: String, inlinePromos: [PromotionItemConfig]) -> String {
      guard !inlinePromos.isEmpty else { return html }

      // Find all <h2 positions – these are natural section boundaries
      let h2Pattern = "<h2"
      var h2Positions: [String.Index] = []
      var searchStart = html.startIndex
      while let range = html.range(of: h2Pattern, range: searchStart..<html.endIndex) {
         h2Positions.append(range.lowerBound)
         searchStart = range.upperBound
      }

      // Need at least 2 sections (so there's a boundary to insert at)
      guard h2Positions.count >= 2 else { return html }

      // Pick the h2 closest to the middle of the article for the first inline promo
      let middleOffset = html.count / 2
      let bestIndex = h2Positions.min(by: {
         abs(html.distance(from: html.startIndex, to: $0) - middleOffset) <
         abs(html.distance(from: html.startIndex, to: $1) - middleOffset)
      })!

      // Insert the promo card right before the chosen <h2
      let promoHTML = self.renderPromoCard(inlinePromos[0], inline: true)
      var result = String(html[html.startIndex..<bestIndex])
      result += promoHTML
      result += String(html[bestIndex..<html.endIndex])

      return result
   }

   /// Renders a subtle, conversational follow-me footer below promotions.
   private func renderFollowMe(isSnippet: Bool = false) -> String {
      let socialLinks = self.config.footer?.social ?? []
      guard !socialLinks.isEmpty else { return "" }

      // Build a conversational sentence with social links
      let linkParts = socialLinks.map { link in
         let name = link.platform.capitalized
         return "<a href=\"\(link.url)\" target=\"_blank\" rel=\"noopener\">\(name)</a>"
      }

      let connector = self.uiStrings.string(for: .connectorAnd)
      let linksHTML: String
      if linkParts.count == 1 {
         linksHTML = linkParts[0]
      } else if linkParts.count == 2 {
         linksHTML = "\(linkParts[0]) \(connector) \(linkParts[1])"
      } else {
         let last = linkParts.last!
         let rest = linkParts.dropLast().joined(separator: ", ")
         linksHTML = "\(rest) \(connector) \(last)"
      }

      let key: UIStringKey = isSnippet ? .followMeShort : .followMeArticle
      let text = self.uiStrings.string(for: key, args: linksHTML)

      return "<div class=\"sk-author-follow\"><p>\(text)</p></div>"
   }
}
