import Foundation
import Markdown

public struct MarkdownRenderer {
   public init() {}


   /// Renders a short markdown string as inline HTML (no wrapping `<p>` tags).
   /// Supports links, bold, italic, code, and other inline formatting.
   public func renderInline(_ markdown: String) -> String {
      let document = Document(parsing: markdown)
      var parts: [String] = []
      for child in document.children {
         if let paragraph = child as? Paragraph {
            parts.append(paragraph.children.map { self.renderInline($0) }.joined())
         }
      }
      return parts.joined(separator: "<br />")
   }

   public func render(_ markdown: String, strippingTitleMatching title: String? = nil) -> String {
      let document = Document(parsing: markdown, options: [.parseBlockDirectives])
      var html = ""
      var strippedLeadingH1 = false

      for child in document.children {
         if !strippedLeadingH1, let title, let heading = child as? Heading, heading.level == 1 {
            let headingText = heading.children.map { self.renderInline($0) }.joined()
            let plainText = headingText.replacing(#/<[^>]+>/#, with: "")
            if plainText.trimmingCharacters(in: .whitespaces) == title.trimmingCharacters(in: .whitespaces) {
               strippedLeadingH1 = true
               continue
            }
         }
         if !strippedLeadingH1, !(child is Heading) {
            strippedLeadingH1 = true
         }
         html += self.renderNode(child)
      }

      return html
   }

   func renderNode(_ node: Markup) -> String {
      switch node {
      case let heading as Heading:
         let level = heading.level
         let content = heading.children.map { self.renderInline($0) }.joined()
         let id = self.generateHeadingID(from: heading)
         return "<h\(level) id=\"\(id)\">\(content)</h\(level)>"

      case let paragraph as Paragraph:
         let content = paragraph.children.map { self.renderInline($0) }.joined()
         return "<p>\(content)</p>"

      case let list as UnorderedList:
         let items = list.children.compactMap { $0 as? ListItem }.map { item in
            let content = self.renderListItemContent(item)
            return "<li>\(content)</li>"
         }.joined()
         return "<ul>\(items)</ul>"

      case let list as OrderedList:
         let items = list.children.compactMap { $0 as? ListItem }.map { item in
            let content = self.renderListItemContent(item)
            return "<li>\(content)</li>"
         }.joined()
         return "<ol>\(items)</ol>"

      case let code as CodeBlock:
         return self.renderCodeBlock(code: code.code, language: code.language)

      case let blockQuote as BlockQuote:
         let content = blockQuote.children.map { self.renderNode($0) }.joined()
         return "<blockquote>\(content)</blockquote>"

      case is ThematicBreak:
         return "<hr />"

      case let table as Table:
         return self.renderTable(table)

      case let htmlBlock as HTMLBlock:
         return htmlBlock.rawHTML

      case let directive as BlockDirective:
         return self.renderBlockDirective(directive)

      default:
         return ""
      }
   }

   private func renderBlockDirective(_ directive: BlockDirective) -> String {
      switch directive.name {
      case "LinkCard":
         return self.renderLinkCard(directive)
      default:
         return ""
      }
   }

   private func renderLinkCard(_ directive: BlockDirective) -> String {
      let arguments = directive.argumentText.parseNameValueArguments()
      var argMap: [String: String] = [:]
      for arg in arguments {
         argMap[arg.name] = arg.value
      }

      guard let url = argMap["url"], !url.isEmpty else { return "" }
      let title = argMap["title"] ?? url
      let explicitSource = argMap["source"]

      var descriptionParts: [String] = []
      for child in directive.children {
         if let paragraph = child as? Paragraph {
            descriptionParts.append(paragraph.children.map { self.renderInline($0) }.joined())
         }
      }
      let description = descriptionParts.joined(separator: " ")

      let (sourceLabel, sourceIcon) = self.linkCardSource(for: url, explicit: explicitSource)

      var html = "<a class=\"sk-link-card\" href=\"\(self.escapeHTMLAttribute(url))\">"
      html += "<span class=\"sk-link-card-source\">\(sourceIcon) \(self.escapeHTML(sourceLabel))</span>"
      html += "<span class=\"sk-link-card-title\">\(self.escapeHTML(title))</span>"
      if !description.isEmpty {
         html += "<span class=\"sk-link-card-description\">\(description)</span>"
      }
      html += "</a>"
      return html
   }

   private func linkCardSource(for url: String, explicit: String?) -> (label: String, iconSVG: String) {
      let githubIcon = "<svg viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" fill=\"currentColor\" aria-hidden=\"true\"><path d=\"M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z\"/></svg>"
      let globeIcon = "<svg viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" fill=\"currentColor\" aria-hidden=\"true\"><path d=\"M8 0a8 8 0 100 16A8 8 0 008 0zm5.3 5H11a13 13 0 00-1.1-3.2A6 6 0 0113.3 5zM8 1.1c.7.9 1.2 2 1.5 3.2h-3c.3-1.2.8-2.3 1.5-3.2zM1.3 9a6.2 6.2 0 010-2.7h2.6A13 13 0 003.7 8c0 .6 0 1.2.1 1.7H1.4zm.8 1.7h2.3A13 13 0 005.5 14 6 6 0 012 10.7zm2.3-5.4H2A6 6 0 015.5 2a13 13 0 00-1.1 3.3zM8 14.9c-.7-.9-1.2-2-1.5-3.2h3c-.3 1.2-.8 2.3-1.5 3.2zm1.8-4H6.2c-.1-.6-.2-1.2-.2-1.9s.1-1.3.2-1.7h3.6c.1.4.2 1 .2 1.7s-.1 1.3-.2 1.9zm.3 3.3a13 13 0 001.1-3.5h2.3A6 6 0 0110 14.2zm1.4-5.2c.1-.5.1-1.1.1-1.7s0-1.2-.1-1.7h2.6a6.2 6.2 0 010 2.7h-2.6z\"/></svg>"

      let host = self.extractHost(from: url)?.lowercased() ?? ""

      if let explicit = explicit, !explicit.isEmpty {
         let icon = host == "github.com" || host.hasSuffix(".github.com") ? githubIcon : globeIcon
         return (explicit, icon)
      }
      if host == "github.com" || host.hasSuffix(".github.com") {
         return ("GitHub", githubIcon)
      }
      let label = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
      return (label.isEmpty ? "Link" : label, globeIcon)
   }

   private func extractHost(from url: String) -> String? {
      guard let components = URLComponents(string: url) else { return nil }
      return components.host
   }

   private func escapeHTMLAttribute(_ string: String) -> String {
      self.escapeHTML(string)
   }

   private func renderCodeBlock(code: String, language: String?) -> String {
      let trimmedCode = code.hasSuffix("\n") ? String(code.dropLast()) : code
      let escaped = self.escapeHTML(trimmedCode)
      if let lang = language, !lang.isEmpty {
         return "<pre><code class=\"language-\(lang)\">\(escaped)</code></pre>"
      }
      return "<pre><code>\(escaped)</code></pre>"
   }

   private func renderListItemContent(_ item: ListItem) -> String {
      var result = ""
      if let checkbox = item.checkbox {
         let checked = checkbox == .checked ? " checked" : ""
         result += "<input type=\"checkbox\" disabled\(checked) /> "
      }
      result += item.children.map { self.renderNode($0) }.joined()
      return result
   }

   private func renderTable(_ table: Table) -> String {
      var html = "<table>"

      let head = table.head
      html += "<thead><tr>"
      for cell in head.cells {
         let alignment = self.tableColumnAlignment(cell, in: table)
         let alignAttr = alignment.map { " style=\"text-align: \($0)\"" } ?? ""
         let content = cell.children.map { self.renderInline($0) }.joined()
         html += "<th scope=\"col\"\(alignAttr)>\(content)</th>"
      }
      html += "</tr></thead>"

      html += "<tbody>"
      for row in table.body.rows {
         html += "<tr>"
         for (index, cell) in row.cells.enumerated() {
            let alignment = self.tableBodyCellAlignment(at: index, in: table)
            let alignAttr = alignment.map { " style=\"text-align: \($0)\"" } ?? ""
            let content = cell.children.map { self.renderInline($0) }.joined()
            html += "<td\(alignAttr)>\(content)</td>"
         }
         html += "</tr>"
      }
      html += "</tbody>"

      html += "</table>"
      return html
   }

   private func tableColumnAlignment(_ cell: Table.Cell, in table: Table) -> String? {
      let columnIndex = cell.indexInParent
      return self.alignmentString(for: table.columnAlignments[safe: columnIndex])
   }

   private func tableBodyCellAlignment(at index: Int, in table: Table) -> String? {
      self.alignmentString(for: table.columnAlignments[safe: index])
   }

   private func alignmentString(for alignment: Table.ColumnAlignment??) -> String? {
      guard let alignment = alignment.flatMap({ $0 }) else { return nil }
      switch alignment {
      case .left: return "left"
      case .center: return "center"
      case .right: return "right"
      }
   }

   func renderInline(_ inline: Markup) -> String {
      switch inline {
      case let text as Text:
         return self.escapeHTML(text.string)

      case let strong as Strong:
         let content = strong.children.map { self.renderInline($0) }.joined()
         return "<strong>\(content)</strong>"

      case let emphasis as Emphasis:
         let content = emphasis.children.map { self.renderInline($0) }.joined()
         return "<em>\(content)</em>"

      case let code as InlineCode:
         return "<code>\(self.escapeHTML(code.code))</code>"

      case let link as Link:
         let content = link.children.map { self.renderInline($0) }.joined()
         let destination = link.destination ?? ""
         return "<a href=\"\(destination)\">\(content)</a>"

      case let image as Image:
         let src = image.source ?? ""
         let alt = image.children.map { self.renderInline($0) }.joined()
         let titleAttr = image.title.map { " title=\"\(self.escapeHTML($0))\"" } ?? ""
         return "<img src=\"\(src)\" alt=\"\(alt)\"\(titleAttr) loading=\"lazy\" />"

      case let strikethrough as Strikethrough:
         let content = strikethrough.children.map { self.renderInline($0) }.joined()
         return "<del>\(content)</del>"

      case is SoftBreak:
         return "\n"

      case is LineBreak:
         return "<br />"

      case let inlineHTML as InlineHTML:
         return inlineHTML.rawHTML

      default:
         if let container = inline as? InlineContainer {
            return container.children.map { self.renderInline($0) }.joined()
         }
         return ""
      }
   }

   private func generateHeadingID(from heading: Heading) -> String {
      let plainText = heading.children.compactMap { child -> String? in
         if let text = child as? Text { return text.string }
         if let code = child as? InlineCode { return code.code }
         if let link = child as? Link { return link.children.compactMap { ($0 as? Text)?.string }.joined() }
         if let strong = child as? Strong { return strong.children.compactMap { ($0 as? Text)?.string }.joined() }
         if let emphasis = child as? Emphasis { return emphasis.children.compactMap { ($0 as? Text)?.string }.joined() }
         return nil
      }.joined()

      return plainText
         .lowercased()
         .replacing(/[^\w\s-]/, with: "")
         .replacing(/\s+/, with: "-")
         .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
   }

   func escapeHTML(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
   }
}

extension Collection {
   subscript(safe index: Index) -> Element? {
      self.indices.contains(index) ? self[index] : nil
   }
}
