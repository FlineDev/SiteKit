import Foundation

/// Emits SiteKit's bundled DocC TOC scroll-spy script (`docc-toc.js`) to
/// `/assets/js/docc-toc.js`. `DocCArticlePage` links it from each note's
/// `<head>` (deferred). The script watches the article's h2/h3 headings and
/// keeps the matching `.sk-docc-toc-item` highlighted with `is-active` as the
/// user scrolls the independently-scrolling `.sk-docc-scroll` container.
/// Clicking a TOC item smooth-scrolls the target heading into view inside that
/// container, respecting the heading's `scroll-margin-top`. Progressive
/// enhancement: with no JS the anchor links still jump to their targets and the
/// `is-active` highlight is simply never set.
public struct DocCTocScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("docc-toc.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL `DocCArticlePage` links from `<head>`.
   public static let scriptURL = "/assets/js/docc-toc.js"

   /// Returns the bundled `docc-toc.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-toc.js",
         at: Bundle.module.url(forResource: "docc-toc", withExtension: "js")
      )
   }
}
