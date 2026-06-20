import Foundation
import SiteKit

/// Renders ``OpenAPISpec/SchemaNode`` values to semantic HTML, shared by the
/// operation page (request/response shapes) and the schema page (full detail).
///
/// A `$ref` renders as a link to that schema's page rather than being expanded
/// inline, so the docs stay deep-linkable and a schema is documented in one place.
/// This slice emits structure + classes only; the stylesheet is a later slice.
enum OpenAPISchemaHTML {
   /// A compact inline type label: a link for a `$ref`, `array of <item>` for an
   /// array, the composition keyword for a composed schema, or `type (format)` with
   /// a nullable marker for a scalar/object.
   ///
   /// `spec` is threaded so a `$ref` resolves to the same collision-safe schema slug
   /// the schema page uses, keeping every link in step with its target page.
   static func typeLabel(_ node: OpenAPISpec.SchemaNode, context: BuildContext, spec: OpenAPISpec) -> String {
      if let referenceName = node.referenceName {
         let slug = OpenAPIRoutes.schemaSlug(for: referenceName, in: spec)
         let href = OpenAPIHTML.escape(OpenAPIRoutes.schemaPath(context, schemaSlug: slug))
         return "<a class=\"sk-openapi-type-ref\" href=\"\(href)\">\(OpenAPIHTML.escape(referenceName))</a>"
      }
      if let composition = node.composition {
         let members = composition.subschemas.map { self.typeLabel($0, context: context, spec: spec) }.joined(separator: ", ")
         return "<span class=\"sk-openapi-type\" data-composition=\"\(composition.kind.rawValue)\">\(composition.kind.rawValue) (\(members))</span>"
      }
      if node.type == "array" {
         let item = node.items.first.map { self.typeLabel($0, context: context, spec: spec) } ?? "<span class=\"sk-openapi-type\">any</span>"
         return "<span class=\"sk-openapi-type\">array of \(item)</span>"
      }
      var label = node.type ?? "any"
      if let format = node.format, !format.isEmpty {
         label += " (\(format))"
      }
      if node.nullable {
         label += " · nullable"
      }
      return "<span class=\"sk-openapi-type\">\(OpenAPIHTML.escape(label))</span>"
   }

   /// An object's property table (name / type / required / description). Returns an
   /// empty string when the node has no properties.
   static func propertyTable(_ node: OpenAPISpec.SchemaNode, context: BuildContext, spec: OpenAPISpec) -> String {
      guard !node.properties.isEmpty else { return "" }
      let rows = node.properties.map { property -> String in
         let required =
            property.required
            ? "<span class=\"sk-openapi-required\" data-required=\"true\">required</span>"
            : "<span class=\"sk-openapi-optional\">optional</span>"
         let description = property.schema.description.map { OpenAPIHTML.escape($0) } ?? ""
         return "<tr class=\"sk-openapi-prop\">"
            + "<td class=\"sk-openapi-prop-name\"><code>\(OpenAPIHTML.escape(property.name))</code></td>"
            + "<td class=\"sk-openapi-prop-type\">\(self.typeLabel(property.schema, context: context, spec: spec))</td>"
            + "<td class=\"sk-openapi-prop-required\">\(required)</td>"
            + "<td class=\"sk-openapi-prop-desc\">\(description)</td>"
            + "</tr>"
      }.joined()
      return "<table class=\"sk-openapi-props\">"
         + "<thead><tr><th>Property</th><th>Type</th><th>Required</th><th>Description</th></tr></thead>"
         + "<tbody>\(rows)</tbody>"
         + "</table>"
   }

   /// The full schema-page body for one node: type, description, nullable/deprecated
   /// facets, enum values, composition (with discriminator), property table, and the
   /// element type of an array.
   static func detail(_ node: OpenAPISpec.SchemaNode, context: BuildContext, spec: OpenAPISpec) -> String {
      var html = "<p class=\"sk-openapi-schema-type\">Type: \(self.typeLabel(node, context: context, spec: spec))</p>"
      if let description = node.description, !description.isEmpty {
         html += "<p class=\"sk-openapi-description\">\(OpenAPIHTML.escape(description))</p>"
      }
      html += self.facetsHTML(node)

      if !node.enumValues.isEmpty {
         let items = node.enumValues.map { "<li><code>\(OpenAPIHTML.escape($0))</code></li>" }.joined()
         html += "<section class=\"sk-openapi-enum\"><h2>Allowed values</h2><ul>\(items)</ul></section>"
      }

      if let composition = node.composition {
         html += self.compositionHTML(composition, context: context, spec: spec)
      }

      if !node.properties.isEmpty {
         html += "<section class=\"sk-openapi-schema-props\"><h2>Properties</h2>\(self.propertyTable(node, context: context, spec: spec))</section>"
      }

      if node.type == "array", let item = node.items.first {
         html += "<section class=\"sk-openapi-array-items\"><h2>Items</h2><p>\(self.typeLabel(item, context: context, spec: spec))</p></section>"
      }

      return html
   }

   /// The nullable / deprecated facet chips, or an empty string when neither applies.
   static func facetsHTML(_ node: OpenAPISpec.SchemaNode) -> String {
      var badges = ""
      if node.nullable {
         badges += "<span class=\"sk-openapi-facet\" data-facet=\"nullable\">nullable</span>"
      }
      badges += OpenAPIBadges.deprecatedBadge(node.deprecated)
      return badges.isEmpty ? "" : "<div class=\"sk-openapi-facets\">\(badges)</div>"
   }

   /// The `allOf` / `oneOf` / `anyOf` member list plus the discriminator, if any.
   static func compositionHTML(_ composition: OpenAPISpec.Composition, context: BuildContext, spec: OpenAPISpec) -> String {
      let members = composition.subschemas.map { "<li>\(self.typeLabel($0, context: context, spec: spec))</li>" }.joined()
      var html = "<section class=\"sk-openapi-composition\" data-composition=\"\(composition.kind.rawValue)\">"
      html += "<h2>\(composition.kind.rawValue)</h2><ul>\(members)</ul>"
      if let discriminator = composition.discriminator {
         html += "<p class=\"sk-openapi-discriminator\">Discriminator: <code>\(OpenAPIHTML.escape(discriminator.propertyName))</code></p>"
      }
      html += "</section>"
      return html
   }
}
