import SiteKit
import SwiftIDEUtils
import SwiftParser
import SwiftSyntax

/// A SwiftSyntax-based code highlighter that classifies Swift tokens by their syntactic role and
/// emits a distinct `sk-tok-<role>` span per role, for an Xcode-like, semantic-near palette.
///
/// Compared with the regex `CodeHighlighter` (which only recognizes keywords, strings, comments,
/// numbers, attributes, and capitalized type names), this highlighter additionally distinguishes
/// value references (`stickers` → `variable`, rendered green), function calls (`call`), member
/// accesses (`member`), parameter bindings (`param`), booleans/`nil` (`boolean`), and argument
/// labels (`label`). It does so purely from the parsed syntax tree – no type-checker or symbol
/// graph – so it is fast and error-tolerant on the partial code fragments common in DocC notes.
///
/// The classification is SYNTACTIC, not semantic: every capitalized type (initializer, annotation,
/// or bare reference) gets the single `type` role, exactly like the regex `CodeHighlighter`. The
/// extra value this highlighter adds is the EXPRESSION-position roles the regex pass cannot see –
/// the green `variable` references above all.
///
/// Non-Swift snippets (and nil/empty languages) are delegated to a fallback highlighter – by
/// default the zero-dependency regex `CodeHighlighter` – so a DocC site can inject this single
/// highlighter and still get reasonable coloring for its Python, shell, or YAML blocks.
public struct SwiftSyntaxHighlighter: CodeHighlighting {
   private let fallback: any CodeHighlighting

   /// Creates a SwiftSyntax-based highlighter.
   ///
   /// - Parameter fallback: The highlighter used for non-Swift snippets and nil/empty languages. Pass
   ///   nil (the default) to use the zero-dependency regex `CodeHighlighter`. Resolved internally so
   ///   the default does not reference an internal type across the module boundary.
   public init(fallback: (any CodeHighlighting)? = nil) {
      self.fallback = fallback ?? CodeHighlighter()
   }

   public func highlight(code: String, language: String?) -> String {
      guard let language = language?.lowercased().trimmingCharacters(in: .whitespaces),
            language == "swift" else {
         return self.fallback.highlight(code: code, language: language)
      }
      return self.highlightSwift(code)
   }

   // MARK: - Swift highlighting

   /// Parses `code`, merges the base syntactic classification with the per-token role refinement,
   /// and emits one HTML fragment of escaped, role-tagged spans.
   func highlightSwift(_ code: String) -> String {
      let bytes = Array(code.utf8)
      let count = bytes.count
      guard count > 0 else { return "" }

      let tree = Parser.parse(source: code)
      let roleMap = SwiftTokenRoleClassifier.classify(tree)

      var output = ""
      var cursor = 0

      // The classification stream is ordered and non-overlapping. Any byte range it does not cover
      // (whitespace, punctuation classified `.none`) is emitted as plain escaped text via the gap
      // fill below, so the full source is always reproduced exactly once.
      for classified in tree.classifications {
         let lower = classified.range.lowerBound.utf8Offset
         let upper = classified.range.upperBound.utf8Offset
         guard lower < upper, lower >= cursor, upper <= count else { continue }

         if lower > cursor {
            output += Self.escapedSlice(bytes, from: cursor, to: lower)
         }

         let text = Self.escapedSlice(bytes, from: lower, to: upper)
         if let role = self.role(forKind: classified.kind, offset: lower, bytes: bytes, from: lower, to: upper, roleMap: roleMap) {
            output += "<span class=\"sk-tok-\(role)\">\(text)</span>"
         } else {
            output += text
         }
         cursor = upper
      }

      if cursor < count {
         output += Self.escapedSlice(bytes, from: cursor, to: count)
      }
      return output
   }

   /// Resolves the final `sk-tok-*` role class for one classified range: a visitor refinement when
   /// present, otherwise a direct mapping of the base `SyntaxClassification`.
   private func role(
      forKind kind: SyntaxClassification,
      offset: Int,
      bytes: [UInt8],
      from lower: Int,
      to upper: Int,
      roleMap: [Int: String]
   ) -> String? {
      if let refined = roleMap[offset] {
         return refined
      }
      switch kind {
      case .keyword, .ifConfigDirective:
         return "keyword"
      case .type:
         // A token the base pass already knows sits in TYPE position (`View` in `: View`, `Sticker`
         // in `[Sticker]`). Every capitalized type gets the single `type` role, matching the regex
         // highlighter and the expression-visitor types above.
         return "type"
      case .stringLiteral, .regexLiteral:
         return "string"
      case .integerLiteral, .floatLiteral:
         return "number"
      case .attribute:
         return "attribute"
      case .lineComment, .blockComment, .docLineComment, .docBlockComment:
         return "comment"
      case .operator:
         return "operator"
      case .argumentLabel:
         return "label"
      case .dollarIdentifier:
         // `$0`, `$1` – anonymous closure arguments, i.e. value references.
         return "variable"
      case .identifier:
         // An identifier the role visitor did not refine. Mirror the regex highlighter's only
         // heuristic – a capitalized identifier is a `type`; leave anything else uncolored rather
         // than guess.
         let text = String(decoding: bytes[lower..<upper], as: UTF8.self)
         return text.first?.isUppercase == true ? "type" : nil
      case .editorPlaceholder, .none:
         return nil
      @unknown default:
         return nil
      }
   }

   /// Decodes `bytes[lower..<upper]` (always on valid UTF-8 boundaries, since the range comes from
   /// token/classification offsets) and HTML-escapes it for safe embedding inside a `<code>` span.
   private static func escapedSlice(_ bytes: [UInt8], from lower: Int, to upper: Int) -> String {
      HTMLEscaping.escape(String(decoding: bytes[lower..<upper], as: UTF8.self))
   }
}
