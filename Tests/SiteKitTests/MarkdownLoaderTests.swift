import Foundation
import Testing
@testable import SiteKit

@Suite("MarkdownLoader")
struct MarkdownLoaderTests {
   // MARK: - Helpers

   private func source(filename: String = "2026-01-01-test.md", content: String) -> MarkdownSource {
      let url = URL(fileURLWithPath: "/tmp/Content/Blog/\(filename)")
      return MarkdownSource(filePath: url, content: content)
   }

   // MARK: - Default required fields

   @Test("Default requiredFields enforce title")
   func defaultRequiresTitle() {
      let loader = MarkdownLoader()
      let content = """
      ---
      date: 2026-01-01
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(filename: "untitled.md", content: content))
      }
   }

   @Test("Default requiredFields enforce date when filename has no date prefix")
   func defaultRequiresDateWhenFilenameLacksDate() {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: Hello
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(filename: "hello.md", content: content))
      }
   }

   @Test("date requirement satisfied by filename date prefix")
   func dateSatisfiedByFilename() throws {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: Hello
      ---
      Body
      """
      let page = try loader.load(source: self.source(filename: "2026-01-01-hello.md", content: content))
      #expect(page.title == "Hello")
      #expect(page.date != nil)
   }

   // MARK: - Custom required fields

   @Test("Custom requiredFields enforce extra field")
   func customRequiredFieldEnforced() {
      let loader = MarkdownLoader(requiredFields: ["title", "date", "category"])
      let content = """
      ---
      title: Hello
      date: 2026-01-01
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(content: content))
      }
   }

   @Test("Custom requiredFields pass when all present")
   func customRequiredFieldPasses() throws {
      let loader = MarkdownLoader(requiredFields: ["title", "date", "category"])
      let content = """
      ---
      title: Hello
      date: 2026-01-01
      category: tech
      ---
      Body
      """
      let page = try loader.load(source: self.source(content: content))
      #expect(page.category == "tech")
   }

   // MARK: - Empty requiredFields

   @Test("Empty requiredFields accepts minimal frontmatter")
   func emptyRequiredFieldsAccepts() throws {
      let loader = MarkdownLoader(requiredFields: [])
      let content = """
      ---
      placeholder: x
      ---
      Body
      """
      let page = try loader.load(source: self.source(filename: "anything.md", content: content))
      #expect(page.title == "")
      #expect(page.date == nil)
   }

   // MARK: - Empty-string rejection

   @Test("Empty-string title rejected as missing")
   func emptyStringTitleRejected() {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: "   "
      date: 2026-01-01
      ---
      Body
      """
      #expect(throws: MarkdownLoaderError.self) {
         try loader.load(source: self.source(content: content))
      }
   }

   // MARK: - Error message format

   @Test("Error message format matches spec for missing field")
   func errorMessageFormat() throws {
      let loader = MarkdownLoader(requiredFields: ["title", "date", "audioURL"])
      let content = """
      ---
      title: Episode 1
      date: 2026-01-01
      ---
      Body
      """
      let url = URL(fileURLWithPath: "/Content/Episodes/2026-01-01-ep1.md")
      let source = MarkdownSource(filePath: url, content: content)

      do {
         _ = try loader.load(source: source)
         Issue.record("expected throw")
      } catch let error as MarkdownLoaderError {
         #expect(
            error.errorDescription == "Error: /Content/Episodes/2026-01-01-ep1.md:2: required frontmatter field 'audioURL' is missing or empty"
         )
      }
   }

   @Test("Error message uses provided frontmatterStartLine when set")
   func errorMessageHonorsStartLine() throws {
      let loader = MarkdownLoader(requiredFields: ["category"])
      let content = """
      ---
      title: Hi
      date: 2026-01-01
      ---
      Body
      """
      let url = URL(fileURLWithPath: "/Content/Blog/2026-01-01-hi.md")
      let source = MarkdownSource(filePath: url, content: content, frontmatterStartLine: 7)

      do {
         _ = try loader.load(source: source)
         Issue.record("expected throw")
      } catch let error as MarkdownLoaderError {
         #expect(error.errorDescription?.contains(":7:") == true)
      }
   }

   // MARK: - Frontmatter slug override

   @Test("Frontmatter slug overrides filename-derived slug")
   func slugFrontmatterOverridesFilename() throws {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: Original Title
      slug: my-custom-slug
      ---
      Body
      """
      let page = try loader.load(source: self.source(filename: "2026-01-01-filename-slug.md", content: content))
      #expect(page.slug == "my-custom-slug")
   }

   @Test("Frontmatter slug overrides title slugification when filename has no date prefix")
   func slugFrontmatterOverridesTitleSlugification() throws {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: AsyncMutex one-liner
      date: 2026-04-12
      slug: async-mutex-one-liner
      ---
      Body
      """
      let page = try loader.load(source: self.source(filename: "anything.md", content: content))
      #expect(page.slug == "async-mutex-one-liner")
   }

   @Test("Frontmatter slug does not leak into extensions when honored as primary slug")
   func slugNotInExtensionsWhenHonored() throws {
      let loader = MarkdownLoader()
      let content = """
      ---
      title: X
      date: 2026-01-01
      slug: explicit-slug
      ---
      Body
      """
      let page = try loader.load(source: self.source(filename: "anything.md", content: content))
      #expect(page.slug == "explicit-slug")
      #expect(page.extensions["slug"] == nil)
   }
}
