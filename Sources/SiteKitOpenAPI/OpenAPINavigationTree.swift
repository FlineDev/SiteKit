import Foundation
import SiteKit

/// The navigation-tree data model for the OpenAPI sidebar: an ordered list of
/// groups, each a tag (or the synthetic Schemas group) holding its navigable items.
///
/// Built purely from ``OpenAPISpec`` (no `import OpenAPIKit`), so the rail mirrors
/// the tag pages and schema pages exactly – including the cross-listing rule, where a
/// multi-tag operation appears under every tag it carries, each entry linking to its
/// one canonical operation page. Mirrors `DocCNavigationTree` (a phase-independent
/// builder the sidebar renderer consumes), kept deliberately flat: the API graph is
/// two levels (tag → operation, plus a flat Schemas group), so no deeper nesting.
enum OpenAPINavigationTree {
   /// One navigable leaf: an operation (carrying its HTTP `method`) or a schema
   /// (`method` is nil). `url` is the page it links to; `isDeprecated` drives the
   /// dimming hook the stylesheet targets.
   struct Item: Equatable {
      /// The compact nav label (operation summary / id, or schema name).
      let title: String

      /// The page this item links to (an operation's canonical page, or a schema page).
      let url: String

      /// The uppercased HTTP method for an operation item; nil for a schema item.
      let method: String?

      /// Whether the underlying operation or schema is marked `deprecated`.
      let isDeprecated: Bool

      /// Whether this entry is the operation's canonical occurrence (under its first
      /// tag). A cross-listed entry on a secondary tag is non-canonical; only the
      /// canonical occurrence is marked `aria-current` on the operation's own page, so
      /// a page advertises exactly one current item. Always true for schema items.
      let isCanonical: Bool
   }

   /// One group: a tag (its header links to the tag page) or the Schemas group (which
   /// has no index page, so `url` is nil and the header is a plain label).
   struct Group: Equatable {
      /// The group title (the tag name, or `Schemas`).
      let title: String

      /// The page the group header links to, or nil for a non-navigable label.
      let url: String?

      /// The group's navigable items, in document order.
      let items: [Item]
   }

   /// Builds the ordered group list: one group per tag (in ``OpenAPIRoutes/tagSections(_:)``
   /// order, so the rail matches the tag pages and landing cards, cross-listing
   /// included), then a Schemas group listing every component schema. Returns an empty
   /// list when the spec declares no operations and no schemas.
   static func build(_ spec: OpenAPISpec, context: BuildContext) -> [Group] {
      var groups: [Group] = OpenAPIRoutes.tagSections(spec).map { section in
         let items = section.operations.map { ref in
            Item(
               title: Self.operationTitle(ref.operation),
               url: OpenAPIRoutes.operationPath(context, tagSlug: ref.canonicalTagSlug, operationSlug: ref.slug),
               method: ref.operation.method,
               isDeprecated: ref.operation.deprecated,
               isCanonical: ref.isCanonical
            )
         }
         return Group(
            title: section.tag.name,
            url: OpenAPIRoutes.tagPath(context, tagSlug: section.slug),
            items: items
         )
      }

      if !spec.schemas.isEmpty {
         let items = spec.schemas.map { schema in
            Item(
               title: schema.name,
               url: OpenAPIRoutes.schemaPath(context, schemaSlug: OpenAPIRoutes.schemaSlug(for: schema.name, in: spec)),
               method: nil,
               isDeprecated: schema.schema.deprecated,
               isCanonical: true
            )
         }
         // There is no `/schemas/` index page in this design, so the group header is a
         // plain label (url nil); each item still links to its own schema page.
         groups.append(Group(title: "Schemas", url: nil, items: items))
      }

      return groups
   }

   /// The compact nav label for an operation: its summary when present (matching the
   /// operation page's H1), otherwise its `operationId`, falling back to
   /// `"<method> <path>"`. A long summary is clipped to one line with an ellipsis by
   /// the stylesheet, with the full text on the link's `title` tooltip.
   private static func operationTitle(_ operation: OpenAPISpec.Operation) -> String {
      if let summary = operation.summary, !summary.isEmpty {
         return summary
      }
      if let operationId = operation.operationId, !operationId.isEmpty {
         return operationId
      }
      return "\(operation.method) \(operation.path)"
   }
}
