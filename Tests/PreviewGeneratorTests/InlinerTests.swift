import Foundation
import Testing

@testable import PreviewGeneratorKit

@Suite("PreviewInliner")
struct InlinerTests {
   @Test("Inlines a local <link rel=\"stylesheet\"> into a <style> block")
   func inlinesLocalStylesheet() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }
      try writeFile("body{color:red}", at: siteDirectory.appendingPathComponent("assets/theme/theme.css"))

      let html = #"<link rel="stylesheet" href="/assets/theme/theme.css"/>"#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output.contains("<style>body{color:red}</style>"))
      #expect(!output.contains(#"<link rel="stylesheet""#))
   }

   @Test("Leaves an external CDN <link> alone")
   func leavesExternalStylesheetAlone() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }

      let html = #"<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader"/>"#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output == html)
   }

   @Test("Inlines a local <script src> while preserving inline <script> blocks")
   func inlinesLocalScriptKeepsInline() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }
      try writeFile("console.log('hi');", at: siteDirectory.appendingPathComponent("assets/theme/theme.js"))

      let html = #"""
      <script src="/assets/theme/theme.js" defer></script>
      <script>var x = 1;</script>
      """#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output.contains("<script>console.log('hi');</script>"))
      #expect(output.contains("<script>var x = 1;</script>"))
      #expect(!output.contains(#"src=""#))
   }

   @Test("Rewrites a local <img src> to a data: URI")
   func rewritesLocalImageToDataURI() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }
      let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
      let imageURL = siteDirectory.appendingPathComponent("assets/cover.png")
      try FileManager.default.createDirectory(
         at: imageURL.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
      try bytes.write(to: imageURL)

      let html = #"<img src="/assets/cover.png" alt="Cover" width="200" height="100"/>"#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output.contains("data:image/png;base64,"))
      #expect(output.contains("alt=\"Cover\""))
      #expect(!output.contains(#"src="/assets/cover.png""#))
   }

   @Test("Leaves an external <img> URL alone")
   func leavesExternalImageAlone() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }

      let html = #"<img src="https://cdn.example.com/logo.png" alt="Logo"/>"#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output == html)
   }

   @Test("Strips cache-busting query strings produced by PageShell")
   func stripsCacheBustQueryStrings() {
      let html = #"<link rel="stylesheet" href="https://example.com/a.css?v=abc12345"/>"#
      let output = PreviewInliner.stripCacheBustingQueryStrings(in: html)
      #expect(output == #"<link rel="stylesheet" href="https://example.com/a.css"/>"#)
   }

   @Test("Resolves cache-busted local stylesheet hrefs against the filesystem")
   func inlinesLocalStylesheetWithCacheBust() throws {
      let siteDirectory = try makeTempSite()
      defer { try? FileManager.default.removeItem(at: siteDirectory) }
      try writeFile("a{}", at: siteDirectory.appendingPathComponent("assets/theme/a.css"))

      let html = #"<link rel="stylesheet" href="/assets/theme/a.css?v=deadbeef"/>"#
      let output = PreviewInliner.inline(html: html, siteDirectory: siteDirectory)

      #expect(output.contains("<style>a{}</style>"))
   }

   @Test("isLocalAsset classifies common forms correctly")
   func classifiesAssetURLs() {
      #expect(PreviewInliner.isLocalAsset("/assets/foo.css"))
      #expect(PreviewInliner.isLocalAsset("assets/foo.css"))
      #expect(!PreviewInliner.isLocalAsset("https://fonts.googleapis.com/x.css"))
      #expect(!PreviewInliner.isLocalAsset("//cdn.example.com/x.js"))
      #expect(!PreviewInliner.isLocalAsset("data:image/svg+xml,<svg/>"))
      #expect(!PreviewInliner.isLocalAsset("#section"))
      #expect(!PreviewInliner.isLocalAsset(""))
   }

   @Test("Strips the LanguageRedirectRenderer inline script")
   func stripsLanguageRedirectScript() {
      let html = #"<!doctype html><html><head><title>x</title><script>(function() { 'use strict'; var LANGS = ["en", "de"]; var DEFAULT = 'en'; for (var i = 0; i < LANGS.length; i++) { } })()</script><link rel="stylesheet" href="/foo.css"></head></html>"#
      let output = PreviewInliner.stripLanguageRedirect(in: html)
      #expect(!output.contains("var LANGS"))
      #expect(output.contains(#"<link rel="stylesheet""#))
   }

   @Test("Preserves an unrelated inline script emitted BEFORE the LANGS one")
   func preservesEarlierScriptWhenLangsComesSecond() {
      // PageShell may grow new inline scripts (analytics nonce, CSP setup, etc.)
      // that emit ahead of the language-redirect script in some future change.
      // The strip must close on each script's own `</script>` – not consume
      // across boundaries – so this earlier marker survives.
      let html = #"""
      <head>
      <script>window.__preLangMarker = true; if (1 < 2) {}</script>
      <script>(function() { 'use strict'; var LANGS = ["en", "de"]; for (var i = 0; i < LANGS.length; i++) {} })()</script>
      </head>
      """#
      let output = PreviewInliner.stripLanguageRedirect(in: html)
      #expect(output.contains("window.__preLangMarker = true"))
      #expect(output.contains("if (1 < 2)"))
      #expect(!output.contains("var LANGS"))
   }

   @Test("Leaves other inline scripts (JSON-LD, theme bootstrap) alone")
   func keepsUnrelatedInlineScripts() {
      let html = #"""
      <script>(function() { var LANGS = ["en", "de"]; })()</script>
      <script type="application/ld+json">{"@context":"https://schema.org"}</script>
      <script>document.documentElement.setAttribute('data-theme','dark')</script>
      """#
      let output = PreviewInliner.stripLanguageRedirect(in: html)
      #expect(!output.contains("var LANGS"))
      #expect(output.contains(#"application/ld+json"#))
      #expect(output.contains("setAttribute('data-theme'"))
   }

   @Test("Extracts attribute values from arbitrary tag strings")
   func extractsAttributes() {
      let tag = #"<link rel="stylesheet" href='/foo.css' media="all"/>"#
      #expect(PreviewInliner.attribute(named: "href", in: tag) == "/foo.css")
      #expect(PreviewInliner.attribute(named: "rel", in: tag) == "stylesheet")
      #expect(PreviewInliner.attribute(named: "media", in: tag) == "all")
      #expect(PreviewInliner.attribute(named: "missing", in: tag) == nil)
   }

   // MARK: - Helpers

   private func makeTempSite() throws -> URL {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewInliner-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      return url
   }

   private func writeFile(_ content: String, at url: URL) throws {
      try FileManager.default.createDirectory(
         at: url.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
   }
}
