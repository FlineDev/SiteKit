import Foundation
import Testing

@testable import SiteKit

@Suite("NavIndexRenderer")
struct NavIndexRendererTests {
   // MARK: - Helpers

   /// A DocC-shaped context: one session note with a contributor, the contributor's
   /// profile note (consumed by `DocCContributorPage` and re-homed under
   /// `/documentation/contributors/jeehut/`), and an orphan profile whose handle never
   /// contributed (so no detail page exists anywhere).
   private func doccContributorContext() -> BuildContext {
      let sectionConfig = SectionConfig(
         name: "Documentation",
         slug: "documentation",
         contentDirectory: "Documentation.docc",
         urlPrefix: "documentation"
      )
      let note = PageModel(
         title: "Session A",
         date: Date(timeIntervalSince1970: 1_700_000_000),
         slug: "wwdc24-100-a",
         htmlContent: "<p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Documentation.docc/wwdc24-100-a.md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributors": ["JeeHut"]]
      )
      let profile = PageModel(
         title: "Cihat Gündüz",
         slug: "jeehut",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Documentation.docc/Contributors/JeeHut.md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
      let orphanProfile = PageModel(
         title: "Ghost",
         slug: "ghost",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Documentation.docc/Contributors/Ghost.md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
      return BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            sections: [sectionConfig],
            docc: DocCConfig(contributors: true)
         ),
         themeConfig: nil,
         sections: [ContentSection(config: sectionConfig, pages: [note, profile, orphanProfile])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func indexEntries(
      resolvers: [any PagePathResolving]
   ) throws -> (nav: [[String: Any]], search: [[String: Any]]) {
      let files = try NavIndexRenderer(pathResolvers: resolvers).render(context: self.doccContributorContext())
      let navFile = try #require(files.first { $0.outputPath.lastPathComponent == "nav-index.json" })
      let searchFile = try #require(files.first { $0.outputPath.lastPathComponent == "search-index.json" })
      let navWrapper = try #require(
         try JSONSerialization.jsonObject(with: Data(navFile.content.utf8)) as? [String: Any]
      )
      let nav = try #require(navWrapper["articles"] as? [[String: Any]])
      let search = try #require(
         try JSONSerialization.jsonObject(with: Data(searchFile.content.utf8)) as? [[String: Any]]
      )
      return (nav: nav, search: search)
   }

   // MARK: - Path resolvers (outputURL overrides)

   /// Both indexes must carry the URL `DocCContributorPage` actually writes for a
   /// consumed profile note, not the router default `/documentation/<handle>/`
   /// that nothing serves.
   @Test("Contributor profile entries carry the path the contributor page writes")
   func resolverRemapsConsumedPages() throws {
      let entries = try self.indexEntries(resolvers: [DocCContributorPage()])

      let navProfile = try #require(entries.nav.first { $0["slug"] as? String == "jeehut" })
      #expect(navProfile["url"] as? String == "/documentation/contributors/jeehut/")
      let searchProfile = try #require(entries.search.first { $0["slug"] as? String == "jeehut" })
      #expect(searchProfile["url"] as? String == "/documentation/contributors/jeehut/")

      #expect(!entries.nav.contains { $0["url"] as? String == "/documentation/jeehut/" })
      #expect(!entries.search.contains { $0["url"] as? String == "/documentation/jeehut/" })
   }

   @Test("Profile notes whose handle never contributed are omitted from both indexes")
   func resolverOmitsUnpublishedPages() throws {
      let entries = try self.indexEntries(resolvers: [DocCContributorPage()])
      #expect(!entries.nav.contains { $0["slug"] as? String == "ghost" })
      #expect(!entries.search.contains { $0["slug"] as? String == "ghost" })
   }

   /// The resolver must only touch the pages it claims: every entry besides the remapped
   /// profile and the dropped orphan must come out structurally identical (the JSON is
   /// serialized with sorted keys, so structural equality implies byte equality).
   @Test("Resolver injection leaves every non-overridden entry identical")
   func resolverKeepsOtherEntriesIdentical() throws {
      let with = try self.indexEntries(resolvers: [DocCContributorPage()])
      let without = try self.indexEntries(resolvers: [])

      func expected(from entries: [[String: Any]]) -> [[String: Any]] {
         entries
            .filter { $0["slug"] as? String != "ghost" }
            .map { entry in
               var entry = entry
               if entry["slug"] as? String == "jeehut" {
                  entry["url"] = "/documentation/contributors/jeehut/"
               }
               return entry
            }
      }

      #expect(NSArray(array: with.nav) == NSArray(array: expected(from: without.nav)))
      #expect(NSArray(array: with.search) == NSArray(array: expected(from: without.search)))
   }
}
