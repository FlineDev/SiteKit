import Foundation
import Testing
@testable import SiteKitCLI

@Suite("ScaffoldCopier")
struct ScaffoldCopierTests {
   /// Builds a fake blueprint directory carrying every kind of cruft the copy must exclude
   /// plus a handful of legitimate files, and returns its URL inside a fresh temp directory.
   private func makeFakeBlueprint() throws -> (root: URL, blueprint: URL) {
      let manager = FileManager.default
      let root = manager.temporaryDirectory.appendingPathComponent("sitekit-test-\(UUID().uuidString)")
      let blueprint = root.appendingPathComponent("Blog")

      // Legitimate content that MUST survive the copy.
      try manager.createDirectory(
         at: blueprint.appendingPathComponent("Sources/Site"),
         withIntermediateDirectories: true
      )
      try "@main struct Site {}".write(
         to: blueprint.appendingPathComponent("Sources/Site/Main.swift"),
         atomically: true,
         encoding: .utf8
      )
      try "name: Site".write(
         to: blueprint.appendingPathComponent("SiteConfig.yaml"),
         atomically: true,
         encoding: .utf8
      )
      try ".build/\n".write(
         to: blueprint.appendingPathComponent(".gitignore"),
         atomically: true,
         encoding: .utf8
      )
      // .github is NOT excluded – a scaffolded site keeps its CI workflow.
      try manager.createDirectory(
         at: blueprint.appendingPathComponent(".github/workflows"),
         withIntermediateDirectories: true
      )
      try "name: deploy".write(
         to: blueprint.appendingPathComponent(".github/workflows/deploy.yml"),
         atomically: true,
         encoding: .utf8
      )

      // Cruft that MUST be excluded.
      try manager.createDirectory(
         at: blueprint.appendingPathComponent(".build/x86_64"),
         withIntermediateDirectories: true
      )
      try "huge build product".write(
         to: blueprint.appendingPathComponent(".build/x86_64/binary"),
         atomically: true,
         encoding: .utf8
      )
      try manager.createDirectory(at: blueprint.appendingPathComponent(".git"), withIntermediateDirectories: true)
      try "ref: refs/heads/main".write(
         to: blueprint.appendingPathComponent(".git/HEAD"),
         atomically: true,
         encoding: .utf8
      )
      try manager.createDirectory(at: blueprint.appendingPathComponent("_Site"), withIntermediateDirectories: true)
      try "<html></html>".write(
         to: blueprint.appendingPathComponent("_Site/index.html"),
         atomically: true,
         encoding: .utf8
      )
      try manager.createDirectory(
         at: blueprint.appendingPathComponent("Site.xcodeproj"),
         withIntermediateDirectories: true
      )
      try manager.createDirectory(at: blueprint.appendingPathComponent(".swiftpm"), withIntermediateDirectories: true)
      try "metadata".write(
         to: blueprint.appendingPathComponent(".DS_Store"),
         atomically: true,
         encoding: .utf8
      )

      // Cruft NESTED inside a legitimate subdirectory – must also be excluded, at any depth.
      try manager.createDirectory(
         at: blueprint.appendingPathComponent("Sources/Site/.build/arm64"),
         withIntermediateDirectories: true
      )
      try "nested build product".write(
         to: blueprint.appendingPathComponent("Sources/Site/.build/arm64/binary"),
         atomically: true,
         encoding: .utf8
      )

      return (root, blueprint)
   }

