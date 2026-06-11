import Foundation
import Testing
@testable import SiteKit

@Suite("URLRouter")
struct URLRouterTests {
   /// Bare-bones conformance proves the protocol no longer requires snippet helpers.
   private struct MinimalRouter: URLRouter {
      func articlePath(for page: PageModel) -> String { "/article/\(page.slug)/" }
      func categoryPath(for category: CategoryConfig) -> String { "/\(category.slug)/" }
      func tagPath(for tag: String) -> String { "/tags/\(tag)/" }
      func tagsIndexPath() -> String { "/tags/" }
      func staticPagePath(for page: PageModel) -> String { "/\(page.slug)/" }
      func blogListingPath() -> String { "/blog/" }
      func homePath() -> String { "/" }
      func pagePath(for page: PageModel, in section: SectionConfig) -> String {
         "/\(section.urlPrefix)/\(page.slug)/"
      }
      func sectionListingPath(for section: SectionConfig) -> String {
         "/\(section.urlPrefix)/"
      }
   }

   @Test("URLRouter protocol can be conformed without snippet helpers")
   func protocolConformsWithoutSnippetHelpers() {
      let router: any URLRouter = MinimalRouter()
      let section = SectionConfig(name: "Learning Paths", slug: "learning-paths", contentDirectory: "LearningPaths", urlPrefix: "learning-paths")
      let page = PageModel(title: "Lesson", slug: "lesson-1", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/x.md"))
      #expect(router.pagePath(for: page, in: section) == "/learning-paths/lesson-1/")
      #expect(router.sectionListingPath(for: section) == "/learning-paths/")
   }

   @Test("DefaultURLRouter pagePath honors a section's urlPrefix")
   func defaultRouterUsesSectionPrefix() {
      let config = SiteConfig(name: "T", baseURL: "https://example.com")
      let router = DefaultURLRouter(config: config)
      let section = SectionConfig(name: "Notes", slug: "notes", contentDirectory: "Notes", urlPrefix: "notes")
      let page = PageModel(title: "First", slug: "first", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/x.md"))
      #expect(router.pagePath(for: page, in: section) == "/notes/first/")
      #expect(router.sectionListingPath(for: section) == "/notes/")
   }

   @Test("LocaleAwareURLRouter prefixes non-default-language section paths")
   func localeAwareSectionPaths() {
      let config = SiteConfig(name: "T", baseURL: "https://example.com")
      let inner = DefaultURLRouter(config: config)
      let router = LocaleAwareURLRouter(wrapping: inner, locale: "de", defaultLanguage: "en")
      let section = SectionConfig(name: "Notes", slug: "notes", contentDirectory: "Notes", urlPrefix: "notes")
      let page = PageModel(title: "First", slug: "first", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/x.md"))
      #expect(router.pagePath(for: page, in: section) == "/de/notes/first/")
      #expect(router.sectionListingPath(for: section) == "/de/notes/")
   }
}
