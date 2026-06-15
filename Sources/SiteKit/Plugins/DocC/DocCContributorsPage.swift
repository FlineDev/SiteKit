import Foundation

/// Renders a DocC contributors list page at `/<urlPrefix>/contributors/`.
///
/// Aggregates GitHub handles from every `doccNote` page's `doccContributors`
/// extension (an array of handle strings that `DocCLoader` populates from the
/// `@Contributors { @GitHubUser("handle") }` DocC directive). The page shows
/// a compact hero with a prism decoration, a three-stat row (contributors,
/// total notes, years covered), and a responsive grid of contributor cards
/// sorted by contribution count (descending), then handle (ascending) for a
/// stable tie-break.
///
/// The page is only emitted when at least one contributor handle exists. An
/// empty catalog (all stubs, no `@Contributors` directives) produces no output
/// so no orphan page appears.
///
/// Role pills and a podium/top-3 ranking are intentionally omitted: no role
/// source exists in the DocC catalog schema, and a flat grid communicates
/// equal standing more accurately than an arbitrary ranking.
///
/// ## DOM shape
///
/// ```
/// DocCShell wraps the content below in the app shell (appbar + sidebar + scrim + scroll):
/// main.sk-docc-home.sk-docc-contributors-page
///     div.sk-docc-hero.sk-docc-hero--compact
///       div.sk-docc-hero-inner
///         div.sk-docc-hero-eyebrow      (eyebrow, "Community")
///         h1.sk-docc-hero-title         ("Contributors")
///         p.sk-docc-hero-sub            (subtitle)
///       div.sk-docc-hero-art > div.sk-docc-hero-prism
///     div.sk-docc-contrib-topbar
///       div.sk-docc-contrib-stats
///         div.sk-docc-stat × 3          (Contributors, Notes written, Years covered)
///           span.sk-docc-stat-num
///           span.sk-docc-stat-label
///       a.sk-docc-contrib-become-cta    (optional; only when contributorsBecomeHref is set)
///     section.sk-docc-contrib-all
///       h2.sk-docc-contrib-all-heading
///       p.sk-docc-contrib-all-lead
///       div.sk-docc-contrib-grid
///         a.sk-docc-contrib-item × N    (link to contributor detail page)
///           div.sk-docc-avatar
///             img                       (github avatar, 40×40, lazy-loaded)
///           div.sk-docc-contrib-meta
///             span.sk-docc-contrib-name ("@handle")
///             span.sk-docc-contrib-sub  ("N notes")
/// ```
public struct DocCContributorsPage: Page {
   public init() {}

   // MARK: - Page protocol

   /// Returns one synthetic `PageModel` at slug "contributors" when at least
   /// one contributor handle is present across all DocC notes. Returns an
   /// empty array otherwise so no empty page is emitted.
   ///
   /// When the catalog includes a `Contributors.md` note (slug == "contributors"), its
   /// title and abstract are used for the hero instead of the hardcoded defaults.
   /// `DocCReservedRoutes` ensures `DocCArticlePage` does not also render that note.
   public func pages(in context: BuildContext) -> [PageModel] {
      let allNotes = Self.doccNotes(in: context)
      let hasAnyContributor = allNotes.contains { note in
         let handles = note.extensions["doccContributors"] as? [String]
         return !(handles ?? []).isEmpty
      }
      guard hasAnyContributor else { return [] }

      // Use the catalog's Contributors.md note for title and abstract when present.
      let catalogNote = allNotes.first { $0.slug == DocCReservedRoutes.contributorsSlug }
      let title = catalogNote?.title ?? "Contributors"
      let summary = catalogNote?.summary ?? "Everyone who contributed notes to \(context.config.name)."

      return [
         PageModel(
            title: title,
            slug: DocCReservedRoutes.contributorsSlug,
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("contributors.docc"),
            summary: summary,
            pageType: .staticPage
         )
      ]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let allNotes = Self.doccNotes(in: context)
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: DocCReservedRoutes.contributorsSlug)
      let ui = context.uiStrings

      let counts = Self.contributorCounts(from: allNotes)
      let notesWithContributors = allNotes.filter { note in
         let handles = note.extensions["doccContributors"] as? [String]
         return !(handles ?? []).isEmpty
      }.count

