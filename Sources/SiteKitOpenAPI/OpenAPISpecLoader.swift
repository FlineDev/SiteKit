import Foundation
// The target declares only the `OpenAPIKitCompat` product, but `OpenAPIKitCompat` re-exports
// `OpenAPIKit` (3.1), `OpenAPIKit30` (3.0), and `OpenAPIKitCore`, so all three resolve transitively
// and are imported explicitly here to name their types directly (the 3.0 document, the 3.1 document,
// and the shared `Either` / `AnyCodable` / `JSONSchema` types) and to make the dependency intent legible.
import OpenAPIKit
import OpenAPIKit30
import OpenAPIKitCompat
import OpenAPIKitCore
import SiteKit
import Yams

// Both OpenAPIKit (3.1) and OpenAPIKit30 export `JSONSchema`, and both re-export `Either` /
// `AnyCodable` from OpenAPIKitCore, so the bare names are ambiguous while both modules are imported
// (OpenAPIKit30 is needed only to decode legacy 3.0 documents before converting them). The loader
// normalizes every document to the 3.1 model up front, so the mapping below speaks only the 3.1
// types: these file-private aliases pin the bare names to the right module.
private typealias JSONSchema = OpenAPIKit.JSONSchema
private typealias Either<A, B> = OpenAPIKitCore.Either<A, B>
private typealias AnyCodable = OpenAPIKitCore.AnyCodable

/// Loads an OpenAPI document from a file URL into the flattened ``OpenAPISpec``.
///
/// The loader handles the full 2×2 input matrix on its own:
/// - **Format** is auto-detected by file extension: `.json` decodes with
///   `JSONDecoder`, `.yaml`/`.yml` (and anything else) decode with Yams.
/// - **Version** is auto-detected from the document's `openapi:` field: 3.1
///   documents decode straight to OpenAPIKit's 3.1 model, while 3.0 documents
///   decode with `OpenAPIKit30` and are normalized to 3.1 through
///   `OpenAPIKitCompat`'s `convert(to:)`. Everything downstream therefore sees
///   one 3.1 shape and the renderers never branch on spec version.
///
/// Conforms to SiteKit's `Loader` so it slots into the pipeline's loading phase;
/// its `Source` is a file `URL` and its `Output` is the typed ``OpenAPISpec``.
public struct OpenAPISpecLoader: Loader {
   public typealias Source = URL
   public typealias Output = OpenAPISpec

   public init() {}

   /// Errors thrown while loading and decoding an OpenAPI document.
   public enum LoadError: Swift.Error, CustomStringConvertible, Equatable {
      /// The `openapi:` version field was missing or not a recognized 3.0/3.1 value.
      case unsupportedVersion(String)

      public var description: String {
         switch self {
         case .unsupportedVersion(let found):
            "Unsupported or missing OpenAPI version '\(found)'. SiteKitOpenAPI supports OpenAPI 3.0.x and 3.1.x."
         }
      }
   }

   /// Decodes the document at `source` and projects it into an ``OpenAPISpec``.
   ///
   /// Throws:
   /// - ``LoadError/unsupportedVersion(_:)`` when the `openapi:` field is absent
   ///   (for example a Swagger 2.0 document) or names a major version other than
   ///   3.0 / 3.1;
   /// - a file-read error – which does name the file – when `url` cannot be read;
   /// - a `DecodingError` when the document is present but malformed (the decoder
   ///   error pinpoints the offending key/path, though not the file name).
   public func load(source url: URL) throws -> OpenAPISpec {
      let data = try Data(contentsOf: url)
      let isJSON = url.pathExtension.lowercased() == "json"

      let document = try Self.decodeDocument(data: data, isJSON: isJSON)
      return Self.makeSpec(from: document)
   }

   // MARK: - Decoding

   /// Detects the document's major version and decodes to a unified 3.1 model.
   private static func decodeDocument(data: Data, isJSON: Bool) throws -> OpenAPIKit.OpenAPI.Document {
      let version = try detectMajorVersion(data: data, isJSON: isJSON)

      switch version {
      case .v3_1:
         return try decode(OpenAPIKit.OpenAPI.Document.self, from: data, isJSON: isJSON)
      case .v3_0:
         let legacy = try decode(OpenAPIKit30.OpenAPI.Document.self, from: data, isJSON: isJSON)
         return legacy.convert(to: .v3_1_1)
      }
   }

