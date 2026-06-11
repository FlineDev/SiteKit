import Crypto
import Foundation
import Logging

/// Post-processor that renames referenced theme CSS/JS assets to content-hashed
/// filenames (`theme.css` → `theme.<hash>.css`) and rewrites every reference to
/// match – the single source of truth for cache-busting SiteKit's `immutable`-cached
/// assets.
///
/// ### Why a hashed FILENAME instead of a `?v=` query
///
/// The `_headers` rules for `/assets/*.css` and `/assets/*.js` ship
/// `Cache-Control: public, max-age=31536000, immutable`. A query string does NOT
/// reliably bust an `immutable` response: browsers told `immutable` skip
/// revalidation for the whole URL regardless of its query, and CDNs may normalize
/// or ignore the query when keying their cache. So a returning visitor keeps the
/// STALE theme CSS after a redeploy until the year-long TTL expires.
///
/// A content-hashed *filename* sidesteps this entirely: when the bytes change, the
/// filename changes, so the URL is genuinely new and every cache fetches it from
/// origin. When the bytes do NOT change, the filename is identical across deploys,
/// so unchanged assets stay cached (the win the `?v=<random-per-build>` token threw
/// away – it busted every asset on every deploy whether or not it changed).
///
/// ### Single source of truth (no 404s)
///
/// One component computes the hash, renames the file, and rewrites the references.
/// The emitted filename and every link to it are derived from the *same* computed
/// name in the *same* code path, so the two can never diverge – the failure mode of
/// computing the name independently in an emitter and a referencer (yielding a
/// dangling reference) is structurally impossible here.
///
/// ### Why a post-processor (hash reflects what actually ships)
///
/// This runs LAST in the processor chain – after `AssetMinifier` – so the hash is
/// taken over each asset's FINAL on-disk bytes (post-minification). The hash
/// therefore changes if and only if the bytes a visitor actually downloads change.
///
/// ### Scope
///
/// - Only local references (`/assets/…`) ending in `.css` or `.js` that appear in a
///   rendered `.html` or `.css` file are considered. External CDN URLs, images,
///   fonts, JSON indexes, and favicons keep their stable paths (images already get
///   responsive variants; favicons live at fixed root paths).
/// - An asset is hashed only when it is actually referenced AND its file exists on
///   disk. Emitted-but-unreferenced files (e.g. `tokens.css` / `base.css`, which
///   `PageShell` inlines rather than links) are left untouched – there is nothing to
///   bust if nothing fetches them.
/// - References to an asset that does not exist on disk are left verbatim (no 404 is
///   introduced where there was a valid file; a pre-existing dangling reference stays
///   exactly as it was).
public struct AssetFingerprinter: OutputProcessor {
   public init() {}

   public func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws {
      let logger = Logger(label: "SiteKit.AssetFingerprinter")
      let fileManager = FileManager.default

      // Collect every reference-bearing file once (HTML carries the `<link>`/`<script>`
      // references; CSS is included so a theme that `@import`s/`url()`s a hashed asset
      // stays consistent – production themes don't, so in practice only HTML is rewritten).
      var referenceBearingURLs: [URL] = []
      if let enumerator = fileManager.enumerator(at: outputDirectory, includingPropertiesForKeys: [.isRegularFileKey]) {
         for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "html" || ext == "css" {
               referenceBearingURLs.append(fileURL)
            }
         }
      }

      // Pass 1 – discover which local CSS/JS assets are actually referenced.
      var referencedPaths = Set<String>()
      for fileURL in referenceBearingURLs {
         guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
         for path in Self.referencedAssetPaths(in: content) {
            referencedPaths.insert(path)
         }
      }

