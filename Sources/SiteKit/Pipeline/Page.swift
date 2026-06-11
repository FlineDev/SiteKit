import Foundation

/// Produces one HTML output file per page in the build context, wrapped in the
/// standard site chrome.
///
/// `Page` is the primary customisation surface for adding HTML page types to a
/// SiteKit site. It is a sub-protocol of `Renderer` so that page renderers and
/// system renderers compose uniformly in the pipeline, while keeping the
/// HTML-emitting surface focused on the two questions that actually vary per
/// page type: *which* pages to render, and *how* to render one.
///
/// The default `render(context:)` extension iterates `pages(in:)` and
/// calls `renderHTML(_:context:)` for each – conformers do not implement
/// `Renderer.render` directly.
///
/// ## How to implement
///
/// ```swift
/// public struct RecipePage: Page {
///    public init() {}
///    public func pages(in context: BuildContext) -> [PageModel] {
///       context.sections.first(where: { $0.config.slug == "recipes" })?.pages ?? []
///    }
///    public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
///       let body = "<article><h1>\(page.title)</h1>\(page.htmlContent)</article>"
///       return PageShell.wrap(content: body, page: page, context: context)
///    }
/// }
/// ```
///
/// Always call `PageShell.wrap(content:page:context:)` to get the standard
/// `<head>`/`<header>`/`<footer>`/theme CSS/hreflang/OG/JSON-LD. The built-in
/// renderers (`ArticlePageRenderer`, `HomePageRenderer`, `SectionPageRenderer`,
/// `StaticPageRenderer`, etc.) delegate to `OutputFileRenderer` helpers that
/// invoke PageShell internally – see those for working examples and AGENTS.md
/// §5 for the full extension recipe.
///
/// Override `outputURL(for:context:)` only when the renderer produces pages at
/// non-standard paths (home, listings, error pages, podcast variants); the
/// default dispatches by `page.pageType` through `context.router`.
///
/// ## What this should NOT do
///
/// - Emit non-HTML files – that is `Renderer`'s job. A `.css`, `.xml`, or
///   `.json` output should live in a plain `Renderer` conformer.
/// - Bypass `PageShell` – handcrafting `<head>` skips canonical URLs, hreflang,
///   OG, JSON-LD, performance preloads, and per-locale UI strings.
/// - Mutate `BuildContext` – it is read-only.
/// - Write the output file directly – `render` does that via the `OutputFile`
///   return value.
public protocol Page: Renderer {
   /// Returns the pages this renderer is responsible for in the current build context.
   func pages(in context: BuildContext) -> [PageModel]

   /// Returns the fully-rendered HTML for one page (chrome included). SiteKit's
   /// built-in conformers delegate to `OutputFileRenderer` helpers, which wrap the
   /// body with PageShell chrome. Custom conformers should call
   /// `PageShell.wrap(content:page:context:)` from inside this method to get the
   /// same chrome – the `content:` argument there is the body-only HTML, while the
   /// return value of `renderHTML` is the assembled full document.
   func renderHTML(_ page: PageModel, context: BuildContext) -> String

   /// Returns the output URL where the rendered page will be written.
   ///
   /// The default extension dispatches by `page.pageType`: `.article` uses the
   /// router's `articlePath(for:)`, `.staticPage` uses `staticPagePath(for:)`.
   /// Override when the renderer produces pages at non-standard paths (home,
   /// listings, error pages, section pages, podcast variants, draft previews).
   func outputURL(for page: PageModel, context: BuildContext) -> URL
}

extension Page {
   /// Default `render` iterates `pages(in:)` and produces one `OutputFile`
   /// per page by calling `renderHTML` for the full HTML and `outputURL` for the
   /// destination path. PageShell wrapping happens inside `renderHTML` (built-in
   /// renderers delegate to OutputFileRenderer; custom renderers call
   /// `PageShell.wrap(...)` directly).
   public func render(context: BuildContext) throws -> [OutputFile] {
      self.pages(in: context).map { page in
         OutputFile(
            outputPath: self.outputURL(for: page, context: context),
            content: self.renderHTML(page, context: context)
         )
      }
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String
      switch page.pageType {
      case .article:
         path = context.router.articlePath(for: page)
      case .staticPage:
         path = context.router.staticPagePath(for: page)
      }
      let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }
}
