import Foundation
import Testing
@testable import SiteKit

@Suite("StaticPageLoader")
struct StaticPageLoaderTests {
   // MARK: - Helpers

   private func source(filename: String = "about.md", content: String) -> MarkdownSource {
      let url = URL(fileURLWithPath: "/tmp/Content/Pages/\(filename)")
      return MarkdownSource(filePath: url, content: content)
   }

   // MARK: - Default required fields

   @Test("Default required fields enforce title and slug")
   func defaultRequiresTitleAndSlug() throws {
      let loader = StaticPageLoader()
      let withoutTitle = """
      ---
      slug: about
      ---
      Body
      """
      let withoutSlug = """
      ---
      title: About
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(content: withoutTitle))
      }
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(content: withoutSlug))
      }
   }

   @Test("Loads a valid static page")
   func loadsValidStaticPage() throws {
      let loader = StaticPageLoader()
      let content = """
      ---
      title: About
      slug: about
      description: About this site
      ---
      ## Hello
      Body content.
      """
      let page = try loader.load(source: self.source(content: content))
      #expect(page.title == "About")
      #expect(page.slug == "about")
      #expect(page.description == "About this site")
      #expect(page.pageType == .staticPage)
   }

   // MARK: - Error shape parity with MarkdownLoader

   @Test("Error message format matches MarkdownLoader shape (path:line:field)")
   func errorMessageMatchesMarkdownLoaderShape() {
      let loader = StaticPageLoader()
      let content = """
      ---
      slug: about
      ---
      Body
      """
      do {
         _ = try loader.load(source: self.source(content: content))
         Issue.record("expected throw")
      } catch let error as MarkdownLoaderError {
         let description = error.errorDescription
         #expect(description?.contains("/tmp/Content/Pages/about.md") == true)
         #expect(description?.contains("required frontmatter field 'title'") == true)
      } catch {
         Issue.record("expected MarkdownLoaderError, got \(error)")
      }
   }

   // MARK: - Custom required fields

   @Test("Custom required fields enforce extra field")
   func customRequiredFieldEnforced() {
      let loader = StaticPageLoader(requiredFields: ["title", "slug", "description"])
      let content = """
      ---
      title: About
      slug: about
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(content: content))
      }
   }

   @Test("Empty required fields accepts frontmatter without title or slug")
   func emptyRequiredFieldsAccepts() throws {
      let loader = StaticPageLoader(requiredFields: [])
      let content = """
      ---
      placeholder: x
      ---
      Body
      """
      let page = try loader.load(source: self.source(content: content))
      #expect(page.title == "")
      #expect(page.slug == "")
   }
}
