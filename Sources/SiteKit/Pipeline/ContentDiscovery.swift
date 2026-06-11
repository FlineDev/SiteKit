import Foundation

/// Discovers content source files in a directory – phase 1 of the pipeline.
///
/// Different sites organise content differently: flat directories, nested
/// per-locale folders, JSON manifests, even remote API sources. Conformers
/// own the "where does content live" decision and return `MarkdownSource`
/// values that the `Loader` phase parses into `PageModel`s. Splitting
/// discovery from loading is intentional – a custom layout swaps in a new
/// `ContentDiscovery` without touching the Markdown parser.
///
/// SiteKit ships `MarkdownContentDiscovery` (flat `*.md` walk) and
/// `LocalizedContentDiscovery` (`<lang>/<file>.md` for multilingual sites).
///
/// ## How to implement
///
/// ```swift
/// public struct NestedContentDiscovery: ContentDiscovery {
///    public init() {}
///    public func discover(in directory: URL) throws -> [MarkdownSource] {
///       // walk `directory`, return MarkdownSource per file
///       []
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.contentDiscovery(_:)`. See AGENTS.md §8 for a
/// worked example.
///
/// ## What this should NOT do
///
/// - Parse frontmatter or Markdown body – return raw content; the `Loader`
///   phase decodes it.
/// - Filter by `draft:` / `date:` semantics – that is the loader's job since
///   it knows the frontmatter shape.
/// - Mutate the source directory – discovery is read-only.
/// - Return a non-deterministic order – sort the result so downstream phases
///   produce stable output.
public protocol ContentDiscovery {
   /// Finds the content source files under `directory` and returns them as raw
   /// `MarkdownSource` values for the `Loader` phase.
   ///
   /// On single-language builds this is called once per declared content section
   /// (with that section's directory) and once for the static `Pages/` directory.
   /// Multilingual builds route through `LocalizedContentDiscovery` instead, so a
   /// custom conformer registered via `SiteBuilder.contentDiscovery(_:)` only
   /// affects single-language sites. Return the sources in a deterministic order
   /// (sort by path) so downstream phases produce stable output across builds.
   func discover(in directory: URL) throws -> [MarkdownSource]
}
