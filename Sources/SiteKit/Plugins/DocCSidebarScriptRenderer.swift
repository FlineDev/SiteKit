import Foundation

/// Emits SiteKit's bundled DocC off-canvas sidebar toggle script
/// (`docc-sidebar.js`) to `/assets/js/docc-sidebar.js`. `DocCArticlePage` links it
/// from each note's `<head>` (deferred). The script wires the mobile hamburger
/// button, the close button, the scrim, the Escape key, and nav-link taps to the
/// off-canvas drawer. Progressive enhancement: with no JS the sidebar stacks above
/// the content (no-JS fallback CSS), so navigation is never blocked. Runs once per
/// build.
public struct DocCSidebarScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("docc-sidebar.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL `DocCArticlePage` links from `<head>`.
   public static let scriptURL = "/assets/js/docc-sidebar.js"

   /// Returns the bundled `docc-sidebar.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-sidebar.js",
         at: Bundle.module.url(forResource: "docc-sidebar", withExtension: "js")
      )
   }
}
