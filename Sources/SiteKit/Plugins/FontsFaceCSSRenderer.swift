import Foundation

/// Emits `/assets/theme/fonts.css` with `@font-face` rules when `theme.yaml` has
/// `selfHostedFonts: true`. PageShell loads this file asynchronously (preload+onload) so
/// font downloads don't compete with HTML and critical CSS for bandwidth on first paint.
///
/// The woff2 files must be placed in `Theme/fonts/` using the naming convention
/// `{FamilyNameNoSpaces}-{weight}.woff2` – e.g., `Inter-400.woff2`, `JetBrainsMono-500.woff2`.
/// The `AssetCopier` copies the whole `Theme/` directory to `/assets/theme/` at build time,
/// so fonts end up at `/assets/theme/fonts/...` automatically.
public struct FontsFaceCSSRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard let css = TokenCSSGenerator.selfHostedFontFaceCSS(themeConfig: context.themeConfig) else {
         return []
      }
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("theme")
         .appendingPathComponent("fonts.css")
      return [OutputFile(outputPath: path, content: css)]
   }
}
