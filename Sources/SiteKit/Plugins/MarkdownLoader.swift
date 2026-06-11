import Foundation

public enum MarkdownLoaderError: LocalizedError {
   case missingRequiredField(field: String, sourcePath: String, line: Int)
   case invalidDateFormat(String)

   public var errorDescription: String? {
      switch self {
      case .missingRequiredField(let field, let path, let line):
         return "Error: \(path):\(line): required frontmatter field '\(field)' is missing or empty"
      case .invalidDateFormat(let dateString):
         return "Invalid date format: \(dateString)"
      }
   }
}

/// Parses a `MarkdownSource` into a `PageModel`: extracts YAML frontmatter,
/// validates the configured `requiredFields`, renders the Markdown body to
/// HTML, and derives `date`/`slug` from the filename when needed.
///
/// `requiredFields` is the fail-fast list. The default `["title", "date"]`
/// matches blog content. Blueprints customise it (podcast episodes require
/// `audioURL`, `duration`; some sites add `imageAlt` to enforce
/// accessibility). Pass `[]` to skip validation entirely.
///
/// `date` is special: if the source filename matches the
/// `YYYY-MM-DD-slug.md` convention, the date is recovered from the filename
/// even when the frontmatter omits the key. Equivalent fallback applies to
/// `slug` (filename stem becomes the slug).
public struct MarkdownLoader: Loader {
   public typealias Source = MarkdownSource
   public typealias Output = PageModel

   /// Frontmatter keys that must be present (and non-empty) for a markdown file
   /// to load successfully. The default `["title", "date"]` matches v0.9 behavior.
   /// Blueprints can pass a different list (e.g. podcast episodes additionally require
   /// `["audioURL", "duration"]`). Pass `[]` to disable validation entirely.
   ///
   /// "date" has a special case: it is also accepted when the filename matches the
   /// `YYYY-MM-DD-slug.md` convention even if the frontmatter omits the key.
   public let requiredFields: [String]
   private let markdownRenderer: MarkdownRenderer
   private let language: String?

   public init(requiredFields: [String] = ["title", "date"], language: String? = nil) {
      self.requiredFields = requiredFields
      self.markdownRenderer = MarkdownRenderer()
      self.language = language
   }

   public func load(source: MarkdownSource) throws -> PageModel {
      let (frontmatter, markdownBody) = try FrontmatterParser.parse(from: source.content)
      let filenameComponents = self.parseFilenameComponents(source.filePath)

      try self.validateRequiredFields(frontmatter, source: source, filenameDate: filenameComponents.date)

      let title = frontmatter["title"] as? String ?? ""

      let date: Date?
      if let dateValue = frontmatter["date"] {
         date = try self.parseDate(from: dateValue)
      } else if let filenameDate = filenameComponents.date {
         date = filenameDate
      } else {
         date = nil
      }

      let slug = (frontmatter["slug"] as? String) ?? filenameComponents.slug ?? title.slugified(language: self.language)
      let htmlContent = self.markdownRenderer.render(markdownBody, strippingTitleMatching: title)

      let category = frontmatter["category"] as? String ?? ""
      let tags = self.parseTags(from: frontmatter)
      let summary = frontmatter["summary"] as? String
      let author = frontmatter["author"].flatMap { Person.from(frontmatterValue: $0) }
      let image = frontmatter["image"] as? String
      let imageAlt = frontmatter["imageAlt"] as? String
      // YAML parsers may interpret hex-like IDs (e.g. "deadbeef") as integers
      let id: String?
      if let stringID = frontmatter["id"] as? String {
         id = stringID
      } else if let rawID = frontmatter["id"] {
         // Yams may parse hex-like values as Int, or other types
         id = String(describing: rawID)
      } else {
         id = nil
      }
      let draft = frontmatter["draft"] as? Bool ?? false
      let originalLanguage = frontmatter["originalLanguage"] as? String

      // Pass unknown frontmatter fields to PageModel.extensions for custom access
      let knownKeys: Set<String> = [
         "title", "date", "slug", "category", "tags", "summary", "author",
         "image", "imageAlt", "id", "draft", "originalLanguage",
         "description", "legalDocument",
      ]
      var extensions: [String: any Sendable] = [:]
      for (key, value) in frontmatter where !knownKeys.contains(key) {
         // YAML values are basic types (String, Int, Bool, Double, [Any], [String: Any])
         // which are all Sendable – store them directly for custom frontmatter access
         if let string = value as? String {
            extensions[key] = string
         } else if let int = value as? Int {
            extensions[key] = int
         } else if let double = value as? Double {
            extensions[key] = double
         } else if let bool = value as? Bool {
            extensions[key] = bool
         } else if let strings = value as? [String] {
            extensions[key] = strings
         } else if let arrayOfDicts = value as? [[String: Any]] {
            // Support arrays of dictionaries (e.g. chapters with start/title)
            let sendable: [[String: String]] = arrayOfDicts.compactMap { dict in
               var result: [String: String] = [:]
               for (k, v) in dict {
                  result[k] = String(describing: v)
               }
               return result
            }
            extensions[key] = sendable
         }
      }

      return PageModel(
         id: id,
         title: title,
         date: date,
         slug: slug,
         htmlContent: htmlContent,
         sourcePath: source.filePath,
         category: category,
         tags: tags,
         summary: summary,
         author: author,
         image: image,
         imageAlt: imageAlt,
         draft: draft,
         originalLanguage: originalLanguage,
         extensions: extensions
      )
   }

