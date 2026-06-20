import Foundation
import SiteKit

/// One page per tag: the tag's name and description, followed by the list of its
/// operations (method badge + path + summary), each linking to its operation page.
///
/// Mirrors `DocCArticlePage`'s shape (a titled article wrapped in the shell). The
/// tag-to-operation grouping comes from ``OpenAPIRoutes/tagSections(_:)``, so the tag
/// pages list exactly the operations the landing cards count and the operation URLs
/// nest under.
public struct OpenAPITagPage: Page {
   private let spec: OpenAPISpec

   /// Creates the tag-page renderer for `spec`.
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func pages(in context: BuildContext) -> [PageModel] {
      OpenAPIRoutes.tagSections(self.spec).map { section in
         let path = OpenAPIRoutes.tagPath(context, tagSlug: section.slug)
         return PageModel(
            title: section.tag.name,
            slug: section.slug,
            htmlContent: "",
            sourcePath: self.syntheticSource(context: context, slug: section.slug),
            summary: section.tag.description,
            description: section.tag.description,
            pageType: .staticPage,
            extensions: ["openAPITagName": section.tag.name, "openAPIPath": path]
         )
      }
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let tagName: String = page.extensionValue("openAPITagName") ?? page.title
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.tagPath(context, tagSlug: page.slug)
      guard let section = OpenAPIRoutes.tagSections(self.spec).first(where: { $0.tag.name == tagName }) else {
         // The tag vanished from the spec between pages(in:) and render – render an empty shell.
         return OpenAPIShell.wrap(
            content: "",
            page: page,
            context: context,
            head: self.head(page: page, path: path, context: context),
            spec: self.spec
         )
      }

      let body =
         "<article class=\"sk-openapi-tag\">"
         + self.headerHTML(section: section)
         + self.operationListHTML(section: section, context: context)
         + "</article>"

      return OpenAPIShell.wrap(
         content: body,
         page: page,
         context: context,
         head: self.head(page: page, path: path, context: context),
         spec: self.spec
      )
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      let path: String = page.extensionValue("openAPIPath") ?? OpenAPIRoutes.tagPath(context, tagSlug: page.slug)
      return OpenAPIRoutes.outputURL(for: path, context: context)
   }

   // MARK: - Body

   private func headerHTML(section: OpenAPIRoutes.TagSection) -> String {
      var header = "<header class=\"sk-openapi-tag-header\">"
      header += "<h1 class=\"sk-openapi-title\">\(OpenAPIHTML.escape(section.tag.name))</h1>"
      if let description = section.tag.description, !description.isEmpty {
         header += "<p class=\"sk-openapi-description\">\(OpenAPIHTML.escape(description))</p>"
      }
      header += "</header>"
      return header
   }

   private func operationListHTML(section: OpenAPIRoutes.TagSection, context: BuildContext) -> String {
      let rows = section.operations.map { ref -> String in
         let operation = ref.operation
         // Every entry links to the operation's one canonical page (under its first
         // tag), so a cross-listed operation never spawns a duplicate URL.
         let href = OpenAPIHTML.escape(
            OpenAPIRoutes.operationPath(context, tagSlug: ref.canonicalTagSlug, operationSlug: ref.slug)
         )
         let summary = operation.summary.map { "<span class=\"sk-openapi-op-summary\">\(OpenAPIHTML.escape($0))</span>" } ?? ""
         return "<li class=\"sk-openapi-op-item\">"
            + "<a class=\"sk-openapi-op-link\" href=\"\(href)\">"
            + OpenAPIBadges.methodBadge(operation.method)
            + "<code class=\"sk-openapi-op-path\">\(OpenAPIHTML.escape(operation.path))</code>"
            + summary
            + OpenAPIBadges.deprecatedBadge(operation.deprecated)
            + "</a>"
            + "</li>"
      }.joined()
      return "<ul class=\"sk-openapi-op-list\">\(rows)</ul>"
   }

   private func head(page: PageModel, path: String, context: BuildContext) -> String {
      OutputFileRenderer(context: context).buildHead(
         title: "\(page.title) – \(context.config.name)",
         description: page.summary,
         canonicalURL: "\(context.config.baseURL)\(path)",
         ogType: "website"
      )
   }

   private func syntheticSource(context: BuildContext, slug: String) -> URL {
      context.projectDirectory
         .appendingPathComponent(context.config.contentDirectory)
         .appendingPathComponent("openapi.yaml")
   }
}