      // Distinct year count from year keys present in the note slugs.
      let yearsCovered = Self.yearsCovered(from: allNotes)
      let becomeCTAHref = context.config.docc?.contributorsBecomeHref

      let main = "<main class=\"sk-docc-home sk-docc-contributors-page\">"
         + self.hero(title: page.title, ui: ui)
         + self.topbar(
               contributorCount: counts.count,
               noteCount: notesWithContributors,
               yearsCovered: yearsCovered,
               becomeCTAHref: becomeCTAHref,
               ui: ui
            )
         + self.allContributorsSection(counts: counts, prefix: prefix, ui: ui)
         + "</main>"

      let renderer = OutputFileRenderer(context: context)
      let canonical = "\(context.config.baseURL)\(self.contributorsPath(prefix: prefix))"
      let head = renderer.buildHead(
         title: "Contributors · \(context.config.name)",
         description: "Everyone who contributed notes to \(context.config.name).",
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      return DocCShell.wrap(content: main, sidebar: sidebar, page: page, context: context, head: head)
   }

   /// Writes the page to `<outputDir>/<urlPrefix>/contributors/index.html`.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let relative = self.contributorsPath(prefix: prefix)
         .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Hero

   /// Renders the contributors compact hero with eyebrow, title, and subtitle.
   /// Pass `showPrism: false` to suppress the decorative art panel;
   /// `sk-docc-hero--noprism` is added automatically.
   /// Both `sk-docc-hero--compact` (canonical) and `is-compact` (contract alias) are
   /// always emitted so theme CSS can target either.
   func hero(title: String, ui: UIStrings, showPrism: Bool = true) -> String {
      let eyebrow = ui.string(for: .doccContributorsEyebrow)
      let subtitle = ui.string(for: .doccContributorsSubtitle)
      let noprismClass = showPrism ? "" : " sk-docc-hero--noprism"
      return "<div class=\"sk-docc-hero sk-docc-hero--compact is-compact\(noprismClass)\">"
         + "<div class=\"sk-docc-hero-inner\">"
         + "<div class=\"sk-docc-hero-eyebrow\">\(Self.escape(eyebrow))</div>"
         + "<h1 class=\"sk-docc-hero-title\">\(Self.escape(title))</h1>"
         + "<p class=\"sk-docc-hero-sub\">\(Self.escape(subtitle))</p>"
         + "</div>"
         + (showPrism ? "<div class=\"sk-docc-hero-art\" aria-hidden=\"true\"><div class=\"sk-docc-hero-prism\"></div></div>" : "")
         + "</div>"
   }

   // MARK: - Topbar (stats + optional CTA)

   /// Renders the three-stat row (contributors, notes written, years covered) and the
   /// optional "Become a contributor" CTA button. The CTA is omitted when `becomeCTAHref`
   /// is nil so plain docs sites without a contributing guide stay uncluttered.
   func topbar(
      contributorCount: Int,
      noteCount: Int,
      yearsCovered: Int,
      becomeCTAHref: String?,
      ui: UIStrings
   ) -> String {
      let notesLabel = ui.string(for: .doccContributorsStatNotes)
      let yearsLabel = ui.string(for: .doccContributorsStatYears)
      let contributorLabel = contributorCount == 1
         ? ui.string(for: .doccContributorsStatContributor)
         : ui.string(for: .doccContributorsStatContributors)
      let stats = "<div class=\"sk-docc-contrib-stats\">"
         + self.stat(num: contributorCount, label: contributorLabel)
         + self.stat(num: noteCount, label: notesLabel)
         + self.stat(num: yearsCovered, label: yearsLabel)
         + "</div>"

      let cta: String
      if let href = becomeCTAHref {
         let label = ui.string(for: .doccContributorsBecomeCTA)
         cta = "<a class=\"sk-docc-contrib-become-cta\" href=\"\(Self.escape(href))\">\(Self.escape(label))</a>"
      } else {
         cta = ""
      }

      return "<div class=\"sk-docc-contrib-topbar\">\(stats)\(cta)</div>"
   }

   private func stat(num: Int, label: String) -> String {
      "<div class=\"sk-docc-stat\">"
         + "<span class=\"sk-docc-stat-num\">\(num)</span>"
         + "<span class=\"sk-docc-stat-label\">\(Self.escape(label))</span>"
         + "</div>"
   }

