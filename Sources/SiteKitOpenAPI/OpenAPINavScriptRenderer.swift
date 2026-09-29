import Foundation
import SiteKit

/// Emits SiteKitOpenAPI's bundled nav-rail enhancement script to
/// `/assets/js/openapi-nav.js`. `OpenAPIShell` links it from every page (deferred).
///
/// The script is progressive enhancement only: the rail is a fully navigable list
/// without JS. The script adds collapse/expand twists per group, a live filter box,
/// scrolls the active item into view, and wires the mobile drawer toggle. Mirrors
/// `DocCSidebarScriptRenderer` / `DocCFilterScriptRenderer`, adapted to the
/// `sk-openapi-*` markup. A `Renderer` with `scope: .global`, so it runs once per
/// build.
///
/// (Classic in-page-TOC scrollspy does not apply here: the rail is a cross-page tree,
/// not an in-page heading list, so "active section" is the current page's item, which
/// the server marks `aria-current` and the script scrolls into view. An in-page TOC
/// rail with heading scrollspy would be a separate addition.)
public struct OpenAPINavScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   /// The public URL `OpenAPIShell` links from the page (deferred).
   public static let scriptURL = "/assets/js/openapi-nav.js"

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try OpenAPIStylesheetRenderer.loadResource(named: "openapi-nav", withExtension: "js")
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("openapi-nav.js")
      return [OutputFile(outputPath: path, content: js)]
   }
}
