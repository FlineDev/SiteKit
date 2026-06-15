import Foundation

/// Shared builder for the `sk-docc-sessitem` session row – the framework-icon ·
/// eyebrow · title · blurb · chevron card reused across the DocC listing surfaces
/// (year overview, contributor detail, and the dedicated search page's server-rendered
/// fallback). Centralising the row assembly here keeps every surface byte-identical
/// instead of maintaining three (now four) near-copies of the same markup.
///
/// The differences between callers are expressed through slots rather than forks:
/// - `leadingGlyph` – a framework icon (`frameworkIconHTML`) on the year/search rows,
///   the mono brace (`braceGlyph`) on contributor rows.
/// - `headExtra` – extra markup appended inside the head row after the title (e.g. the
///   year page's "Needs notes" stub pill).
/// - `footExtra` – the foot row's contents (e.g. kind/platform badges, a stub pill, or a
///   note-type badge); an empty string omits the foot entirely.
///
/// The dynamically-filtered search **page** renders its rows client-side from the search
/// index (so they can be re-listed as the query and facets change), mirroring these exact
/// class names in `docc-search-page.js` so one set of CSS rules styles both the
/// server-rendered and the client-rendered rows.
enum DocCSessionRow {
   /// The mono "{ }" brace glyph used as the leading mark on contributor rows.
   static let braceGlyph =
      "<span class=\"sk-docc-sessitem-brace\" aria-hidden=\"true\">{ }</span>"

   /// Renders the framework icon slot for a session row: a white FontAwesome glyph centered
   /// on the framework's colored tile (a chip), or a neutral placeholder square when the note
   /// has no framework or the framework key is not in the registry.
   ///
   /// The tile background (the framework gradient for two colors, a solid fill for one) and the
   /// white glyph color are applied by CSS keyed on `data-framework` (the generated
   /// `[data-framework]` rules from `DocCStylesheetRenderer` paint the tile; `docc.css` makes
   /// the glyph white). A white glyph on a saturated tile reads cleanly in both light and dark,
   /// so no per-glyph inline color/background is emitted here.
   ///
   /// Mirrors the sidebar's icon treatment so a session looks the same in the tree and in
   /// a listing row. The icon class is `sk-docc-sessitem-icon` (distinct from the sidebar's
   /// `sk-docc-nav-icon` so each context sizes its slot independently).
   static func frameworkIconHTML(framework: String?, context: BuildContext) -> String {
      let icons = context.config.docc?.frameworks
      guard let key = framework, let icon = icons?[key] else {
         return "<span class=\"sk-docc-sessitem-icon\" aria-hidden=\"true\"></span>"
      }
      return "<span class=\"sk-docc-sessitem-icon\" data-framework=\"\(self.escape(key))\" aria-hidden=\"true\">"
         + "<i class=\"\(self.escape(icon.glyph))\" aria-hidden=\"true\"></i>"
         + "</span>"
   }

   /// Assembles the full `<a class="sk-docc-sessitem">` anchor from its parts.
   ///
   /// - Parameters:
   ///   - href: The destination URL (escaped here).
   ///   - leadingGlyph: Pre-rendered leading mark (`frameworkIconHTML` or `braceGlyph`).
   ///   - eyebrow: Optional small-caps eyebrow text (escaped here); omitted when nil.
   ///   - titleHTML: The title, already escaped (or pre-highlighted) by the caller.
   ///   - headExtra: Raw markup appended in the head row after the title; "" for none.
   ///   - minutes: Optional reading-time minutes, rendered right-aligned; nil for none.
   ///   - blurb: Optional summary line (escaped here); omitted when nil/empty.
   ///   - footExtra: Raw markup for the foot row's contents; "" omits the foot entirely.
   ///   - isStub: Adds the `is-stub` dimming modifier when true.
   static func render(
      href: String,
      leadingGlyph: String,
      eyebrow: String?,
      titleHTML: String,
      headExtra: String = "",
      minutes: Int? = nil,
      blurb: String? = nil,
      footExtra: String = "",
      isStub: Bool = false
   ) -> String {
      var head = "<div class=\"sk-docc-sessitem-head\">"
      if let eyebrow, !eyebrow.isEmpty {
         head += "<span class=\"sk-docc-sessitem-eyebrow\">\(self.escape(eyebrow))</span>"
      }
      head += "<span class=\"sk-docc-sessitem-title\">\(titleHTML)</span>"
      head += headExtra
      if let minutes {
         head += "<span class=\"sk-docc-sessitem-min\">\(minutes) min</span>"
      }
      head += "</div>"

      var main = "<div class=\"sk-docc-sessitem-main\">\(head)"
      if let blurb, !blurb.isEmpty {
         main += "<p class=\"sk-docc-sessitem-blurb\">\(self.escape(blurb))</p>"
      }
      if !footExtra.isEmpty {
         main += "<div class=\"sk-docc-sessitem-foot\">\(footExtra)</div>"
      }
      main += "</div>"

      let stubClass = isStub ? " is-stub" : ""
      return "<a class=\"sk-docc-sessitem\(stubClass)\" href=\"\(self.escape(href))\">"
         + leadingGlyph
         + main
         + "<i class=\"sk-docc-sessitem-chev\" aria-hidden=\"true\">›</i>"
         + "</a>"
   }

   static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
