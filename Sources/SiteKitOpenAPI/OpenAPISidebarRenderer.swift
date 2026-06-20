import Foundation
import SiteKit

/// Emits the persistent left-rail navigation tree shared by every OpenAPI page: a
/// landing link at the top, one group per tag (header → tag page) listing that tag's
/// operations (method badge + name → operation page), and a Schemas group listing
/// every schema. Mirrors `DocCSidebarRenderer`: it takes the current page's path and
/// marks the matching item `aria-current="page"` with an `is-active` class.
///
/// Semantic HTML only this slice – the stylesheet and the collapse/expand script are
/// a later slice (the DocC parallel is `DocCSidebarScriptRenderer`; no `<script>` is
/// emitted here). The `sk-openapi-nav-*` classes plus the `data-method` /
/// `data-deprecated` hooks are exactly what that stylesheet and script will target.
///
/// Built from ``OpenAPISpec`` only (no `import OpenAPIKit`), so the rail stays in step
/// with the tag and schema pages, cross-listing included (a multi-tag operation
/// appears under every tag it carries, each linking to its one canonical page).
enum OpenAPISidebarRenderer {
   /// Renders the `<nav>` rail for `spec`, marking the item whose URL equals
   /// `currentPath` as the active page.
   static func render(spec: OpenAPISpec, context: BuildContext, currentPath: String) -> String {
      let groups = OpenAPINavigationTree.build(spec, context: context)

      var html = "<nav class=\"sk-openapi-nav\" aria-label=\"API navigation\">"
      html += Self.homeLinkHTML(spec: spec, context: context, currentPath: currentPath)
      if !groups.isEmpty {
         html += "<ul class=\"sk-openapi-nav-groups\">"
         html += groups.map { Self.groupHTML($0, currentPath: currentPath) }.joined()
         html += "</ul>"
      }
      html += "</nav>"
      return html
   }

   /// The top-of-rail link back to the landing page, marked active on the landing page.
   private static func homeLinkHTML(spec: OpenAPISpec, context: BuildContext, currentPath: String) -> String {
      let url = OpenAPIRoutes.landingPath(context)
      let active = url == currentPath
      return "<a class=\"sk-openapi-nav-home\(active ? " is-active" : "")\" href=\"\(OpenAPIHTML.escape(url))\"\(Self.currentAttribute(active))>"
         + OpenAPIHTML.escape(spec.info.title)
         + "</a>"
   }

   /// One group: its header (a tag-page link, or a plain label for Schemas) plus the
   /// nested list of its items.
   private static func groupHTML(_ group: OpenAPINavigationTree.Group, currentPath: String) -> String {
      var html = "<li class=\"sk-openapi-nav-group\">"
      html += Self.groupHeaderHTML(group, currentPath: currentPath)
      if !group.items.isEmpty {
         html += "<ul class=\"sk-openapi-nav-items\">"
         html += group.items.map { Self.itemHTML($0, currentPath: currentPath) }.joined()
         html += "</ul>"
      }
      html += "</li>"
      return html
   }

   private static func groupHeaderHTML(_ group: OpenAPINavigationTree.Group, currentPath: String) -> String {
      let title = OpenAPIHTML.escape(group.title)
      guard let url = group.url else {
         // A group with no index page (Schemas) renders a plain, non-link label.
         return "<span class=\"sk-openapi-nav-group-title\">\(title)</span>"
      }
      let active = url == currentPath
      return
         "<a class=\"sk-openapi-nav-group-title\(active ? " is-active" : "")\" href=\"\(OpenAPIHTML.escape(url))\"\(Self.currentAttribute(active))>\(title)</a>"
   }

   /// One leaf item: the method badge (operations only) plus the label, linking to the
   /// item's page. The `<li>` carries `data-method` and the deprecated hook so the
   /// stylesheet can color the verb and dim a deprecated row.
   private static func itemHTML(_ item: OpenAPINavigationTree.Item, currentPath: String) -> String {
      let active = item.url == currentPath
      // Highlight every occurrence at the current path, but emit aria-current only on
      // the canonical occurrence, so a cross-listed operation marks exactly one current
      // item per page (a11y) while both occurrences still read as active.
      let current = active && item.isCanonical
      var attributes = ""
      if let method = item.method {
         attributes += " data-method=\"\(OpenAPIHTML.escape(method.lowercased()))\""
      }
      if item.isDeprecated {
         attributes += " data-deprecated=\"true\""
      }
      let badge = item.method.map { OpenAPIBadges.methodBadge($0) } ?? ""
      // The full label is on the link's title attribute so a summary clipped to one line
      // (text-overflow: ellipsis) is still readable on hover.
      let label = OpenAPIHTML.escape(item.title)
      return "<li class=\"sk-openapi-nav-item\"\(attributes)>"
         + "<a class=\"sk-openapi-nav-link\(active ? " is-active" : "")\" href=\"\(OpenAPIHTML.escape(item.url))\" title=\"\(label)\"\(Self.currentAttribute(current))>"
         + badge
         + "<span class=\"sk-openapi-nav-label\">\(label)</span>"
         + "</a>"
         + "</li>"
   }

   /// The `aria-current="page"` attribute (with a leading space) when active, else empty.
   private static func currentAttribute(_ active: Bool) -> String {
      active ? " aria-current=\"page\"" : ""
   }
}
