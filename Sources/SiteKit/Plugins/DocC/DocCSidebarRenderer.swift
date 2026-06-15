import Foundation

/// Renders the DocC sidebar navigation tree to HTML for a given page.
///
/// Key constraint (from the spec): **active-branch-only DOM**. Only the year of
/// the current page expands its session list into the DOM; every other year is a
/// bare link. This keeps each page's sidebar at ~one year of sessions instead of
/// dumping all ~2183 nodes onto every page. It is also fully no-JS: a collapsed
/// year is a link to that year's overview page, which then renders expanded – so
/// navigation works without any client-side toggle. The current page is marked
/// with `aria-current="page"`.
///
/// Layout: the rendered `<nav>` carries a title row (`sk-docc-sidebar-head`), the
/// sidebar search box, the navigation list, a pinned filter box at the bottom,
/// and – on mobile, where the sidebar becomes an off-canvas drawer – a close
/// affordance whose toggle JS lives in `docc-sidebar.js`. Loose (non-year) pages
/// are grouped under a muted small-caps "Articles" eyebrow (`sk-docc-nav-section`)
/// so they read as a distinct section rather than dangling after the year tree.
///
/// B3 additions: framework-icon glyphs (FontAwesome, colored from config registry),
/// year glyph images (from @PageImage icon), a collapsible Contributors subtree
/// (top-N by note count), topic subgroups under the active year, stub dimming, and
/// a pinned filter box at the bottom.
struct DocCSidebarRenderer {
   /// The heading shown above the navigation tree (e.g. "Documentation").
   var title: String
   /// The eyebrow shown above the loose (non-year) pages group.
   var looseSectionTitle: String
   /// The placeholder text for the pinned filter box.
   var filterPlaceholder: String
   /// Registry of framework icons, keyed by framework slug. Nil means no glyphs.
   var frameworkIcons: [String: DocCFrameworkIcon]?
   /// Registry mapping a loose guide page's slug → a Font Awesome glyph class (e.g.
   /// `"fa-solid fa-pen-to-square"`). A loose page whose slug is absent here – or any loose
   /// page when this is `nil` – renders `Self.defaultGuideGlyph`, never the empty placeholder.
   /// Inlined by `FontAwesomeInliner` (Phase 6), like the framework + Contributors glyphs.
   var guideIcons: [String: String]?
   /// Maximum contributors shown in the collapsible Contributors subtree. `nil` or `0`
   /// means *no cap* – show every contributor (the default). The collapsed disclosure keeps
   /// the full list out of the way and the bottom filter narrows it, so nesting all of them
   /// adds no clutter. A positive value caps the list (e.g. a site can still pass `14`).
   var contributorsLimit: Int?
   /// Optional Font Awesome class for the Contributors top-item glyph (e.g. `"fa-solid fa-user-group"`).
   /// When `nil`, a `fa-solid fa-users` icon on a gradient tile is rendered – never the empty
   /// placeholder circle. Inlined by `FontAwesomeInliner` (Phase 6), like session framework icons.
   var contributorsGlyph: String?
   /// Asset path for avatar fallback image, e.g. "avatar-fallback.svg".
   var avatarFallbackPath: String?
   /// Aggregated contributors list (handle + noteCount) for the subtree.
   var contributors: [(handle: String, noteCount: Int)]
   /// URL prefix for the documentation section (e.g. "documentation"). Used to build
   /// correct contributor detail page hrefs: `/<urlPrefix>/contributors/<handle>/`.
   var urlPrefix: String
   /// Label for the Contributors subtree group header. Localised via `doccContributors`.
   var contributorsLabel: String
   /// Tooltip for stub session rows. Localised via `doccStubTitle`.
   var stubTitle: String

   /// The fallback glyph for any loose (guide) item without a configured icon, so a guide is
   /// never an empty placeholder – even on a docs site with no `guideIcons` config. A generic
   /// "document" glyph that reads sensibly for any kind of article/guide.
   static let defaultGuideGlyph = "fa-solid fa-file-lines"

