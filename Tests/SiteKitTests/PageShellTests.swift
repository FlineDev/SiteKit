import Foundation
import Testing
@testable import SiteKit

@Suite("PageShell")
struct PageShellTests {
   // MARK: - Helpers

   private func makeContext() -> BuildContext {
      let config = SiteConfig(name: "Test", baseURL: "https://example.com")
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func makeArticlePage() -> PageModel {
      PageModel(
         title: "Hello",
         date: Date(timeIntervalSince1970: 1_700_000_000),
         slug: "hello",
         htmlContent: "<p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Content/Blog/2026-01-01-hello.md"),
         pageType: .article
      )
   }

   private func makeStaticPage() -> PageModel {
      PageModel(
         title: "About",
         slug: "about",
         htmlContent: "<p>Hi</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Content/Pages/about.md"),
         pageType: .staticPage
      )
   }

   // MARK: - Canonical URL dispatched by pageType

   @Test("Article PageModel produces an articlePath canonical URL")
   func articleCanonicalUsesArticlePath() {
      let html = PageShell.wrap(
         content: "<main>body</main>",
         page: self.makeArticlePage(),
         context: self.makeContext()
      )
      // DefaultURLRouter's articlePath for a default Blog section
      #expect(html.contains("<link rel=\"canonical\" href=\"https://example.com/blog/hello/\""))
   }

   @Test("Static PageModel produces a staticPagePath canonical URL")
   func staticPageCanonicalUsesStaticPagePath() {
      let html = PageShell.wrap(
         content: "<main>body</main>",
         page: self.makeStaticPage(),
         context: self.makeContext()
      )
      // DefaultURLRouter's staticPagePath: /<slug>/
      #expect(html.contains("<link rel=\"canonical\" href=\"https://example.com/about/\""))
      #expect(!html.contains("/blog/about/"))
   }

   // MARK: - JSON-LD dispatched by pageType

   @Test("Article PageModel emits BlogPosting JSON-LD")
   func articleEmitsBlogPostingJSONLD() {
      let html = PageShell.wrap(
         content: "<main>body</main>",
         page: self.makeArticlePage(),
         context: self.makeContext()
      )
      #expect(html.contains("<script type=\"application/ld+json\">"))
      #expect(html.contains("\"@type\":\"BlogPosting\""))
      // JSONSerialization escapes forward slashes; match the escaped form.
      #expect(html.contains("\"url\":\"https:\\/\\/example.com\\/blog\\/hello\\/\""))
   }

   @Test("Static PageModel emits WebPage JSON-LD")
   func staticPageEmitsWebPageJSONLD() {
      let html = PageShell.wrap(
         content: "<main>body</main>",
         page: self.makeStaticPage(),
         context: self.makeContext()
      )
      #expect(html.contains("<script type=\"application/ld+json\">"))
      #expect(html.contains("\"@type\":\"WebPage\""))
      #expect(html.contains("\"url\":\"https:\\/\\/example.com\\/about\\/\""))
   }

   // MARK: - Chrome mode (additive opt-in)

   /// A context whose config actually produces a site header (nav items) + footer,
   /// so the standard-vs-appShell difference is observable.
   private func makeChromeContext() -> BuildContext {
      let config = SiteConfig(
         name: "Test",
         baseURL: "https://example.com",
         navigation: NavigationConfig(items: [NavigationItemConfig(title: "Home", url: "/")]),
         footer: FooterConfig(links: [NavigationItemConfig(title: "Imprint", url: "/imprint/")])
      )
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   @Test("Default chrome keeps the generic site header + footer")
   func standardChromeKeepsSiteChrome() {
      let html = PageShell.wrap(
         content: "<main>body</main>",
         page: self.makeArticlePage(),
         context: self.makeChromeContext()
      )
      #expect(html.contains("sk-site-header"))
      #expect(html.contains("sk-site-footer"))
      #expect(html.contains("id=\"main-content\""))
   }

   @Test("appShell chrome suppresses the generic site header + footer (page owns its chrome)")
   func appShellChromeSuppressesSiteChrome() {
      let page = self.makeArticlePage()
      let context = self.makeChromeContext()
      // Same context, both modes: standard emits the chrome, appShell strips it.
      let standard = PageShell.wrap(content: "<main>body</main>", page: page, context: context)
      let appShell = PageShell.wrap(content: "<main>body</main>", page: page, context: context, chrome: .appShell)

      #expect(standard.contains("sk-site-header") && standard.contains("sk-site-footer"))
      #expect(!appShell.contains("sk-site-header"))
      #expect(!appShell.contains("sk-site-footer"))
      // The skip link + main-content wrapper + body still ship in appShell mode.
      #expect(appShell.contains("id=\"main-content\""))
      #expect(appShell.contains("<main>body</main>"))
      #expect(appShell.contains("sk-skip-link"))
   }
}
