import Foundation

/// Shared gradient hero box for DocC page headers.
///
/// One mechanic, three consumers: session-note article headers and guide headers
/// (both via `DocCArticlePage`) and the Missing-Sessions hero (`DocCMissingPage`).
/// The box is the `sk-docc-hero` gradient surface; slots fill its inner column with
/// a top line (breadcrumb nav or eyebrow), the page h1, a subtitle, and an optional
/// CTA row that lives INSIDE the box. An optional decorative art panel sits to the
/// right of the inner column.
///
/// Two styles share the mechanic: `card` (the default) is a rounded card whose inner
/// column keeps the base horizontal inset, matching the home/contributors hero surface;
/// `band` adds `sk-docc-hero--band`, which the stylesheet turns into a square-cornered
/// color band spanning the full content pane while the text stays on the column width.
enum DocCHeroBox {
   /// Renders the gradient hero box.
   ///
   /// - Parameters:
   ///   - tag: Wrapping element name – "header" for article headers (semantic
   ///     sectioning), "div" for special pages whose heading lives inside `main`.
   ///   - leadingClasses: Consumer-specific classes emitted BEFORE the shared hero
   ///     classes, so consumers can be targeted by a stable class prefix.
   ///   - style: Card (rounded, inset, default) or band (full-width color band).
   ///   - topHTML: Pre-rendered slot above the title (breadcrumb nav or eyebrow). Empty to omit.
   ///   - titleHTML: Pre-rendered h1 element.
   ///   - subtitleHTML: Pre-rendered subtitle/abstract element. Empty to omit.
   ///   - ctaHTML: Pre-rendered CTA row rendered inside the box, after the subtitle. Empty to omit.
   ///   - artHTML: Decorative art panel rendered after the inner column. Empty to omit.
   static func render(
      tag: String = "div",
      leadingClasses: [String] = [],
      style: DocCArticleHeroStyle = .card,
      topHTML: String = "",
      titleHTML: String,
      subtitleHTML: String = "",
      ctaHTML: String = "",
      artHTML: String = ""
   ) -> String {
      var heroClasses = ["sk-docc-hero", "sk-docc-hero--compact", "is-compact"]
      if style == .band {
         heroClasses.append("sk-docc-hero--band")
      }
      let classes = (leadingClasses + heroClasses).joined(separator: " ")
      let inner = "<div class=\"sk-docc-hero-inner\">\(topHTML)\(titleHTML)\(subtitleHTML)\(ctaHTML)</div>"
      return "<\(tag) class=\"\(classes)\">\(inner)\(artHTML)</\(tag)>"
   }

   /// The decorative prism art panel: the brand key-visual hook that the stylesheet
   /// (or a site's theme layer) paints with the radial-gradient blob. Markup matches
   /// the panel the home and contributors heroes emit, so all prism heroes share one
   /// skinning surface.
   static func prismArt() -> String {
      "<div class=\"sk-docc-hero-art\" aria-hidden=\"true\"><div class=\"sk-docc-hero-prism\"></div></div>"
   }
}
