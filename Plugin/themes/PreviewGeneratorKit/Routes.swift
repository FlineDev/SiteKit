import Foundation

/// One built route exposed to the preview grid. Adding a third route
/// (e.g. a tag-listing preview) is a single append to ``previewRoutes`` –
/// the inliner loop, the grid generator, and the per-variant tile
/// pairing all key off this list.
public struct PreviewRoute: Sendable, Equatable {
   /// Stable identifier used in filenames and error messages.
   public let id: String

   /// Human-readable label shown on the grid tile (e.g. "Home", "Article").
   public let label: String

   /// `_Site/`-relative path of the source HTML the driver inlines.
   public let sourcePath: String

   public init(id: String, label: String, sourcePath: String) {
      self.id = id
      self.label = label
      self.sourcePath = sourcePath
   }

   /// Computes the per-variant output filename. The Home route keeps the
   /// bare ``<variant>.html`` legacy name so review notes from earlier
   /// rounds still resolve; subsequent routes append a hyphenated suffix.
   public func outputFilename(for variant: PreviewVariant) -> String {
      if self.id == "home" {
         return "\(variant.id).html"
      }
      return "\(variant.id)-\(self.id).html"
   }
}

/// The canonical preview routes. Two routes (Home + Article) means each
/// of the nine variants produces two standalone HTMLs – 18 total
/// preview files.
public let previewRoutes: [PreviewRoute] = [
   PreviewRoute(
      id: "home",
      label: "Home",
      sourcePath: "index.html"
   ),
   PreviewRoute(
      id: "article",
      label: "Article",
      sourcePath: "blog/working-with-async-sequences-in-swift/index.html"
   ),
]