   /// The two major OpenAPI versions this loader accepts.
   private enum MajorVersion {
      case v3_0
      case v3_1
   }

   /// A minimal probe that reads only the `openapi:` field so the right typed
   /// decoder can be chosen before the full (version-specific) decode. `openapi`
   /// is optional so a document that omits it (for example Swagger 2.0, which uses
   /// `swagger:` instead) decodes cleanly here and is rejected with a precise
   /// ``LoadError/unsupportedVersion(_:)`` rather than a raw `DecodingError`.
   private struct VersionProbe: Decodable {
      let openapi: String?
   }

   /// Reads the `openapi:` field and maps it to a ``MajorVersion``.
   ///
   /// S2: this re-parses the whole document as `VersionProbe` before the real
   /// decode (a second full parse). Fine for build-time specs; revisit only if it
   /// shows up in profiles.
   private static func detectMajorVersion(data: Data, isJSON: Bool) throws -> MajorVersion {
      let probe = try decode(VersionProbe.self, from: data, isJSON: isJSON)
      let version = probe.openapi ?? "<missing>"
      if version.hasPrefix("3.1") {
         return .v3_1
      } else if version.hasPrefix("3.0") {
         return .v3_0
      } else {
         throw LoadError.unsupportedVersion(version)
      }
   }

   /// Decodes `T` from `data` using the JSON or YAML decoder per `isJSON`.
   private static func decode<T: Decodable>(_ type: T.Type, from data: Data, isJSON: Bool) throws -> T {
      if isJSON {
         return try JSONDecoder().decode(T.self, from: data)
      } else {
         return try YAMLDecoder().decode(T.self, from: data)
      }
   }

   // MARK: - Mapping

   /// Projects a decoded 3.1 document into the flattened ``OpenAPISpec``.
   ///
   /// Path items and the schemas, parameters, request bodies, and responses
   /// nested inside operations may each be either an inline value or a `$ref`.
   /// A single self-contained spec (the shape this blueprint supports) carries
   /// them inline, so inline values are flattened in full; a `$ref` at the schema
   /// level is preserved by name (``OpenAPISpec/SchemaNode/referenceName``) for
   /// the renderers to link, and a `$ref` at the path-item / parameter / request-
   /// body / response / content level is dropped consistently (see the helpers).
   private static func makeSpec(from document: OpenAPIKit.OpenAPI.Document) -> OpenAPISpec {
      let info = OpenAPISpec.Info(
         title: document.info.title,
         version: document.info.version,
         summary: document.info.summary,
         description: document.info.description
      )

      let servers = document.servers.map { server in
         OpenAPISpec.Server(url: server.urlTemplate.absoluteString, description: server.description)
      }

      let tags = (document.tags ?? []).map { tag in
         OpenAPISpec.Tag(name: tag.name, description: tag.description)
      }

      var operations: [OpenAPISpec.Operation] = []
      for (path, pathItemEither) in document.paths {
         // Single self-contained specs carry path items inline; a referenced path
         // item is out of scope for this blueprint and is skipped rather than guessed.
         // S2: resolve in-file component references and stop dropping referenced nodes.
         guard case .b(let pathItem) = pathItemEither else { continue }
         for endpoint in pathItem.endpoints {
            operations.append(Self.makeOperation(endpoint.operation, method: endpoint.method.rawValue, path: path.rawValue))
         }
      }

      let schemas = document.components.schemas.map { entry in
         OpenAPISpec.SchemaObject(name: entry.key.rawValue, schema: Self.makeSchema(entry.value))
      }

      return OpenAPISpec(info: info, servers: servers, tags: tags, operations: operations, schemas: schemas)
   }

   private static func makeOperation(_ operation: OpenAPIKit.OpenAPI.Operation, method: String, path: String) -> OpenAPISpec.Operation {
      OpenAPISpec.Operation(
         method: method,
         path: path,
         operationId: operation.operationId,
         summary: operation.summary,
         description: operation.description,
         tags: operation.tags ?? [],
         parameters: operation.parameters.compactMap { Self.makeParameter($0) },
         requestBody: operation.requestBody.flatMap { Self.makeRequestBody($0) },
         responses: Self.makeResponses(operation.responses),
         security: Self.makeSecurity(operation.security),
         deprecated: operation.deprecated
      )
   }

