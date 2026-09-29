import Foundation
import SiteKit

/// Renders the site's 404 page through the full ``OpenAPIShell`` – appbar (brand → landing,
/// search, theme toggle), the nav rail, and the footer – with a "page not found" message and a
/// link back to the API landing in the content area.
///
/// Mirrors `DocCMissingPage`: a blueprint that ships an error page in its own chrome rather than
/// the base `ErrorPageRenderer`'s footer-only page, so a reader who lands on a missing URL can
/// navigate straight back into the docs instead of hitting a dead end. Still emitted at
/// `404.html` (the Cloudflare Pages convention), so the redirect renderers are unaffected.
/// Built from ``OpenAPISpec`` only – no `import OpenAPIKit`.
public struct OpenAPIMissingPage: Page {
   private let spec: OpenAPISpec

   /// Creates the 404 renderer for `spec` (the spec backs the shared nav rail).
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func pages(in context: BuildContext) -> [PageModel] {
      [
         PageModel(
            title: "Page not found",
            slug: "404",
            htmlContent: "",
            sourcePath: context.projectDirectory
               .appendingPathComponent(context.config.contentDirectory)
               .appendingPathComponent("openapi.yaml"),
            pageType: .staticPage,
            // A path that matches no nav item, so the shell marks nothing active on the 404.
            extensions: ["openAPIPath": "/404.html"]
         )
      ]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let landing = OpenAPIRoutes.landingPath(context)
      let renderer = OutputFileRenderer(context: context)
      let head = renderer.buildHead(
         title: "\(page.title) – \(context.config.name)",
         description: "The page you are looking for could not be found.",
         canonicalURL: "\(context.config.baseURL)/404.html",
         ogType: "website"
      )

      let body =
         "<article class=\"sk-openapi-notfound\">"
         + "<h1 class=\"sk-openapi-title\">\(OpenAPIHTML.escape(page.title))</h1>"
         + "<p class=\"sk-openapi-description\">The page you are looking for does not exist or may have moved.</p>"
         + "<p><a class=\"sk-openapi-notfound-home\" href=\"\(OpenAPIHTML.escape(landing))\">"
         + "Back to \(OpenAPIHTML.escape(context.config.name))</a></p>"
         + "</article>"

      return OpenAPIShell.wrap(content: body, page: page, context: context, head: head, spec: self.spec)
   }

   /// Writes the page to `<outputDir>/404.html` (the host serves it for unmatched paths).
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      context.outputDirectory.appendingPathComponent("404.html")
   }
}
