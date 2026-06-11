import Foundation

/// Streams open/close tag events out of HTML so a caller can track an ancestor
/// stack without pulling in a full DOM parser.
///
/// Intentionally permissive – designed for the output of Markdown renderers and
/// SiteKit templates, not arbitrary hand-written HTML. Known limitations:
/// - Doesn't attempt to validate nesting (callers reconcile on their own).
/// - Treats HTML comments as opaque and skips them.
/// - `<script>` / `<style>` content is skipped up to the closing tag so that
///   `<` inside inline JS doesn't look like a new element.
///
/// Good enough for the image-rewriting pass, where the structural signal we need
/// is simply "what ancestor classes are in scope at each `<img>`".
final class HTMLTagScanner {
   enum EventKind {
      case open(tagName: String, classes: Set<String>)
      case close(tagName: String)
   }

   struct Event {
      let kind: EventKind
      let range: Range<String.Index>
   }

   private let source: String
   private var cursor: String.Index

   init(source: String) {
      self.source = source
      self.cursor = source.startIndex
   }

   func next() -> Event? {
      while self.cursor < self.source.endIndex {
         guard let lessThanIndex = self.source[self.cursor...].firstIndex(of: "<") else {
            self.cursor = self.source.endIndex
            return nil
         }
         self.cursor = lessThanIndex

         // Skip HTML comments: <!-- … -->
         if self.source[self.cursor...].hasPrefix("<!--") {
            if let endRange = self.source.range(of: "-->", range: self.cursor..<self.source.endIndex) {
               self.cursor = endRange.upperBound
            } else {
               self.cursor = self.source.endIndex
            }
            continue
         }
         // Skip doctype / processing instructions: <! …>, <? …>
         if self.source[self.cursor...].hasPrefix("<!") || self.source[self.cursor...].hasPrefix("<?") {
            if let endIndex = self.source[self.cursor...].firstIndex(of: ">") {
               self.cursor = self.source.index(after: endIndex)
            } else {
               self.cursor = self.source.endIndex
            }
            continue
         }
         // Find the matching `>` for this element. Bail out if malformed.
         guard let greaterIndex = self.source[self.cursor...].firstIndex(of: ">") else {
            self.cursor = self.source.endIndex
            return nil
         }
         let tagEnd = self.source.index(after: greaterIndex)
         let tagRange = self.cursor..<tagEnd

         // Decide open vs close by the character immediately after `<`.
         let afterLT = self.source.index(after: self.cursor)
         if afterLT < self.source.endIndex, self.source[afterLT] == "/" {
            // Closing tag: </tagName>
            let nameStart = self.source.index(after: afterLT)
            let nameEnd = Self.endOfTagName(in: self.source, from: nameStart)
            let tagName = String(self.source[nameStart..<nameEnd])
            self.cursor = tagEnd
            return Event(kind: .close(tagName: tagName), range: tagRange)
         } else {
            // Opening tag: <tagName ...>. Parse tag name + classes.
            let nameStart = afterLT
            let nameEnd = Self.endOfTagName(in: self.source, from: nameStart)
            let tagName = String(self.source[nameStart..<nameEnd])
            let attributeString = self.source[nameEnd..<greaterIndex]
            let classes = Self.extractClasses(from: String(attributeString))

            // Skip contents of <script> / <style> to avoid treating `<` in inline
            // code as a tag. We still emit the opening tag event; then advance
            // past the closing tag before the next scan.
            let lowered = tagName.lowercased()
            if lowered == "script" || lowered == "style" {
               let closingTag = "</\(lowered)"
               if let closeRange = self.source.range(of: closingTag, options: .caseInsensitive, range: tagEnd..<self.source.endIndex) {
                  if let closeGreaterIndex = self.source[closeRange.upperBound...].firstIndex(of: ">") {
                     self.cursor = self.source.index(after: closeGreaterIndex)
                  } else {
                     self.cursor = self.source.endIndex
                  }
               } else {
                  self.cursor = self.source.endIndex
               }
            } else {
               self.cursor = tagEnd
            }
            return Event(kind: .open(tagName: tagName, classes: classes), range: tagRange)
         }
      }
      return nil
   }

   private static func endOfTagName(in source: String, from start: String.Index) -> String.Index {
      var index = start
      while index < source.endIndex {
         let character = source[index]
         if character.isWhitespace || character == ">" || character == "/" {
            return index
         }
         index = source.index(after: index)
      }
      return source.endIndex
   }

   /// Extracts space-separated class tokens from a tag's attribute string.
   /// Tolerates double/single quoted forms. Returns an empty set if `class=` is absent.
   private static func extractClasses(from attributeString: String) -> Set<String> {
      let regex = #/\bclass\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/#
      guard let match = attributeString.firstMatch(of: regex) else { return [] }
      let value: String
      if let v = match.output.1 { value = String(v) }
      else if let v = match.output.2 { value = String(v) }
      else if let v = match.output.3 { value = String(v) }
      else { return [] }
      return Set(value.split(whereSeparator: { $0.isWhitespace }).map(String.init))
   }
}