   /// Maps an inline parameter. A `$ref`'d parameter is dropped (returns `nil`),
   /// matching the drop-on-reference choice across the other nesting levels until
   /// S2 resolves in-file component references.
   private static func makeParameter(
      _ parameterEither: Either<OpenAPIKit.OpenAPI.Reference<OpenAPIKit.OpenAPI.Parameter>, OpenAPIKit.OpenAPI.Parameter>
   ) -> OpenAPISpec.Parameter? {
      guard case .b(let parameter) = parameterEither else { return nil }

      let schema: OpenAPISpec.SchemaNode?
      switch parameter.schemaOrContent {
      case .a(let schemaContext):
         schema = Self.makeSchema(from: schemaContext.schema)
      case .b(let contentMap):
         schema = Self.makeContent(contentMap).first?.schema
      }

      return OpenAPISpec.Parameter(
         name: parameter.name,
         location: OpenAPISpec.Parameter.Location(rawValue: parameter.location.rawValue),
         description: parameter.description,
         required: parameter.required,
         deprecated: parameter.deprecated,
         schema: schema
      )
   }

   /// Maps an inline request body. A `$ref`'d request body is dropped (returns
   /// `nil`), consistent with the other reference levels.
   private static func makeRequestBody(_ requestEither: Either<OpenAPIKit.OpenAPI.Reference<OpenAPIKit.OpenAPI.Request>, OpenAPIKit.OpenAPI.Request>)
      -> OpenAPISpec.RequestBody?
   {
      guard case .b(let request) = requestEither else { return nil }
      return OpenAPISpec.RequestBody(
         description: request.description,
         required: request.required,
         content: Self.makeContent(request.content)
      )
   }

   /// Maps the inline responses. A `$ref`'d response is dropped (`compactMap`),
   /// consistent with the parameter / request-body reference handling above –
   /// rather than emitting a degenerate empty response. S2 resolves these refs.
   private static func makeResponses(_ responses: OpenAPIKit.OpenAPI.Response.Map) -> [OpenAPISpec.Response] {
      responses.compactMap { entry in
         guard case .b(let response) = entry.value else { return nil }
         return OpenAPISpec.Response(
            statusCode: entry.key.rawValue,
            description: response.description,
            content: Self.makeContent(response.content)
         )
      }
   }

   /// Maps the inline media-type representations. A `$ref`'d content entry is
   /// dropped (`compactMap`), consistent with the other reference levels.
   private static func makeContent(_ content: OpenAPIKit.OpenAPI.Content.Map) -> [OpenAPISpec.MediaType] {
      content.compactMap { entry in
         guard case .b(let inline) = entry.value else { return nil }
         return OpenAPISpec.MediaType(contentType: entry.key.rawValue, schema: inline.schema.map { Self.makeSchema($0) })
      }
   }

   /// Maps each per-operation security requirement (a named scheme reference plus
   /// its scopes). S2: flatten the `components/securitySchemes` *definitions*
   /// (type / location / OAuth flows) when the operation pages need to render them.
   private static func makeSecurity(_ security: [OpenAPIKit.OpenAPI.SecurityRequirement]?) -> [OpenAPISpec.SecurityRequirement] {
      (security ?? []).map { requirement in
         let schemes =
            requirement
            .compactMap { reference, scopes -> OpenAPISpec.SecurityRequirement.SchemeRequirement? in
               guard let name = reference.name else { return nil }
               return OpenAPISpec.SecurityRequirement.SchemeRequirement(name: name, scopes: scopes)
            }
            // A requirement's schemes come from a dictionary (no inherent order);
            // sort by name so the rendered output is deterministic build to build.
            .sorted { $0.name < $1.name }
         return OpenAPISpec.SecurityRequirement(schemes: schemes)
      }
   }

   // MARK: - Schema mapping

   /// Flattens an inline-or-referenced schema, preserving a top-level `$ref` by name.
   private static func makeSchema(from schemaEither: Either<OpenAPIKit.OpenAPI.Reference<JSONSchema>, JSONSchema>) -> OpenAPISpec.SchemaNode {
      switch schemaEither {
      case .a(let reference):
         return OpenAPISpec.SchemaNode(referenceName: reference.name)
      case .b(let schema):
         return Self.makeSchema(schema)
      }
   }

