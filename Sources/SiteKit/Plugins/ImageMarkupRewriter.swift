import Foundation

/// Applies an `ImageVariantPlanner.Plan` to a parsed attribute dictionary, setting
/// `src`, `srcset`, `sizes`, `width`, and `height` for the rewritten `<img>`.
///
/// Kept separate from the rest of `ImageResizer` so the plan→markup transformation
/// can be tested in isolation: feed in a plan + attrs, inspect the output dict,
/// no filesystem required.
enum ImageMarkupRewriter {
   static func apply(
      plan: ImageVariantPlanner.Plan,
      parsed: [String: String],
      pathByWidth: [Int: String]
   ) -> [String: String] {
      var result = parsed

      switch plan.strategy {
      case .density:
         let srcPath = pathByWidth[plan.fallbackWidth] ?? (result["src"] ?? "")
         result["src"] = srcPath
         // Collapse duplicate entries (e.g. source smaller than retina target) – a
         // single path with `1x` already covers those cases.
         var seenPaths: Set<String> = []
         var srcsetParts: [String] = []
         for pair in plan.densityPairs {
            guard let path = pathByWidth[pair.targetWidth] else { continue }
            guard seenPaths.insert(path).inserted else { continue }
            srcsetParts.append("\(path) \(pair.pixelRatio)")
         }
         result["srcset"] = srcsetParts.joined(separator: ", ")
         // Density srcset doesn't need `sizes`.
         result.removeValue(forKey: "sizes")

      case .responsive:
         let srcPath = pathByWidth[plan.fallbackWidth] ?? (result["src"] ?? "")
         result["src"] = srcPath
         var srcsetParts: [String] = []
         for entry in plan.responsiveEntries {
            guard let path = pathByWidth[entry.width] else { continue }
            srcsetParts.append("\(path) \(entry.width)w")
         }
         result["srcset"] = srcsetParts.joined(separator: ", ")
         // Sizes: mobile media query first, desktop default last. Example:
         // `(max-width: 768px) 390px, 720px`.
         var sizesParts: [String] = []
         sizesParts.append("(max-width: \(plan.mobileBreakpoint)px) \(plan.role.mobileWidth)px")
         sizesParts.append("\(plan.role.desktopWidth)px")
         result["sizes"] = sizesParts.joined(separator: ", ")
      }

      result["width"] = String(plan.displayWidth)
      result["height"] = String(plan.displayHeight)

      return result
   }
}
