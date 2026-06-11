import Foundation

/// Renders the DocC landing page: a gradient hero followed by up to three optional
/// content sections (Overview, Contributing, Topics) and a static TOC rail, all
/// wrapped in the shared `DocCShell` app-chrome.
///
/// ## Reusability invariant
///
/// Every section is driven by a config slot declared in `DocCConfig`. When the slot
/// is absent, the section is omitted entirely so a site with an empty `docc:` block
/// still renders a valid hero-only home page. No WWDCNotes strings or colors exist
/// in this file.
///
/// ## DOM shape (inside DocCShell)
///
/// ```
/// div.sk-docc-home.sk-docc-col-main
///   div.sk-docc-hero                          eyebrow + 2-tone title + abstract + prism art
///   section#overview.sk-docc-home-section     h2 + lead + numbered ways list (optional)
///   section#contributing.sk-docc-home-section h2 + lead + inline link (optional)
///   section#topics.sk-docc-home-section       h2 + cardgrid (optional)
/// aside.sk-docc-toc                           static TOC rail; items for rendered sections only
/// ```
///
/// The global footer (call-to-action cards + legal disclaimer) is rendered by
/// `DocCShell.wrap` from `SiteConfig.docc.footerCards` / `docc.footerDisclaimer`,
/// so it appears on every DocC page uniformly.
public struct DocCHomePage: Page {
   /// A call-to-action card – kept for backward compatibility with code that creates
   /// `DocCHomePage.FooterCard` values directly. Footer cards for all DocC pages are
   /// now declared in `SiteConfig.docc.footerCards` (as `DocCFooterCardConfig`) and
   /// rendered by `DocCShell`. This type is no longer used by `DocCHomePage` itself.
   @available(*, deprecated, message: "Declare footer cards in SiteConfig.docc.footerCards instead. DocCShell now renders the footer on all DocC pages.")
   public struct FooterCard: Sendable {
      public let heading: String
      public let body: String
      public let ctaLabel: String
      public let href: String

      public init(heading: String, body: String, ctaLabel: String, href: String) {
         self.heading = heading
         self.body = body
         self.ctaLabel = ctaLabel
         self.href = href
      }
   }

   /// Optional eyebrow text rendered above the hero title. Defaults to nil (omitted).
   public let heroEyebrow: String?
   /// Whether to show the decorative prism art in the hero. Defaults to true.
   /// Pass `false` to add `sk-docc-hero--noprism` and let the inner content span full width.
   public let showPrism: Bool

   public init(heroEyebrow: String? = nil, showPrism: Bool = true) {
      self.heroEyebrow = heroEyebrow
      self.showPrism = showPrism
   }

   // MARK: - Page protocol

   /// Returns a single synthetic `PageModel` that represents the DocC home page.
   /// The model is not backed by a Markdown file – its slug, title, and description
   /// come from `SiteConfig`.
   public func pages(in context: BuildContext) -> [PageModel] {
      let config = context.config
      return [
         PageModel(
            title: config.name,
            slug: Self.homeSlug(context: context),
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("SiteConfig.yaml"),
            summary: config.description,
            description: config.description,
            pageType: .staticPage
         )
      ]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let section = context.config.effectiveSections.first
      let prefix = section?.urlPrefix ?? "documentation"
      let allNotes = context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: Self.homeSlug(context: context))

      let renderer = OutputFileRenderer(context: context)
      let pagePath = Self.homePath(context: context)
      let canonical = "\(context.config.baseURL)\(pagePath)"
      // Use the dedicated homeAbstract for the SEO description when available so the
      // hero copy and the meta description can diverge.
      let metaDescription = context.config.docc?.homeAbstract ?? context.config.description
      let head = renderer.buildHead(
         title: context.config.name,
         description: metaDescription,
         canonicalURL: canonical,
         ogType: "website"
      ) + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"

