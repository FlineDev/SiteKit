import Foundation
import Logging

/// Post-processor that generates responsive `srcset` / `sizes` variants for every
/// `<img>` tag in rendered HTML, driven by `Content/ImageManifest.yaml`.
///
/// ### The problem this solves
///
/// SiteKit renderers can't know what CSS display width an image will render at – that
/// depends on theme CSS. A hero image committed at 2000×1125 might be displayed at
/// 720 CSS px on desktop and 390 CSS px on mobile. Serving one large file to both
/// wastes mobile bandwidth; generating density variants (1x/2x/3x) from a naive
/// fallback width over-serves on most screens.
///
/// ### The solution
///
/// `ImageManifest.yaml` declares each image *role* (article-hero, article-card-thumb,
/// app-icon, logo, …) with `desktopWidth` and `mobileWidth` values the agent reads
/// from theme CSS. For each `<img>` the pipeline:
///
/// 1. Resolves a role by matching selectors (first-wins).
/// 2. Computes the retina-target widths: `desktopWidth × 2` for desktop, `mobileWidth × 3`
///    for mobile. Phones dominate 3× DPR, laptops mostly 2× DPR.
/// 3. Decides srcset shape:
///    - If mobile ≥ desktop / 2 (mobile layout is not significantly narrower): emit a
///      simple density srcset – `src` at 1×, `srcset="… 2x"` at desktop retina.
///    - If mobile < desktop / 2 (mobile is meaningfully narrower, e.g. full-bleed hero):
///      emit a `sizes`+`srcset` responsive combo. Browser picks the smallest variant
///      whose width ≥ `viewport_px × devicePixelRatio`.
/// 4. Always emits `width` / `height` to fix Cumulative Layout Shift.
/// 5. Generates variants via ImageMagick (`magick` v7 or `convert` v6). Never upscales.
///    Caches at `.sitekit-cache/images/<sha8>-<w>w.<ext>` keyed on src path + target
///    width – subsequent builds are fully offline.
///
/// If no manifest exists, logs a warning and falls back to the legacy heuristic
/// (explicit width attribute, else `min(source, 900)`) – the build still succeeds.
///
/// ### Opt-out
///
/// Set `resizeImages: false` in `theme.yaml`.
///
/// ### Tooling
///
/// Requires ImageMagick on PATH (`brew install imagemagick` / `apt-get install imagemagick`).
/// If missing, the processor is a no-op and logs a warning.
public struct ImageResizer: OutputProcessor {
   public init() {}

