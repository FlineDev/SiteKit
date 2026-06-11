import Foundation

/// Enricher that assigns a framework key to each DocC session note using a central
/// flat JSON map (`{ "wwdc25-101": "design", "wwdc25-210": "swiftui", … }`), rather
/// than requiring per-note frontmatter edits.
///
/// The lookup key is derived from the note slug's first two dash-separated segments:
/// `wwdc25-101-keynote` → `wwdc25-101`. This matches the key format the WWDCNotes metadata generator
/// produces from the sessions.json session id (`wwdc2025-101` → strip century → `wwdc25-101`).
///
/// When `doccFramework` is already set on a note (via a per-note `<!-- framework: key -->`
/// comment or `@CustomAttribute(name:"framework")` directive), the map lookup is skipped
/// and the per-note value wins. This preserves the ability to override individual sessions
/// without touching the central map.
///
/// Non-DocC pages (those lacking the `doccNote: true` extension) are passed through unchanged.
public struct DocCFrameworkEnricher: Enricher {
   /// The central session-id → framework-key map, loaded from `sessionFrameworksPath`.
   private let map: [String: String]

   /// Initialise with a pre-decoded map. The map uses the `wwdcYY-<code>` key format.
   public init(map: [String: String]) {
      self.map = map
   }

   public func enrich(_ page: PageModel) throws -> PageModel {
      // Only act on notes loaded by DocCLoader.
      guard (page.extensions["doccNote"] as? Bool) == true else { return page }

      // Per-note value wins – do not overwrite it.
      if page.extensions["doccFramework"] != nil { return page }

      // Derive lookup key: first two dash-separated slug segments (WWDC only).
      // An empty key means the slug is not a WWDC session – leave it untouched.
      let key = Self.sessionKey(from: page.slug)
      guard !key.isEmpty, let frameworkKey = self.map[key] else { return page }

      var extensions = page.extensions
      extensions["doccFramework"] = frameworkKey
      return PageModel(
         id: page.id,
         title: page.title,
         date: page.date,
         slug: page.slug,
         htmlContent: page.htmlContent,
         sourcePath: page.sourcePath,
         category: page.category,
         tags: page.tags,
         summary: page.summary,
         description: page.description,
         author: page.author,
         image: page.image,
         imageAlt: page.imageAlt,
         draft: page.draft,
         pageType: page.pageType,
         locale: page.locale,
         originalLanguage: page.originalLanguage,
         legalDocument: page.legalDocument,
         extensions: extensions
      )
   }

   /// Returns the `wwdcYY-<code>` lookup key for a slug, i.e. the first two
   /// dash-separated segments joined by a dash. Only WWDC session slugs (first
   /// segment starts with "wwdc") get a key; non-WWDC slugs like "getting-started"
   /// would match the same two-segment pattern but have no entry in the map, so
   /// returning an empty string avoids a spurious lookup.
   ///
   /// Examples:
   /// - `wwdc25-101-keynote` → `wwdc25-101`
   /// - `wwdc24-10094-foo-bar` → `wwdc24-10094`
   /// - `wwdc25` (year overview) → `wwdc25` (single segment, no match expected)
   /// - `getting-started` → `""` (no WWDC prefix, skipped)
   static func sessionKey(from slug: String) -> String {
      let parts = slug.split(separator: "-")
      guard parts.count >= 2 else { return slug }
      // Only derive a lookup key for WWDC session slugs. Non-WWDC slugs with two
      // dash-separated segments (e.g. "getting-started") must not receive a key
      // because the map only contains WWDC session ids.
      guard parts[0].lowercased().hasPrefix("wwdc") else { return "" }
      return parts.prefix(2).joined(separator: "-")
   }
}
