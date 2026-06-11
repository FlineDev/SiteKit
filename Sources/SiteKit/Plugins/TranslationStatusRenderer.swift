import Foundation

/// Writes `translation-status.json` at the site root with the list of pages
/// missing translations per locale, plus the configured `translationMode`
/// and `styleGuidePath`.
///
/// AI agents consume this file to know exactly which sources need
/// translating and to which language; the style guide path lets them load
/// the project's tone-of-voice guidance in the same step. Always `.global`
/// scope. Part of the AI-friendliness cross-cutting concern.
public struct TranslationStatusRenderer: Renderer {
   public var scope: RenderScope { .global }

   private let missingTranslations: [MissingTranslation]
   private let translationMode: String
   private let styleGuidePath: String?

   public init(
      missingTranslations: [MissingTranslation],
      translationMode: String,
      styleGuidePath: String?
   ) {
      self.missingTranslations = missingTranslations
      self.translationMode = translationMode
      self.styleGuidePath = styleGuidePath
   }

   public func render(context: BuildContext) throws -> [OutputFile] {
      var json: [String: Any] = [
         "translationMode": self.translationMode,
         "missingCount": self.missingTranslations.count,
      ]

      if let styleGuidePath {
         json["styleGuidePath"] = styleGuidePath
      }

      let missingEntries: [[String: String]] = self.missingTranslations.map { entry in
         [
            "sourceFile": entry.sourceFile,
            "locale": entry.locale,
            "expectedFile": entry.expectedFile,
         ]
      }
      json["missing"] = missingEntries

      let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
      let content = String(data: data, encoding: .utf8) ?? "{}"

      let outputPath = context.outputDirectory.appendingPathComponent("translation-status.json")
      return [OutputFile(outputPath: outputPath, content: content)]
   }
}
