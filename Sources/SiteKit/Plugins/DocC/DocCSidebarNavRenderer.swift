import Foundation

/// Global renderer that emits `/assets/docc-sidebar-nav.json`: a compact, machine-readable dump
/// of every year branch's sessions so the sidebar can lazy-hydrate a non-active year's subtree on
/// first twist-open without navigating – and without shipping all sessions into every page's HTML.
///
/// The active-branch-only DOM (see `DocCSidebarRenderer`) keeps each page light by emitting only
/// the current year's sessions. That leaves a non-active year's twist with nothing local to open.
/// Rather than dumping every year onto every page (~+350 KB of HTML/page), the client fetches this
/// single file once (cached across the whole visit) and hydrates a subtree only when the reader
/// first twists it open.
///
/// The tree is built from the SAME `DocCNavigationTree.build` output the DocC page renderers use
/// (identical page set + url prefix), so the JSON mirrors exactly what the sidebar would have
/// server-rendered for that year – same nodes, slugs, order, and grouping. Only year branches are
/// included; Contributors is always fully server-rendered from the aggregated contributors list
/// and is never hydrated, so it is deliberately absent here.
///
/// Shape (object keys sorted for stable, diff-friendly output):
/// ```json
/// {
///   "wwdc24": {
///     "groups": [{ "title": "Essentials", "slugs": ["wwdc24-101-foo"] }],
///     "sessions": {
///       "wwdc24-101-foo": { "title": "Foo", "url": "/documentation/wwdc24-101-foo/", "framework": "swiftui", "isStub": false }
///     }
///   }
/// }
/// ```
/// `groups` preserves the year overview's topic-subgroup declaration order; an empty array means
/// the year has no subgroups and the client renders `sessions` flat, in sorted-slug order (which
/// equals the renderer's slug-sorted children order). `framework` may be null; `isStub` is a bool.
public struct DocCSidebarNavRenderer: Renderer {
   /// One file per build – the JSON is locale-agnostic and cached across every page of the visit.
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      // Reuse the exact plumbing the DocC pages use to build their sidebar tree: all DocC notes
      // plus the first section's url prefix → DocCNavigationTree.build. This guarantees the JSON
      // matches the sidebar the renderer would produce (same nodes, slugs, and order).
      let prefix = context.config.effectiveSections.first?.urlPrefix ?? "documentation"
      let allNotes = context.sections.flatMap(\.pages).filter {
         ($0.extensions["doccNote"] as? Bool) == true
      }
      let tree = DocCNavigationTree.build(from: allNotes, urlPrefix: prefix)

      var years: [String: Any] = [:]
      for node in tree {
         let nodeSlug = DocCSidebarRenderer.slug(fromURL: node.url)
         // Year detection mirrors DocCSidebarRenderer.render exactly: a node is a year when it has
         // session children OR its slug is itself a year key (an empty year). Loose nodes – the
         // Contributors index, contributor detail pages, Contributing, the catalog index – are not
         // years and are skipped; they are never hydrated.
         let isYear = !node.isGroup && (!node.children.isEmpty || DocCNavigationTree.yearKey(of: nodeSlug) == nodeSlug)
         guard isYear else { continue }

         // Sessions keyed by slug, derived from the child url the same way the renderer does
         // (last path component), so the keys line up with the topic-subgroup slugs and with
         // `data-docc-branch-sessions` / `data-docc-unhydrated` in the HTML.
         var sessions: [String: Any] = [:]
         for child in node.children {
            let slug = DocCSidebarRenderer.slug(fromURL: child.url)
            // `framework` is nullable; encode a real JSON null (NSNull) when absent rather than
            // dropping the key, so the client can rely on the field always being present.
            let framework: Any = child.framework ?? NSNull()
            sessions[slug] = [
               "title": child.title,
               "url": child.url,
               "framework": framework,
               "isStub": child.isStub,
            ]
         }

         // Topic subgroups → ordered groups (title + slugs). JSONSerialization preserves array
         // order, so declaration order survives; only object keys are sorted by `.sortedKeys`.
         let groups: [[String: Any]] = node.topicSubgroups.map { group in
            ["title": group.title, "slugs": group.slugs]
         }

         years[nodeSlug] = ["groups": groups, "sessions": sessions]
      }

      // `.sortedKeys` makes the output deterministic (stable byte-diff + reproducible tests);
      // pretty-printing keeps it human-readable when inspecting the built site.
      let data = try JSONSerialization.data(withJSONObject: years, options: [.sortedKeys, .prettyPrinted])
      let outputPath = context.outputDirectory.appendingPathComponent("assets/docc-sidebar-nav.json")
      return [OutputFile(outputPath: outputPath, content: String(decoding: data, as: UTF8.self))]
   }
}
