import Foundation

/// Resolves DocC `<doc:Identifier>` cross-references to internal SiteKit links.
///
/// In a DocC catalog a note links to another with `<doc:WWDC24-10132-Some-Title>`,
/// which swift-markdown renders as `<a href="doc:WWDC24-10132-Some-Title">…</a>` –
/// a dead `doc:` URL. The identifier is the target note's filename stem, so its
/// destination slug is derivable without a cross-page lookup: slugify the
/// identifier and route it under the catalog's URL prefix. When the link text is
/// the bare autolink (`doc:Identifier`), it is replaced with a readable label
/// derived from the identifier; an author-written label is kept as-is.
public struct DocCCrossReferenceEnricher: Enricher {
   private let urlPrefix: String
   private let language: String?

   /// - Parameter urlPrefix: the DocC section's URL prefix (e.g. `documentation`),
   ///   without leading/trailing slashes.
   public init(urlPrefix: String, language: String? = nil) {
      self.urlPrefix = urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      self.language = language
   }

   public func enrich(_ page: PageModel) throws -> PageModel {
      guard page.htmlContent.contains("\"doc:") else { return page }
      let rewritten = self.rewriteDocLinks(in: page.htmlContent)
      guard rewritten != page.htmlContent else { return page }

      return PageModel(
         id: page.id,
         title: page.title,
         date: page.date,
         slug: page.slug,
         htmlContent: rewritten,
         sourcePath: page.sourcePath,
         category: page.category,
         tags: page.tags,
         summary: page.summary,
         description: page.description,
         author: page.author,
         image: page.image,
         imageAlt: page.imageAlt,
         draft: page.draft,
         pageType: page.pageType,
         locale: page.locale,
         originalLanguage: page.originalLanguage,
         legalDocument: page.legalDocument,
         extensions: page.extensions
      )
   }

   private func rewriteDocLinks(in html: String) -> String {
      let pattern = #/<a href="doc:([^"]*)">(.*?)<\/a>/#
      var result = ""
      var cursor = html.startIndex
      for match in html.matches(of: pattern) {
         result += html[cursor ..< match.range.lowerBound]
         let identifier = String(match.output.1)
         let text = String(match.output.2)
         let url = self.resolveURL(forIdentifier: identifier)
         let isBareAutolink = text == "doc:\(identifier)" || text == identifier
         let label = isBareAutolink ? Self.readableLabel(for: identifier) : text
         result += "<a href=\"\(url)\">\(label)</a>"
         cursor = match.range.upperBound
      }
      result += html[cursor...]
      return result
   }

   private func resolveURL(forIdentifier identifier: String) -> String {
      let slug = identifier.slugified(language: self.language)
      return self.urlPrefix.isEmpty ? "/\(slug)/" : "/\(self.urlPrefix)/\(slug)/"
   }

   /// Turns `WWDC24-10132-Explore-video-experiences` into `Explore video experiences`
   /// by stripping a leading `WWDC<year>-<sessionId>-` prefix and de-hyphenating.
   /// Year-only identifiers (`WWDC25`) pass through unchanged.
   static func readableLabel(for identifier: String) -> String {
      var label = identifier
      if let prefix = identifier.firstMatch(of: #/^WWDC\d{2}-[0-9A-Za-z]+-/#) {
         label = String(identifier[prefix.range.upperBound...])
      }
      label = label.replacing("-", with: " ")
      return label.isEmpty ? identifier : label
   }
}
