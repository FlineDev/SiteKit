import Foundation

/// A flattened, render-ready view of an OpenAPI document.
///
/// `OpenAPISpecLoader` decodes an OpenAPI 3.0 or 3.1 file (YAML or JSON),
/// normalizes 3.0 documents to the 3.1 shape, and projects the result into this
/// value model. The model is intentionally decoupled from OpenAPIKit so the page
/// renderers (landing, tag, operation, schema) read only SiteKit-owned types and
/// never `import OpenAPIKit`. This is the contract every OpenAPI renderer builds on.
///
/// Every type in the model is nested under `OpenAPISpec` (for example
/// ``OpenAPISpec/Operation`` and ``OpenAPISpec/SchemaNode``). The namespace keeps
/// the surface predictable and, in particular, keeps ``OpenAPISpec/Operation``
/// from shadowing `Foundation.Operation` for a consumer that imports both.
public struct OpenAPISpec: Sendable, Equatable {
   /// The document's `info` block: title, version, description.
   public let info: Info

   /// The declared servers, in document order.
   public let servers: [Server]

   /// The declared tags, in document order. Operations reference these by name.
   public let tags: [Tag]

   /// Every operation across all paths, flattened to one list (method + path +
   /// the operation's metadata), in document order.
   public let operations: [Operation]

   /// The reusable schemas from `components/schemas`, in document order.
   public let schemas: [SchemaObject]

   /// Memberwise initializer.
   public init(
      info: Info,
      servers: [Server],
      tags: [Tag],
      operations: [Operation],
      schemas: [SchemaObject]
   ) {
      self.info = info
      self.servers = servers
      self.tags = tags
      self.operations = operations
      self.schemas = schemas
   }

   /// The document's `info` block.
   public struct Info: Sendable, Equatable {
      /// The API title, shown as the site/landing heading.
      public let title: String

      /// The API version string (for example `1.0.0`).
      public let version: String

      /// The API's short summary, if provided (OpenAPI 3.1 only).
      public let summary: String?

      /// The API's longer description (Markdown), if provided.
      public let description: String?

      /// Memberwise initializer.
      public init(title: String, version: String, summary: String? = nil, description: String? = nil) {
         self.title = title
         self.version = version
         self.summary = summary
         self.description = description
      }
   }

   /// One server entry from the document's `servers` list.
   public struct Server: Sendable, Equatable {
      /// The server URL, with any `{variable}` templates left intact.
      public let url: String

      /// The server's description, if provided.
      public let description: String?

      /// Memberwise initializer.
      public init(url: String, description: String? = nil) {
         self.url = url
         self.description = description
      }
   }

   /// One tag entry from the document's `tags` list. Operations group under a
   /// tag's `name`.
   public struct Tag: Sendable, Equatable {
      /// The tag name, used to group operations and as the tag page slug.
      public let name: String

      /// The tag's description (Markdown), if provided.
      public let description: String?

      /// Memberwise initializer.
      public init(name: String, description: String? = nil) {
         self.name = name
         self.description = description
      }
   }
}

extension OpenAPISpec {
   /// One operation: an HTTP method on a path plus its documented metadata.
   public struct Operation: Sendable, Equatable {
      /// The uppercased HTTP method (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, …).
      public let method: String

      /// The templated path the operation lives under (for example `/pets/{id}`).
      public let path: String

      /// The operation's stable `operationId`, if provided.
      public let operationId: String?

      /// The operation's short summary, if provided.
      public let summary: String?

      /// The operation's longer description (Markdown), if provided.
      public let description: String?

      /// The tags this operation belongs to, in document order.
      public let tags: [String]

      /// The operation's parameters (path, query, header, cookie), in document order.
      public let parameters: [Parameter]

      /// The operation's request body, if it declares one.
      public let requestBody: RequestBody?

      /// The operation's responses keyed by status, in document order.
      public let responses: [Response]

      /// The operation's security requirements (an OR of requirement sets, each an
      /// AND of named schemes), in document order.
      public let security: [SecurityRequirement]

      /// Whether the operation is marked `deprecated`.
      public let deprecated: Bool

      /// Memberwise initializer.
      public init(
         method: String,
         path: String,
         operationId: String? = nil,
         summary: String? = nil,
         description: String? = nil,
         tags: [String] = [],
         parameters: [Parameter] = [],
         requestBody: RequestBody? = nil,
         responses: [Response] = [],
         security: [SecurityRequirement] = [],
         deprecated: Bool = false
      ) {
         self.method = method
         self.path = path
         self.operationId = operationId
         self.summary = summary
         self.description = description
         self.tags = tags
         self.parameters = parameters
         self.requestBody = requestBody
         self.responses = responses
         self.security = security
         self.deprecated = deprecated
      }
   }