   init(
      title: String = "Documentation",
      looseSectionTitle: String = "Articles",
      filterPlaceholder: String = "Filter sessions & years",
      frameworkIcons: [String: DocCFrameworkIcon]? = nil,
      guideIcons: [String: String]? = nil,
      contributorsLimit: Int? = nil,
      contributorsGlyph: String? = nil,
      avatarFallbackPath: String? = nil,
      contributors: [(handle: String, noteCount: Int)] = [],
      urlPrefix: String = "documentation",
      contributorsLabel: String = "Contributors",
      stubTitle: String = "No notes yet"
   ) {
      self.title = title
      self.looseSectionTitle = looseSectionTitle
      self.filterPlaceholder = filterPlaceholder
      self.frameworkIcons = frameworkIcons
      self.guideIcons = guideIcons
      self.contributorsLimit = contributorsLimit
      self.contributorsGlyph = contributorsGlyph
      self.avatarFallbackPath = avatarFallbackPath
      self.contributors = contributors
      self.urlPrefix = urlPrefix
      self.contributorsLabel = contributorsLabel
      self.stubTitle = stubTitle
   }

   func render(tree: [DocCNavNode], currentSlug: String) -> String {
      let activeYear = DocCNavigationTree.yearKey(of: currentSlug)

      // Every top item (Contributors + each year) shares one structure and lives in one
      // `<ul>`, so the accordion JS and the filter can select ".sk-docc-nav-top" uniformly.
      var topItems: [String] = []
      var looseItems: [String] = []
      var groupSections: [(title: String, items: [String])] = []

      // Contributors is the first top item, shown only when there are contributors.
      if !self.contributors.isEmpty {
         topItems.append(self.contributorsItem(currentSlug: currentSlug))
      }

      for node in tree {
         // Curated loose-page group (e.g. "Guides"): a labelled section of flat leaves, built by
         // DocCNavigationTree from a `## Topics` `### Heading`. Rendered as its own nav section
         // rather than dumped into the catch-all Articles list.
         if node.isGroup {
            let items = node.children.map { self.looseItem($0, currentSlug: currentSlug) }
            if !items.isEmpty {
               groupSections.append((title: node.title, items: items))
            }
            continue
         }

         let nodeSlug = Self.slug(fromURL: node.url)
         let isYear = !node.children.isEmpty || DocCNavigationTree.yearKey(of: nodeSlug) == nodeSlug
         if isYear {
            topItems.append(self.yearItem(node, activeYear: activeYear, currentSlug: currentSlug))
            continue
         }
         // Loose-node partition: the contributor index + its detail pages never land in
         // the flat Articles list. The index is already the Contributors top-item link;
         // each `contributors/<handle>` detail page is nested under that disclosure (built
         // from the aggregated `contributors` list, which is a superset). Everything else
         // (Contributing, Missing Sessions, the catalog index, …) stays in Articles.
         let fullSlug = self.pageSlug(fromURL: node.url)
         if fullSlug == "contributors" || fullSlug.hasPrefix("contributors/") {
            continue
         }
         looseItems.append(self.looseItem(node, currentSlug: currentSlug))
      }

      var listParts: [String] = []

      if !topItems.isEmpty {
         listParts.append("<ul class=\"sk-docc-nav\">\(topItems.joined())</ul>")
      }
      // Curated groups render as their own labelled sections, ahead of the catch-all Articles
      // section, so a "Guides" group reads as intentional curation rather than leftover articles.
      for group in groupSections {
         listParts.append("<p class=\"sk-docc-nav-section\">\(Self.escape(group.title))</p>")
         listParts.append("<ul class=\"sk-docc-nav sk-docc-nav-loose\">\(group.items.joined())</ul>")
      }
      if !looseItems.isEmpty {
         listParts.append("<p class=\"sk-docc-nav-section\">\(Self.escape(self.looseSectionTitle))</p>")
         listParts.append("<ul class=\"sk-docc-nav sk-docc-nav-loose\">\(looseItems.joined())</ul>")
      }

      // The sidebar head keeps only the mobile close affordance. The nav's accessible
      // name lives on the `aria-label` below, not as a visible heading – a plain docs
      // sidebar needs no "Documentation" title row above its own tree. On desktop the
      // close button is hidden, so the head collapses to nothing.
      let head = "<div class=\"sk-docc-sidebar-head\">"
         + "<button type=\"button\" class=\"sk-docc-sidebar-close\" data-docc-sidebar-close aria-label=\"Close navigation\">"
         + Self.closeIcon
         + "</button></div>"

      // Full-text search lives in one global place – the appbar ⌘K overlay (see
      // DocCShell) – so the sidebar carries no search box of its own. The pinned
      // bottom filter box stays: it live-narrows the visible tree, a distinct
      // affordance from search that matches the reference layout.
      let filterBox = self.filterBoxHTML()
      // Hidden clone source for the lazy-hydrate + cross-year-filter JS: one framework-icon span per
      // distinct framework anywhere in the tree (all years), so a row hydrated for a non-active year
      // always has a same-framework icon to clone. Purely additive – appended after the filter box so
      // the active-branch markup above is byte-identical to before. See `iconLegendHTML`.
      let iconLegend = self.iconLegendHTML(tree: tree)
      // The stub tooltip rides on the nav root so the lazy-hydrate JS (docc-sidebar.js) can stamp
      // the same localized `title` on hydrated stub rows that the server stamps on rendered ones.
      return "<nav id=\"sk-docc-sidebar\" class=\"sk-docc-sidebar\" aria-label=\"\(Self.escape(self.title))\""
         + " data-docc-stub-title=\"\(Self.escape(self.stubTitle))\">"
         + head
         + "<div class=\"sk-docc-nav-scroll\">\(listParts.joined())</div>"
         + filterBox
         + iconLegend
         + "</nav>"
   }

