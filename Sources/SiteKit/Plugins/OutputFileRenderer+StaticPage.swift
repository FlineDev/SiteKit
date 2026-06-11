import Foundation

extension OutputFileRenderer {
   public func renderStaticPage(_ page: PageModel) -> OutputFile {
      let pageTitle = "\(page.title) – \(self.config.name)"

      let hreflangMap: [String: String]? = page.extensionValue("hreflang")

      let head = self.buildHead(
         title: pageTitle,
         description: page.description,
         canonicalURL: "\(self.config.baseURL)\(self.router.staticPagePath(for: page))",
         ogType: "website",
         image: page.image,
         hreflang: hreflangMap
      )

      var articleParts: [String] = [
         "<header class=\"sk-article-header\"><h1 class=\"sk-article-title\">\(page.title.htmlEscaped)</h1></header>",
      ]

      // Legal notice for translated legal documents
      if let noticeHTML = self.renderLegalNotice(for: page, hreflangMap: hreflangMap) {
         articleParts.append(noticeHTML)
      }

      articleParts.append("<div class=\"sk-article-body\">\(page.htmlContent)</div>")

      let mainContent = "<main class=\"sk-main\"><article class=\"sk-static-page\" data-slug=\"\(page.slug)\">\(articleParts.joined())</article></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-static",
         dataAttributes: ["data-slug": page.slug],
         content: mainContent
      )

      let relativePath = String(self.router.staticPagePath(for: page).dropFirst())
      let outputPath = self.outputDirectory
         .appendingPathComponent(relativePath)
         .appendingPathComponent("index.html")

      return OutputFile(outputPath: outputPath, content: html)
   }

   private func renderLegalNotice(for page: PageModel, hreflangMap: [String: String]?) -> String? {
      guard page.legalDocument else { return nil }

      let legalLang = self.config.effectiveLegalLanguage

      // Don't show notice on the legally binding version itself
      guard page.locale != legalLang else { return nil }

      // Look up localized language name for the legal language
      let langNameKey = "langName\(legalLang.prefix(1).uppercased())\(legalLang.dropFirst())"
      let langName = self.uiStrings.string(forRawKey: langNameKey) ?? legalLang

      // Find legal-language page path from hreflang map
      let absoluteURL = hreflangMap?[legalLang] ?? ""
      let relativePath = absoluteURL.hasPrefix(self.config.baseURL)
         ? String(absoluteURL.dropFirst(self.config.baseURL.count))
         : absoluteURL
      let legalURL = relativePath.isEmpty ? "" : "\(relativePath)?noredirect"

      // Build the language name – wrap it in a link if URL is available
      let langNameHTML: String
      if !legalURL.isEmpty {
         langNameHTML = "<a class=\"sk-translation-notice-link\" href=\"\(legalURL)\">\(langName.htmlEscaped)</a>"
      } else {
         langNameHTML = langName.htmlEscaped
      }

      // Substitute the linked language name into the localized notice template
      let noticeTemplate = self.uiStrings.string(for: .legalNotice, args: "%@")
      let noticeHTML = noticeTemplate.htmlEscaped.replacing("%@", with: langNameHTML)

      let parts: [String] = [
         "<i class=\"fa-solid fa-scale-balanced\" aria-hidden=\"true\"></i>",
         "<span>\(noticeHTML)</span>",
      ]

      return "<aside class=\"sk-translation-notice\">\(parts.joined())</aside>"
   }
}
