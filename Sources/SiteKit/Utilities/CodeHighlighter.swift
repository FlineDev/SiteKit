import Foundation

/// Build-time syntax highlighter for DocC code blocks.
///
/// Tokenizes a plain-text code snippet and wraps recognized tokens in
/// `<span class="sk-tok-*">` elements so theme-token CSS can apply colors
/// without any client-side JavaScript.
///
/// The tokenizer operates on **raw** (unescaped) source text so that regex
/// patterns for strings, comments, and keywords work correctly. Each token's
/// text is HTML-escaped as it is emitted, so the output is safe to embed
/// directly inside a `<code>` element without any further escaping.
///
/// Supported first-class language: **swift**.
/// Generic fallback (keywords + strings + comments + numbers): any other
/// language identifier. Nil/empty language: plain escaped text (no spans).
///
/// Usage:
/// ```swift
/// let html = CodeHighlighter.highlight(code: rawCode, language: "swift")
/// ```
public struct CodeHighlighter: CodeHighlighting {

   /// Creates the zero-dependency regex highlighter – the default DocC code highlighter.
   public init() {}

   // MARK: - CodeHighlighting

   /// Highlights `code` for `language`, satisfying the `CodeHighlighting` seam. Forwards to the
   /// static `highlight(code:language:)` entry point that carries the regex implementation, so
   /// the regex logic has a single home while `DocCLoader` can hold this as `any CodeHighlighting`.
   public func highlight(code: String, language: String?) -> String {
      Self.highlight(code: code, language: language)
   }

   // MARK: - Static API

   /// Highlights `code` for the given `language` and returns an HTML fragment
   /// containing `<span class="sk-tok-*">` tokens. The returned string is
   /// safe to embed inside a `<code>` element without further escaping.
   ///
   /// - Parameters:
   ///   - code: The raw, unescaped source code to highlight.
   ///   - language: A language identifier (e.g. "swift", "python"). Nil or
   ///     empty falls back to plain escaped text (no spans).
   static func highlight(code: String, language: String?) -> String {
      guard let lang = language?.lowercased().trimmingCharacters(in: .whitespaces),
            !lang.isEmpty else {
         return escapeHTML(code)
      }
      if lang == "swift" {
         return tokenize(code, rules: swiftRules, lexConfig: swiftLexConfig)
      }
      return tokenize(code, rules: genericRules(for: lang), lexConfig: genericLexConfig)
   }

   /// Post-processes rendered article body HTML and applies syntax highlighting
   /// to every `<pre><code class="language-X">…</code></pre>` block found.
   ///
   /// Adds `sk-docc-highlight` to the `<pre>` class list so the token CSS rules
   /// are scoped to highlighted blocks. Blocks whose language class is absent or
   /// empty use `defaultLanguage` when provided; blocks with no language and no
   /// default are left as plain escaped text.
   ///
   /// This method is DocC-only: it is called from `DocCLoader` after the body
   /// HTML is produced and is not referenced by any shared renderer.
   ///
   /// The block-extraction plumbing now lives on the `CodeHighlighting` protocol so every
   /// conformer shares it; this static entry point is a thin shim over the regex conformer
   /// for callers (and tests) that reach `CodeHighlighter` directly.
   ///
   /// - Parameters:
   ///   - html: The rendered article body HTML (code content is already HTML-escaped
   ///     by `MarkdownRenderer`).
   ///   - defaultLanguage: Optional fallback language for untagged fences.
   static func applyToBodyHTML(_ html: String, defaultLanguage: String?) -> String {
      CodeHighlighter().applyToBodyHTML(html, defaultLanguage: defaultLanguage)
   }

   // MARK: - HTML helpers

   /// Escapes `<`, `>`, `&`, and `"` so the text is safe in HTML content. Forwards to the
   /// shared `HTMLEscaping` helper so every highlighter escapes identically.
   static func escapeHTML(_ string: String) -> String {
      HTMLEscaping.escape(string)
   }

   /// Reverses the four basic HTML entities used by `escapeHTML`.
   /// Used to recover raw source text from already-escaped HTML before re-tokenizing.
   static func unescapeHTML(_ string: String) -> String {
      HTMLEscaping.unescape(string)
   }

   // MARK: - Tokenization engine

   /// A rule maps a named NSRegularExpression to a CSS token class suffix.
   private struct Rule {
      let pattern: NSRegularExpression
      let tokenClass: String
   }

