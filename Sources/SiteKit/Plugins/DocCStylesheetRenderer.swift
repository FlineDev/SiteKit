import Foundation

/// Emits SiteKit's bundled DocC component stylesheet (`docc.css`) to
/// `/assets/css/docc.css`. `DocCArticlePage` links it from each note's `<head>`,
/// so the DocC layout (sidebar grid) and components (header chrome, Quick Read,
/// contributors, directive blocks) are styled. The CSS is token-based, so a DocC
/// site inherits its theme's color scheme and fonts. Runs once per build.
///
/// When `docc.frameworks` is configured with `colors`, this renderer appends a
/// generated block of `[data-framework="key"]` CSS rules that paint each framework's
/// icon tile in its registry color (a solid fill or a gradient). The glyph itself is
/// rendered white by docc.css, so the icon reads as a white-on-color chip. The rules
/// are data-driven from config – no hardcoding of specific framework names.
public struct DocCStylesheetRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      var css = try Self.loadDocCCSS()

      // Append generated framework-tile rules when the registry is configured. Each framework
      // carries 1 or 2 hex colors; 1 color paints a solid tile, 2 colors a 145deg gradient tile.
      // The rule targets `[data-framework="key"]` on the icon span (sidebar, session row, and
      // related-item chips share it); the glyph inside stays white via docc.css for contrast.
      if let frameworks = context.config.docc?.frameworks, !frameworks.isEmpty {
         css += Self.frameworkColorCSS(from: frameworks)
      }

      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("css")
         .appendingPathComponent("docc.css")
      return [OutputFile(outputPath: path, content: css)]
   }

   /// The public URL `DocCArticlePage` links from `<head>`.
   public static let cssURL = "/assets/css/docc.css"

   /// Returns the DocC stylesheet as a string, for emitting at `cssURL`.
   /// Throws when the resource is missing from the module bundle, so a build cannot
   /// silently produce a site without its DocC styles.
   public static func loadDocCCSS() throws -> String {
      try BundledResource.loadText(
         named: "docc.css",
         at: Bundle.module.url(forResource: "docc", withExtension: "css")
      )
   }

   /// Generates a CSS block with one rule per framework key so each framework's icon tile
   /// renders in its registry color. Sorted by key for deterministic output.
   ///
   /// Each rule paints the chip's `background` only: `[data-framework="key"] { background: ... }`
   /// – a solid fill for a single color, a 145deg gradient for two. The glyph itself is rendered
   /// white by docc.css, so a white glyph on the saturated tile stays legible in both light and
   /// dark. The glyph color is deliberately NOT set here (the earlier `color: colors[0]` made the
   /// glyph the same hue as its tile, the low-contrast bug this fix removes).
   static func frameworkColorCSS(from frameworks: [String: DocCFrameworkIcon]) -> String {
      var lines: [String] = ["\n/* Framework icon tiles – generated from docc.frameworks registry. One rule per key paints",
                             "   the chip background (1 color: solid fill, 2 colors: 145deg gradient); the glyph is white",
                             "   (docc.css) so it reads on the saturated tile in both light and dark. */"]
      for key in frameworks.keys.sorted() {
         guard let icon = frameworks[key], !icon.colors.isEmpty else { continue }
         // Escape the key for CSS attribute selector safety: strip anything that is not
         // alphanumeric, hyphen, or underscore (keys are validated on decode, but be safe).
         let safeKey = key.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
         guard !safeKey.isEmpty else { continue }
         let color0 = icon.colors[0]
         if icon.colors.count >= 2 {
            let color1 = icon.colors[1]
            lines.append("[data-framework=\"\(safeKey)\"] { background: linear-gradient(145deg, \(color0), \(color1)); }")
         } else {
            lines.append("[data-framework=\"\(safeKey)\"] { background: \(color0); }")
         }
      }
      return lines.joined(separator: "\n") + "\n"
   }
}
