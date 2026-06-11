import Foundation

/// Renders the 404 error page at `/404.html` (and `/<locale>/404.html` on
/// multilingual sites).
///
/// Title and message come from `SiteConfig.errorPages["404"]` when set,
/// otherwise from the locale-aware `UIStrings`. The 404 has no underlying
/// `PageModel`, so `pages(in:)` returns a single synthesized marker.
public struct ErrorPageRenderer: Page {
   public init() {}

   /// The 404 page has no underlying `PageModel`; we synthesize a single marker.
   public func pages(in context: BuildContext) -> [PageModel] {
      [Self.marker()]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      OutputFileRenderer(context: context).render404Page().content
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      // Mirrors path computation in OutputFileRenderer.render404Page –
      // default-locale at /404.html, other locales at /<locale>/404.html.
      let locale = context.uiStrings.locale
      let defaultLang = context.config.effectiveDefaultLanguage
      if locale == defaultLang {
         return context.outputDirectory.appendingPathComponent("404.html")
      }
      return context.outputDirectory.appendingPathComponent(locale).appendingPathComponent("404.html")
   }

   private static func marker() -> PageModel {
      PageModel(
         title: "",
         slug: "",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/dev/null"),
         pageType: .staticPage
      )
   }
}
