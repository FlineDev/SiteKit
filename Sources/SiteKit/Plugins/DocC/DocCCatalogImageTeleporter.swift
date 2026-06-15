import Foundation
import Logging

/// Teleports every image file from every `.docc` catalog into the output `/assets/`
/// root, flat, so body images and `@PageImage` icon URLs resolve to real files.
///
/// DocC catalogs store images in two layouts:
/// - Year glyphs and shared banners: `<catalog>.docc/Images/<name>.<ext>`
/// - Per-note body images: `<catalog>.docc/<year>/<note-name>/<name>.<ext>`
///   (e.g. `WWDC25/WWDC25-361-Create-icons-with-Icon-Composer/WWDC25-361-Supported-Icon-Modes.jpeg`)
///
/// The teleporter walks every `.docc` catalog recursively and emits ALL asset files
/// (images: png, jpg, jpeg, svg, webp, gif; videos: mp4, mov – case-insensitive) into
/// `output/assets/` flat, regardless of which subdirectory they live in. This ensures both
/// layouts produce files at `/assets/<name>.<ext>` to match the URLs that
/// `DocCLoader.resolveImageName` / `resolveVideoName` and `DocCDirectiveRenderer` generate
/// (the `@Video` player resolves `/assets/<name>.mp4`, so videos must teleport too).
///
/// Emitting rules:
/// - Every `*.docc` bundle found anywhere under the content source directory contributes.
/// - ALL asset files (any subfolder, recursively) are emitted – not just `Images/`.
/// - Non-asset files (`.md`, `.swift`, `.json`, etc.) are skipped so only
///   browser-renderable assets land in the output.
/// - On name collision across two source files, the last-encountered file wins and a
///   warning is logged naming BOTH source paths. The WWDCNotes convention prefixes
///   filenames with the session id (e.g. `WWDC21-10012-appClipSafari`) so collisions
///   are rare in practice; the guard prevents silent data loss when they occur.
///
/// This teleporter is automatically registered by `SiteBuilder.docc(...)`. It is a
/// no-op on non-DocC sites because their content directories contain no `.docc` bundles.
public struct DocCCatalogImageTeleporter: Teleporter {
   private let contentDirectory: URL
   private let logger: Logger

   /// Browser-renderable asset extensions teleported flat into `/assets/`: images plus the
   /// `.mp4`/`.mov` videos that the `@Video` directive renders as inline `<video>` players.
   private static let assetExtensions: Set<String> = ["png", "jpg", "jpeg", "svg", "webp", "gif", "mp4", "mov"]

   /// - Parameter contentDirectory: The site's content root (e.g. `projectDir/Content`).
   ///   Every `.docc` bundle under this tree contributes all of its image files.
   public init(contentDirectory: URL) {
      self.contentDirectory = contentDirectory
      self.logger = Logger(label: "SiteKit.docc-images")
   }

   /// Copies every image asset found inside any `.docc` catalog under `contentDirectory`
   /// into `outputDirectory/assets/` (flat layout). Both `Images/` subdirectories and
   /// per-note sibling subfolders are covered by the recursive walk.
   ///
   /// The `sourceDirectory` parameter is ignored because catalog paths are computed
   /// from `contentDirectory` at init time; this matches the `Teleporter` protocol
   /// contract where `copy(from:to:)` is called with the site's standard asset directory
   /// as `sourceDirectory` and the output root as `outputDirectory`.
   public func copy(from sourceDirectory: URL, to outputDirectory: URL) throws {
      let assetsOutput = outputDirectory.appendingPathComponent("assets")
      let fileManager = FileManager.default

      let catalogDirs = self.findCatalogDirs(fileManager: fileManager)
      guard !catalogDirs.isEmpty else {
         self.logger.info("No .docc catalogs found under \(self.contentDirectory.path), skipping")
         return
      }

      try fileManager.createDirectory(at: assetsOutput, withIntermediateDirectories: true, attributes: nil)

      // Track source path for each emitted filename so duplicate-name collisions can be logged
      // with full context (both source paths) rather than silently overwriting.
      var emittedSources: [String: URL] = [:]
      for catalogDir in catalogDirs {
         try self.emitImages(from: catalogDir, to: assetsOutput, fileManager: fileManager, emittedSources: &emittedSources)
      }
   }

   /// Not used by the DocC pipeline but required by the `Teleporter` protocol.
   /// Falls back to a no-op since catalog images are always emitted to the default
   /// `/assets/` root, not to a caller-specified destination.
   public func copy(from sourceDirectory: URL, into destinationDirectory: URL) throws {
      // DocCCatalogImageTeleporter is only used for the standard assets emission path.
      // The protocol method is intentionally left as a no-op; callers that need an
      // explicit-destination copy of catalog images should use copy(from:to:) instead.
   }

   // MARK: - Private helpers

   /// Returns every `.docc` bundle directory found recursively under the content directory,
   /// in stable (file-system enumeration) order. Each catalog's entire subtree contributes.
   private func findCatalogDirs(fileManager: FileManager) -> [URL] {
      guard let enumerator = fileManager.enumerator(
         at: self.contentDirectory,
         includingPropertiesForKeys: [.isDirectoryKey],
         options: [.skipsHiddenFiles]
      ) else {
         return []
      }

      var catalogs: [URL] = []
      while let url = enumerator.nextObject() as? URL {
         guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
               values.isDirectory == true,
               url.pathExtension == "docc"
         else { continue }

         // Skip the subtree from the outer enumeration: the inner emitImages walk
         // handles all descendants of this catalog root directly.
         enumerator.skipDescendants()
         catalogs.append(url)
         self.logger.info("Found .docc catalog at \(url.path)")
      }

      return catalogs
   }

   /// Recursively walks `catalogDir` and copies every image file (by extension) to
   /// `assetsOutput`, flat. On a name collision both source paths are logged as a warning.
   private func emitImages(
      from catalogDir: URL,
      to assetsOutput: URL,
      fileManager: FileManager,
      emittedSources: inout [String: URL]
   ) throws {
      guard let enumerator = fileManager.enumerator(
         at: catalogDir,
         includingPropertiesForKeys: [.isRegularFileKey],
         options: [.skipsHiddenFiles]
      ) else { return }

      while let url = enumerator.nextObject() as? URL {
         guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
               values.isRegularFile == true
         else { continue }

         // Only emit known asset types (images + videos); skip .md, .swift, .json, etc.
         let ext = url.pathExtension.lowercased()
         guard Self.assetExtensions.contains(ext) else { continue }

         let filename = url.lastPathComponent
         let destination = assetsOutput.appendingPathComponent(filename)

         if let previousSource = emittedSources[filename] {
            self.logger.warning(
               "DocC catalog image name collision: \"\(filename)\" found at both \(previousSource.path) and \(url.path) – keeping first"
            )
            // Keep the first-emitted file; do not overwrite so the build is deterministic.
            continue
         }

         if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
         }
         try fileManager.copyItem(at: url, to: destination)
         emittedSources[filename] = url
         self.logger.debug("Teleported \(filename) → assets/\(filename)")
      }
   }
}