   /// Flattens an OpenAPIKit `JSONSchema` into the OpenAPIKit-free ``OpenAPISpec/SchemaNode``.
   private static func makeSchema(_ schema: JSONSchema) -> OpenAPISpec.SchemaNode {
      let title = schema.title
      let description = schema.description
      let deprecated = schema.deprecated
      let nullable = schema.nullable

      switch schema.value {
      case .reference(let reference, _):
         return OpenAPISpec.SchemaNode(
            title: title,
            description: description,
            referenceName: reference.name,
            deprecated: deprecated,
            nullable: nullable
         )

      case .object(_, let context):
         let properties = context.properties.map { entry in
            OpenAPISpec.SchemaProperty(
               name: entry.key,
               required: context.requiredProperties.contains(entry.key),
               schema: Self.makeSchema(entry.value)
            )
         }
         return OpenAPISpec.SchemaNode(
            type: "object",
            title: title,
            description: description,
            required: context.requiredProperties,
            properties: properties,
            deprecated: deprecated,
            nullable: nullable
         )

      case .array(_, let context):
         let items = context.items.map { [Self.makeSchema($0)] } ?? []
         return OpenAPISpec.SchemaNode(
            type: "array",
            format: schema.formatString,
            title: title,
            description: description,
            items: items,
            deprecated: deprecated,
            nullable: nullable
         )

      case .all(of: let subschemas, _):
         return Self.makeComposition(
            .allOf,
            subschemas,
            discriminator: schema.discriminator,
            title: title,
            description: description,
            deprecated: deprecated,
            nullable: nullable
         )
      case .one(of: let subschemas, _):
         return Self.makeComposition(
            .oneOf,
            subschemas,
            discriminator: schema.discriminator,
            title: title,
            description: description,
            deprecated: deprecated,
            nullable: nullable
         )
      case .any(of: let subschemas, _):
         return Self.makeComposition(
            .anyOf,
            subschemas,
            discriminator: schema.discriminator,
            title: title,
            description: description,
            deprecated: deprecated,
            nullable: nullable
         )

      default:
         // Scalars (string / integer / number / boolean / null) plus `.not` and
         // untyped `.fragment`: carry the type, format, and enum values where present.
         return OpenAPISpec.SchemaNode(
            type: schema.jsonType?.rawValue,
            format: schema.formatString,
            title: title,
            description: description,
            enumValues: Self.makeEnumValues(schema.allowedValues),
            deprecated: deprecated,
            nullable: nullable
         )
      }
   }

   private static func makeComposition(
      _ kind: OpenAPISpec.Composition.Kind,
      _ subschemas: [JSONSchema],
      discriminator: OpenAPIKit.OpenAPI.Discriminator?,
      title: String?,
      description: String?,
      deprecated: Bool,
      nullable: Bool
   ) -> OpenAPISpec.SchemaNode {
      OpenAPISpec.SchemaNode(
         title: title,
         description: description,
         composition: OpenAPISpec.Composition(
            kind: kind,
            subschemas: subschemas.map { Self.makeSchema($0) },
            discriminator: Self.makeDiscriminator(discriminator)
         ),
         deprecated: deprecated,
         nullable: nullable
      )
   }

   private static func makeDiscriminator(_ discriminator: OpenAPIKit.OpenAPI.Discriminator?) -> OpenAPISpec.Composition.Discriminator? {
      guard let discriminator else { return nil }
      var mapping: [String: String] = [:]
      for (value, schemaName) in discriminator.mapping ?? [:] {
         mapping[value] = schemaName
      }
      return OpenAPISpec.Composition.Discriminator(propertyName: discriminator.propertyName, mapping: mapping)
   }

   /// Renders enum values to their string form. S2: a structured (non-scalar) enum
   /// value would yield a Swift debug string here; revisit if such enums appear.
   private static func makeEnumValues(_ values: [AnyCodable]?) -> [String] {
      (values ?? []).map { value in
         if let string = value.value as? String { return string }
         return String(describing: value.value)
      }
   }
}