   // MARK: - Contributors subtree

   /// Renders the collapsible Contributors top item: the same `[twist][glyph][link]` row as
   /// a year, plus a nested subtree of contributor detail rows. The subtree is built from the
   /// aggregated `contributors` list (a superset of the synthetic detail pages), so it is
   /// complete whether or not those pages also leaked into the nav tree.
   private func contributorsItem(currentSlug: String) -> String {
      // Open whenever the reader is inside the contributors section – the overview page
      // or any contributor detail page – and collapsed everywhere else.
      let isContributorsActive = currentSlug == "contributors" || currentSlug.hasPrefix("contributors/")

      // No cap by default (show every contributor); a positive limit still caps the list.
      let shown: ArraySlice<(handle: String, noteCount: Int)>
      if let limit = self.contributorsLimit, limit > 0 {
         shown = self.contributors.prefix(limit)
      } else {
         shown = self.contributors[...]
      }

      var rows: [String] = []
      for contrib in shown {
         let handle = contrib.handle
         let count = contrib.noteCount
         // Avatar is a 20px photo, so request a 40px source for retina sharpness.
         let avatarSrc = "https://github.com/\(Self.escape(handle)).png?size=40"
         let fallbackAttr: String
         if let fallback = self.avatarFallbackPath {
            let fallbackURL = Self.escape("/assets/\(fallback)")
            // The onerror handler avoids a separate JS dependency for avatar fallback; it
            // sets the src to the fallback asset and removes itself so it does not fire a
            // second time. Caveat: inline event handlers are blocked by a strict
            // `script-src` CSP – in a hardened deployment replace this with a small
            // external script that attaches the handler after DOMContentLoaded.
            fallbackAttr = " onerror=\"this.onerror=null;this.src='\(fallbackURL)'\" data-avatar-fallback"
         } else {
            fallbackAttr = " data-avatar-fallback"
         }
         let avatarImg = "<img class=\"sk-docc-nav-avatar\" src=\"\(avatarSrc)\" alt=\"\(Self.escape(handle))\" loading=\"lazy\" width=\"20\" height=\"20\"\(fallbackAttr)/>"
         // Contributor detail page slug: `contributors/<lowercased-handle>` (matches
         // DocCContributorPage.swift slug = "\(DocCReservedRoutes.contributorsSlug)/\(key)").
         let lowerHandle = handle.lowercased()
         let href = "/\(self.urlPrefix)/contributors/\(Self.escape(lowerHandle))/"
         let isActive = currentSlug == "contributors/\(lowerHandle)"
         let activePart = isActive ? " aria-current=\"page\"" : ""
         rows.append(
            "<li class=\"sk-docc-nav-session\">"
               + "<a class=\"sk-docc-nav-link\"\(activePart) href=\"\(href)\">"
               + avatarImg
               + "<span class=\"sk-docc-nav-text\">\(Self.escape(handle)) <span class=\"sk-docc-nav-count\">(\(count))</span></span>"
               + "</a></li>"
         )
      }

      let linkExtraClass = isContributorsActive ? "sk-docc-nav-year sk-docc-nav-contrib-active" : "sk-docc-nav-year"
      return self.topItemRow(
         branchKey: "contrib",
         subtreeID: "sk-docc-contrib-subtree",
         liExtraClass: "sk-docc-nav-contrib-group",
         linkExtraClass: linkExtraClass,
         href: "/\(self.urlPrefix)/contributors/",
         isCurrent: currentSlug == "contributors",
         glyphHTML: self.contributorsGlyphHTML(),
         labelText: self.contributorsLabel,
         twistAriaLabel: self.contributorsLabel,
         isOpen: isContributorsActive,
         subtreeInner: rows.joined(),
         subtreeExtraClass: " sk-docc-contrib-subtree"
      )
   }

