import Foundation

/// The shared DocC app-shell – a fixed-viewport chrome that every DocC page renderer wraps its
/// body in, so the whole catalog presents one consistent docs layout.
///
/// Generic and parametrizable: the brand label, the sidebar nav tree, the page body, and the
/// optional "on this page" TOC are all supplied by the caller, so the same shell skins any
/// docs-style site, not just WWDCNotes. Color, fonts, and accents come from the theme tokens
/// (see `docc.css`), so the shell inherits the active scheme without hard-coded brand values.
///
/// Structure (mirrors the `.sk-docc-*` rules in `docc.css`):
/// ```
/// div.sk-docc-layout                ← app root; carries docc-sidebar.js hooks (data-sidebar-open, .sk-docc-js)
///   header.sk-docc-appbar           ← burger (mobile) + brand (left) + search pill (right)
///   div.sk-docc-body                ← flex row: sidebar | scrollable content
///     nav.sk-docc-sidebar           ← caller's nav tree (independently scrolls)
///     div.sk-docc-scrim             ← off-canvas backdrop (mobile)
///     main.sk-docc-scroll           ← independently scrolls
///       div.sk-docc-page[ --with-toc]
///         {content}                 ← caller's body (an article carries .sk-docc-col-main; wide pages do not)
///         {toc}                     ← optional aside.sk-docc-toc, present only with a TOC
///       footer.sk-docc-footer       ← optional; cards + legal block from config; scrolls with content
/// ```
///
/// The shell is wrapped in `PageShell` with `chrome: .appShell`, which suppresses the generic
/// site `<header>`/`<footer>` – the DocC shell supplies its own, so it would otherwise double up.
enum DocCShell {
   /// Assembles the app-shell around `content` and returns the complete HTML page.
   ///
   /// The shell owns the `<script defer>` links for every script the appbar-bearing
   /// DocC chrome requires: search overlay, sidebar drawer, sidebar filter, theme
   /// switch, and (when a TOC rail is present) the TOC scroll-spy. This ensures every
   /// DocC page type – article, home, year listing, contributors, contributor detail,
   /// missing notes, or any future addition – gets the scripts without per-page wiring.
   ///
   /// Search chrome (the appbar pill, the overlay modal, the search script link, and the
   /// framework-registry JSON) is emitted only when `DocCConfig.searchEnabled` is true.
   /// With `search: false` the builder skips the search renderers, so the script and index
   /// files never exist – emitting the chrome would 404 the script and dead-end the pill.
   ///
   /// - Parameters:
   ///   - content: The page-specific body. An article should carry `sk-docc-col-main` (capped,
   ///     centered, readable width); wide pages (home, year, contributors) supply full-width content.
   ///   - sidebar: The rendered navigation tree (`DocCSidebarRenderer`).
   ///   - toc: The optional "on this page" TOC aside. When non-nil the page becomes 3-column
   ///     (`sk-docc-page--with-toc`) and the TOC scroll-spy script is injected; when nil
   ///     the page stays 2-column and the TOC script is omitted.
   ///   - page / context / head: Threaded to `PageShell.wrap`.
   static func wrap(
      content: String,
      sidebar: String,
      toc: String? = nil,
      page: PageModel,
      context: BuildContext,
      head: String
   ) -> String {
      let pageClass = toc == nil ? "sk-docc-page" : "sk-docc-page sk-docc-page--with-toc"
      let searchEnabled = context.config.docc?.searchEnabled ?? true
      let shell = "<div class=\"sk-docc-layout\">"
         + self.appbar(context: context)
         + "<div class=\"sk-docc-body\">"
         + sidebar
         + "<div class=\"sk-docc-scrim\" data-docc-sidebar-scrim hidden></div>"
         + "<main class=\"sk-docc-scroll\">"
         + "<div class=\"\(pageClass)\">"
         + content
         + (toc ?? "")
         + "</div>"
         + self.footerHTML(context: context)
         + "</main>"
         + "</div>"
         + (searchEnabled ? self.searchOverlayHTML(context: context) : "")
         + "</div>"

      // Shell-universal scripts: search (only when the feature is on), sidebar drawer,
      // sidebar filter, theme switch. The TOC scroll-spy is included only when a TOC rail
      // is present so pages without a TOC do not load a script that has no targets to observe.
      var shellScripts =
         (searchEnabled ? "<script defer src=\"\(DocCSearchScriptRenderer.scriptURL)\"></script>" : "")
         + "<script defer src=\"\(DocCSidebarScriptRenderer.scriptURL)\"></script>"
         + "<script defer src=\"\(DocCFilterScriptRenderer.scriptURL)\"></script>"
         + "<script defer src=\"\(DocCThemeScriptRenderer.scriptURL)\"></script>"
      if toc != nil {
         shellScripts += "<script defer src=\"\(DocCTocScriptRenderer.scriptURL)\"></script>"
      }

      return PageShell.wrap(
         content: shell,
         page: page,
         context: context,
         head: head + shellScripts,
         bodyClass: "sk-docc-shell-body",
         chrome: .appShell
      )
   }

