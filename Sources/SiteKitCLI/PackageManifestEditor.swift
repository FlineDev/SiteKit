import Foundation

enum PackageManifestError: Error, CustomStringConvertible {
   case dependencyNotFound
   case dependencyNotVersionPinned

   var description: String {
      switch self {
      case .dependencyNotFound:
         return "No SiteKit dependency found in Package.swift. Run this in a SiteKit site directory."
      case .dependencyNotVersionPinned:
         return """
            The SiteKit dependency is not pinned to a released version (it uses a branch or local path). \
            'sitekit update' only bumps version-pinned dependencies – edit Package.swift manually.
            """
      }
   }
}

/// Pure-string detection and rewriting of the SiteKit dependency clause in a site's `Package.swift`.
///
/// `sitekit update` is deliberately limited (F03): it detects the version-pinned SiteKit
/// `.package(…SiteKit.git…, from: "x.y.z")` clause and bumps that one clause. `branch:` /
/// `revision:` / local `path:` forms are reported as not-version-pinned so the user edits them by
/// hand – no auto-migration.
///
/// Two correctness guards (M-015 R2): full-line `//` comments are masked out before matching, so a
/// commented-out hint line cannot shadow the live dependency or get rewritten in its place; and the
/// rewrite is scoped to the single matched version substring rather than a global replace, so a
/// second `.package(…)` clause elsewhere in the manifest is never touched.
enum PackageManifestEditor {
   /// Matches a version-pinned SiteKit `.package(…)` clause. Group 1 is everything up to and
   /// including the `from:` opening quote, group 2 the version, group 3 the closing quote.
   ///
   /// `[^)]*?` between `.package(` and the URL (and again before `from:`) tolerates the named form
   /// `.package(name: "SiteKit", url: …, from: …)` and multi-line declarations alike – `[^)]`
   /// spans newlines but stops at the clause's own closing paren.
   private static let versionPattern =
      #"(\.package\([^)]*?"[^"]*SiteKit\.git"[^)]*?from:\s*")([^"]*)(")"#

   /// Matches a SiteKit dependency declared by `branch:` / `revision:` / local `path:` instead of a
   /// released version – including the named (`name:`-first) form.
   private static let nonVersionPattern =
      #"\.package\([^)]*?(?:"[^"]*SiteKit\.git"[^)]*?(?:branch|revision):|path:\s*"[^"]*SiteKit[^"]*")"#

   /// The currently-pinned SiteKit version in `manifest`, or `nil` when no version-pinned,
   /// non-commented clause exists.
   static func currentVersion(in manifest: String) -> String? {
      Self.versionMatch(in: manifest)?.version
   }

   /// Returns `manifest` with the SiteKit dependency version bumped to `version`.
   ///
   /// Throws `dependencyNotVersionPinned` when the SiteKit clause uses `branch:` / `revision:` /
   /// `path:`, and `dependencyNotFound` when there is no SiteKit dependency at all. Only the single
   /// matched version substring is rewritten; the rest of the manifest is left byte-identical.
   static func bumped(_ manifest: String, to version: String) throws -> String {
      if let match = Self.versionMatch(in: manifest), let range = Range(match.versionRange, in: manifest) {
         var result = manifest
         result.replaceSubrange(range, with: version)
         return result
      }
      let masked = Self.maskingCommentLines(manifest)
      if masked.range(of: Self.nonVersionPattern, options: .regularExpression) != nil {
         throw PackageManifestError.dependencyNotVersionPinned
      }
      throw PackageManifestError.dependencyNotFound
   }

   /// The first version-pinned SiteKit clause: the `NSRange` of its version substring (valid in the
   /// original `manifest` – the mask preserves UTF-16 length) and that version's value.
   private static func versionMatch(in manifest: String) -> (versionRange: NSRange, version: String)? {
      let masked = Self.maskingCommentLines(manifest)
      guard let regex = try? NSRegularExpression(pattern: Self.versionPattern) else { return nil }
      let searchRange = NSRange(masked.startIndex..., in: masked)
      guard let match = regex.firstMatch(in: masked, range: searchRange) else { return nil }
      let versionNSRange = match.range(at: 2)
      guard let versionRange = Range(versionNSRange, in: manifest) else { return nil }
      return (versionNSRange, String(manifest[versionRange]))
   }

   /// Returns `manifest` with every full-line `//` comment blanked to spaces, preserving each
   /// line's UTF-16 length so `NSRange` offsets computed on the result stay valid in the original.
   private static func maskingCommentLines(_ manifest: String) -> String {
      manifest
         .split(separator: "\n", omittingEmptySubsequences: false)
         .map { line -> Substring in
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
               return Substring(String(repeating: " ", count: line.utf16.count))
            }
            return line
         }
         .joined(separator: "\n")
   }
}
