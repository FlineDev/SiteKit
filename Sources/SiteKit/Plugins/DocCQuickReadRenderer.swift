import Foundation
import Markdown

/// Renders the "Quick Read" summary that DocC notes place at the top
/// (`> **Quick Read** (AI): …`) as a TLDR card component instead of a plain
/// `<blockquote>`. The emitted element carries both `sk-docc-quickread` (for
/// backwards compatibility with existing theme CSS) and `sk-docc-tldr` (for the
/// redesigned TLDR card styling).
///
/// The leading "Quick Read" label – and any immediately following separator such
/// as a colon, en-dash, or em-dash – is stripped from the first paragraph's text
/// because the tag pill (`<span class="sk-docc-tldr-tag">`) replaces it visually.
/// Any content after the first paragraph (bullets, sub-paragraphs) is rendered as-is.
///
/// Returns `nil` for any blockquote that is not a Quick Read, so the caller falls
/// back to normal blockquote rendering.
public struct DocCQuickReadRenderer {
   private let markdown = MarkdownRenderer()

   public init() {}

   /// Renders a Quick Read blockquote as a TLDR card.
   ///
   /// When `uiStrings` is provided, a subtle AI-generated hint line is appended at the
   /// bottom of the card (the hint is always accurate: the quick summary is always produced
   /// by the build pipeline, not written by hand). Pass `nil` only in unit tests that do
   /// not exercise the hint line.
   public func render(_ blockQuote: BlockQuote, uiStrings: UIStrings? = nil) -> String? {
      guard Self.isQuickRead(blockQuote) else { return nil }

      let children = Array(blockQuote.children)
      var innerParts: [String] = []

      // The tag pill replaces the literal "Quick Read" prefix in the first paragraph,
      // so we strip the prefix and render the remainder as the lead sentence.
      innerParts.append("<span class=\"sk-docc-tldr-tag\">Quick Read</span>")

      if let firstParagraph = children.first as? Paragraph {
         let leadHTML = self.leadText(from: firstParagraph)
         if !leadHTML.isEmpty {
            innerParts.append("<p class=\"sk-docc-tldr-lead\">\(leadHTML)</p>")
         }
         // Render remaining children. Unordered lists whose items are anchor links
         // are promoted to jump pills (`sk-docc-tldr-jump`); other children render
         // verbatim. This matches the prototype's row of section-jump buttons.
         let rest = children.dropFirst().map { child -> String in
            if let list = child as? UnorderedList {
               let pillHTML = self.jumpPillsHTML(from: list)
               if let pills = pillHTML { return pills }
            }
            return self.markdown.renderNode(child)
         }.joined()
         innerParts.append(rest)
      } else {
         // First child is not a paragraph – render everything as-is without lead extraction.
         let all = children.map { self.markdown.renderNode($0) }.joined()
         innerParts.append(all)
      }

      // Append the AI-generated hint line when UIStrings are available. The quick summary
      // is always produced by the build pipeline – adding this hint on every card is correct.
      if let s = uiStrings {
         let hint = s.string(for: .doccQuickReadAiHint)
         innerParts.append("<span class=\"sk-docc-tldr-ai-hint\">\(Self.escape(hint))</span>")
      }

      let inner = innerParts.joined()
      return "<aside class=\"sk-docc-quickread sk-docc-tldr\" id=\"quick-read\">\(inner)</aside>"
   }

   /// Converts an unordered list of anchor-link items to a row of jump pills.
   ///
   /// A list qualifies when every item's content is a single `Link` node whose
   /// destination starts with `#` (an in-page anchor). Mixed lists – even one
   /// non-anchor item – fall back to normal list rendering so the author can
   /// freely mix link and non-link bullets without surprising output.
   ///
   /// Each qualifying item becomes a `<a class="sk-docc-tldr-jump" href="#id">label ›</a>`.
   /// Anchors are preferred over buttons so the scroll works without JavaScript
   /// (the heading's `scroll-margin-top` in docc.css absorbs the sticky appbar).
   private func jumpPillsHTML(from list: UnorderedList) -> String? {
      let items = list.children.compactMap { $0 as? ListItem }
      guard !items.isEmpty else { return nil }

      var pills: [String] = []
      for item in items {
         // Extract the single Link from this list item, tolerating either:
         //   - tight-list layout: ListItem → Link (inline directly)
         //   - loose-list / blockquote layout: ListItem → Paragraph → Link
         guard let link = Self.singleAnchorLink(in: item) else { return nil }
         let label = link.children.map { self.markdown.renderInline($0) }.joined()
         let safeHref = Self.escape(link.destination ?? "")
         pills.append("<a class=\"sk-docc-tldr-jump\" href=\"\(safeHref)\">\(label) ›</a>")
      }

      return "<div class=\"sk-docc-tldr-jumps\">\(pills.joined())</div>"
   }

