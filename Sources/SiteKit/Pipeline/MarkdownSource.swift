import Foundation

/// A single Markdown file discovered on disk, ready for the `Loader` phase.
///
/// Produced by `ContentDiscovery` and consumed by `MarkdownLoader` (or a
/// custom `Loader`). `filePath` keeps the source location for error reporting
/// and locale derivation; `content` is the raw file bytes decoded as UTF-8.
public struct MarkdownSource {
   /// Absolute file URL of the discovered Markdown file.
   public let filePath: URL

   /// The raw file content (frontmatter included), decoded as UTF-8.
   public let content: String

   /// 1-based line number at which the frontmatter body begins (the first line
   /// after the opening `---`). Optional because most discovery plugins don't
   /// track it; loaders fall back to `2` (the standard YAML frontmatter
   /// convention) when reporting errors.
   public let frontmatterStartLine: Int?

   /// Memberwise initializer.
   public init(filePath: URL, content: String, frontmatterStartLine: Int? = nil) {
      self.filePath = filePath
      self.content = content
      self.frontmatterStartLine = frontmatterStartLine
   }
}
