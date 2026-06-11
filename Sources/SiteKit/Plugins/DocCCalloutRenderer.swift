import Foundation
import Markdown

/// Maps standard DocC callout blockquotes to styled `sk-docc-callout` components.
///
/// A callout is a blockquote whose first paragraph begins with one of the five
/// recognised DocC callout kinds (case-insensitive, optional bold wrapping):
/// `Tip:`, `Note:`, `Important:`, `Warning:`, `Experiment:`.
///
/// Input (markdown author writes):
/// ```
/// > Tip: Enable dark mode in Settings to reduce eye strain at night.
/// ```
///
/// Output:
/// ```html
/// <div class="sk-docc-callout sk-docc-callout--tip">
///   <span class="sk-docc-callout-label">Tip</span>
///   <div>Enable dark mode in Settings to reduce eye strain at night.</div>
/// </div>
/// ```
///
/// The badge text comes from `UIStrings` (keys `doccCalloutTip` etc.), so any
/// site can localise it. Returns `nil` for any blockquote that is not a callout
/// so the caller falls back to default blockquote rendering.
public struct DocCCalloutRenderer {
   /// Recognised callout kinds. Lowercased for case-insensitive matching.
   public enum Kind: String, CaseIterable {
      case tip
      case note
      case important
      case warning
      case experiment

      /// The `UIStringKey` whose localised value is used as the badge label.
      var uiStringKey: UIStringKey {
         switch self {
         case .tip: return .doccCalloutTip
         case .note: return .doccCalloutNote
         case .important: return .doccCalloutImportant
         case .warning: return .doccCalloutWarning
         case .experiment: return .doccCalloutExperiment
         }
      }
   }

   private let markdownRenderer = MarkdownRenderer()

   public init() {}

   /// Renders `blockQuote` as a callout component when its opening text matches
   /// one of the recognised kinds. Returns `nil` for unrecognised blockquotes.
   ///
   /// - Parameters:
   ///   - blockQuote: The AST node to inspect.
   ///   - labelForKind: Closure that maps a kind to its localised badge text.
   ///     Defaults to the raw capitalised kind name; pass a UIStrings look-up
   ///     in production to get localised labels.
   public func render(
      _ blockQuote: BlockQuote,
      labelForKind: (Kind) -> String = { $0.rawValue.prefix(1).uppercased() + $0.rawValue.dropFirst() }
   ) -> String? {
      guard let (kind, rest) = self.detectCallout(blockQuote) else { return nil }
      let label = labelForKind(kind)
      let safeName = kind.rawValue
      let inner = self.renderRest(rest)
      return "<div class=\"sk-docc-callout sk-docc-callout--\(safeName)\">"
         + "<span class=\"sk-docc-callout-label\">\(Self.escape(label))</span>"
         + "<div>\(inner)</div>"
         + "</div>"
   }

   // MARK: - Detection

   /// Checks whether the blockquote is a DocC callout and, if so, returns the
   /// kind plus the remaining body (the children with the opening kind-prefix
   /// stripped from the first paragraph).
   ///
   /// Handles two common authoring styles:
   /// - Plain prefix: `> Note: the actual content`
   /// - Bold prefix:  `> **Note:** the actual content`
   func detectCallout(_ blockQuote: BlockQuote) -> (Kind, [any Markup])? {
      let children = Array(blockQuote.children)
      guard let firstParagraph = children.first as? Paragraph else { return nil }

      let plain = firstParagraph.plainText
         .trimmingCharacters(in: .whitespacesAndNewlines)

      guard let kind = Self.calloutKind(from: plain) else { return nil }

      // Reconstruct the children list with the first paragraph's leading
      // kind-prefix stripped so the rendered content does not repeat "Tip:".
      let strippedParagraph = self.stripPrefix(from: firstParagraph, kind: kind)
      var result: [any Markup] = []
      if let p = strippedParagraph { result.append(p) }
      result += Array(children.dropFirst())
      return (kind, result)
   }

   /// Matches the plain-text start of a paragraph against the known kind names.
   ///
   /// Only the colon form is recognised (`Tip:`, `Note:`, `Important:`, `Warning:`,
   /// `Experiment:`). The space-only form (`> Note something`) is intentionally
   /// excluded: it triggers false positives on any sentence that starts with a
   /// recognised word (e.g. `> Note something here`). The DocC spec requires the
   /// colon, so the lenient space variant is not needed.
   static func calloutKind(from plainText: String) -> Kind? {
      let lower = plainText.lowercased()
      for kind in Kind.allCases {
         if lower.hasPrefix("\(kind.rawValue):") {
            return kind
         }
      }
      return nil
   }

   // MARK: - Rendering

   /// Renders the callout body (the first paragraph with its prefix stripped,
   /// plus any subsequent children).
   private func renderRest(_ nodes: [any Markup]) -> String {
      nodes.map { node in
         if let paragraph = node as? Paragraph {
            return "<p>\(paragraph.children.map { self.markdownRenderer.renderInline($0) }.joined())</p>"
         }
         return self.markdownRenderer.renderNode(node)
      }.joined()
   }

   /// Returns a new `Paragraph` with the leading kind-prefix inline content
   /// removed, or `nil` if the paragraph is entirely the prefix (nothing left).
   ///
   /// The prefix can appear as plain text or wrapped in `**bold**`; both are
   /// stripped. What remains becomes the callout body.
   private func stripPrefix(from paragraph: Paragraph, kind: Kind) -> Paragraph? {
      // Render the full paragraph plain text, find where the actual content starts
      // (after "Kind:" and optional whitespace), then re-render only from that offset.
      let plain = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
      let prefix = kind.rawValue + ":"
      var body: Substring = plain[plain.startIndex...]
      if body.lowercased().hasPrefix(prefix) {
         body = body.dropFirst(prefix.count)
      }
      body = body.drop(while: { $0.isWhitespace })
      if body.isEmpty { return nil }

      // Re-create a minimal paragraph by parsing just the body text so the AST
      // types line up. This avoids complex inline-child surgery while staying
      // inside the swift-markdown model.
      let reparsed = Document(parsing: String(body))
      return reparsed.children.compactMap { $0 as? Paragraph }.first
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
