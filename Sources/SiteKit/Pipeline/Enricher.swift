import Foundation

/// Adds or refines fields on a `PageModel` – phase 3 of the pipeline.
///
/// Enrichers transform `PageModel → PageModel` without changing the type and
/// chain in registration order. Use them for derived fields that need the
/// loaded model (or sometimes the full content graph) but that should not
/// live in the loader: hreflang tables on multilingual sites
/// (`HreflangEnricher`), promotion-slot selection (`PromotionEnricher`),
/// reading-time estimates, computed summaries, taxonomy normalisation.
///
/// Splitting "what the source file says" (`Loader`) from "what the rendered
/// model needs" (`Enricher`) keeps loaders single-format and trivially
/// testable, and lets enrichers compose freely without touching the parser.
///
/// ## How to implement
///
/// ```swift
/// public struct ReadingTimeEnricher: Enricher {
///    public init() {}
///    public func enrich(_ page: PageModel) throws -> PageModel {
///       var extensions = page.extensions
///       extensions["readingTime"] = page.readTimeMinutes
///       return PageModel(/* ...all fields..., */ extensions: extensions)
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.enricher(_:)`. Built-in enrichers
/// (`HreflangEnricher`, `PromotionEnricher`) are appended last by the
/// blueprint factory methods. See AGENTS.md §8 for the full extension recipe.
///
/// ## What this should NOT do
///
/// - Render HTML or write output files – that is the `Renderer` / `Page`
///   phase.
/// - Read additional source files from disk – discovery and loading already
///   happened. Enrichers should be deterministic given their input.
/// - Mutate the input `PageModel` instance – return a new value (the type is
///   already designed for this).
/// - Depend on other enrichers' side effects implicitly – express ordering by
///   registration order, not by mutual knowledge.
public protocol Enricher {
   /// Returns a copy of `page` with derived fields added or refined.
   ///
   /// Called once per loaded page, in enricher registration order – later
   /// enrichers see earlier enrichers' output. Store computed values in
   /// `PageModel.extensions` (or replace typed fields) and return the new
   /// value; the input instance must stay untouched.
   func enrich(_ page: PageModel) throws -> PageModel
}
