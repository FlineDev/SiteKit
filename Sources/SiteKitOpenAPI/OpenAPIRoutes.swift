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

   /// Path segments the schema pages own (`/<prefix>/schemas/<schema>/`). A tag must
   /// never slug to one of these, or that tag's operation pages would collide with
   /// the schema namespace; the slug allocator reserves them up front.
   static let reservedTagSlugs: Set<String> = ["schemas"]

   /// Folds an arbitrary string into an ASCII URL slug `[a-z0-9-]`: accented and
   /// diacritic characters map to their ASCII base via ICU (`Café` → `cafe`, `Größe`
   /// → `grosse`), the result is lowercased, only `[a-z0-9]` is kept, and every other
   /// run collapses to a single hyphen (so `"/pets/{petId}"` becomes `"pets-petid"`).
   ///
   /// URL slugs are machine identifiers for deep links and SEO canonicals, where
   /// ASCII is the safe, percent-encoding-free form; display text keeps its real
   /// characters (umlauts included) and only the slug folds. The fold is a clean ICU
   /// character mapping, never a `ue`→`ü`-style find-replace.
   static func slugify(_ string: String) -> String {
      let folded = string.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX")).lowercased()
      var slug = ""
      var lastWasHyphen = false
      for character in folded {
         if character.isASCII, character.isLetter || character.isNumber {
            slug.append(character)
            lastWasHyphen = false
         } else if !lastWasHyphen {
            slug.append("-")
            lastWasHyphen = true
         }
      }
      return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
   }

   /// Assigns each raw name a unique slug. The base comes from ``slugify(_:)``;
   /// when two names fold to the same slug, the fold is empty (an all-non-ASCII
   /// name), or the base is already reserved, the slug is disambiguated
   /// deterministically with a numeric suffix (`-2`, `-3`, …) and a build warning,
   /// so two pages never silently overwrite each other at the same output path.
   ///
   /// - Parameters:
   ///   - rawNames: the names to slug, in order (the order fixes which name keeps
   ///     the bare slug and which gets suffixed).
   ///   - reserved: slugs that are already taken before allocation begins.
   ///   - kind: a noun for the warning message (`tag`, `operation`, `schema`).
   static func uniqueSlugs(_ rawNames: [String], reserving reserved: Set<String> = [], kind: String) -> [String] {
      var used = reserved
      var result: [String] = []
      for raw in rawNames {
         var base = self.slugify(raw)
         if base.isEmpty { base = "section" }
         var candidate = base
         if used.contains(candidate) {
            var suffix = 2
            while used.contains("\(base)-\(suffix)") { suffix += 1 }
            candidate = "\(base)-\(suffix)"
            print(
               "[SiteKit] Warning: OpenAPI \(kind) slug collision – '\(raw)' folds to '\(base)', already in use; using '\(candidate)' to keep deep links unique."
            )
         }
         used.insert(candidate)
         result.append(candidate)
      }
      return result
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

   /// The collision-safe slug assignment for the spec's component schemas, keyed by
   /// schema name. Component schema names are unique keys, but two distinct names can
   /// still fold to the same slug (`Pet` and `pet`), so the slugs are uniqued in
   /// document order. Both the schema pages and the `$ref` links resolve through this
   /// one map, so a link always lands on the page it names.
   static func schemaSlugMap(_ spec: OpenAPISpec) -> [String: String] {
      let names = spec.schemas.map(\.name)
      let slugs = self.uniqueSlugs(names, kind: "schema")
      return Dictionary(uniqueKeysWithValues: zip(names, slugs))
   }

   /// The unique slug for one schema `name` within `spec`, falling back to the bare
   /// fold for a name not declared in `components/schemas` (a dangling `$ref`).
   static func schemaSlug(for name: String, in spec: OpenAPISpec) -> String {
      self.schemaSlugMap(spec)[name] ?? self.slugify(name)
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

   /// One operation as listed under a tag section: the operation itself, its unique
   /// slug, and the slug of its canonical tag (the tag whose page hosts the
   /// operation's one canonical URL). `isCanonical` is true when the enclosing
   /// section IS that canonical tag. A cross-listed entry on a secondary tag carries
   /// the same `slug`/`canonicalTagSlug`, so its link points at the one canonical
   /// page rather than a duplicate.
   struct OperationRef {
      let operation: OpenAPISpec.Operation
      let slug: String
      let canonicalTagSlug: String
      let isCanonical: Bool
   }

   /// One tag's section: the tag (name + description), its collision-safe slug, and
   /// the operations listed under it.
   struct TagSection {
      let tag: OpenAPISpec.Tag
      let slug: String
      let operations: [OperationRef]
   }

   /// Groups the spec's operations into tag sections, with collision-safe tag and
   /// operation slugs so no two pages resolve to the same output path.
   ///
   /// Each operation has one canonical tag (its first declared tag, or ``defaultTag``
   /// when untagged) under which its single page lives. Tag sections appear in
   /// document order: declared tags first, then any tag an operation introduces, with
   /// the synthetic `general` section always last. A tag that lists no operation is
   /// omitted. Tag slugs are uniqued (reserving the schema namespace) and operation
   /// slugs are uniqued within their canonical tag, so the landing, tag pages, and
   /// operation URLs all agree on one stable, non-colliding path per page.
   static func tagSections(_ spec: OpenAPISpec) -> [TagSection] {
      var descriptions: [String: String?] = [:]
      for tag in spec.tags {
         descriptions[tag.name] = tag.description
      }

      // Tag order: declared tags first, then tags an operation introduces, general last.
      var order: [String] = spec.tags.map(\.name)
      for operation in spec.operations where !order.contains(self.canonicalTag(for: operation)) {
         order.append(self.canonicalTag(for: operation))
      }
      if let generalIndex = order.firstIndex(of: self.defaultTag) {
         order.remove(at: generalIndex)
         order.append(self.defaultTag)
      }

      // Collision-safe tag slugs (reserving the schema namespace) and per-canonical-tag
      // operation slugs, computed once so every renderer agrees on the same paths.
      let tagSlugs = self.uniqueSlugs(order, reserving: self.reservedTagSlugs, kind: "tag")
      let tagSlugByName = Dictionary(uniqueKeysWithValues: zip(order, tagSlugs))

      var operationSlugByIndex: [Int: String] = [:]
      for name in order {
         let indices = spec.operations.indices.filter { self.canonicalTag(for: spec.operations[$0]) == name }
         let rawNames = indices.map { self.operationRawName(spec.operations[$0]) }
         let slugs = self.uniqueSlugs(rawNames, kind: "operation")
         for (index, slug) in zip(indices, slugs) {
            operationSlugByIndex[index] = slug
         }
      }

      // Build each section. This slice lists an operation only under its canonical
      // tag; cross-listing secondary tags is a later slice (the OperationRef already
      // carries the canonical link target so that addition is non-breaking).
      return order.compactMap { name in
         let sectionSlug = tagSlugByName[name] ?? self.slugify(name)
         let refs: [OperationRef] = spec.operations.indices.compactMap { index in
            let operation = spec.operations[index]
            guard self.canonicalTag(for: operation) == name else { return nil }
            let operationSlug = operationSlugByIndex[index] ?? self.operationSlug(for: operation)
            return OperationRef(operation: operation, slug: operationSlug, canonicalTagSlug: sectionSlug, isCanonical: true)
         }
         guard !refs.isEmpty else { return nil }
         let tag = OpenAPISpec.Tag(name: name, description: descriptions[name] ?? nil)
         return TagSection(tag: tag, slug: sectionSlug, operations: refs)
      }
   }

   /// The human-meaningful raw identifier an operation slug is folded from: its
   /// `operationId` when present, otherwise `"<method> <path>"`.
   private static func operationRawName(_ operation: OpenAPISpec.Operation) -> String {
      if let operationId = operation.operationId, !operationId.isEmpty {
         return operationId
      }
      return "\(operation.method) \(operation.path)"
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
