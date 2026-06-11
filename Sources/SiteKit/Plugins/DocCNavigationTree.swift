import Foundation

/// A named group of session slugs parsed from a `### Heading` + `@Links` pair in a year
/// overview note's `## Topics` section. Used by `DocCYearListingPage` to render grouped
/// session lists instead of one flat list.
struct DocCTopicGroup: Equatable, Sendable {
   let title: String
   let slugs: [String]

   init(title: String, slugs: [String]) {
      self.title = title
      self.slugs = slugs
   }
}

/// One external link parsed from a contributor profile note's `## Links` section
/// (e.g. `* [Blog](https://example.com)`). `label` is the visible link text ("Blog",
/// "X/Twitter") and `url` is its destination. Populated by `DocCLoader` on notes that
/// live under a `Contributors/` directory and consumed by `DocCContributorPage`.
struct DocCContributorLink: Equatable, Sendable {
   let label: String
   let url: String

   init(label: String, url: String) {
      self.label = label
      self.url = url
   }
}

/// A node in the DocC sidebar navigation tree. A year node has session children;
/// a session (or a loose page) is a leaf.
struct DocCNavNode: Equatable, Sendable {
   let title: String
   let url: String
   let children: [DocCNavNode]
   /// The framework key for this session (e.g. "swiftui"), looked up in DocCConfig.frameworks.
   /// Nil for year nodes and pages with no framework field.
   let framework: String?
   /// URL of a glyph image for a year row, resolved from @PageImage(purpose: icon).
   /// Nil for non-year nodes or year nodes with no icon PageImage.
   let glyphImageURL: String?
   /// True when this session note is a stub (abstract-only placeholder, no real notes yet).
   let isStub: Bool
   /// Topic subgroups for the active year, keyed by group title in declaration order.
   /// Only populated on a year node whose children are grouped; empty otherwise.
   let topicSubgroups: [DocCTopicGroup]
   /// True when this node is a curated loose-page group (a labelled bucket of guide/article
   /// leaves curated via a `## Topics` `### Heading`), NOT a year branch. A group node carries
   /// its leaves in `children` but has an empty `url` and must never be treated as a year (no
   /// twist/​hydration, no year card, no nav-JSON branch). Year detection elsewhere keys on
   /// `children` being non-empty, so every such site must additionally exclude `isGroup` nodes.
   let isGroup: Bool

   init(
      title: String,
      url: String,
      children: [DocCNavNode] = [],
      framework: String? = nil,
      glyphImageURL: String? = nil,
      isStub: Bool = false,
      topicSubgroups: [DocCTopicGroup] = [],
      isGroup: Bool = false
   ) {
      self.title = title
      self.url = url
      self.children = children
      self.framework = framework
      self.glyphImageURL = glyphImageURL
      self.isStub = isStub
      self.topicSubgroups = topicSubgroups
      self.isGroup = isGroup
   }
}

