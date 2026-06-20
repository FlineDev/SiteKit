import Foundation
import SiteKit

/// The landing page of the OpenAPI docs site: the API title and description, an
/// optional `Content/api-intro.md` prose block, and a card per tag linking to that
/// tag's page.
///
/// Mirrors `DocCHomePage`: it emits a single synthetic `PageModel` (not backed by a
/// Markdown file) and wraps its body in the `OpenAPIShell`. The cards come from
/// ``OpenAPIRoutes/tagSections(_:)`` so the landing, tag pages, and operation URLs
/// agree on which operations belong to which tag.
public struct OpenAPILandingPage: Page {
   private let spec: OpenAPISpec

   /// Creates the landing renderer for `spec`.
   public init(spec: OpenAPISpec) {
      self.spec = spec
   }

   public func pages(in context: BuildContext) -> [PageModel] {
      [
         PageModel(
            title: self.spec.info.title,
            slug: OpenAPIRoutes.prefix(context),
            htmlContent: "",
            sourcePath: context.projectDirectory.appendingPathComponent("\(context.config.contentDirectory)/openapi.yaml"),
            summary: self.spec.info.description,
            description: self.spec.info.description,
            pageType: .staticPage
         )
      ]
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let path = OpenAPIRoutes.landingPath(context)
      let renderer = OutputFileRenderer(context: context)
      let head = renderer.buildHead(
         title: "\(self.spec.info.title) – \(context.config.name)",
         description: self.spec.info.description,
         canonicalURL: "\(context.config.baseURL)\(path)",
         ogType: "website"
      )

      let body =
         "<article class=\"sk-openapi-landing\">"
         + self.headerHTML()
         + self.introHTML(context: context)
         + self.tagCardsHTML(context: context)
         + "</article>"

      return OpenAPIShell.wrap(content: body, page: page, context: context, head: head, spec: self.spec)
   }

   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      OpenAPIRoutes.outputURL(for: OpenAPIRoutes.landingPath(context), context: context)
   }

   // MARK: - Body sections

   /// The API title + version + description header.
   private func headerHTML() -> String {
      let info = self.spec.info
      var header = "<header class=\"sk-openapi-landing-header\">"
      header += "<h1 class=\"sk-openapi-title\">\(OpenAPIHTML.escape(info.title))</h1>"
      header += "<p class=\"sk-openapi-version\">\(OpenAPIHTML.escape(info.version))</p>"
      if let description = info.description, !description.isEmpty {
         header += "<p class=\"sk-openapi-description\">\(OpenAPIHTML.escape(description))</p>"
      }
      header += "</header>"
      return header
   }

   /// Optional getting-started prose from `Content/api-intro.md`. Returns an empty
   /// string when the file is absent, so the landing is a no-op without it.
   private func introHTML(context: BuildContext) -> String {
      let url = context.projectDirectory
         .appendingPathComponent(context.config.contentDirectory)
         .appendingPathComponent("api-intro.md")
      guard let markdown = try? String(contentsOf: url, encoding: .utf8) else { return "" }
      // Reuse SiteKit's Markdown loader (no required frontmatter) to render the prose
      // to HTML, so api-intro.md supports the same Markdown as the rest of a SiteKit site.
      let source = MarkdownSource(filePath: url, content: markdown)
      guard let page = try? MarkdownLoader(requiredFields: []).load(source: source) else { return "" }
      return "<section class=\"sk-openapi-intro\">\(page.htmlContent)</section>"
   }

   /// A card per tag section, linking to the tag page. The endpoint count reflects
   /// every operation listed under the tag (an operation is counted under each tag it
   /// carries), matching what the tag page shows.
   private func tagCardsHTML(context: BuildContext) -> String {
      let sections = OpenAPIRoutes.tagSections(self.spec)
      guard !sections.isEmpty else { return "" }

      let cards = sections.map { section -> String in
         let href = OpenAPIHTML.escape(OpenAPIRoutes.tagPath(context, tagSlug: section.slug))
         let count = section.operations.count
         let countLabel = count == 1 ? "1 endpoint" : "\(count) endpoints"
         var card = "<a class=\"sk-openapi-tag-card\" href=\"\(href)\">"
         card += "<h2 class=\"sk-openapi-tag-card-title\">\(OpenAPIHTML.escape(section.tag.name))</h2>"
         if let description = section.tag.description, !description.isEmpty {
            card += "<p class=\"sk-openapi-tag-card-desc\">\(OpenAPIHTML.escape(description))</p>"
         }
         card += "<p class=\"sk-openapi-tag-card-count\">\(countLabel)</p>"
         card += "</a>"
         return card
      }.joined()

      return "<section class=\"sk-openapi-tag-cards\">\(cards)</section>"
   }
}
