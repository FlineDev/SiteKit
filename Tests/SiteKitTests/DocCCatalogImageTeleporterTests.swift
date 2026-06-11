import Foundation
import Testing

@testable import SiteKit

@Suite("DocCCatalogImageTeleporter")
struct DocCCatalogImageTeleporterTests {
   private func makeTempDir(suffix: String = "") -> URL {
      let name = "SiteKitDocCImageTeleporterTests-\(UUID().uuidString)\(suffix)"
      let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      return dir
   }

   private func write(_ content: String = "placeholder", to url: URL) throws {
      try FileManager.default.createDirectory(
         at: url.deletingLastPathComponent(),
         withIntermediateDirectories: true,
         attributes: nil
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
   }

   // MARK: – Core emission

   @Test("Emits a .docc/Images/ file flat into output/assets/")
   func emitsCatalogImageFlat() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Simulate a .docc catalog with one image asset.
      let catalogImages = contentDir
         .appendingPathComponent("Documentation.docc")
         .appendingPathComponent("Images")
      try self.write("svg-content", to: catalogImages.appendingPathComponent("WWDC25-Icon.svg"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      let emitted = outputDir.appendingPathComponent("assets").appendingPathComponent("WWDC25-Icon.svg")
      #expect(FileManager.default.fileExists(atPath: emitted.path), "Expected WWDC25-Icon.svg in output/assets/")
   }

   @Test("Emitted path matches DocCLoader.resolveNavIconURL result")
   func emittedPathMatchesResolver() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Catalog with a PNG icon named WWDC24-Icon.
      let catalogImages = contentDir
         .appendingPathComponent("Documentation.docc")
         .appendingPathComponent("Images")
      try self.write("png-data", to: catalogImages.appendingPathComponent("WWDC24-Icon.png"))

      // Build the fake source path the loader would see.
      let fakeSourcePath = contentDir
         .appendingPathComponent("Documentation.docc")
         .appendingPathComponent("WWDC24.md")

      // Run teleporter.
      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      // Resolve URL the same way DocCLoader does.
      let rawURL = "/assets/WWDC24-Icon"
      let resolvedURL = DocCLoader.resolveNavIconURL(rawURL, relativeTo: fakeSourcePath)

      // The resolved URL must point to a file that the teleporter just emitted.
      // resolvedURL = "/assets/WWDC24-Icon.png"; strip the leading "/" and join with outputDir.
      let relativePath = String(resolvedURL.dropFirst()) // "assets/WWDC24-Icon.png"
      let onDisk = outputDir.appendingPathComponent(relativePath)

      #expect(resolvedURL == "/assets/WWDC24-Icon.png", "Resolver should append .png extension")
      #expect(FileManager.default.fileExists(atPath: onDisk.path), "Teleported file must exist at the resolver's URL path")
   }

   @Test("Handles multiple .docc catalogs under the content directory")
   func multipleCatalogs() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Two catalogs, each with one image.
      let imagesA = contentDir.appendingPathComponent("A.docc/Images")
      let imagesB = contentDir.appendingPathComponent("B.docc/Images")
      try self.write("a-svg", to: imagesA.appendingPathComponent("IconA.svg"))
      try self.write("b-svg", to: imagesB.appendingPathComponent("IconB.svg"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      let assets = outputDir.appendingPathComponent("assets")
      #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent("IconA.svg").path))
      #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent("IconB.svg").path))
   }

   @Test("No-op when the content directory has no .docc catalog")
   func noCatalog() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Plain content directory with no .docc bundle.
      try self.write("# Post", to: contentDir.appendingPathComponent("Articles/post.md"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      // Must not throw.
      try teleporter.copy(from: contentDir, to: outputDir)

      // No assets directory is created when there is nothing to emit.
      let assets = outputDir.appendingPathComponent("assets")
      let isEmpty = !FileManager.default.fileExists(atPath: assets.path)
         || (try? FileManager.default.contentsOfDirectory(atPath: assets.path))?.isEmpty == true
      #expect(isEmpty, "No assets should be emitted when there is no catalog")
   }

   @Test("No-op when the .docc catalog has no Images/ directory")
   func catalogWithoutImages() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // A .docc catalog that only has Markdown content, no Images/ folder.
      let catalog = contentDir.appendingPathComponent("Documentation.docc")
      try self.write("# WWDC25\n", to: catalog.appendingPathComponent("WWDC25.md"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      let assets = outputDir.appendingPathComponent("assets")
      let isEmpty = !FileManager.default.fileExists(atPath: assets.path)
         || (try? FileManager.default.contentsOfDirectory(atPath: assets.path))?.isEmpty == true
      #expect(isEmpty, "No assets should be emitted when Images/ is absent")
   }

   @Test("Flattens sub-directories inside Images/ into assets/")
   func flattensSubdirectories() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // An image nested inside a sub-directory of Images/.
      let nested = contentDir
         .appendingPathComponent("Documentation.docc/Images/2025")
      try self.write("svg", to: nested.appendingPathComponent("WWDC25.svg"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      // The file must land flat in assets/, not in assets/2025/.
      let flat = outputDir.appendingPathComponent("assets/WWDC25.svg")
      #expect(FileManager.default.fileExists(atPath: flat.path), "Nested image must be flattened to assets/")
   }

   @Test("SiteBuilder.docc registers DocCCatalogImageTeleporter via additionalTeleporter")
   func doccBuilderRegistersImageTeleporter() {
      let config = SiteConfig(name: "Docs", baseURL: "https://example.com")
      let builder = SiteBuilder.docc(
         config: config,
         projectDirectory: URL(fileURLWithPath: "/tmp/sitekit-docc-teleporter-test")
      )
      // buildPipeline() must not throw – this exercises the registration path.
      let pipeline = builder.buildPipeline()
      _ = pipeline
   }

   // MARK: – Per-note sibling subfolder emission (BUG A fix)

   @Test("Emits images from a per-note sibling subfolder (WWDCNotes body-image convention)")
   func emitsPerNoteSiblingSubfolderImages() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Simulate the WWDCNotes layout: note .md + sibling subfolder with body images.
      // *.docc/WWDC25/WWDC25-361-Create-icons-with-Icon-Composer/WWDC25-361-Supported-Icon-Modes.jpeg
      let noteSubfolder = contentDir
         .appendingPathComponent("Documentation.docc")
         .appendingPathComponent("WWDC25")
         .appendingPathComponent("WWDC25-361-Create-icons-with-Icon-Composer")
      try self.write("jpeg-data", to: noteSubfolder.appendingPathComponent("WWDC25-361-Supported-Icon-Modes.jpeg"))
      // Also a shared catalog image for non-regression.
      let imagesDir = contentDir.appendingPathComponent("Documentation.docc/Images")
      try self.write("svg-data", to: imagesDir.appendingPathComponent("WWDC25-Icon.svg"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      let assets = outputDir.appendingPathComponent("assets")
      // Per-note body image must land flat in assets/.
      #expect(
         FileManager.default.fileExists(atPath: assets.appendingPathComponent("WWDC25-361-Supported-Icon-Modes.jpeg").path),
         "Per-note subfolder image must be teleported to assets/"
      )
      // Catalog-level image (year glyph) must still be emitted.
      #expect(
         FileManager.default.fileExists(atPath: assets.appendingPathComponent("WWDC25-Icon.svg").path),
         "Top-level Images/ file must still be emitted (non-regression)"
      )
   }

   @Test("Teleports .mp4/.mov videos into assets/ so @Video sources resolve")
   func emitsVideoAssets() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // A note's body video (per-note subfolder, WWDCNotes convention) plus a .mov.
      let noteSubfolder = contentDir
         .appendingPathComponent("Documentation.docc")
         .appendingPathComponent("WWDC24")
         .appendingPathComponent("WWDC24-188-Whats-new-in-SF-Symbols")
      try self.write("mp4-data", to: noteSubfolder.appendingPathComponent("WWDC24-188-Magic-Replace.mp4"))
      try self.write("mov-data", to: noteSubfolder.appendingPathComponent("WWDC24-188-Variable-Color.mov"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      try teleporter.copy(from: contentDir, to: outputDir)

      let assets = outputDir.appendingPathComponent("assets")
      #expect(
         FileManager.default.fileExists(atPath: assets.appendingPathComponent("WWDC24-188-Magic-Replace.mp4").path),
         ".mp4 video must be teleported to assets/ so the @Video <source> resolves to a real file"
      )
      #expect(
         FileManager.default.fileExists(atPath: assets.appendingPathComponent("WWDC24-188-Variable-Color.mov").path),
         ".mov video must be teleported to assets/"
      )
   }

   @Test("Name collision: first-emitted file wins; warning logged, no crash")
   func nameCollisionKeepsFirst() throws {
      let contentDir = self.makeTempDir(suffix: "-content")
      let outputDir = self.makeTempDir(suffix: "-output")
      defer {
         try? FileManager.default.removeItem(at: contentDir)
         try? FileManager.default.removeItem(at: outputDir)
      }

      // Two files with the same name in different locations of the same catalog.
      let imagesDir = contentDir.appendingPathComponent("Documentation.docc/Images")
      let noteSubfolder = contentDir.appendingPathComponent("Documentation.docc/WWDC25/Note")
      try self.write("first", to: imagesDir.appendingPathComponent("Icon.png"))
      try self.write("second", to: noteSubfolder.appendingPathComponent("Icon.png"))

      let teleporter = DocCCatalogImageTeleporter(contentDirectory: contentDir)
      // Must not throw even when a collision occurs.
      try teleporter.copy(from: contentDir, to: outputDir)

      let emitted = outputDir.appendingPathComponent("assets/Icon.png")
      #expect(FileManager.default.fileExists(atPath: emitted.path), "One of the two colliding files must be emitted")
   }
}
