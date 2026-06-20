import Foundation
import SiteKit

/// The shared OpenAPI app-shell: the chrome every OpenAPI page renderer wraps its
/// body in, so the whole API-docs site presents one consistent docs layout.
///
/// Mirrors `DocCShell`: it brings its own appbar and a persistent sidebar nav rail,
/// so it wraps through `PageShell.wrap(... chrome: .appShell)`, which suppresses the
/// generic site `<header>`/`<footer>` that would otherwise double up. Color, fonts,
/// and accents come from the theme tokens, so the shell inherits the active scheme
/// without hard-coded brand values. The stylesheet that targets these `sk-openapi-*`
/// classes (and the `data-method` verb colors and the sidebar collapse/expand
/// script) is a later slice; this slice emits the semantic structure those rules and
/// that script will target.
///
/// Structure:
/// ```
/// div.sk-openapi-layout
///   header.sk-openapi-appbar        ← brand (links to the landing page)
///   div.sk-openapi-body             ← flex row: [sidebar nav rail] | content
///     nav.sk-openapi-nav            ← landing + tag/operation/schema tree (active item marked)
///     main.sk-openapi-scroll
///       div.sk-openapi-page
///         {content}                 ← the caller's page body
/// ```
enum OpenAPIShell {
   /// Assembles the app-shell (appbar + sidebar nav rail + content) around `content`
   /// and returns the complete HTML page.
   ///
   /// - Parameters:
   ///   - content: The page-specific body HTML.
   ///   - page: The synthetic `PageModel` for this page, threaded to `PageShell`. The
   ///     page identifies the active nav item: every OpenAPI page stashes its
   ///     canonical path in the `openAPIPath` extension, and the landing page (the only
   ///     one without it) falls back to the landing path.
   ///   - context: The build context (config, theme, output paths).
   ///   - head: The fully-built `<head>` content (each renderer builds its own via
   ///     `OutputFileRenderer.buildHead(...)` so canonical/OG carry the page's real URL).
   ///   - spec: The loaded spec, from which the shared nav rail is built so every page
   ///     shows the same tree with this page marked active.
   static func wrap(content: String, page: PageModel, context: BuildContext, head: String, spec: OpenAPISpec) -> String {
      let currentPath: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.landingPath(context)
      let nav = OpenAPISidebarRenderer.render(spec: spec, context: context, currentPath: currentPath)

      // Link the component stylesheet after the caller's critical head (so it never blocks
      // first paint) and defer the nav-enhancement script (progressive enhancement: the rail
      // works without it). Both are emitted once per build by their `.global` renderers.
      let headWithAssets =
         head
         + "<link rel=\"stylesheet\" href=\"\(OpenAPIStylesheetRenderer.cssURL)\"/>"
         + "<script defer src=\"\(OpenAPINavScriptRenderer.scriptURL)\"></script>"

      let shell =
         "<div class=\"sk-openapi-layout\">"
         + self.appbar(context: context)
         + "<div class=\"sk-openapi-body\">"
         + nav
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
         head: headWithAssets,
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
