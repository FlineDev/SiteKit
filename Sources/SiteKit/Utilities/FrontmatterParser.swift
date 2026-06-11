import Foundation
import Yams

enum FrontmatterParserError: Error {
   case missingFrontmatter
   case invalidFrontmatter(String)
}

enum FrontmatterParser {
   /// Parses YAML frontmatter delimited by `---` from markdown content.
   /// Returns the parsed metadata dictionary and the remaining body string.
   static func parse(from content: String) throws -> (metadata: [String: Any], body: String) {
      let lines = content.components(separatedBy: .newlines)

      guard lines.first == "---" else {
         throw FrontmatterParserError.missingFrontmatter
      }

      guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
         throw FrontmatterParserError.missingFrontmatter
      }

      let frontmatterLines = lines[1..<endIndex]
      let frontmatterYAML = frontmatterLines.joined(separator: "\n")

      guard let frontmatter = try? Yams.load(yaml: frontmatterYAML) as? [String: Any] else {
         throw FrontmatterParserError.invalidFrontmatter(frontmatterYAML)
      }

      let bodyLines = lines[(endIndex + 1)...]
      let body = bodyLines.joined(separator: "\n")

      return (frontmatter, body)
   }
}