   /// Renders the shared DocC footer from config – call-to-action cards + a legal block.
   ///
   /// The footer is emitted inside `.sk-docc-scroll`, after `.sk-docc-page`, so it scrolls
   /// with the content on every DocC page (article, year, home, contributors). When neither
   /// `footerCards`, `footerDisclaimer`, nor `footerLegalNotice` is configured, an empty
   /// string is returned so no empty footer element pollutes the DOM.
   ///
   /// All text comes from `SiteConfig.docc` – no brand strings are hardcoded here.
   static func footerHTML(context: BuildContext) -> String {
      let docc = context.config.docc
      let cards = docc?.footerCards ?? []
      let disclaimer = docc?.footerDisclaimer
      let legalNotice = docc?.footerLegalNotice

      // Nothing configured – omit entirely (no empty footer in the DOM).
      guard !cards.isEmpty || disclaimer != nil || legalNotice != nil else { return "" }

      var inner = ""

      // Card columns: a 2-up grid of call-to-action links.
      if !cards.isEmpty {
         let cols = cards.map { card -> String in
            "<a class=\"sk-docc-footer-card\" href=\"\(self.escape(card.href))\">"
               + "<h4>\(self.escape(card.heading))</h4>"
               + "<p>\(self.escape(card.body))</p>"
               + "<span class=\"sk-docc-link\">\(self.escape(card.ctaLabel))</span>"
               + "</a>"
         }.joined()
         inner += "<div class=\"sk-docc-footer-cols\">\(cols)</div>"
      }

      // Legal block: brand mark as the left column, disclaimer + legal small print as the
      // text column beside it (stacked below on narrow viewports). The text wrap keeps the
      // brand a layout sibling of all text, so CSS can place the columns without knowing
      // which of the two text parts is configured.
      if disclaimer != nil || legalNotice != nil {
         let brandName = self.escape(context.config.name)
         var text = ""
         if let disclaimer {
            text += "<p>\(self.escape(disclaimer))</p>"
         }
         if let legalNotice {
            // Each non-empty line is one paragraph; blank separator lines (YAML block
            // scalars keep them) produce no empty elements.
            let paragraphs = legalNotice
               .components(separatedBy: .newlines)
               .map { $0.trimmingCharacters(in: .whitespaces) }
               .filter { !$0.isEmpty }
               .map { "<p>\(self.escape($0))</p>" }
               .joined()
            if !paragraphs.isEmpty {
               text += "<div class=\"sk-docc-footer-notice\">\(paragraphs)</div>"
            }
         }
         inner += "<div class=\"sk-docc-footer-legal\">"
            + "<div class=\"sk-docc-footer-brand\">\(brandName)</div>"
            + "<div class=\"sk-docc-footer-legal-text\">\(text)</div>"
            + "</div>"
      }

      return "<footer class=\"sk-docc-footer\">\(inner)</footer>"
   }

   /// The appbar: the hamburger (mobile drawer trigger) + brand wordmark on the left,
   /// and a search trigger pill (icon + localized label + keyboard shortcut hint) on the right.
   ///
   /// Brand rendering is parametrizable via `DocCConfig.brand`:
   /// - When `brand` is set, the wordmark splits into a primary span (`sk-docc-brand-1`, text
   ///   color) and an accent span (`sk-docc-brand-2`, `--color-accent`). An optional logo image
   ///   is placed before the wordmark when `brand.logoPath` is provided.
   /// - When `brand` is absent, the plain `config.name` is rendered as before (no regression).
   ///
   /// The search pill opens the `docc-search.js` overlay (whose input carries
   /// `sk-docc-search-input`). `⌘K` / `Ctrl+K` keyboard shortcuts are added by the search
   /// script so they work globally on DocC pages. When `DocCConfig.searchEnabled` is false
   /// the pill is omitted – the overlay, script, and index it depends on are not built.
   static func appbar(context: BuildContext) -> String {
      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let homeURL = "/\(prefix)/"
      let searchEnabled = context.config.docc?.searchEnabled ?? true
      let searchPill = searchEnabled
         ? self.searchPillHTML(label: context.uiStrings.string(for: .doccSearch))
         : ""

      return "<header class=\"sk-docc-appbar\">"
         + "<div class=\"sk-docc-appbar-left\">"
         + "<button type=\"button\" class=\"sk-docc-burger\" data-docc-sidebar-open"
         + " aria-label=\"Open navigation\" aria-expanded=\"false\" aria-controls=\"sk-docc-sidebar\">"
         + self.burgerIcon
         + "</button>"
         + self.brandHTML(config: context.config, homeURL: homeURL)
         + "</div>"
         + "<div class=\"sk-docc-appbar-right\">"
         + searchPill
         + self.themeSwitchHTML(context: context)
         + "</div>"
         + "</header>"
   }

