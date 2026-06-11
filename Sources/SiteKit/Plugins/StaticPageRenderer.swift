import Foundation

/// Renders top-level static pages (about, privacy, imprint, etc.) as
/// individual HTML files under the site root.
///
/// Inputs come from `context.staticPages` – `PageModel`s with
/// `pageType: .staticPage` that the loader pulled from the project's
/// `Pages/` (or section-specific) directory. Output paths follow
/// `URLRouter.staticPagePath(for:)`, which produces `/<slug>/index.html`
/// (with empty slug becoming `/`).
///
/// For static pages that need template variable substitution
/// (e.g. `{{EPISODE_COUNT}}`), use `TemplateStaticPageRenderer` instead.
public struct StaticPageRenderer: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      context.staticPages
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      OutputFileRenderer(context: context).renderStaticPage(page).content
   }
}
