import Foundation

extension OutputFileRenderer {
   public func render404Page() -> OutputFile {
      let errorConfig = self.config.errorPages?["404"]
      let title = errorConfig?.title ?? self.uiStrings.string(for: .pageNotFound)
      let message = errorConfig?.message ?? self.uiStrings.string(for: .pageNotFoundMessage)
      let pageTitle = "\(title) – \(self.config.name)"

      let hreflang: [String: String]? = self.config.isMultilingual ? {
         let defaultLang = self.config.effectiveDefaultLanguage
         var map: [String: String] = [:]
         for locale in self.config.allLanguages {
            let path = locale == defaultLang ? "/404.html" : "/\(locale)/404.html"
            map[locale] = "\(self.config.baseURL)\(path)"
         }
         if let defaultURL = map[defaultLang] { map["x-default"] = defaultURL }
         return map
      }() : nil

      let head = self.buildHead(title: pageTitle, hreflang: hreflang)

      let mainContent = "<main class=\"sk-main\"><div class=\"sk-error-page\"><h1 class=\"sk-error-code\">\(self.uiStrings.string(for: .errorCode404).htmlEscaped)</h1><p class=\"sk-error-message\">\(message.htmlEscaped)</p><p class=\"sk-error-action\"><a href=\"\(self.router.homePath())\">← \(self.uiStrings.string(for: .goToHomePage).htmlEscaped)</a></p></div></main>"

      let html = self.renderPageShell(
         head: head,
         bodyClass: "sk-page-error",
         content: mainContent
      )

      let locale = self.uiStrings.locale
      let defaultLang = self.config.effectiveDefaultLanguage
      let outputPath: URL
      if locale == defaultLang {
         outputPath = self.outputDirectory.appendingPathComponent("404.html")
      } else {
         outputPath = self.outputDirectory.appendingPathComponent(locale).appendingPathComponent("404.html")
      }
      return OutputFile(outputPath: outputPath, content: html)
   }
}