   /// Renders the single appearance toggle button for the appbar, sitting beside the
   /// search pill. Mirrors the shared site toggle on fline.dev: one button that flips
   /// the effective theme (light ↔ dark) on click and persists the choice; the OS
   /// preference is the pre-click default. `docc-theme.js` wires the click, swaps the
   /// icon to reflect the current state, and follows the OS until the user clicks.
   ///
   /// The button is rendered with the moon glyph as a sensible static default; the
   /// theme JS replaces it on load with the icon that matches the applied theme.
   /// No-JS fallback: the button renders as inert HTML and clicking does not switch.
   private static func themeSwitchHTML(context: BuildContext) -> String {
      let label = self.escape(context.uiStrings.string(for: .doccThemeToggle))
      return "<button type=\"button\" class=\"sk-docc-theme-toggle\" data-docc-theme-toggle aria-label=\"\(label)\">"
         + self.themeMoonIcon
         + "</button>"
   }

   /// The global search overlay: a modal dialog opened by the appbar ⌘K pill (and the
   /// ⌘K / Ctrl+K shortcut). It holds the full-text search field, a results list rendered
   /// as rich rows, and a right-side preview panel that mirrors the focused result – the
   /// same visual language as the dedicated search page, so the quick-jump overlay matches
   /// the production search experience instead of a bare title list.
   ///
   /// `docc-search.js` shows/hides the overlay, lazy-loads the index, renders rows, and
   /// hydrates the preview panel on hover / arrow-key focus. All localized strings (result
   /// count, empty state, the preview's "Watch Video" / "View more" / note-type labels)
   /// ride on `data-*` attributes so the client script stays locale-agnostic. The framework
   /// color registry is emitted as an inline JSON block so a client-rendered row can paint
   /// the same gradient icon square the page does. Rendered once per page, hidden until opened.
   private static func searchOverlayHTML(context: BuildContext) -> String {
      let s = context.uiStrings
      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let cleanPrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let searchPageURL = cleanPrefix.isEmpty ? "/search/" : "/\(cleanPrefix)/search/"
      let placeholder = self.escape(s.string(for: .doccSearchPlaceholder))
      let label = self.escape(s.string(for: .doccSearch))
      let countTemplate = self.escape(s.string(for: .doccSearchResultCount))
      let emptyTitle = self.escape(s.string(for: .doccSearchNoMatches))
      let emptyBody = self.escape(s.string(for: .doccSearchNoMatchesBody))
      let watchLabel = self.escape(s.string(for: .doccWatchVideo))
      let moreLabel = self.escape(s.string(for: .doccSearchViewNote))

      // Optional "Try:" suggestion chips, server-rendered from config when provided.
      var suggestHTML = ""
      if let suggestions = context.config.docc?.searchSuggestions, !suggestions.isEmpty {
         let tryLabel = self.escape(s.string(for: .doccSearchTry))
         let chips = suggestions.map { term in
            "<button type=\"button\" class=\"sk-docc-search-chip\" data-docc-search-suggest=\"\(self.escape(term))\">"
               + self.escape(term)
               + "</button>"
         }.joined()
         suggestHTML = "<div class=\"sk-docc-search-suggest\">"
            + "<span class=\"sk-docc-search-try\">\(tryLabel)</span>"
            + chips
            + "</div>"
      }

      // The two-pane body: a scrollable results list on the left and a preview panel on
      // the right that the script hydrates from the focused result. The panel is an empty
      // server-rendered shell so no-JS readers never see a dangling, never-filled column
      // (CSS keeps it collapsed until the script reveals it).
      let body = "<div class=\"sk-docc-search-body\">"
         + "<ul class=\"sk-docc-search-results sk-docc-sesslist\" hidden></ul>"
         + "<div class=\"sk-docc-search-preview\" data-docc-search-preview hidden aria-hidden=\"true\"></div>"
         + "</div>"

      let closeLabel = self.escape(s.string(for: .doccSearchClose))
      return "<div class=\"sk-docc-search-overlay\" data-docc-search-overlay hidden>"
         + "<div class=\"sk-docc-search-backdrop\" data-docc-search-close></div>"
         + "<div class=\"sk-docc-search-modal\" role=\"dialog\" aria-modal=\"true\" aria-label=\"\(label)\">"
         + "<div class=\"sk-docc-search-field\">"
         + self.searchIcon
         + "<input class=\"sk-docc-search-input\" type=\"search\" autocomplete=\"off\""
         + " placeholder=\"\(placeholder)\" aria-label=\"\(label)\""
         + " data-docc-search-count=\"\(countTemplate)\""
         + " data-docc-search-empty-title=\"\(emptyTitle)\""
         + " data-docc-search-empty-body=\"\(emptyBody)\""
         + " data-docc-search-watch=\"\(watchLabel)\""
         + " data-docc-search-more=\"\(moreLabel)\""
         + " \(DocCSearchPage.dataLabelAttributes(strings: s))/>"
         + "<button type=\"button\" class=\"sk-docc-search-close\" data-docc-search-close aria-label=\"\(closeLabel)\">"
         + self.closeIcon
         + "</button>"
         + "</div>"
         + suggestHTML
         + "<p class=\"sk-docc-search-count\" hidden aria-live=\"polite\"></p>"
         + body
         + self.searchSeeAllHTML(searchPageURL: searchPageURL, label: self.escape(s.string(for: .doccSearchSeeAll)))
         + self.frameworkRegistryJSON(context: context)
         + "</div>"
         + "</div>"
   }

