import Testing
@testable import SiteKit

@Suite("FrontmatterParser")
struct FrontmatterParserTests {
   @Test("Parses valid frontmatter with title")
   func validFrontmatter() throws {
      let content = "---\ntitle: \"Hello World\"\n---\nBody content here."
      let result = try FrontmatterParser.parse(from: content)
      #expect(result.metadata["title"] as? String == "Hello World")
      #expect(result.body == "Body content here.")
   }

   @Test("Parses multiple frontmatter fields")
   func multipleFields() throws {
      let content = """
      ---
      title: "Test Post"
      category: "developer"
      draft: true
      ---
      Body
      """
      let result = try FrontmatterParser.parse(from: content)
      #expect(result.metadata["title"] as? String == "Test Post")
      #expect(result.metadata["category"] as? String == "developer")
      #expect(result.metadata["draft"] as? Bool == true)
   }

   @Test("Throws on missing frontmatter delimiters")
   func missingDelimiters() {
      let content = "No frontmatter here"
      #expect(throws: FrontmatterParserError.self) {
         try FrontmatterParser.parse(from: content)
      }
   }

   @Test("Throws on unclosed frontmatter")
   func unclosedFrontmatter() {
      let content = """
      ---
      title: "Unclosed"
      Body without closing delimiter
      """
      #expect(throws: FrontmatterParserError.self) {
         try FrontmatterParser.parse(from: content)
      }
   }

   @Test("Handles empty body after frontmatter")
   func emptyBody() throws {
      let content = "---\ntitle: \"Empty Body\"\n---\n"
      let result = try FrontmatterParser.parse(from: content)
      #expect(result.metadata["title"] as? String == "Empty Body")
      #expect(result.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
   }

   @Test("Parses tags as list")
   func tagsList() throws {
      let content = """
      ---
      title: "Tagged"
      tags:
        - swift
        - ios
      ---
      Content
      """
      let result = try FrontmatterParser.parse(from: content)
      let tags = result.metadata["tags"] as? [String]
      #expect(tags == ["swift", "ios"])
   }
}
