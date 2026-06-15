import Foundation

/// Renders a DocC note to a full HTML page.
///
/// Assembles the DocC content zones in order: the gradient header box (breadcrumb,
/// title, abstract, and the meta row with Watch Video button, platform badges, and
/// read time – all inside the shared hero surface), the Community↔AI body switcher
/// or stub empty-state, Written By author block (community mode, non-stub), and the
/// Related Sessions list (session notes only – guides have no session topology).
/// Wraps the result in PageShell so the page inherits every SEO/perf/i18n concern.
/// Selects only the notes that `DocCLoader` produced (marked with the `doccNote`
/// extension); year-root and contributors notes are excluded because those routes
/// are owned by specialized page types.
public struct DocCArticlePage: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      let allNotes = context.sections
         .flatMap(\.pages)
         .filter { ($0.extensions["doccNote"] as? Bool) == true }
      // Exclude notes whose routes are claimed by a specialized page (DocCYearListingPage,
      // DocCContributorsPage). Those pages own the output URL; rendering the same URL here
      // would overwrite the specialized output with a generic prose article.
      let reserved = DocCReservedRoutes.reservedSlugs(in: allNotes, docc: context.config.docc)
      return allNotes.filter { !reserved.contains($0.slug) }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      // DocC brings its own sidebar + content layout (styled by the DocC CSS as a
      // grid) rather than relying on a layout template's nav slot, so the doc tree
      // – not the site's nav items – fills the sidebar. The sidebar renders only
      // the current page's year expanded (active-branch-only DOM).
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      // Build the navigation tree from ALL DocC notes (including the ones reserved by
      // specialized pages), so year-root and contributors links appear in the sidebar
      // even when those routes are owned by DocCYearListingPage / DocCContributorsPage.
      let allNotes = context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: page.slug)

      // Content/guide articles (@PageKind(article)) are never stubs: they have a real body
      // regardless of whether doccIsStub was set. A session note is a stub only when it is not
      // a content article and was explicitly flagged by the loader.
      let isContentArticle = (page.extensions["doccPageKind"] as? String) == "article"
      let isStub = !isContentArticle && (page.extensions["doccIsStub"] as? Bool) == true
      let hasQuickRead = !isStub && page.htmlContent.contains("sk-docc-quickread")

      // Derive the "on this page" rail from the community body's headings and inject stable ids.
      // Then prepend a Quick Read entry and append Written By + Related to build the full TOC.
      let (bodyWithIDs, bodyHeadingsTOC) = self.onThisPageTOC(fromBodyHTML: page.htmlContent, uiStrings: context.uiStrings)

      // Aggregate all notes for the contributor count lookup and related auto-derive.
      let sidebarInfo = DocCSidebarRenderer.make(from: context)

      let article = self.articleContent(
         for: page,
         bodyHTML: bodyWithIDs,
         allNotes: allNotes,
         navTree: tree,
         sidebarInfo: sidebarInfo,
         prefix: prefix,
         context: context
      )

      // Assemble the full TOC rail from static entries + body heading entries. The Related
      // entry only appears when the article actually renders the Related section (session
      // notes only – guides and loose pages suppress it, see articleContent).
      let hasContributors = (page.extensions["doccContributors"] as? [String]).map { !$0.isEmpty } ?? false
      let toc = self.buildFullTOC(
         bodyHeadingsTOC: bodyHeadingsTOC,
         hasQuickRead: hasQuickRead,
         isStub: isStub,
         hasContributors: hasContributors,
         hasRelated: Self.isSessionNote(page),
         context: context
      )

      // Build the head ourselves: PageShell's default head derives an article's
      // canonical from the /blog/ article path, which is wrong for DocC notes that
      // live under the section prefix (/documentation/<slug>/). Build via buildHead
      // with the correct canonical and append the DocC stylesheet link.
      let renderer = OutputFileRenderer(context: context)
      let pagePath = section.map { context.router.pagePath(for: page, in: $0) } ?? "/\(page.slug)/"
      let canonical = "\(context.config.baseURL)\(pagePath)"
      let head = renderer.buildHead(
         title: "\(page.title) – \(context.config.name)",
         description: page.summary ?? page.description,
         canonicalURL: canonical,
         ogType: "article",
         image: page.image,
         imageAlt: page.imageAlt,
         articleDate: page.date,
         articleAuthor: page.author ?? context.config.author,
         hreflang: page.extensionValue("hreflang")
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      return DocCShell.wrap(content: article, sidebar: sidebar, toc: toc, page: page, context: context, head: head)
   }

   /// Routes a note under the catalog section's URL prefix (e.g. `/documentation/<slug>/`),
   /// NOT the default `.article` path (`/blog/`). This MUST agree with the prefix
   /// `DocCCrossReferenceEnricher` resolves `<doc:>` links to (both read the first
   /// declared section): otherwise a note lives at one path while links point at
   /// another and every internal cross-reference dangles.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String
      if let section = context.config.effectiveSections.first {
         path = context.router.pagePath(for: page, in: section)
      } else {
         path = "/\(page.slug)/"
      }
      var relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
      if relative.hasSuffix("/") { relative = String(relative.dropLast()) }
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Article content

   /// The DocC article HTML without the page shell – testable without a full `BuildContext`.
   ///
   /// Emits, in order inside `article.sk-docc-article.sk-docc-col-main`:
   /// gradient header box (breadcrumb, h1, abstract, meta row), variant switcher or stub
   /// empty-state, Written By (community + non-stub), Related Sessions (session notes only).
   func articleContent(
      for page: PageModel,
      bodyHTML: String,
      allNotes: [PageModel],
      navTree: [DocCNavNode],
      sidebarInfo: DocCSidebarRenderer,
      prefix: String,
      context: BuildContext
   ) -> String {
      // Content/guide articles (@PageKind(article)) are never stubs, even when the loader
      // set doccIsStub because the article body was sparse (e.g. abstract-only frontmatter).
      let isContentArticle = (page.extensions["doccPageKind"] as? String) == "article"
      let isStub = !isContentArticle && (page.extensions["doccIsStub"] as? Bool) == true
      let s = context.uiStrings

      var parts: [String] = []

      // Gradient header box: breadcrumb, h1, abstract, and the meta row (Watch Video
      // button + platform badges + read time) all live inside the shared hero surface,
      // visually separating the article head from the body content below.
      // Card style: the header lives inside the capped article column like any other
      // article content. Band style: the header is emitted BEFORE the article element,
      // as a direct child of the page container – only there can it span the TOC grid's
      // full width and bleed to the pane edges; inside the capped column it could not.
      let heroStyle = context.config.docc?.articleHeroStyle ?? .card
      let headerHTML = self.headerBox(for: page, isStub: isStub, prefix: prefix, siteConfig: context.config, uiStrings: s)
      if heroStyle == .card {
         parts.append(headerHTML)
      }

      // Stub: replace body/switch/written-by with the empty-state.
      if isStub {
         parts.append(self.stubEmptyState(for: page, prefix: prefix, uiStrings: s))
      } else {
         // AI variant HTML (pre-rendered) from the .ai.md sibling, when present.
         let aiVariant = page.extensions["doccAIVariant"] as? String
         let switcher = DocCVariantSwitcher()
         let bodySection = switcher.render(
            community: bodyHTML,
            ai: aiVariant,
            slug: page.slug,
            uiStrings: s
         )
         parts.append("<div class=\"sk-article-body\">\(bodySection)</div>")

         // Corrections nudge: a one-line invitation to fix or extend the note, linking to
         // the contributing guide. Session notes only – on guides the nudge is meaningless
         // (and the contributing guide would link to itself). Stubs skip it because their
         // empty-state already carries the contribute call-to-action.
         if Self.isSessionNote(page) {
            parts.append(self.correctionsCTA(prefix: prefix, uiStrings: s))
         }

         // Written By: rendered in community mode only for non-stub notes.
         let writtenByHTML = self.writtenBy(
            for: page,
            sidebarInfo: sidebarInfo,
            prefix: prefix,
            uiStrings: s,
            context: context
         )
         if let wb = writtenByHTML {
            parts.append(wb)
         }
      }

      // Related sessions: rendered for session notes only (stubs included). Guides and
      // other loose pages carry no year key, and the related list derives from session
      // metadata (year/topic/framework), so it would be meaningless there. On a generic
      // docs site every page is a loose page, so the section disappears entirely – correct,
      // because there is no session topology to relate against.
      if Self.isSessionNote(page) {
         let relatedHTML = self.relatedSessions(
            for: page,
            allNotes: allNotes,
            navTree: navTree,
            prefix: prefix,
            uiStrings: s,
            context: context
         )
         parts.append(relatedHTML)
      }

      let article = "<article class=\"sk-docc-article sk-docc-col-main\">\(parts.joined())</article>"
      return heroStyle == .band ? headerHTML + article : article
   }

   /// Simplified overload used by existing tests that do not have a `BuildContext`.
   ///
   /// The h1 is the bare note title, matching the full `renderHTML` path: the session number
   /// lives in the breadcrumb's trailing crumb, not in the h1, so the title appears once. This
   /// overload renders no breadcrumb, so it only exercises the title/abstract/CTA/body chrome.
   /// It always renders the card style (with prism art) – the default the full path uses when
   /// no `articleHero` is configured – so its output matches production card markup.
   func articleContent(for page: PageModel, bodyHTML: String) -> String {
      let abstractHTML: String
      if let abstract = page.summary, !abstract.isEmpty {
         abstractHTML = "<p class=\"sk-docc-abstract\">\(Self.escape(abstract))</p>"
      } else {
         abstractHTML = ""
      }
      let header = DocCHeroBox.render(
         tag: "header",
         leadingClasses: ["sk-docc-header"],
         titleHTML: "<h1 class=\"sk-docc-title\">\(Self.escape(page.title))</h1>",
         subtitleHTML: abstractHTML,
         ctaHTML: self.callToAction(for: page) + self.contributors(for: page),
         artHTML: DocCHeroBox.prismArt()
      )
      let aiVariant = page.extensions["doccAIVariant"] as? String
      let body = DocCVariantSwitcher().render(community: bodyHTML, ai: aiVariant, slug: page.slug)
      return "<article class=\"sk-docc-article sk-docc-col-main\">\(header)<div class=\"sk-article-body\">\(body)</div></article>"
   }

   // MARK: - Breadcrumb

   /// Builds the article breadcrumb: site root › year › session number.
   ///
   /// The trailing crumb is the bare session number (e.g. "286"), so the breadcrumb reads
   /// "WWDCNotes › WWDC25 › 286" and never repeats the page title (which is already the h1).
   /// A note with no session number in its slug (a guide or other article) falls back to the
   /// page title as the trailing crumb, so the breadcrumb is never empty or left with a
   /// dangling separator.
   private func breadcrumb(for page: PageModel, siteConfig: SiteConfig, prefix: String) -> String {
      // Each crumb carries the separator that PRECEDES it: the site root has none, every
      // deeper crumb descends with a chevron (›). One separator style throughout – mixing
      // the chevron with a middle dot read as inconsistent.
      var crumbs: [(separator: String, html: String)] = []

      let siteHref = "/\(prefix)/"
      crumbs.append(("", "<a class=\"sk-docc-bc-item\" href=\"\(siteHref)\">\(Self.escape(siteConfig.name))</a>"))

      // Year crumb: label from doccTitleHeading ("WWDC25 · Session 256" → "WWDC25") or the slug.
      if let yearKey = DocCNavigationTree.yearKey(of: page.slug) {
         let yearLabel: String
         if let heading = page.extensions["doccTitleHeading"] as? String {
            yearLabel = heading.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? heading
         } else {
            yearLabel = yearKey.uppercased()
         }
         let yearHref = "/\(prefix)/\(yearKey)/"
         crumbs.append(("›", "<a class=\"sk-docc-bc-item\" href=\"\(yearHref)\">\(Self.escape(yearLabel))</a>"))
      }

      // Trailing (current) crumb: the session number when the slug carries one, else the
      // page title (guides/articles). Both descend with the same chevron as the year crumb.
      let currentLabel = DocCYearListingPage.sessionID(from: page.slug) ?? page.title
      crumbs.append(("›", "<span class=\"sk-docc-bc-item is-current\">\(Self.escape(currentLabel))</span>"))

      let body = crumbs.map { crumb in
         crumb.separator.isEmpty
            ? crumb.html
            : "<span class=\"sk-docc-bc-sep\" aria-hidden=\"true\">\(crumb.separator)</span>" + crumb.html
      }.joined()

      return "<nav class=\"sk-docc-breadcrumb\" aria-label=\"Breadcrumb\">\(body)</nav>"
   }

   // MARK: - Header box

   /// Renders the article's gradient header box via the shared `DocCHeroBox` mechanic:
   /// breadcrumb on top, then the h1 (the note title), the abstract, and the meta row
   /// (Watch Video CTA + badges + read time) – all inside the box.
   ///
   /// The h1 is the title alone. The session number is not shown here – it lives in the
   /// breadcrumb's trailing crumb (e.g. "WWDC25 › 286"), and the year already appears as a
   /// breadcrumb crumb, so repeating either in the h1 would duplicate the title on the page.
   ///
   /// The box renders in the site's configured hero style: the card carries the decorative
   /// prism art panel (same surface language as the home/contributors heroes); the band has
   /// no art panel – its presence is the full-width color sweep itself.
   private func headerBox(
      for page: PageModel,
      isStub: Bool,
      prefix: String,
      siteConfig: SiteConfig,
      uiStrings: UIStrings
   ) -> String {
      let abstractHTML: String
      if let abstract = page.summary, !abstract.isEmpty {
         abstractHTML = "<p class=\"sk-docc-abstract\">\(Self.escape(abstract))</p>"
      } else {
         abstractHTML = ""
      }
      let style = siteConfig.docc?.articleHeroStyle ?? .card
      return DocCHeroBox.render(
         tag: "header",
         leadingClasses: ["sk-docc-header"],
         style: style,
         topHTML: self.breadcrumb(for: page, siteConfig: siteConfig, prefix: prefix),
         titleHTML: "<h1 class=\"sk-docc-title\">\(Self.escape(page.title))</h1>",
         subtitleHTML: abstractHTML,
         ctaHTML: self.metaRow(for: page, isStub: isStub, uiStrings: uiStrings),
         artHTML: style == .card ? DocCHeroBox.prismArt() : ""
      )
   }

   /// Whether the page is a WWDC session note (year-keyed slug). Loose pages (guides,
   /// generic docs articles) have no year key and no session topology to relate against.
   static func isSessionNote(_ page: PageModel) -> Bool {
      DocCNavigationTree.yearKey(of: page.slug) != nil
   }

   // MARK: - Article meta row

   private func metaRow(for page: PageModel, isStub: Bool, uiStrings s: UIStrings) -> String {
      var parts: [String] = []

      // Watch Video button: shown when a CTA URL is present.
      if let url = page.extensions["doccCTAURL"] as? String, !url.isEmpty {
         let baseLabel = s.string(for: .doccWatchVideo)
         let minutes = page.extensions["doccMinutes"] as? Int
         let fullLabel: String
         if let min = minutes {
            fullLabel = "\(baseLabel) (\(min) min)"
         } else if let ctaLabel = page.extensions["doccCTALabel"] as? String, !ctaLabel.isEmpty {
            fullLabel = ctaLabel
         } else {
            fullLabel = baseLabel
         }
         parts.append(
            "<a class=\"sk-docc-watch\" href=\"\(Self.escape(url))\">"
            + Self.playIcon
            + Self.escape(fullLabel)
            + "</a>"
         )
      }

      // Platform badges from page.tags (set by the brand's enricher, empty by default).
      if !page.tags.isEmpty {
         let badges = page.tags.map { tag in
            "<span class=\"sk-docc-badge\">\(Self.escape(tag))</span>"
         }.joined()
         parts.append("<div class=\"sk-docc-badges\">\(badges)</div>")
      }

      // Read time: omit for stubs (they have no real content to estimate from).
      if !isStub {
         let minutes = page.readTimeMinutes
         let label = "\(minutes) \(s.string(for: .doccReadTime))"
         parts.append("<span class=\"sk-docc-readtime\">\(Self.escape(label))</span>")
      }

      guard !parts.isEmpty else { return "" }
      return "<div class=\"sk-docc-article-meta\">\(parts.joined())</div>"
   }

   // MARK: - Written By

   /// Renders the Written By section for a community, non-stub article.
   ///
   /// Each contributor gets an avatar (from GitHub), their handle as the display
   /// name, a note-count stat derived from the site-wide aggregation, and two
   /// links: their Contributed Notes page and their GitHub profile.
   ///
   /// Avatar: `https://github.com/<handle>.png?size=108` with an inline `onerror`
   /// fallback to `/assets/theme/images/avatar-fallback.svg` (same path as the sidebar),
   /// matching the `DocCSidebarRenderer` contributor avatar behaviour.
   private func writtenBy(
      for page: PageModel,
      sidebarInfo: DocCSidebarRenderer,
      prefix: String,
      uiStrings s: UIStrings,
      context: BuildContext
   ) -> String? {
      guard let handles = page.extensions["doccContributors"] as? [String], !handles.isEmpty else { return nil }

      // Build a quick lookup from the aggregated contributors list.
      let countByHandle = Dictionary(
         sidebarInfo.contributors.map { ($0.handle, $0.noteCount) },
         uniquingKeysWith: { first, _ in first }
      )

      // Avatar fallback: use the same asset path as the sidebar contributor avatars.
      // The onerror handler sets the src to the fallback once and removes itself so it
      // does not fire a second time. Absent when no avatarFallbackPath is configured.
      let fallbackAttr: String
      if let fallbackPath = context.config.docc?.avatarFallbackPath {
         let fallbackURL = Self.escape("/assets/\(fallbackPath)")
         fallbackAttr = " onerror=\"this.onerror=null;this.src='\(fallbackURL)'\" data-avatar-fallback"
      } else {
         fallbackAttr = " data-avatar-fallback"
      }

      let authorCards = handles.map { handle -> String in
         let safe = Self.escape(handle)
         let count = countByHandle[handle] ?? 1
         let notesLabel = count == 1 ? s.string(for: .doccNoteContributed) : s.string(for: .doccNotesContributed)
         let notesStat = "\(count) \(notesLabel)"
         let contributedLabel = s.string(for: .doccContributedNotes)
         let contributedHref = "/\(Self.escape(prefix))/contributors/\(Self.escape(handle.lowercased()))/"
         let githubHref = "https://github.com/\(safe)"

         let avatar = "<img class=\"sk-docc-wb-avatar\" src=\"https://github.com/\(safe).png?size=108\""
            + " alt=\"\(safe)\" width=\"54\" height=\"54\" loading=\"lazy\"\(fallbackAttr)/>"

         let links = "<div class=\"sk-docc-wb-links\">"
            + "<a class=\"sk-docc-wb-link\" href=\"\(contributedHref)\">"
            + Self.notesIcon + Self.escape(contributedLabel)
            + "</a>"
            + "<a class=\"sk-docc-wb-link\" href=\"\(githubHref)\" rel=\"noopener\">"
            + Self.githubIcon + "GitHub"
            + "</a>"
            + "</div>"

         return "<div class=\"sk-docc-writtenby\">"
            + avatar
            + "<div class=\"sk-docc-wb-main\">"
            + "<div class=\"sk-docc-wb-name\">\(safe)</div>"
            + "<div class=\"sk-docc-wb-meta\">\(Self.escape(notesStat))</div>"
            + links
            + "</div>"
            + "</div>"
      }.joined()

      return "<section id=\"writtenby\" class=\"sk-docc-topicgroup\">"
         + "<h2 class=\"sk-docc-topicgroup-title\">\(Self.escape(s.string(for: .doccWrittenBy)))</h2>"
         + authorCards
         + "</section>"
   }

   // MARK: - Related sessions

   /// Renders the Related Sessions list at the bottom of the article.
   ///
   /// The list is sourced from the optional `doccRelated: [slug]` frontmatter
   /// override when present. When absent, the related sessions are auto-derived
   /// from the nav tree: same topic group first, then same framework, then same
   /// year, excluding the current note, preferring non-stubs, capped at 4.
   private func relatedSessions(
      for page: PageModel,
      allNotes: [PageModel],
      navTree: [DocCNavNode],
      prefix: String,
      uiStrings s: UIStrings,
      context: BuildContext
   ) -> String {
      let related = Self.relatedNotes(
         for: page,
         allNotes: allNotes,
         navTree: navTree
      )

      // Heading is always rendered; the list may be empty if there are no notes in the catalog.
      let items = related.map { note -> String in
         let href = "/\(Self.escape(prefix))/\(Self.escape(note.slug))/"
         let framework = note.extensions["doccFramework"] as? String
         let iconHTML = Self.relatedItemIcon(framework: framework, context: context)
         let blurb = note.summary ?? ""
         return "<a class=\"sk-docc-relitem\" href=\"\(href)\">"
            + "<div class=\"sk-docc-relitem-icon\">\(iconHTML)</div>"
            + "<div>"
            + "<div class=\"sk-docc-relitem-title\">\(Self.escape(note.title))</div>"
            + (blurb.isEmpty ? "" : "<p class=\"sk-docc-relitem-blurb\">\(Self.escape(blurb))</p>")
            + "</div>"
            + "</a>"
      }.joined()

      return "<section id=\"related\" class=\"sk-docc-topicgroup\">"
         + "<h2 class=\"sk-docc-topicgroup-title\">\(Self.escape(s.string(for: .doccRelatedSessions)))</h2>"
         + (items.isEmpty ? "" : "<div class=\"sk-docc-related\">\(items)</div>")
         + "</section>"
   }

   // MARK: - Stub empty-state

   private func stubEmptyState(for page: PageModel, prefix: String, uiStrings s: UIStrings) -> String {
      let title = s.string(for: .doccStubEmptyTitle)
      let body = s.string(for: .doccStubEmptyBody)
      let cta = s.string(for: .doccStubEmptyCTA)
      // Link CTA to the contributing guide (the known slug across DocC catalogs).
      let ctaHref = "/\(Self.escape(prefix))/contributing/"
      return "<div id=\"quick-read\" class=\"sk-docc-empty\">"
         + "<div class=\"sk-docc-empty-mark\">✍️</div>"
         + "<h3 class=\"sk-docc-empty-title\">\(Self.escape(title))</h3>"
         + "<p class=\"sk-docc-empty-body\">\(Self.escape(body))</p>"
         + "<a class=\"sk-docc-btn\" href=\"\(ctaHref)\">\(Self.escape(cta))</a>"
         + "</div>"
   }

   // MARK: - Corrections nudge

   /// The one-line corrections invitation at the end of a session note's body. The whole
   /// line is a single link (one clear tap target) to the contributing guide – the same
   /// known slug the stub empty-state CTA uses. Deliberately plain (no box surface): it is
   /// a quiet sign-off line, not a content section.
   private func correctionsCTA(prefix: String, uiStrings s: UIStrings) -> String {
      let href = "/\(Self.escape(prefix))/contributing/"
      return "<p class=\"sk-docc-corrections\">"
         + "<a href=\"\(href)\">\(Self.escape(s.string(for: .doccCorrectionsCTA)))</a>"
         + "</p>"
   }

   // MARK: - Full TOC assembly

   /// Builds the complete "On this page" sidebar rail: Quick Read entry +
   /// body h2/h3 headings + (community, non-stub, contributor-present) Written By + Related Sessions.
   ///
   /// Returns `nil` (no rail) for a stub with fewer than two heading-equivalent
   /// entries, matching the existing behaviour for short notes.
   private func buildFullTOC(
      bodyHeadingsTOC: String?,
      hasQuickRead: Bool,
      isStub: Bool,
      hasContributors: Bool,
      hasRelated: Bool,
      context: BuildContext
   ) -> String? {
      let s = context.uiStrings

      var staticItems: [String] = []

      // Quick Read / stub anchor – always first when the card is rendered.
      // The aside renders as id="quick-read"; the stub empty-state also uses id="quick-read".
      if hasQuickRead || isStub {
         let label = s.string(for: .doccQuickReadTag)
         staticItems.append(
            "<a class=\"sk-docc-toc-item\" href=\"#quick-read\">\(Self.escape(label))</a>"
         )
      }

      // Collect the body heading items out of the bodyHeadingsTOC aside (parse the <a> elements).
      var headingItems: [String] = []
      if let tocHTML = bodyHeadingsTOC {
         // Extract only the <a …> links from the existing TOC; discard the wrapper aside.
         if let navRange = tocHTML.range(of: "<nav>"),
            let navEndRange = tocHTML.range(of: "</nav>", range: navRange.upperBound..<tocHTML.endIndex)
         {
            let navContent = String(tocHTML[navRange.upperBound..<navEndRange.lowerBound])
            // Split on link tags (keep each full <a …>…</a> intact).
            let pattern = #"<a [^>]+>.*?</a>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
               let ns = navContent as NSString
               let matches = regex.matches(in: navContent, range: NSRange(location: 0, length: ns.length))
               headingItems = matches.map { ns.substring(with: $0.range) }
            }
         }
      }

      // Written By appears after the body headings only for community (non-stub) notes that
      // actually have contributors – when writtenBy() returns nil there is no `id="writtenby"`
      // in the DOM, so the TOC anchor would dangle.
      var trailingItems: [String] = []
      if !isStub && hasContributors {
         trailingItems.append(
            "<a class=\"sk-docc-toc-item\" href=\"#writtenby\">\(Self.escape(s.string(for: .doccWrittenBy)))</a>"
         )
      }
      // Related only when the article renders the section – otherwise the anchor would dangle.
      if hasRelated {
         trailingItems.append(
            "<a class=\"sk-docc-toc-item\" href=\"#related\">\(Self.escape(s.string(for: .doccRelatedSessions)))</a>"
         )
      }

      // Deduplicate the assembled list before emitting.
      // Rule 1: drop any item whose href (anchor id) appeared earlier – keep the first occurrence.
      // Rule 2: drop body-scraped heading items whose visible label (lowercased, trimmed) matches a
      //         curated label (Quick Read tag, Written By, Related Sessions) – the curated item wins.
      let curatedLabels: Set<String> = [
         s.string(for: .doccQuickReadTag).lowercased(),
         s.string(for: .doccWrittenBy).lowercased(),
         s.string(for: .doccRelatedSessions).lowercased(),
      ]
      let hrefPattern = #"href="([^"]*)""#
      let labelPattern = #">([^<]*)</a>"#
      func extractHref(_ item: String) -> String? {
         guard let r = try? NSRegularExpression(pattern: hrefPattern),
               let m = r.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
               let range = Range(m.range(at: 1), in: item) else { return nil }
         return String(item[range])
      }
      func extractLabel(_ item: String) -> String? {
         guard let r = try? NSRegularExpression(pattern: labelPattern),
               let m = r.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
               let range = Range(m.range(at: 1), in: item) else { return nil }
         return String(item[range]).trimmingCharacters(in: .whitespaces)
      }

      let curatedHrefs = Set(staticItems.compactMap { extractHref($0) })
      var seenHrefs = Set<String>()
      let allItems = (staticItems + headingItems + trailingItems).filter { item in
         guard let href = extractHref(item) else { return true }
         // Rule 1: duplicate href – keep first occurrence.
         if seenHrefs.contains(href) { return false }
         seenHrefs.insert(href)
         // Rule 2: body-scraped item whose label matches a curated section label – skip when
         // the curated item owns the same href or a curated section with that label already exists.
         let isBodyItem = headingItems.contains(item)
         if isBodyItem, let label = extractLabel(item), curatedLabels.contains(label.lowercased()) {
            return false
         }
         // Rule 3: body-scraped item whose href is already owned by a curated static item – skip.
         if isBodyItem && curatedHrefs.contains(href) { return false }
         return true
      }
      // Suppress the TOC rail when there is nothing meaningful beyond the trailing entries
      // (avoids a rail with only "Related Sessions" on a bare page with no body headings).
      guard allItems.count >= 2 else { return nil }

      let tocTitle = s.string(for: .doccTocTitle)
      return "<aside class=\"sk-docc-toc\" aria-label=\"\(Self.escape(tocTitle))\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(tocTitle))</div>"
         + "<nav>\(allItems.joined())</nav>"
         + "</aside>"
   }

   // MARK: - Related auto-derive

   /// Returns up to 4 related sessions for the given note, sourced from the optional
   /// `doccRelated` frontmatter override (explicit slug list) or auto-derived from the
   /// nav tree (same topic group → same framework → same year; non-stubs preferred;
   /// self excluded).
   static func relatedNotes(
      for page: PageModel,
      allNotes: [PageModel],
      navTree: [DocCNavNode]
   ) -> [PageModel] {
      // Explicit override: doccRelated is a [String] of slugs the author specifies.
      if let explicit = page.extensions["doccRelated"] as? [String], !explicit.isEmpty {
         let bySlug = Dictionary(allNotes.map { ($0.slug, $0) }, uniquingKeysWith: { f, _ in f })
         return explicit.compactMap { bySlug[$0] }.prefix(4).map { $0 }
      }

      return Self.autoRelatedNotes(for: page, allNotes: allNotes, navTree: navTree)
   }

   /// Auto-derives up to 4 related notes using the nav-tree topology.
   ///
   /// Priority:
   ///   1. Other notes in the same topic group (e.g. "Design" or "SwiftUI").
   ///   2. Notes sharing the same framework key.
   ///   3. Any note from the same year.
   /// Within each tier: non-stubs come before stubs; ties broken by slug for determinism.
   private static func autoRelatedNotes(
      for page: PageModel,
      allNotes: [PageModel],
      navTree: [DocCNavNode]
   ) -> [PageModel] {
      let currentSlug = page.slug
      guard let currentYear = DocCNavigationTree.yearKey(of: currentSlug) else { return [] }
      let currentFramework = page.extensions["doccFramework"] as? String

      // Gather same-year notes (excluding self and year-root).
      let sameYearNotes = allNotes.filter { note in
         guard note.slug != currentSlug else { return false }
         guard let y = DocCNavigationTree.yearKey(of: note.slug), y == currentYear else { return false }
         guard note.slug != currentYear else { return false } // exclude year-root overview
         return true
      }

      // Find which topic group the current note belongs to (from the year node's subgroups).
      let yearNode = navTree.first { DocCNavigationTree.yearKey(of: Self.slug(fromURL: $0.url)) == currentYear }
      var currentGroupTitle: String?
      if let yearNode {
         for group in yearNode.topicSubgroups {
            if group.slugs.contains(currentSlug) {
               currentGroupTitle = group.title
               break
            }
         }
      }

      // Build slug→note map for group lookup.
      let bySlug = Dictionary(sameYearNotes.map { ($0.slug, $0) }, uniquingKeysWith: { f, _ in f })

      // Tier 1: same topic group.
      var tier1: [PageModel] = []
      if let groupTitle = currentGroupTitle,
         let group = yearNode?.topicSubgroups.first(where: { $0.title == groupTitle })
      {
         tier1 = group.slugs.compactMap { bySlug[$0] }
      }

      // Tier 2: same framework (exclude already-in-tier-1).
      var tier2: [PageModel] = []
      if let fw = currentFramework, !fw.isEmpty {
         let tier1Slugs = Set(tier1.map(\.slug))
         tier2 = sameYearNotes.filter { note in
            guard !tier1Slugs.contains(note.slug) else { return false }
            return (note.extensions["doccFramework"] as? String) == fw
         }
      }

      // Tier 3: rest of the same year (exclude tiers 1+2).
      let coveredSlugs = Set(tier1.map(\.slug)).union(tier2.map(\.slug))
      let tier3 = sameYearNotes.filter { !coveredSlugs.contains($0.slug) }

      // Within each tier prefer non-stubs, then sort by slug for determinism.
      func sort(_ notes: [PageModel]) -> [PageModel] {
         notes.sorted { lhs, rhs in
            let lStub = (lhs.extensions["doccIsStub"] as? Bool) == true
            let rStub = (rhs.extensions["doccIsStub"] as? Bool) == true
            if lStub != rStub { return !lStub }
            return lhs.slug < rhs.slug
         }
      }

      var result: [PageModel] = []
      for tier in [tier1, tier2, tier3] {
         result += sort(tier)
         if result.count >= 4 { break }
      }
      return Array(result.prefix(4))
   }

   /// Extracts the trailing URL path component as a slug (mirrors `DocCSidebarRenderer.slug(fromURL:)`).
   private static func slug(fromURL url: String) -> String {
      url.split(separator: "/").last.map(String.init) ?? url
   }

   // MARK: - On-this-page TOC (body headings only)

   /// Derives the "on this page" navigation from the body's `h2`/`h3` headings and returns the
   /// body with a stable `id` on each referenced heading – existing ids are reused; missing ones
   /// are slugified from the heading text and injected. Returns `toc == nil` (and the body
   /// untouched) when there are fewer than two headings, so short notes render two-column with
   /// no empty rail.
   ///
   /// The returned TOC aside is an intermediate value: `buildFullTOC` extracts only the `<a>`
   /// link items from it and reconstructs the wrapper. Pass `uiStrings` to get a localized title
   /// in the intermediate aside (used by tests that call this method directly); defaults to `en`.
   func onThisPageTOC(fromBodyHTML body: String, uiStrings: UIStrings = UIStrings(locale: "en")) -> (body: String, toc: String?) {
      let pattern = "<(h2|h3)\\b([^>]*)>(.*?)</\\1>"
      guard let regex = try? NSRegularExpression(
         pattern: pattern,
         options: [.caseInsensitive, .dotMatchesLineSeparators]
      ) else {
         return (body, nil)
      }
      let ns = body as NSString
      let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
      guard matches.count >= 2 else { return (body, nil) }

      var usedSlugs = Set<String>()
      var items: [String] = []
      var rebuilt = ""
      var cursor = 0
      for match in matches {
         let whole = match.range
         let level = ns.substring(with: match.range(at: 1)).lowercased()
         let attrs = ns.substring(with: match.range(at: 2))
         let inner = ns.substring(with: match.range(at: 3))
         let text = Self.stripTags(inner).trimmingCharacters(in: .whitespacesAndNewlines)

         let id: String
         let headingHTML: String
         if let existing = Self.attributeValue("id", in: attrs), !existing.isEmpty {
            id = existing
            usedSlugs.insert(existing)
            headingHTML = ns.substring(with: whole)
         } else {
            id = Self.uniqueSlug(from: text, used: &usedSlugs)
            headingHTML = "<\(level)\(attrs) id=\"\(id)\">\(inner)</\(level)>"
         }

         rebuilt += ns.substring(with: NSRange(location: cursor, length: whole.location - cursor))
         rebuilt += headingHTML
         cursor = whole.location + whole.length

         let subClass = level == "h3" ? " is-sub" : ""
         // `id` is attribute-escaped: generated slugs are alnum+hyphen, but a reused id read
         // from the source HTML could in theory contain a quote or ampersand.
         items.append("<a class=\"sk-docc-toc-item\(subClass)\" href=\"#\(Self.escape(id))\">\(Self.escape(text))</a>")
      }
      rebuilt += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))

      let tocTitle = uiStrings.string(for: .doccTocTitle)
      let toc = "<aside class=\"sk-docc-toc\" aria-label=\"\(Self.escape(tocTitle))\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(tocTitle))</div>"
         + "<nav>\(items.joined())</nav>"
         + "</aside>"
      return (rebuilt, toc)
   }

   /// Strips HTML tags and decodes the basic entities so a heading's text can be slugified
   /// and used as a plain-text TOC label.
   static func stripTags(_ html: String) -> String {
      var result = ""
      var inTag = false
      for ch in html {
         if ch == "<" { inTag = true }
         else if ch == ">" { inTag = false }
         else if !inTag { result.append(ch) }
      }
      return result
         .replacing("&amp;", with: "&")
         .replacing("&lt;", with: "<")
         .replacing("&gt;", with: ">")
         .replacing("&quot;", with: "\"")
         .replacing("&#39;", with: "'")
   }

   /// Reads an attribute value out of a tag's attribute string (e.g. the `id` of `id="foo"`).
   static func attributeValue(_ name: String, in attrs: String) -> String? {
      guard let regex = try? NSRegularExpression(
         pattern: "\\b\(name)\\s*=\\s*[\"']([^\"']*)[\"']",
         options: [.caseInsensitive]
      ) else { return nil }
      let ns = attrs as NSString
      guard let match = regex.firstMatch(in: attrs, range: NSRange(location: 0, length: ns.length)),
         match.numberOfRanges > 1 else { return nil }
      return ns.substring(with: match.range(at: 1))
   }

   /// Slugifies `text`, de-duplicating against `used` with a numeric suffix so repeated headings
   /// get distinct anchor targets.
   static func uniqueSlug(from text: String, used: inout Set<String>) -> String {
      let base = Self.slugify(text)
      let root = base.isEmpty ? "section" : base
      var candidate = root
      var n = 2
      while used.contains(candidate) {
         candidate = "\(root)-\(n)"
         n += 1
      }
      used.insert(candidate)
      return candidate
   }

   /// Lowercases, keeps `[a-z0-9]`, and collapses every other run into a single hyphen.
   static func slugify(_ text: String) -> String {
      var slug = ""
      var pendingDash = false
      for scalar in text.lowercased().unicodeScalars {
         let v = scalar.value
         let isAlnum = (v >= 97 && v <= 122) || (v >= 48 && v <= 57)
         if isAlnum {
            if pendingDash { slug.append("-") }
            slug.unicodeScalars.append(scalar)
            pendingDash = false
         } else if !slug.isEmpty {
            pendingDash = true
         }
      }
      return slug
   }

   // MARK: - Legacy helpers (used by articleContent(for:bodyHTML:))

   private func callToAction(for page: PageModel) -> String {
      guard let url = page.extensions["doccCTAURL"] as? String, !url.isEmpty else { return "" }
      let label = (page.extensions["doccCTALabel"] as? String) ?? "Watch Video"
      return "<a class=\"sk-docc-cta\" href=\"\(Self.escape(url))\">\(Self.escape(label))</a>"
   }

   private func contributors(for page: PageModel) -> String {
      guard let handles = page.extensions["doccContributors"] as? [String], !handles.isEmpty else { return "" }
      let items = handles.map { handle -> String in
         let safe = Self.escape(handle)
         return "<a class=\"sk-docc-contributor\" href=\"https://github.com/\(safe)\">"
            + "<img src=\"https://github.com/\(safe).png?size=48\" alt=\"\(safe)\" width=\"24\" height=\"24\" loading=\"lazy\" />"
            + "<span>\(safe)</span></a>"
      }.joined()
      return "<div class=\"sk-docc-contributors\">\(items)</div>"
   }

   // MARK: - Inline SVGs / icons

   /// Small play triangle for the Watch Video button.
   private static let playIcon =
      "<svg class=\"sk-docc-watch-ic\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"currentColor\" aria-hidden=\"true\"><path d=\"M8 5v14l11-7z\"/></svg>"

   /// Notes / file icon for the Contributed Notes link.
   private static let notesIcon =
      "<svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><path d=\"M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z\"/><polyline points=\"14 2 14 8 20 8\"/></svg>"

   /// GitHub logo icon for the GitHub link.
   private static let githubIcon =
      "<svg viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"currentColor\" aria-hidden=\"true\"><path d=\"M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0 0 22 12.017C22 6.484 17.522 2 12 2z\"/></svg>"

   /// Framework icon for related session items.
   ///
   /// Uses the same chip mechanism as `DocCSessionRow.frameworkIconHTML`: looks up the framework
   /// key in `config.docc.frameworks` and emits a `data-framework` span holding a white glyph.
   /// The tile background (two-color gradient or one-color solid fill) is painted by the generated
   /// `[data-framework]` CSS and the glyph is rendered white by docc.css, so it stays legible in
   /// both light and dark. Falls back to a neutral brace glyph when the framework is unknown or
   /// absent.
   private static func relatedItemIcon(framework: String?, context: BuildContext) -> String {
      let icons = context.config.docc?.frameworks
      guard let key = framework, !key.isEmpty, let icon = icons?[key] else {
         return "<span class=\"sk-docc-relitem-brace\">{}</span>"
      }
      return "<span class=\"sk-docc-relitem-fw-icon\" data-framework=\"\(Self.escape(key))\" aria-hidden=\"true\">"
         + "<i class=\"\(Self.escape(icon.glyph))\" aria-hidden=\"true\"></i>"
         + "</span>"
   }

   // MARK: - HTML helpers

   static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
