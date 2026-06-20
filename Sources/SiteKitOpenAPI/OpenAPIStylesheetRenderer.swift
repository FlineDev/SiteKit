import Foundation
import SiteKit

/// Emits SiteKitOpenAPI's bundled component stylesheet to `/assets/css/openapi.css`,
/// and appends a generated block of semantic HTTP-verb color rules.
///
/// `OpenAPIShell` links this stylesheet from every page's `<head>` (after the
/// critical theme CSS, so it never blocks first paint). The stylesheet reads the
/// theme token variables, so an OpenAPI site inherits its color scheme, fonts, and
/// spacing across all schemes and layouts in light and dark, with no layout change.
///
/// The appended verb block is the `[data-method]` parallel to DocC's generated
/// `[data-framework]` tiles: one `.sk-openapi-method[data-method="<verb>"]` rule per
/// HTTP verb paints that verb's badge its semantic color (an industry-standard
/// Swagger/Stripe-like palette), shared by the operation-header badges and the
/// in-rail badges. The rules are generated (not hand-written per verb) so the palette
/// stays in one place. A `Renderer` with `scope: .global`, so it runs once per build.
public struct OpenAPIStylesheetRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   /// The public URL `OpenAPIShell` links from `<head>`.
   public static let cssURL = "/assets/css/openapi.css"

   /// The semantic HTTP-verb palette: an industry-standard hue per verb (the
   /// Swagger-UI family). These are the one place fixed hues are allowed (the verb
   /// semantics are universal); everything else derives from theme tokens.
   ///
   /// Each entry also fixes the badge `label` color, chosen so the label clears WCAG
   /// AA (≥ 4.5:1) on that background: near-black on the light verbs (GET/POST/PUT/
   /// PATCH/DELETE), white on the dark verbs (HEAD/OPTIONS). The blanket white the
   /// chips used before failed AA on the light hues, so the label color travels with
   /// the background – both generated, no hand-maintained drift. Computed ratios:
   /// GET 9.1, POST 10.3, PUT 10.3, PATCH 13.1, DELETE 5.8, HEAD 5.7, OPTIONS 6.9.
   static let verbColors: [(verb: String, background: String, label: String)] = [
      ("get", "#61affe", "#000"),
      ("post", "#49cc90", "#000"),
      ("put", "#fca130", "#000"),
      ("patch", "#50e3c2", "#000"),
      ("delete", "#f93e3e", "#000"),
      ("head", "#9012fe", "#fff"),
      ("options", "#0d5aa7", "#fff"),
   ]

   public func render(context: BuildContext) throws -> [OutputFile] {
      var css = try Self.loadStylesheet()
      css += Self.methodColorCSS()

      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("css")
         .appendingPathComponent("openapi.css")
      return [OutputFile(outputPath: path, content: css)]
   }

   /// Generates the per-verb color block: one rule per ``verbColors`` entry painting
   /// the method badge's background *and* its AA-checked label color. Shared by the
   /// operation header and the nav rail (both use `.sk-openapi-method[data-method=…]`).
   static func methodColorCSS() -> String {
      var lines = [
         "",
         "/* HTTP-verb colors – generated from the semantic verb palette. One rule per verb",
         "   paints the method badge background and its label color, the latter chosen so the",
         "   label clears WCAG AA (>= 4.5:1) on that hue (near-black on the light verbs, white",
         "   on the dark ones) in light and dark. */",
      ]
      for entry in self.verbColors {
         lines.append(
            ".sk-openapi-method[data-method=\"\(entry.verb)\"] { background: \(entry.background); color: \(entry.label); }"
         )
      }
      return lines.joined(separator: "\n") + "\n"
   }

   /// Loads the bundled `openapi.css` from the module resources. Throws when the
   /// resource is missing, so a build cannot silently produce an unstyled site.
   static func loadStylesheet() throws -> String {
      try Self.loadResource(named: "openapi", withExtension: "css")
   }

   /// Loads a bundled text resource from this module's bundle, or throws a clear error
   /// naming the missing file. (SiteKit's `BundledResource` is internal to that module,
   /// so this target carries its own small loader.)
   static func loadResource(named name: String, withExtension ext: String) throws -> String {
      guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
         throw OpenAPIResourceError.missing("\(name).\(ext)")
      }
      return try String(contentsOf: url, encoding: .utf8)
   }
}

/// An error raised when a bundled SiteKitOpenAPI asset (stylesheet, script) is absent
/// from the module bundle.
public enum OpenAPIResourceError: Error, Equatable, CustomStringConvertible {
   /// The named resource was not found in the module bundle.
   case missing(String)

   public var description: String {
      switch self {
      case .missing(let name):
         "Bundled SiteKitOpenAPI resource '\(name)' is missing from the module bundle."
      }
   }
}
