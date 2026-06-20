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
      // first paint) and defer the enhancement scripts (progressive enhancement: the rail,
      // search, and theme toggle all work as plain HTML without them). The inline theme-init
      // runs before first paint so an OS-dark reader never sees a light flash. All are emitted
      // once per build by their `.global` renderers.
      let headWithAssets =
         head
         + self.themeInitScript(context: context)
         + "<link rel=\"stylesheet\" href=\"\(OpenAPIStylesheetRenderer.cssURL)\"/>"
         + "<script defer src=\"\(OpenAPINavScriptRenderer.scriptURL)\"></script>"
         + "<script defer src=\"\(OpenAPISearchScriptRenderer.scriptURL)\"></script>"
         + "<script defer src=\"\(OpenAPIThemeScriptRenderer.scriptURL)\"></script>"

      let shell =
         "<div class=\"sk-openapi-layout\">"
         + self.appbar(context: context)
         + "<div class=\"sk-openapi-body\">"
         + nav
         // Off-canvas backdrop (mobile drawer): shown behind the rail when open, click/tap or
         // Escape closes it. Gated behind html.js by the stylesheet (cut-the-mustard).
         + "<div class=\"sk-openapi-scrim\" data-openapi-nav-scrim hidden></div>"
         + "<main class=\"sk-openapi-scroll\">"
         + "<div class=\"sk-openapi-page\">"
         + content
         + "</div>"
         + self.footerHTML(context: context)
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

   /// The appbar: the API name as a brand wordmark linking back to the landing page, plus a
   /// full-text search box. The search box is only useful with JavaScript (it queries
   /// `/assets/search-index.json`), so the stylesheet reveals it behind `html.js` – a JS-off
   /// reader never sees a dead control.
   static func appbar(context: BuildContext) -> String {
      let homeURL = OpenAPIHTML.escape(OpenAPIRoutes.landingPath(context))
      let name = OpenAPIHTML.escape(context.config.name)
      return "<header class=\"sk-openapi-appbar\">"
         + "<a class=\"sk-openapi-brand\" href=\"\(homeURL)\">\(name)</a>"
         + "<div class=\"sk-openapi-search\">"
         + "<input type=\"search\" class=\"sk-openapi-search-input\" data-openapi-search"
         + " placeholder=\"Search the API…\" aria-label=\"Search the API\" autocomplete=\"off\""
         + " role=\"combobox\" aria-expanded=\"false\" aria-controls=\"sk-openapi-search-results\"/>"
         + "<div class=\"sk-openapi-search-results\" id=\"sk-openapi-search-results\" role=\"listbox\" hidden></div>"
         + "</div>"
         + Self.themeToggleHTML
         + "</header>"
   }

   /// The appearance toggle button, consistent with the base SiteKit (DocC) toggle: it flips
   /// the effective theme (light ↔ dark) and persists the choice under the shared
   /// `localStorage "theme"` key, the same contract `openapi-theme.js` and the head-init read –
   /// so a reader's choice carries across every SiteKit surface on the site. The static moon
   /// glyph is the default; `openapi-theme.js` swaps it to a sun while dark. Always rendered,
   /// inert without JS (matching the base DocC toggle).
   private static let themeToggleHTML =
      "<button type=\"button\" class=\"sk-openapi-theme-toggle\" data-openapi-theme-toggle aria-label=\"Toggle light or dark appearance\">"
      + "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
      + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
      + "<path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\"/></svg>"
      + "</button>"

   /// The flash-free theme-init, emitted inline in `<head>` so the right `data-theme` is set
   /// before first paint. Reads the shared `localStorage "theme"` key, falling back to the OS
   /// `prefers-color-scheme` – the same default-follow-OS behaviour the base SiteKit sites get
   /// from their theme `headInlineScript`. Skipped when the site's `theme.yaml` already provides
   /// a `headInlineScript` (PageShell injects that), so an author override is never doubled.
   private static func themeInitScript(context: BuildContext) -> String {
      guard context.themeConfig?.headInlineScript == nil else { return "" }
      return "<script>(function(){try{var t=localStorage.getItem('theme');"
         + "if(t!=='light'&&t!=='dark'){t=window.matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light';}"
         + "document.documentElement.setAttribute('data-theme',t);}catch(e){}})();</script>"
   }

   /// The shared footer, rendered from `SiteConfig.footer` (the standard footer config every
   /// SiteKit site uses): a row of footer links followed by a copyright line, token-styled and
   /// scrolling with the content like the DocC footer. Returns an empty string when nothing is
   /// configured, so no empty `<footer>` pollutes the DOM.
   static func footerHTML(context: BuildContext) -> String {
      guard let footer = context.config.footer else { return "" }
      let links = footer.links ?? []
      let copyright = Self.copyrightLine(footer: footer, siteName: context.config.name)
      guard !links.isEmpty || copyright != nil else { return "" }

      var inner = ""
      if !links.isEmpty {
         let items = links.map { link in
            "<a class=\"sk-openapi-footer-link\" href=\"\(OpenAPIHTML.escape(link.url))\">\(OpenAPIHTML.escape(link.title))</a>"
         }.joined()
         inner += "<nav class=\"sk-openapi-footer-links\" aria-label=\"Footer\">\(items)</nav>"
      }
      if let copyright {
         inner += "<p class=\"sk-openapi-footer-copyright\">\(OpenAPIHTML.escape(copyright))</p>"
      }
      return "<footer class=\"sk-openapi-footer\">\(inner)</footer>"
   }

   /// The copyright line: the explicit `copyright` string when set, else `© <name>` from
   /// `copyrightName` (falling back to the site name). Returns nil when neither yields text.
   private static func copyrightLine(footer: FooterConfig, siteName: String) -> String? {
      if let copyright = footer.copyright, !copyright.isEmpty {
         return copyright
      }
      let name = footer.copyrightName ?? siteName
      return name.isEmpty ? nil : "© \(name)"
   }
}
