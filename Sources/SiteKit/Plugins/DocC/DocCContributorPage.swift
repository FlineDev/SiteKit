import Foundation

/// Renders one detail page per distinct DocC contributor at
/// `/<urlPrefix>/contributors/<lowercased-handle>/`.
///
/// When `generate-metadata` has written a `Contributors/<handle>.md` profile note, the page
/// **consumes** it: the real full name (its `# Title`), the GitHub bio (its abstract), and its
/// `## Links` (Blog + X/Twitter) all appear in a left-aligned profile header. The note's
/// per-year contribution lists are derived from the actual catalog session notes (richer than
/// the profile's static `@Links`), so the header is the only part fed by the profile note.
/// When no profile note exists for a handle, the header degrades to `@handle` + a derived
/// note-count line + the GitHub link – the contributor system still works on a bare catalog
/// that only carries `@GitHubUser("handle")` directives.
///
/// Below the header: a Contributions intro section (heading + derived lead "Contributed N
/// notes in total. Most active year: YYYY.") and the contributor's notes grouped by year (h3
/// per year + session rows reusing the `sk-docc-sessitem` pattern from `DocCYearListingPage`).
/// A TOC rail lists Contributions and each year as anchor targets.
///
/// The page is emitted for every distinct handle that appears in at least one `doccNote`
/// page's `doccContributors` extension. GitHub handles are case-insensitive; the URL path is
/// lowercased while the display name keeps the original casing as provided by the catalog. The
/// matching profile note is found by its bare-handle slug (lowercased).
///
/// `/contributors/<handle>/` is the one canonical contributor URL: `DocCReservedRoutes`
/// reserves each generated profile note's bare-handle slug so `DocCArticlePage` never also
/// renders a duplicate `/documentation/<handle>/` orphan.
///
/// ## DOM shape
///
/// ```
/// DocCShell wraps the content below in the app shell (appbar + sidebar + scrim + scroll):
/// main.sk-docc-home.sk-docc-contributor-detail
///     div.sk-docc-breadcrumb
///       a (Contributors) › span (handle)
///     header.sk-docc-contrib-profile               (left-aligned, no centered hero / prism)
///       div.sk-docc-contrib-profile-avatar > img   (72×72, GitHub avatar)
///       div.sk-docc-contrib-profile-text
///         h1.sk-docc-contrib-profile-name          (full name from the profile note, else "@handle")
///         p.sk-docc-contrib-profile-bio            (GitHub bio; omitted when absent)
///         div.sk-docc-contrib-profile-links        (Blog, X/Twitter, GitHub)
///     section.sk-docc-section#contributions
///       h2 (Contributions heading)
///       p.sk-docc-contrib-intro-lead (derived lead sentence)
///     section.sk-docc-section#y<year> × M  (one per year, newest first)
///       h3.sk-docc-cyear (year label)
///       div.sk-docc-sesslist
///         a.sk-docc-sessitem × N
/// ```
public struct DocCContributorPage: Page {
   public init() {}

   // MARK: - Page protocol

   /// Returns one synthetic `PageModel` per distinct contributor handle found
   /// across all DocC notes. The slug encodes the lowercased handle so
   /// `outputURL(for:context:)` can derive the URL path without storing extra
   /// state. The original-case handle is preserved in `extensions["doccContributorHandle"]`
   /// for display use in `renderHTML(_:context:)`.
   public func pages(in context: BuildContext) -> [PageModel] {
      let allNotes = Self.doccNotes(in: context)
      // Build a lowercased-handle → original-case-handle mapping and a
      // handle → [notes] mapping in one pass. First-seen casing wins for display.
      var handleDisplay: [String: String] = [:]  // lowercased → original
      var notesByHandle: [String: [PageModel]] = [:]
      for note in allNotes {
         guard let handles = note.extensions["doccContributors"] as? [String] else { continue }
         for handle in Set(handles) {
            let key = handle.lowercased()
            if handleDisplay[key] == nil { handleDisplay[key] = handle }
            notesByHandle[key, default: []].append(note)
         }
      }
      guard !handleDisplay.isEmpty else { return [] }

      return handleDisplay.keys.sorted().map { key in
         let display = handleDisplay[key] ?? key
         return PageModel(
            title: "@\(display)",
            slug: "\(DocCReservedRoutes.contributorsSlug)/\(key)",
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("contributor-\(key).docc"),
            summary: "Notes contributed by @\(display).",
            pageType: .staticPage,
            extensions: ["doccContributorHandle": display]
         )
      }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let allNotes = Self.doccNotes(in: context)
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)

