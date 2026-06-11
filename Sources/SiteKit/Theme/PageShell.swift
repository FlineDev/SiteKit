import Foundation

/// Selects how much of SiteKit's site chrome `PageShell` wraps around the page body.
///
/// - `standard`: the full site chrome – generic site `<header>` navigation and
///   `<footer>`. This is the default and the behavior every page has always had.
/// - `appShell`: chrome-suppressed – only the skip link and the `#main-content`
///   wrapper are emitted; the page body supplies its own header/footer. Used by
///   self-contained app-shell layouts (e.g. the DocC docs shell, which renders its
///   own appbar + sidebar + footer and would double up on the generic site nav).
public enum PageChrome: Sendable {
   /// Full site chrome: generic `<header>` navigation and `<footer>` – the
   /// default.
   case standard
   /// Chrome-suppressed: only the skip link and the `#main-content` wrapper;
   /// the page body supplies its own header/footer.
   case appShell
}

/// SiteKit's page shell – the `<head>` + `<header>` + `<footer>` chrome that wraps
/// every HTML page produced by `Page` conformers.
///
/// AI agents and humans writing custom `Page` renderers should call
/// `PageShell.wrap(content:page:context:)` from `renderHTML(_:context:)` to get
/// the standard SiteKit chrome (SEO metadata, OG tags, JSON-LD, hreflang, theme CSS,
/// performance preloads, site navigation, footer). Bypassing PageShell is allowed but
/// loses these invariants – only do it when intentionally producing a non-standard
/// document (e.g. an HTML redirect stub).
///
/// PageShell is a thin public namespace over `OutputFileRenderer.renderPageShell(...)`,
/// which holds the actual HTML assembly. Renderer-specific arguments (`head`,
/// `bodyClass`, `dataAttributes`) can be supplied to customise the shell; sensible
/// defaults derived from the page model and build context are used otherwise.
public enum PageShell {
   /// Wraps a body string with SiteKit's full site chrome and returns the complete HTML page.
   ///
   /// - Parameters:
   ///   - content: The page-specific body HTML (typically `<main>...</main>`).
   ///   - page: The page model providing title, description, image, and metadata.
   ///   - context: The build context (config, router, theme, locale).
   ///   - head: Optional fully-built `<head>` content. When `nil`, PageShell derives
   ///     a head from `page` and `context` (title, description, OG, Twitter Card,
   ///     hreflang, JSON-LD) suitable for the page's `pageType`.
   ///   - bodyClass: Optional CSS classes on `<body>`. When `nil`, derived from `pageType`.
   ///   - dataAttributes: Optional `data-*` attributes on `<body>`.
   ///   - chrome: How much site chrome to wrap around `content`. Defaults to `.standard`
   ///     (generic site header + footer). Pass `.appShell` for layouts that render their
   ///     own chrome and must not inherit the site nav/footer.
   public static func wrap(
      content: String,
      page: PageModel,
      context: BuildContext,
      head: String? = nil,
      bodyClass: String? = nil,
      dataAttributes: [String: String] = [:],
      chrome: PageChrome = .standard
   ) -> String {
      let renderer = OutputFileRenderer(context: context)
      let effectiveHead = head ?? Self.defaultHead(for: page, context: context, renderer: renderer)
      let effectiveBodyClass = bodyClass ?? Self.defaultBodyClass(for: page)
      return renderer.renderPageShell(
         head: effectiveHead,
         bodyClass: effectiveBodyClass,
         dataAttributes: dataAttributes,
         content: content,
         chrome: chrome
      )
   }

   private static func defaultHead(for page: PageModel, context: BuildContext, renderer: OutputFileRenderer) -> String {
      let pageTitle = "\(page.title) – \(context.config.name)"
      let pagePath: String
      let jsonLD: String
      switch page.pageType {
      case .article:
         pagePath = context.router.articlePath(for: page)
         jsonLD = renderer.buildArticleJSONLD(page: page, canonicalURL: "\(context.config.baseURL)\(pagePath)")
      case .staticPage:
         pagePath = context.router.staticPagePath(for: page)
         jsonLD = renderer.buildWebPageJSONLD(page: page, canonicalURL: "\(context.config.baseURL)\(pagePath)")
      }
      let canonical = "\(context.config.baseURL)\(pagePath)"
      let hreflang: [String: String]? = page.extensionValue("hreflang")
      let ogType = page.pageType == .article ? "article" : "website"
      return renderer.buildHead(
         title: pageTitle,
         description: page.summary ?? page.description,
         canonicalURL: canonical,
         ogType: ogType,
         image: page.image,
         imageAlt: page.imageAlt,
         articleDate: page.pageType == .article ? page.date : nil,
         articleAuthor: page.author ?? context.config.author,
         articleCategory: page.pageType == .article ? page.category : nil,
         jsonLD: jsonLD,
         hreflang: hreflang
      )
   }

   private static func defaultBodyClass(for page: PageModel) -> String {
      switch page.pageType {
      case .article: return "sk-page-article"
      case .staticPage: return "sk-page-static"
      }
   }
}
