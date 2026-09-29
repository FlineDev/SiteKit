import Foundation
import SiteKit

/// Emits the OpenAPI full-text search index to `/assets/search-index.json`: one record per
/// generated page (landing, tags, operations, schemas), each with its title, URL, a short
/// summary, and facets (kind, plus HTTP method / tag for operations).
///
/// The OpenAPI pages reach `context.sections` via ``OpenAPIContentProvider``; this renderer
/// walks them and keeps only those carrying an `openAPIPath` (the OpenAPI pages), so it stays
/// scoped to the API surface even if a host site mixes in other sections. URLs come from the
/// same ``OpenAPIRoutes`` stamp the page renderers use (via the shared ``OpenAPIPagePathResolver``),
/// never a recomputed path. The bundled `openapi-search.js` (``OpenAPISearchScriptRenderer``)
/// fetches this file to power the appbar search box. A `.global` renderer – one index per build.
///
/// Unlike `DocCSearchIndexRenderer` (sharded, session-note-scoped), this is a single small
/// JSON array: an API surface is bounded (operations + schemas), so one file fetched once is
/// simpler than shard manifests, and it is OpenAPIKit-free.
public struct OpenAPISearchIndexRenderer: Renderer {
   public var scope: RenderScope { .global }

   /// The public URL the search script fetches.
   public static let indexURL = "/assets/search-index.json"

   /// Path authorities consulted per page (mirroring sitemap + nav index): a page the
   /// resolvers mark `.unpublished` is omitted so a result never links to a 404.
   let pathResolvers: [any PagePathResolving]

   public init(pathResolvers: [any PagePathResolving] = []) {
      self.pathResolvers = pathResolvers
   }

   /// One search record. `summary`, `method`, and `tag` are omitted from the JSON when absent.
   struct Record: Codable, Equatable {
      let title: String
      let url: String
      let kind: String
      var summary: String?
      var method: String?
      var tag: String?
   }

   public func render(context: BuildContext) throws -> [OutputFile] {
      var records: [Record] = []
      for page in context.sections.flatMap(\.pages) {
         guard let url: String = page.extensionValue("openAPIPath") else { continue }
         if case .unpublished = self.pathResolvers.pathResolution(for: page, context: context) {
            continue
         }

         var record = Record(title: page.title, url: url, kind: Self.kind(of: page, url: url, context: context))
         if let summary = (page.summary ?? page.description).flatMap({ $0.isEmpty ? nil : $0 }) {
            record.summary = summary
         }
         if let operation: OpenAPISpec.Operation = page.extensionValue("openAPIOperation") {
            record.method = operation.method.uppercased()
            record.tag = operation.tags.first
         }
         records.append(record)
      }

      guard !records.isEmpty else { return [] }

      let encoder = JSONEncoder()
      // Keep the URLs readable (`/api/pets/…`, not `\/api\/pets\/`) – any JSON parser accepts
      // both, but the unescaped form is friendlier for an AI agent eyeballing the file.
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(records)
      let path = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("search-index.json")
      return [OutputFile(outputPath: path, content: String(decoding: data, as: UTF8.self))]
   }

   /// Classifies a page from its markers and URL (operation by its stamped operation, schema /
   /// landing by URL shape, tag otherwise) – no OpenAPIKit and no spec re-walk needed.
   private static func kind(of page: PageModel, url: String, context: BuildContext) -> String {
      if page.extensionValue("openAPIOperation") as OpenAPISpec.Operation? != nil {
         return "operation"
      }
      if url == OpenAPIRoutes.landingPath(context) {
         return "landing"
      }
      if url.contains("/schemas/") {
         return "schema"
      }
      return "tag"
   }
}
