import Foundation
import Logging

/// Default `Teleporter` that copies asset files from the project's assets
/// directory into the output directory's `/assets/` subtree.
///
/// `copy(from:to:)` honours SiteKit's standard layout (project
/// `Content/Assets/` → output `assets/`); `copy(from:into:)` writes to an
/// explicit destination for callers that want full control (e.g. copying a
/// theme folder, or per-locale fan-out). Hidden files are not skipped – drop
/// them in the source directory only when they should ship.
///
/// Replace via `SiteBuilder.teleporter(_:)` to add transformations on the
/// way out (EXIF stripping, format conversion). For responsive image
/// variants, layer `ImageResizer` (phase 6) on top instead of replacing this.
public struct AssetCopier: Teleporter {
   private let logger: Logger

   public init() {
      self.logger = Logger(label: "SiteKit.assets")
   }

   public func copy(from sourceDirectory: URL, to outputDirectory: URL) throws {
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: sourceDirectory.path) else {
         self.logger.info("No assets directory found at \(sourceDirectory.path), skipping")
         return
      }

      let assetsOutputDirectory = outputDirectory.appendingPathComponent("assets")

      try self.copyDirectory(from: sourceDirectory, to: assetsOutputDirectory)
      self.logger.info("Copied assets to \(assetsOutputDirectory.path)")
   }

   public func copy(from sourceDirectory: URL, into destinationDirectory: URL) throws {
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: sourceDirectory.path) else {
         self.logger.info("Directory not found at \(sourceDirectory.path), skipping")
         return
      }

      try self.copyDirectory(from: sourceDirectory, to: destinationDirectory)
      self.logger.info("Copied \(sourceDirectory.lastPathComponent) to \(destinationDirectory.path)")
   }

   private func copyDirectory(from source: URL, to destination: URL) throws {
      let fileManager = FileManager.default

      try fileManager.createDirectory(
         at: destination,
         withIntermediateDirectories: true,
         attributes: nil
      )

      let contents = try fileManager.contentsOfDirectory(
         at: source,
         includingPropertiesForKeys: [.isDirectoryKey],
         options: [.skipsHiddenFiles]
      )

      for item in contents {
         // Skip theme.yaml – it's config, not a deployable asset
         if item.lastPathComponent == "theme.yaml" { continue }

         let destinationItem = destination.appendingPathComponent(item.lastPathComponent)
         let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])

         if resourceValues.isDirectory == true {
            try self.copyDirectory(from: item, to: destinationItem)
         } else {
            if fileManager.fileExists(atPath: destinationItem.path) {
               try fileManager.removeItem(at: destinationItem)
            }
            try fileManager.copyItem(at: item, to: destinationItem)
         }
      }
   }
}
