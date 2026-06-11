import Foundation
import Testing

@testable import SiteKit

@Suite("DocCContributorPage")
struct DocCContributorPageTests {
   private static let docSection = SectionConfig(
      name: "Documentation",
      slug: "documentation",
      contentDirectory: "Documentation.docc",
      urlPrefix: "documentation"
   )

   private func note(
      title: String,
      slug: String,
      summary: String? = nil,
      contributors: [String] = [],
      isStub: Bool = false,
      minutes: Int? = nil
   ) -> PageModel {
      var extensions: [String: any Sendable] = ["doccNote": true]
      if !contributors.isEmpty { extensions["doccContributors"] = contributors }
      if isStub { extensions["doccIsStub"] = true }
      if let minutes { extensions["doccMinutes"] = minutes }
      return PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: summary,
         pageType: .article,
         extensions: extensions
      )
   }

   private func context(notes: [PageModel]) -> BuildContext {
      BuildContext(
         config: SiteConfig(
            name: "My Docs",
            baseURL: "https://example.com",
            description: "A documentation catalog.",
            sections: [Self.docSection],
            // DocCContributorPage only ships when the contributors feature is on, so the embedded
            // sidebar's contributor subtree (gated in DocCSidebarRenderer.make) must be enabled here.
            docc: DocCConfig(contributors: true)
         ),
         themeConfig: nil,
         sections: [ContentSection(config: Self.docSection, pages: notes)],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func profileNote(title: String, slug: String) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/\(slug).md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributorProfile": true]
      )
   }

   // MARK: - PagePathResolving

   @Test("Profile notes resolve to the contributor detail path")
   func pathResolutionRemapsProfileNotes() {
      let profile = self.profileNote(title: "Alice A.", slug: "alice")
      let ctx = context(notes: [
         // Mixed-case handle in the note: matching must be case-insensitive.
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["AliCe"]),
         profile,
      ])
      let resolution = DocCContributorPage().pathResolution(for: profile, context: ctx)
      #expect(resolution == .path("/documentation/contributors/alice/"))
   }

   @Test("Profile notes whose handle never contributed resolve to unpublished")
   func pathResolutionUnpublishedForOrphanProfiles() {
      let profile = self.profileNote(title: "Ghost", slug: "ghost")
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
         profile,
      ])
      let resolution = DocCContributorPage().pathResolution(for: profile, context: ctx)
      #expect(resolution == .unpublished)
   }

   @Test("Regular notes resolve to the router default")
   func pathResolutionDefaultForRegularNotes() {
      let regular = note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"])
      let ctx = context(notes: [regular])
      let resolution = DocCContributorPage().pathResolution(for: regular, context: ctx)
      #expect(resolution == .routerDefault)
   }

   // MARK: - pages(in:)

   @Test("Returns one page per distinct contributor handle")
   func returnsOnePagePerHandle() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice", "bob"]),
         note(title: "Session B", slug: "wwdc24-101-b", contributors: ["carol"]),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      // 3 distinct handles → 3 detail pages
      #expect(pages.count == 3)
      let slugs = Set(pages.map(\.slug))
      #expect(slugs.contains("contributors/alice"))
      #expect(slugs.contains("contributors/bob"))
      #expect(slugs.contains("contributors/carol"))
   }

   @Test("Returns empty array when no notes have contributors")
   func returnsEmptyWhenNoContributors() {
      let ctx = context(notes: [
         note(title: "Stub", slug: "wwdc24-200-stub"),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   @Test("Returns empty array when catalog has no notes at all")
   func returnsEmptyForEmptyCatalog() {
      let ctx = context(notes: [])
      let pages = DocCContributorPage().pages(in: ctx)
      #expect(pages.isEmpty)
   }

   @Test("Lowercases handle in slug but keeps original casing in title and extension")
   func lowercasesHandleInSlugKeepsOriginalCase() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["AliceDoe"]),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      #expect(pages.count == 1)
      let page = pages[0]
      // Slug is lowercased for case-insensitive URL routing.
      #expect(page.slug == "contributors/alicedoe")
      // Title and extension preserve original casing for display.
      #expect(page.title == "@AliceDoe")
      #expect(page.extensions["doccContributorHandle"] as? String == "AliceDoe")
   }

   @Test("Deduplicates the same handle appearing in multiple notes")
   func deduplicatesAcrossNotes() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
         note(title: "Session B", slug: "wwdc24-101-b", contributors: ["alice"]),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      // alice appears in 2 notes but should yield only 1 detail page
      #expect(pages.count == 1)
   }

   // MARK: - outputURL

   @Test("outputURL ends with /<prefix>/contributors/<lowercased-handle>/index.html")
   func outputURLPath() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let url = DocCContributorPage().outputURL(for: page, context: ctx)
      #expect(url.path.hasSuffix("/documentation/contributors/alice/index.html"))
   }

   @Test("outputURL lowercases a mixed-case handle in the URL path")
   func outputURLLowercasesHandle() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["AliceDoe"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let url = DocCContributorPage().outputURL(for: page, context: ctx)
      #expect(url.path.hasSuffix("/documentation/contributors/alicedoe/index.html"))
      #expect(!url.path.contains("AliceDoe"))
   }

   // MARK: - renderHTML

   @Test("Renders DocC layout chrome (layout, sidebar, scrim)")
   func rendersChrome() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-layout"))
      #expect(html.contains("sk-docc-sidebar"))
      #expect(html.contains("sk-docc-scrim"))
   }

   @Test("Renders contributor detail main class")
   func rendersDetailMainClass() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)
      #expect(html.contains("sk-docc-contributor-detail"))
   }

   @Test("GitHub avatar URL uses 160px size and GitHub profile link is present")
   func gitHubAvatarAndProfileURLs() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("https://github.com/alice.png?size=160"))
      #expect(html.contains("href=\"https://github.com/alice\""))
      #expect(html.contains("sk-docc-contrib-profile-avatar"))
      #expect(html.contains("sk-docc-contrib-profile-link--github"))
   }

   @Test("Header falls back to @handle and a note-count line when no profile note exists")
   func heroShowsHandleAndNoteCount() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
         note(title: "Session B", slug: "wwdc24-101-b", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("@alice"))
      #expect(html.contains("2 notes contributed"))
   }

   @Test("Note count sub-line uses singular form for exactly one note")
   func noteCountSingular() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)
      #expect(html.contains("1 note contributed"))
   }

   @Test("Contributions list contains both notes when handle is in 2 notes")
   func contributionsListContainsBothNotes() {
      let ctx = context(notes: [
         note(title: "Session Alpha", slug: "wwdc24-100-alpha", contributors: ["alice"]),
         note(title: "Session Beta", slug: "wwdc24-101-beta", contributors: ["alice", "bob"]),
         note(title: "Session Gamma", slug: "wwdc24-102-gamma", contributors: ["bob"]),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      let alicePage = pages.first { $0.slug == "contributors/alice" }!
      let html = DocCContributorPage().renderHTML(alicePage, context: ctx)

      // Alice's notes should appear; Bob's note that Alice is not in should not.
      #expect(html.contains("Session Alpha"))
      #expect(html.contains("Session Beta"))
      #expect(!html.contains("Session Gamma"))
   }

   @Test("Note rows use sk-docc-sessitem structure with brace and chevron")
   func noteRowsUseSessitemStructure() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("sk-docc-sesslist"))
      #expect(html.contains("sk-docc-sessitem"))
      #expect(html.contains("sk-docc-sessitem-brace"))
      #expect(html.contains("sk-docc-sessitem-chev"))
   }

   @Test("Note row links to the note URL under the prefix")
   func noteRowLinksToNoteURL() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("href=\"/documentation/wwdc24-100-a/\""))
   }

   @Test("HTML-escapes a handle containing special characters in display text")
   func htmlEscapesHandleInDisplayText() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["a&b"]),
      ])
      let pages = DocCContributorPage().pages(in: ctx)
      guard let page = pages.first else {
         // If escaping the handle breaks pages(in:), the test surfaces the issue.
         return
      }
      let html = DocCContributorPage().renderHTML(page, context: ctx)
      // The handle must be HTML-escaped in display text contexts (title, h1, etc.).
      #expect(html.contains("@a&amp;b"))
      // The avatar src and profile href also use the escaped form.
      #expect(html.contains("https://github.com/a&amp;b.png?size=160"))
   }

   @Test("Profile header is left-aligned: no centered hero and no decorative prism")
   func profileHeaderHasNoHeroOrPrism() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)
      // The "komische position" fix: the centered hero + prism are gone.
      #expect(!html.contains("sk-docc-hero-prism"))
      #expect(!html.contains("sk-docc-hero--compact"))
      // Replaced by the left-aligned profile header.
      #expect(html.contains("sk-docc-contrib-profile"))
      #expect(html.contains("sk-docc-contrib-profile-name"))
   }

   // MARK: - Consuming the generated Contributors/<handle>.md profile note

   /// A generated contributor profile note (slug == bare handle) carrying a full name (title),
   /// a bio (abstract), and parsed `## Links` – exactly what `DocCLoader` produces for a file
   /// under a `Contributors/` directory.
   private func profileNote(
      handle: String,
      fullName: String,
      bio: String,
      links: [DocCContributorLink]
   ) -> PageModel {
      var extensions: [String: any Sendable] = [
         "doccNote": true,
         "doccContributorProfile": true,
      ]
      if !links.isEmpty { extensions["doccContributorLinks"] = links }
      return PageModel(
         title: fullName,
         slug: handle.lowercased(),
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/\(handle).md"),
         summary: bio,
         pageType: .article,
         extensions: extensions
      )
   }

   @Test("Detail page consumes the profile note: full name, bio, Blog and X/Twitter links")
   func consumesProfileNote() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["Jeehut"]),
         profileNote(
            handle: "Jeehut",
            fullName: "Cihat Gündüz (1 note)",
            bio: "Spatial-first Indie Developer for Platforms.",
            links: [
               DocCContributorLink(label: "Blog", url: "https://fline.dev"),
               DocCContributorLink(label: "X/Twitter", url: "https://x.com/Jeehut"),
            ]
         ),
      ])
      let page = DocCContributorPage().pages(in: ctx).first { $0.slug == "contributors/jeehut" }!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      // Full name (with umlaut) is the H1, not the bare @handle.
      #expect(html.contains("<h1 class=\"sk-docc-contrib-profile-name\">Cihat Gündüz (1 note)</h1>"))
      #expect(!html.contains("<h1 class=\"sk-docc-contrib-profile-name\">@Jeehut</h1>"))
      // Bio from the abstract.
      #expect(html.contains("Spatial-first Indie Developer for Platforms."))
      // Blog + X/Twitter links from ## Links.
      #expect(html.contains("href=\"https://fline.dev\""))
      #expect(html.contains(">Blog</a>"))
      #expect(html.contains("href=\"https://x.com/Jeehut\""))
      #expect(html.contains(">X/Twitter</a>"))
      // GitHub link is still present.
      #expect(html.contains("href=\"https://github.com/Jeehut\""))
   }

   @Test("Without a profile note the header degrades to @handle and shows the derived count")
   func fallsBackWhenNoProfileNote() {
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice"]),
         note(title: "Session B", slug: "wwdc24-101-b", contributors: ["alice"]),
      ])
      let page = DocCContributorPage().pages(in: ctx).first!
      let html = DocCContributorPage().renderHTML(page, context: ctx)

      #expect(html.contains("<h1 class=\"sk-docc-contrib-profile-name\">@alice</h1>"))
      // No profile note → the derived note-count line is shown so the count is not lost.
      #expect(html.contains("2 notes contributed"))
      // No external Blog/X links to render; only the GitHub link.
      #expect(html.contains("href=\"https://github.com/alice\""))
   }

   @Test("Sidebar marks the active contributor row aria-current=page on the detail page")
   func sidebarMarksActiveContributorRow() {
      // This verifies the sidebar receives the full contributor slug ("contributors/alice")
      // rather than just "contributors", so the individual row gets aria-current="page".
      let ctx = context(notes: [
         note(title: "Session A", slug: "wwdc24-100-a", contributors: ["alice", "bob"]),
      ])
      let alicePage = DocCContributorPage().pages(in: ctx).first { $0.slug == "contributors/alice" }!
      let html = DocCContributorPage().renderHTML(alicePage, context: ctx)
      // The sidebar link to alice's detail page must be marked aria-current="page".
      // Attribute order in the anchor: aria-current comes before href (see DocCSidebarRenderer).
      #expect(html.contains("aria-current=\"page\" href=\"/documentation/contributors/alice/\""))
      // Bob's row must NOT be marked current.
      #expect(!html.contains("aria-current=\"page\" href=\"/documentation/contributors/bob/\""))
   }
}
