import Foundation

/// Emits SiteKit's bundled DocC sidebar tree-filter script (`docc-filter.js`) to
/// `/assets/js/docc-filter.js`. `DocCArticlePage` (and sibling DocC page renderers)
/// link it from each page's `<head>` (deferred). The script wires the pinned
/// `.sk-docc-filter-input` to live-filter sidebar tree rows by substring and highlight
/// matches with `<mark>`. Progressive enhancement: with no JS the filter box is still
/// visible as a static input but does not filter the tree.
public struct DocCFilterScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("docc-filter.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL page renderers link from `<head>`.
   public static let scriptURL = "/assets/js/docc-filter.js"

   /// Returns the bundled `docc-filter.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-filter.js",
         at: Bundle.module.url(forResource: "docc-filter", withExtension: "js")
      )
   }
}