   /// The shared `[twist][glyph][link]` row + branch subtree used by every top item (years
   /// AND Contributors). The twist is an `<a href=…>` pointing at the SAME branch-overview URL
   /// as the adjacent row link (so the two share one navigation target). With JS the click
   /// handler intercepts it (`preventDefault`) to hydrate/toggle the subtree inline; with no JS
   /// it natively navigates to the overview, which server-renders the branch expanded – so the
   /// disclosure affordance degrades gracefully instead of going dead. `aria-expanded` is valid
   /// on a link, so the twist keeps native `role=link` semantics (no `role="button"`). The
   /// subtree carries a stable `id` + `data-docc-branch-sessions` the accordion JS keys on, and
   /// is server-rendered open (no `hidden`, `aria-expanded="true"`) for the active branch and
   /// hidden otherwise – which delivers single-accordion + no-JS degradation for free.
   /// `subtreeInner` is the inner row HTML; empty means a placeholder subtree (a non-active
   /// year, whose sessions are not in the DOM under the active-branch-only design).
   /// `unhydratedKey`, when non-nil, marks the placeholder subtree with `data-docc-unhydrated`
   /// so the JS fetches `docc-sidebar-nav.json` and fills the rows on first twist-open instead
   /// of navigating. Only non-active year subtrees set it; the active year (already populated)
   /// and Contributors (always populated) pass nil.
   private func topItemRow(
      branchKey: String,
      subtreeID: String,
      liExtraClass: String,
      linkExtraClass: String,
      href: String,
      isCurrent: Bool,
      glyphHTML: String,
      labelText: String,
      twistAriaLabel: String,
      isOpen: Bool,
      subtreeInner: String,
      subtreeExtraClass: String,
      unhydratedKey: String? = nil
   ) -> String {
      // The twist is a real link to the branch overview (same href as the row link), not a
      // <button>: with JS the click handler intercepts it to hydrate/toggle inline, with no JS
      // it natively navigates to the overview (which server-renders the branch expanded), so the
      // disclosure is never an inert control. `aria-expanded` is ARIA-valid on a link.
      let twist = "<a class=\"sk-docc-nav-twist sk-docc-nav-twist-btn\""
         + " data-docc-subtree-toggle aria-controls=\"\(subtreeID)\""
         + " aria-expanded=\"\(isOpen ? "true" : "false")\""
         + " aria-label=\"\(Self.escape(twistAriaLabel))\""
         + " href=\"\(Self.escape(href))\">"
         + Self.chevronIcon
         + "</a>"
      let linkClass = linkExtraClass.isEmpty ? "sk-docc-nav-link" : "sk-docc-nav-link \(linkExtraClass)"
      let currentAttr = isCurrent ? " aria-current=\"page\"" : ""
      let link = "<a class=\"\(linkClass)\" href=\"\(Self.escape(href))\"\(currentAttr)>"
         + glyphHTML
         + "<span class=\"sk-docc-nav-text\">\(Self.escape(labelText))</span>"
         + "</a>"
      let subtreeClass = "sk-docc-nav-sessions sk-docc-nav-subtree\(subtreeExtraClass)"
      // The hydration marker sits before `data-docc-branch-sessions` so that attribute stays
      // directly adjacent to `hidden` (the contract the accordion JS and the tests key on).
      let unhydratedAttr = unhydratedKey.map { " data-docc-unhydrated=\"\(Self.escape($0))\"" } ?? ""
      let subtree = "<ul id=\"\(subtreeID)\" class=\"\(subtreeClass)\"\(unhydratedAttr) data-docc-branch-sessions=\"\(Self.escape(branchKey))\"\(isOpen ? "" : " hidden")>"
         + subtreeInner
         + "</ul>"
      let liClass = liExtraClass.isEmpty
         ? "sk-docc-nav-item sk-docc-nav-top"
         : "sk-docc-nav-item sk-docc-nav-top \(liExtraClass)"
      return "<li class=\"\(liClass)\" data-docc-branch=\"\(Self.escape(branchKey))\">"
         + "<div class=\"sk-docc-nav-row\">\(twist)\(link)</div>"
         + subtree
         + "</li>"
   }