      // Recover the display handle and lowercase key from the page model.
      let display = page.extensions["doccContributorHandle"] as? String ?? page.title
      let handleKey = Self.handleKey(from: page.slug)

      // Consume the generated `Contributors/<handle>.md` profile note when present (matched by
      // its bare-handle slug): its title is the real full name, its abstract the GitHub bio, and
      // its parsed `## Links` the Blog + X/Twitter links. Absent → the header degrades to the
      // handle alone, so a bare catalog with only `@GitHubUser` directives still renders.
      let profile = allNotes.first { note in
         (note.extensions["doccContributorProfile"] as? Bool) == true && note.slug == handleKey
      }
      let fullName = profile?.title
      let bio = profile?.summary
      let links = profile?.extensions["doccContributorLinks"] as? [DocCContributorLink] ?? []

      // Pass the full contributor path so the sidebar highlights the active contributor row,
      // e.g. "contributors/alice" when on /documentation/contributors/alice/.
      let sidebarSlug = "\(DocCReservedRoutes.contributorsSlug)/\(handleKey)"
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: sidebarSlug)
      let ui = context.uiStrings

      // Collect the notes for this contributor, sorted by slug for a stable order.
      let contributorNotes = allNotes.filter { note in
         guard let handles = note.extensions["doccContributors"] as? [String] else { return false }
         return handles.contains { $0.lowercased() == handleKey }
      }.sorted { $0.slug < $1.slug }

      // Group notes by year key, newest year first.
      let byYear = Self.groupByYear(contributorNotes)

      // 3-level breadcrumb: <site home> › Contributors › @handle
      // Uses the same sk-docc-bc-item / is-current + nav.sk-docc-breadcrumb structure as
      // DocCArticlePage so the existing breadcrumb CSS applies without extra rules.
      let homeHref = "/\(prefix)/"
      let siteName = Self.escape(context.config.name)
      let contributorsListPath = Self.escape(self.contributorsListPath(prefix: prefix))
      let contributorsLabel = Self.escape(ui.string(for: .doccContributors))
      let breadcrumbItems: [String] = [
         "<a class=\"sk-docc-bc-item\" href=\"\(homeHref)\">\(siteName)</a>",
         "<a class=\"sk-docc-bc-item\" href=\"\(contributorsListPath)\">\(contributorsLabel)</a>",
         "<span class=\"sk-docc-bc-item is-current\">@\(Self.escape(display))</span>",
      ]
      let breadcrumbSeparated = breadcrumbItems.enumerated().map { idx, item in
         idx == 0 ? item : "<span class=\"sk-docc-bc-sep\" aria-hidden=\"true\">›</span>" + item
      }.joined()
      let breadcrumb = "<nav class=\"sk-docc-breadcrumb\" aria-label=\"Breadcrumb\">\(breadcrumbSeparated)</nav>"

      let main = "<main class=\"sk-docc-home sk-docc-contributor-detail\">"
         + breadcrumb
         + self.profileHeader(
               display: display,
               fullName: fullName,
               bio: bio,
               links: links,
               noteCount: contributorNotes.count,
               ui: ui
            )
         + self.contributionsSection(noteCount: contributorNotes.count, byYear: byYear, prefix: prefix, ui: ui)
         + "</main>"

      // Build the on-this-page TOC rail: "Contributions" + one entry per year group.
      // Anchors must match the ids emitted by contributionsSection: #contributions and
      // #y<yearKey> (e.g. #ywwdc25). The scroll-spy in docc-toc.js derives its targets
      // from these href values, so correct anchor alignment is all it needs.
      let toc = self.buildTOC(byYear: byYear, ui: ui)

      let renderer = OutputFileRenderer(context: context)
      let detailPath = self.detailPath(handleKey: handleKey, prefix: prefix)
      let canonical = "\(context.config.baseURL)\(detailPath)"
      let head = renderer.buildHead(
         title: "@\(display) · \(context.config.name)",
         description: "Notes contributed by @\(display) to \(context.config.name).",
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      return DocCShell.wrap(content: main, sidebar: sidebar, toc: toc, page: page, context: context, head: head)
   }

   /// Writes to `<outputDir>/<prefix>/contributors/<lowercased-handle>/index.html`.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let handleKey = Self.handleKey(from: page.slug)
      let relative = self.detailPath(handleKey: handleKey, prefix: prefix)
         .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Profile header

   /// Renders the left-aligned profile header: avatar as a modest page icon, then the full name
   /// (or `@handle` fallback), the GitHub bio, and a row of links (Blog + X/Twitter from the
   /// profile note, plus the always-present GitHub profile). No centered hero, no decorative
   /// prism – the header reads as part of the left-aligned DocC content, mirroring real-DocC.
   ///
   /// `fullName` is the profile note's title when a `Contributors/<handle>.md` exists. When it
   /// is nil (no profile note), the heading falls back to `@handle` and a derived "N notes
   /// contributed" line is shown so the contribution count is not lost – the profile note's
   /// title already carries the count, so that line is omitted when a profile is present.
   func profileHeader(
      display: String,
      fullName: String?,
      bio: String?,
      links: [DocCContributorLink],
      noteCount: Int,
      ui: UIStrings
   ) -> String {
      let avatarURL = "https://github.com/\(Self.escape(display)).png?size=160"
      let profileURL = "https://github.com/\(Self.escape(display))"

      let avatar = "<div class=\"sk-docc-contrib-profile-avatar\">"
         + "<img src=\"\(avatarURL)\" alt=\"\" width=\"72\" height=\"72\" loading=\"eager\"/>"
         + "</div>"

      let heading = fullName.map { Self.escape($0) } ?? "@\(Self.escape(display))"
      var text = "<h1 class=\"sk-docc-contrib-profile-name\">\(heading)</h1>"

      // Bio from the profile note's abstract; omitted when no profile or an empty bio.
      if let bio, !bio.isEmpty {
         text += "<p class=\"sk-docc-contrib-profile-bio\">\(Self.escape(bio))</p>"
      }

      // Without a profile note the name carries no count, so surface the derived count here.
      if fullName == nil {
         let noteLabel = noteCount == 1
            ? ui.string(for: .doccNoteContributed)
            : ui.string(for: .doccNotesContributed)
         text += "<p class=\"sk-docc-contrib-profile-count\">\(noteCount) \(Self.escape(noteLabel))</p>"
      }

      // Links row: the parsed Blog + X/Twitter (in profile-file order), then the GitHub profile.
      var linkItems: [String] = links.map { link in
         "<a class=\"sk-docc-contrib-profile-link\" href=\"\(Self.escape(link.url))\" rel=\"noopener\">"
            + "\(Self.escape(link.label))</a>"
      }
      let githubLinkLabel = ui.string(for: .doccContributorViewGitHub)
      linkItems.append(
         "<a class=\"sk-docc-contrib-profile-link sk-docc-contrib-profile-link--github\" href=\"\(profileURL)\" rel=\"noopener\">"
            + "\(Self.escape(githubLinkLabel))</a>"
      )
      text += "<div class=\"sk-docc-contrib-profile-links\">\(linkItems.joined())</div>"

      return "<header class=\"sk-docc-contrib-profile\">"
         + avatar
         + "<div class=\"sk-docc-contrib-profile-text\">\(text)</div>"
         + "</header>"
   }

   // MARK: - Contributions section

   /// Renders the Contributions heading + derived intro lead + per-year grouped note lists.
   /// The intro lead is "Contributed N session notes in total. Most active year: YYYY."
   /// where both numbers are derived from the contributor's actual notes.
   func contributionsSection(
      noteCount: Int,
      byYear: [(yearKey: String, notes: [PageModel])],
      prefix: String,
      ui: UIStrings
   ) -> String {
      let heading = ui.string(for: .doccContributorContributionsHeading)
      // Derive the most-active year: the year key with the most notes, tie-broken by newest year.
      let mostActiveYear = byYear.max(by: { lhs, rhs in
         if lhs.notes.count != rhs.notes.count { return lhs.notes.count < rhs.notes.count }
         return lhs.yearKey < rhs.yearKey  // newer key string sorts higher (e.g. wwdc25 > wwdc24)
      })?.yearKey.uppercased() ?? ""

      let leadFormat = ui.string(for: .doccContributorContributionsLead)
      // The UIString format is "%lld session notes in total. Most active year: %@."
      // When noteCount is zero (no notes matched this handle) mostActiveYear would be an
      // empty string, producing a broken "Most active year: ." sentence. Omit that entire
      // sentence and render only the note count so the page degrades gracefully.
      let lead: String
      if noteCount == 0 || mostActiveYear.isEmpty {
         lead = "\(noteCount) \(noteCount == 1 ? ui.string(for: .doccNoteContributed) : ui.string(for: .doccNotesContributed))"
      } else {
         lead = String(format: leadFormat, noteCount, mostActiveYear)
      }

      var html = "<section class=\"sk-docc-section\" id=\"contributions\">"
         + "<h2>\(Self.escape(heading))</h2>"
         + "<p class=\"sk-docc-contrib-intro-lead\">\(Self.escape(lead))</p>"
         + "</section>"

      for group in byYear {
         let yearLabel = group.yearKey.uppercased()
         let anchorID = "y\(group.yearKey)"
         let rows = group.notes.map { self.sessionItem($0, prefix: prefix) }.joined()
         html += "<section class=\"sk-docc-section\" id=\"\(Self.escape(anchorID))\">"
            + "<h3 class=\"sk-docc-cyear\">\(Self.escape(yearLabel))</h3>"
            + "<div class=\"sk-docc-sesslist\">\(rows)</div>"
            + "</section>"
      }

      return html
   }

   // MARK: - Note list helpers

   /// Reuses the shared `sk-docc-sessitem` row (`DocCSessionRow`) with the mono brace as
   /// the leading glyph and a "STUB" pill in the foot for placeholder sessions.
   func sessionItem(_ note: PageModel, prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let href = clean.isEmpty ? "/\(note.slug)/" : "/\(clean)/\(note.slug)/"
      let isStub = (note.extensions["doccIsStub"] as? Bool) == true
      return DocCSessionRow.render(
         href: href,
         leadingGlyph: DocCSessionRow.braceGlyph,
         eyebrow: DocCYearListingPage.eyebrow(for: note),
         titleHTML: Self.escape(note.title),
         minutes: note.extensions["doccMinutes"] as? Int,
         blurb: note.summary,
         footExtra: isStub ? "<span class=\"sk-docc-stub-pill\">STUB</span>" : "",
         isStub: isStub
      )
   }

   // MARK: - TOC rail

   /// Builds the on-this-page TOC aside for a contributor detail page.
   /// Lists a "Contributions" entry pointing at `#contributions`, followed by
   /// one sub-entry per year group pointing at `#y<yearKey>` (e.g. `#ywwdc25`).
   /// Returns nil when there are no year groups so a page with zero notes gets no
   /// empty rail. The scroll-spy in `docc-toc.js` reads the `href` attribute of
   /// each TOC link and activates the matching section during scroll.
   func buildTOC(byYear: [(yearKey: String, notes: [PageModel])], ui: UIStrings) -> String? {
      guard !byYear.isEmpty else { return nil }
      let heading = ui.string(for: .doccContributorContributionsHeading)
      var items: [String] = []
      items.append(
         "<a class=\"sk-docc-toc-item\" href=\"#contributions\">\(Self.escape(heading))</a>"
      )
      for group in byYear {
         let yearLabel = group.yearKey.uppercased()
         let anchorID = "y\(group.yearKey)"
         items.append(
            "<a class=\"sk-docc-toc-item is-sub\" href=\"#\(Self.escape(anchorID))\">\(Self.escape(yearLabel))</a>"
         )
      }
      let tocTitle = ui.string(for: .doccTocTitle)
      return "<aside class=\"sk-docc-toc\" aria-label=\"\(Self.escape(tocTitle))\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(tocTitle))</div>"
         + "<nav>\(items.joined())</nav>"
         + "</aside>"
   }

   // MARK: - Helpers

   static func doccNotes(in context: BuildContext) -> [PageModel] {
      context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
   }

   /// Groups a contributor's notes by year key, newest year first.
   /// Notes without a detectable year key fall into a fallback group keyed "".
   static func groupByYear(_ notes: [PageModel]) -> [(yearKey: String, notes: [PageModel])] {
      var groups: [String: [PageModel]] = [:]
      for note in notes {
         let key = DocCNavigationTree.yearKey(of: note.slug) ?? ""
         groups[key, default: []].append(note)
      }
      // Sort groups newest-year-first (string-descending works for "wwdc25" > "wwdc24").
      return groups.keys
         .sorted(by: >)
         .compactMap { key -> (yearKey: String, notes: [PageModel])? in
            guard let group = groups[key], !group.isEmpty else { return nil }
            return (yearKey: key, notes: group.sorted { $0.slug < $1.slug })
         }
   }

   /// Extracts the lowercased handle from a page slug of the form
   /// `contributors/<lowercased-handle>`.
   static func handleKey(from slug: String) -> String {
      let prefix = "\(DocCReservedRoutes.contributorsSlug)/"
      guard slug.hasPrefix(prefix) else { return slug.lowercased() }
      return String(slug.dropFirst(prefix.count))
   }

   func detailPath(handleKey: String, prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty
         ? "/contributors/\(handleKey)/"
         : "/\(clean)/contributors/\(handleKey)/"
   }

   func contributorsListPath(prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty ? "/contributors/" : "/\(clean)/contributors/"
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}

// MARK: - PagePathResolving

extension DocCContributorPage: PagePathResolving {
   /// Resolves the final site path of a contributor profile note. This renderer consumes
   /// the note's content (name, bio, links) and re-homes it at
   /// `/<prefix>/contributors/<handle>/`, so the router-derived `/<prefix>/<handle>/`
   /// points at a URL nothing writes (`DocCReservedRoutes` keeps `DocCArticlePage` away
   /// from it). A profile whose handle never contributed a note gets no detail page at
   /// all and must not be listed anywhere. Non-profile pages stay on the router default.
   public func pathResolution(for page: PageModel, context: BuildContext) -> PagePathResolution {
      guard (page.extensions["doccContributorProfile"] as? Bool) == true else { return .routerDefault }

      let handleKey = Self.handleKey(from: page.slug)
      let hasContributions = Self.doccNotes(in: context).contains { note in
         guard let handles = note.extensions["doccContributors"] as? [String] else { return false }
         return handles.contains { $0.lowercased() == handleKey }
      }
      guard hasContributions else { return .unpublished }

      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      return .path(self.detailPath(handleKey: handleKey, prefix: prefix))
   }
}
