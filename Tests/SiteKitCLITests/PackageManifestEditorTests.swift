import Foundation
import Testing
@testable import SiteKitCLI

@Suite("PackageManifestEditor")
struct PackageManifestEditorTests {
   private let versionPinnedManifest = """
      // swift-tools-version: 6.2
      import PackageDescription

      let package = Package(
         name: "Site",
         platforms: [.macOS(.v26)],
         dependencies: [
            .package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0"),
         ],
         targets: [
            .executableTarget(name: "Site", dependencies: [.product(name: "SiteKit", package: "SiteKit")]),
         ]
      )
      """

   @Test("Detects the currently-pinned SiteKit version")
   func detectsCurrentVersion() {
      #expect(PackageManifestEditor.currentVersion(in: self.versionPinnedManifest) == "1.0.0")
   }

   @Test("Bumps the SiteKit dependency version, leaving the rest of the manifest intact")
   func bumpsVersion() throws {
      let bumped = try PackageManifestEditor.bumped(self.versionPinnedManifest, to: "1.4.2")
      #expect(bumped.contains(#".package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.4.2")"#))
      #expect(!bumped.contains("1.0.0"))
      #expect(bumped.contains(#"name: "Site""#))
   }

   @Test("Throws dependencyNotVersionPinned for a branch-based dependency")
   func throwsForBranchDependency() {
      let branchManifest = self.versionPinnedManifest.replacingOccurrences(
         of: #"from: "1.0.0""#,
         with: #"branch: "main""#
      )
      #expect(PackageManifestEditor.currentVersion(in: branchManifest) == nil)
      #expect(throws: PackageManifestError.self) {
         try PackageManifestEditor.bumped(branchManifest, to: "1.4.2")
      }
   }

   @Test("A commented-out SiteKit clause never shadows the live dependency or gets rewritten")
   func commentLinesAreMaskedAndRewriteIsScoped() throws {
      // A commented hint clause (version 9.9.9) sits above the live version-pinned dep (1.0.0).
      let manifest = """
         // swift-tools-version: 6.2
         import PackageDescription

         let package = Package(
            name: "Site",
            dependencies: [
               // .package(url: "https://github.com/FlineDev/SiteKit.git", from: "9.9.9"),
               .package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0"),
            ]
         )
         """
      // currentVersion reports the LIVE dep, not the commented one.
      #expect(PackageManifestEditor.currentVersion(in: manifest) == "1.0.0")

      // bumped() rewrites ONLY the live clause; the commented 9.9.9 line is left byte-identical.
      let bumped = try PackageManifestEditor.bumped(manifest, to: "2.0.0")
      #expect(bumped.contains(#"// .package(url: "https://github.com/FlineDev/SiteKit.git", from: "9.9.9"),"#))
      #expect(bumped.contains(#"   .package(url: "https://github.com/FlineDev/SiteKit.git", from: "2.0.0"),"#))
      #expect(!bumped.contains(#"from: "1.0.0""#))
   }

   @Test("A commented version clause does not bypass branch/path rejection")
   func commentedClauseDoesNotBypassBranchRejection() {
      // Commented `from:` hint above a LIVE branch-based dep – must still be rejected.
      let manifest = """
         let package = Package(
            dependencies: [
               // .package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0"),
               .package(url: "https://github.com/FlineDev/SiteKit.git", branch: "main"),
            ]
         )
         """
      #expect(PackageManifestEditor.currentVersion(in: manifest) == nil)
      #expect(throws: PackageManifestError.dependencyNotVersionPinned) {
         try PackageManifestEditor.bumped(manifest, to: "1.4.2")
      }
   }

   @Test("Handles the named .package(name:url:from:) form")
   func handlesNamedPackageForm() throws {
      let named = """
         let package = Package(
            dependencies: [
               .package(name: "SiteKit", url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0"),
            ]
         )
         """
      #expect(PackageManifestEditor.currentVersion(in: named) == "1.0.0")
      let bumped = try PackageManifestEditor.bumped(named, to: "1.5.0")
      #expect(bumped.contains(#"from: "1.5.0""#))

      // The named form with branch: is rejected as not-version-pinned, not reported as absent.
      let namedBranch = named.replacingOccurrences(of: #"from: "1.0.0""#, with: #"branch: "main""#)
      #expect(throws: PackageManifestError.dependencyNotVersionPinned) {
         try PackageManifestEditor.bumped(namedBranch, to: "1.5.0")
      }
   }

   @Test("Throws dependencyNotFound when there is no SiteKit dependency")
   func throwsWhenDependencyAbsent() {
      let manifest = """
         // swift-tools-version: 6.2
         import PackageDescription
         let package = Package(name: "Other", dependencies: [])
         """
      #expect(throws: PackageManifestError.self) {
         try PackageManifestEditor.bumped(manifest, to: "1.4.2")
      }
   }
}