   /// The Contributors top-item glyph: a colored Font Awesome icon centered on a gradient
   /// tile (24px, the shared top-glyph footprint), replacing the old empty placeholder
   /// circle. Defaults to `fa-solid fa-users`; overridable via `contributorsGlyph`.
   private func contributorsGlyphHTML() -> String {
      let glyph = self.contributorsGlyph ?? "fa-solid fa-users"
      return "<span class=\"sk-docc-nav-icon sk-docc-nav-top-glyph sk-docc-nav-contrib-glyph\" aria-hidden=\"true\">"
         + "<i class=\"\(Self.escape(glyph))\" aria-hidden=\"true\"></i>"
         + "</span>"
   }

   // MARK: - Year items

   /// A year top item: the shared `[twist][glyph][link]` row, plus – when it is the active
   /// year – its session list inside the branch subtree. A non-active year emits an empty,
   /// hidden subtree placeholder (active-branch-only DOM) marked `data-docc-unhydrated`; its
   /// sessions are not in the DOM to toggle in place, so the JS fetches `docc-sidebar-nav.json`
   /// and fills the rows on first twist-open (navigating only if that fetch fails). The row
   /// link still reaches the year overview, which server-renders the branch expanded for no-JS.
   private func yearItem(_ yearNode: DocCNavNode, activeYear: String?, currentSlug: String) -> String {
      let yearSlug = Self.slug(fromURL: yearNode.url)
      let isActiveYear = !yearNode.children.isEmpty && yearSlug == activeYear
      let isCurrent = yearSlug == currentSlug

      var subtreeInner = ""
      var subtreeExtraClass = ""
      if isActiveYear {
         // If the year has topic subgroups, render them; otherwise render sessions flat.
         if !yearNode.topicSubgroups.isEmpty {
            subtreeInner = self.groupedSessionsInner(yearNode: yearNode, currentSlug: currentSlug)
            subtreeExtraClass = " sk-docc-nav-grouped"
         } else {
            subtreeInner = yearNode.children.map { self.sessionRow($0, currentSlug: currentSlug) }.joined()
         }
      }

      return self.topItemRow(
         branchKey: yearSlug,
         subtreeID: "sk-docc-subtree-\(yearSlug)",
         liExtraClass: isActiveYear ? "sk-docc-nav-expanded" : "",
         linkExtraClass: "sk-docc-nav-year",
         href: yearNode.url,
         isCurrent: isCurrent,
         glyphHTML: self.yearGlyphHTML(for: yearNode),
         labelText: yearNode.title,
         twistAriaLabel: yearNode.title,
         isOpen: isActiveYear,
         subtreeInner: subtreeInner,
         subtreeExtraClass: subtreeExtraClass,
         // A non-active year is a placeholder: mark it so the JS lazy-hydrates its sessions
         // from docc-sidebar-nav.json on first open instead of navigating. The active year is
         // already populated, so it needs no marker.
         unhydratedKey: isActiveYear ? nil : yearSlug
      )
   }

