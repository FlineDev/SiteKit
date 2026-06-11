import Foundation

/// One of the nine preview variants. Each variant pins a layout template + color
/// scheme + font pairing + light/dark mode; the driver writes a matching
/// `theme.yaml` into the fixture before each build.
public struct PreviewVariant: Sendable, Equatable {
   public enum Mode: String, Sendable, Equatable {
      case light, dark
   }

   public let layoutTemplate: String
   public let colorScheme: String
   public let fontPairing: String
   public let mode: Mode

   public init(layoutTemplate: String, colorScheme: String, fontPairing: String, mode: Mode) {
      self.layoutTemplate = layoutTemplate
      self.colorScheme = colorScheme
      self.fontPairing = fontPairing
      self.mode = mode
   }

   /// Filename stem used for `preview/<id>.html`. The committed
   /// `ThemePreview.html` index references these names directly, so changing the
   /// shape here means updating the index alongside.
   public var id: String {
      "\(self.layoutTemplate)-\(self.colorScheme)-\(self.fontPairing)-\(self.mode.rawValue)"
   }

   /// Content of the `theme.yaml` the driver writes into the fixture before the
   /// matching build. The `headInlineScript` forces `data-theme` to the variant's
   /// mode at first paint – overriding the localStorage / `prefers-color-scheme`
   /// detection a real site would use – so a "dark" preview always renders dark.
   public func themeYAML() -> String {
      """
      name: "\(self.layoutTemplate)"
      colorScheme: "\(self.colorScheme)"
      fontPairing: "\(self.fontPairing)"
      css:
         - "css/theme.css"
      js:
         - "js/theme.js"
      headInlineScript: "document.documentElement.setAttribute('data-theme','\(self.mode.rawValue)')"
      """
   }
}

/// The canonical nine variants. Three per layout template, each pairing it with
/// a different color scheme and font pairing so the grid exercises the full
/// chrome × token combination space. Adding a fourth layout template is a
/// one-line edit here plus a re-run.
public let previewVariants: [PreviewVariant] = [
   PreviewVariant(layoutTemplate: "Classic", colorScheme: "indigo", fontPairing: "editorial", mode: .light),
   PreviewVariant(layoutTemplate: "Classic", colorScheme: "slate", fontPairing: "system", mode: .dark),
   PreviewVariant(layoutTemplate: "Classic", colorScheme: "amber", fontPairing: "modern", mode: .light),
   PreviewVariant(layoutTemplate: "Sidebar", colorScheme: "slate", fontPairing: "system", mode: .light),
   PreviewVariant(layoutTemplate: "Sidebar", colorScheme: "indigo", fontPairing: "modern", mode: .dark),
   PreviewVariant(layoutTemplate: "Sidebar", colorScheme: "amber", fontPairing: "editorial", mode: .light),
   PreviewVariant(layoutTemplate: "Minimal", colorScheme: "amber", fontPairing: "editorial", mode: .light),
   PreviewVariant(layoutTemplate: "Minimal", colorScheme: "indigo", fontPairing: "system", mode: .dark),
   PreviewVariant(layoutTemplate: "Minimal", colorScheme: "slate", fontPairing: "modern", mode: .light),
]
