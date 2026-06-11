import Foundation

/// Produces zero or more `OutputFile`s from a read-only `BuildContext`.
///
/// `Renderer` is SiteKit's system-level rendering primitive – phase 5 of the
/// pipeline. Use it for non-HTML system outputs (sitemap, robots.txt, RSS
/// feeds, JSON indexes, CSS bundles, Cloudflare `_headers`, redirects). For
/// full HTML pages with the standard site chrome (head, header, footer, theme
/// CSS, hreflang, OG, JSON-LD), conform to `Page` instead – `Page` extends
/// `Renderer` and applies `PageShell` automatically.
///
/// `scope: RenderScope` declares whether the renderer runs once per locale
/// (`.perLocale`, the default) or once per build (`.global`). Routing is by
/// the declared scope, not by type identity.
///
/// ## How to implement
///
/// ```swift
/// public struct MyRenderer: Renderer {
///    public var scope: RenderScope { .global }  // or .perLocale
///    public init() {}
///    public func render(context: BuildContext) throws -> [OutputFile] {
///       let path = context.outputDirectory.appendingPathComponent("my-output.txt")
///       return [OutputFile(outputPath: path, content: "hello")]
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.renderer(MyRenderer())`. See AGENTS.md §6 for a
/// worked example.
///
/// ## What this should NOT do
///
/// - Mutate `BuildContext` – it is read-only and shared across renderers.
/// - Read or discover source files from disk – that is the `ContentDiscovery`
///   and `Loader` phases.
/// - Apply post-render transformations to other renderers' output – that is
///   the `OutputProcessor` phase (phase 6).
/// - Emit the standard HTML site chrome – conform to `Page` instead so
///   `PageShell` handles `<head>`/`<header>`/`<footer>` consistently.
public protocol Renderer {
   /// Whether the pipeline invokes this renderer once per locale (`.perLocale`)
   /// or exactly once per build (`.global`). Defaults to `.perLocale` via the
   /// protocol extension; declare `.global` for site-wide singletons such as
   /// the sitemap index, robots.txt, or Cloudflare `_headers`.
   var scope: RenderScope { get }

   /// Produces this renderer's output files for one build pass.
   ///
   /// Called once per locale's `BuildContext` (`.perLocale`) or once with the
   /// default locale's context (`.global`). Return an empty array when there is
   /// nothing to emit – e.g. a feature gated off in `SiteConfig`. A thrown error
   /// aborts the whole build, so throw only on genuine misconfiguration, not on
   /// absent optional content.
   func render(context: BuildContext) throws -> [OutputFile]
}

extension Renderer {
   /// Renderers run once per locale unless they opt into `.global` explicitly.
   public var scope: RenderScope { .perLocale }
}
