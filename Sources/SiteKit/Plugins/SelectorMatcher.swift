import Foundation

/// Matches a minimal subset of CSS selectors against an `<img>` element in generated HTML.
///
/// A full CSS selector engine would be overkill – the image pipeline only needs
/// enough expressivity to distinguish the roles SiteKit themes actually render.
/// Supported forms:
///
/// | Form | Example | Meaning |
/// |------|---------|---------|
/// | `tag` | `img` | tag name must match |
/// | `.class` | `.sk-post-image` | element must have the class |
/// | `tag.class[.class…]` | `img.hero.lead` | tag and every class |
/// | `A > B` | `figure.hero > img` | A must match immediate parent; B must match element |
/// | `A B` | `.sk-article-body img` | A must match some ancestor; B must match element |
/// | `a, b` | `.avatar, .author-img` | any branch matching wins |
///
/// Both combinators can be chained (`.a > .b > img`, `.a .b img`, mix of both).
/// Each part on either side of a combinator is itself a simple form (tag, class,
/// or tag.class). Selectors are first-match – the role resolver walks the manifest
/// in order and stops at the first matching role.
enum SelectorMatcher {
   /// Structural context for a single `<img>`: the element's tag/classes plus the
   /// ordered chain of open ancestors. Index 0 of `ancestors` is the immediate
   /// parent; the last element is the outermost tracked ancestor.
   struct Candidate {
      let tagName: String
      let classes: Set<String>
      let ancestors: [Ancestor]

      init(tagName: String, classes: Set<String>, ancestors: [Ancestor] = []) {
         self.tagName = tagName.lowercased()
         self.classes = classes
         self.ancestors = ancestors
      }

      struct Ancestor: Equatable {
         let tagName: String
         let classes: Set<String>

         init(tagName: String, classes: Set<String>) {
            self.tagName = tagName.lowercased()
            self.classes = classes
         }
      }
   }

   /// Returns true if `selector` matches `candidate`. Splits comma-separated lists
   /// and succeeds on the first matching branch.
   static func matches(selector: String, candidate: Candidate) -> Bool {
      let branches = selector.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      for branch in branches where !branch.isEmpty {
         if Self.matchesBranch(selector: branch, candidate: candidate) {
            return true
         }
      }
      return false
   }

   /// Matches one branch (no commas). A branch is a sequence of simple forms
   /// separated by combinators – either `>` (immediate parent) or whitespace
   /// (any ancestor). The last simple form must match `candidate` itself.
   private static func matchesBranch(selector: String, candidate: Candidate) -> Bool {
      let tokens = Self.tokenize(branch: selector)
      guard let last = tokens.last, case .part(let elementPart) = last else { return false }
      guard Self.matchesPart(elementPart, tagName: candidate.tagName, classes: candidate.classes) else {
         return false
      }

      // Walk the remaining tokens right-to-left through the ancestor chain.
      // `ancestorIndex` tracks the next ancestor to consider; `Candidate.ancestors[0]`
      // is the immediate parent.
      var ancestorIndex = 0
      var index = tokens.count - 2
      while index >= 0 {
         guard case .combinator(let combinator) = tokens[index] else { return false }
         guard index > 0, case .part(let part) = tokens[index - 1] else { return false }

         switch combinator {
         case .child:
            // Must match the immediate next ancestor in the chain exactly.
            guard ancestorIndex < candidate.ancestors.count else { return false }
            let ancestor = candidate.ancestors[ancestorIndex]
            guard Self.matchesPart(part, tagName: ancestor.tagName, classes: ancestor.classes) else {
               return false
            }
            ancestorIndex += 1
         case .descendant:
            // Search forward through ancestors until we find a match.
            var found = false
            while ancestorIndex < candidate.ancestors.count {
               let ancestor = candidate.ancestors[ancestorIndex]
               ancestorIndex += 1
               if Self.matchesPart(part, tagName: ancestor.tagName, classes: ancestor.classes) {
                  found = true
                  break
               }
            }
            if !found { return false }
         }

         index -= 2
      }
      return true
   }

   // MARK: - Tokenization

   private enum Token {
      case part(Part)
      case combinator(Combinator)
   }

   private enum Combinator {
      case child
      case descendant
   }

   private struct Part {
      let tagName: String?
      let requiredClasses: [String]
   }

   /// Splits a branch into alternating `part` / `combinator` tokens.
   /// Whitespace around `>` collapses to a single child combinator; other
   /// whitespace produces a descendant combinator.
   private static func tokenize(branch: String) -> [Token] {
      var tokens: [Token] = []
      var currentPart = ""
      var cursor = branch.startIndex

      func flushPart() {
         let trimmed = currentPart.trimmingCharacters(in: .whitespaces)
         currentPart = ""
         guard !trimmed.isEmpty else { return }
         tokens.append(.part(Self.parsePart(trimmed)))
      }

      while cursor < branch.endIndex {
         let character = branch[cursor]
         if character == ">" {
            flushPart()
            // If the previous token was a descendant combinator (from whitespace
            // before `>`), promote it to a child combinator.
            if case .combinator(.descendant) = tokens.last {
               tokens.removeLast()
            }
            tokens.append(.combinator(.child))
            cursor = branch.index(after: cursor)
            // Skip whitespace after `>` so a single token boundary remains.
            while cursor < branch.endIndex, branch[cursor].isWhitespace {
               cursor = branch.index(after: cursor)
            }
         } else if character.isWhitespace {
            flushPart()
            if case .combinator = tokens.last {
               // Already at a combinator boundary; collapse.
            } else if !tokens.isEmpty {
               tokens.append(.combinator(.descendant))
            }
            cursor = branch.index(after: cursor)
         } else {
            currentPart.append(character)
            cursor = branch.index(after: cursor)
         }
      }
      flushPart()
      return tokens
   }

   /// Parses a simple form `tag`, `.class`, or `tag.class[.class…]`. Tag names
   /// are lowercased; class names preserve case.
   private static func parsePart(_ text: String) -> Part {
      var tagName: String?
      var requiredClasses: [String] = []
      var cursor = text.startIndex

      if text[cursor] != "." {
         let dotIndex = text[cursor...].firstIndex(of: ".") ?? text.endIndex
         tagName = String(text[cursor..<dotIndex]).lowercased()
         cursor = dotIndex
      }
      while cursor < text.endIndex, text[cursor] == "." {
         let start = text.index(after: cursor)
         let end = text[start...].firstIndex(of: ".") ?? text.endIndex
         let className = String(text[start..<end])
         if !className.isEmpty {
            requiredClasses.append(className)
         }
         cursor = end
      }
      return Part(tagName: tagName, requiredClasses: requiredClasses)
   }

   private static func matchesPart(_ part: Part, tagName: String, classes: Set<String>) -> Bool {
      if let required = part.tagName, required != tagName { return false }
      for required in part.requiredClasses where !classes.contains(required) {
         return false
      }
      return true
   }
}
