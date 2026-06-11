import Foundation

/// Emits `/assets/theme/css/tokens.css` from the theme's preset and per-site
/// token overrides – colours, fonts, spacing, radii.
///
/// Always `.global` scope: tokens are site-wide and locale-independent.
/// `PageShell` inlines a critical subset of these tokens directly in the
/// `<head>` of every page to keep first paint synchronous; this renderer
/// still emits the full file so theme JavaScript or sites that override
/// theme CSS can reference it.
public struct TokenCSSOutputRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard let css = TokenCSSGenerator.generate(themeConfig: context.themeConfig) else { return [] }
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("theme")
         .appendingPathComponent("css")
         .appendingPathComponent("tokens.css")
      return [OutputFile(outputPath: path, content: css)]
   }
}