   /// Emits the framework → gradient-colors map as an inline JSON block the overlay's
   /// script reads to paint a colored icon square on each result row and in the preview
   /// panel. Mirrors the dedicated search page's block (same `data-docc-search-frameworks`
   /// hook), but the shell carries every configured framework rather than only those
   /// present in one page's records – the overlay lives on every page, so it cannot assume
   /// which frameworks the catalog uses. Returns an empty string when no colors are
   /// configured, in which case the row/panel icon degrades to a neutral square.
   private static func frameworkRegistryJSON(context: BuildContext) -> String {
      let icons = context.config.docc?.frameworks ?? [:]
      var registry: [String: [String]] = [:]
      for (key, icon) in icons where !icon.colors.isEmpty {
         registry[key] = icon.colors
      }
      guard !registry.isEmpty,
         let data = try? JSONSerialization.data(withJSONObject: registry, options: [.sortedKeys]),
         let json = String(data: data, encoding: .utf8)
      else {
         return ""
      }
      // A JSON script block is the safe container: no executable code, and the content is
      // hex color strings + framework keys (no "</script>" can appear), so no escaping trap.
      return "<script type=\"application/json\" data-docc-search-frameworks>\(json)</script>"
   }

   /// The overlay's footer link: a deep-link into the dedicated search page carrying the
   /// reader's current query (`/<prefix>/search/?q=…`). `docc-search.js` keeps the `href`'s
   /// query in sync as the reader types and reveals the footer once the query is non-empty,
   /// so the overlay stays a quick-jump while the page becomes the full facet experience.
   /// The base href works without JS too (it lands on the search page, query empty).
   private static func searchSeeAllHTML(searchPageURL: String, label: String) -> String {
      "<div class=\"sk-docc-search-foot\" data-docc-search-foot hidden>"
         + "<a class=\"sk-docc-search-seeall\" data-docc-search-seeall"
         + " data-docc-search-page-url=\"\(self.escape(searchPageURL))\" href=\"\(self.escape(searchPageURL))\">"
         + label
         + " <span aria-hidden=\"true\">→</span>"
         + "</a>"
         + "</div>"
   }

