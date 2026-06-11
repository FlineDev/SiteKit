import Foundation

/// Represents a missing translation file.
public struct MissingTranslation: Sendable {
   /// Filename of the default-language source that lacks a translation.
   public let sourceFile: String

   /// Language code of the missing translation.
   public let locale: String

   /// Filename the translation is expected at (locale-suffix convention,
   /// e.g. `About.de.md`).
   public let expectedFile: String

   /// Memberwise initializer.
   public init(sourceFile: String, locale: String, expectedFile: String) {
      self.sourceFile = sourceFile
      self.locale = locale
      self.expectedFile = expectedFile
   }
}

/// Checks for missing translations by comparing default-language files against
/// available translations for each configured language.
public enum TranslationStatus {
   /// Compares default-language content files against translations for each target language.
   ///
   /// Iterates the supplied `sections` (typically `SiteConfig.effectiveSections`) and the
   /// optional `staticPagesDirectory` to discover content folders to check. Each section's
   /// `contentDirectory` is resolved relative to `contentDirectory`. A folder is visited
   /// only once even if both a section and `staticPagesDirectory` reference the same name.
   ///
   /// - Parameters:
   ///   - contentDirectory: Root content directory (e.g. `Content/`).
   ///   - defaultLanguage: The default language code.
   ///   - targetLanguages: Additional language codes to check.
   ///   - localizedDiscovery: The content discovery instance to use.
   ///   - sections: Section configs to check. Typically `SiteConfig.effectiveSections`.
   ///   - staticPagesDirectory: Subdirectory holding static (non-sectioned) pages, or `nil`
   ///     when the site has no static-pages folder. Defaults to `"Pages"` for back-compat
   ///     with SiteKit's standard layout.
   /// - Returns: List of missing translations.
   public static func check(
      contentDirectory: URL,
      defaultLanguage: String,
      targetLanguages: [String],
      localizedDiscovery: LocalizedContentDiscovery,
      sections: [SectionConfig],
      staticPagesDirectory: String? = "Pages"
   ) -> [MissingTranslation] {
      guard !targetLanguages.isEmpty else { return [] }

      var missing: [MissingTranslation] = []
      var visited: Set<String> = []

      for section in sections {
         let dirName = section.contentDirectory
         guard visited.insert(dirName).inserted else { continue }
         let dir = contentDirectory.appendingPathComponent(dirName)
         missing.append(contentsOf: self.checkDirectory(
            dir,
            defaultLanguage: defaultLanguage,
            targetLanguages: targetLanguages,
            localizedDiscovery: localizedDiscovery
         ))
      }

      if let staticName = staticPagesDirectory, visited.insert(staticName).inserted {
         let dir = contentDirectory.appendingPathComponent(staticName)
         missing.append(contentsOf: self.checkDirectory(
            dir,
            defaultLanguage: defaultLanguage,
            targetLanguages: targetLanguages,
            localizedDiscovery: localizedDiscovery
         ))
      }

      return missing
   }

   private static func checkDirectory(
      _ directory: URL,
      defaultLanguage: String,
      targetLanguages: [String],
      localizedDiscovery: LocalizedContentDiscovery
   ) -> [MissingTranslation] {
      guard let content = try? localizedDiscovery.discoverLocalized(in: directory) else { return [] }
      let defaultSources = content[defaultLanguage] ?? []
      guard !defaultSources.isEmpty else { return [] }
      let defaultBases = defaultSources.map { localizedDiscovery.baseFilename(for: $0.filePath) }

      var missing: [MissingTranslation] = []
      for locale in targetLanguages {
         let translatedSources = content[locale] ?? []
         let translatedBases = Set(translatedSources.map { localizedDiscovery.baseFilename(for: $0.filePath) })

         for base in defaultBases where !translatedBases.contains(base) {
            missing.append(MissingTranslation(
               sourceFile: "\(base).md",
               locale: locale,
               expectedFile: "\(base).\(locale).md"
            ))
         }
      }
      return missing
   }
}
