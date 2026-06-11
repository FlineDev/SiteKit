import Foundation
import Testing
@testable import SiteKit

@Suite("SitemapRenderer")
struct SitemapRendererTests {
   // MARK: - Helpers

   private func makeContext(tags: [String: [PageModel]]) -> BuildContext {
      let config = SiteConfig(name: "Test", baseURL: "https://example.com")
      let section = ContentSection(
         config: SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog"),
         pages: [self.makePage(slug: "intro", title: "Intro")]
      )
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [section],
         staticPages: [],
         tags: tags,
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func makePage(slug: String, title: String) -> PageModel {
      PageModel(
         title: title,
         date: Date(timeIntervalSince1970: 1_700_000_000),
         slug: slug,
         htmlContent: "<p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Content/\(slug).md")
      )
   }

   /// Pulls the per-tag slugs (in document order) out of the `/tags/<slug>/` locs,
   /// skipping the bare `/tags/` index entry.
   private func tagSlugs(inSitemap xml: String) -> [String] {
      let locs = xml.components(separatedBy: "<loc>").dropFirst()
         .compactMap { $0.components(separatedBy: "</loc>").first }
      return locs.compactMap { loc -> String? in
         guard let range = loc.range(of: "/tags/") else { return nil }
         let tail = loc[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
         return tail.isEmpty ? nil : tail
      }
   }

   // MARK: - Determinism

   /// Tag entries must be emitted in alphabetical order so the sitemap is byte-stable
   /// across builds. `context.tags` is a Dictionary, whose iteration order is
   /// hash-randomized per run – without an explicit sort the order would vary build
   /// to build (the cause of the spurious sitemap diffs seen during the P2b pilot).
   @Test("Tag entries are emitted in deterministic alphabetical order")
   func tagEntriesSortedDeterministically() throws {
      let page = self.makePage(slug: "intro", title: "Intro")
      let tags: [String: [PageModel]] = [
         "delta": [page], "alpha": [page], "foxtrot": [page],
         "charlie": [page], "echo": [page], "bravo": [page],
      ]
      let context = self.makeContext(tags: tags)

      let files = try SitemapRenderer().render(context: context)
      let sitemap = try #require(files.first { $0.outputPath.lastPathComponent == "sitemap.xml" })

      let tagOrder = self.tagSlugs(inSitemap: sitemap.content)
      #expect(tagOrder == ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot"])
   }

   // MARK: - Path resolvers (outputURL overrides)

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

   private func sitemapXML(resolvers: [any PagePathResolving]) throws -> String {
      let files = try SitemapRenderer(pathResolvers: resolvers).render(context: self.doccContributorContext())
      let sitemap = try #require(files.first { $0.outputPath.lastPathComponent == "sitemap.xml" })
      return sitemap.content
   }

   /// The router derives `/documentation/jeehut/` for the profile note, but nothing writes
   /// that URL – `DocCContributorPage` re-homes the content under `/contributors/<handle>/`.
   /// The sitemap must list the path that actually exists, not the router default.
   @Test("Contributor profile notes are listed at the path the contributor page writes")
   func resolverRemapsConsumedPages() throws {
      let xml = try self.sitemapXML(resolvers: [DocCContributorPage()])
      #expect(xml.contains("<loc>https://example.com/documentation/contributors/jeehut/</loc>"))
      #expect(!xml.contains("<loc>https://example.com/documentation/jeehut/</loc>"))
   }

   @Test("Profile notes whose handle never contributed are omitted entirely")
   func resolverOmitsUnpublishedPages() throws {
      let xml = try self.sitemapXML(resolvers: [DocCContributorPage()])
      #expect(!xml.contains("/documentation/ghost/"))
      #expect(!xml.contains("/documentation/contributors/ghost/"))
   }

   /// The resolver must only touch the pages it claims: remapping the profile note and
   /// dropping the orphan must leave every other byte of the sitemap unchanged.
   @Test("Resolver injection leaves every non-overridden entry byte-identical")
   func resolverKeepsOtherEntriesByteIdentical() throws {
      let without = try self.sitemapXML(resolvers: [])
      let with = try self.sitemapXML(resolvers: [DocCContributorPage()])
      let expected = without
         .replacingOccurrences(
            of: "<loc>https://example.com/documentation/jeehut/</loc>",
            with: "<loc>https://example.com/documentation/contributors/jeehut/</loc>"
         )
         .replacingOccurrences(of: "<url><loc>https://example.com/documentation/ghost/</loc></url>", with: "")
      #expect(with == expected)
   }
}
