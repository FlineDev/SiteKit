// swift-tools-version: 6.2
import PackageDescription

let package = Package(
   name: "SiteKit",
   platforms: [.macOS(.v26)],
   products: [
      .library(name: "SiteKit", targets: ["SiteKit"]),
      // The executable *product* is `sitekit` (the durable public command name); its *target*
      // is `SiteKitCLI` because a target literally named `sitekit` collides with the `SiteKit`
      // library target on a case-insensitive filesystem – at both the `Sources/` directory and
      // the `.build/` intermediate level. `swift run sitekit` resolves the product name.
      .executable(name: "sitekit", targets: ["SiteKitCLI"]),
   ],
   dependencies: [
      .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0"),

      .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
      .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
      .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
      .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
   ],
   targets: [
      .target(
         name: "SiteKit",
         dependencies: [
            .product(name: "Markdown", package: "swift-markdown"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Crypto", package: "swift-crypto"),

            "Yams",
         ],
         resources: [.process("Resources")]
      ),
      .executableTarget(
         name: "SiteKitCLI",
         dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
         ]
      ),
      .testTarget(
         name: "SiteKitTests",
         dependencies: ["SiteKit"]
      ),
      .testTarget(
         name: "SiteKitCLITests",
         dependencies: ["SiteKitCLI"]
      ),
      // Internal build-tooling for the theme-preview pipeline. None of these
      // targets touch SiteKit's library surface – they live under `Plugin/themes/`
      // and exist solely so contributors can regenerate the nine real-build
      // preview HTML files (`swift run PreviewGenerator`).
      .target(
         name: "PreviewGeneratorKit",
         path: "Plugin/themes/PreviewGeneratorKit"
      ),
      .executableTarget(
         name: "PreviewGenerator",
         dependencies: ["PreviewGeneratorKit"],
         path: "Plugin/themes",
         exclude: [
            "PreviewGeneratorKit",
            "preview",
            "preview-build",
            "preview-fixture",
            "preview-fixture-podcast",
            "templates",
            "README.md",
            "ThemePreview.html",
         ],
         sources: ["generate-previews.swift"]
      ),
      .testTarget(
         name: "PreviewGeneratorTests",
         dependencies: ["PreviewGeneratorKit"]
      ),
   ]
)
