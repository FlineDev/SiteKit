import Foundation

/// One named schema from the spec's `components/schemas` section.
///
/// The `name` is the component key (for example `Pet`), which doubles as the
/// slug for the schema's documentation page; `schema` is the flattened,
/// OpenAPIKit-free description the renderers walk.
public struct SchemaObject: Sendable, Equatable {
   /// The component key, for example `Pet` for `#/components/schemas/Pet`.
   public let name: String

   /// The flattened schema description.
   public let schema: SchemaNode

   /// Memberwise initializer.
   public init(name: String, schema: SchemaNode) {
      self.name = name
      self.schema = schema
   }
}

/// A flattened, render-ready description of a JSON Schema node.
///
/// This is deliberately decoupled from OpenAPIKit's `JSONSchema` so the page
/// renderers never need to `import OpenAPIKit`. It captures the facets a docs
/// renderer cares about (type, format, the object's properties, an array's
/// element schema, `$ref` targets, enum values, composition) and flattens the
/// rest. Recursion runs through arrays (`properties`, `items`, `composition`)
/// so the value type stays a plain `struct` without boxing.
public struct SchemaNode: Sendable, Equatable {
   /// The JSON Schema `type` keyword (`object`, `array`, `string`, `integer`,
   /// `number`, `boolean`, `null`), or `nil` for a reference, a composition, or
   /// an untyped fragment.
   public let type: String?

   /// The `format` keyword refining `type` (for example `int64`, `date-time`).
   public let format: String?

   /// The schema's `title`, if any.
   public let title: String?

   /// The schema's `description`, if any.
   public let description: String?

   /// The names of the required properties (object schemas only).
   public let required: [String]

   /// The object's properties in declaration order (object schemas only).
   public let properties: [SchemaProperty]

   /// The array element schema, in a zero-or-one-element array (array schemas
   /// only). An array is used instead of an optional so the value type need not
   /// be `indirect`.
   public let items: [SchemaNode]

   /// The allowed values of an `enum` schema, rendered to their string form.
   public let enumValues: [String]

   /// The local `$ref` target name (for example `Pet` for
   /// `#/components/schemas/Pet`) when this node is a reference, else `nil`.
   public let referenceName: String?

   /// The `allOf` / `oneOf` / `anyOf` composition this node represents, if any.
   public let composition: Composition?

   /// Whether the schema is marked `deprecated`.
   public let deprecated: Bool

   /// Whether the schema is nullable (the 3.0 `nullable: true` flag, normalized
   /// from a `["T", "null"]` type array by OpenAPIKit on 3.1 documents).
   public let nullable: Bool

   /// Memberwise initializer. Every field defaults to its empty value so a
   /// renderer can construct a partial node without restating the whole shape.
   public init(
      type: String? = nil,
      format: String? = nil,
      title: String? = nil,
      description: String? = nil,
      required: [String] = [],
      properties: [SchemaProperty] = [],
      items: [SchemaNode] = [],
      enumValues: [String] = [],
      referenceName: String? = nil,
      composition: Composition? = nil,
      deprecated: Bool = false,
      nullable: Bool = false
   ) {
      self.type = type
      self.format = format
      self.title = title
      self.description = description
      self.required = required
      self.properties = properties
      self.items = items
      self.enumValues = enumValues
      self.referenceName = referenceName
      self.composition = composition
      self.deprecated = deprecated
      self.nullable = nullable
   }
}

/// One property of an object schema: its name, whether it is required, and the
/// flattened schema describing its value.
public struct SchemaProperty: Sendable, Equatable {
   /// The property name as it appears in the object.
   public let name: String

   /// Whether the parent object lists this property in its `required` array.
   public let required: Bool

   /// The flattened schema of the property's value.
   public let schema: SchemaNode

   /// Memberwise initializer.
   public init(name: String, required: Bool, schema: SchemaNode) {
      self.name = name
      self.required = required
      self.schema = schema
   }
}

/// An `allOf` / `oneOf` / `anyOf` schema composition and its member schemas.
public struct Composition: Sendable, Equatable {
   /// Which JSON Schema composition keyword produced this node.
   public enum Kind: String, Sendable, Equatable {
      /// `allOf` – the value must satisfy every member schema.
      case allOf
      /// `oneOf` – the value must satisfy exactly one member schema.
      case oneOf
      /// `anyOf` – the value must satisfy at least one member schema.
      case anyOf
   }

   /// The composition keyword.
   public let kind: Kind

   /// The member schemas being composed, in declaration order.
   public let subschemas: [SchemaNode]

   /// Memberwise initializer.
   public init(kind: Kind, subschemas: [SchemaNode]) {
      self.kind = kind
      self.subschemas = subschemas
   }
}
