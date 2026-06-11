import Foundation

/// Emits SiteKit's bundled facet-search script (`docc-search-page.js`) to
/// `/assets/search/docc-search-page.js`. `DocCSearchPage` links it from the search
/// page's `<head>` (deferred). The script hydrates the dedicated search page: it reads
/// the query + facets from the URL, lazily loads the same sharded index the ⌘K overlay
/// uses, filters by free-text AND facets, renders `sk-docc-sessitem` result rows, keeps
/// live per-facet counts, and writes the active query/facets back into the URL so the
/// page stays bookmarkable. Runs once per build. Progressive enhancement: with no JS the
/// search box and facet chips render as inert markup and the sidebar still navigates.
public struct DocCSearchPageScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("search")
         .appendingPathComponent("docc-search-page.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL `DocCSearchPage` links from `<head>`.
   public static let scriptURL = "/assets/search/docc-search-page.js"

   /// Returns the bundled `docc-search-page.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-search-page.js",
         at: Bundle.module.url(forResource: "docc-search-page", withExtension: "js")
      )
   }
}
