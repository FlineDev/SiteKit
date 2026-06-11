import Foundation

/// Decides which image variants to generate for a given role and how to express
/// them in the rewritten `<img>` markup (`src`, `srcset`, `sizes`, `width`, `height`).
///
/// Two emission strategies, chosen by comparing mobile and desktop layout widths:
///
/// - **Density strategy** (mobile ≥ desktop / 2): the mobile layout is not
///   meaningfully narrower than desktop (e.g. avatars, icons, cards that fill a
///   single column at both breakpoints). Emit a simple density srcset:
///   `src="…-{desktopWidth}w.webp"` + `srcset="… 2x"`. Two variants on disk.
///
/// - **Responsive strategy** (mobile < desktop / 2): mobile is meaningfully
///   narrower (full-bleed heroes, hero backgrounds). Emit a `sizes` +
///   width-descriptor srcset so the browser can pick a mobile-specific variant
///   when the viewport is below the breakpoint. Three variants on disk:
///   mobile-retina, desktop (1×), desktop-retina.
///
/// In both strategies we cap targets at the source image's intrinsic width –
/// asking ImageMagick to upscale would either fail (`>` modifier refuses) or
/// balloon file size for no quality gain. If two planned targets collapse to the
/// same file (e.g. both ≥ source), the plan emits the source path for both so
/// the srcset still makes sense.
struct ImageVariantPlanner {
   enum Strategy: Equatable {
      case density
      case responsive
   }

   struct Plan {
      let strategy: Strategy
      let role: ImageRole
      let displayWidth: Int              // the `width` attr – logical CSS width at desktop
      let displayHeight: Int             // derived from source aspect ratio
      let fallbackWidth: Int             // the target that will back `src=` attr
      let densityPairs: [(pixelRatio: String, targetWidth: Int)]   // for .density
      let responsiveEntries: [(width: Int, mediaQuery: String?)]   // for .responsive: srcset + sizes
      let mobileBreakpoint: Int

      /// The set of target widths we need to generate, deduped.
      var uniqueTargetWidths: [Int] {
         switch self.strategy {
         case .density:
            return Array(Set(self.densityPairs.map(\.targetWidth))).sorted()
         case .responsive:
            return Array(Set(self.responsiveEntries.map(\.width))).sorted()
         }
      }

      /// The smallest target width – used for "bytes saved" accounting (what a
      /// mobile visitor actually downloads).
      var smallestTargetWidth: Int {
         self.uniqueTargetWidths.first ?? self.fallbackWidth
      }
   }

   static func plan(role: ImageRole, sourceWidth: Int, sourceHeight: Int, mobileBreakpoint: Int) -> Plan {
      let desktopBase = min(role.desktopWidth, sourceWidth)
      let desktopRetina = min(role.desktopWidth * 2, sourceWidth)
      let mobileRetina = min(role.mobileWidth * 3, sourceWidth)

      // Height at the chosen `width` attr. Match CSS aspect-ratio expectations:
      // we advertise `width=desktopBase`, so the complementary height preserves the
      // source aspect ratio (browsers scale the picked srcset variant to fit).
      let height: Int
      if sourceWidth > 0 {
         height = max(1, Int(Double(desktopBase) * Double(sourceHeight) / Double(sourceWidth) + 0.5))
      } else {
         height = 1
      }

      let useResponsive = role.mobileWidth * 2 < role.desktopWidth
         && mobileRetina < desktopRetina

      if useResponsive {
         // Three widths – mobile retina, desktop 1×, desktop retina – give the
         // browser enough options to pick the most efficient download for any
         // viewport × DPR combination. Without the desktop-1× entry, a
         // desktop DPR=1 visitor would load the retina variant unnecessarily.
         var widths: Set<Int> = [mobileRetina, desktopBase, desktopRetina]
         let sortedWidths = widths.sorted()
         widths = Set(sortedWidths)  // already a Set; kept for clarity
         let entries: [(width: Int, mediaQuery: String?)] = sortedWidths.map {
            (width: $0, mediaQuery: nil)
         }
         return Plan(
            strategy: .responsive,
            role: role,
            displayWidth: desktopBase,
            displayHeight: height,
            fallbackWidth: desktopBase,
            densityPairs: [],
            responsiveEntries: entries,
            mobileBreakpoint: mobileBreakpoint
         )
      } else {
         var pairs: [(pixelRatio: String, targetWidth: Int)] = []
         pairs.append((pixelRatio: "1x", targetWidth: desktopBase))
         if desktopRetina != desktopBase {
            pairs.append((pixelRatio: "2x", targetWidth: desktopRetina))
         }
         // Dedupe accidental duplicates (source smaller than both targets).
         var seen: Set<Int> = []
         let uniquePairs = pairs.filter { seen.insert($0.targetWidth).inserted }
         return Plan(
            strategy: .density,
            role: role,
            displayWidth: desktopBase,
            displayHeight: height,
            fallbackWidth: desktopBase,
            densityPairs: uniquePairs,
            responsiveEntries: [],
            mobileBreakpoint: mobileBreakpoint
         )
      }
   }
}
