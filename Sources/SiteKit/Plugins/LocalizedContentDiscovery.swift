import Foundation

/// Locale-aware content discovery that groups markdown files by language.
///
/// Recognizes Hugo-style locale suffixes in filenames:
/// - `article.md` → default language
/// - `article.de.md` → German
/// - `article.fr.md` → French
///
/// Only recognizes configured language codes as suffixes to avoid false positives
/// (e.g. `my-post.v2.md` won't be treated as a locale file).
public struct LocalizedContentDiscovery: ContentDiscovery {
   private let configuredLanguages: Set<String>
   private let defaultLanguage: String

   public init(defaultLanguage: String, additionalLanguages: [String]) {
      self.defaultLanguage = defaultLanguage
      self.configuredLanguages = Set(additionalLanguages)
   }

   /// Standard discovery: returns only default-language files (backward compatible).
   public func discover(in directory: URL) throws -> [MarkdownSource] {
      let all = try self.discoverLocalized(in: directory)
      return all[self.defaultLanguage] ?? []
   }

   /// Returns all content grouped by locale.
   ///
   /// Files without a locale suffix are assigned to `defaultLanguage`.
   /// Files with a recognized locale suffix (e.g. `.de.md`) are grouped under that locale.
   public func discoverLocalized(in directory: URL) throws -> [String: [MarkdownSource]] {
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: directory.path) else {
         return [:]
      }

      let contents = try fileManager.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: nil,
         options: [.skipsHiddenFiles]
      )

      let markdownFiles = contents.filter { $0.pathExtension == "md" }.sorted { $0.path < $1.path }

      var grouped: [String: [MarkdownSource]] = [:]

      for fileURL in markdownFiles {
         let locale = self.parseLocale(from: fileURL)
         let content = try String(contentsOf: fileURL, encoding: .utf8)
         let source = MarkdownSource(filePath: fileURL, content: content)
         grouped[locale, default: []].append(source)
      }

      return grouped
   }

   /// Parses the locale from a filename.
   ///
   /// `2025-01-01-my-post.de.md` → `"de"`
   /// `2025-01-01-my-post.md` → defaultLanguage
   /// `home.fr.md` → `"fr"`
   private func parseLocale(from fileURL: URL) -> String {
      let filename = fileURL.deletingPathExtension().lastPathComponent // e.g. "2025-01-01-my-post.de"
      let parts = filename.split(separator: ".")
      guard parts.count >= 2 else { return self.defaultLanguage }

      let potentialLocale = String(parts.last!)
      if self.configuredLanguages.contains(potentialLocale) {
         return potentialLocale
      }
      return self.defaultLanguage
   }

   /// Returns the base filename (without locale suffix) for matching translations across languages.
   ///
   /// `2025-01-01-my-post.de.md` → `"2025-01-01-my-post"`
   /// `2025-01-01-my-post.md` → `"2025-01-01-my-post"`
   public func baseFilename(for fileURL: URL) -> String {
      let filename = fileURL.deletingPathExtension().lastPathComponent
      let parts = filename.split(separator: ".")
      guard parts.count >= 2 else { return filename }

      let potentialLocale = String(parts.last!)
      if self.configuredLanguages.contains(potentialLocale) {
         return parts.dropLast().joined(separator: ".")
      }
      return filename
   }
}
