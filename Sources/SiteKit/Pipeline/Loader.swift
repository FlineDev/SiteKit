import Foundation

/// Parses one source artefact into a typed model – phase 2 of the pipeline.
///
/// `Loader` is generic over the input format (`Source`) and the produced
/// output (`Output`) so the same protocol covers Markdown→`PageModel`,
/// YAML→any `Decodable`, or any other input/output pairing without special
/// casing. SiteKit ships `MarkdownLoader` (Markdown → `PageModel` with
/// `requiredFields` validation) and `YAMLLoader<Output>` (YAML → any
/// `Decodable` type).
///
/// The loader phase is purely format-translation – discovery (which files to
/// load) happens in `ContentDiscovery` (phase 1) and any post-load enrichment
/// happens in `Enricher` (phase 3). Keeping these three responsibilities
/// separate keeps loaders single-format and trivially testable.
///
/// ## How to implement
///
/// ```swift
/// public struct JSONFeedLoader: Loader {
///    public typealias Source = URL
///    public typealias Output = [PageModel]
///    public init() {}
///    public func load(source: URL) throws -> [PageModel] {
///       let data = try Data(contentsOf: source)
///       // decode + map to PageModel
///       return []
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.articleLoader(_:)` for the article-section
/// loader, or `SiteBuilder.staticPageLoader(_:)` for static pages. See AGENTS.md
/// §8 for a worked example.
///
/// ## What this should NOT do
///
/// - Discover files on disk – that is `ContentDiscovery` (phase 1). A `Loader`
///   receives one source at a time.
/// - Add computed or cross-page fields (reading time, hreflang, promotions) –
///   that is `Enricher` (phase 3).
/// - Render HTML or write output files – those are phases 4 and 5.
/// - Throw on missing optional fields – validate only the documented
///   `requiredFields` set; everything else is downstream concern.
public protocol Loader<Source, Output> {
   /// The input artefact this loader understands – e.g. `MarkdownSource` for
   /// the shipped Markdown path, or a file `URL` for custom formats.
   associatedtype Source

   /// The typed model this loader produces – `PageModel` for page content, or
   /// any `Decodable` for data files (see `YAMLLoader`).
   associatedtype Output

   /// Parses one source artefact into the typed output model.
   ///
   /// Called once per discovered source. Throw when the source is malformed or
   /// misses a required field – the error aborts the build with the file named,
   /// which beats silently shipping a half-parsed page.
   func load(source: Source) throws -> Output
}
