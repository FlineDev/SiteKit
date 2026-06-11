import Foundation

/// Emits the micro base CSS (reset, accessibility, body layout) from SiteKit's bundled resources.
/// Only active when the token system is in use.
///
/// Note: `OutputFileRenderer.buildHead()` inlines the same CSS directly in the `<head>` of
/// every page to avoid an extra render-blocking request on first visit. This file is still
/// emitted at `/assets/css/base.css` so theme CSS can `@import` it or sites can reference
/// it explicitly if they need to.
public struct BaseCSSOutputRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard context.themeConfig?.hasTokens == true else { return [] }

      let css = try Self.loadBaseCSS()

      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("css")
         .appendingPathComponent("base.css")
      return [OutputFile(outputPath: path, content: css)]
   }

   /// Returns the base CSS as a string, for inlining in `<head>` or emitting as a file.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without its base styles.
   public static func loadBaseCSS() throws -> String {
      try BundledResource.loadText(
         named: "base.css",
         at: Bundle.module.url(forResource: "base", withExtension: "css")
      )
   }
}