/// Builds the flat 2-level Year → Session navigation tree for a DocC catalog from
/// the loaded pages.
///
/// The hierarchy comes from the slug: a year overview has slug `wwdc<year>`
/// (e.g. `wwdc24`), a session has `wwdc<year>-<id>-…`. Years are listed
/// newest-first; sessions within a year are sorted by slug. Pages that match no
/// WWDC pattern (e.g. a `Contributing` page) become top-level leaves after the
/// years. `sessions.json` carries no topic/track field, so the tree is
/// deliberately two levels deep – no third grouping is possible.
enum DocCNavigationTree {
   static func build(from pages: [PageModel], urlPrefix: String) -> [DocCNavNode] {
      let prefix = urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      func url(forSlug slug: String) -> String {
         prefix.isEmpty ? "/\(slug)/" : "/\(prefix)/\(slug)/"
      }

      var yearOverviews: [String: PageModel] = [:]
      var sessionsByYear: [String: [PageModel]] = [:]
      var loosePages: [PageModel] = []

      for page in pages {
         // Generated contributor profile notes (`Contributors/<handle>.md`) are represented by
         // the Contributors subtree (built from the aggregated handle list), so they never become
         // flat article leaves. Dropping them here is what clears the per-contributor flood out of
         // the loose "Articles" list.
         if (page.extensions["doccContributorProfile"] as? Bool) == true { continue }

         guard let yearKey = Self.yearKey(of: page.slug) else {
            loosePages.append(page)
            continue
         }
         if page.slug == yearKey {
            yearOverviews[yearKey] = page
         } else {
            sessionsByYear[yearKey, default: []].append(page)
         }
      }

      let years = Set(yearOverviews.keys).union(sessionsByYear.keys).sorted(by: >)
      var nodes: [DocCNavNode] = years.map { yearKey in
         let yearPage = yearOverviews[yearKey]
         let sortedSessions = (sessionsByYear[yearKey] ?? []).sorted { $0.slug < $1.slug }

         // Build a slug→framework+isStub lookup so the navigation tree carries rich metadata
         // without duplicating all of PageModel. Only the per-session fields (framework,
         // isStub) are promoted; the year glyph comes from the year overview's extensions.
         let sessionNodes: [DocCNavNode] = sortedSessions.map { session in
            let framework = session.extensions["doccFramework"] as? String
            let isStub = session.extensions["doccIsStub"] as? Bool ?? false
            return DocCNavNode(
               title: session.title,
               url: url(forSlug: session.slug),
               framework: framework,
               isStub: isStub
            )
         }

         // Year glyph: declared via @PageImage(purpose: icon) in the year overview.
         // The loader stores the resolved asset path in "doccNavIconURL".
         let glyphImageURL = yearPage?.extensions["doccNavIconURL"] as? String

         // Topic subgroups from the year overview's ## Topics section, for sidebar grouping.
         let topicSubgroups = yearPage?.extensions["doccTopicGroups"] as? [DocCTopicGroup] ?? []

         return DocCNavNode(
            title: yearPage?.title ?? yearKey.uppercased(),
            url: url(forSlug: yearKey),
            children: sessionNodes,
            glyphImageURL: glyphImageURL,
            topicSubgroups: topicSubgroups
         )
      }

      // Curate loose pages via `## Topics` groups declared on a loose index/root page: a loose
      // page listed under a `### GroupTitle` (e.g. "Guides") nests under a labelled group instead
      // of dangling in the flat list, mirroring real Swift-DocC's `## Topics` curation. Only loose
      // pages' topic groups are read and only loose pages are pulled into groups, so year/​session
      // grouping is untouched and curated years/​sessions (if any are listed) keep their own home.
      let looseBySlug = Dictionary(loosePages.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
      var groupOrder: [String] = []                 // group titles in first-seen order
      var groupMembers: [String: [PageModel]] = [:] // group title → curated loose pages
      var curatedSlugs = Set<String>()              // loose pages claimed by some group
      var curationSourceSlugs = Set<String>()       // loose pages that declare a ## Topics curation

      for source in loosePages.sorted(by: { $0.slug < $1.slug }) {
         guard let topicGroups = source.extensions["doccTopicGroups"] as? [DocCTopicGroup] else { continue }
         // A loose page that curates others via `## Topics` is the catalog/module root or a
         // collection index – structural chrome, not a leaf article. Record it so the flat-leaf
         // pass below skips it; otherwise it dangles in the catch-all list (e.g. the `WWDCNotes`
         // root note showing up as a stray Articles entry).
         curationSourceSlugs.insert(source.slug)
         for group in topicGroups {
            for slug in group.slugs {
               guard let page = looseBySlug[slug], !curatedSlugs.contains(slug), page.slug != source.slug else { continue }
               if groupMembers[group.title] == nil { groupOrder.append(group.title) }
               groupMembers[group.title, default: []].append(page)
               curatedSlugs.insert(slug)
            }
         }
      }

      // Group nodes come after the years, in first-seen declaration order. Each group's children
      // keep the order the author declared in the `## Topics` block (the order slugs were
      // accumulated above), matching how the active year's inner topic subgroups render. This is
      // still deterministic – it comes straight from the `.md` Topics block – just author-curated
      // rather than alphabetical.
      for title in groupOrder {
         let children = (groupMembers[title] ?? [])
            .map { DocCNavNode(title: $0.title, url: url(forSlug: $0.slug)) }
         guard !children.isEmpty else { continue }
         nodes.append(DocCNavNode(title: title, url: "", children: children, isGroup: true))
      }

      // Remaining uncurated loose pages stay as flat top-level leaves after the groups. A curation
      // source (a `## Topics` root/index page) is excluded: it is structural chrome, reached via
      // its groups and the home page, not a standalone article leaf.
      nodes += loosePages
         .filter { !curatedSlugs.contains($0.slug) && !curationSourceSlugs.contains($0.slug) }
         .sorted { $0.slug < $1.slug }
         .map { DocCNavNode(title: $0.title, url: url(forSlug: $0.slug)) }
      return nodes
   }

   /// The `wwdc<digits>` year key at the start of a slug, or nil for non-WWDC slugs.
   static func yearKey(of slug: String) -> String? {
      guard let match = slug.firstMatch(of: #/^wwdc\d{2}/#) else { return nil }
      return String(slug[match.range])
   }
}
