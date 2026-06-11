import Foundation

/// Default content discovery that finds markdown files in a flat directory.
///
/// Scans a single directory for `.md` files, reads their content, and returns
/// them as `MarkdownSource` objects sorted by filename.
public struct MarkdownContentDiscovery: ContentDiscovery {
   public init() {}

   public func discover(in directory: URL) throws -> [MarkdownSource] {
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: directory.path) else {
         return []
      }

      let contents = try fileManager.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: nil,
         options: [.skipsHiddenFiles]
      )

      let markdownFiles = contents.filter { $0.pathExtension == "md" }.sorted { $0.path < $1.path }

      return try markdownFiles.map { fileURL in
         let content = try String(contentsOf: fileURL, encoding: .utf8)
         return MarkdownSource(filePath: fileURL, content: content)
      }
   }
}
