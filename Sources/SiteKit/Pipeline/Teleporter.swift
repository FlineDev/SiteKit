import Foundation

/// Copies or transforms asset files from a source directory to an output
/// directory – phase 0 of the pipeline.
///
/// Teleporter runs in parallel with the content phases (1-6) because assets
/// (images, fonts, vendor JS/CSS, downloadable files) do not depend on the
/// content graph. SiteKit ships `AssetCopier` as the default conformer;
/// replace it when assets need transformation on the way out (e.g. image
/// format conversion at copy time).
///
/// Two methods exist so callers can distinguish "copy into the site's default
/// asset layout" (`copy(from:to:)` – the teleporter derives the layout under the
/// output root) from "copy directly into a specific destination directory"
/// (`copy(from:into:)`); blueprint factory methods choose the right one based on
/// whether they need locale-aware fan-out.
///
/// ## How to implement
///
/// ```swift
/// public struct StripExifTeleporter: Teleporter {
///    public init() {}
///    public func copy(from sourceDirectory: URL, to outputDirectory: URL) throws {
///       // walk sourceDirectory, strip EXIF, write to outputDirectory
///    }
///    public func copy(from sourceDirectory: URL, into destinationDirectory: URL) throws {
///       // same logic, explicit destination
///    }
/// }
/// ```
///
/// Register with `SiteBuilder.teleporter(_:)`.
///
/// ## What this should NOT do
///
/// - Read or modify the content graph – teleporter runs in parallel with
///   content phases and has no `BuildContext` access.
/// - Generate responsive image variants – that is `ImageResizer`
///   (`OutputProcessor`, phase 6) so the variant set can be chosen from the
///   actual rendered HTML.
/// - Mutate the source directory – copy or transform on the way out.
public protocol Teleporter {
   /// Copies assets from `sourceDirectory` into the site's default asset layout
   /// under `outputDirectory` (e.g. `Content/Assets/` → `<output>/assets/`).
   func copy(from sourceDirectory: URL, to outputDirectory: URL) throws

   /// Copies assets from `sourceDirectory` directly into `destinationDirectory`,
   /// without applying the default asset layout – for callers that control the
   /// exact destination (theme folders, per-locale fan-out).
   func copy(from sourceDirectory: URL, into destinationDirectory: URL) throws
}