   /// Renders the brand anchor: 2-tone wordmark (with optional logo image) when `docc.brand`
   /// is configured, or the plain site name as a fallback.
   private static func brandHTML(config: SiteConfig, homeURL: String) -> String {
      let href = self.escape(homeURL)
      if let brand = config.docc?.brand {
         var logo = ""
         if let logoPath = brand.logoPath {
            // Serve the logo from the site's assets root so it resolves on every page depth.
            let logoSrc = self.escape("/assets/\(logoPath)")
            let alt = self.escape("\(brand.prefix)\(brand.accent) logo")
            logo = "<img class=\"sk-docc-brand-logo\" src=\"\(logoSrc)\" alt=\"\(alt)\""
               + self.logoSizeHTML(brand: brand)
               + " aria-hidden=\"true\"/>"
         }
         let prefix = self.escape(brand.prefix)
         let accent = self.escape(brand.accent)
         return "<a class=\"sk-docc-brand\" href=\"\(href)\">"
            + logo
            + "<span class=\"sk-docc-wordmark\">"
            + "<span class=\"sk-docc-brand-1\">\(prefix)</span>"
            + "<span class=\"sk-docc-brand-2\">\(accent)</span>"
            + "</span>"
            + "</a>"
      } else {
         return "<a class=\"sk-docc-brand\" href=\"\(href)\">\(self.escape(config.name))</a>"
      }
   }

   /// Builds the size markup for the brand logo from `brand.logoWidth`/`logoHeight`.
   /// A configured size must beat the stylesheet's `.sk-docc-brand-logo` rule, and HTML
   /// width/height attributes alone cannot do that (presentational attributes lose against
   /// any CSS declaration) – so the override rides on an inline style. The attributes are
   /// still emitted as the browser's intrinsic-size hint at shell level; in default builds
   /// the `ImageResizer` output processor later rewrites those attributes to the actual
   /// image dimensions while the inline style survives untouched. Each dimension is
   /// independent: setting only one overrides just that axis and the stylesheet keeps the
   /// other. Values of zero or below are ignored like nil – `width: 0px` would collapse
   /// the axis and negative CSS lengths are invalid anyway.
   /// Returns an empty string when no usable size is configured, leaving the stylesheet
   /// in charge.
   private static func logoSizeHTML(brand: DocCBrandConfig) -> String {
      var attributes = ""
      var styles: [String] = []
      if let width = brand.logoWidth, width > 0 {
         attributes += " width=\"\(width)\""
         styles.append("width: \(width)px;")
      }
      if let height = brand.logoHeight, height > 0 {
         attributes += " height=\"\(height)\""
         styles.append("height: \(height)px;")
      }
      guard !styles.isEmpty else { return "" }
      return attributes + " style=\"\(styles.joined(separator: " "))\""
   }

   /// Renders the search trigger pill: search icon + label (hidden ≤760px) + ⌘K hint.
   /// Clicking opens the search overlay and focuses its input; the keyboard shortcuts live in docc-search.js.
   private static func searchPillHTML(label: String) -> String {
      // The isMac check in docc-search.js renders ⌘K on macOS / Ctrl+K elsewhere.
      // The pill always shows ⌘K because the site is rendered statically – JS will swap
      // to Ctrl+K at runtime on non-Mac platforms via the data-docc-kbd attribute.
      let safeLabel = self.escape(label)
      return "<button type=\"button\" class=\"sk-docc-search-pill\" data-docc-search-open"
         + " aria-label=\"\(safeLabel)\">"
         + self.searchIcon
         + "<span class=\"sk-docc-search-pill-label\">\(safeLabel)</span>"
         + "<kbd class=\"sk-docc-kbd\" data-docc-kbd aria-hidden=\"true\">⌘K</kbd>"
         + "</button>"
   }

   /// Inline hamburger glyph – no Font Awesome dependency, matching the site's inline-SVG convention.
   static let burgerIcon =
      "<svg width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<line x1=\"3\" y1=\"6\" x2=\"21\" y2=\"6\"/><line x1=\"3\" y1=\"12\" x2=\"21\" y2=\"12\"/>"
         + "<line x1=\"3\" y1=\"18\" x2=\"21\" y2=\"18\"/></svg>"

   /// Inline search magnifying-glass glyph – matches the prototype's 15×15 search icon.
   private static let searchIcon =
      "<svg width=\"15\" height=\"15\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<circle cx=\"11\" cy=\"11\" r=\"7\"/><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/></svg>"

   /// Inline crescent-moon glyph – the static default for the theme toggle, shown while
   /// the page is light (clicking switches to dark). `docc-theme.js` swaps it for the sun
   /// glyph while the page is dark. Matches the stroke-based inline-SVG convention.
   private static let themeMoonIcon =
      "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\"/></svg>"

   /// Inline close (×) glyph for the search overlay's dismiss button.
   private static let closeIcon =
      "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\"/><line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\"/></svg>"

   static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
