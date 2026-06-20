import Foundation
import SiteKit

/// The deep-linkable URL scheme for the OpenAPI docs site, plus the slug helpers
/// the page renderers share so paths stay consistent across landing, tag,
/// operation, and schema pages.
///
/// Every page lives under the configured section `urlPrefix` (default `api`):
/// - Landing: `/<prefix>/`
/// - Tag page: `/<prefix>/<tag-slug>/`
/// - Operation page: `/<prefix>/<tag-slug>/<operation-slug>/`
/// - Schema page: `/<prefix>/schemas/<schema-slug>/`
///
/// Paths are stable (they become external deep links and SEO canonicals in a
/// later slice), so the slug rules here are the single source of truth.
enum OpenAPIRoutes {
   /// The cleaned section URL prefix (no leading/trailing slashes), defaulting to
   /// `api` when the site declares no section.
   static func prefix(_ context: BuildContext) -> String {
      let raw = context.config.effectiveSections.first?.urlPrefix ?? "api"
      return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
   }

   /// The tag an untagged operation is grouped under, so no operation is dropped.
   static let defaultTag = "general"

   /// Lowercases and hyphenates an arbitrary string into a URL-safe slug: runs of
   /// non-alphanumeric characters collapse to a single hyphen, and leading/trailing
   /// hyphens are trimmed (so `"/pets/{petId}"` becomes `"pets-petid"`).
   static func slugify(_ string: String) -> String {
      let lowered = string.lowercased()
      var slug = ""
      var lastWasHyphen = false
      for character in lowered {
         if character.isLetter || character.isNumber {
            slug.append(character)
            lastWasHyphen = false
         } else if !lastWasHyphen {
            slug.append("-")
            lastWasHyphen = true
         }
      }
      return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
   }

   /// The slug for a tag name.
   static func tagSlug(_ tag: String) -> String {
      self.slugify(tag)
   }

   /// The tag an operation is canonically grouped under: its first declared tag,
   /// or ``defaultTag`` when it has none.
   static func canonicalTag(for operation: OpenAPISpec.Operation) -> String {
      operation.tags.first ?? self.defaultTag
   }

   /// The slug for an operation: its `operationId` when present, otherwise a
   /// `<method>-<path>` slug (so every operation has a stable, unique-enough slug).
   static func operationSlug(for operation: OpenAPISpec.Operation) -> String {
      if let operationId = operation.operationId, !operationId.isEmpty {
         return self.slugify(operationId)
      }
      return self.slugify("\(operation.method)-\(operation.path)")
   }

   /// The slug for a component schema name.
   static func schemaSlug(_ name: String) -> String {
      self.slugify(name)
   }

   /// `/<prefix>/` – the landing page.
   static func landingPath(_ context: BuildContext) -> String {
      "/\(self.prefix(context))/"
   }

   /// `/<prefix>/<tag-slug>/` – a tag page.
   static func tagPath(_ context: BuildContext, tagSlug: String) -> String {
      "/\(self.prefix(context))/\(tagSlug)/"
   }

   /// `/<prefix>/<tag-slug>/<operation-slug>/` – an operation page.
   static func operationPath(_ context: BuildContext, tagSlug: String, operationSlug: String) -> String {
      "/\(self.prefix(context))/\(tagSlug)/\(operationSlug)/"
   }

   /// `/<prefix>/schemas/<schema-slug>/` – a schema page.
   static func schemaPath(_ context: BuildContext, schemaSlug: String) -> String {
      "/\(self.prefix(context))/schemas/\(schemaSlug)/"
   }

   /// Groups the spec's operations by their canonical tag (first declared tag, or
   /// ``defaultTag`` when untagged), so the landing, tag pages, and operation URLs
   /// all agree on which tag owns an operation.
   ///
   /// Order: declared tags in document order first, then any extra tag only an
   /// operation introduces, then the synthetic `general` group. A declared tag that
   /// owns no operation is omitted (no empty group). Each group's `tag` carries the
   /// declared description where one exists.
   static func tagGroups(_ spec: OpenAPISpec) -> [(tag: OpenAPISpec.Tag, operations: [OpenAPISpec.Operation])] {
      var order: [String] = spec.tags.map(\.name)
      var descriptions: [String: String?] = [:]
      for tag in spec.tags {
         descriptions[tag.name] = tag.description
      }

      var operationsByTag: [String: [OpenAPISpec.Operation]] = [:]
      for operation in spec.operations {
         let tag = self.canonicalTag(for: operation)
         operationsByTag[tag, default: []].append(operation)
         if !order.contains(tag) {
            order.append(tag)
         }
      }

      return order.compactMap { name in
         guard let operations = operationsByTag[name], !operations.isEmpty else { return nil }
         let tag = OpenAPISpec.Tag(name: name, description: descriptions[name] ?? nil)
         return (tag, operations)
      }
   }

   /// Maps a site-relative path (`/api/pets/`) to its `index.html` file URL under
   /// the build output directory.
   static func outputURL(for path: String, context: BuildContext) -> URL {
      var relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
      if relative.hasSuffix("/") { relative = String(relative.dropLast()) }
      if relative.isEmpty {
         return context.outputDirectory.appendingPathComponent("index.html")
      }
      return context.outputDirectory
         .appendingPathComponent(relative)
         .appendingPathComponent("index.html")
   }
}