   /// Renders the inner rows of a grouped session list (subgroup headers + session rows),
   /// without the enclosing `<ul>` – `topItemRow` wraps it in the branch subtree list.
   private func groupedSessionsInner(yearNode: DocCNavNode, currentSlug: String) -> String {
      // Build a flat slug→DocCNavNode lookup for the year's children.
      var childBySlug: [String: DocCNavNode] = [:]
      for child in yearNode.children {
         childBySlug[Self.slug(fromURL: child.url)] = child
      }

      // Track which children are placed in a group (to avoid double-rendering).
      var placedSlugs = Set<String>()

      var groups: [String] = []
      for group in yearNode.topicSubgroups {
         var rows: [String] = []
         for slug in group.slugs {
            if let node = childBySlug[slug] {
               placedSlugs.insert(slug)
               rows.append(self.sessionRow(node, currentSlug: currentSlug))
            }
         }
         if !rows.isEmpty {
            groups.append(
               "<li class=\"sk-docc-nav-subgroup\">"
                  + "<span class=\"sk-docc-nav-subgroup-h\">\(Self.escape(group.title))</span>"
                  + "<ul class=\"sk-docc-nav-sessions\">\(rows.joined())</ul>"
                  + "</li>"
            )
         }
      }

      // Any sessions not in any group are appended ungrouped at the end.
      let ungrouped = yearNode.children
         .filter { !placedSlugs.contains(Self.slug(fromURL: $0.url)) }
         .map { self.sessionRow($0, currentSlug: currentSlug) }
         .joined()

      let ungroupedItem = ungrouped.isEmpty ? "" : "<li class=\"sk-docc-nav-subgroup\">\(ungrouped)</li>"

      return groups.joined() + ungroupedItem
   }

   /// Renders a single session row with framework icon and stub dimming.
   private func sessionRow(_ session: DocCNavNode, currentSlug: String) -> String {
      let current = Self.slug(fromURL: session.url) == currentSlug
      let stubClass = session.isStub ? " sk-docc-nav-stub" : ""
      let stubAttr = session.isStub ? " title=\"\(Self.escape(self.stubTitle))\"" : ""
      return "<li class=\"sk-docc-nav-session\(stubClass)\">"
         + "<a class=\"sk-docc-nav-link\" href=\"\(Self.escape(session.url))\""
         + (current ? " aria-current=\"page\"" : "")
         + stubAttr
         + ">"
         + self.sessionIconHTML(framework: session.framework)
         + "<span class=\"sk-docc-nav-text\">\(Self.escape(session.title))</span></a></li>"
   }

   // MARK: - Loose items

   /// A loose (non-year) page row, e.g. a "Contributing" page. Its icon slot always carries a
   /// real guide glyph – the slug's configured icon, or the shared default – never the empty
   /// placeholder span.
   private func looseItem(_ node: DocCNavNode, currentSlug: String) -> String {
      let slug = Self.slug(fromURL: node.url)
      let current = slug == currentSlug
      return "<li class=\"sk-docc-nav-item\">"
         + "<a class=\"sk-docc-nav-link\" href=\"\(Self.escape(node.url))\""
         + (current ? " aria-current=\"page\"" : "")
         + ">\(self.guideGlyphHTML(slug: slug))"
         + "<span class=\"sk-docc-nav-text\">\(Self.escape(node.title))</span></a></li>"
   }

   /// The glyph for a loose (guide) item: the slug's configured Font Awesome icon, or the shared
   /// default (`fa-solid fa-file-lines`) when none is configured – so a loose item is always a
   /// real glyph on a neutral chip tile, never the empty placeholder. The neutral tile + muted
   /// glyph reads as a quiet sibling of the saturated framework chips, marking these as curated
   /// navigation rather than brand badges. The FA `<i>` is inlined to an SVG by FontAwesomeInliner.
   private func guideGlyphHTML(slug: String) -> String {
      let glyph = self.guideIcons?[slug] ?? Self.defaultGuideGlyph
      return "<span class=\"sk-docc-nav-icon sk-docc-nav-guide-icon\" aria-hidden=\"true\">"
         + "<i class=\"\(Self.escape(glyph))\" aria-hidden=\"true\"></i>"
         + "</span>"
   }

   // MARK: - Icon helpers

   /// Renders a year glyph from a `@PageImage(purpose: icon)` resolved URL, or a neutral
   /// placeholder when no image is declared. Matches the prototype's `<YearGlyph>` shape.
   private func yearGlyphHTML(for yearNode: DocCNavNode) -> String {
      if let src = yearNode.glyphImageURL {
         return "<img class=\"sk-docc-nav-yearglyph sk-docc-nav-top-glyph\" src=\"\(Self.escape(src))\" alt=\"\" aria-hidden=\"true\" loading=\"lazy\" width=\"24\" height=\"24\"/>"
      } else {
         // Neutral rounded placeholder sharing the 24px top-glyph footprint with year images
         // and the Contributors tile, so every top row reads as [twist][24px glyph][text].
         return "<span class=\"sk-docc-nav-icon sk-docc-nav-top-glyph sk-docc-nav-yearglyph-placeholder\" aria-hidden=\"true\"></span>"
      }
   }

