import Foundation

/// Mutates the output directory in place after every renderer has written its
/// files – phase 6 of the pipeline.
///
/// `OutputProcessor` is the right place for cross-cutting transformations that
/// need to see the *final* HTML / CSS / asset state: responsive image variants
/// (`ImageResizer`), one-pass FontAwesome SVG inlining (`FontAwesomeInliner`),
/// CSS `background-image` URL rewriting (`CSSBackgroundImageProcessor`),
/// minification (`AssetMinifier`), content-hash fingerprinting
/// (`AssetFingerprinter`). Runs once per build (not once per locale), after
/// every renderer completes.
///
/// Processors read + write files on disk in the output directory. The default
/// chain (`ImageResizer` → `FontAwesomeInliner` → `CSSBackgroundImageProcessor`
/// → `AssetMinifier` → `AssetFingerprinter`) applies only while no processor is
/// set explicitly: the first `SiteBuilder.processor(_:)` call starts a fresh
/// list, so registering a custom processor REPLACES the default chain rather
/// than appending to it. To keep the defaults and add your own, pass the full
/// list to `SiteBuilder.processors(_:)` with your processor appended.
///
/// ## How to implement
///
/// ```swift
/// public struct HTMLMinifier: OutputProcessor {
///    public init() {}
///    public func process(
///       outputDirectory: URL,
///       projectDirectory: URL,
///       themeConfig: ThemeConfig?
///    ) throws {
///       // walk outputDirectory, minify .html files in place
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.processor(_:)` (appends to the explicit list,
/// replacing the default chain on first use) or `SiteBuilder.processors(_:)`
/// (sets the entire chain; `nil` restores the defaults). See AGENTS.md §7 for
/// a worked example.
///
/// ## What this should NOT do
///
/// - Produce HTML pages or new system files – that is `Page` or `Renderer`.
/// - Depend on the order of other processors' side effects beyond what
///   registration order guarantees.
/// - Re-read source files from `projectDirectory` when the output directory
///   already contains the rendered representation – the `outputDirectory` is
///   the canonical input to phase 6.
/// - Skip files based on naming heuristics when a `ThemeConfig`-driven
///   decision would be more accurate.
public protocol OutputProcessor {
   /// Transforms the written output directory in place.
   ///
   /// Called once per build, after all renderers have written their files, in
   /// processor registration order. `projectDirectory` grants read access to
   /// source-side state (e.g. an image-variant cache); `themeConfig` is the
   /// loaded theme, or nil when no theme config could be loaded. A thrown
   /// error does NOT abort the build – the pipeline logs it as a warning and
   /// continues with the next processor, so the site still ships (without this
   /// processor's optimization).
   func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws
}
