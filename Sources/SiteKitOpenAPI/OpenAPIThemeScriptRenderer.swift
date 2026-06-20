import Foundation
import SiteKit

/// Emits the bundled appbar theme-toggle script to `/assets/js/openapi-theme.js`. The
/// `OpenAPIShell` links it (deferred) from every page.
///
/// Consistent with the base SiteKit (DocC) theme toggle: same `localStorage "theme"` key and
/// `data-theme` contract, so a reader's light/dark choice persists across every SiteKit surface
/// on the site. With no stored key the toggle follows the OS appearance live (the inline
/// head-init applied the initial `data-theme`); a click flips the effective theme, persists the
/// opposite value, and stops following the OS. Progressive enhancement: without JS the button
/// renders as inert HTML and clicking does not switch (matching the base DocC toggle). A
/// `.global` renderer.
public struct OpenAPIThemeScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   /// The public URL `OpenAPIShell` links from the page (deferred).
   public static let scriptURL = "/assets/js/openapi-theme.js"

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try OpenAPIStylesheetRenderer.loadResource(named: "openapi-theme", withExtension: "js")
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("openapi-theme.js")
      return [OutputFile(outputPath: path, content: js)]
   }
}
