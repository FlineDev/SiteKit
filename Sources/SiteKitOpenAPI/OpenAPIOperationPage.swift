import Foundation
import SiteKit

/// The leaf page: one page per operation, the richest of the OpenAPI pages. It
/// renders the method badge (`data-method`), the full path, the description, a
/// parameters table, the request-body shape, the responses per status code with
/// their schemas and examples, and the security requirements.
///
/// Mirrors `DocCArticlePage` + `DocCAPIBadges`. **Static-first** (the v1.1.0
/// decision): request/response shapes and examples are rendered as static HTML and
/// there is no live "try-it" request widget; a clearly-marked seam shows where one
/// would mount in a future release.
public struct OpenAPIOperationPage: Page {
   private let spec: OpenAPISpec

   /// Creates the operation-page renderer for `spec`.
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func pages(in context: BuildContext) -> [PageModel] {
      OpenAPIRoutes.tagGroups(self.spec).flatMap { group -> [PageModel] in
         let tagSlug = OpenAPIRoutes.tagSlug(group.tag.name)
         return group.operations.map { operation in
            let operationSlug = OpenAPIRoutes.operationSlug(for: operation)
            let path = OpenAPIRoutes.operationPath(context, tagSlug: tagSlug, operationSlug: operationSlug)
            return PageModel(
               title: operation.summary ?? "\(operation.method) \(operation.path)",
               slug: operationSlug,
               htmlContent: "",
               sourcePath: context.projectDirectory
                  .appendingPathComponent(context.config.contentDirectory)
                  .appendingPathComponent("openapi.yaml"),
               summary: operation.summary ?? operation.description,
               description: operation.description ?? operation.summary,
               pageType: .staticPage,
               extensions: ["openAPIOperation": operation, "openAPIPath": path]
            )
         }
      }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      guard let operation: OpenAPISpec.Operation = page.extensionValue("openAPIOperation") else {
         return OpenAPIShell.wrap(content: "", page: page, context: context, head: self.head(page: page, context: context))
      }

      let body =
         "<article class=\"sk-openapi-operation\">"
         + self.headerHTML(operation)
         + self.parametersHTML(operation, context: context)
         + self.requestBodyHTML(operation, context: context)
         + self.responsesHTML(operation, context: context)
         + self.securityHTML(operation)
         // v1.2.0: a future renderer injects the interactive try-it widget at this seam.
         + "<!-- v1.2.0: try-it widget mounts here -->"
         + "</article>"

      return OpenAPIShell.wrap(content: body, page: page, context: context, head: self.head(page: page, context: context))
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.landingPath(context)
      return OpenAPIRoutes.outputURL(for: path, context: context)
   }

   // MARK: - Body sections

   private func headerHTML(_ operation: OpenAPISpec.Operation) -> String {
      var header = "<header class=\"sk-openapi-op-header\">"
      header += "<div class=\"sk-openapi-op-line\">"
      header += OpenAPIBadges.methodBadge(operation.method)
      header += "<code class=\"sk-openapi-op-path\">\(OpenAPIHTML.escape(operation.path))</code>"
      header += OpenAPIBadges.deprecatedBadge(operation.deprecated)
      header += "</div>"
      if let summary = operation.summary, !summary.isEmpty {
         header += "<h1 class=\"sk-openapi-title\">\(OpenAPIHTML.escape(summary))</h1>"
      }
      if let description = operation.description, !description.isEmpty, description != operation.summary {
         header += "<p class=\"sk-openapi-description\">\(OpenAPIHTML.escape(description))</p>"
      }
      header += "</header>"
      return header
   }

   private func parametersHTML(_ operation: OpenAPISpec.Operation, context: BuildContext) -> String {
      guard !operation.parameters.isEmpty else { return "" }
      let rows = operation.parameters.map { parameter -> String in
         let required =
            parameter.required
            ? "<span class=\"sk-openapi-required\" data-required=\"true\">required</span>"
            : "<span class=\"sk-openapi-optional\">optional</span>"
         let type = parameter.schema.map { OpenAPISchemaHTML.typeLabel($0, context: context) } ?? "<span class=\"sk-openapi-type\">any</span>"
         let description = parameter.description.map { OpenAPIHTML.escape($0) } ?? ""
         return "<tr class=\"sk-openapi-param\">"
            + "<td class=\"sk-openapi-param-name\"><code>\(OpenAPIHTML.escape(parameter.name))</code></td>"
            + "<td class=\"sk-openapi-param-in\" data-in=\"\(OpenAPIHTML.escape(parameter.location.rawValue))\">\(OpenAPIHTML.escape(parameter.location.rawValue))</td>"
            + "<td class=\"sk-openapi-param-required\">\(required)</td>"
            + "<td class=\"sk-openapi-param-type\">\(type)</td>"
            + "<td class=\"sk-openapi-param-desc\">\(description)</td>"
            + "</tr>"
      }.joined()
      return "<section class=\"sk-openapi-parameters\">"
         + "<h2>Parameters</h2>"
         + "<table class=\"sk-openapi-param-table\">"
         + "<thead><tr><th>Name</th><th>In</th><th>Required</th><th>Type</th><th>Description</th></tr></thead>"
         + "<tbody>\(rows)</tbody>"
         + "</table>"
         + "</section>"
   }

