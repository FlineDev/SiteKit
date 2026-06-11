import Foundation

/// Single source of truth for which DocC catalog notes are superseded by a specialized
/// page renderer. When a catalog generates overview notes (e.g. `WWDC24.md`, `Contributors.md`),
/// those notes would otherwise collide with the specialized pages that own those routes.
/// This enum centralises the ownership rules so that:
/// - `DocCArticlePage` can exclude the claimed slugs from its `pages(in:)` output.
/// - `DocCYearListingPage` and `DocCContributorsPage` can read the catalog note for
///   hero metadata without duplicating the "is this note mine?" logic.
///
/// Adding support for a new specialized page is a one-line addition: expose a
/// `static let <name>Slug = "<slug>"` constant and add it to `reservedSlugs(in:)`
/// when a catalog note with that slug exists – just as `missingSlug` was added for
/// `DocCMissingPage`.
enum DocCReservedRoutes {
   /// The slug owned by `DocCContributorsPage`.
   static let contributorsSlug = "contributors"

   /// The slug owned by `DocCMissingPage`.
   ///
   /// Matches the slug of the `MissingNotes.md` catalog note that WWDCNotes ships
   /// at `/documentation/missingnotes/`. The live URL was verified to confirm that
   /// the filename slugifies to `missingnotes` – no hyphen.
   static let missingSlug = "missingnotes"

   /// The slug owned by `DocCSearchPage` (the dedicated facet-filtered search page at
   /// `/<prefix>/search/`). `DocCSearchPage` synthesizes this route from the index, so
   /// any real catalog note that happens to slugify to `search` must yield the URL to it.
   static let searchSlug = "search"

   /// Returns the set of note slugs that are claimed by a specialized page renderer, given the
   /// site's DocC feature flags. A specialized page only claims its slug when the matching feature
   /// is enabled, because a disabled feature does not register its renderer – so the slug must fall
   /// back to `DocCArticlePage` instead of being silently dropped.
   ///
   /// A note is claimed when:
   /// - Its slug equals a year key (`wwdc<digits>`) AND that year has at least one child
   ///   session note → `DocCYearListingPage` owns the year-root URL. (Always – year grouping is
   ///   not a gated feature.)
   /// - Its slug equals `"contributors"` AND `docc.contributorsEnabled` → `DocCContributorsPage`
   ///   owns that URL.
   /// - Its slug equals `"missingnotes"` AND `docc.missingSessionsEnabled` → `DocCMissingPage`
   ///   owns that URL.
   /// - It is a generated contributor profile note (`Contributors/<handle>.md`) → the bare-handle
   ///   slug is always reserved so `DocCArticlePage` never renders a standalone
   ///   `/documentation/<handle>/` orphan. When contributors is on, `DocCContributorPage` owns the
   ///   `/contributors/<handle>/` URL; when off, the profile simply does not appear anywhere.
   /// - Its slug equals `"search"` AND `docc.searchEnabled` → `DocCSearchPage` owns that URL.
   ///
   /// Notes whose slugs are in this set must NOT be rendered by `DocCArticlePage`,
   /// because the specialized page already writes the same output URL.
   ///
   /// `docc` is the site's `DocCConfig` (nil ⇒ all-default flags: contributors/missing off, search on).
   static func reservedSlugs(in notes: [PageModel], docc: DocCConfig?) -> Set<String> {
      let features = docc ?? DocCConfig()
      var reserved = Set<String>()

      // Collect all year keys that have at least one session child.
      var yearsWithSessions = Set<String>()
      for note in notes {
         guard let key = DocCNavigationTree.yearKey(of: note.slug), note.slug != key else { continue }
         yearsWithSessions.insert(key)
      }

      // Any catalog note whose slug IS a year key with sessions is owned by DocCYearListingPage.
      // Year grouping is unconditional – it is not one of the gated features.
      for note in notes {
         guard let key = DocCNavigationTree.yearKey(of: note.slug), note.slug == key else { continue }
         if yearsWithSessions.contains(key) {
            reserved.insert(note.slug)
         }
      }

      // The contributors note is owned by DocCContributorsPage only when the contributors feature
      // is enabled. When off, the page is not registered, so a literal `Contributors.md` note must
      // render as a normal article rather than vanish.
      if features.contributorsEnabled, notes.contains(where: { $0.slug == Self.contributorsSlug }) {
         reserved.insert(Self.contributorsSlug)
      }

      // The missingnotes note is owned by DocCMissingPage only when the missing-sessions feature
      // is enabled.
      if features.missingSessionsEnabled, notes.contains(where: { $0.slug == Self.missingSlug }) {
         reserved.insert(Self.missingSlug)
      }

      // Generated contributor profile notes (`Contributors/<handle>.md`, slug == bare handle) are
      // reserved unconditionally: with contributors on they are owned by DocCContributorPage at
      // /contributors/<handle>/, and with contributors off they must not leak as standalone
      // /documentation/<handle>/ orphan articles. Either way DocCArticlePage must skip them.
      for note in notes where (note.extensions["doccContributorProfile"] as? Bool) == true {
         reserved.insert(note.slug)
      }

      // The search note (if a catalog ships one) is owned by DocCSearchPage only when search is on.
      if features.searchEnabled, notes.contains(where: { $0.slug == Self.searchSlug }) {
         reserved.insert(Self.searchSlug)
      }

      return reserved
   }

   /// Returns true when a note whose slug equals a year key should be owned by
   /// `DocCYearListingPage` (i.e. the year has at least one session note).
   static func isClaimedYearRoot(slug: String, in notes: [PageModel]) -> Bool {
      guard let key = DocCNavigationTree.yearKey(of: slug), slug == key else { return false }
      return notes.contains { note in
         guard let noteKey = DocCNavigationTree.yearKey(of: note.slug) else { return false }
         return noteKey == key && note.slug != key
      }
   }
}
