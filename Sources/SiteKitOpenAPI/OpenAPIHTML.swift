import Foundation

/// Small HTML helpers shared by the OpenAPI page renderers.
///
/// The renderers assemble HTML by string concatenation (like the DocC plugin
/// set), so every value interpolated from the spec passes through `escape(_:)`
/// to neutralize `&`, `"`, `'`, `<`, `>`.
enum OpenAPIHTML {
   /// Escapes the five characters that would otherwise break out of text or an
   /// attribute value in the assembled HTML.
   static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("'", with: "&#39;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