   public func process(outputDirectory: URL, projectDirectory: URL, themeConfig: ThemeConfig?) throws {
      guard themeConfig?.resizeImages != false else { return }

      let logger = Logger(label: "SiteKit.ImageResizer")

      guard let tool = ImageToolResolver.find() else {
         logger.warning("No image resize tool found on PATH (tried `magick`, `convert`). Install imagemagick to enable responsive image generation. Skipping.")
         return
      }

      let manifest: ImageManifest?
      do {
         manifest = try ImageManifest.load(fromProjectDirectory: projectDirectory)
         if manifest == nil {
            logger.warning("No Content/ImageManifest.yaml found – falling back to heuristic image sizing. Create a manifest for per-role optimal widths.")
         }
      } catch {
         logger.warning("Failed to load ImageManifest.yaml: \(error). Falling back to heuristic.")
         manifest = nil
      }

      let cacheDir = projectDirectory.appendingPathComponent(".sitekit-cache/images")
      try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

      var variantsGenerated = 0
      var cacheHits = 0
      var filesModified = 0
      var imagesRewritten = 0
      var totalBytesSaved: Int64 = 0
      var skipped = 0
      var roleMatchCounts: [String: Int] = [:]
      var uncovered = 0

      // Dedupe `magick identify` calls across the whole build. Each probe spawns
      // a subprocess (~100-200 ms); the same `src` path typically appears on
      // dozens of pages (a logo appears on every page, hero images appear on the
      // article page + listing + home). Caching cuts probe time from O(pages × imgs)
      // to O(unique sources).
      var dimensionsCache: [String: (Int, Int)] = [:]

      guard let enumerator = FileManager.default.enumerator(
         at: outputDirectory,
         includingPropertiesForKeys: [.isRegularFileKey]
      ) else { return }

      for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "html" {
         var html = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
         guard html.contains("<img") else { continue }

         let result = Self.processFile(
            html: html,
            outputDirectory: outputDirectory,
            cacheDir: cacheDir,
            tool: tool,
            manifest: manifest,
            dimensionsCache: &dimensionsCache,
            logger: logger
         )
         if result.html != html {
            html = result.html
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            filesModified += 1
         }
         variantsGenerated += result.variantsGenerated
         cacheHits += result.cacheHits
         totalBytesSaved += result.bytesSaved
         skipped += result.skipped
         imagesRewritten += result.imagesRewritten
         uncovered += result.uncovered
         for (role, count) in result.roleMatchCounts {
            roleMatchCounts[role, default: 0] += count
         }
      }

      if variantsGenerated > 0 || cacheHits > 0 || imagesRewritten > 0 {
         let savedKB = Int(totalBytesSaved / 1024)
         let rolesSummary = roleMatchCounts.isEmpty
            ? ""
            : " [\(roleMatchCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ", "))]"
         logger.info(
            "Image resize: \(imagesRewritten) <img> rewritten across \(filesModified) page(s), \(variantsGenerated) variant(s) generated, \(cacheHits) cache hit(s). ~\(savedKB) KB saved per first visit.\(rolesSummary)"
         )
      }
      if skipped > 0 {
         logger.info("Image resize: \(skipped) <img> skipped (external src, missing file, unsupported format, or already resized).")
      }
      if uncovered > 0 {
         logger.warning("\(uncovered) <img> fell through to the default role. Consider adding a specific role to Content/ImageManifest.yaml.")
      }
   }

   // MARK: - Tool discovery
   //
   // Delegates to `ImageToolResolver` so the CSS-background processor and the
   // `<img>` resizer share one code path, one cache directory, and one set of
   // ImageMagick invocations. Keep them in sync – changes here belong in the
   // resolver.
   typealias ImageTool = ImageToolResolver.Tool

   // MARK: - Per-file processing

   struct FileResult {
      var html: String
      var variantsGenerated: Int
      var cacheHits: Int
      var bytesSaved: Int64
      var skipped: Int
      var imagesRewritten: Int
      var uncovered: Int
      var roleMatchCounts: [String: Int]
   }

