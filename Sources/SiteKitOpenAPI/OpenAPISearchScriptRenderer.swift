import Foundation
import SiteKit

/// Emits SiteKitOpenAPI's bundled appbar-search script to `/assets/js/openapi-search.js`.
/// `OpenAPIShell` links it (deferred) from every page.
///
/// Progressive enhancement, mirroring `DocCSearchScriptRenderer`: the search box only does
/// anything with JavaScript, so the stylesheet keeps it hidden until `openapi-nav.js` adds the
/// `js` class. On first focus the script lazily fetches `/assets/search-index.json`
/// (``OpenAPISearchIndexRenderer``) and filters it client-side by title / summary / path,
/// rendering a results list that links to the matching pages. This is full-text site search,
/// distinct from the nav *filter* (which only hides non-matching rows already in the rail).
/// A `.global` renderer – emitted once per build.
public struct OpenAPISearchScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   /// The public URL `OpenAPIShell` links from the page (deferred).
   public static let scriptURL = "/assets/js/openapi-search.js"

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try OpenAPIStylesheetRenderer.loadResource(named: "openapi-search", withExtension: "js")
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("openapi-search.js")
      return [OutputFile(outputPath: path, content: js)]
   }
}
