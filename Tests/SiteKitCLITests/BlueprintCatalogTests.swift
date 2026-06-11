import Foundation
import Testing
@testable import SiteKitCLI

@Suite("BlueprintCatalog")
struct BlueprintCatalogTests {
   /// Builds a fake catalog with two paired blueprints and one unpaired directory.
   private func makeFakeCatalog() throws -> URL {
      let manager = FileManager.default
      let catalog = manager.temporaryDirectory.appendingPathComponent("sitekit-catalog-\(UUID().uuidString)")
      try manager.createDirectory(at: catalog.appendingPathComponent("Blog"), withIntermediateDirectories: true)
      try manager.createDirectory(at: catalog.appendingPathComponent("Podcast"), withIntermediateDirectories: true)
      // A directory with no paired .md must be ignored.
      try manager.createDirectory(at: catalog.appendingPathComponent("Orphan"), withIntermediateDirectories: true)

      try "# Blueprint: Blog\n\n**A full-featured blog.**\n"
         .write(to: catalog.appendingPathComponent("Blog.md"), atomically: true, encoding: .utf8)
      try "# Blueprint: Podcast\n\n**A podcast website.**\n"
         .write(to: catalog.appendingPathComponent("Podcast.md"), atomically: true, encoding: .utf8)
      return catalog
   }

   @Test("Lists only directories that have a paired <Name>.md, sorted by name")
   func listsPairedBlueprints() throws {
      let manager = FileManager.default
      let catalog = try makeFakeCatalog()
      defer { try? manager.removeItem(at: catalog) }

      let blueprints = try BlueprintCatalog.all(in: catalog)
      #expect(blueprints == [
         Blueprint(name: "Blog", description: "A full-featured blog."),
         Blueprint(name: "Podcast", description: "A podcast website."),
      ])
   }

   @Test("Strips the bold markers from the line-3 description")
   func parsesDescription() throws {
      let manager = FileManager.default
      let catalog = try makeFakeCatalog()
      defer { try? manager.removeItem(at: catalog) }

      let description = BlueprintCatalog.description(fromMarkdownAt: catalog.appendingPathComponent("Blog.md"))
      #expect(description == "A full-featured blog.")
   }

   @Test("Throws blueprintNotFound for an unknown name")
   func throwsForUnknownBlueprint() throws {
      let manager = FileManager.default
      let catalog = try makeFakeCatalog()
      defer { try? manager.removeItem(at: catalog) }

      #expect(throws: BlueprintCatalogError.self) {
         try BlueprintCatalog.blueprint(named: "Nonexistent", in: catalog)
      }
   }

   @Test("Throws directoryNotFound for a missing catalog directory")
   func throwsForMissingDirectory() {
      let missing = FileManager.default.temporaryDirectory.appendingPathComponent("sitekit-missing-\(UUID().uuidString)")
      #expect(throws: BlueprintCatalogError.self) {
         try BlueprintCatalog.all(in: missing)
      }
   }

   @Test("The real shipped catalog has the 9 blueprints")
   func realCatalogHasAllBlueprints() throws {
      let blueprints = try BlueprintCatalog.all(in: PackageRoot.blueprintsDirectory)
      let names = blueprints.map(\.name).sorted()
      #expect(names == ["AppLanding", "Blog", "DocC", "IndieDev", "Newsletter", "Plain", "Podcast", "Portfolio", "Snippets"])
      #expect(blueprints.allSatisfy { !$0.description.isEmpty })
   }
}