   /// Configuration for the context-aware string/comment pre-pass.
   ///
   /// Strings and comments cannot be matched with independent priority regexes:
   /// a `//` or `/*` *inside* a string literal must not open a comment, and a quote
   /// *inside* a comment must not open a string. A single left-to-right scan driven
   /// by this config decides, at each position, whether a string or comment opens
   /// and consumes it whole before any quote/comment marker inside it is considered.
   /// Code-unit values let the scan compare against ASCII delimiters cheaply.
   private struct LexConfig {
      /// Quote code units that both open and close a string literal.
      let stringQuotes: Set<UInt16>
      /// Line-comment opener sequences (e.g. `//`, `#`); each runs to end of line.
      let lineCommentStarts: [[UInt16]]
      /// Block-comment open/close sequences (e.g. `/*` … `*/`); nil when unsupported.
      let blockCommentOpen: [UInt16]?
      let blockCommentClose: [UInt16]?
   }

   /// Tokenizes `rawText` (unescaped source code), wrapping recognized regions with
   /// `<span class="sk-tok-<tokenClass>">…</span>` and HTML-escaping every span's
   /// contents. Text outside any token is escaped too.
   ///
   /// Two passes over a parallel token-class array (indexed by UTF-16 code unit):
   /// pass 1 is a context-aware left-to-right scan that claims string and comment
   /// spans (so an open string swallows any inner `//` or `/*`, and vice versa);
   /// pass 2 applies the word/number `rules` in priority order, claiming only the
   /// positions that pass 1 left unowned (so a keyword inside a string is never
   /// re-colored). Runs of equal class are then emitted in one walk.
   private static func tokenize(_ rawText: String, rules: [Rule], lexConfig: LexConfig) -> String {
      let chars = Array(rawText.utf16)
      let len = chars.count
      guard len > 0 else { return "" }

      // nil = unhighlighted.
      var tokenClass = [String?](repeating: nil, count: len)

      // Pass 1 – context-aware string/comment scan.
      markStringsAndComments(chars, len: len, config: lexConfig, into: &tokenClass)

      // Pass 2 – remaining word/number rules, claiming only still-unowned positions.
      let ns = rawText as NSString
      for rule in rules {
         let matches = rule.pattern.matches(in: rawText, range: NSRange(location: 0, length: ns.length))
         for match in matches {
            let r = match.range
            guard r.location != NSNotFound, r.length > 0 else { continue }
            let start = r.location
            let end = min(r.location + r.length, len)
            // Only claim positions not already owned by a string/comment or a
            // higher-priority rule.
            if (start..<end).allSatisfy({ tokenClass[$0] == nil }) {
               for i in start..<end { tokenClass[i] = rule.tokenClass }
            }
         }
      }

      // Walk the code-unit array and emit runs of the same token class.
      // Each run's substring is HTML-escaped before wrapping.
      var output = ""
      var i = 0
      while i < len {
         let cls = tokenClass[i]
         // Find the end of this run.
         var j = i + 1
         while j < len, tokenClass[j] == cls { j += 1 }

         // Extract the substring (via NSString for UTF-16 correctness) and escape it.
         let substr = ns.substring(with: NSRange(location: i, length: j - i))
         let escaped = escapeHTML(substr)
         if let cls {
            output += "<span class=\"sk-tok-\(cls)\">\(escaped)</span>"
         } else {
            output += escaped
         }
         i = j
      }
      return output
   }

   /// Single left-to-right scan claiming string-literal and comment spans into
   /// `tokenClass`. Once a string opens it runs to its closing quote (honoring `\`
   /// escapes) so any `//` or `/*` inside is part of the string; once a comment
   /// opens it runs to its terminator so any quote inside is part of the comment.
   /// A quote or block-comment opener with no terminator is left unclaimed and
   /// treated as ordinary text, matching the previous regex behavior.
   private static func markStringsAndComments(
      _ chars: [UInt16],
      len: Int,
      config: LexConfig,
      into tokenClass: inout [String?]
   ) {
      let backslash = Array("\\".utf16)[0]
      let newline = Array("\n".utf16)[0]

      var i = 0
      while i < len {
         // Block comment: /* … */, possibly spanning lines. Claimed only when closed.
         if let open = config.blockCommentOpen, let close = config.blockCommentClose,
            matchesSequence(chars, at: i, len: len, sequence: open),
            let closeStart = findSequence(chars, from: i + open.count, len: len, sequence: close) {
            let stop = closeStart + close.count
            for k in i..<stop { tokenClass[k] = "comment" }
            i = stop
            continue
         }

         // Line comment: runs from its opener to the end of the line (or text).
         if let start = config.lineCommentStarts.first(where: {
            matchesSequence(chars, at: i, len: len, sequence: $0)
         }) {
            var end = i + start.count
            while end < len, chars[end] != newline { end += 1 }
            for k in i..<end { tokenClass[k] = "comment" }
            i = end
            continue
         }

         // String literal: opens on a quote, closes on the same quote. Claimed only
         // when a closing quote is found, so a lone quote stays plain text.
         if config.stringQuotes.contains(chars[i]) {
            let quote = chars[i]
            var j = i + 1
            var closed = false
            while j < len {
               if chars[j] == backslash {
                  j += 2
                  continue
               }
               if chars[j] == quote {
                  closed = true
                  break
               }
               j += 1
            }
            if closed {
               for k in i...j { tokenClass[k] = "string" }
               i = j + 1
               continue
            }
         }

         i += 1
      }
   }

