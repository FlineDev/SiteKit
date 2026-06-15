import Foundation

/// Renders a DocC year-overview page: a banner image, a title block (eyebrow + h1 + stack
/// subtitle), stats row (notes / sessions / topics counts), and the topic-grouped session
/// list, all inside the shared DocC app-shell with a static TOC rail.
///
/// A year URL (`/<prefix>/wwdc24/`) is owned by exactly one renderer. When the catalog
/// ships a year-overview note (slug equals the year key, e.g. `wwdc24.md`), this renderer
/// still owns the URL and uses the note's title and abstract for the page copy – `DocCArticlePage`
/// excludes those notes via `DocCReservedRoutes`. When no overview note exists, the page
/// uses a synthesized title (the year key uppercased).
///
/// This is generic SiteKit chrome: it carries no WWDCNotes branding. Year-specific data
/// (banner image, stack subtitle, blurb, topic groups) all flow in through `SiteConfig.docc`
/// and the catalog's year-overview note – nothing in this file is catalog-specific.
public struct DocCYearListingPage: Page {
   public init() {}

   // MARK: - Page protocol

   /// One synthetic page per year that has at least one child session note. The slug
   /// and title come from the catalog's overview note for that year when one exists;
   /// otherwise the slug is the year key and the title is its uppercased form.
   public func pages(in context: BuildContext) -> [PageModel] {
      let notes = Self.doccNotes(in: context)

      // Build a map of year key → overview note (slug == year key) for title/abstract lookup.
      var overviewByYear: [String: PageModel] = [:]
      for note in notes {
         guard let key = DocCNavigationTree.yearKey(of: note.slug), note.slug == key else { continue }
         overviewByYear[key] = note
      }

      // Collect all years that have at least one child session note. Only those years
      // are owned by this renderer (DocCReservedRoutes.isClaimedYearRoot agrees).
      var yearKeys: [String] = []
      var seen = Set<String>()
      for note in notes {
         guard let key = DocCNavigationTree.yearKey(of: note.slug), note.slug != key else { continue }
         if seen.insert(key).inserted { yearKeys.append(key) }
      }

      return yearKeys.sorted(by: >).map { key in
         let overviewNote = overviewByYear[key]
         let title = overviewNote?.title ?? key.uppercased()
         let summary = overviewNote?.summary
         return PageModel(
            title: title,
            slug: key,
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("\(key).docc"),
            summary: summary,
            pageType: .staticPage,
            locale: context.config.effectiveDefaultLanguage,
            extensions: ["doccYearListing": true]
         )
      }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let allNotes = Self.doccNotes(in: context)
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: page.slug)

      let yearKey = page.slug
      // The title is the resolved year label (e.g. "WWDC25"); look up brand data with it.
      let yearLabel = page.title
      let sessions = allNotes
         .filter { DocCNavigationTree.yearKey(of: $0.slug) == yearKey && $0.slug != yearKey }
         .sorted { $0.slug < $1.slug }

      guard !sessions.isEmpty else {
         return self.emptyYearPage(page: page, yearLabel: yearLabel, sidebar: sidebar, prefix: prefix, context: context)
      }

      let sessionBySlug: [String: PageModel] = Dictionary(uniqueKeysWithValues: sessions.map { ($0.slug, $0) })
      let overviewNote = allNotes.first { $0.slug == yearKey }
      let topicGroups = overviewNote?.extensions["doccTopicGroups"] as? [DocCTopicGroup]

      // Derive stats: notes = non-stub sessions; sessions = all; topics = group count.
      let noteCount = sessions.filter { ($0.extensions["doccIsStub"] as? Bool) != true }.count
      let sessionCount = sessions.count
      let topicCount = (topicGroups?.filter { !$0.slugs.isEmpty }.count) ?? 0
      let strings = context.uiStrings

      let docc = context.config.docc
      let yearConfig = docc?.years?[yearLabel]

      let bannerHTML = self.yearBannerHTML(yearLabel: yearLabel, yearConfig: yearConfig, docc: docc)
      let titleBlockHTML = self.yearTitleBlock(page: page, yearConfig: yearConfig, strings: strings)
      let introHTML = self.yearIntroSection(
         page: page,
         yearConfig: yearConfig,
         noteCount: noteCount,
         sessionCount: sessionCount,
         topicCount: topicCount,
         strings: strings
      )

      let (groupsHTML, tocGroups) = self.groupedContent(
         topicGroups: topicGroups,
         allSessions: sessions,
         sessionBySlug: sessionBySlug,
         prefix: prefix,
         context: context
      )