      // Build the rename map: referenced + existing + not-already-fingerprinted →
      // content-hashed filename. Sorted for deterministic processing/logging.
      var renameMap: [String: String] = [:]   // "/assets/…/theme.css" → "/assets/…/theme.<hash>.css"
      var fileRenames: [(from: URL, to: URL)] = []
      for path in referencedPaths.sorted() {
         guard !Self.isAlreadyFingerprinted(path) else { continue }
         let fileURL = Self.fileURL(forSitePath: path, in: outputDirectory)
         guard fileManager.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL)
         else {
            // Referenced but not on disk – leave the reference verbatim, don't invent a 404.
            continue
         }
         let hashedPath = Self.fingerprintedPath(for: path, hash: Self.shortHash(of: data))
         renameMap[path] = hashedPath
         fileRenames.append((from: fileURL, to: Self.fileURL(forSitePath: hashedPath, in: outputDirectory)))
      }

      guard !renameMap.isEmpty else { return }

      // Pass 2 – rewrite references in place. A CSS file that is itself a rename
      // target is written at its OLD path here; pass 3 moves it (carrying the
      // rewritten content) to the hashed path.
      var filesRewritten = 0
      for fileURL in referenceBearingURLs {
         guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
         let rewritten = Self.rewriteReferences(in: content, using: renameMap)
         if rewritten != content {
            try? rewritten.write(to: fileURL, atomically: true, encoding: .utf8)
            filesRewritten += 1
         }
      }

      // Pass 3 – move each target asset to its hashed filename.
      for (from, to) in fileRenames {
         if fileManager.fileExists(atPath: to.path) {
            try? fileManager.removeItem(at: to)
         }
         try? fileManager.moveItem(at: from, to: to)
      }

      logger.info("Fingerprinted \(renameMap.count) asset(s), rewrote references in \(filesRewritten) file(s).")
   }

   // MARK: - Reference scanning & rewriting

   /// Matches a site-absolute reference to a local `.css`/`.js` asset, with an
   /// optional `?query`. The negative lookahead after the extension keeps `theme.css`
   /// from matching as a prefix of a longer name (e.g. `theme.css.map`). Computed (not
   /// stored) so the `Regex` value is not a non-Sendable global.
   static var assetReferencePattern: Regex<Substring> {
      #/\/assets\/[A-Za-z0-9._\/\-]*\.(?:css|js)(?![A-Za-z0-9._\/\-])(?:\?[^"'\s)>]*)?/#
   }

   /// Returns the distinct asset paths (query stripped) referenced in `content`.
   static func referencedAssetPaths(in content: String) -> Set<String> {
      var paths = Set<String>()
      for match in content.matches(of: Self.assetReferencePattern) {
         paths.insert(Self.stripQuery(String(match.output)))
      }
      return paths
   }

   /// Replaces every reference whose (query-stripped) path is in `renameMap` with its
   /// hashed path, dropping any `?query`. References not in the map are left verbatim.
   static func rewriteReferences(in content: String, using renameMap: [String: String]) -> String {
      content.replacing(Self.assetReferencePattern) { match in
         let token = String(match.output)
         let path = Self.stripQuery(token)
         return renameMap[path] ?? token
      }
   }

   private static func stripQuery(_ token: String) -> String {
      if let queryIndex = token.firstIndex(of: "?") {
         return String(token[..<queryIndex])
      }
      return token
   }

   // MARK: - Path & hash helpers

   /// Inserts the hash before the file extension: `/a/theme.css` + `1a2b3c4d`
   /// → `/a/theme.1a2b3c4d.css`.
   static func fingerprintedPath(for sitePath: String, hash: String) -> String {
      let ext = (sitePath as NSString).pathExtension
      let base = (sitePath as NSString).deletingPathExtension
      return "\(base).\(hash).\(ext)"
   }

   /// True when the filename already carries a `.<8 hex>` fingerprint segment before
   /// its extension – guards against double-fingerprinting on `--no-clean` rebuilds.
   static func isAlreadyFingerprinted(_ sitePath: String) -> Bool {
      let base = (sitePath as NSString).deletingPathExtension
      return base.contains(#/\.[0-9a-f]{8}$/#)
   }

   /// Resolves a site-absolute asset path (`/assets/…`) to its file URL in the output dir.
   static func fileURL(forSitePath sitePath: String, in outputDirectory: URL) -> URL {
      outputDirectory.appendingPathComponent(String(sitePath.drop(while: { $0 == "/" })))
   }

   /// First 8 hex characters of the SHA-256 digest of `data`. 32 bits of entropy is
   /// ample for the handful of theme assets a site ships; collisions are effectively
   /// impossible and would, at worst, share a (still content-correct) cache key.
   static func shortHash(of data: Data) -> String {
      SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
   }
}