   /// True when `chars` beginning at `index` matches `sequence` in full.
   private static func matchesSequence(_ chars: [UInt16], at index: Int, len: Int, sequence: [UInt16]) -> Bool {
      guard index + sequence.count <= len else { return false }
      for k in 0..<sequence.count where chars[index + k] != sequence[k] {
         return false
      }
      return true
   }

   /// Start index of the first `sequence` occurrence at or after `from`, or nil if
   /// it does not occur before `len`.
   private static func findSequence(_ chars: [UInt16], from: Int, len: Int, sequence: [UInt16]) -> Int? {
      guard !sequence.isEmpty else { return nil }
      var k = from
      while k <= len - sequence.count {
         if matchesSequence(chars, at: k, len: len, sequence: sequence) {
            return k
         }
         k += 1
      }
      return nil
   }

   // MARK: - Swift rules

   /// String and comment delimiters for Swift: double-quoted strings, `//` line
   /// comments, and `/* … */` block comments. Consumed by the context-aware
   /// pre-pass so a `//` or `/*` inside a string is never treated as a comment.
   private static let swiftLexConfig = LexConfig(
      stringQuotes: Set("\"".utf16),
      lineCommentStarts: [Array("//".utf16)],
      blockCommentOpen: Array("/*".utf16),
      blockCommentClose: Array("*/".utf16)
   )

   /// Ordered rule set for Swift, applied after the string/comment pre-pass in
   /// priority order: numbers, attributes, keywords, types.
   private static let swiftRules: [Rule] = buildSwiftRules()

   private static func buildSwiftRules() -> [Rule] {
      var rules: [Rule] = []

      // 1. Numeric literals (decimal, hex 0x…, binary 0b…, float).
      if let r = try? NSRegularExpression(
         pattern: #"\b(?:0x[\da-fA-F_]+|0b[01_]+|[\d][\d_]*(?:\.[\d_]+)?(?:[eE][+-]?[\d_]+)?)\b"#
      ) {
         rules.append(Rule(pattern: r, tokenClass: "number"))
      }

      // 2. Swift attributes: `@Identifier`.
      if let r = try? NSRegularExpression(pattern: #"@[a-zA-Z_]\w*"#) {
         rules.append(Rule(pattern: r, tokenClass: "attribute"))
      }

      // 3. Swift keywords (word-boundary matched).
      let swiftKeywords = [
         "actor", "any", "as", "associatedtype", "async", "await",
         "break", "case", "catch", "class", "continue",
         "default", "defer", "deinit", "do",
         "else", "enum", "extension",
         "fallthrough", "false", "fileprivate", "final", "for", "func",
         "get", "guard",
         "if", "import", "in", "inout", "internal", "is",
         "let",
         "mutating",
         "nil",
         "nonisolated",
         "open", "operator", "override",
         "package", "precedencegroup", "private", "protocol", "public",
         "repeat", "rethrows", "return",
         "self", "set", "some", "static", "struct", "subscript", "super", "switch",
         "throw", "throws", "true", "try", "type", "typealias",
         "unowned", "var",
         "weak", "where", "while",
      ].sorted(by: { $0.count > $1.count })
      let kwAlt = swiftKeywords.joined(separator: "|")
      if let r = try? NSRegularExpression(pattern: "\\b(?:\(kwAlt))\\b") {
         rules.append(Rule(pattern: r, tokenClass: "keyword"))
      }

      // 4. Type names: identifiers starting with an uppercase letter.
      if let r = try? NSRegularExpression(pattern: #"\b[A-Z][a-zA-Z0-9_]*\b"#) {
         rules.append(Rule(pattern: r, tokenClass: "type"))
      }

      return rules
   }

   // MARK: - Generic fallback rules

