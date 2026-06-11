import Foundation
import Testing
@testable import SiteKit

@Suite("RSSFeedRenderer URL absolutization")
struct RSSFeedRendererURLAbsolutisationTests {
   @Test("Absolutizes root-relative img src against baseURL")
   func absolutizesRootRelativeImg() {
      let html = #"<p><img src="/assets/images/blog/foo/hero.webp" alt="Hero"/></p>"#
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result.contains(#"src="https://example.com/assets/images/blog/foo/hero.webp""#))
   }

   @Test("Absolutizes root-relative anchor href against baseURL")
   func absolutizesRootRelativeAnchor() {
      let html = #"<p><a href="/blog/foo/">link</a></p>"#
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result.contains(#"href="https://example.com/blog/foo/""#))
   }

   @Test("Leaves https:// URLs untouched")
   func leavesAbsoluteURLsAlone() {
      let html = #"<p><a href="https://other.example/x">x</a><img src="https://other.example/y.png"/></p>"#
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result == html)
   }

   @Test("Leaves protocol-relative URLs untouched")
   func leavesProtocolRelativeAlone() {
      let html = #"<img src="//cdn.example.com/x.png"/>"#
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result == html)
   }

   @Test("Leaves mailto:, tel:, and anchor URLs untouched")
   func leavesNonHTTPURLsAlone() {
      // Wrap with extra # delimiters so the literal # in href="#section" is not parsed as a macro.
      let html = ##"<a href="mailto:a@b.c">m</a><a href="tel:+1">t</a><a href="#section">s</a>"##
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result == html)
   }

   @Test("Leaves data: URIs untouched")
   func leavesDataURIsAlone() {
      // Use plain string concatenation to avoid in-source colon parsing inside raw string
      let dataURI = "data:image/png;base64,XYZ"
      let html = "<img src=\"\(dataURI)\"/>"
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result == html)
   }

   @Test("Handles trailing-slash baseURL the same as no-trailing-slash")
   func handlesTrailingSlashBase() {
      let html = #"<img src="/x.png"/>"#
      let withSlash = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com/")
      let withoutSlash = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(withSlash == withoutSlash)
      #expect(withSlash.contains(#"src="https://example.com/x.png""#))
   }

   @Test("Single-quoted attributes are absolutized")
   func absolutizesSingleQuotedAttribute() {
      let html = "<img src='/assets/x.png' alt='x'/>"
      let result = RSSFeedRenderer.absolutizeHTMLURLs(in: html, baseURL: "https://example.com")
      #expect(result.contains("src='https://example.com/assets/x.png'"))
   }
}

@Suite("RSSFeedRenderer media:thumbnail and namespace")
struct RSSFeedRendererMediaThumbnailTests {
   private func makeFeed(items: [FeedItem]) -> FeedData {
      FeedData(
         title: "Test",
         description: "Test feed",
         siteURL: "https://example.com/",
         feedURL: "https://example.com/feed.xml",
         language: "en",
         items: items,
         outputRelativePath: "feed.xml"
      )
   }

   @Test("Always declares media: namespace on <rss>")
   func declaresMediaNamespace() {
      let xml = RSSFeedRenderer.buildRSS(feed: self.makeFeed(items: []))
      #expect(xml.contains(#"xmlns:media="http://search.yahoo.com/mrss/""#))
   }

   @Test("Emits <media:thumbnail> when imageURL is set")
   func emitsThumbnail() {
      let item = FeedItem(
         title: "Post",
         url: "https://example.com/blog/post/",
         date: Date(timeIntervalSince1970: 0),
         summary: "summary",
         htmlContent: "<p>Hi</p>",
         imageURL: "https://example.com/assets/hero.webp",
         imageAlt: "Alt"
      )
      let xml = RSSFeedRenderer.buildRSS(feed: self.makeFeed(items: [item]))
      #expect(xml.contains(#"<media:thumbnail url="https://example.com/assets/hero.webp"/>"#))
   }

   @Test("Omits <media:thumbnail> when imageURL is nil")
   func omitsThumbnail() {
      let item = FeedItem(
         title: "Post",
         url: "https://example.com/blog/post/",
         date: Date(timeIntervalSince1970: 0),
         summary: "summary",
         htmlContent: "<p>Hi</p>",
         imageURL: nil
      )
      let xml = RSSFeedRenderer.buildRSS(feed: self.makeFeed(items: [item]))
      #expect(!xml.contains("<media:thumbnail"))
   }

   @Test("XML-escapes the imageURL inside the thumbnail attribute")
   func escapesThumbnailURL() {
      let item = FeedItem(
         title: "Post",
         url: "https://example.com/blog/post/",
         date: nil,
         summary: "",
         htmlContent: "",
         imageURL: "https://example.com/assets/hero.webp?v=1&size=lg"
      )
      let xml = RSSFeedRenderer.buildRSS(feed: self.makeFeed(items: [item]))
      // & must be escaped to &amp; inside the URL attribute
      #expect(xml.contains("?v=1&amp;size=lg"))
      #expect(!xml.contains("?v=1&size=lg"))
   }
}
