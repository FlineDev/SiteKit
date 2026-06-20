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
   /// Swagger-UI family), harmonized to read as white-on-color chips in light and
   /// dark. These are the one place fixed hues are allowed (the verb semantics are
   /// universal); everything else derives from theme tokens.
   static let verbColors: [(verb: String, color: String)] = [
      ("get", "#61affe"),
      ("post", "#49cc90"),
      ("put", "#fca130"),
      ("patch", "#50e3c2"),
      ("delete", "#f93e3e"),
      ("head", "#9012fe"),
      ("options", "#0d5aa7"),
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
   /// the method badge's background. Shared by the operation header and the nav rail
   /// (both use `.sk-openapi-method[data-method="<verb>"]`).
   static func methodColorCSS() -> String {
      var lines = [
         "",
         "/* HTTP-verb colors – generated from the semantic verb palette. One rule per verb",
         "   paints the method badge background; the label is white (openapi.css) so it reads",
         "   on the saturated chip in light and dark. */",
      ]
      for entry in self.verbColors {
         lines.append(".sk-openapi-method[data-method=\"\(entry.verb)\"] { background: \(entry.color); }")
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
