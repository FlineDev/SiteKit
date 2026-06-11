import Foundation

/// Declares how often a `Renderer` runs across the locales of a multilingual
/// build.
///
/// - `.perLocale`: the renderer runs once for every locale's `BuildContext`
///   and produces per-locale output files (article HTML, listings, per-locale
///   feeds, per-locale CSS). This is the default for the `Renderer` extension.
/// - `.global`: the renderer runs exactly once per build, regardless of
///   locale count, and produces site-wide output files (sitemap.xml,
///   sitemap-index, robots.txt, llms.txt, Cloudflare `_headers`,
///   `_redirects`, language-redirect HTML). For multilingual sites,
///   declaring `.global` avoids redundant work and prevents per-locale
///   invocations from overwriting each other.
///
/// The pipeline routes renderers by this declared scope, not by type
/// identity – adding a new global system file means declaring `.global` on
/// the new renderer and registering it, with no central registry edit
/// required.
public enum RenderScope: Sendable {
   /// Run once per locale's `BuildContext` – the default.
   case perLocale
   /// Run exactly once per build, with the default locale's context.
   case global
}
