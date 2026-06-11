import Foundation

/// Locates the SiteKit package root and the blueprint catalog within it.
///
/// The CLI ships as an `executableTarget` inside SiteKit's own `Package.swift`, so the
/// canonical run path is `swift run sitekit …` from a SiteKit clone. The package root is
/// found by walking up from this source file's compile-time path (`#filePath`):
/// `Sources/SiteKitCLI/PackageRoot.swift` → drop three components → the repo root.
///
/// Trade-off: a binary copied elsewhere via `swift build -c release` still resolves the
/// path back to the original source tree, so a globally installed binary only works while
/// the clone exists at its original location. Global install is explicitly not a v1.0
/// requirement (see F03 implementation decision 2) – `swift run` from a clone always works.
enum PackageRoot {
   /// The SiteKit repository root, derived from this file's `#filePath`.
   static var url: URL {
      URL(fileURLWithPath: #filePath)
         .deletingLastPathComponent()  // Sources/SiteKitCLI
         .deletingLastPathComponent()  // Sources
         .deletingLastPathComponent()  // repo root
   }

   /// The on-disk blueprint catalog directory (`Plugin/blueprints/`).
   static var blueprintsDirectory: URL {
      self.url
         .appendingPathComponent("Plugin")
         .appendingPathComponent("blueprints")
   }
}
