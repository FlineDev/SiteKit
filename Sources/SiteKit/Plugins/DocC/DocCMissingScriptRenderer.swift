import Foundation

/// Emits SiteKit's bundled missing-sessions "Show more" script (`docc-missing.js`) to
/// `/assets/js/docc-missing.js`. `DocCMissingPage` links it `defer` from its `<head>`.
/// The script collapses each year's overflow stub cards behind a toggle button and
/// reveals that button. Progressive enhancement: with no JS every card stays visible
/// and the button stays hidden, so all stub sessions remain reachable. Runs once per build.
public struct DocCMissingScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("docc-missing.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL `DocCMissingPage` links from `<head>`.
   public static let scriptURL = "/assets/js/docc-missing.js"

   /// Returns the bundled `docc-missing.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-missing.js",
         at: Bundle.module.url(forResource: "docc-missing", withExtension: "js")
      )
   }
}
