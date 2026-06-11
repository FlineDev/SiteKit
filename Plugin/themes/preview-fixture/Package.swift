// swift-tools-version: 6.2
import PackageDescription

// Pins SiteKit via a local `path:` dep so the preview pipeline always builds
// against the current working tree of the parent repo, not a released tag.
// (Three levels up – `Plugin/themes/preview-fixture/` to repo root.)
let package = Package(
   name: "Site",
   platforms: [.macOS(.v26)],
   dependencies: [
      .package(path: "../../.."),
   ],
   targets: [
      .executableTarget(
         name: "Site",
         dependencies: [
            .product(name: "SiteKit", package: "SiteKit"),
         ]
      ),
   ]
)
