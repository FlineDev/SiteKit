import Foundation
import SiteKit

/// The shared OpenAPI app-shell: the chrome every OpenAPI page renderer wraps its
/// body in, so the whole API-docs site presents one consistent docs layout.
///
/// Mirrors `DocCShell`: it brings its own appbar (and, from a later slice, a
/// sidebar nav rail), so it wraps through `PageShell.wrap(... chrome: .appShell)`,
/// which suppresses the generic site `<header>`/`<footer>` that would otherwise
/// double up. Color, fonts, and accents come from the theme tokens, so the shell
/// inherits the active scheme without hard-coded brand values. The stylesheet that
/// targets these `sk-openapi-*` classes and the `data-method` verb colors is a
/// later slice; this slice emits the semantic structure those rules will target.
///
/// Structure:
/// ```
/// div.sk-openapi-layout
///   header.sk-openapi-appbar        ← brand (links to the landing page)
///   div.sk-openapi-body             ← flex row: [sidebar nav: later slice] | content
///     main.sk-openapi-scroll
///       div.sk-openapi-page
///         {content}                 ← the caller's page body
/// ```
enum OpenAPIShell {
   /// Assembles the app-shell around `content` and returns the complete HTML page.
   ///
   /// - Parameters:
   ///   - content: The page-specific body HTML.
   ///   - page: The synthetic `PageModel` for this page, threaded to `PageShell`.
   ///   - context: The build context (config, theme, output paths).
   ///   - head: The fully-built `<head>` content (each renderer builds its own via
   ///     `OutputFileRenderer.buildHead(...)` so canonical/OG carry the page's real URL).
   static func wrap(content: String, page: PageModel, context: BuildContext, head: String) -> String {
      let shell =
         "<div class=\"sk-openapi-layout\">"
         + self.appbar(context: context)
         + "<div class=\"sk-openapi-body\">"
         // A later slice mounts the tag/operation/schema sidebar nav tree here.
         + "<!-- nav sidebar mounts here in a later slice -->"
         + "<main class=\"sk-openapi-scroll\">"
         + "<div class=\"sk-openapi-page\">"
         + content
         + "</div>"
         + "</main>"
         + "</div>"
         + "</div>"

      return PageShell.wrap(
         content: shell,
         page: page,
         context: context,
         head: head,
         bodyClass: "sk-openapi-shell-body",
         chrome: .appShell
      )
   }

   /// The appbar: the API name as a brand wordmark linking back to the landing page.
   static func appbar(context: BuildContext) -> String {
      let homeURL = OpenAPIHTML.escape(OpenAPIRoutes.landingPath(context))
      let name = OpenAPIHTML.escape(context.config.name)
      return "<header class=\"sk-openapi-appbar\">"
         + "<a class=\"sk-openapi-brand\" href=\"\(homeURL)\">\(name)</a>"
         + "</header>"
   }
}
