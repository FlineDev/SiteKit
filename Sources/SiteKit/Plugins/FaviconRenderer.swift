import Foundation
import Logging

/// Copies pre-generated favicon files from `Content/Assets/Favicons/` to the site output root.
///
/// **How it works:**
/// The renderer copies all files from the site's `Content/Assets/Favicons/` directory to the
/// output root (`_Site/`), where browsers expect favicon files. If the directory does not exist
/// or is empty, a warning is logged with instructions for generating the files.
///
/// **Why no image processing:**
/// FaviconRenderer intentionally does NOT resize or convert images at build time. Image
/// processing requires platform-specific CLI tools that may not be available in CI
/// environments. Instead, favicons are generated once locally, committed to the repo,
/// and simply copied at build time. This makes builds fast, reproducible, and CI-friendly.
///
/// **Standard favicon files:**
/// - `apple-touch-icon.png` – 180×180 PNG, **opaque background**, iOS home-screen bookmark
/// - `favicon-32x32.png` – 32×32 PNG, transparent, browser tabs
/// - `favicon-16x16.png` – 16×16 PNG, transparent, browser tabs (small)
/// - `favicon.ico` – multi-size (16/32/48/64), legacy `/favicon.ico` request fallback
///
/// Any additional files (e.g. `site.webmanifest`) are also copied to the site root.
///
/// **Apple-touch-icon: respect Apple's icon grid.**
/// The apple-touch-icon is rendered by iOS as a full app-style tile on the user's home
/// screen. Unlike browser-tab favicons, it must be **opaque** (transparent icons inherit
/// the wallpaper) and must **respect the iOS icon keyline** – primary content fits within
/// ~66–72% of the canvas, with the rest being opaque background. Filling 180×180 edge-to-edge
/// looks amateurish and may get clipped by iOS' rounded-corner squircle mask.
///
/// **Generating favicons (macOS, requires ImageMagick: `brew install imagemagick`):**
/// ```bash
/// mkdir -p Content/Assets/Favicons
/// SRC="path/to/your-logo.png"
/// BG="#0F172A"   # Opaque bg (e.g. dark-mode body color)
///
/// # apple-touch-icon: logo at 66% keyline (118px), centered on opaque bg.
/// # -trim removes transparent source padding so 66% applies to actual content.
/// magick "$SRC" -trim +repage -resize 118x118 \
///    -background "$BG" -gravity center -extent 180x180 \
///    Content/Assets/Favicons/apple-touch-icon.png
///
/// # Browser-tab favicons: transparent, tight crop for legibility at tiny sizes.
/// magick "$SRC" -trim +repage -resize 32x32 Content/Assets/Favicons/favicon-32x32.png
/// magick "$SRC" -trim +repage -resize 16x16 Content/Assets/Favicons/favicon-16x16.png
/// magick "$SRC" -trim +repage -define icon:auto-resize=64,48,32,16 \
///    Content/Assets/Favicons/favicon.ico
/// ```
///
/// Start from a square source ≥512×512 for best results. Any raster format works (PNG,
/// JPG, WebP). **Always visually inspect the generated apple-touch-icon** before
/// committing – iOS caches home-screen icons aggressively, so getting it right the first
/// time matters.
///
/// **What favicons are (for explaining to users):**
/// Favicons are small icon versions of your logo that appear in browser tabs, bookmarks,
/// and when someone saves your website to their phone's home screen. They make your site
/// look professional and recognizable.
public struct FaviconRenderer: Renderer {
   public var scope: RenderScope { .global }

   private let logger = Logger(label: "SiteKit.FaviconRenderer")

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      // Resolve under the configured assetsDirectory (the same root the AssetCopier
      // teleports from), not contentDirectory + "Assets". Those coincide for the
      // default blog layout (contentDirectory "Content", assetsDirectory
      // "Content/Assets") but diverge for DocC sites, where contentDirectory is "."
      // and the favicons still live under "Content/Assets/Favicons".
      let faviconsDir = context.projectDirectory
         .appendingPathComponent(context.config.assetsDirectory)
         .appendingPathComponent("Favicons")

      let fileManager = FileManager.default
      guard fileManager.fileExists(atPath: faviconsDir.path) else {
         self.logMissingFaviconsWarning()
         return []
      }

      let filenames: [String]
      do {
         filenames = try fileManager.contentsOfDirectory(atPath: faviconsDir.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
      } catch {
         self.logger.warning("Could not read Favicons directory: \(error.localizedDescription)")
         return []
      }

      guard !filenames.isEmpty else {
         self.logMissingFaviconsWarning()
         return []
      }

      var files: [OutputFile] = []
      for filename in filenames {
         let sourcePath = faviconsDir.appendingPathComponent(filename)
         guard let data = try? Data(contentsOf: sourcePath) else {
            self.logger.warning("Could not read favicon file: \(filename)")
            continue
         }

         let outputPath = context.outputDirectory.appendingPathComponent(filename)
         files.append(OutputFile(outputPath: outputPath, binaryContent: data))
      }

      if files.isEmpty {
         self.logger.warning("No favicon files could be read from Content/Assets/Favicons/")
      } else {
         self.logger.info("Copying \(files.count) favicon file(s) from Content/Assets/Favicons/ to site root")
      }

      return files
   }

   // MARK: - Missing Favicons Warning

   private func logMissingFaviconsWarning() {
      self.logger.warning(
         """
         No favicons found in Content/Assets/Favicons/. \
         Favicons make your site look professional in browser tabs and when saved to home screens. \
         Requires ImageMagick (brew install imagemagick). Apple-touch-icon must be opaque and \
         respect Apple's icon grid (logo at ~66% of 180×180 canvas, centered on opaque bg). \
         Generate them with: \
         magick <source> -trim +repage -resize 118x118 -background '#0F172A' -gravity center \
         -extent 180x180 Content/Assets/Favicons/apple-touch-icon.png; \
         magick <source> -trim +repage -resize 32x32 Content/Assets/Favicons/favicon-32x32.png; \
         magick <source> -trim +repage -resize 16x16 Content/Assets/Favicons/favicon-16x16.png; \
         magick <source> -trim +repage -define icon:auto-resize=64,48,32,16 \
         Content/Assets/Favicons/favicon.ico. \
         See FaviconRenderer docs for details.
         """
      )
   }
}
