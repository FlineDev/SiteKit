import Foundation

/// Renders the dedicated, deep-linkable DocC search page at `/<prefix>/search/`.
///
/// Unlike the ⌘K overlay (a quick-jump modal with no facets and no URL), this is a
/// first-class page you can land on, bookmark, and share with the query and facets
/// baked into the URL: `?q=…&year=wwdc25&type=community&framework=swiftui`. The two
/// share one search index – the overlay's "See all results" footer link deep-links
/// here carrying the current query.
///
/// ## Layout (inside `DocCShell`)
///
/// The shell already supplies the persistent nav sidebar (left column); this page's
/// body is the remaining two columns:
/// ```
/// div.sk-docc-search-page                 ← 2-col grid: filter aside | results main
///   aside.sk-docc-search-aside            ← "FILTER" heading + facet chip groups + clear-all
///     div.sk-docc-search-facet × N        ← one per group (Year, Topic; Note type only when
///                                           `docc.searchNoteTypeFilter` opts in)
///   div.sk-docc-search-main
///     div.sk-docc-search-field            ← big search box (icon + input + clear ✕)
///     div.sk-docc-search-suggest          ← "Try:" chips, shown only while the query is empty
///     p.sk-docc-searchpage-count          ← live "N results" line
///     ul.sk-docc-searchpage-results       ← sk-docc-sessitem rows, rendered client-side
///     div.sk-docc-searchpage-state        ← prompt / loading / zero-state messages
/// ```
///
/// All facets, results, counts, highlighting, and URL synchronisation are handled by
/// `docc-search-page.js` over the shared sharded index; this renderer emits the static
/// shell (data-driven facet chips, suggestion chips, localized strings on data-*
/// attributes) and lets the client hydrate the dynamic parts. With no JS the page still
/// renders the search box, the facet chips, and the suggestion chips as inert markup,
/// and the sidebar still navigates the whole catalog (progressive enhancement).
public struct DocCSearchPage: Page {
   public init() {}

   // MARK: - Page protocol

   /// One synthetic page at slug `search`, emitted only when the catalog has at least one
   /// DocC note (an empty catalog has nothing to search, mirroring `DocCSearchIndexRenderer`).
   public func pages(in context: BuildContext) -> [PageModel] {
      let notes = Self.doccNotes(in: context)
      guard !notes.isEmpty else { return [] }
      return [
         PageModel(
            title: context.uiStrings.string(for: .doccSearch),
            slug: DocCReservedRoutes.searchSlug,
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("search.docc"),
            summary: nil,
            pageType: .staticPage,
            locale: context.config.effectiveDefaultLanguage,
            extensions: ["doccSearchPage": true]
         )
      ]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let notes = Self.doccNotes(in: context)
      let tree = DocCNavigationTree.build(from: notes, urlPrefix: prefix)
      let sidebar = DocCSidebarRenderer.make(from: context).render(tree: tree, currentSlug: page.slug)
      let strings = context.uiStrings

      // Derive the facet value sets present in the catalog so the chips are data-driven
      // (no dead chips for years/frameworks/types that have no notes).
      let records = DocCSearchIndex.build(from: notes, urlPrefix: prefix)
      let years = Self.distinctYears(in: records)
      let frameworks = Self.distinctFrameworks(in: records)
      // The Note-type group is opt-in (`docc.searchNoteTypeFilter`): most catalogs hold a
      // single note type, where the filter is noise. An empty dimension is never emitted by
      // `filterAside`, so gating reduces to handing it an empty list. Result-row badges and
      // the data-* badge labels are NOT gated – rows always show their type.
      let noteTypeFilterEnabled = context.config.docc?.searchNoteTypeFilterEnabled ?? false
      let types = noteTypeFilterEnabled ? Self.distinctNoteTypes(in: records) : []

      let content = "<div class=\"sk-docc-search-page\" data-docc-search-page"
         + " \(Self.dataLabelAttributes(strings: strings))>"
         + self.filterAside(
            years: years,
            frameworks: frameworks,
            frameworkIcons: context.config.docc?.frameworks ?? [:],
            types: types,
            strings: strings
         )
         + self.searchMain(context: context, strings: strings)
         + self.frameworkRegistryJSON(context: context, frameworks: frameworks)
         + "</div>"

      let renderer = OutputFileRenderer(context: context)
      let canonical = "\(context.config.baseURL)\(self.searchPath(prefix: prefix))"
      let head = renderer.buildHead(
         title: "\(strings.string(for: .doccSearch)) · \(context.config.name)",
         description: context.config.description,
         canonicalURL: canonical,
         ogType: "website"
      )
         + "<link rel=\"stylesheet\" href=\"\(DocCStylesheetRenderer.cssURL)\"/>"
         + "<script defer src=\"\(DocCSearchPageScriptRenderer.scriptURL)\"></script>"

      return DocCShell.wrap(content: content, sidebar: sidebar, toc: nil, page: page, context: context, head: head)
   }

