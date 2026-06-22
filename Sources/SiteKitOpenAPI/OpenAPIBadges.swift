import Foundation

/// Shared chips for the OpenAPI pages: the HTTP method badge (the verb-colored
/// pill) and the deprecated marker.
///
/// The method badge carries `data-method="<verb>"` (lowercased) so a later slice's
/// stylesheet can paint each verb its semantic color, the same way the DocC plugin
/// targets `data-framework`. This slice only emits the semantic markup.
enum OpenAPIBadges {
   /// The verb pill, for example `<span class="sk-openapi-method" data-method="get">GET</span>`.
   static func methodBadge(_ method: String) -> String {
      let lower = OpenAPIHTML.escape(method.lowercased())
      let label = OpenAPIHTML.escape(method.uppercased())
      return "<span class=\"sk-openapi-method\" data-method=\"\(lower)\">\(label)</span>"
   }

   /// The "Deprecated" marker, or an empty string when `isDeprecated` is false.
   static func deprecatedBadge(_ isDeprecated: Bool) -> String {
      isDeprecated ? "<span class=\"sk-openapi-deprecated\" data-deprecated=\"true\">Deprecated</span>" : ""
   }
}
