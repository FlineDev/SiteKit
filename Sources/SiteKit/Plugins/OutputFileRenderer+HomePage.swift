import Foundation

extension OutputFileRenderer {
   public func renderHomePage(recentPosts: [PageModel], homeContent: String? = nil) -> OutputFile {
      let locale = self.uiStrings.locale
      let localeOverride = self.config.localization?.localeOverrides?[locale]
      let homeConfig = localeOverride?.homePage ?? self.config.homePage
      let title = homeConfig?.title ?? self.config.name
      // PageModel title includes subtitle for richer social sharing previews
      let pageTitle: String
      if let homeTitle = homeConfig?.title, let subtitle = homeConfig?.subtitle {
         pageTitle = "\(homeTitle) – \(subtitle)"
      } else {
         pageTitle = homeConfig?.title ?? self.config.name
      }
      let pageDescription = localeOverride?.description ?? self.config.description

      let homePath = self.router.homePath()
      let hreflang = self.buildHreflangForAllLanguages { $0.homePath() }
      // Note: we deliberately DO NOT preload a post-card image here. On many home pages
      // the LCP is text (hero title) or custom content (profile intro, app cards), not
      // a post image. Preloading an image that isn't the LCP wastes bandwidth on slow
      // networks. The first card image still gets `fetchpriority="high"` in the body,
      // which helps when it *is* the LCP without hurting when it isn't.
      let head = self.buildHead(
         title: pageTitle,
         description: pageDescription,
         canonicalURL: self.config.baseURL + homePath,
         ogType: "website",
         rssFeedURL: "\(homePath.hasSuffix("/") ? String(homePath.dropLast()) : homePath)/feed.xml",
         rssFeedTitle: self.config.name,
         jsonLD: self.buildWebSiteJSONLD(),
         hreflang: hreflang
      )

      var heroParts: [String] = [
         "<h1 class=\"sk-home-title\">\(title.htmlEscaped)</h1>"
      ]

      if let subtitle = homeConfig?.subtitle {
         heroParts.append("<p class=\"sk-home-subtitle\">\(subtitle.htmlEscaped)</p>")
      }

      var mainParts: [String] = [
         "<section class=\"sk-home-hero\">\(heroParts.joined())</section>"
      ]

      if let homeContent, !homeContent.isEmpty {
         mainParts.append("<div class=\"sk-home-content\">\(homeContent)</div>")
      }

      if !recentPosts.isEmpty {
         let count = homeConfig?.recentPostsCount ?? 5
         let posts = Array(recentPosts.sortedByDate().prefix(count))

         mainParts.append(
            "<section class=\"sk-home-recent\"><h2 class=\"sk-home-section-title\">\(self.uiStrings.string(for: .recentPosts).htmlEscaped)</h2>\(self.articleList(posts))<p class=\"sk-home-all-posts\"><a href=\"\(self.router.blogListingPath())\">\(self.uiStrings.string(for: .viewAllPosts).htmlEscaped) →</a></p></section>"
         )
      }

      let mainContent = "<main class=\"sk-main\">\(mainParts.joined())</main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-home",
         content: mainContent
      )

      let relativePath = String(homePath.dropFirst())  // "" or "de/"
      let outputPath = self.outputDirectory
         .appendingPathComponent(relativePath)
         .appendingPathComponent("index.html")
      return OutputFile(outputPath: outputPath, content: html)
   }
}
