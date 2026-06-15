import Foundation

/// Emits SiteKit's bundled DocC sidebar theme-switch script (`docc-theme.js`) to
/// `/assets/js/docc-theme.js`. Every DocC page renderer links it from the page's
/// `<head>` (deferred). The script wires the three-option segmented control
/// (`.sk-docc-themeswitch`) to the shared `localStorage` theme key so Light / Dark /
/// Auto persist across page navigations and reloads, consistent with the site's
/// `headInlineScript` theme-init that runs on every page load.
///
/// Key–value contract (must match the site's `headInlineScript`):
///   - Key: `"theme"` in `localStorage`
///   - Values: `"light"` or `"dark"` (stored); absent key means Auto
///   - Effect: sets `data-theme` on `<html>` to `"light"` or `"dark"`
///
/// Progressive enhancement: when JS is absent the segmented control is still rendered
/// as plain HTML in the sidebar but clicking does not switch the theme.
public struct DocCThemeScriptRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let js = try Self.loadScript()
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("docc-theme.js")
      return [OutputFile(outputPath: path, content: js)]
   }

   /// The public URL page renderers link from `<head>`.
   public static let scriptURL = "/assets/js/docc-theme.js"

   /// Returns the bundled `docc-theme.js` as a string, for emitting at `scriptURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without this script.
   public static func loadScript() throws -> String {
      try BundledResource.loadText(
         named: "docc-theme.js",
         at: Bundle.module.url(forResource: "docc-theme", withExtension: "js")
      )
   }
}
