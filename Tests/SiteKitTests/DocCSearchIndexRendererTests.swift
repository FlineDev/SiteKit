import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSearchIndexRenderer")
struct DocCSearchIndexRendererTests {
   private func context(pageCount: Int) -> BuildContext {
      let pages = (0 ..< pageCount).map { i in
         PageModel(
            title: "Note \(i)",
            slug: "wwdc24-\(i)-note",
            htmlContent: "<p>Body \(i)</p>",
            sourcePath: URL(fileURLWithPath: "/tmp/\(i).md"),
            extensions: ["doccNote": true]
         )
      }
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

   @Test("Shards records and emits a manifest")
   func shardsAndManifest() throws {
      let files = try DocCSearchIndexRenderer(shardSize: 2).render(context: self.context(pageCount: 5))
      // 5 records / shardSize 2 = 3 shards + 1 manifest.
      let shardFiles = files.filter { $0.outputPath.lastPathComponent.hasPrefix("docc-search-") }
      let manifest = try #require(files.first { $0.outputPath.lastPathComponent == "docc-search.json" })
      #expect(shardFiles.count == 3)
      #expect(shardFiles.allSatisfy { $0.outputPath.path.contains("/assets/search/") })

      // Manifest lists the shards and the total count.
      let json = try JSONSerialization.jsonObject(with: Data(manifest.content.utf8)) as? [String: Any]
      #expect(json?["count"] as? Int == 5)
      #expect((json?["shards"] as? [String])?.count == 3)
      #expect((json?["shards"] as? [String])?.first == "/assets/search/docc-search-0.json")
   }

   @Test("Shard JSON decodes back into records with resolved URLs")
   func shardDecodes() throws {
      let files = try DocCSearchIndexRenderer(shardSize: 10).render(context: self.context(pageCount: 2))
      let shard = try #require(files.first { $0.outputPath.lastPathComponent == "docc-search-0.json" })
      let records = try JSONDecoder().decode([DocCSearchRecord].self, from: Data(shard.content.utf8))
      #expect(records.count == 2)
      #expect(records[0].url == "/documentation/wwdc24-0-note/")
      #expect(records[0].text.contains("Body 0"))
   }

   // MARK: - Path resolvers + profile exclusion

   /// One regular session note, the contributor's profile note, and an orphan profile
   /// whose handle never contributed – the DocC shape that exposed 404 URLs in the index.
   private func contributorContext() -> BuildContext {
      let section = SectionConfig(name: "Docs", slug: "documentation", contentDirectory: "Docs", urlPrefix: "documentation")
      let note = PageModel(
         title: "Session A",
         slug: "wwdc24-100-a",
         htmlContent: "<p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc24-100-a.md"),
         extensions: ["doccNote": true, "doccContributors": ["JeeHut"]]
      )
      let profile = PageModel(
         title: "Cihat Gündüz",
         slug: "jeehut",
         htmlContent: "<p>Bio</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/JeeHut.md"),
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
      let orphanProfile = PageModel(
         title: "Ghost",
         slug: "ghost",
         htmlContent: "<p>Gone</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/Ghost.md"),
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
      return BuildContext(
         config: SiteConfig(
            name: "Docs",
            baseURL: "https://example.com",
            sections: [section],
            docc: DocCConfig(contributors: true)
         ),
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: [note, profile, orphanProfile])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   /// Decodes the records of every shard file – the manifest is just a table of contents,
   /// so URL assertions must run against the actual shard records.
   private func allShardRecords(in files: [OutputFile]) throws -> [DocCSearchRecord] {
      try files
         .filter { $0.outputPath.lastPathComponent.hasPrefix("docc-search-") }
         .flatMap { try JSONDecoder().decode([DocCSearchRecord].self, from: Data($0.content.utf8)) }
   }

   /// The ⌘K index is a session-note index: profile notes are consumed by
   /// `DocCContributorPage`, carry no facet data, and their router-derived URL
   /// `/documentation/<handle>/` is a 404 – they must not be indexed at all.
   @Test("Contributor profile notes are not indexed, session notes stay untouched")
   func excludesProfileNotes() throws {
      let files = try DocCSearchIndexRenderer(pathResolvers: [DocCContributorPage()])
         .render(context: self.contributorContext())
      let records = try self.allShardRecords(in: files)

      #expect(!records.contains { $0.url == "/documentation/jeehut/" })
      #expect(!records.contains { $0.url == "/documentation/ghost/" })
      #expect(!records.contains { $0.title == "Cihat Gündüz" || $0.title == "Ghost" })
      // The regular session note keeps its untouched record.
      let session = try #require(records.first { $0.url == "/documentation/wwdc24-100-a/" })
      #expect(session.title == "Session A")
      #expect(records.count == 1)

      // The manifest count matches the actual shard records.
      let manifest = try #require(files.first { $0.outputPath.lastPathComponent == "docc-search.json" })
      let json = try JSONSerialization.jsonObject(with: Data(manifest.content.utf8)) as? [String: Any]
      #expect(json?["count"] as? Int == 1)
   }

   /// Generic path truth: any future page re-homed by its rendering plugin must be
   /// indexed at the path that plugin writes, and a consumed page without an own URL
   /// must drop out – independent of the contributor feature.
   private struct RehomingResolver: PagePathResolving {
      func pathResolution(for page: PageModel, context: BuildContext) -> PagePathResolution {
         switch page.slug {
         case "wwdc24-0-note": return .path("/elsewhere/wwdc24-0-note/")
         case "wwdc24-1-note": return .unpublished
         default: return .routerDefault
         }
      }
   }

   @Test("Re-homed pages are indexed at the resolver path, unpublished pages drop out")
   func appliesGenericPathResolution() throws {
      let files = try DocCSearchIndexRenderer(pathResolvers: [RehomingResolver()])
         .render(context: self.context(pageCount: 3))
      let records = try self.allShardRecords(in: files)

      #expect(records.contains { $0.url == "/elsewhere/wwdc24-0-note/" })
      #expect(!records.contains { $0.url == "/documentation/wwdc24-0-note/" })
      #expect(!records.contains { $0.url.contains("wwdc24-1-note") })
      #expect(records.contains { $0.url == "/documentation/wwdc24-2-note/" })
      #expect(records.count == 2)
   }

   @Test("Emits nothing when there are no DocC pages")
   func noDocCPages() throws {
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
      #expect(try DocCSearchIndexRenderer().render(context: context).isEmpty)
   }
}
