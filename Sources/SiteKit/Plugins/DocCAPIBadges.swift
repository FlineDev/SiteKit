import Foundation

/// Renders a comma-separated API/framework list ("Foundation Models, AlarmKit") as a row
/// of badge chips. Shared by the home-page year cards and the year detail intro so both
/// surfaces speak the same chip language. Blank input (nil, empty, or separators only)
/// renders nothing, so callers never emit an empty badge row and its spacing.
enum DocCAPIBadges {
   static func render(_ apis: String?) -> String {
      let items = (apis ?? "")
         .split(separator: ",")
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }
      guard !items.isEmpty else { return "" }
      let badges = items.map { "<span class=\"sk-docc-api-badge\">\(Self.escape($0))</span>" }.joined()
      return "<div class=\"sk-docc-api-badges\">\(badges)</div>"
   }

   private static func escape(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("\"", with: "&quot;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }
}
