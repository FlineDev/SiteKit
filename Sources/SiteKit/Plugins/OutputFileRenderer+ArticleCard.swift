import Foundation

extension OutputFileRenderer {
   func articleList(_ pages: [PageModel], tagContext: String? = nil) -> String {
      if pages.isEmpty {
         return "<p class=\"sk-empty\">\(self.uiStrings.string(for: .noPostsYet).htmlEscaped)</p>"
      }

      let items = pages.enumerated().map { index, page -> String in
         let articleURL = self.router.articlePath(for: page)
         let contextParam = tagContext.map { "?from=\($0)" } ?? ""

         var cardParts: [String] = []

         // Image preview. The first card image is typically above the fold on listings
         // and is often the LCP candidate – prioritize its fetch. Everything below gets
         // lazy loading so it doesn't compete with critical resources on slow networks.
         if let image = page.image, !image.isEmpty {
            let loadAttrs = index == 0 ? " fetchpriority=\"high\"" : " loading=\"lazy\""
            cardParts.append("<div class=\"sk-post-image-container\"><img class=\"sk-post-image\" src=\"\(image)\" alt=\"\(page.title.htmlEscaped)\"\(loadAttrs)/></div>")
         }

         // Content section
         var contentParts: [String] = [
            "<h2 class=\"sk-post-title\">\(page.title.htmlEscaped)</h2>",
            "<time class=\"sk-post-date\" datetime=\"\(self.isoDate(page.date))\">\(self.formatDate(page.date).htmlEscaped)</time>",
         ]

         if let summary = page.summary, !summary.isEmpty {
            contentParts.append("<p class=\"sk-post-summary\">\(summary.htmlEscaped)</p>")
         }

         cardParts.append("<div class=\"sk-post-content\">\(contentParts.joined())</div>")

         // Card footer with category and tags
         var footerParts: [String] = []
         if !page.category.isEmpty {
            footerParts.append("<span class=\"sk-post-category\"><a href=\"\(self.router.blogListingPath())\">\(self.categoryDisplayName(for: page.category).htmlEscaped)</a></span>")
         }

         if !page.tags.isEmpty {
            let tagLinks = page.tags.prefix(3).map { tag in
               "<li class=\"sk-tag\"><a class=\"sk-tag-link\" href=\"\(self.router.tagPath(for: tag))\">\(self.tagDisplayName(for: tag).htmlEscaped)</a></li>"
            }.joined()
            footerParts.append("<ul class=\"sk-tag-list sk-tag-list-inline\">\(tagLinks)</ul>")
         }

         let footerHTML = footerParts.isEmpty ? "" : "<div class=\"sk-post-footer\">\(footerParts.joined())</div>"

         // The sk-post-link is an invisible overlay making the whole card clickable; give it
         // an accessible name so screen readers + Lighthouse can identify the destination.
         return "<li class=\"sk-post-card\"><a class=\"sk-post-link\" href=\"\(articleURL)\(contextParam)\" aria-label=\"\(page.title.htmlEscaped)\"></a><article>\(cardParts.joined())</article>\(footerHTML)</li>"
      }.joined()

      return "<ul class=\"sk-post-list\">\(items)</ul>"
   }
}
