import Foundation

/// Emits the DocC full-text search index as sharded JSON plus a manifest.
///
/// The records (`DocCSearchIndex.build`) are split into fixed-size shards written
/// to `/assets/search/docc-search-<n>.json`, with a manifest at
/// `/assets/search/docc-search.json` listing the shard URLs and the total count.
/// Sharding keeps each file small so the client fetches them lazily and in
/// parallel on first search instead of loading one large index up front. Runs
/// once per build.
public struct DocCSearchIndexRenderer: Renderer {
   public var scope: RenderScope { .global }

   private let shardSize: Int

   /// Path authorities consulted per page, mirroring sitemap + nav index: a `Page` plugin
   /// that writes a page somewhere the router cannot derive (or consumes it without an own
   /// URL) is handed in here by the blueprint so search results link to URLs that exist.
   let pathResolvers: [any PagePathResolving]

   public init(shardSize: Int = 150, pathResolvers: [any PagePathResolving] = []) {
      self.shardSize = max(1, shardSize)
      self.pathResolvers = pathResolvers
   }

   public func render(context: BuildContext) throws -> [OutputFile] {
      // The ⌘K index is a session-note index. Contributor profile notes are consumed by
      // DocCContributorPage: their indexable text (the GitHub bio) proxies a page whose real
      // content is the derived contribution lists, and they fit no facet (no year, no
      // framework) – so they are not indexed at all. Contributors stay discoverable via the
      // contributors overview page and the sidebar.
      let pages = context.sections
         .flatMap(\.pages)
         .filter { ($0.extensions["doccNote"] as? Bool) == true }
         .filter { ($0.extensions["doccContributorProfile"] as? Bool) != true }

      // Generic path truth, mirroring sitemap + nav index: a page re-homed by its rendering
      // plugin is indexed at the path that plugin actually writes, a consumed page without
      // an own URL drops out (its record would link to a 404).
      var urlOverrides: [String: String] = [:]
      var indexedPages: [PageModel] = []
      for page in pages {
         switch self.pathResolvers.pathResolution(for: page, context: context) {
         case .unpublished:
            continue
         case .path(let overriddenPath):
            urlOverrides[page.slug] = overriddenPath
            indexedPages.append(page)
         case .routerDefault:
            indexedPages.append(page)
         }
      }
      guard !indexedPages.isEmpty else { return [] }

      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let records = DocCSearchIndex.build(from: indexedPages, urlPrefix: prefix, urlOverrides: urlOverrides)

      let base = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("search")

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]

      var files: [OutputFile] = []
      var shardURLs: [String] = []
      var shardIndex = 0
      var start = 0
      while start < records.count {
         let end = min(start + self.shardSize, records.count)
         let shard = Array(records[start ..< end])
         let name = "docc-search-\(shardIndex).json"
         let data = try encoder.encode(shard)
         files.append(OutputFile(
            outputPath: base.appendingPathComponent(name),
            content: String(decoding: data, as: UTF8.self)
         ))
         shardURLs.append("/assets/search/\(name)")
         shardIndex += 1
         start = end
      }

      let manifest: [String: Any] = ["count": records.count, "shards": shardURLs]
      let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
      files.append(OutputFile(
         outputPath: base.appendingPathComponent("docc-search.json"),
         content: String(decoding: manifestData, as: UTF8.self)
      ))

      return files
   }
}
