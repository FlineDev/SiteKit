import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSearchIndex")
struct DocCSearchIndexTests {
   private func page(
      _ slug: String,
      _ title: String,
      html: String,
      summary: String? = nil,
      extensions: [String: any Sendable] = [:]
   ) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: html,
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         summary: summary,
         extensions: extensions
      )
   }

   @Test("Builds a record per page with a resolved URL and plain-text excerpt")
   func buildsRecords() {
      let pages = [
         self.page("wwdc24-1-x", "Meet X", html: "<h2>Overview</h2><p>Hello <strong>world</strong>.</p>", summary: "A short note."),
      ]
      let records = DocCSearchIndex.build(from: pages, urlPrefix: "documentation")
      #expect(records.count == 1)
      let record = records[0]
      #expect(record.title == "Meet X")
      #expect(record.url == "/documentation/wwdc24-1-x/")
      // HTML stripped to plain text, summary prepended, no tags remain.
      #expect(record.text.hasPrefix("A short note."))
      #expect(record.text.contains("Overview"))
      // Tags become spaces, so words stay separated and matchable (tokenized search).
      #expect(record.text.contains("Hello world"))
      #expect(!record.text.contains("<"))
   }

   @Test("Decodes entities and collapses whitespace")
   func decodesAndCollapses() {
      let text = DocCSearchIndex.searchableText(
         html: "<p>A   &amp;   B\n\n  &lt;tag&gt;</p>",
         summary: nil,
         limit: 600
      )
      #expect(text == "A & B <tag>")
   }

   @Test("Caps the excerpt length")
   func capsLength() {
      let long = String(repeating: "word ", count: 500)
      let text = DocCSearchIndex.searchableText(html: "<p>\(long)</p>", summary: nil, limit: 50)
      #expect(text.count == 50)
   }

   @Test("Surfaces the abstract and video CTA as distinct preview fields")
   func populatesPreviewFields() {
      let pages = [
         self.page(
            "wwdc25-10060-platforms-sotu",
            "Platforms State of the Union",
            html: "<p>The annual platforms address.</p>",
            summary: "What's new across Apple's platforms this year.",
            extensions: ["doccCTAURL": "https://developer.apple.com/videos/play/wwdc2025/10060/", "doccMinutes": 41]
         )
      ]
      let record = DocCSearchIndex.build(from: pages, urlPrefix: "documentation")[0]
      #expect(record.summary == "What's new across Apple's platforms this year.")
      #expect(record.videoMinutes == 41)
      #expect(record.videoURL == "https://developer.apple.com/videos/play/wwdc2025/10060/")
      // The abstract still rides in the match corpus so a description hit is findable.
      #expect(record.text.contains("What's new across Apple's platforms"))
   }

   @Test("Omits preview fields when the note carries no abstract or video")
   func omitsPreviewFieldsWhenAbsent() {
      let pages = [
         self.page("wwdc24-1-x", "Meet X", html: "<p>Body only.</p>", summary: nil),
      ]
      let record = DocCSearchIndex.build(from: pages, urlPrefix: "documentation")[0]
      #expect(record.summary == nil)
      #expect(record.videoMinutes == nil)
      #expect(record.videoURL == nil)
   }

   @Test("Treats a blank abstract or video URL as absent")
   func blankPreviewFieldsBecomeNil() {
      let pages = [
         self.page(
            "wwdc24-2-y",
            "Note Y",
            html: "<p>Body.</p>",
            summary: "   ",
            extensions: ["doccCTAURL": "  "]
         )
      ]
      let record = DocCSearchIndex.build(from: pages, urlPrefix: "documentation")[0]
      #expect(record.summary == nil)
      #expect(record.videoURL == nil)
   }

   @Test("Encodes only the populated preview fields into the JSON index")
   func encodingOmitsNilPreviewFields() throws {
      let withVideo = DocCSearchRecord(
         title: "A", url: "/a/", text: "a", summary: "Abstract", videoMinutes: 12, videoURL: "https://v/"
      )
      let bare = DocCSearchRecord(title: "B", url: "/b/", text: "b")

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let withJSON = String(decoding: try encoder.encode(withVideo), as: UTF8.self)
      let bareJSON = String(decoding: try encoder.encode(bare), as: UTF8.self)

      // Present record carries the terse keys the client reads.
      #expect(withJSON.contains("\"summary\":\"Abstract\""))
      #expect(withJSON.contains("\"minutes\":12"))
      #expect(withJSON.contains("\"video\":\"https:\\/\\/v\\/\""))
      // Absent fields are omitted entirely (no null), keeping each shard small.
      #expect(!bareJSON.contains("summary"))
      #expect(!bareJSON.contains("minutes"))
      #expect(!bareJSON.contains("video"))
   }
}
