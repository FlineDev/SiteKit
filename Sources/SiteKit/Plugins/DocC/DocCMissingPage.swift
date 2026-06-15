import Foundation

/// Renders a DocC coverage page at `/<urlPrefix>/missingnotes/`.
///
/// Shows, per WWDC year (newest first), how many session notes are fully
/// documented versus still placeholder stubs. A stub is any note where
/// `extensions["doccIsStub"] == true` – a value `DocCLoader` sets when the note
/// has no real body content.
///
/// The page is only emitted when at least one stub session exists anywhere in the
/// catalog. When the catalog is fully documented, no missing-notes page appears
/// (no empty "nothing to see here" orphan page).
///
/// When the catalog ships a `MissingNotes.md` note (slug == "missingnotes"), its
/// title and abstract are adopted for the hero – the same pattern used by
/// `DocCYearListingPage` for year-overview notes and `DocCContributorsPage` for
/// the contributors note. `DocCReservedRoutes` ensures `DocCArticlePage` does not
/// also render that catalog note.
///
/// ## DOM shape
///
/// ```
/// DocCShell wraps the content below in the app shell (appbar + sidebar + scrim + scroll):
/// main.sk-docc-home.sk-docc-missing
///     div.sk-docc-missing-hero.sk-docc-hero.sk-docc-hero--compact.is-compact
///       div.sk-docc-hero-inner
///         div.sk-docc-hero-eyebrow      ("Help wanted")
///         h1.sk-docc-hero-title         ("Missing Sessions")
///         p.sk-docc-hero-sub            (derived subtitle)
///         a.sk-docc-missing-contribute-cta  (optional; only when missingContributeHref is set)
///       div.sk-docc-hero-art > div.sk-docc-hero-prism   (decorative brand prism)
///     section.sk-docc-section#coverage
///       h2 (Coverage by year heading)
///       p  (short lead)
///       div.sk-docc-coverage-wrap       (one row per year, newest first)
///         div.sk-docc-coverage#<yearKey>  (stable per-year anchor, e.g. #wwdc25)
///           div.sk-docc-coverage-head
///             span.sk-docc-coverage-year
///             span.sk-docc-coverage-pct   (percentage number)
///             span.sk-docc-coverage-count ("N of M missing")
///           div.sk-docc-coverage-bar
///             div.sk-docc-coverage-fill   (width = documented%)
///           div.sk-docc-missing-cards     (stub cards for this year)
///             a.sk-docc-missing-card[ --extra] × N   (--extra = beyond the fold)
///               span.sk-docc-sessitem-brace
///               div.sk-docc-missing-card-main
///                 div.sk-docc-missing-card-title
///                 p.sk-docc-missing-card-blurb
///           button.sk-docc-missing-more   (only when the year overflows the fold;
///                                          starts hidden, revealed by docc-missing.js)
/// ```
///
/// The right TOC rail lists "Coverage" plus one `is-sub` jump-link per year (`#<yearKey>`).
public struct DocCMissingPage: Page {
   public init() {}

   // MARK: - Page protocol

