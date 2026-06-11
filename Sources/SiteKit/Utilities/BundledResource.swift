import Foundation

/// Thrown when a resource SiteKit ships inside its module bundle cannot be loaded at build time.
///
/// A missing bundled resource means the produced site would be incomplete (e.g. pages reference
/// a fingerprinted script URL that no renderer emitted), so loaders fail loudly instead of
/// letting the build finish with exit 0.
public enum BundledResourceError: Error, Equatable, CustomStringConvertible {
   /// The named resource file is absent from `Bundle.module` or unreadable. Typical cause: an
   /// incomplete or clobbered `.build` directory, e.g. a cleanup that removed the resource
   /// bundle while a build was running.
   case missingResource(String)

   public var description: String {
      switch self {
      case .missingResource(let fileName):
         return """
         SiteKit's bundled resource '\(fileName)' is missing from the module bundle. The site \
         cannot be built completely without it. The .build directory is likely incomplete or \
         was modified while building – rebuild with `swift build` and retry.
         """
      }
   }
}

/// Loads text resources SiteKit ships in its module bundle (`Bundle.module`).
///
/// Central seam for every bundled-resource loader (DocC scripts, `docc.css`, `base.css`):
/// callers resolve the bundle URL themselves and pass it in, so tests can exercise the
/// missing-resource path without faking `Bundle.module`.
enum BundledResource {
   /// Returns the UTF-8 contents of `url`, throwing `BundledResourceError.missingResource`
   /// when `url` is nil or unreadable. `fileName` names the resource in the error message.
   static func loadText(named fileName: String, at url: URL?) throws -> String {
      guard
         let url,
         let text = try? String(contentsOf: url, encoding: .utf8)
      else {
         throw BundledResourceError.missingResource(fileName)
      }
      return text
   }
}