   /// Writes the page to `<outputDir>/<prefix>/search/index.html`.
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let relative = self.searchPath(prefix: prefix).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }

   // MARK: - Filter aside

   /// Builds the FILTER aside: a heading plus one facet group per non-empty dimension,
   /// then a hidden "Clear filters" button the client reveals once a facet is active.
   func filterAside(
      years: [String],
      frameworks: [String],
      frameworkIcons: [String: DocCFrameworkIcon],
      types: [DocCNoteType],
      strings: UIStrings
   ) -> String {
      var groups = ""

      if !years.isEmpty {
         let chips = years.map { year in
            self.facetChip(facet: "year", value: year, label: year.uppercased())
         }
         groups += self.facetGroup(facet: "year", label: strings.string(for: .doccSearchFacetYear), chips: chips, strings: strings)
      }

      if !types.isEmpty {
         let chips = types.map { type in
            self.facetChip(facet: "type", value: type.rawValue, label: Self.noteTypeLabel(type, strings: strings))
         }
         groups += self.facetGroup(facet: "type", label: strings.string(for: .doccSearchFacetType), chips: chips, strings: strings)
      }

      if !frameworks.isEmpty {
         let chips = frameworks.map { key in
            // Only the visible label prefers the configured displayName; the chip value (and
            // with it the ?framework= URL param, JS filtering, and the color registry) stays
            // the raw key so deep links and client lookups are unaffected by label changes.
            self.facetChip(facet: "framework", value: key, label: frameworkIcons[key]?.displayName ?? key)
         }
         groups += self.facetGroup(facet: "framework", label: strings.string(for: .doccSearchFacetFramework), chips: chips, strings: strings)
      }

      let clearLabel = Self.escape(strings.string(for: .doccSearchClearFilters))
      let aside = "<aside class=\"sk-docc-search-aside\" aria-label=\"\(Self.escape(strings.string(for: .doccSearchFilterHeading)))\">"
         + "<h2 class=\"sk-docc-search-aside-title\">\(Self.escape(strings.string(for: .doccSearchFilterHeading)))</h2>"
         + groups
         + "<button type=\"button\" class=\"sk-docc-search-clear\" data-docc-search-clear hidden>\(clearLabel)</button>"
         + "</aside>"
      return aside
   }

   /// One facet group: a label and a chip row that starts with an "All" chip (active by
   /// default) followed by the value chips. Each chip carries a live-count slot the client fills.
   private func facetGroup(facet: String, label: String, chips: [String], strings: UIStrings) -> String {
      let allChip = "<button type=\"button\" class=\"sk-docc-facet-chip is-active\""
         + " data-docc-facet=\"\(Self.escape(facet))\" data-docc-facet-value=\"\" aria-pressed=\"true\">"
         + "<span class=\"sk-docc-facet-chip-label\">\(Self.escape(strings.string(for: .doccSearchFacetAll)))</span>"
         + "<span class=\"sk-docc-facet-count\" data-docc-facet-count></span>"
         + "</button>"
      return "<div class=\"sk-docc-search-facet\" data-docc-facet-group=\"\(Self.escape(facet))\">"
         + "<span class=\"sk-docc-search-facet-label\">\(Self.escape(label))</span>"
         + "<div class=\"sk-docc-search-chips\">\(allChip)\(chips.joined())</div>"
         + "</div>"
   }

   /// One value chip inside a facet group.
   private func facetChip(facet: String, value: String, label: String) -> String {
      "<button type=\"button\" class=\"sk-docc-facet-chip\""
         + " data-docc-facet=\"\(Self.escape(facet))\" data-docc-facet-value=\"\(Self.escape(value))\" aria-pressed=\"false\">"
         + "<span class=\"sk-docc-facet-chip-label\">\(Self.escape(label))</span>"
         + "<span class=\"sk-docc-facet-count\" data-docc-facet-count></span>"
         + "</button>"
   }

   // MARK: - Search main

   /// Builds the results main column: the big search field, the suggestion chips,
   /// a count line, the results list, and a state container.
   func searchMain(context: BuildContext, strings: UIStrings) -> String {
      let placeholder = Self.escape(strings.string(for: .doccSearchPlaceholder))
      let label = Self.escape(strings.string(for: .doccSearch))
      let countTemplate = Self.escape(strings.string(for: .doccSearchResultCount))
      let emptyTitle = Self.escape(strings.string(for: .doccSearchNoMatches))
      let emptyBody = Self.escape(strings.string(for: .doccSearchNoMatchesFilters))
      let prompt = Self.escape(strings.string(for: .doccSearchPrompt))
      let loading = Self.escape(strings.string(for: .doccSearchLoading))
      let clearLabel = Self.escape(strings.string(for: .doccSearchClose))

      let field = "<div class=\"sk-docc-search-field sk-docc-searchpage-field\">"
         + Self.searchIcon
         + "<input class=\"sk-docc-searchpage-input\" type=\"search\" autocomplete=\"off\""
         + " placeholder=\"\(placeholder)\" aria-label=\"\(label)\""
         + " data-docc-search-count=\"\(countTemplate)\""
         + " data-docc-search-empty-title=\"\(emptyTitle)\""
         + " data-docc-search-empty-body=\"\(emptyBody)\""
         + " data-docc-search-prompt=\"\(prompt)\""
         + " data-docc-search-loading=\"\(loading)\"/>"
         + "<button type=\"button\" class=\"sk-docc-search-close\" data-docc-searchpage-clear-query aria-label=\"\(clearLabel)\" hidden>"
         + Self.closeIcon
         + "</button>"
         + "</div>"

      // "Try:" suggestion chips (server-rendered from config), shown while the query is empty.
      var suggestHTML = ""
      if let suggestions = context.config.docc?.searchSuggestions, !suggestions.isEmpty {
         let tryLabel = Self.escape(strings.string(for: .doccSearchTry))
         let chips = suggestions.map { term in
            "<button type=\"button\" class=\"sk-docc-search-chip\" data-docc-search-suggest=\"\(Self.escape(term))\">"
               + Self.escape(term)
               + "</button>"
         }.joined()
         suggestHTML = "<div class=\"sk-docc-search-suggest\" data-docc-searchpage-suggest>"
            + "<span class=\"sk-docc-search-try\">\(tryLabel)</span>"
            + chips
            + "</div>"
      }

      // The state container starts with the prompt; the client swaps in loading / zero-state.
      let state = "<div class=\"sk-docc-searchpage-state\" data-docc-searchpage-state>"
         + "<p class=\"sk-docc-searchpage-prompt\">\(prompt)</p>"
         + "</div>"

      return "<div class=\"sk-docc-search-main\">"
         + field
         + suggestHTML
         + "<p class=\"sk-docc-searchpage-count\" data-docc-searchpage-count hidden aria-live=\"polite\"></p>"
         + "<ul class=\"sk-docc-searchpage-results sk-docc-sesslist\" data-docc-searchpage-results hidden></ul>"
         + state
         + "</div>"
   }

   // MARK: - Framework color registry

   /// Emits the framework → gradient-colors map as inline JSON so the client can render a
   /// colored icon square for each result row. FontAwesome glyphs are inlined as SVG at
   /// build time over static HTML, so a client-rendered row cannot carry an FA glyph;
   /// a color square keyed by framework is the faithful, dependency-free stand-in.
   func frameworkRegistryJSON(context: BuildContext, frameworks: [String]) -> String {
      let icons = context.config.docc?.frameworks ?? [:]
      var registry: [String: [String]] = [:]
      for key in frameworks {
         if let colors = icons[key]?.colors, !colors.isEmpty {
            registry[key] = colors
         }
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

   // MARK: - data-* label attributes

   /// The localized note-type badge labels, carried on the page root so the client can
   /// label result-row badges without bundling any English strings.
   static func dataLabelAttributes(strings: UIStrings) -> String {
      "data-docc-label-ai=\"\(escape(noteTypeLabel(.ai, strings: strings)))\""
         + " data-docc-label-community=\"\(escape(noteTypeLabel(.community, strings: strings)))\""
         + " data-docc-label-stub=\"\(escape(noteTypeLabel(.stub, strings: strings)))\""
   }

   // MARK: - Facet value extraction

   /// Distinct WWDC year keys present in the records, newest first.
   static func distinctYears(in records: [DocCSearchRecord]) -> [String] {
      var seen = Set<String>()
      var years: [String] = []
      for record in records {
         guard let year = record.year, seen.insert(year).inserted else { continue }
         years.append(year)
      }
      return years.sorted(by: >)
   }

   /// Distinct framework keys present in the records, alphabetically.
   static func distinctFrameworks(in records: [DocCSearchRecord]) -> [String] {
      var seen = Set<String>()
      for record in records {
         if let framework = record.framework { seen.insert(framework) }
      }
      return seen.sorted()
   }

   /// Distinct note types present in the records, in the fixed AI → Community → Stub order.
   static func distinctNoteTypes(in records: [DocCSearchRecord]) -> [DocCNoteType] {
      let present = Set(records.map(\.noteType))
      return [.ai, .community, .stub].filter { present.contains($0) }
   }

   /// The short display label for a note type, used by the facet chips and the page root's
   /// data-* badge labels.
   static func noteTypeLabel(_ type: DocCNoteType, strings: UIStrings) -> String {
      switch type {
      case .ai: return strings.string(for: .doccSearchTypeAI)
      case .community: return strings.string(for: .doccSearchTypeCommunity)
      case .stub: return strings.string(for: .doccSearchTypeStub)
      }
   }

   // MARK: - Helpers

   static func doccNotes(in context: BuildContext) -> [PageModel] {
      context.sections.flatMap(\.pages).filter { ($0.extensions["doccNote"] as? Bool) == true }
   }

   func searchPath(prefix: String) -> String {
      let clean = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return clean.isEmpty ? "/\(DocCReservedRoutes.searchSlug)/" : "/\(clean)/\(DocCReservedRoutes.searchSlug)/"
   }

   /// Inline search magnifying-glass glyph – matches the overlay's icon.
   static let searchIcon =
      "<svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
         + "<circle cx=\"11\" cy=\"11\" r=\"7\"/><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/></svg>"

   /// Inline close (×) glyph for the search field's clear button.
   static let closeIcon =
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
