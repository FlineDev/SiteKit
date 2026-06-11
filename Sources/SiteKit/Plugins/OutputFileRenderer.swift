import Foundation

extension String {
   /// HTML-escapes special characters for safe inclusion in HTML text content and attribute values.
   /// Matches Plot's escaping behavior: &, <, >
   public var htmlEscaped: String {
      self.replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
   }

   /// XML-escapes special characters for safe inclusion in XML attributes and text.
   public var xmlEscaped: String {
      self.replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
         .replacing("'", with: "&apos;")
   }
}

public struct OutputFileRenderer {
   /// A random per-build token, formerly appended to theme asset URLs as a
   /// cache-busting query.
   ///
   /// Deprecated: SiteKit now busts the `immutable`-cached `/assets/*` responses with
   /// content-hashed FILENAMES (`theme.<hash>.css`), applied by `AssetFingerprinter`
   /// in the output-processing phase. A query string does not reliably bust an
   /// `immutable` response (browsers skip revalidation, CDNs may ignore the query),
   /// and a random-per-build token also re-downloaded UNCHANGED assets on every
   /// deploy. The hashed filename fixes both: it changes only when the bytes change.
   /// Kept (still functional) so any external custom `Renderer` referencing it keeps
   /// compiling; it is no longer used by SiteKit itself.
   @available(*, deprecated, message: "Asset cache-busting now uses content-hashed filenames via AssetFingerprinter. This token is no longer applied by SiteKit.")
   public static let assetCacheBustToken: String = {
      String(format: "%08x", UInt32.random(in: 0..<UInt32.max))
   }()

   /// The query-string suffix formerly appended to asset URLs. Example: `"?v=abc12345"`.
   ///
   /// Deprecated: see ``assetCacheBustToken``. SiteKit no longer appends this – assets
   /// are cache-busted via content-hashed filenames (`AssetFingerprinter`).
   @available(*, deprecated, message: "Asset cache-busting now uses content-hashed filenames via AssetFingerprinter. This query suffix is no longer applied by SiteKit.")
   public static var assetCacheBustQuery: String {
      "?v=\(Self.assetCacheBustToken)"
   }

   let outputDirectory: URL
   let projectDirectory: URL
   let config: SiteConfig
   let themeConfig: ThemeConfig?
   let router: any URLRouter
   let uiStrings: UIStrings

   public init(outputDirectory: URL, projectDirectory: URL? = nil, config: SiteConfig, themeConfig: ThemeConfig? = nil, router: (any URLRouter)? = nil, uiStrings: UIStrings? = nil) {
      self.outputDirectory = outputDirectory
      self.projectDirectory = projectDirectory ?? outputDirectory.deletingLastPathComponent()
      self.config = config
      self.themeConfig = themeConfig
      self.router = router ?? DefaultURLRouter(config: config)
      self.uiStrings = uiStrings ?? UIStrings(locale: config.language)
   }

   /// Convenience initializer from BuildContext.
   /// Use this from custom `Renderer` implementations to access the shared page shell.
   public init(context: BuildContext) {
      self.outputDirectory = context.outputDirectory
      self.projectDirectory = context.projectDirectory
      self.config = context.config
      self.themeConfig = context.themeConfig
      self.router = context.router
      self.uiStrings = context.uiStrings
   }

   var languageCode: String {
      self.uiStrings.locale
   }

   func categoryDisplayName(for slug: String) -> String {
      self.config.categories.first { $0.slug == slug }?.name ?? slug
   }

   func tagDisplayName(for slug: String) -> String {
      self.config.tagDisplayNames?[slug] ?? slug
   }

   func formatDate(_ date: Date?) -> String {
      guard let date else { return "" }
      let formatter = DateFormatter()
      formatter.dateStyle = .long
      formatter.timeStyle = .none
      formatter.locale = Locale(identifier: self.uiStrings.locale)
      return formatter.string(from: date)
   }

   func isoDate(_ date: Date?) -> String {
      guard let date else { return "" }
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate]
      return formatter.string(from: date)
   }
}
