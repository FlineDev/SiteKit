import Foundation
import SiteKit

/// One page per component schema: the schema name, its type, the property table
/// (name / type / required / description), any composition (allOf / oneOf / anyOf
/// with its discriminator), enum values, and the nullable / deprecated facets.
///
/// Mirrors `DocCArticlePage`. Operation pages link here for every `$ref`, so each
/// schema is documented once and deep-linkable. Rendering is delegated to
/// ``OpenAPISchemaHTML`` so the operation and schema pages speak one schema language.
public struct OpenAPISchemaPage: Page {
   private let spec: OpenAPISpec

   /// Creates the schema-page renderer for `spec`.
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func pages(in context: BuildContext) -> [PageModel] {
      self.spec.schemas.map { schema in
         let slug = OpenAPIRoutes.schemaSlug(for: schema.name, in: self.spec)
         let path = OpenAPIRoutes.schemaPath(context, schemaSlug: slug)
         return PageModel(
            title: schema.name,
            slug: slug,
            htmlContent: "",
            sourcePath: context.projectDirectory
               .appendingPathComponent(context.config.contentDirectory)
               .appendingPathComponent("openapi.yaml"),
            summary: schema.schema.description,
            description: schema.schema.description,
            pageType: .staticPage,
            extensions: ["openAPISchema": schema, "openAPIPath": path]
         )
      }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let schema: OpenAPISpec.SchemaObject = page.extensionValue("openAPISchema") else {
         return OpenAPIShell.wrap(content: "", page: page, context: context, head: self.head(page: page, context: context))
      }

      let body =
         "<article class=\"sk-openapi-schema\" data-schema=\"\(OpenAPIHTML.escape(schema.name))\">"
         + "<header class=\"sk-openapi-schema-header\"><h1 class=\"sk-openapi-title\"><code>\(OpenAPIHTML.escape(schema.name))</code></h1></header>"
         + OpenAPISchemaHTML.detail(schema.schema, context: context, spec: self.spec)
         + "</article>"

      return OpenAPIShell.wrap(content: body, page: page, context: context, head: self.head(page: page, context: context))
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.schemaPath(context, schemaSlug: page.slug)
      return OpenAPIRoutes.outputURL(for: path, context: context)
   }

   private func head(page: PageModel, context: BuildContext) -> String {
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.schemaPath(context, schemaSlug: page.slug)
      return OutputFileRenderer(context: context).buildHead(
         title: "\(page.title) – \(context.config.name)",
         description: page.summary,
         canonicalURL: "\(context.config.baseURL)\(path)",
         ogType: "website"
      )
   }
}