   /// Walks the HTML of a single file, tracking open ancestor tags, and rewrites each
   /// `<img>` in place. Uses a stack-based tag scanner (not a DOM parser) – enough
   /// for typical renderer output, and much faster than pulling in an HTML parser.
   static func processFile(
      html: String,
      outputDirectory: URL,
      cacheDir: URL,
      tool: ImageTool,
      manifest: ImageManifest?,
      dimensionsCache: inout [String: (Int, Int)],
      logger: Logger
   ) -> FileResult {
      let alreadyResizedRegex = #/-\d+w\./#

      var variantsGenerated = 0
      var cacheHits = 0
      var bytesSaved: Int64 = 0
      var skipped = 0
      var imagesRewritten = 0
      var uncovered = 0
      var roleMatchCounts: [String: Int] = [:]
      // Tracks the rewrite per `<img>` so a second pass can update matching
      // `<link rel="preload" as="image">` entries. Without this, the browser
      // preloads the original source while the body references a resized variant,
      // causing a wasted double-download that Lighthouse flags as an unused preload.
      // We also carry `srcset` / `sizes` so the preload can use `imagesrcset` /
      // `imagesizes` and let the browser preload the BEST variant for the viewport.
      var srcRewrites: [String: PreloadRewrite] = [:]

      // Walk tags left-to-right. Maintain a stack of (tagName, classes) for open
      // ancestors. Void/self-closing tags don't push. Closing tags pop. When we
      // hit an <img>, the current stack is the ancestor chain (top = immediate parent).
      let scanner = HTMLTagScanner(source: html)
      var ancestorStack: [SelectorMatcher.Candidate.Ancestor] = []
      var rebuilt = ""
      rebuilt.reserveCapacity(html.count)
      var cursor = html.startIndex

      while let event = scanner.next() {
         switch event.kind {
         case .open(let tagName, let classes) where tagName.lowercased() == "img":
            // Flush content before this <img>.
            rebuilt.append(contentsOf: html[cursor..<event.range.lowerBound])
            cursor = event.range.upperBound

            let originalMatch = String(html[event.range])
            let ancestors = Array(ancestorStack.reversed()) // top of stack = immediate parent
            let candidate = SelectorMatcher.Candidate(
               tagName: "img",
               classes: classes,
               ancestors: ancestors
            )

            let (replacement, effect) = Self.rewriteImgTag(
               originalMatch: originalMatch,
               candidate: candidate,
               alreadyResizedRegex: alreadyResizedRegex,
               outputDirectory: outputDirectory,
               cacheDir: cacheDir,
               tool: tool,
               manifest: manifest,
               dimensionsCache: &dimensionsCache,
               logger: logger
            )
            switch effect {
            case .rewritten(let roleName, let newVariants, let cacheHitsCount, let bytesSavedCount, let wasUncovered, let originalSrc, let rewrite):
               imagesRewritten += 1
               variantsGenerated += newVariants
               cacheHits += cacheHitsCount
               bytesSaved += bytesSavedCount
               roleMatchCounts[roleName, default: 0] += 1
               if wasUncovered { uncovered += 1 }
               if originalSrc != rewrite.newSrc || rewrite.srcset != nil {
                  srcRewrites[originalSrc] = rewrite
               }
               rebuilt.append(replacement)
            case .skipped:
               skipped += 1
               rebuilt.append(originalMatch)
            }
            // <img> is void – do NOT push on stack.
         case .open(let tagName, let classes):
            if !Self.isVoidElement(tagName) {
               ancestorStack.append(SelectorMatcher.Candidate.Ancestor(tagName: tagName, classes: classes))
            }
         case .close(let tagName):
            // Pop to the matching open tag. Tolerates minor imbalance from mal-written
            // HTML; the tracker is best-effort and drifts back into sync at each new
            // element. We don't want one stray `</foo>` to derail all subsequent images.
            if let index = ancestorStack.lastIndex(where: { $0.tagName == tagName.lowercased() }) {
               ancestorStack.removeSubrange(index..<ancestorStack.count)
            }
         }
      }
      rebuilt.append(contentsOf: html[cursor..<html.endIndex])

      // Second pass: rewrite `<link rel="preload" as="image" href="X">` URLs so
      // they point at the resized variant the body will actually reference.
      // Otherwise the browser downloads X once (preload) AND the variant (img render)
      // – Lighthouse flags this as an unused preload.
      if !srcRewrites.isEmpty {
         rebuilt = Self.rewritePreloadHrefs(in: rebuilt, srcRewrites: srcRewrites)
      }

      return FileResult(
         html: rebuilt,
         variantsGenerated: variantsGenerated,
         cacheHits: cacheHits,
         bytesSaved: bytesSaved,
         skipped: skipped,
         imagesRewritten: imagesRewritten,
         uncovered: uncovered,
         roleMatchCounts: roleMatchCounts
      )
   }

