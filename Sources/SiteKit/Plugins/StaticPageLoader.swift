import Foundation

/// Parses a `MarkdownSource` into a `PageModel` with
/// `pageType: .staticPage` for top-level pages like about, privacy, imprint,
/// changelog – anything that lives outside a date-driven section.
///
/// Validation goes through the same `requiredFields:` contract `MarkdownLoader`
/// uses, with `["title", "slug"]` as the default (slug is mandatory because
/// static pages map directly to URLs at the site root and the author should
/// choose the URL consciously). Both loaders raise the same
/// `MarkdownLoaderError.missingRequiredField(field:sourcePath:line:)` shape so
/// build-error messages and `catch` recipes are uniform.
public struct StaticPageLoader: Loader {
   public typealias Source = MarkdownSource
   public typealias Output = PageModel

   /// Frontmatter keys that must be present (and non-empty) for a static page
   /// to load successfully. Default `["title", "slug"]` matches v0.9 behavior.
   /// Pass `[]` to disable validation entirely; pass a custom list to enforce
   /// additional fields (e.g. `["title", "slug", "description"]`).
   public let requiredFields: [String]
   private let markdownRenderer: MarkdownRenderer

   public init(requiredFields: [String] = ["title", "slug"]) {
      self.requiredFields = requiredFields
      self.markdownRenderer = MarkdownRenderer()
   }

   public func load(source: MarkdownSource) throws -> PageModel {
      let (frontmatter, markdownBody) = try FrontmatterParser.parse(from: source.content)

      try MarkdownLoader.validateRequiredFields(
         self.requiredFields,
         frontmatter: frontmatter,
         source: source,
         filenameDate: nil
      )

      // After validation, the required fields are guaranteed non-empty when
      // present in `requiredFields`. Treat missing-but-not-required as empty
      // strings – the same forgiving behaviour `MarkdownLoader` provides.
      let title = frontmatter["title"] as? String ?? ""
      let slug = frontmatter["slug"] as? String ?? ""
      let htmlContent = self.markdownRenderer.render(markdownBody, strippingTitleMatching: title)
      let description = frontmatter["description"] as? String
      let image = frontmatter["image"] as? String
      let id = frontmatter["id"] as? String
      let draft = frontmatter["draft"] as? Bool ?? false
      let legalDocument = frontmatter["legalDocument"] as? Bool ?? false

      return PageModel(
         id: id,
         title: title,
         slug: slug,
         htmlContent: htmlContent,
         sourcePath: source.filePath,
         description: description,
         image: image,
         draft: draft,
         pageType: .staticPage,
         legalDocument: legalDocument
      )
   }
}