      let content = "<div class=\"sk-docc-home sk-docc-year sk-docc-col-main\">"
         + bannerHTML
         + titleBlockHTML
         + introHTML
         + groupsHTML
         + "</div>"

      let toc = tocGroups.isEmpty ? nil : self.tocRail(groups: tocGroups, yearLabel: yearLabel, context: context)

      let renderer = OutputFileRenderer(context: context)
      let canonical = "\(context.config.baseURL)\(self.path(forYear: yearKey, prefix: prefix))"
      let head = renderer.buildHead(
         title: "\(page.title) · \(context.config.name)",
         description: page.summary ?? "All \(context.config.name) session notes for \(page.title).",
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      return DocCShell.wrap(content: content, sidebar: sidebar, toc: toc, page: page, context: context, head: head)
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let relative = self.path(forYear: page.slug, prefix: prefix)
         .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Banner

   /// Renders `div.sk-docc-yearbanner > img` when a key-visual resolves. Resolution order:
   /// explicit `docc.years[label].keyVisual` → convention `/assets/<label>.jpeg` (the catalog
   /// image the teleporter already emits). When neither is available, returns an empty string
   /// so the page skips the banner block entirely.
   ///
   /// The banner width matches the content column (no negative-margin breakout). Height is
   /// capped via CSS (16:9, object-fit cover, rounded) to stay consistent across viewports.
   func yearBannerHTML(yearLabel: String, yearConfig: DocCYearCardConfig?, docc: DocCConfig?) -> String {
      let src: String
      if let explicit = yearConfig?.keyVisual, !explicit.isEmpty {
         src = explicit
      } else {
         // Convention: /assets/<label>.jpeg – matches DocCCatalogImageTeleporter output.
         src = "/assets/\(yearLabel).jpeg"
      }
      // The onerror handler removes the whole banner div when the image fails (404),
      // so a year without a key-visual renders a clean banner-free page rather than
      // showing a broken-image placeholder. Single quotes work inside double-quoted attrs.
      let onerrorJS = "this.parentElement.remove()"
      return "<div class=\"sk-docc-yearbanner\">"
         + "<img src=\"\(Self.escape(src))\" alt=\"\(Self.escape(yearLabel))\""
         + " loading=\"eager\" onerror=\"\(Self.escape(onerrorJS))\"/>"
         + "</div>"
   }

   // MARK: - Title block

   /// Renders the year title block: eyebrow ("Year overview") + h1 (year label) + optional
   /// stack subtitle from `docc.years[label].stack`.
   func yearTitleBlock(page: PageModel, yearConfig: DocCYearCardConfig?, strings: UIStrings) -> String {
      var html = "<div class=\"sk-docc-yeartitle\">"
      html += "<span class=\"sk-docc-hero-eyebrow\">\(Self.escape(strings.string(for: .doccYearEyebrow)))</span>"
      html += "<h1 class=\"sk-docc-yeartitle-h\">\(Self.escape(page.title))</h1>"
      if let stack = yearConfig?.stack, !stack.isEmpty {
         html += "<p class=\"sk-docc-yeartitle-sub\">\(Self.escape(stack))</p>"
      }
      html += "</div>"
      return html
   }

   // MARK: - Intro section (lead + stats)

   /// Renders the intro section: lead paragraph (blurb ?? page.summary) + framework badge
   /// row + stats row. The section is always present when sessions exist; the lead is
   /// omitted if both blurb and summary are nil, the badge row when `apis` is blank.
   /// Lead → badges → stats mirrors the year card's blurb → badges order so the two
   /// surfaces present the year metadata consistently.
   func yearIntroSection(
      page: PageModel,
      yearConfig: DocCYearCardConfig?,
      noteCount: Int,
      sessionCount: Int,
      topicCount: Int,
      strings: UIStrings
   ) -> String {
      var html = "<section class=\"sk-docc-year-intro\">"
      let lead = yearConfig?.blurb ?? page.summary
      if let lead, !lead.isEmpty {
         html += "<p class=\"sk-docc-home-lead\">\(Self.escape(lead))</p>"
      }
      html += DocCAPIBadges.render(yearConfig?.apis)
      html += "<div class=\"sk-docc-yearstats\">"
         + "<span><b>\(noteCount)</b> \(Self.escape(strings.string(for: .doccYearStatsNotes)))</span>"
         + "<span><b>\(sessionCount)</b> \(Self.escape(strings.string(for: .doccYearStatsSessions)))</span>"
         + "<span><b>\(topicCount)</b> \(Self.escape(strings.string(for: .doccYearStatsTopics)))</span>"
         + "</div>"
      html += "</section>"
      return html
   }

   // MARK: - Session rows

   /// Renders sessions grouped by `DocCTopicGroup` entries from the year overview note.
   /// Each group becomes a `<section id=…>` for the TOC rail to anchor to.
   /// Returns both the HTML string and the list of (id, title) pairs for the TOC rail.
   func groupedContent(
      topicGroups: [DocCTopicGroup]?,
      allSessions: [PageModel],
      sessionBySlug: [String: PageModel],
      prefix: String,
      context: BuildContext
   ) -> (html: String, tocGroups: [(id: String, title: String)]) {
      guard let topicGroups, !topicGroups.isEmpty else {
         // No topic groups: render a single flat session list with no TOC groups.
         let rows = allSessions.map { self.sessionItem($0, prefix: prefix, context: context) }.joined()
         return ("<div class=\"sk-docc-sesslist\">\(rows)</div>", [])
      }

      var coveredSlugs = Set<String>()
      var html = ""
      var tocGroups: [(id: String, title: String)] = []

      for group in topicGroups {
         let resolved = group.slugs.compactMap { sessionBySlug[$0] }
         guard !resolved.isEmpty else { continue }
         for note in resolved { coveredSlugs.insert(note.slug) }
         let groupID = Self.groupAnchorID(group.title)
         let rows = resolved.map { self.sessionItem($0, prefix: prefix, context: context) }.joined()
         html += "<section id=\"\(Self.escape(groupID))\" class=\"sk-docc-topicgroup\">"
            + "<h2 class=\"sk-docc-topicgroup-title\">\(Self.escape(group.title))</h2>"
            + "<div class=\"sk-docc-sesslist\">\(rows)</div>"
            + "</section>"
         tocGroups.append((id: groupID, title: group.title))
      }

      // Append any sessions not in any group so none are silently lost.
      let remaining = allSessions.filter { !coveredSlugs.contains($0.slug) }
      if !remaining.isEmpty {
         let moreTitle = context.uiStrings.string(for: .doccMoreSessions)
         let moreID = Self.groupAnchorID(moreTitle)
         let rows = remaining.map { self.sessionItem($0, prefix: prefix, context: context) }.joined()
         html += "<section id=\"\(Self.escape(moreID))\" class=\"sk-docc-topicgroup\">"
            + "<h2 class=\"sk-docc-topicgroup-title\">\(Self.escape(moreTitle))</h2>"
            + "<div class=\"sk-docc-sesslist\">\(rows)</div>"
            + "</section>"
         tocGroups.append((id: moreID, title: moreTitle))
      }

      return (html, tocGroups)
   }

   func sessionItem(_ note: PageModel, prefix: String, context: BuildContext) -> String {
      let isStub = (note.extensions["doccIsStub"] as? Bool) == true

      // "Needs notes" pill appears in the head row (right of title, before duration).
      // The pill label is a compact inline badge; the sidebar tooltip uses doccStubTitle.
      let headExtra = isStub
         ? "<span class=\"sk-docc-stub-pill\">\(Self.escape(context.uiStrings.string(for: .doccStubPillLabel)))</span>"
         : ""

      // Optional kind/platform foot: only emitted when the note carries doccKind or
      // doccPlatforms extensions. Neither is set by the loader today; this renders them
      // automatically if they are added to frontmatter in the future.
      var footExtra = ""
      if let kind = note.extensions["doccKind"] as? String, !kind.isEmpty {
         footExtra += "<span class=\"sk-docc-sessitem-kind\">\(Self.escape(kind))</span>"
      }
      if let platforms = note.extensions["doccPlatforms"] as? [String], !platforms.isEmpty {
         let tags = platforms.map { "<span class=\"sk-docc-sessitem-platform\">\(Self.escape($0))</span>" }.joined()
         footExtra += "<div class=\"sk-docc-sessitem-platforms\">\(tags)</div>"
      }

      // Framework icon as the leading glyph: falls back to a neutral placeholder when no
      // framework or registry entry is found.
      let frameworkKey = note.extensions["doccFramework"] as? String
      return DocCSessionRow.render(
         href: self.notePath(slug: note.slug, prefix: prefix),
         leadingGlyph: DocCSessionRow.frameworkIconHTML(framework: frameworkKey, context: context),
         eyebrow: Self.eyebrow(for: note),
         titleHTML: Self.escape(note.title),
         headExtra: headExtra,
         minutes: note.extensions["doccMinutes"] as? Int,
         blurb: note.summary,
         footExtra: footExtra,
         isStub: isStub
      )
   }

   // MARK: - TOC rail

   /// Renders the static `aside.sk-docc-toc` rail whose items are the rendered topic-group
   /// sections. The title is the year label. Uses the same CSS classes as the article TOC
   /// rail so `docc-toc.js` scroll-spy works without additional JS.
   func tocRail(groups: [(id: String, title: String)], yearLabel: String, context: BuildContext) -> String {
      guard !groups.isEmpty else { return "" }
      let items = groups.map { group -> String in
         "<a class=\"sk-docc-toc-item\" href=\"#\(group.id)\">\(Self.escape(group.title))</a>"
      }.joined()
      return "<aside class=\"sk-docc-toc\" aria-label=\"On this page\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(yearLabel))</div>"
         + "<nav>\(items)</nav>"
         + "</aside>"
   }

   // MARK: - Empty year graceful state

   /// Renders a graceful empty state when the year has no session notes yet. No TOC rail
   /// is emitted for an empty year.
   func emptyYearPage(
      page: PageModel,
      yearLabel: String,
      sidebar: String,
      prefix: String,
      context: BuildContext
   ) -> String {
      let strings = context.uiStrings
      let yearKey = page.slug
      let content = "<div class=\"sk-docc-home sk-docc-year sk-docc-col-main\">"
         + "<div class=\"sk-docc-yeartitle\">"
         + "<span class=\"sk-docc-hero-eyebrow\">\(Self.escape(strings.string(for: .doccYearEyebrow)))</span>"
         + "<h1 class=\"sk-docc-yeartitle-h\">\(Self.escape(page.title))</h1>"
         + "</div>"
         + "<section class=\"sk-docc-year-intro\">"
         + "<p class=\"sk-docc-home-lead\">\(Self.escape(yearLabel)) is in the archive but has no session notes yet.</p>"
         + "</section>"
         + "</div>"

      let renderer = OutputFileRenderer(context: context)
      let canonical = "\(context.config.baseURL)\(self.path(forYear: yearKey, prefix: prefix))"
      let head = renderer.buildHead(
         title: "\(page.title) · \(context.config.name)",
         description: "All \(context.config.name) session notes for \(page.title).",
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      return DocCShell.wrap(content: content, sidebar: sidebar, toc: nil, page: page, context: context, head: head)
   }

   // MARK: - Helpers

   static func doccNotes(in context: BuildContext) -> [PageModel] {
      context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
   }

   /// Eyebrow like "WWDC24 · 10060": the year heading plus the session id parsed
   /// from the slug (`wwdc24-10060-meet-x` → `10060`). Falls back to just the year
   /// heading, or nil when neither is available.
   static func eyebrow(for note: PageModel) -> String? {
      let heading = (note.extensions["doccTitleHeading"] as? String).flatMap { $0.isEmpty ? nil : $0 }
         ?? DocCNavigationTree.yearKey(of: note.slug)?.uppercased()
      let sessionID = Self.sessionID(from: note.slug)
      switch (heading, sessionID) {
      case let (heading?, sessionID?): return "\(heading) · \(sessionID)"
      case let (heading?, nil): return heading
      default: return sessionID
      }
   }

   /// The session id is the slug segment right after the `wwdc<yy>-` prefix
   /// (e.g. `wwdc24-10060-meet-x` → `10060`). Nil when the slug has no id segment.
   static func sessionID(from slug: String) -> String? {
      guard let yearKey = DocCNavigationTree.yearKey(of: slug) else { return nil }
      let rest = slug.dropFirst(yearKey.count)
      guard rest.hasPrefix("-") else { return nil }
      let segment = rest.dropFirst().prefix { $0 != "-" }
      return segment.isEmpty ? nil : String(segment)
   }

   /// Converts a group title to a stable anchor id: lowercase, ASCII alnum and hyphens only,
   /// runs of other characters collapsed to a single hyphen, leading/trailing hyphens stripped.
   static func groupAnchorID(_ title: String) -> String {
      var id = ""
      var pendingDash = false
      for scalar in title.lowercased().unicodeScalars {
         let v = scalar.value
         let isAlnum = (v >= 97 && v <= 122) || (v >= 48 && v <= 57)
         if isAlnum {
            if pendingDash && !id.isEmpty { id.append("-") }
            id.unicodeScalars.append(scalar)
            pendingDash = false
         } else if !id.isEmpty {
            pendingDash = true
         }
      }
      return id
   }

   func path(forYear yearKey: String, prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty ? "/\(yearKey)/" : "/\(clean)/\(yearKey)/"
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