   /// Returns the single anchor `Link` from a `ListItem` when the item's content
   /// reduces to exactly one link whose destination begins with `#`. Returns `nil`
   /// when the item contains any non-anchor, non-whitespace content.
   private static func singleAnchorLink(in item: ListItem) -> Link? {
      // Collect all non-whitespace inline nodes from the item, looking through
      // Paragraphs (which Markdown wraps list items in for both tight and loose lists).
      var links: [Link] = []
      var hasNonLink = false

      for child in item.children {
         let inlines: [any Markup]
         if let paragraph = child as? Paragraph {
            inlines = Array(paragraph.children)
         } else {
            // Non-paragraph direct child (unusual) – treat item as non-qualifying.
            return nil
         }
         for inline in inlines {
            if let link = inline as? Link {
               links.append(link)
            } else if let text = inline as? Text, text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
               // Ignore pure-whitespace text nodes.
               continue
            } else if inline is SoftBreak || inline is LineBreak {
               continue
            } else {
               hasNonLink = true
            }
         }
      }

      guard !hasNonLink, links.count == 1 else { return nil }
      let link = links[0]
      guard let dest = link.destination, dest.hasPrefix("#") else { return nil }
      return link
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }

   static func isQuickRead(_ blockQuote: BlockQuote) -> Bool {
      guard let firstParagraph = blockQuote.children.compactMap({ $0 as? Paragraph }).first else {
         return false
      }
      return firstParagraph.plainText
         .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
         .lowercased()
         .hasPrefix("quick read")
   }

   /// Extracts the inline HTML of the first paragraph with the leading "Quick Read"
   /// prefix (and optional trailing separator: colon, en-dash `–`, em-dash `–`)
   /// removed. The remaining text becomes the TLDR lead sentence shown below the tag.
   private func leadText(from paragraph: Paragraph) -> String {
      // Render all inline children to HTML, then strip the "Quick Read …" prefix.
      let rawHTML = paragraph.children.map { self.markdown.renderInline($0) }.joined()

      // Strip any wrapping bold/strong around the label: the markdown commonly writes
      // `**Quick Read** (AI):` so the rendered HTML starts with `<strong>Quick Read</strong>`.
      // We operate on the plain-text representation to locate the prefix, then trim
      // the rendered HTML by finding the first non-label content after the separator.
      let plain = paragraph.plainText
         .trimmingCharacters(in: .whitespacesAndNewlines)

      // Determine how many characters the "Quick Read" label spans in the plain text,
      // including an optional trailing separator (colon, en-dash, em-dash, slash).
      let lower = plain.lowercased()
      guard lower.hasPrefix("quick read") else { return rawHTML }

      var afterLabel = plain[plain.index(plain.startIndex, offsetBy: "quick read".count)...]

      // Skip any parenthetical qualifier like " (AI)" before the separator.
      if afterLabel.hasPrefix(" (") || afterLabel.hasPrefix("(") {
         if let closeIdx = afterLabel.firstIndex(of: ")") {
            afterLabel = afterLabel[afterLabel.index(after: closeIdx)...]
         }
      }

      // Skip an optional separator character and surrounding whitespace.
      afterLabel = afterLabel.drop(while: { $0.isWhitespace })
      if afterLabel.hasPrefix(":") || afterLabel.hasPrefix("–") || afterLabel.hasPrefix("–") || afterLabel.hasPrefix("/") {
         afterLabel = afterLabel.dropFirst()
      }
      afterLabel = afterLabel.drop(while: { $0.isWhitespace })

      let leadPlain = String(afterLabel)

      // If the entire first paragraph was just the label, return empty so no lead <p> is emitted.
      guard !leadPlain.isEmpty else { return "" }

      // Re-render only the inline children that contribute to the lead text.
      // We reconstruct by rendering all children and then stripping the label prefix
      // from the resulting HTML – this is simpler than re-walking the AST for a trim.
      return self.stripQuickReadPrefix(from: rawHTML, leadPlainText: leadPlain)
   }

   /// Strips the "Quick Read" label markup from rendered inline HTML, leaving only
   /// the lead text that follows the separator. Handles both plain-text and bold-wrapped
   /// label variants (`**Quick Read**` → `<strong>Quick Read</strong>`).
   private func stripQuickReadPrefix(from html: String, leadPlainText: String) -> String {
      // Locate the lead plain text inside the rendered HTML and return from that point.
      // The lead plain text is unescaped prose; escapeHTML of it should appear verbatim.
      let escaped = leadPlainText
         .replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")

      if let range = html.range(of: escaped) {
         return String(html[range.lowerBound...])
      }

      // Fallback: return the raw HTML unchanged if we cannot locate the lead text.
      return html
   }
}
