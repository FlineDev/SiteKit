import Foundation

/// HTML entity escaping shared by every code highlighter and the body-rewriting plumbing.
///
/// Kept in one place so the regex `CodeHighlighter`, the `CodeHighlighting` body-rewriter,
/// and any out-of-module conformer (e.g. the SwiftSyntax highlighter) all escape token text
/// identically. Only the four entities a build-time highlighter ever needs are handled.
public enum HTMLEscaping {
   /// Escapes `&`, `<`, `>`, and `"` so the text is safe in HTML content. The `&` rule runs
   /// first so the ampersands introduced by the other rules are not re-escaped.
   public static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
   }

   /// Reverses the four entities `escape(_:)` produces. Used to recover raw source text from
   /// already-escaped rendered HTML before re-tokenizing it.
   public static func unescape(_ string: String) -> String {
      string
         .replacing("&lt;", with: "<")
         .replacing("&gt;", with: ">")
         .replacing("&quot;", with: "\"")
         .replacing("&amp;", with: "&")
   }
}

/// A build-time syntax highlighter for DocC code blocks.
///
/// A conformer turns one raw (unescaped) code snippet into an HTML fragment of
/// `<span class="sk-tok-*">` tokens whose contents are HTML-escaped, so the output is safe
/// to embed inside a `<code>` element. The shared `applyToBodyHTML(_:defaultLanguage:)`
/// default walks a rendered article body and re-highlights every fenced `<pre><code>` block
/// through `highlight(code:language:)`, so a conformer only implements the per-snippet step.
///
/// SiteKit ships two conformers:
/// - `CodeHighlighter` – the zero-dependency regex highlighter, the default in the base
///   `SiteKit` library. It recognizes keywords, strings, comments, numbers, attributes, and
///   capitalized type names.
/// - `SwiftSyntaxHighlighter` – a SwiftSyntax-based highlighter in the optional
///   `SiteKitSyntaxHighlighting` product. It classifies Swift tokens by syntactic role
///   (variable, call, member, parameter, …) for a semantic-near, Xcode-like palette.
///
/// DocC sites opt into the richer highlighter by injecting it (`SiteBuilder.docc(…, highlighter:)`
/// or `DocCLoader(…, highlighter:)`); sites that stay on the default never compile swift-syntax.
public protocol CodeHighlighting: Sendable {
   /// Highlights `code` for the given `language` and returns an HTML fragment containing
   /// `<span class="sk-tok-*">` tokens. The returned string is safe to embed inside a `<code>`
   /// element without further escaping. A nil, empty, or unknown language returns plain escaped
   /// text with no spans.
   ///
   /// - Parameters:
   ///   - code: The raw, unescaped source code to highlight.
   ///   - language: A language identifier (e.g. "swift", "python"). Nil or empty falls back to
   ///     plain escaped text.
   func highlight(code: String, language: String?) -> String
}

extension CodeHighlighting {
   /// Post-processes rendered article body HTML and applies syntax highlighting to every
   /// `<pre><code class="language-X">…</code></pre>` block found.
   ///
   /// Adds `sk-docc-highlight` to the `<pre>` class list so the token CSS rules are scoped to
   /// highlighted blocks. Blocks whose language class is absent or empty use `defaultLanguage`
   /// when provided; blocks with no language and no default are left as plain escaped text.
   ///
   /// This is the shared block-level plumbing for every conformer: it locates the fenced blocks
   /// and delegates the per-snippet work to `highlight(code:language:)`. It is DocC-only – it is
   /// called from `DocCLoader` after the body HTML is produced and is not referenced by any
   /// shared renderer.
   ///
   /// - Parameters:
   ///   - html: The rendered article body HTML (code content is already HTML-escaped by
   ///     `MarkdownRenderer`).
   ///   - defaultLanguage: Optional fallback language for untagged fences.
   public func applyToBodyHTML(_ html: String, defaultLanguage: String?) -> String {
      // Match: <pre><code class="language-X">...content...</code></pre>
      // or     <pre><code>...content...</code></pre>  (no language class)
      // The content may span multiple lines, so .dotMatchesLineSeparators is required.
      guard let regex = try? NSRegularExpression(
         pattern: #"<pre><code((?:\s+class="language-([^"]*)")?)\s*>(.*?)</code></pre>"#,
         options: [.dotMatchesLineSeparators]
      ) else { return html }

      let ns = html as NSString
      var result = ""
      var cursor = 0

      let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
      for match in matches {
         // Append verbatim text before this match.
         let wholeRange = match.range
         result += ns.substring(with: NSRange(location: cursor, length: wholeRange.location - cursor))

         // Extract language from `class="language-X"` (group 2). When the class attribute is
         // entirely absent group 1 and group 2 are both empty.
         let language: String?
         if match.range(at: 2).location != NSNotFound {
            let langRaw = ns.substring(with: match.range(at: 2))
            language = langRaw.isEmpty ? defaultLanguage : langRaw
         } else {
            language = defaultLanguage
         }

         // The already-escaped code content (group 3).
         let escapedContent: String
         if match.range(at: 3).location != NSNotFound {
            escapedContent = ns.substring(with: match.range(at: 3))
         } else {
            escapedContent = ""
         }

         // Unescape then re-highlight so the tokenizer works on plain text.
         let rawContent = HTMLEscaping.unescape(escapedContent)
         let highlighted: String
         let classAttr: String
         if let lang = language?.lowercased().trimmingCharacters(in: .whitespaces), !lang.isEmpty {
            highlighted = self.highlight(code: rawContent, language: lang)
            classAttr = " class=\"language-\(HTMLEscaping.escape(lang))\""
         } else {
            // No language and no default: just re-escape the raw content.
            highlighted = HTMLEscaping.escape(rawContent)
            classAttr = ""
         }

         result += "<pre class=\"sk-docc-highlight\"><code\(classAttr)>\(highlighted)</code></pre>"
         cursor = wholeRange.location + wholeRange.length
      }

      result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
      return result
   }
}
