import Foundation
import Yams

/// Failures while loading `Content/ImageManifest.yaml`.
public enum ImageManifestError: Error {
   /// No manifest file exists at the given URL.
   case fileNotFound(URL)
   /// The manifest exists but does not decode; the payload is the decoder's
   /// error description.
   case invalidYAML(String)
}

/// Declares the CSS display width of every `<img>` on a site so the image pipeline
/// can generate correctly-sized variants.
///
/// ### Why this exists
///
/// Static site generators can't know what CSS pixel width an image will render at
/// without rendering the page in a browser. A hero image committed at 2000×1125 px
/// might be displayed at 720 CSS px on desktop and 390 CSS px on mobile – the pipeline
/// must serve a size that respects retina DPR at each breakpoint (e.g. 720×2 = 1440
/// for desktop retina, 390×3 = 1170 for mobile retina) without over-serving.
///
/// `ImageManifest.yaml` makes that display width **declarative data** the AI agent
/// maintains by reading theme CSS. The agent:
/// - reads selectors & widths from `base.css` and `Theme/*.css`
/// - writes one role per image class used on the site
/// - re-visits the manifest only when the layout changes (new breakpoint, new class)
///
/// Per-article content additions (new markdown file, new inline image) usually need
/// no manifest edit – existing role selectors cover them.
///
/// ### File location
///
/// `<projectDirectory>/Content/ImageManifest.yaml` by convention. If the file is
/// missing, the pipeline falls back to a heuristic and logs a warning.
///
/// ### Shape
///
/// ```yaml
/// roles:
///   - name: article-hero
///     selector: "figure.sk-article-hero > img"
///     desktopWidth: 720
///     mobileWidth: 390
///   - name: default         # catch-all – put last
///     selector: "img"
///     desktopWidth: 720
///     mobileWidth: 390
///
/// mobileBreakpoint: 768     # CSS px breakpoint between mobile & desktop widths
/// ```
///
/// Role match order matters – first-match wins. The pipeline resolves a role per
/// `<img>` by walking `roles` in order and testing each `selector` against the
/// image's tag name, classes, and immediate parent.
public struct ImageManifest: Codable, Sendable, Equatable {
   /// The declared image roles, tested in order – first matching `selector`
   /// wins, so put the catch-all role last.
   public let roles: [ImageRole]

   /// CSS px viewport breakpoint separating `mobileWidth` from `desktopWidth`;
   /// nil falls back to 768 (see `effectiveMobileBreakpoint`).
   public let mobileBreakpoint: Int?

   /// Memberwise initializer – primarily for tests; production manifests load
   /// from YAML via `load(fromProjectDirectory:)`.
   public init(roles: [ImageRole], mobileBreakpoint: Int? = nil) {
      self.roles = roles
      self.mobileBreakpoint = mobileBreakpoint
   }

   /// CSS px breakpoint between mobile and desktop widths. Defaults to 768.
   public var effectiveMobileBreakpoint: Int {
      self.mobileBreakpoint ?? 768
   }

   /// Loads `ImageManifest.yaml` from a project's `Content/` directory.
   ///
   /// Returns `nil` if the file doesn't exist – the caller decides whether that's
   /// a soft warning (fall back to heuristic) or an error.
   public static func load(fromProjectDirectory projectDirectory: URL) throws -> ImageManifest? {
      let manifestPath = projectDirectory
         .appendingPathComponent("Content")
         .appendingPathComponent("ImageManifest.yaml")
      guard FileManager.default.fileExists(atPath: manifestPath.path) else { return nil }

      let yamlString = try String(contentsOf: manifestPath, encoding: .utf8)
      do {
         return try YAMLDecoder().decode(ImageManifest.self, from: yamlString)
      } catch {
         throw ImageManifestError.invalidYAML(error.localizedDescription)
      }
   }
}

/// A single entry in `ImageManifest.yaml`. Describes one visual role (article hero,
/// listing thumbnail, app icon, logo, etc.) and the CSS display width it occupies
/// at desktop and mobile breakpoints.
///
/// The `selector` is a minimal CSS-ish expression – see `SelectorMatcher` for the
/// supported grammar. Just enough to express class, tag, parent > child, and
/// comma-separated alternatives; a full CSS selector engine would be overkill for
/// the roles a static site generator needs to distinguish.
public struct ImageRole: Codable, Sendable, Equatable {
   /// Human-readable role label (e.g. `article-hero`) – documentation only,
   /// matching is by `selector`.
   public let name: String

   /// Minimal CSS-ish selector matched against an `<img>`'s tag, classes, and
   /// immediate parent (see `SelectorMatcher` for the grammar).
   public let selector: String

   /// CSS display width in px at or above the mobile breakpoint.
   public let desktopWidth: Int

   /// CSS display width in px below the mobile breakpoint.
   public let mobileWidth: Int

   /// Memberwise initializer – primarily for tests; production roles decode
   /// from `ImageManifest.yaml`.
   public init(name: String, selector: String, desktopWidth: Int, mobileWidth: Int) {
      self.name = name
      self.selector = selector
      self.desktopWidth = desktopWidth
      self.mobileWidth = mobileWidth
   }
}