   private func requestBodyHTML(_ operation: OpenAPISpec.Operation, context: BuildContext) -> String {
      guard let body = operation.requestBody else { return "" }
      let requiredMarker = body.required ? " <span class=\"sk-openapi-required\" data-required=\"true\">required</span>" : ""
      let description = body.description.map { "<p class=\"sk-openapi-description\">\(OpenAPIHTML.escape($0))</p>" } ?? ""
      return "<section class=\"sk-openapi-request-body\">"
         + "<h2>Request body\(requiredMarker)</h2>"
         + description
         + self.contentHTML(body.content, context: context)
         + "</section>"
   }

   private func responsesHTML(_ operation: OpenAPISpec.Operation, context: BuildContext) -> String {
      guard !operation.responses.isEmpty else { return "" }
      let blocks = operation.responses.map { response -> String in
         let description = response.description.map { "<p class=\"sk-openapi-response-desc\">\(OpenAPIHTML.escape($0))</p>" } ?? ""
         return "<div class=\"sk-openapi-response\" data-status=\"\(OpenAPIHTML.escape(response.statusCode))\">"
            + "<h3 class=\"sk-openapi-status\"><code>\(OpenAPIHTML.escape(response.statusCode))</code></h3>"
            + description
            + self.contentHTML(response.content, context: context)
            + "</div>"
      }.joined()
      return "<section class=\"sk-openapi-responses\"><h2>Responses</h2>\(blocks)</section>"
   }

   /// Renders a content list (request or response): per media type, the content type,
   /// the schema shape (a property table when the schema is an inline object), and the
   /// example when one is declared.
   private func contentHTML(_ content: [OpenAPISpec.MediaType], context: BuildContext) -> String {
      guard !content.isEmpty else { return "" }
      return content.map { media -> String in
         var html = "<div class=\"sk-openapi-media\" data-content-type=\"\(OpenAPIHTML.escape(media.contentType))\">"
         html += "<p class=\"sk-openapi-content-type\"><code>\(OpenAPIHTML.escape(media.contentType))</code></p>"
         if let schema = media.schema {
            html += "<p class=\"sk-openapi-media-type\">\(OpenAPISchemaHTML.typeLabel(schema, context: context))</p>"
            html += OpenAPISchemaHTML.propertyTable(schema, context: context)
         }
         if let example = media.example {
            html += "<details class=\"sk-openapi-example\"><summary>Example</summary>"
            html += "<pre class=\"sk-openapi-example-body\"><code>\(OpenAPIHTML.escape(example))</code></pre>"
            html += "</details>"
         }
         html += "</div>"
         return html
      }.joined()
   }

   private func securityHTML(_ operation: OpenAPISpec.Operation) -> String {
      guard !operation.security.isEmpty else { return "" }
      let requirements = operation.security.map { requirement -> String in
         let schemes = requirement.schemes.map { scheme -> String in
            let scopes = scheme.scopes.isEmpty ? "" : " (\(scheme.scopes.map { OpenAPIHTML.escape($0) }.joined(separator: ", ")))"
            return "<li><code>\(OpenAPIHTML.escape(scheme.name))</code>\(scopes)</li>"
         }.joined()
         return "<ul class=\"sk-openapi-security-set\">\(schemes)</ul>"
      }.joined()
      return "<section class=\"sk-openapi-security\"><h2>Security</h2>\(requirements)</section>"
   }

   private func head(page: PageModel, context: BuildContext) -> String {
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.landingPath(context)
      return OutputFileRenderer(context: context).buildHead(
         title: "\(page.title) – \(context.config.name)",
         description: page.summary ?? page.description,
         canonicalURL: "\(context.config.baseURL)\(path)",
         ogType: "website"
      )
   }
}