   /// Updates `<link rel="preload" as="image" href="X">` entries so `X` tracks the
   /// rewritten `<img>` src the body ends up using. Also injects `imagesrcset` +
   /// `imagesizes` so the browser can preload the BEST variant per viewport –
   /// otherwise a mobile visitor preloads the desktop 1× and loads the mobile
   /// retina separately, wasting the preload.
   private static func rewritePreloadHrefs(in html: String, srcRewrites: [String: PreloadRewrite]) -> String {
      let preloadPattern = #/<link\b[^>]*\brel="preload"[^>]*\bas="image"[^>]*\bhref="([^"]+)"[^>]*>/#
      var result = ""
      result.reserveCapacity(html.count)
      var cursor = html.startIndex
      for match in html.matches(of: preloadPattern) {
         result.append(contentsOf: html[cursor..<match.range.lowerBound])
         cursor = match.range.upperBound
         let fullTag = String(match.output.0)
         let originalHref = String(match.output.1)
         guard let rewrite = srcRewrites[originalHref] else {
            result.append(fullTag)
            continue
         }
         // Swap the href, then append imagesrcset/imagesizes before the closing `>`.
         // Strip any trailing `/>` or `>` so we can inject attributes cleanly.
         var rebuilt = fullTag.replacing("href=\"\(originalHref)\"", with: "href=\"\(rewrite.newSrc)\"")
         let endsSelfClosing = rebuilt.hasSuffix("/>")
         rebuilt.removeLast(endsSelfClosing ? 2 : 1)
         if let srcset = rewrite.srcset, !srcset.isEmpty {
            rebuilt += " imagesrcset=\"\(srcset)\""
         }
         if let sizes = rewrite.sizes, !sizes.isEmpty {
            rebuilt += " imagesizes=\"\(sizes)\""
         }
         rebuilt += endsSelfClosing ? "/>" : ">"
         result.append(rebuilt)
      }
      result.append(contentsOf: html[cursor..<html.endIndex])
      return result
   }

   private static func isVoidElement(_ tagName: String) -> Bool {
      let void: Set<String> = [
         "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
         "meta", "param", "source", "track", "wbr",
      ]
      return void.contains(tagName.lowercased())
   }

   // MARK: - Per-<img> rewrite

   private enum RewriteEffect {
      case rewritten(role: String, variantsGenerated: Int, cacheHits: Int, bytesSaved: Int64, uncovered: Bool, originalSrc: String, rewrite: PreloadRewrite)
      case skipped
   }

   /// Data the preload pass needs to rebuild a `<link rel="preload" as="image">`
   /// tag so it matches the `<img>`: the new `src`, plus the `srcset` / `sizes`
   /// attributes (if any) so the browser can pick the best variant per viewport.
   struct PreloadRewrite {
      let newSrc: String
      let srcset: String?
      let sizes: String?
   }

