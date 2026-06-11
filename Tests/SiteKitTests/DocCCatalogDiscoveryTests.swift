import Foundation
import Testing

@testable import SiteKit

@Suite("DocCCatalogDiscovery")
struct DocCCatalogDiscoveryTests {
   private func makeTempDir() -> URL {
      let dir = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("SiteKitDocCDiscoveryTests-\(UUID().uuidString)")
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      return dir
   }

   private func write(_ contents: String, to url: URL) throws {
      try FileManager.default.createDirectory(
         at: url.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
      try contents.write(to: url, atomically: true, encoding: .utf8)
   }

   @Test("Walks nested year folders and overview pages, sorted, skipping assets")
   func walksNestedCatalog() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      // A miniature .docc layout: year overviews + nested per-session notes + an asset.
      try self.write("# WWDC24", to: root.appendingPathComponent("WWDC24.md"))
      try self.write("# WWDC23", to: root.appendingPathComponent("WWDC23.md"))
      try self.write("# Meet FinanceKit", to: root.appendingPathComponent("WWDC24/WWDC24-2023-Meet-FinanceKit.md"))
      try self.write("# Whats New", to: root.appendingPathComponent("WWDC24/WWDC24-10061-Whats-New.md"))
      try self.write("# A Session", to: root.appendingPathComponent("WWDC23/WWDC23-100-A-Session.md"))
      // Non-Markdown catalog files + an asset folder – must be skipped.
      try self.write("{}", to: root.appendingPathComponent("Info.plist"))
      try self.write("binary", to: root.appendingPathComponent("WWDC24/WWDC24-2023-Meet-FinanceKit/hero.png"))

      let sources = try DocCCatalogDiscovery().discover(in: root)

      // Five .md files found recursively; the plist and png are skipped.
      #expect(sources.count == 5)
      #expect(sources.allSatisfy { $0.filePath.pathExtension == "md" })

      // Deterministic path sort.
      let paths = sources.map(\.filePath.path)
      #expect(paths == paths.sorted())

      // Nested notes are reached.
      #expect(sources.contains { $0.filePath.lastPathComponent == "WWDC24-2023-Meet-FinanceKit.md" })
      // Raw content is returned unparsed.
      #expect(sources.contains { $0.content == "# Meet FinanceKit" })
   }

   @Test("Skips an .ai.md when its community sibling exists, keeps AI-only")
   func skipsPairedAIVariant() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      // Paired: community + AI variant – only the community note is emitted.
      try self.write("# Paired", to: root.appendingPathComponent("WWDC24-1-Paired.md"))
      try self.write("# Paired AI", to: root.appendingPathComponent("WWDC24-1-Paired.ai.md"))
      // AI-only: no community sibling – kept as its own page.
      try self.write("# AI Only", to: root.appendingPathComponent("WWDC24-2-AIOnly.ai.md"))

      let sources = try DocCCatalogDiscovery().discover(in: root)
      let names = sources.map(\.filePath.lastPathComponent).sorted()
      #expect(names == ["WWDC24-1-Paired.md", "WWDC24-2-AIOnly.ai.md"])
      #expect(!names.contains("WWDC24-1-Paired.ai.md"))
   }

   @Test("Returns empty for a missing directory")
   func missingDirectory() throws {
      let missing = self.makeTempDir().appendingPathComponent("does-not-exist")
      let sources = try DocCCatalogDiscovery().discover(in: missing)
      #expect(sources.isEmpty)
   }
}
