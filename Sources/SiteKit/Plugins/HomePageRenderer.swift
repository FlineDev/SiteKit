import Foundation

/// Renders the site home page at `/` (and `/<locale>/` on multilingual sites).
///
/// The home page has no underlying source `PageModel`, so `pages(in:)`
/// returns a single synthesized marker; `renderHTML` ignores the marker and
/// asks `OutputFileRenderer.renderHomePage` to assemble the page from
/// `context.config.homePage` (title/subtitle), `context.homeContent`
/// (optional Markdown body), and `context.articles` (recent posts).
///
/// Subclassing pattern: write a custom `HomePageRenderer`-style conformer and
/// register it via `SiteBuilder.renderer(_:)`. Override `outputURL` only if
/// you ship a home at a non-root path.
public struct HomePageRenderer: Page {
   public init() {}

   /// The home page does not correspond to a loaded `PageModel`, so we synthesize a
   /// single marker model for it. `renderHTML` and `outputURL` use the context to
   /// produce the actual home HTML and `/index.html` path (or `/<locale>/index.html`).
   public func pages(in context: BuildContext) -> [PageModel] {
      [Self.homeMarker()]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      OutputFileRenderer(context: context)
         .renderHomePage(recentPosts: context.articles, homeContent: context.homeContent)
         .content
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      // Mirrors path computation in OutputFileRenderer.renderHomePage –
      // "" or "<locale>/" relative to outputDirectory, then "index.html".
      let homePath = context.router.homePath()
      let relative = String(homePath.dropFirst())
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   private static func homeMarker() -> PageModel {
      PageModel(
         title: "",
         slug: "",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