   /// Returns one synthetic `PageModel` at slug "missingnotes" when at least one
   /// stub note exists in the catalog. Returns an empty array otherwise.
   ///
   /// When the catalog includes a `MissingNotes.md` note (slug == "missingnotes"),
   /// its title and abstract are used for the hero in place of the hardcoded defaults.
   public func pages(in context: BuildContext) -> [PageModel] {
      let allNotes = Self.doccNotes(in: context)
      let hasAnyStub = allNotes.contains { ($0.extensions["doccIsStub"] as? Bool) == true }
      guard hasAnyStub else { return [] }

      // Adopt the catalog's MissingNotes.md note for title/abstract when present.
      let catalogNote = allNotes.first { $0.slug == DocCReservedRoutes.missingSlug }
      let title = catalogNote?.title ?? "Missing Sessions"
      let summary = catalogNote?.summary ?? "Session notes that still need to be documented."

      return [
         PageModel(
            title: title,
            slug: DocCReservedRoutes.missingSlug,
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("missingnotes.docc"),
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
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: DocCReservedRoutes.missingSlug)
      let ui = context.uiStrings

      let yearStats = Self.coverageByYear(from: allNotes)
      let totalMissing = yearStats.reduce(0) { $0 + $1.missing }
      let yearsWithMissing = yearStats.filter { $0.missing > 0 }.count
      let contributeCTAHref = context.config.docc?.missingContributeHref

      let main = "<main class=\"sk-docc-home sk-docc-missing\">"
         + self.hero(
            title: page.title,
            totalMissing: totalMissing,
            yearsWithMissing: yearsWithMissing,
            ui: ui,
            ctaHTML: self.contributeCTA(href: contributeCTAHref, ui: ui)
         )
         + self.coverageSection(yearStats: yearStats, prefix: prefix, ui: ui)
         + "</main>"

      // Build the on-this-page TOC rail: "Coverage" + one sub-entry per year that has
      // missing sessions. Anchors match ids emitted by coverageSection: #coverage (the
      // containing section); no per-year anchors are emitted currently, so only the
      // top-level #coverage entry is listed. The scroll-spy derives targets from these hrefs.
      let toc = self.buildTOC(yearStats: yearStats, ui: ui)

      let renderer = OutputFileRenderer(context: context)
      let canonical = "\(context.config.baseURL)\(self.missingPath(prefix: prefix))"
      let head = renderer.buildHead(
         title: "\(page.title) · \(context.config.name)",
         description: page.summary ?? "Session notes that still need to be documented.",
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"
         // The missing-page show-more toggle script. Deferred and a no-op on years
         // with no overflow, so linking it unconditionally on this page is safe.
         + "<script defer src=\"\(DocCMissingScriptRenderer.scriptURL)\"></script>"

      return DocCShell.wrap(content: main, sidebar: sidebar, toc: toc, page: page, context: context, head: head)
   }

   /// Writes the page to `<outputDir>/<urlPrefix>/missingnotes/index.html`.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let relative = self.missingPath(prefix: prefix)
         .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Hero

   /// Renders the compact hero for the missing-notes page via the shared `DocCHeroBox`
   /// mechanic. The eyebrow ("Help wanted") comes from UIStrings so it is localizable.
   /// The decorative art panel carries the brand prism – the same key visual as the
   /// home and contributors heroes, so every special-page hero speaks one surface
   /// language. The braces motif stays present on the page through the stub cards'
   /// `sk-docc-sessitem-brace` glyphs below. The contribute CTA (when configured)
   /// lives inside the box, below the subtitle.
   func hero(title: String, totalMissing: Int, yearsWithMissing: Int, ui: UIStrings, ctaHTML: String = "") -> String {
      let eyebrow = ui.string(for: .doccMissingEyebrow)
      let sub: String
      if totalMissing == 0 {
         sub = ui.string(for: .doccMissingHeroComplete)
      } else {
         let template = ui.string(for: .doccMissingHeroSub)
         sub = String(format: template, totalMissing, yearsWithMissing)
      }
      return DocCHeroBox.render(
         leadingClasses: ["sk-docc-missing-hero"],
         topHTML: "<div class=\"sk-docc-hero-eyebrow\">\(Self.escape(eyebrow))</div>",
         titleHTML: "<h1 class=\"sk-docc-hero-title\">\(Self.escape(title))</h1>",
         subtitleHTML: "<p class=\"sk-docc-hero-sub\">\(Self.escape(sub))</p>",
         ctaHTML: ctaHTML,
         artHTML: DocCHeroBox.prismArt()
      )
   }

   // MARK: - Contribute CTA

   /// Renders the "Learn how to contribute" CTA link when `href` is non-nil.
   /// Omitted entirely when `href` is nil so plain docs sites without a contributing
   /// guide produce no dead link.
   func contributeCTA(href: String?, ui: UIStrings) -> String {
      guard let href else { return "" }
      let label = ui.string(for: .doccMissingLearnCTA)
      return "<a class=\"sk-docc-missing-contribute-cta\" href=\"\(Self.escape(href))\">\(Self.escape(label))</a>"
   }

   // MARK: - Coverage section

   /// How many stub cards a year shows inline before the rest fold behind a
   /// "Show more" toggle. Picked so a typical year previews two-to-three grid rows
   /// without turning the page into one long inline scroll (the regression this fixes).
   static let cardsBeforeFold = 8

   /// Renders the "Coverage by year" section: heading, lead, and one coverage row
   /// per year (newest first). Each row shows the year label, the documented %,
   /// the "N of M missing" chip, the progress bar, and the stub cards for that year
   /// (truncated to `cardsBeforeFold`, with the remainder behind a "Show more" toggle).
   func coverageSection(yearStats: [YearCoverage], prefix: String, ui: UIStrings) -> String {
      guard !yearStats.isEmpty else { return "" }
      let heading = ui.string(for: .doccMissingCoverageHeading)
      let lead = ui.string(for: .doccMissingCoverageLead)
      let countFormat = ui.string(for: .doccMissingCountFormat)
      let showMoreFormat = ui.string(for: .doccMissingShowMore)
      let showLessLabel = ui.string(for: .doccMissingShowLess)
      let rows = yearStats.map { stat in
         self.coverageRow(
            stat: stat,
            prefix: prefix,
            countFormat: countFormat,
            showMoreFormat: showMoreFormat,
            showLessLabel: showLessLabel
         )
      }.joined()
      return "<section class=\"sk-docc-section\" id=\"coverage\">"
         + "<h2>\(Self.escape(heading))</h2>"
         + "<p class=\"sk-docc-missing-coverage-lead\">\(Self.escape(lead))</p>"
         + "<div class=\"sk-docc-coverage-wrap\">\(rows)</div>"
         + "</section>"
   }

   private func coverageRow(
      stat: YearCoverage,
      prefix: String,
      countFormat: String,
      showMoreFormat: String,
      showLessLabel: String
   ) -> String {
      let yearLabel = stat.yearKey.uppercased()
      let pct = stat.total > 0 ? (stat.documented * 100 / stat.total) : 100
      // "N of M missing" surfaces both the gap and the year's size so coverage reads
      // at a glance. Positional format → translators may reorder the two numbers.
      let countText = String(format: countFormat, stat.missing, stat.total)

      let head = "<div class=\"sk-docc-coverage-head\">"
         + "<span class=\"sk-docc-coverage-year\">\(Self.escape(yearLabel))</span>"
         + "<span class=\"sk-docc-coverage-pct\">\(pct)%</span>"
         + "<span class=\"sk-docc-coverage-count\">\(Self.escape(countText))</span>"
         + "</div>"

      let bar = "<div class=\"sk-docc-coverage-bar\">"
         + "<div class=\"sk-docc-coverage-fill\" style=\"width:\(pct)%\"></div>"
         + "</div>"

      let stubCards = self.stubCardsBlock(
         stat: stat,
         prefix: prefix,
         showMoreFormat: showMoreFormat,
         showLessLabel: showLessLabel
      )

      // Stable per-year anchor (the year key, e.g. "wwdc25") so the TOC rail and any
      // deep link target this row. Derived from the key, not a position, so it never
      // shifts as coverage changes.
      return "<div class=\"sk-docc-coverage\" id=\"\(Self.escape(stat.yearKey))\">"
         + head
         + bar
         + stubCards
         + "</div>"
   }

   /// Renders a year's stub cards plus, when the year has more than `cardsBeforeFold`
   /// stubs, a "Show more" toggle. Progressive enhancement: every card is rendered
   /// (the overflow ones carry `sk-docc-missing-card--extra`) and the button starts
   /// `hidden`. With no JS all cards stay visible and no dead button shows;
   /// `docc-missing.js` collapses the overflow and reveals the toggle. The toggle's
   /// two labels ride on `data-*` attributes so the script stays locale-agnostic.
   private func stubCardsBlock(
      stat: YearCoverage,
      prefix: String,
      showMoreFormat: String,
      showLessLabel: String
   ) -> String {
      guard !stat.stubs.isEmpty else { return "" }
      let fold = Self.cardsBeforeFold
      let cards = stat.stubs.enumerated().map { index, stub in
         let extra = index >= fold ? " sk-docc-missing-card--extra" : ""
         let href = self.notePath(slug: stub.slug, prefix: prefix)
         let blurb = stub.summary.map { "<p class=\"sk-docc-missing-card-blurb\">\(Self.escape($0))</p>" } ?? ""
         return "<a class=\"sk-docc-missing-card\(extra)\" href=\"\(Self.escape(href))\">"
            + "<span class=\"sk-docc-sessitem-brace\" aria-hidden=\"true\">{ }</span>"
            + "<div class=\"sk-docc-missing-card-main\">"
            + "<div class=\"sk-docc-missing-card-title\">\(Self.escape(stub.title))</div>"
            + blurb
            + "</div>"
            + "<i class=\"sk-docc-sessitem-chev\" aria-hidden=\"true\">›</i>"
            + "</a>"
      }.joined()
      let cardsDiv = "<div class=\"sk-docc-missing-cards\">\(cards)</div>"

      let hiddenCount = stat.stubs.count - fold
      guard hiddenCount > 0 else { return cardsDiv }
      let moreLabel = String(format: showMoreFormat, hiddenCount)
      let button = "<button type=\"button\" class=\"sk-docc-missing-more\" data-docc-missing-more hidden"
         + " aria-expanded=\"false\""
         + " data-docc-missing-label-more=\"\(Self.escape(moreLabel))\""
         + " data-docc-missing-label-less=\"\(Self.escape(showLessLabel))\">"
         + "\(Self.escape(moreLabel))</button>"
      return cardsDiv + button
   }

   // MARK: - TOC rail

   /// Builds the on-this-page TOC aside for the missing-notes page.
   /// Lists a top-level "Coverage" anchor pointing at the `#coverage` section id,
   /// then one `is-sub` entry per year pointing at that year's row id (e.g. `#wwdc25`),
   /// newest-first – matching the ids `coverageRow` emits. `docc-toc.js` reads each
   /// link's `href` to drive scroll-spy and smooth-scroll, so no extra wiring is needed.
   /// Returns nil when there are no year stats to avoid rendering an empty rail.
   func buildTOC(yearStats: [YearCoverage], ui: UIStrings) -> String? {
      guard !yearStats.isEmpty else { return nil }
      let heading = ui.string(for: .doccMissingCoverageHeading)
      let tocTitle = ui.string(for: .doccTocTitle)
      var items: [String] = [
         "<a class=\"sk-docc-toc-item\" href=\"#coverage\">\(Self.escape(heading))</a>"
      ]
      for stat in yearStats {
         let yearLabel = stat.yearKey.uppercased()
         items.append(
            "<a class=\"sk-docc-toc-item is-sub\" href=\"#\(Self.escape(stat.yearKey))\">\(Self.escape(yearLabel))</a>"
         )
      }
      return "<aside class=\"sk-docc-toc\" aria-label=\"\(Self.escape(tocTitle))\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(tocTitle))</div>"
         + "<nav>\(items.joined())</nav>"
         + "</aside>"
   }

   // MARK: - Coverage computation

   /// Per-year coverage statistics: total sessions, documented sessions,
   /// missing (stub) sessions, and the stub `PageModel` list for linking.
   struct YearCoverage {
      let yearKey: String
      let total: Int
      let documented: Int
      let missing: Int
      let stubs: [PageModel]
   }

   /// Builds per-year coverage statistics from all DocC notes, sorted newest year first.
   /// Only notes whose slug matches a WWDC session pattern (i.e. the slug contains a
   /// year key prefix AND is NOT itself the year-root overview note) are counted as
   /// sessions. Year-root overview notes and loose pages are excluded from the tally.
   static func coverageByYear(from notes: [PageModel]) -> [YearCoverage] {
      // Group session notes by year. Exclude year-root overview notes (slug == yearKey).
      var sessionsByYear: [String: [PageModel]] = [:]
      for note in notes {
         guard let key = DocCNavigationTree.yearKey(of: note.slug), note.slug != key else { continue }
         sessionsByYear[key, default: []].append(note)
      }

      return sessionsByYear.keys
         .sorted(by: >)  // newest year first
         .compactMap { key -> YearCoverage? in
            guard let sessions = sessionsByYear[key], !sessions.isEmpty else { return nil }
            let stubs = sessions.filter { ($0.extensions["doccIsStub"] as? Bool) == true }
               .sorted { $0.slug < $1.slug }
            return YearCoverage(
               yearKey: key,
               total: sessions.count,
               documented: sessions.count - stubs.count,
               missing: stubs.count,
               stubs: stubs
            )
         }
   }

   // MARK: - Helpers

   static func doccNotes(in context: BuildContext) -> [PageModel] {
      context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
   }

   func missingPath(prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty ? "/\(DocCReservedRoutes.missingSlug)/" : "/\(clean)/\(DocCReservedRoutes.missingSlug)/"
   }

   func notePath(slug: String, prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty ? "/\(slug)/" : "/\(clean)/\(slug)/"
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
