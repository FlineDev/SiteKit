import Foundation

/// A single YAML file ready for `YAMLLoader<T>` to decode into a `Decodable`
/// model.
///
/// `SiteConfig`, `ThemeConfig`, and section-level configuration files all
/// arrive in the pipeline as `YAMLSource` values. The `init(url:)`
/// convenience reads + UTF-8-decodes in one step for the common case.
public struct YAMLSource {
   /// Absolute file URL of the YAML file – kept for error reporting.
   public let filePath: URL

   /// The raw YAML text.
   public let content: String

   /// Creates a source from already-loaded YAML text.
   public init(filePath: URL, content: String) {
      self.filePath = filePath
      self.content = content
   }

   /// Reads and UTF-8-decodes the file at `url` in one step.
   public init(url: URL) throws {
      self.filePath = url
      self.content = try String(contentsOf: url, encoding: .utf8)
   }
}