   private func validateRequiredFields(
      _ frontmatter: [String: Any],
      source: MarkdownSource,
      filenameDate: Date?
   ) throws {
      try MarkdownLoader.validateRequiredFields(
         self.requiredFields,
         frontmatter: frontmatter,
         source: source,
         filenameDate: filenameDate
      )
   }

   /// Shared validation entry point. `StaticPageLoader` reuses this so both
   /// loaders raise the same `MarkdownLoaderError.missingRequiredField` shape
   /// against the same `requiredFields:` contract.
   static func validateRequiredFields(
      _ requiredFields: [String],
      frontmatter: [String: Any],
      source: MarkdownSource,
      filenameDate: Date?
   ) throws {
      let line = source.frontmatterStartLine ?? 2
      let path = source.filePath.path
      for field in requiredFields {
         // "date" is satisfied by the filename prefix even when frontmatter omits it.
         if field == "date" {
            if frontmatter["date"] != nil && !(frontmatter["date"] is NSNull) {
               if let stringValue = frontmatter["date"] as? String,
                  stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                  throw MarkdownLoaderError.missingRequiredField(field: field, sourcePath: path, line: line)
               }
               continue
            }
            if filenameDate != nil { continue }
            throw MarkdownLoaderError.missingRequiredField(field: field, sourcePath: path, line: line)
         }

         let value = frontmatter[field]
         if value == nil || value is NSNull {
            throw MarkdownLoaderError.missingRequiredField(field: field, sourcePath: path, line: line)
         }
         if let stringValue = value as? String,
            stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MarkdownLoaderError.missingRequiredField(field: field, sourcePath: path, line: line)
         }
      }
   }

   private func parseFilenameComponents(_ filePath: URL) -> (date: Date?, slug: String?) {
      let filename = filePath.deletingPathExtension().lastPathComponent

      let pattern = /^(\d{4}-\d{2}-\d{2})-(.+)$/
      guard let match = filename.wholeMatch(of: pattern) else {
         return (nil, nil)
      }

      let dateString = String(match.1)
      let slug = String(match.2)

      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      let date = formatter.date(from: dateString)

      return (date, slug)
   }

   private func parseTags(from frontmatter: [String: Any]) -> [String] {
      if let tags = frontmatter["tags"] as? [String] {
         return tags
      }
      if let tags = frontmatter["tags"] as? String {
         return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      }
      return []
   }

   private func parseDate(from value: Any) throws -> Date {
      if let date = value as? Date {
         return date
      }

      if let dateString = value as? String {
         let formatter = ISO8601DateFormatter()
         formatter.formatOptions = [.withFullDate]

         if let date = formatter.date(from: dateString) {
            return date
         }

         let dateOnlyFormatter = DateFormatter()
         dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

         if let date = dateOnlyFormatter.date(from: dateString) {
            return date
         }

         throw MarkdownLoaderError.invalidDateFormat(dateString)
      }

      throw MarkdownLoaderError.invalidDateFormat(String(describing: value))
   }

}
