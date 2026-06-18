// swift-tools-version: 6.2
import PackageDescription

let package = Package(
   name: "SiteKit",
   platforms: [.macOS(.v26)],
   products: [
      .library(name: "SiteKit", targets: ["SiteKit"]),
      // Optional add-on library: a SwiftSyntax-based Swift code highlighter for DocC sites that want
      // semantic-near token roles (variable/call/member/param/…) instead of the regex highlighter's
      // capitalized-only type detection. It lives in its own product+target so it pulls swift-syntax
      // ONLY into builds that actually use it. A consumer depending only on the `SiteKit` product never
      // compiles swift-syntax (SE-0226 target-based dependency resolution prunes it).
      .library(name: "SiteKitSyntaxHighlighting", targets: ["SiteKitSyntaxHighlighting"]),
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

      // swift-syntax powers ONLY the optional SiteKitSyntaxHighlighting target. The 6xx.x line tracks
      // the Swift toolchain (603.x = Swift 6.3, the toolchain SiteKit builds with). Only the parser +
      // tree + syntactic-classification modules are used; the macro/compiler-plugin modules (the heavy,
      // slow-to-compile part of swift-syntax) are deliberately NOT depended upon.
      .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.0"..<"604.0.0"),
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
      // Optional SwiftSyntax-based highlighter. Depends on the base `SiteKit` library (for the
      // `CodeHighlighting` seam) plus exactly three swift-syntax modules: SwiftParser (error-tolerant
      // parsing of code fragments), SwiftSyntax (the tree + visitor), and SwiftIDEUtils (the syntactic
      // `classifications` API that SourceKit uses). Deliberately excludes SwiftSyntaxMacros,
      // SwiftCompilerPlugin, SwiftSyntaxMacroExpansion, SwiftOperators, SwiftSyntaxBuilder and
      // SwiftParserDiagnostics – none are needed to classify tokens, and they are the bulk of the
      // swift-syntax build cost.
      .target(
         name: "SiteKitSyntaxHighlighting",
         dependencies: [
            "SiteKit",
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "SwiftIDEUtils", package: "swift-syntax"),
         ]
      ),
      .testTarget(
         name: "SiteKitTests",
         dependencies: ["SiteKit"]
      ),
      .testTarget(
         name: "SiteKitSyntaxHighlightingTests",
         dependencies: ["SiteKitSyntaxHighlighting"]
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
