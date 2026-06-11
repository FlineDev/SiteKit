import Foundation
import Testing

@testable import SiteKit

@Suite("DocCReservedRoutes")
struct DocCReservedRoutesTests {
   // MARK: - Helpers

   private func note(slug: String, title: String = "Untitled", doccNote: Bool = true) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         pageType: .article,
         extensions: doccNote ? ["doccNote": true] : [:]
      )
   }

   // MARK: - reservedSlugs(in:)

   @Test("Empty set when catalog has no year-root notes and no contributors note")
   func emptyWhenNoClaimedNotes() {
      // Loose page and a session without a year-root overview note.
      // A year that has session children but no overview note is NOT reserved –
      // there is no catalog note slug to reserve.
      let notes: [PageModel] = [
         self.note(slug: "contributing"),
         self.note(slug: "wwdc24-100-meet-x"),
         self.note(slug: "wwdc24-101-whats-new"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(reserved.isEmpty)
   }

   @Test("Year-root note with at least one child session IS in reservedSlugs")
   func yearRootWithSessionsIsReserved() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),           // overview catalog note for 2024
         self.note(slug: "wwdc24-100-meet-x"),// child session → year is "claimed"
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(reserved.contains("wwdc24"))
      // The session slug itself is not reserved (DocCArticlePage renders it).
      #expect(!reserved.contains("wwdc24-100-meet-x"))
   }

   @Test("Year-root note WITHOUT any child session is NOT in reservedSlugs")
   func yearRootAloneIsNotReserved() {
      // The "wwdc24" note exists but no session note shares the same year prefix,
      // so DocCYearListingPage would have nothing to list – it does not own the URL.
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(!reserved.contains("wwdc24"))
   }

   @Test("contributors slug IS in reservedSlugs when a contributors note is present and the feature is on")
   func contributorsNoteIsReserved() {
      let notes: [PageModel] = [
         self.note(slug: "contributors"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: DocCConfig(contributors: true))
      #expect(reserved.contains("contributors"))
   }

   @Test("contributors slug is NOT in reservedSlugs when no contributors note exists")
   func contributorsAbsentMeansNotReserved() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: DocCConfig(contributors: true))
      #expect(!reserved.contains("contributors"))
   }

   @Test("Multiple years: each year with sessions and an overview note is reserved")
   func multipleYearsReserved() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),
         self.note(slug: "wwdc24-100-meet-x"),
         self.note(slug: "wwdc23"),
         self.note(slug: "wwdc23-50-older"),
         self.note(slug: "wwdc22"),  // overview only, no sessions → not claimed
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(reserved.contains("wwdc24"))
      #expect(reserved.contains("wwdc23"))
      #expect(!reserved.contains("wwdc22"))
      // Session slugs are not reserved.
      #expect(!reserved.contains("wwdc24-100-meet-x"))
      #expect(!reserved.contains("wwdc23-50-older"))
   }

   // MARK: - isClaimedYearRoot(slug:in:)

   @Test("isClaimedYearRoot is true for a year slug when that year has session children")
   func claimedYearRootTrueWithSessions() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      #expect(DocCReservedRoutes.isClaimedYearRoot(slug: "wwdc24", in: notes))
   }

   @Test("isClaimedYearRoot is false for a year slug when that year has no session children")
   func claimedYearRootFalseWithoutSessions() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),
      ]
      #expect(!DocCReservedRoutes.isClaimedYearRoot(slug: "wwdc24", in: notes))
   }

   @Test("isClaimedYearRoot is false for a session slug (not a year root)")
   func claimedYearRootFalseForSessionSlug() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      // A session slug is not a year root regardless of siblings.
      #expect(!DocCReservedRoutes.isClaimedYearRoot(slug: "wwdc24-100-meet-x", in: notes))
   }

   @Test("isClaimedYearRoot is false for a loose (non-year) slug")
   func claimedYearRootFalseForLooseSlug() {
      let notes: [PageModel] = [
         self.note(slug: "contributing"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      #expect(!DocCReservedRoutes.isClaimedYearRoot(slug: "contributing", in: notes))
   }

   // MARK: - missingSlug (DocCMissingPage)

   @Test("missingnotes slug IS in reservedSlugs when a missingnotes note is present and the feature is on")
   func missingNoteIsReserved() {
      let notes: [PageModel] = [
         self.note(slug: "missingnotes"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: DocCConfig(missingSessions: true))
      #expect(reserved.contains("missingnotes"))
   }

   @Test("missingnotes slug is NOT in reservedSlugs when no missingnotes note exists")
   func missingNoteAbsentMeansNotReserved() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: DocCConfig(missingSessions: true))
      #expect(!reserved.contains("missingnotes"))
   }

   // MARK: - Contributor profile slugs (DocCContributorPage)

   private func profileNote(slug: String) -> PageModel {
      PageModel(
         title: slug,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/\(slug).md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
   }

   @Test("A generated contributor profile slug IS reserved (no standalone /documentation/<handle>/)")
   func contributorProfileSlugIsReserved() {
      let notes: [PageModel] = [
         self.note(slug: "wwdc24-100-meet-x"),
         self.profileNote(slug: "jeehut"),
         self.profileNote(slug: "dasalexq"),
      ]
      // Profile reservation is unconditional, so it holds even with the contributors feature off.
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(reserved.contains("jeehut"))
      #expect(reserved.contains("dasalexq"))
      // DocCArticlePage therefore renders neither profile as a standalone article.
      let articleNotes = notes.filter { !reserved.contains($0.slug) }
      #expect(!articleNotes.contains { $0.slug == "jeehut" })
      #expect(articleNotes.contains { $0.slug == "wwdc24-100-meet-x" })
   }

   @Test("A bare-handle slug is NOT reserved when the note is not a contributor profile")
   func bareHandleNotReservedWithoutProfileFlag() {
      let notes: [PageModel] = [
         self.note(slug: "jeehut"),  // a regular note that merely happens to slugify to a handle
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: nil)
      #expect(!reserved.contains("jeehut"))
   }

   @Test("DocCArticlePage excludes missingnotes slug from its pages(in:) output")
   func articlePageExcludesMissingnotesSlug() {
      // When a missingnotes catalog note exists, DocCArticlePage must not render it
      // because DocCMissingPage owns that URL.
      let notes: [PageModel] = [
         self.note(slug: "missingnotes"),
         self.note(slug: "wwdc24-100-meet-x"),
      ]
      let reserved = DocCReservedRoutes.reservedSlugs(in: notes, docc: DocCConfig(missingSessions: true))
      let articlePageNotes = notes.filter { !reserved.contains($0.slug) }
      #expect(!articlePageNotes.contains(where: { $0.slug == "missingnotes" }))
      // The session note is still included.
      #expect(articlePageNotes.contains(where: { $0.slug == "wwdc24-100-meet-x" }))
   }

   // MARK: - Feature gating (DocCConfig flags)

   /// A catalog that ships all three special notes, used to isolate the flag behavior.
   private var fullCatalog: [PageModel] {
      [
         self.note(slug: "wwdc24-100-meet-x"),
         self.note(slug: "contributors", title: "Contributors"),
         self.note(slug: "missingnotes", title: "Missing Notes"),
         self.note(slug: "search", title: "Search"),
      ]
   }

   @Test("Default flags: contributors + missingnotes NOT reserved, search IS reserved")
   func defaultFlagsGating() {
      // nil docc ⇒ contributors off, missingSessions off, search on – the clean generic-docs default.
      let reserved = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: nil)
      #expect(!reserved.contains("contributors"))
      #expect(!reserved.contains("missingnotes"))
      #expect(reserved.contains("search"))
   }

   @Test("contributors flag flips the contributors-route reservation on and off")
   func contributorsFlagGates() {
      let off = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(contributors: false))
      #expect(!off.contains("contributors"))
      let on = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(contributors: true))
      #expect(on.contains("contributors"))
   }

   @Test("missingSessions flag flips the missingnotes-route reservation on and off")
   func missingSessionsFlagGates() {
      let off = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(missingSessions: false))
      #expect(!off.contains("missingnotes"))
      let on = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(missingSessions: true))
      #expect(on.contains("missingnotes"))
   }

   @Test("search flag flips the search-route reservation on and off")
   func searchFlagGates() {
      let off = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(search: false))
      #expect(!off.contains("search"))
      let on = DocCReservedRoutes.reservedSlugs(in: self.fullCatalog, docc: DocCConfig(search: true))
      #expect(on.contains("search"))
   }

   @Test("Flags-on catalog reserves all three special routes plus the year root")
   func allFlagsOnReservesEverything() {
      let notes = self.fullCatalog + [self.note(slug: "wwdc24", title: "WWDC24")]
      let reserved = DocCReservedRoutes.reservedSlugs(
         in: notes,
         docc: DocCConfig(contributors: true, missingSessions: true, search: true)
      )
      #expect(reserved.contains("contributors"))
      #expect(reserved.contains("missingnotes"))
      #expect(reserved.contains("search"))
      #expect(reserved.contains("wwdc24"))  // year root stays unconditional
   }
}
