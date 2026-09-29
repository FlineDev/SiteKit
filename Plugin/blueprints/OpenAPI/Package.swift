// swift-tools-version: 6.2
import PackageDescription

let package = Package(
   name: "Site",
   platforms: [.macOS(.v26)],
   dependencies: [
      // The OpenAPI blueprint ships in the optional SiteKitOpenAPI product (it pulls the
      // OpenAPI parser only into builds that use it).
      .package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.1.0")
   ],
   targets: [
      .executableTarget(
         name: "Site",
         dependencies: [
            .product(name: "SiteKit", package: "SiteKit"),
            .product(name: "SiteKitOpenAPI", package: "SiteKit"),
         ]
      )
   ]
)