      let (content, toc) = self.buildHomeContentAndToc(tree: tree, context: context)
      return DocCShell.wrap(
         content: content,
         sidebar: sidebar,
         toc: toc,
         page: page,
         context: context,
         head: head
      )
   }

   /// The home page is written to `/<urlPrefix>/index.html` (or `/index.html` when
   /// no section is configured). This keeps the home URL consistent with the
   /// sidebar's first-level links and the sitemap.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path = Self.homePath(context: context)
      var relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
      if relative.hasSuffix("/") { relative = String(relative.dropLast()) }
      if relative.isEmpty {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Internal helpers

   /// The `/<urlPrefix>/` path for the home page, with a trailing slash.
   static func homePath(context: BuildContext) -> String {
      let prefix = context.config.effectiveSections.first
         .map { $0.urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")) } ?? ""
      return prefix.isEmpty ? "/" : "/\(prefix)/"
   }

   /// A synthetic slug for the home `PageModel`, derived from the URL prefix.
   static func homeSlug(context: BuildContext) -> String {
      let prefix = context.config.effectiveSections.first
         .map { $0.urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")) } ?? ""
      return prefix.isEmpty ? "home" : prefix
   }

   /// Eyebrow: explicit init value wins, then `docc.homeEyebrow` from config.
   func effectiveEyebrow(context: BuildContext) -> String? {
      self.heroEyebrow ?? context.config.docc?.homeEyebrow
   }

   /// Builds the decorative prism art div. Returns an empty string when `showPrism` is false.
   static func prismArt() -> String {
      "<div class=\"sk-docc-hero-art\" aria-hidden=\"true\"><div class=\"sk-docc-hero-prism\"></div></div>"
   }

   // MARK: - Unified home content + TOC

   /// Assembles the `<div class="sk-docc-home sk-docc-col-main">` content block and the
   /// optional `<aside class="sk-docc-toc">` rail. Both are returned so the caller can
   /// pass them separately to `DocCShell.wrap(content:toc:...)`.
   ///
   /// The content includes the hero plus any sections whose config slots are populated.
   /// The TOC rail lists only the sections that were actually rendered, so the two stay
   /// in sync without extra bookkeeping.
   func buildHomeContentAndToc(tree: [DocCNavNode], context: BuildContext) -> (content: String, toc: String?) {
      let config = context.config
      let docc = config.docc

      // Build each optional section; track which IDs were rendered for the TOC.
      var sections: [(id: String, html: String)] = []

      if let html = self.overviewSection(docc: docc, context: context) {
         sections.append((id: "overview", html: html))
      }
      if let html = self.contributingSection(docc: docc, context: context) {
         sections.append((id: "contributing", html: html))
      }
      if let html = self.topicsSection(tree: tree, context: context) {
         sections.append((id: "topics", html: html))
      }

      let heroHTML = self.hero(
         siteName: config.name,
         subtitle: docc?.homeAbstract ?? config.description,
         eyebrow: self.effectiveEyebrow(context: context),
         showPrism: self.showPrism,
         brand: docc?.brand
      )

      let sectionsHTML = sections.map(\.html).joined()
      let content = "<div class=\"sk-docc-home sk-docc-col-main\">"
         + heroHTML
         + sectionsHTML
         + "</div>"

      let toc: String? = sections.isEmpty ? nil : self.tocRail(sections: sections.map(\.id), context: context)
      return (content: content, toc: toc)
   }

   // MARK: - Hero

   /// Renders the home-page hero. The title is 2-tone when `brand` is set: prefix half in
   /// default text color, accent half in `--color-accent` via `sk-docc-hero-title-accent`.
   /// Without a brand the full `siteName` is rendered as plain text. `showPrism: false`
   /// suppresses the decorative art panel and adds `sk-docc-hero--noprism`.
   func hero(siteName: String, subtitle: String?, eyebrow: String?, showPrism: Bool = true, brand: DocCBrandConfig? = nil) -> String {
      var inner = "<div class=\"sk-docc-hero-inner\">"
      if let eyebrow, !eyebrow.isEmpty {
         inner += "<span class=\"sk-docc-hero-eyebrow\">\(Self.escape(eyebrow))</span>"
      }
      // 2-tone title when brand is configured, plain title otherwise.
      let titleContent: String
      if let brand {
         titleContent = "<span>\(Self.escape(brand.prefix))</span>"
            + "<span class=\"sk-docc-hero-title-accent\">\(Self.escape(brand.accent))</span>"
      } else {
         titleContent = Self.escape(siteName)
      }
      inner += "<h1 class=\"sk-docc-hero-title\">\(titleContent)</h1>"
      if let sub = subtitle, !sub.isEmpty {
         inner += "<p class=\"sk-docc-hero-sub\">\(Self.escape(sub))</p>"
      }
      inner += "</div>"
      if showPrism {
         inner += Self.prismArt()
      }
      let noprismClass = showPrism ? "" : " sk-docc-hero--noprism"
      return "<div class=\"sk-docc-hero\(noprismClass)\">\(inner)</div>"
   }

   // MARK: - Overview section

   /// Renders the `#overview` section with an auto-numbered ways list. Returns nil when
   /// `homeWays` is absent or empty so the section is completely omitted.
   func overviewSection(docc: DocCConfig?, context: BuildContext) -> String? {
      guard let ways = docc?.homeWays, !ways.isEmpty else { return nil }
      let strings = context.uiStrings
      var html = "<section id=\"overview\" class=\"sk-docc-home-section\">"
      html += "<h2 class=\"sk-docc-home-h2\">\(Self.escape(strings.string(for: .doccHomeOverview)))</h2>"
      if let lead = docc?.homeOverviewLead, !lead.isEmpty {
         html += "<p class=\"sk-docc-home-lead\">\(Self.escape(lead))</p>"
      }
      let waysHTML = ways.enumerated().map { idx, way in
         "<div class=\"sk-docc-way\">"
            + "<span class=\"sk-docc-way-n\">\(idx + 1)</span>"
            + "<div class=\"sk-docc-way-text\">"
            + "<div class=\"sk-docc-way-title\">\(Self.escape(way.title))</div>"
            + "<div class=\"sk-docc-way-body\">\(Self.escape(way.body))</div>"
            + "</div>"
            + "</div>"
      }.joined()
      html += "<div class=\"sk-docc-ways\">\(waysHTML)</div>"
      html += "</section>"
      return html
   }

   // MARK: - Contributing section

   /// Renders the `#contributing` section with a lead sentence and an inline link.
   /// Returns nil when `homeContributing` is absent.
   func contributingSection(docc: DocCConfig?, context: BuildContext) -> String? {
      guard let contrib = docc?.homeContributing else { return nil }
      let strings = context.uiStrings
      var html = "<section id=\"contributing\" class=\"sk-docc-home-section\">"
      html += "<h2 class=\"sk-docc-home-h2\">\(Self.escape(strings.string(for: .doccHomeContributing)))</h2>"
      let linkHTML = " <a class=\"sk-docc-link\" href=\"\(Self.escape(contrib.linkHref))\">"
         + "\(Self.escape(contrib.linkText))</a>"
      html += "<p class=\"sk-docc-home-lead\">\(Self.escape(contrib.lead))\(linkHTML)</p>"
      html += "</section>"
      return html
   }

   // MARK: - Topics section

   /// Renders the `#topics` section: a `sk-docc-cardgrid` with the Contributors mosaic
   /// card first (when contributors exist) followed by per-year cards derived from the
   /// nav tree. Returns nil when there are no year nodes and no contributors.
   func topicsSection(tree: [DocCNavNode], context: BuildContext) -> String? {
      // Year nodes have children, or their slug matches the wwdcYY pattern. Curated loose-page
      // groups (isGroup) also carry children but are not years, so they are excluded here.
      let yearNodes = tree.filter { node in
         guard !node.isGroup else { return false }
         let s = node.url.split(separator: "/").last.map(String.init) ?? ""
         return !node.children.isEmpty || DocCNavigationTree.yearKey(of: s) != nil
      }

      let sidebarInfo = DocCSidebarRenderer.make(from: context)
      let contributors = Array(sidebarInfo.contributors.prefix(24))
      let urlPrefix = sidebarInfo.urlPrefix
      let docc = context.config.docc

      guard !yearNodes.isEmpty || !contributors.isEmpty else { return nil }

      let strings = context.uiStrings
      var html = "<section id=\"topics\" class=\"sk-docc-home-section\">"
      html += "<h2 class=\"sk-docc-home-h2\">\(Self.escape(strings.string(for: .doccHomeTopics)))</h2>"

      var cards: [String] = []

      // Contributors mosaic is FIRST in the grid when contributors exist.
      if !contributors.isEmpty {
         cards.append(self.contributorsMosaicCard(
            contributors: contributors,
            urlPrefix: urlPrefix,
            docc: docc,
            context: context
         ))
      }

      for node in yearNodes {
         cards.append(self.yearCard(node: node, docc: docc, context: context))
      }

      html += "<div class=\"sk-docc-cardgrid\">\(cards.joined())</div>"
      html += "</section>"
      return html
   }

   // MARK: - Contributors mosaic card

   /// Renders the Contributors mosaic card: a grid of up to 24 hue-gradient tiles.
   /// Each tile's color is deterministically derived from the contributor's handle.
   func contributorsMosaicCard(
      contributors: [(handle: String, noteCount: Int)],
      urlPrefix: String,
      docc: DocCConfig?,
      context: BuildContext
   ) -> String {
      let strings = context.uiStrings
      let href = Self.escape("/\(urlPrefix)/contributors/")
      let tiles = contributors.map { contributor -> String in
         let h = Self.hue(for: contributor.handle)
         let h2 = (h + 50) % 360
         let gradient = "linear-gradient(145deg,hsl(\(h),78%,56%),hsl(\(h2),76%,48%))"
         return "<span class=\"sk-docc-mosaic-tile\" style=\"background:\(gradient)\" aria-hidden=\"true\"></span>"
      }.joined()

      var body = "<div class=\"sk-docc-card-head\">"
         + "<h3 class=\"sk-docc-card-title\">\(Self.escape(strings.string(for: .doccContributors)))</h3>"
         + "</div>"
      if let blurb = docc?.homeContributorsBlurb, !blurb.isEmpty {
         body += "<p class=\"sk-docc-card-blurb\">\(Self.escape(blurb))</p>"
      }
      body += "<span class=\"sk-docc-link sk-docc-card-link\">"
         + Self.escape(strings.string(for: .doccHomeContributorsLink))
         + "</span>"

      return "<a class=\"sk-docc-card sk-docc-card--with-kv\" href=\"\(href)\">"
         + "<div class=\"sk-docc-mosaic\" aria-hidden=\"true\">\(tiles)</div>"
         + "<div class=\"sk-docc-card-body\">\(body)</div>"
         + "</a>"
   }

   // MARK: - Per-year card

   /// Renders one year card in the Topics grid. The key-visual banner is resolved in order:
   /// explicit `docc.years[label].keyVisual` → convention `/assets/<label>.jpeg` with an
   /// `onerror` that swaps to the generative hue gradient → generative gradient directly.
   func yearCard(node: DocCNavNode, docc: DocCConfig?, context: BuildContext) -> String {
      let label = node.title
      let yearConfig = docc?.years?[label]
      // Only non-stub children count as real notes.
      let notes = node.children.filter { !$0.isStub }.count
      let strings = context.uiStrings

      let h = Self.hue(for: label)
      let h2 = (h + 50) % 360
      let gradient = "linear-gradient(145deg,hsl(\(h),78%,56%),hsl(\(h2),76%,48%))"

      // Build the onerror attribute that swaps the container to the generative style when the
      // image fails (404 or network error). Single quotes work inside double-quoted HTML attrs.
      let onerrorJS = "var p=this.parentElement;"
         + "p.classList.add('sk-docc-card-kv--generative');"
         + "p.style.background='\(gradient)';"
         + "this.remove()"

      let kvHTML: String
      if let explicitKV = yearConfig?.keyVisual, !explicitKV.isEmpty {
         kvHTML = "<div class=\"sk-docc-card-kv\">"
            + "<img src=\"\(Self.escape(explicitKV))\" alt=\"\" loading=\"lazy\""
            + " onerror=\"\(Self.escape(onerrorJS))\"/>"
            + "</div>"
      } else {
         // Convention: /assets/<label>.jpeg emitted by DocCCatalogImageTeleporter.
         let src = Self.escape("/assets/\(label).jpeg")
         kvHTML = "<div class=\"sk-docc-card-kv\">"
            + "<img src=\"\(src)\" alt=\"\" loading=\"lazy\""
            + " onerror=\"\(Self.escape(onerrorJS))\"/>"
            + "</div>"
      }

      // Note count: hidden when 0 (all stubs or no children).
      let countHTML = notes > 0
         ? "<span class=\"sk-docc-card-count\">\(notes == 1 ? "1 note" : "\(notes) notes")</span>"
         : ""

      var body = "<div class=\"sk-docc-card-head\">"
         + "<h3 class=\"sk-docc-card-title\">\(Self.escape(label))</h3>"
         + countHTML
         + "</div>"
      // Trimmed gates: a whitespace-only config value must not emit an empty element
      // whose margins would still hold vertical space between title and link.
      if let stack = yearConfig?.stack?.trimmingCharacters(in: .whitespacesAndNewlines), !stack.isEmpty {
         body += "<p class=\"sk-docc-card-stack\">\(Self.escape(stack))</p>"
      }
      if let blurb = yearConfig?.blurb?.trimmingCharacters(in: .whitespacesAndNewlines), !blurb.isEmpty {
         body += "<p class=\"sk-docc-card-blurb\">\(Self.escape(blurb))</p>"
      }
      body += DocCAPIBadges.render(yearConfig?.apis)
      body += "<span class=\"sk-docc-link sk-docc-card-link\">"
         + Self.escape(strings.string(for: .doccHomeYearCardLink))
         + "</span>"

      return "<a class=\"sk-docc-card sk-docc-card--with-kv\" href=\"\(Self.escape(node.url))\">"
         + kvHTML
         + "<div class=\"sk-docc-card-body\">\(body)</div>"
         + "</a>"
   }

   // MARK: - TOC rail

   /// Renders the static `aside.sk-docc-toc` rail from the list of rendered section IDs.
   /// Uses the same CSS classes as the article TOC rail so `docc-toc.js` scroll-spy works
   /// without any additional JS changes.
   func tocRail(sections: [String], context: BuildContext) -> String {
      guard !sections.isEmpty else { return "" }
      let strings = context.uiStrings
      let keyMap: [String: UIStringKey] = [
         "overview": .doccHomeOverview,
         "contributing": .doccHomeContributing,
         "topics": .doccHomeTopics,
      ]
      let items = sections.map { id -> String in
         let label = keyMap[id].map { strings.string(for: $0) } ?? id.capitalized
         return "<a class=\"sk-docc-toc-item\" href=\"#\(id)\">\(Self.escape(label))</a>"
      }.joined()
      let tocTitle = strings.string(for: .doccTocTitle)
      return "<aside class=\"sk-docc-toc\" aria-label=\"\(Self.escape(tocTitle))\">"
         + "<div class=\"sk-docc-toc-title\">\(Self.escape(tocTitle))</div>"
         + "<nav>\(items)</nav>"
         + "</aside>"
   }

   // MARK: - Shared helpers

   /// Deterministic hue 0-359 from any string. A weighted checksum prevents alphabetically
   /// adjacent strings from getting visually identical hues. Uses wrapping arithmetic (&+/&*)
   /// to avoid overflow; `.magnitude` on the final sum gives a UInt that is safe to modulo
   /// even when the sum wrapped to `Int.min` (where `abs` would trap).
   private static func hue(for string: String) -> Int {
      let sum = string.unicodeScalars.enumerated().reduce(0) { acc, pair in
         acc &+ Int(pair.element.value) &* (pair.offset + 1)
      }
      return Int(sum.magnitude % 360)
   }

   /// HTML-escapes the four characters that would otherwise break attribute values or content.
   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
