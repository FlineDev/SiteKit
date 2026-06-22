import Foundation
import SiteKit

/// Generates `/llms.txt` for an OpenAPI docs site, listing **every** operation and schema page
/// individually (not just a section count, as the generic `LlmsTxtRenderer` does), so an AI
/// agent can reach any endpoint or model from one curated file.
///
/// Replaces the stock `LlmsTxtRenderer` in the `.openAPI` blueprint: an API surface is bounded
/// and its value to a machine reader is the full endpoint + schema directory, not RSS feeds
/// (which an API docs site has none of). It walks the pages ``OpenAPIContentProvider`` injected
/// into `context.sections`, using each page's stamped `openAPIPath` for the URL – the same
/// ``OpenAPIRoutes`` truth the pages ship at – and groups them into Endpoints and Schemas.
/// `.global` scope: one llms.txt at the site root.
public struct OpenAPILlmsTxtRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let config = context.config
      let baseURL = config.baseURL

      var lines: [String] = []
      lines.append("# \(config.name)")
      lines.append("")
      if !config.description.isEmpty {
         lines.append("> \(config.description)")
         lines.append("")
      }

      lines.append("## Machine-Readable Indexes")
      lines.append("")
      lines.append("- [Sitemap](\(baseURL)/sitemap.xml): Every page URL with last-modified dates")
      lines.append("- [Navigation Index](\(baseURL)/assets/nav-index.json): Structured metadata for every page")
      lines.append("- [Search Index](\(baseURL)/assets/search-index.json): Full-text records per operation and schema")
      lines.append("")

      let openAPIPages = context.sections.flatMap(\.pages)
         .filter { ($0.extensionValue("openAPIPath") as String?) != nil }

      let operations =
         openAPIPages
         .filter { ($0.extensionValue("openAPIOperation") as OpenAPISpec.Operation?) != nil }
      if !operations.isEmpty {
         lines.append("## Endpoints")
         lines.append("")
         for page in operations {
            let operation: OpenAPISpec.Operation? = page.extensionValue("openAPIOperation")
            let url = page.extensionValue("openAPIPath") ?? ""
            let label = operation.map { "\($0.method.uppercased()) \($0.path)" } ?? page.title
            lines.append("- [\(label)](\(baseURL)\(url)): \(self.describe(page))")
         }
         lines.append("")
      }

      // Schemas live under the reserved /schemas/ namespace; classify by that path segment so no
      // OpenAPIKit type is needed here.
      let schemas = openAPIPages.filter { page in
         (page.extensionValue("openAPIPath") as String? ?? "").contains("/schemas/")
      }
      if !schemas.isEmpty {
         lines.append("## Schemas")
         lines.append("")
         for page in schemas {
            let url = page.extensionValue("openAPIPath") ?? ""
            lines.append("- [\(page.title)](\(baseURL)\(url)): \(self.describe(page))")
         }
         lines.append("")
      }

      let content = lines.joined(separator: "\n")
      let path = context.outputDirectory.appendingPathComponent("llms.txt")
      return [OutputFile(outputPath: path, content: content)]
   }

   /// A one-line description for a page: its summary, else its description, else its title.
   private func describe(_ page: PageModel) -> String {
      if let summary = page.summary, !summary.isEmpty { return summary }
      if let description = page.description, !description.isEmpty { return description }
      return page.title
   }
}