   /// Renders a session icon from the framework registry. When no framework or registry
   /// entry is found, falls back to the neutral rounded placeholder (existing behavior).
   private func sessionIconHTML(framework: String?) -> String {
      guard let key = framework,
            let icon = frameworkIcons?[key]
      else {
         // Neutral placeholder – matches existing sk-docc-nav-icon behavior.
         return "<span class=\"sk-docc-nav-icon\" aria-hidden=\"true\"></span>"
      }

      // Chip: a white FontAwesome glyph centered on the framework's colored tile. The tile
      // background (gradient for two colors, solid fill for one) is painted by the generated
      // `[data-framework]` CSS; the white glyph color comes from docc.css. White-on-saturated
      // reads in both light and dark, so no per-glyph inline color/background is emitted. The
      // glyph itself is inlined by FontAwesomeInliner (Phase 6).
      return "<span class=\"sk-docc-nav-icon sk-docc-nav-fw-icon\" data-framework=\"\(Self.escape(key))\" aria-hidden=\"true\">"
         + "<i class=\"\(Self.escape(icon.glyph))\" aria-hidden=\"true\"></i>"
         + "</span>"
   }

   /// A hidden, aria-hidden legend of one framework-icon span per distinct framework that appears
   /// anywhere in the nav tree – every year, not just the active one.
   ///
   /// It exists purely as a clone source for the client JS. Under the active-branch-only DOM only the
   /// current year's sessions (and so only their frameworks' icons) are ever inlined into a page; a
   /// framework unique to another year would therefore have no same-framework icon on the page to
   /// clone, and a lazy-hydrated or cross-year-filter row for it would fall back to the neutral
   /// placeholder. Emitting every framework's icon once – via the SAME `sessionIconHTML` the session
   /// rows use – guarantees `FontAwesomeInliner` inlines each glyph at build time and the JS finds a
   /// byte-identical clone source for every framework, so a hydrated icon matches a server-rendered
   /// one exactly (same SVG, same color style).
   ///
   /// Only frameworks present in the registry get a real glyph worth cloning; a framework with no
   /// registry entry hydrates to the same neutral placeholder whether or not it is legended, so it is
   /// left out. Frameworks are listed in sorted order for deterministic, diff-friendly output (the
   /// order is irrelevant to the JS, which keys the clone map by framework).
   private func iconLegendHTML(tree: [DocCNavNode]) -> String {
      var frameworks = Set<String>()
      for node in tree {
         for child in node.children {
            if let framework = child.framework {
               frameworks.insert(framework)
            }
         }
      }
      let icons = frameworks
         .sorted()
         .filter { self.frameworkIcons?[$0] != nil }
         .map { self.sessionIconHTML(framework: $0) }
         .joined()
      guard !icons.isEmpty else { return "" }
      return "<div class=\"sk-docc-nav-icon-legend\" hidden aria-hidden=\"true\">\(icons)</div>"
   }

   // MARK: - Filter box

   /// Renders the pinned filter box at the bottom of the sidebar. The matching JS
   /// (docc-filter.js) live-filters the visible tree rows. No-JS fallback: the box is
   /// still rendered and visible, but filtering does not occur – the tree remains fully
   /// accessible as static HTML links.
   private func filterBoxHTML() -> String {
      let safePlaceholder = Self.escape(self.filterPlaceholder)
      // The search icon SVG matches the prototype's wn-filter-box style.
      let searchIcon = "<svg class=\"sk-docc-filter-icon\" width=\"13\" height=\"13\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<circle cx=\"11\" cy=\"11\" r=\"7\"/><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/></svg>"
      return "<div class=\"sk-docc-filter\">"
         + "<div class=\"sk-docc-filter-box\">"
         + searchIcon
         + "<input class=\"sk-docc-filter-input\" type=\"search\" placeholder=\"\(safePlaceholder)\" aria-label=\"\(safePlaceholder)\" autocomplete=\"off\"/>"
         + "<button class=\"sk-docc-filter-clear\" type=\"button\" aria-label=\"Clear filter\" hidden>✕</button>"
         + "</div>"
         + "</div>"
   }

