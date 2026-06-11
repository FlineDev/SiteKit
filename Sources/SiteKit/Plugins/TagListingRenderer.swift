import Foundation

/// Renders one HTML page per tag listing the pages tagged with it, plus a
/// single `/tags/` index page that catalogues every tag.
///
/// Source data is `BuildContext.tags` (tag → `[PageModel]`), which the
/// pipeline builds during loading from `tags:` frontmatter. Display names
/// honour `SiteConfig.tagDisplayNames` for locale-aware overrides. Skipped
/// (returns no files) when no page declares a tag.
public struct TagListingRenderer: Renderer {
   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard !context.tags.isEmpty else { return [] }

      let renderer = OutputFileRenderer(context: context)

      var files: [OutputFile] = []

      // Individual tag pages
      for (tag, tagPages) in context.tags.sorted(by: { $0.key < $1.key }) {
         let file = renderer.renderTagListing(tag: tag, pages: tagPages, sections: context.sections)
         files.append(file)
      }

      // Tags index page
      let tagsIndex = renderer.renderTagsIndex(tags: context.tags)
      files.append(tagsIndex)

      return files
   }
}