   @Test("Excludes build, VCS, and output cruft from a scaffolded copy")
   func excludesCruft() throws {
      let manager = FileManager.default
      let (root, blueprint) = try makeFakeBlueprint()
      defer { try? manager.removeItem(at: root) }

      let target = root.appendingPathComponent("NewSite")
      try ScaffoldCopier.copy(from: blueprint, to: target)

      for excluded in [".build", ".git", "_Site", "Site.xcodeproj", ".swiftpm", ".DS_Store"] {
         #expect(
            !manager.fileExists(atPath: target.appendingPathComponent(excluded).path),
            "\(excluded) must not be copied into a scaffolded site"
         )
      }
   }

   @Test("Keeps legitimate blueprint files in the scaffolded copy")
   func keepsLegitimateFiles() throws {
      let manager = FileManager.default
      let (root, blueprint) = try makeFakeBlueprint()
      defer { try? manager.removeItem(at: root) }

      let target = root.appendingPathComponent("NewSite")
      try ScaffoldCopier.copy(from: blueprint, to: target)

      for kept in ["Sources/Site/Main.swift", "SiteConfig.yaml", ".gitignore", ".github/workflows/deploy.yml"] {
         #expect(
            manager.fileExists(atPath: target.appendingPathComponent(kept).path),
            "\(kept) must survive the scaffold copy"
         )
      }
   }

   @Test("Excludes cruft nested inside a legitimate subdirectory, at any depth")
   func excludesNestedCruft() throws {
      let manager = FileManager.default
      let (root, blueprint) = try makeFakeBlueprint()
      defer { try? manager.removeItem(at: root) }

      let target = root.appendingPathComponent("NewSite")
      try ScaffoldCopier.copy(from: blueprint, to: target)

      // The legitimate subdirectory and its real file survive...
      #expect(manager.fileExists(atPath: target.appendingPathComponent("Sources/Site/Main.swift").path))
      // ...but a `.build/` nested inside it is excluded just like a top-level one.
      #expect(
         !manager.fileExists(atPath: target.appendingPathComponent("Sources/Site/.build").path),
         "a .build/ nested inside Sources/Site/ must not be copied"
      )
   }

   @Test("Throws targetNotADirectory when the target path is an existing file")
   func throwsWhenTargetIsAFile() throws {
      let manager = FileManager.default
      let (root, blueprint) = try makeFakeBlueprint()
      defer { try? manager.removeItem(at: root) }

      let target = root.appendingPathComponent("already-a-file.txt")
      try "occupied".write(to: target, atomically: true, encoding: .utf8)

      #expect(throws: ScaffoldCopierError.self) {
         try ScaffoldCopier.copy(from: blueprint, to: target)
      }
   }

   @Test("isExcluded covers every deny-listed name and .xcodeproj suffix")
   func isExcludedClassifies() {
      for excluded in [".build", ".git", "_Site", ".DS_Store", ".swiftpm", ".sitekit-cache", "MyApp.xcodeproj"] {
         #expect(ScaffoldCopier.isExcluded(excluded), "\(excluded) should be excluded")
      }
      for kept in ["Sources", "Package.swift", ".gitignore", ".github", "Content"] {
         #expect(!ScaffoldCopier.isExcluded(kept), "\(kept) should be kept")
      }
   }

   @Test("Refuses to scaffold into a non-empty directory")
   func refusesNonEmptyTarget() throws {
      let manager = FileManager.default
      let (root, blueprint) = try makeFakeBlueprint()
      defer { try? manager.removeItem(at: root) }

      let target = root.appendingPathComponent("NewSite")
      try manager.createDirectory(at: target, withIntermediateDirectories: true)
      try "existing".write(to: target.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

      #expect(throws: ScaffoldCopierError.self) {
         try ScaffoldCopier.copy(from: blueprint, to: target)
      }
   }

   @Test("Throws when the blueprint source does not exist")
   func throwsOnMissingSource() throws {
      let manager = FileManager.default
      let root = manager.temporaryDirectory.appendingPathComponent("sitekit-test-\(UUID().uuidString)")
      try manager.createDirectory(at: root, withIntermediateDirectories: true)
      defer { try? manager.removeItem(at: root) }

      #expect(throws: ScaffoldCopierError.self) {
         try ScaffoldCopier.copy(
            from: root.appendingPathComponent("DoesNotExist"),
            to: root.appendingPathComponent("NewSite")
         )
      }
   }
}
