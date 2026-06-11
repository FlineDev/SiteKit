import Foundation

enum ScaffoldCopierError: Error, CustomStringConvertible {
   case targetNotEmpty(URL)
   case targetNotADirectory(URL)
   case targetNotReadable(URL)
   case sourceNotFound(URL)

   var description: String {
      switch self {
      case .targetNotEmpty(let url):
         return "Target directory \(url.path) already exists and is not empty. Refusing to overwrite."
      case .targetNotADirectory(let url):
         return "Target path \(url.path) already exists and is a file, not a directory. Refusing to overwrite."
      case .targetNotReadable(let url):
         return "Target directory \(url.path) already exists but cannot be read. Check its permissions."
      case .sourceNotFound(let url):
         return "Blueprint source directory not found at \(url.path)."
      }
   }
}

/// Copies a blueprint directory into a fresh site directory, excluding build / VCS / output cruft.
///
/// The exclude filter is the highest-risk seam in the CLI: a blueprint inside a working SiteKit
/// clone accumulates local development state – an SPM `.build/` directory can reach tens of
/// megabytes – and copying that (or `.git/`, `_Site/`, …) into a user's new site would be a
/// disaster. The filter is a deny-list applied per path component during a recursive walk, so
/// an excluded directory is never even descended into.
enum ScaffoldCopier {
   /// Path components that must never end up in a scaffolded site.
   ///
   /// `.build/` – SPM build products. `.git/` – VCS history of the SiteKit clone.
   /// `_Site/` – a previous build's output. `.DS_Store` – Finder metadata.
   /// `*.xcodeproj` – generated Xcode project. `.swiftpm/` – SPM/Xcode local state.
   /// `.sitekit-cache/` – the per-site build cache (Font Awesome SVGs, image variants).
   static let excludedNames: Set<String> = [".build", ".git", "_Site", ".DS_Store", ".swiftpm", ".sitekit-cache"]

   /// `true` when a path component named `name` must be excluded from a scaffold copy.
   static func isExcluded(_ name: String) -> Bool {
      if self.excludedNames.contains(name) { return true }
      if name.hasSuffix(".xcodeproj") { return true }
      return false
   }

   /// Copies every non-excluded file under `source` into `target`.
   ///
   /// Throws `sourceNotFound` when `source` does not exist; `targetNotADirectory` when `target` is
   /// an existing file; `targetNotReadable` when `target` is a directory that cannot be listed; and
   /// `targetNotEmpty` when `target` is a non-empty directory. An excluded directory is skipped
   /// wholesale – its children are never visited.
   static func copy(from source: URL, to target: URL) throws {
      let manager = FileManager.default

      var sourceIsDirectory: ObjCBool = false
      guard manager.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory),
         sourceIsDirectory.boolValue
      else {
         throw ScaffoldCopierError.sourceNotFound(source)
      }

      var targetIsDirectory: ObjCBool = false
      if manager.fileExists(atPath: target.path, isDirectory: &targetIsDirectory) {
         guard targetIsDirectory.boolValue else {
            throw ScaffoldCopierError.targetNotADirectory(target)
         }
         let contents: [String]
         do {
            contents = try manager.contentsOfDirectory(atPath: target.path)
         } catch {
            throw ScaffoldCopierError.targetNotReadable(target)
         }
         let meaningful = contents.filter { $0 != ".DS_Store" }
         guard meaningful.isEmpty else {
            throw ScaffoldCopierError.targetNotEmpty(target)
         }
      }

      try manager.createDirectory(at: target, withIntermediateDirectories: true)
      try self.copyContents(of: source, into: target, using: manager)
   }

   private static func copyContents(of directory: URL, into target: URL, using manager: FileManager) throws {
      let entries = try manager.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: [.isDirectoryKey],
         options: []
      )
      for entry in entries {
         let name = entry.lastPathComponent
         if self.isExcluded(name) { continue }

         let destination = target.appendingPathComponent(name)
         let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
         if values.isDirectory == true {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            try self.copyContents(of: entry, into: destination, using: manager)
         } else {
            try manager.copyItem(at: entry, to: destination)
         }
      }
   }
}
