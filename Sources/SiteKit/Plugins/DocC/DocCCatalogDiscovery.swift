import Foundation

/// Discovers every Markdown note in a DocC catalog (`.docc`), descending into
/// nested folders.
///
/// A DocC catalog nests content – e.g. one folder per year holding per-session
/// notes (`WWDC24/WWDC24-…-Meet-FinanceKit.md`) plus top-level overview pages
/// (`WWDC24.md`) – so unlike the flat `MarkdownContentDiscovery` this walks the
/// tree recursively. Returns one `MarkdownSource` per `.md` file, sorted by path
/// for stable downstream output.
///
/// Non-Markdown catalog files (`Info.plist`, `theme-settings.json`) and asset
/// folders (`Images/`, the per-note resource directories) carry no `.md` and are
/// naturally skipped. The Years→Sessions hierarchy that powers the sidebar is
/// derived downstream from the source paths – discovery stays read-only and
/// parse-free, per the `ContentDiscovery` contract.
public struct DocCCatalogDiscovery: ContentDiscovery {
   public init() {}

   public func discover(in directory: URL) throws -> [MarkdownSource] {
      let fileManager = FileManager.default
      guard fileManager.fileExists(atPath: directory.path) else { return [] }

      var markdownFiles: [URL] = []
      let enumerator = fileManager.enumerator(
         at: directory,
         includingPropertiesForKeys: [.isRegularFileKey],
         options: [.skipsHiddenFiles]
      )
      while let url = enumerator?.nextObject() as? URL {
         guard url.pathExtension == "md" else { continue }
         // An AI-variant sibling (`<base>.ai.md`) is folded into its community note
         // (`<base>.md`) by the loader, so skip it here when that community note
         // exists. An AI-only note (no community sibling) is kept as its own page.
         if url.lastPathComponent.hasSuffix(".ai.md") {
            let base = String(url.lastPathComponent.dropLast(".ai.md".count))
            let community = url.deletingLastPathComponent().appendingPathComponent("\(base).md")
            if fileManager.fileExists(atPath: community.path) { continue }
         }
         markdownFiles.append(url)
      }

      // Stable, path-sorted order so the build output is deterministic.
      markdownFiles.sort { $0.path < $1.path }

      return try markdownFiles.map { fileURL in
         let content = try String(contentsOf: fileURL, encoding: .utf8)
         return MarkdownSource(filePath: fileURL, content: content)
      }
   }
}
