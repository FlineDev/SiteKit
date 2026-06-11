import Foundation

extension String {
   /// Converts a string to a URL-safe slug (lowercase, alphanumeric, hyphens).
   /// When `language` is `"de"`, handles German umlauts (ä→ae, ö→oe, ü→ue, ß→ss).
   public func slugified(language: String? = nil) -> String {
      var result = self.lowercased()

      // German-specific replacements
      if language == "de" {
         let germanReplacements: [(String, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"),
         ]
         for (from, to) in germanReplacements {
            result = result.replacing(from, with: to)
         }
      }

      let components = result.components(separatedBy: CharacterSet.alphanumerics.inverted)
      return components.filter { !$0.isEmpty }.joined(separator: "-")
   }
}
