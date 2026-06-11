import Foundation

/// Emits SiteKit's bundled DocC client-side search script (`docc-search.js`) to
/// `/assets/search/docc-search.js`. `DocCArticlePage` links it from each note's
/// `<head>` (deferred). The script lazily loads the sharded index and matches the
/// query against each record's title and body excerpt. Runs once per build.
public struct DocCSearchScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("search")
         .appendingPathComponent("docc-search.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL `DocCArticlePage` links from `<head>`.
   public static let scriptURL = "/assets/search/docc-search.js"

   /// Returns the bundled `docc-search.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-search.js",
         at: Bundle.module.url(forResource: "docc-search", withExtension: "js")
      )
   }
}