   // MARK: - Icons

   /// Inline close (×) glyph – no Font Awesome dependency.
   private static let closeIcon =
      "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\"/><line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\"/></svg>"

   /// Inline chevron glyph shown inside every top-item twist (years + Contributors).
   private static let chevronIcon =
      "<svg width=\"9\" height=\"9\" viewBox=\"0 0 10 10\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<path d=\"M3.5 2L7 5L3.5 8\"/></svg>"

   // MARK: - Helpers

   /// The last non-empty path component of a `/prefix/slug/` URL.
   static func slug(fromURL url: String) -> String {
      url.split(separator: "/").last.map(String.init) ?? ""
   }

   /// The full page slug of a `/<urlPrefix>/<slug>/` URL: the path with the configured
   /// `urlPrefix` and surrounding slashes stripped. Unlike `slug(fromURL:)` (last component
   /// only), this keeps multi-segment slugs intact – e.g. `/documentation/contributors/jeehut/`
   /// → `contributors/jeehut` – so the loose-node partition can tell the contributor index
   /// and its detail pages apart from year and article nodes.
   private func pageSlug(fromURL url: String) -> String {
      let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let prefix = self.urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard !prefix.isEmpty else { return trimmed }
      if trimmed == prefix { return "" }
      if trimmed.hasPrefix(prefix + "/") { return String(trimmed.dropFirst(prefix.count + 1)) }
      return trimmed
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}

// MARK: - Factory

extension DocCSidebarRenderer {
   /// Builds a renderer wired to config values from the given context:
   /// - `frameworkIcons` from `config.docc.frameworks`
   /// - `guideIcons` from `config.docc.guideIcons` (nil ⇒ every loose item gets the default glyph)
   /// - `contributorsLimit` from `config.docc.sidebarContributorsLimit` (nil ⇒ show all)
   /// - `avatarFallbackPath` from `config.docc.avatarFallbackPath`
   /// - `contributors` aggregated from all DocC notes' `doccContributors` extension keys
   /// - `filterPlaceholder` from the locale's `doccFilter` UIString
   /// - `contributorsLabel` from the locale's `doccContributors` UIString
   /// - `stubTitle` from the locale's `doccStubTitle` UIString
   /// - `urlPrefix` from the first configured section's URL prefix
   ///
   /// All inputs are optional – with a bare config this returns a renderer equivalent to
   /// `DocCSidebarRenderer()` so the default neutral output is preserved.
   static func make(from context: BuildContext) -> DocCSidebarRenderer {
      let docc = context.config.docc
      let filterPlaceholder = context.uiStrings.string(for: .doccFilter)
      let contributorsLabel = context.uiStrings.string(for: .doccContributors)
      let stubTitle = context.uiStrings.string(for: .doccStubTitle)
      // nil ⇒ no cap (show every contributor); a configured positive value still caps the list.
      let limit = docc?.sidebarContributorsLimit
      let urlPrefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"

      // Aggregate contributors from all DocC notes: collect all handles, count by handle.
      // Gated on the contributors feature flag: when disabled, the subtree is suppressed entirely
      // (an empty list renders no Contributors top item), even if notes carry contributor handles.
      let allNotes = context.sections.flatMap(\.pages).filter {
         ($0.extensions["doccNote"] as? Bool) == true
      }
      var countByHandle: [String: Int] = [:]
      if docc?.contributorsEnabled ?? false {
         for note in allNotes {
            let handles = note.extensions["doccContributors"] as? [String] ?? []
            for handle in handles {
               countByHandle[handle, default: 0] += 1
            }
         }
      }
      // Sort by note count descending; ties broken alphabetically for determinism.
      let contributors = countByHandle
         .sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
         }
         .map { (handle: $0.key, noteCount: $0.value) }

      return DocCSidebarRenderer(
         filterPlaceholder: filterPlaceholder,
         frameworkIcons: docc?.frameworks,
         guideIcons: docc?.guideIcons,
         contributorsLimit: limit,
         avatarFallbackPath: docc?.avatarFallbackPath,
         contributors: contributors,
         urlPrefix: urlPrefix,
         contributorsLabel: contributorsLabel,
         stubTitle: stubTitle
      )
   }
}