   // MARK: - All contributors section

   /// Renders the "All contributors" section heading, lead, and contributor grid.
   func allContributorsSection(counts: [(handle: String, count: Int)], prefix: String, ui: UIStrings) -> String {
      guard !counts.isEmpty else { return "" }
      let heading = ui.string(for: .doccContributorsAllHeading)
      let lead = ui.string(for: .doccContributorsAllLead)
      return "<section class=\"sk-docc-contrib-all\">"
         + "<h2 class=\"sk-docc-contrib-all-heading\">\(Self.escape(heading))</h2>"
         + "<p class=\"sk-docc-contrib-all-lead\">\(Self.escape(lead))</p>"
         + self.contributorGrid(counts: counts, prefix: prefix, ui: ui)
         + "</section>"
   }

   // MARK: - Contributor grid

   func contributorGrid(counts: [(handle: String, count: Int)], prefix: String = "documentation", ui: UIStrings = UIStrings(locale: "en")) -> String {
      guard !counts.isEmpty else { return "" }
      let items = counts.map { entry -> String in
         let noteWord = entry.count == 1
            ? ui.string(for: .doccNoteContributed)
            : ui.string(for: .doccNotesContributed)
         let avatarURL = "https://github.com/\(Self.escape(entry.handle)).png?size=112"
         // Grid cards link to the contributor detail page rather than directly to GitHub;
         // the detail page itself carries the GitHub profile link.
         // Escape the URL so special characters in the handle (e.g. &) are valid HTML.
         let detailURL = Self.escape(self.detailPath(handle: entry.handle, prefix: prefix))
         let avatar = "<div class=\"sk-docc-avatar\">"
            + "<img src=\"\(avatarURL)\" alt=\"\" loading=\"lazy\" width=\"56\" height=\"56\"/>"
            + "</div>"
         let meta = "<div class=\"sk-docc-contrib-meta\">"
            + "<span class=\"sk-docc-contrib-name\">@\(Self.escape(entry.handle))</span>"
            + "<span class=\"sk-docc-contrib-sub\">\(entry.count) \(noteWord)</span>"
            + "</div>"
         return "<a class=\"sk-docc-contrib-item\" href=\"\(detailURL)\">"
            + avatar
            + meta
            + "</a>"
      }.joined()
      return "<div class=\"sk-docc-contrib-grid\">\(items)</div>"
   }

   func detailPath(handle: String, prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let key = handle.lowercased()
      return clean.isEmpty ? "/contributors/\(key)/" : "/\(clean)/contributors/\(key)/"
   }

   // MARK: - Helpers

   /// Returns the count of distinct WWDC year keys present in the note slugs,
   /// used for the "N years covered" stat. Years are inferred from slug prefixes
   /// (e.g. "wwdc25" in "wwdc25-101") so no extra data source is needed.
   static func yearsCovered(from notes: [PageModel]) -> Int {
      var years: Set<String> = []
      for note in notes {
         if let key = DocCNavigationTree.yearKey(of: note.slug) {
            years.insert(key)
         }
      }
      return years.count
   }

   /// Aggregates GitHub handles across all DocC notes, returning an array of
   /// (handle, noteCount) pairs sorted by count descending, then handle ascending.
   /// Handles are deduplicated across notes: appearing in 2 notes → count 2.
   static func contributorCounts(from notes: [PageModel]) -> [(handle: String, count: Int)] {
      var countMap: [String: Int] = [:]
      for note in notes {
         guard let handles = note.extensions["doccContributors"] as? [String] else { continue }
         // Each handle in the array counts as one contribution to this note.
         // Deduplicate per note first so a repeated handle in the same note's
         // @Contributors block does not inflate the count.
         let uniqueHandles = Set(handles)
         for handle in uniqueHandles {
            countMap[handle, default: 0] += 1
         }
      }
      return countMap
         .map { (handle: $0.key, count: $0.value) }
         .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.handle < rhs.handle
         }
   }

   static func doccNotes(in context: BuildContext) -> [PageModel] {
      context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
   }

   func contributorsPath(prefix: String) -> String {
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