   /// One operation parameter (path, query, header, or cookie).
   public struct Parameter: Sendable, Equatable {
      /// Where a parameter is carried in the request.
      public enum Location: Sendable, Equatable {
         /// A query-string parameter (`?name=…`).
         case query
         /// A path parameter (a `{name}` segment).
         case path
         /// A header parameter.
         case header
         /// A cookie parameter.
         case cookie
         /// Any other (forward-compatible) location, carrying its raw spec value.
         case other(String)

         /// The lowercase spec string for this location (`query`, `path`, …).
         public var rawValue: String {
            switch self {
            case .query: "query"
            case .path: "path"
            case .header: "header"
            case .cookie: "cookie"
            case .other(let value): value
            }
         }

         /// Maps a raw OpenAPI location string to a `Location`, preserving unknown
         /// values via `.other` rather than dropping them.
         public init(rawValue: String) {
            switch rawValue {
            case "query": self = .query
            case "path": self = .path
            case "header": self = .header
            case "cookie": self = .cookie
            default: self = .other(rawValue)
            }
         }
      }

      /// The parameter name.
      public let name: String

      /// Where the parameter is carried.
      public let location: Location

      /// The parameter's description (Markdown), if provided.
      public let description: String?

      /// Whether the parameter is required. Path parameters are always required.
      public let required: Bool

      /// Whether the parameter is marked `deprecated`.
      public let deprecated: Bool

      /// The flattened schema describing the parameter's value, if it declares one.
      public let schema: SchemaNode?

      /// Memberwise initializer.
      public init(
         name: String,
         location: Location,
         description: String? = nil,
         required: Bool = false,
         deprecated: Bool = false,
         schema: SchemaNode? = nil
      ) {
         self.name = name
         self.location = location
         self.description = description
         self.required = required
         self.deprecated = deprecated
         self.schema = schema
      }
   }

   /// An operation's request body.
   public struct RequestBody: Sendable, Equatable {
      /// The request body's description (Markdown), if provided.
      public let description: String?

      /// Whether the request body is required.
      public let required: Bool

      /// The body's representations keyed by media type, in document order.
      public let content: [MediaType]

      /// Memberwise initializer.
      public init(description: String? = nil, required: Bool = false, content: [MediaType] = []) {
         self.description = description
         self.required = required
         self.content = content
      }
   }

   /// One media-type representation of a request or response body (for example
   /// `application/json`) and its flattened schema.
   public struct MediaType: Sendable, Equatable {
      /// The media type string (for example `application/json`).
      public let contentType: String

      /// The flattened schema describing this representation, if it declares one.
      public let schema: SchemaNode?

      /// Memberwise initializer.
      public init(contentType: String, schema: SchemaNode? = nil) {
         self.contentType = contentType
         self.schema = schema
      }
   }

   /// One response of an operation, keyed by status.
   public struct Response: Sendable, Equatable {
      /// The status key as written in the spec (for example `200`, `404`,
      /// `default`, or a `2XX` range).
      public let statusCode: String

      /// The response's description, if provided.
      public let description: String?

      /// The response body's representations keyed by media type, in document order.
      public let content: [MediaType]

      /// Memberwise initializer.
      public init(statusCode: String, description: String? = nil, content: [MediaType] = []) {
         self.statusCode = statusCode
         self.description = description
         self.content = content
      }
   }

   /// One security requirement: a set of named schemes that must ALL be satisfied
   /// together. An operation's `security` list is the OR of these requirements.
   public struct SecurityRequirement: Sendable, Equatable {
      /// One named scheme reference inside a requirement, with its required scopes.
      public struct SchemeRequirement: Sendable, Equatable {
         /// The referenced `securityScheme` name from `components/securitySchemes`.
         public let name: String

         /// The OAuth2 / OpenID-Connect scopes required, if any.
         public let scopes: [String]

         /// Memberwise initializer.
         public init(name: String, scopes: [String]) {
            self.name = name
            self.scopes = scopes
         }
      }

      /// The schemes that must all be satisfied for this requirement.
      public let schemes: [SchemeRequirement]

      /// Memberwise initializer.
      public init(schemes: [SchemeRequirement]) {
         self.schemes = schemes
      }
   }
}