   /// String and comment delimiters shared by the non-Swift fallback languages:
   /// double- and single-quoted strings, C-family `//` plus shell/Python `#` line
   /// comments, and `/* … */` block comments. Consumed by the context-aware
   /// pre-pass so a comment marker inside a string (and a quote inside a comment)
   /// is never mistaken for the other.
   private static let genericLexConfig = LexConfig(
      stringQuotes: Set("\"'".utf16),
      lineCommentStarts: [Array("//".utf16), Array("#".utf16)],
      blockCommentOpen: Array("/*".utf16),
      blockCommentClose: Array("*/".utf16)
   )

   /// Returns a generic rule set for non-Swift languages, applied after the
   /// string/comment pre-pass (numbers, then per-language keywords).
   private static func genericRules(for language: String) -> [Rule] {
      var rules: [Rule] = []

      // Numeric literals.
      if let r = try? NSRegularExpression(
         pattern: #"\b(?:0x[\da-fA-F_]+|0b[01_]+|[\d][\d_]*(?:\.[\d_]+)?(?:[eE][+-]?[\d_]+)?)\b"#
      ) {
         rules.append(Rule(pattern: r, tokenClass: "number"))
      }

      // Keywords: per-language list.
      let keywords = languageKeywords(language)
      if !keywords.isEmpty {
         let alt = keywords.sorted(by: { $0.count > $1.count }).joined(separator: "|")
         if let r = try? NSRegularExpression(pattern: "\\b(?:\(alt))\\b") {
            rules.append(Rule(pattern: r, tokenClass: "keyword"))
         }
      }

      return rules
   }

   /// Keyword lists for common languages. Returns an empty array for unknown languages
   /// so those blocks still receive string/comment/number coloring.
   private static func languageKeywords(_ language: String) -> [String] {
      switch language {
      case "javascript", "js", "typescript", "ts":
         return ["async", "await", "break", "case", "catch", "class", "const", "continue",
                 "debugger", "default", "delete", "do", "else", "export", "extends",
                 "finally", "for", "from", "function", "if", "import", "in", "instanceof",
                 "let", "new", "null", "of", "return", "static", "super", "switch",
                 "this", "throw", "true", "false", "try", "typeof", "undefined",
                 "var", "void", "while", "with", "yield"]
      case "python", "py":
         return ["and", "as", "assert", "async", "await", "break", "class", "continue",
                 "def", "del", "elif", "else", "except", "false", "finally", "for",
                 "from", "global", "if", "import", "in", "is", "lambda", "none",
                 "nonlocal", "not", "or", "pass", "raise", "return", "true", "try",
                 "while", "with", "yield"]
      case "kotlin":
         return ["abstract", "actual", "as", "break", "by", "catch", "class", "companion",
                 "const", "continue", "crossinline", "data", "do", "dynamic", "else",
                 "enum", "expect", "external", "false", "final", "finally", "for", "fun",
                 "get", "if", "import", "in", "infix", "init", "inline", "inner",
                 "interface", "internal", "is", "it", "lateinit", "noinline", "null",
                 "object", "open", "operator", "out", "override", "package", "private",
                 "protected", "public", "reified", "return", "sealed", "set", "super",
                 "suspend", "tailrec", "this", "throw", "true", "try", "typealias",
                 "typeof", "val", "var", "vararg", "when", "where", "while"]
      case "ruby", "rb":
         return ["alias", "and", "begin", "break", "case", "class", "def", "defined",
                 "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in",
                 "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
                 "return", "self", "super", "then", "true", "undef", "unless",
                 "until", "when", "while", "yield"]
      case "go":
         return ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                 "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                 "map", "package", "range", "return", "select", "struct", "switch",
                 "type", "var"]
      case "rust", "rs":
         return ["as", "async", "await", "break", "const", "continue", "crate", "dyn",
                 "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
                 "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
                 "self", "static", "struct", "super", "trait", "true", "type",
                 "unsafe", "use", "where", "while"]
      case "bash", "sh", "shell":
         return ["if", "then", "else", "elif", "fi", "for", "do", "done", "while",
                 "until", "case", "esac", "in", "function", "return", "export",
                 "local", "readonly", "unset", "echo", "exit"]
      case "yaml", "yml", "json", "xml", "html", "css":
         // Markup/data formats: no keyword coloring; strings and numbers suffice.
         return []
      default:
         // Unknown language: basic C-family fallback keywords.
         return ["break", "case", "catch", "class", "continue", "default", "do",
                 "else", "false", "finally", "for", "function", "if", "import",
                 "in", "new", "null", "return", "static", "switch", "this",
                 "throw", "true", "try", "var", "void", "while"]
      }
   }
}
