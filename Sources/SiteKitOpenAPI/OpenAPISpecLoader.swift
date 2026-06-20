import Foundation
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
   /// Throws a decoding error (naming the file) when the document is malformed,
   /// or ``LoadError/unsupportedVersion(_:)`` when the `openapi:` field is absent
   /// or names a major version other than 3.0 / 3.1.
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
   /// decoder can be chosen before the full (version-specific) decode.
   private struct VersionProbe: Decodable {
      let openapi: String
   }

   /// Reads the `openapi:` field and maps it to a ``MajorVersion``.
   private static func detectMajorVersion(data: Data, isJSON: Bool) throws -> MajorVersion {
      let probe = try decode(VersionProbe.self, from: data, isJSON: isJSON)
      if probe.openapi.hasPrefix("3.1") {
         return .v3_1
      } else if probe.openapi.hasPrefix("3.0") {
         return .v3_0
      } else {
         throw LoadError.unsupportedVersion(probe.openapi)
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
   /// them inline, so inline values are flattened in full and a top-level `$ref`
   /// to a reusable component is preserved by name (``SchemaNode/referenceName``)
   /// for the renderers to link.
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

      var operations: [Operation] = []
      for (path, pathItemEither) in document.paths {
         // Single self-contained specs carry path items inline; a referenced path
         // item is out of scope for this blueprint and is skipped rather than guessed.
         guard case .b(let pathItem) = pathItemEither else { continue }
         for endpoint in pathItem.endpoints {
            operations.append(Self.makeOperation(endpoint.operation, method: endpoint.method.rawValue, path: path.rawValue))
         }
      }

      let schemas = document.components.schemas.map { entry in
         SchemaObject(name: entry.key.rawValue, schema: Self.makeSchema(entry.value))
      }

      return OpenAPISpec(info: info, servers: servers, tags: tags, operations: operations, schemas: schemas)
   }

   private static func makeOperation(_ operation: OpenAPIKit.OpenAPI.Operation, method: String, path: String) -> Operation {
      Operation(
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

   private static func makeParameter(
      _ parameterEither: Either<OpenAPIKit.OpenAPI.Reference<OpenAPIKit.OpenAPI.Parameter>, OpenAPIKit.OpenAPI.Parameter>
   ) -> Parameter? {
      guard case .b(let parameter) = parameterEither else { return nil }

      let schema: SchemaNode?
      switch parameter.schemaOrContent {
      case .a(let schemaContext):
         schema = Self.makeSchema(from: schemaContext.schema)
      case .b(let contentMap):
         schema = Self.makeContent(contentMap).first?.schema
      }

      return Parameter(
         name: parameter.name,
         location: Parameter.Location(rawValue: parameter.location.rawValue),
         description: parameter.description,
         required: parameter.required,
         deprecated: parameter.deprecated,
         schema: schema
      )
   }

   private static func makeRequestBody(_ requestEither: Either<OpenAPIKit.OpenAPI.Reference<OpenAPIKit.OpenAPI.Request>, OpenAPIKit.OpenAPI.Request>)
      -> RequestBody?
   {
      guard case .b(let request) = requestEither else { return nil }
      return RequestBody(
         description: request.description,
         required: request.required,
         content: Self.makeContent(request.content)
      )
   }

   private static func makeResponses(_ responses: OpenAPIKit.OpenAPI.Response.Map) -> [Response] {
      responses.map { entry in
         let response: OpenAPIKit.OpenAPI.Response?
         if case .b(let value) = entry.value { response = value } else { response = nil }
         return Response(
            statusCode: entry.key.rawValue,
            description: response?.description,
            content: response.map { Self.makeContent($0.content) } ?? []
         )
      }
   }

   private static func makeContent(_ content: OpenAPIKit.OpenAPI.Content.Map) -> [MediaType] {
      content.map { entry in
         let value: OpenAPIKit.OpenAPI.Content?
         if case .b(let inline) = entry.value { value = inline } else { value = nil }
         return MediaType(contentType: entry.key.rawValue, schema: value?.schema.map { Self.makeSchema($0) })
      }
   }

   private static func makeSecurity(_ security: [OpenAPIKit.OpenAPI.SecurityRequirement]?) -> [SecurityRequirement] {
      (security ?? []).map { requirement in
         let schemes =
            requirement
            .compactMap { reference, scopes -> SecurityRequirement.SchemeRequirement? in
               guard let name = reference.name else { return nil }
               return SecurityRequirement.SchemeRequirement(name: name, scopes: scopes)
            }
            // A requirement's schemes come from a dictionary (no inherent order);
            // sort by name so the rendered output is deterministic build to build.
            .sorted { $0.name < $1.name }
         return SecurityRequirement(schemes: schemes)
      }
   }

   // MARK: - Schema mapping

   /// Flattens an inline-or-referenced schema, preserving a top-level `$ref` by name.
   private static func makeSchema(from schemaEither: Either<OpenAPIKit.OpenAPI.Reference<JSONSchema>, JSONSchema>) -> SchemaNode {
      switch schemaEither {
      case .a(let reference):
         return SchemaNode(referenceName: reference.name)
      case .b(let schema):
         return Self.makeSchema(schema)
      }
   }

   /// Flattens an OpenAPIKit `JSONSchema` into the OpenAPIKit-free ``SchemaNode``.
   private static func makeSchema(_ schema: JSONSchema) -> SchemaNode {
      let title = schema.title
      let description = schema.description
      let deprecated = schema.deprecated
      let nullable = schema.nullable

      switch schema.value {
      case .reference(let reference, _):
         return SchemaNode(
            title: title,
            description: description,
            referenceName: reference.name,
            deprecated: deprecated,
            nullable: nullable
         )

      case .object(_, let context):
         let properties = context.properties.map { entry in
            SchemaProperty(
               name: entry.key,
               required: context.requiredProperties.contains(entry.key),
               schema: Self.makeSchema(entry.value)
            )
         }
         return SchemaNode(
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
         return SchemaNode(
            type: "array",
            format: schema.formatString,
            title: title,
            description: description,
            items: items,
            deprecated: deprecated,
            nullable: nullable
         )

      case .all(of: let subschemas, _):
         return Self.makeComposition(.allOf, subschemas, title: title, description: description, deprecated: deprecated, nullable: nullable)
      case .one(of: let subschemas, _):
         return Self.makeComposition(.oneOf, subschemas, title: title, description: description, deprecated: deprecated, nullable: nullable)
      case .any(of: let subschemas, _):
         return Self.makeComposition(.anyOf, subschemas, title: title, description: description, deprecated: deprecated, nullable: nullable)

      default:
         // Scalars (string / integer / number / boolean / null) plus `.not` and
         // untyped `.fragment`: carry the type, format, and enum values where present.
         return SchemaNode(
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
      _ kind: Composition.Kind,
      _ subschemas: [JSONSchema],
      title: String?,
      description: String?,
      deprecated: Bool,
      nullable: Bool
   ) -> SchemaNode {
      SchemaNode(
         title: title,
         description: description,
         composition: Composition(kind: kind, subschemas: subschemas.map { Self.makeSchema($0) }),
         deprecated: deprecated,
         nullable: nullable
      )
   }

   private static func makeEnumValues(_ values: [AnyCodable]?) -> [String] {
      (values ?? []).map { value in
         if let string = value.value as? String { return string }
         return String(describing: value.value)
      }
   }
}
