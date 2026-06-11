import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSidebarNavRenderer")
struct DocCSidebarNavRendererTests {
   /// A small synthetic 2-year DocC catalog: WWDC25 (one flat session) and WWDC24 (a topic
   /// group + a stub session with no framework), plus two loose pages (Contributors index +
   /// Contributing) that must never appear as year keys in the nav JSON.
   private func context() -> BuildContext {
      let pages: [PageModel] = [
         PageModel(title: "WWDC25", slug: "wwdc25", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/wwdc25.md"), extensions: ["doccNote": true]),
         PageModel(title: "Session A", slug: "wwdc25-1-a", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/a.md"), extensions: ["doccNote": true, "doccFramework": "swiftui"]),
         PageModel(
            title: "WWDC24",
            slug: "wwdc24",
            htmlContent: "",
            sourcePath: URL(fileURLWithPath: "/tmp/wwdc24.md"),
            extensions: ["doccNote": true, "doccTopicGroups": [DocCTopicGroup(title: "Essentials", slugs: ["wwdc24-101-foo"])]]
         ),
         PageModel(title: "Foo", slug: "wwdc24-101-foo", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/foo.md"), extensions: ["doccNote": true, "doccFramework": "swiftui", "doccIsStub": false]),
         PageModel(title: "Bar", slug: "wwdc24-102-bar", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/bar.md"), extensions: ["doccNote": true, "doccIsStub": true]),
         PageModel(title: "Contributors", slug: "contributors", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/contributors.md"), extensions: ["doccNote": true]),
         PageModel(title: "Contributing", slug: "contributing", htmlContent: "", sourcePath: URL(fileURLWithPath: "/tmp/contributing.md"), extensions: ["doccNote": true]),
      ]
      let section = SectionConfig(name: "Docs", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation")
      return BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com", sections: [section]),
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: pages)],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   /// Parses the single emitted nav JSON file into a dictionary, failing the test if absent.
   private func navJSON() throws -> [String: Any] {
      let files = try DocCSidebarNavRenderer().render(context: self.context())
      let file = try #require(files.first { $0.outputPath.lastPathComponent == "docc-sidebar-nav.json" })
      #expect(file.outputPath.path.contains("/assets/"))
      let object = try JSONSerialization.jsonObject(with: Data(file.content.utf8))
      return try #require(object as? [String: Any])
   }

   @Test("Emits one parseable JSON file under /assets")
   func emitsParseableFile() throws {
      let files = try DocCSidebarNavRenderer().render(context: self.context())
      #expect(files.count == 1)
      let file = try #require(files.first)
      #expect(file.outputPath.path.hasSuffix("assets/docc-sidebar-nav.json"))
      // Round-trips as JSON.
      #expect((try? JSONSerialization.jsonObject(with: Data(file.content.utf8))) != nil)
   }

   @Test("The renderer is global (one file per build, locale-agnostic)")
   func scopeIsGlobal() {
      #expect(DocCSidebarNavRenderer().scope == .global)
   }

   @Test("Every year branch is a key; loose pages and Contributors are not")
   func yearKeysOnly() throws {
      let json = try self.navJSON()
      #expect(json["wwdc25"] != nil)
      #expect(json["wwdc24"] != nil)
      // Contributors is always server-rendered, never hydrated → not a key. Loose articles
      // (the Contributors index, Contributing) are not years and must be absent too.
      #expect(json["contributors"] == nil)
      #expect(json["contributing"] == nil)
      #expect(json.keys.count == 2)
   }

   @Test("Each session carries title, url, framework and isStub")
   func sessionFields() throws {
      let json = try self.navJSON()
      let wwdc24 = try #require(json["wwdc24"] as? [String: Any])
      let sessions = try #require(wwdc24["sessions"] as? [String: Any])

      let foo = try #require(sessions["wwdc24-101-foo"] as? [String: Any])
      #expect(foo["title"] as? String == "Foo")
      #expect(foo["url"] as? String == "/documentation/wwdc24-101-foo/")
      #expect(foo["framework"] as? String == "swiftui")
      #expect(foo["isStub"] as? Bool == false)

      // The stub session carries a JSON null framework (key present, value null) + isStub true.
      let bar = try #require(sessions["wwdc24-102-bar"] as? [String: Any])
      #expect(bar["title"] as? String == "Bar")
      #expect(bar["framework"] is NSNull)
      #expect(bar["isStub"] as? Bool == true)
   }

   @Test("Topic groups are preserved in order with their slugs")
   func topicGroupsPreserved() throws {
      let json = try self.navJSON()
      let wwdc24 = try #require(json["wwdc24"] as? [String: Any])
      let groups = try #require(wwdc24["groups"] as? [[String: Any]])
      #expect(groups.count == 1)
      #expect(groups[0]["title"] as? String == "Essentials")
      #expect(groups[0]["slugs"] as? [String] == ["wwdc24-101-foo"])
   }

   @Test("A year without topic groups emits an empty groups array")
   func flatYearHasEmptyGroups() throws {
      let json = try self.navJSON()
      let wwdc25 = try #require(json["wwdc25"] as? [String: Any])
      let groups = try #require(wwdc25["groups"] as? [[String: Any]])
      #expect(groups.isEmpty)
      let sessions = try #require(wwdc25["sessions"] as? [String: Any])
      #expect(sessions["wwdc25-1-a"] != nil)
   }

   @Test("Output is deterministic across renders (sorted keys)")
   func deterministicOutput() throws {
      let renderer = DocCSidebarNavRenderer()
      let first = try renderer.render(context: self.context()).first?.content
      let second = try renderer.render(context: self.context()).first?.content
      #expect(first == second)
   }

   @Test("Emits an empty object when there are no DocC pages")
   func emptyWhenNoDocCPages() throws {
      let context = BuildContext(
         config: SiteConfig(name: "Docs", baseURL: "https://example.com"),
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let files = try DocCSidebarNavRenderer().render(context: context)
      let file = try #require(files.first)
      let json = try JSONSerialization.jsonObject(with: Data(file.content.utf8)) as? [String: Any]
      #expect(json?.isEmpty == true)
   }
}