   /// Given a raw `<img …>` tag (match on `originalMatch`) and its structural
   /// context, returns either a rewritten tag string or a skip marker.
   ///
   /// Skip reasons: non-local src, already-resized src, no matching file on disk,
   /// unsupported image format, or `identify` failing on the source. The caller
   /// preserves the original tag text when skipping.
   private static func rewriteImgTag(
      originalMatch: String,
      candidate: SelectorMatcher.Candidate,
      alreadyResizedRegex: Regex<Substring>,
      outputDirectory: URL,
      cacheDir: URL,
      tool: ImageTool,
      manifest: ImageManifest?,
      dimensionsCache: inout [String: (Int, Int)],
      logger: Logger
   ) -> (String, RewriteEffect) {
      // Extract attributes from the tag body. Reuse the existing attribute parser –
      // it tolerates single/double/bare/valueless forms.
      let innerRange = Self.attributesRange(in: originalMatch)
      let attributesString = String(originalMatch[innerRange])
      guard let parsed = Self.parseImgAttributes(in: attributesString) else {
         return (originalMatch, .skipped)
      }

      // Local images only – external URLs (https://…) are outside our control.
      guard let src = parsed["src"], src.hasPrefix("/") else {
         return (originalMatch, .skipped)
      }
      // Already processed: has srcset, or the src already names a resized variant.
      if parsed["srcset"] != nil || src.contains(alreadyResizedRegex) {
         return (originalMatch, .skipped)
      }

      let srcPath = outputDirectory.appendingPathComponent(String(src.dropFirst()))
      guard FileManager.default.fileExists(atPath: srcPath.path) else {
         return (originalMatch, .skipped)
      }

      let fileExtension = srcPath.pathExtension.lowercased()
      guard Self.isResizable(fileExtension: fileExtension) else {
         return (originalMatch, .skipped)
      }

      // Cache identify calls by src path – the same image file is often referenced
      // from many pages (logo on every page, hero on article + listing + home).
      let sourceWidth: Int
      let sourceHeight: Int
      if let cached = dimensionsCache[src] {
         (sourceWidth, sourceHeight) = cached
      } else if let probed = ImageToolResolver.identifyDimensions(of: srcPath, tool: tool) {
         dimensionsCache[src] = probed
         (sourceWidth, sourceHeight) = probed
      } else {
         return (originalMatch, .skipped)
      }

      // Resolve role from manifest (or built-in fallback).
      let (role, wasUncovered) = Self.resolveRole(for: candidate, manifest: manifest, parsed: parsed, sourceWidth: sourceWidth)
      let mobileBreakpoint = manifest?.effectiveMobileBreakpoint ?? 768

      // Plan variants + srcset/sizes shape.
      let plan = ImageVariantPlanner.plan(
         role: role,
         sourceWidth: sourceWidth,
         sourceHeight: sourceHeight,
         mobileBreakpoint: mobileBreakpoint
      )

      // Generate each planned variant.
      var variantsCount = 0
      var cacheHitsCount = 0
      var bytesSavedCount: Int64 = 0
      let originalSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: srcPath.path))
         .flatMap { $0[.size] as? Int64 } ?? 0

      // Variant paths keyed by their planned target width.
      var pathByWidth: [Int: String] = [:]
      for target in plan.uniqueTargetWidths {
         let effectivePath: String
         if target >= sourceWidth {
            // Can't exceed source – reuse original.
            effectivePath = src
         } else {
            let outcome = ImageToolResolver.ensureVariant(
               originalSrc: src,
               outputDirectory: outputDirectory,
               cacheDir: cacheDir,
               targetWidth: target,
               fileExtension: fileExtension,
               tool: tool,
               logger: logger
            )
            switch outcome {
            case .generated(let url):
               variantsCount += 1
               effectivePath = url
            case .cacheHit(let url):
               cacheHitsCount += 1
               effectivePath = url
            case .failed:
               continue
            }

            // Bytes saved: credit at the smallest variant (= what a mobile visitor loads).
            if target == plan.smallestTargetWidth,
               let variantSize = (try? FileManager.default.attributesOfItem(
                  atPath: outputDirectory.appendingPathComponent(String(effectivePath.dropFirst())).path
               )).flatMap({ $0[.size] as? Int64 })
            {
               bytesSavedCount += max(0, originalSize - variantSize)
            }
         }
         pathByWidth[target] = effectivePath
      }

      // If we couldn't produce even a fallback path, skip.
      guard pathByWidth[plan.fallbackWidth] != nil else {
         return (originalMatch, .skipped)
      }

      // Build new attributes.
      let newAttrs = ImageMarkupRewriter.apply(plan: plan, parsed: parsed, pathByWidth: pathByWidth)
      let newAttrsString = Self.reserializeAttributes(newAttrs, preservingOrderFrom: attributesString)
      let rebuilt = "<img \(newAttrsString)>"

      return (rebuilt, .rewritten(
         role: role.name,
         variantsGenerated: variantsCount,
         cacheHits: cacheHitsCount,
         bytesSaved: bytesSavedCount,
         uncovered: wasUncovered,
         originalSrc: src,
         rewrite: PreloadRewrite(
            newSrc: newAttrs["src"] ?? src,
            srcset: newAttrs["srcset"],
            sizes: newAttrs["sizes"]
         )
      ))
   }

   /// Resolves the role for a given `<img>`. Walks the manifest's roles in order;
   /// falls back to a built-in default if no manifest is present or nothing matches.
   private static func resolveRole(
      for candidate: SelectorMatcher.Candidate,
      manifest: ImageManifest?,
      parsed: [String: String],
      sourceWidth: Int
   ) -> (role: ImageRole, uncovered: Bool) {
      if let manifest {
         for role in manifest.roles where SelectorMatcher.matches(selector: role.selector, candidate: candidate) {
            // A role named "default" is considered a catch-all for uncovered-warning purposes.
            let isCatchAll = role.name.lowercased() == "default"
            return (role, isCatchAll)
         }
      }

      // Heuristic fallback: honor explicit `width` attribute if present, else bound
      // the display width to 900 (matches the prior `wideContentWidth` default).
      let heuristicDesktop: Int
      if let widthString = parsed["width"], let explicit = Int(widthString), explicit > 0 {
         heuristicDesktop = explicit
      } else {
         heuristicDesktop = min(sourceWidth, 900)
      }
      let role = ImageRole(
         name: manifest == nil ? "heuristic" : "default",
         selector: "img",
         desktopWidth: heuristicDesktop,
         mobileWidth: heuristicDesktop
      )
      return (role, manifest != nil)
   }

   // MARK: - Attribute parsing helpers

   private static func attributesRange(in imgTag: String) -> Range<String.Index> {
      // Strip leading "<img" and trailing ">"/"/>". Callers pass the exact match.
      var start = imgTag.startIndex
      var end = imgTag.endIndex
      if imgTag.hasPrefix("<img") {
         start = imgTag.index(start, offsetBy: 4)
      }
      if imgTag.hasSuffix("/>") {
         end = imgTag.index(end, offsetBy: -2)
      } else if imgTag.hasSuffix(">") {
         end = imgTag.index(end, offsetBy: -1)
      }
      return start..<end
   }

   private static func isResizable(fileExtension: String) -> Bool {
      ["webp", "jpg", "jpeg", "png"].contains(fileExtension)
   }

   // MARK: - Attribute lenient parser / serializer

   static func parseImgAttributes(in attributesString: String) -> [String: String]? {
      let regex = #/([a-zA-Z_][a-zA-Z0-9_:-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/#
      var result: [String: String] = [:]
      for match in attributesString.matches(of: regex) {
         let (_, name, doubleQuoted, singleQuoted, bare) = match.output
         let value: String
         if let doubleQuoted {
            value = String(doubleQuoted)
         } else if let singleQuoted {
            value = String(singleQuoted)
         } else if let bare {
            value = String(bare)
         } else {
            value = ""
         }
         result[String(name).lowercased()] = value
      }
      return result.isEmpty ? nil : result
   }

   private static func orderedAttributeNames(in attributesString: String) -> [String] {
      let regex = #/([a-zA-Z_][a-zA-Z0-9_:-]*)\s*=/#
      return attributesString.matches(of: regex).map { String($0.output.1).lowercased() }
   }

   static func reserializeAttributes(_ attributes: [String: String], preservingOrderFrom attributesString: String) -> String {
      let originalOrder = Self.orderedAttributeNames(in: attributesString)
      var parts: [String] = []
      var seen: Set<String> = []
      for name in originalOrder where attributes[name] != nil {
         if seen.insert(name).inserted {
            parts.append(Self.formatAttribute(name: name, value: attributes[name]!))
         }
      }
      for (name, value) in attributes.sorted(by: { $0.key < $1.key }) where !seen.contains(name) {
         parts.append(Self.formatAttribute(name: name, value: value))
      }
      return parts.joined(separator: " ")
   }

   private static func formatAttribute(name: String, value: String) -> String {
      guard !value.isEmpty else { return name }
      return #"\#(name)="\#(value.replacing("\"", with: "&quot;"))""#
   }
}
