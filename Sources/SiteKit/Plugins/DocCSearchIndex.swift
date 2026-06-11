import Foundation

/// The authorship/coverage classification of a DocC note, surfaced by the search
/// page's note-type facet.
///
/// Derived at build time from the note's file shape (see `DocCSearchIndex.noteType(for:)`):
/// a stub placeholder, an AI-only note (a `.ai.md` with no community sibling), or a
/// community note (a `.md`, regardless of whether it also offers an AI variant). The
/// raw values are the literal facet/deep-link tokens (`?type=community`), so they are
/// stable wire identifiers, not display labels.
enum DocCNoteType: String, Codable, Equatable, Sendable {
   /// A placeholder note: the session exists but nobody has written it up yet.
   case stub
   /// An AI-authored note with no human-written community variant.
   case ai
   /// A community-authored note (it may additionally offer an AI variant).
   case community
}

/// One searchable record for a DocC note: its title, URL, a condensed plain-text
/// excerpt of the body used for full-text matching, plus the facet fields the
/// dedicated search page filters on (year, framework, note type) and the preview
/// fields the ⌘K overlay's detail panel renders (summary, video duration, video URL).
struct DocCSearchRecord: Codable, Equatable, Sendable {
   let title: String
   let url: String
   let text: String
   /// The WWDC year key the note belongs to (e.g. `wwdc25`); nil for non-WWDC notes.
   let year: String?
   /// The framework key (e.g. `swiftui`); nil when no framework is assigned.
   let framework: String?
   /// AI / community / stub – drives the note-type facet.
   let noteType: DocCNoteType
   /// The note's abstract (Apple's short session description). Already folded into
   /// `text` so it stays matchable, but surfaced here as a distinct field so the
   /// overlay's preview panel can show it on its own line; nil when the note has none.
   let summary: String?
   /// The session-video duration in minutes, when the note carries a video CTA; nil otherwise.
   /// Lets the preview panel render the same "Watch Video (NN min)" affordance the article does.
   let videoMinutes: Int?
   /// The session-video URL, when the note carries a video CTA; nil otherwise.
   let videoURL: String?

   /// JSON keys stay terse and align with the page's deep-link query params: the
   /// note type is serialized as `type` so a record and a `?type=…` URL speak the
   /// same vocabulary. The optional fields (`year`, `framework`, `summary`,
   /// `minutes`, `video`) are omitted from a record when nil, keeping the index small.
   enum CodingKeys: String, CodingKey {
      case title, url, text, year, framework, summary
      case noteType = "type"
      case videoMinutes = "minutes"
      case videoURL = "video"
   }

   init(
      title: String,
      url: String,
      text: String,
      year: String? = nil,
      framework: String? = nil,
      noteType: DocCNoteType = .community,
      summary: String? = nil,
      videoMinutes: Int? = nil,
      videoURL: String? = nil
   ) {
      self.title = title
      self.url = url
      self.text = text
      self.year = year
      self.framework = framework
      self.noteType = noteType
      self.summary = summary
      self.videoMinutes = videoMinutes
      self.videoURL = videoURL
   }
}

/// Builds the full-text search records for a DocC catalog.
///
/// The current SiteKit nav index carries only title/summary/tags; DocC search is
/// full-text, so each record includes a condensed plain-text excerpt of the
/// rendered body (HTML stripped, entities decoded, whitespace collapsed, length
/// capped to keep the index small). The summary is prepended so it ranks first.
/// Each record also carries the three facet fields the dedicated search page filters
/// on and the preview fields the ⌘K overlay's detail panel renders (the abstract and,
/// when present, the session-video duration + URL) – all already known at build time
/// from the slug and the note's extensions, so no new data pipeline is needed. The
/// renderer shards these records and the client searches them; this builder is the
/// pure, testable core.
enum DocCSearchIndex {
   /// `urlOverrides` maps a page slug to its final site path for pages whose rendering
   /// plugin writes them somewhere other than `/<prefix>/<slug>/` – the caller derives it
   /// from the registered `PagePathResolving` plugins so search results link to URLs that
   /// actually exist.
   static func build(
      from pages: [PageModel],
      urlPrefix: String,
      excerptLimit: Int = 600,
      urlOverrides: [String: String] = [:]
   ) -> [DocCSearchRecord] {
      let prefix = urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return pages.map { page in
         let url = urlOverrides[page.slug] ?? (prefix.isEmpty ? "/\(page.slug)/" : "/\(prefix)/\(page.slug)/")
         let text = Self.searchableText(html: page.htmlContent, summary: page.summary, limit: excerptLimit)
         // A blank abstract or video URL is treated as absent so the field is omitted
         // from the index rather than serialized as an empty string the panel would render.
         let summary = page.summary?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
         let videoURL = (page.extensions["doccCTAURL"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
         return DocCSearchRecord(
            title: page.title,
            url: url,
            text: text,
            year: DocCNavigationTree.yearKey(of: page.slug),
            framework: page.extensions["doccFramework"] as? String,
            noteType: Self.noteType(for: page),
            summary: (summary?.isEmpty == false) ? summary : nil,
            videoMinutes: page.extensions["doccMinutes"] as? Int,
            videoURL: (videoURL?.isEmpty == false) ? videoURL : nil
         )
      }
   }

   /// Classifies a note for the note-type facet. Stub wins over everything (a
   /// placeholder has no real authored content of either kind); otherwise the
   /// `doccAIOnly` flag the loader sets on a sibling-less `.ai.md` marks an AI-only
   /// note, and anything else is treated as community-authored.
   static func noteType(for page: PageModel) -> DocCNoteType {
      if (page.extensions["doccIsStub"] as? Bool) == true { return .stub }
      if (page.extensions["doccAIOnly"] as? Bool) == true { return .ai }
      return .community
   }

   /// Reduces rendered HTML to a compact, matchable plain-text excerpt.
   static func searchableText(html: String, summary: String?, limit: Int) -> String {
      var text = html.replacing(#/<[^>]+>/#, with: " ")
      text = text
         .replacing("&amp;", with: "&")
         .replacing("&lt;", with: "<")
         .replacing("&gt;", with: ">")
         .replacing("&quot;", with: "\"")
         .replacing("&#39;", with: "'")
         .replacing("&#x27;", with: "'")
      text = text.replacing(#/\s+/#, with: " ").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      if let summary = summary?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !summary.isEmpty {
         text = text.isEmpty ? summary : "\(summary) \(text)"
      }
      return String(text.prefix(limit))
   }
}
