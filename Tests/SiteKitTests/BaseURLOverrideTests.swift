import Foundation
import Testing

@testable import SiteKit

@Suite("BaseURLOverride")
struct BaseURLOverrideTests {
   // MARK: - CLI argument parsing

   @Test("Absent --base-url option yields nil")
   func absentOption() throws {
      #expect(try SiteBuilder.baseURLOverride(from: ["Site", "build"]) == nil)
   }

   @Test("Valid absolute https URL is returned verbatim")
   func validValue() throws {
      let value = try SiteBuilder.baseURLOverride(from: ["Site", "build", "--base-url", "https://example.org"])
      #expect(value == "https://example.org")
   }

   @Test("Option is found independent of its position among other options")
   func positionIndependent() throws {
      let value = try SiteBuilder.baseURLOverride(from: ["Site", "build", "--no-clean", "--base-url", "http://staging.example.org"])
      #expect(value == "http://staging.example.org")
   }

   @Test("Trailing slashes are stripped so URL joining cannot double them")
   func trailingSlashStripped() throws {
      let value = try SiteBuilder.baseURLOverride(from: ["Site", "build", "--base-url", "https://example.org/"])
      #expect(value == "https://example.org")
   }

   @Test("Missing value after --base-url throws")
   func missingValue() {
      #expect(throws: BaseURLOverrideError.missingValue) {
         try SiteBuilder.baseURLOverride(from: ["Site", "build", "--base-url"])
      }
   }

   @Test("Scheme-less value throws instead of silently building broken absolute URLs")
   func schemelessValue() {
      #expect(throws: BaseURLOverrideError.notAnAbsoluteHTTPURL("wwdcnotes.fline.dev")) {
         try SiteBuilder.baseURLOverride(from: ["Site", "build", "--base-url", "wwdcnotes.fline.dev"])
      }
   }

   @Test("Non-http(s) scheme throws")
   func nonHTTPScheme() {
      #expect(throws: BaseURLOverrideError.notAnAbsoluteHTTPURL("ftp://example.org")) {
         try SiteBuilder.baseURLOverride(from: ["Site", "build", "--base-url", "ftp://example.org"])
      }
   }

   // MARK: - Compose-time captured base URL (HreflangEnricher)

   /// Reflects on a SiteBuilder's private `enrichers` array, mirroring the idiom
   /// in `SiteBuilderEnricherOpsTests`.
   private func enrichers(of builder: SiteBuilder) -> [any Enricher] {
      let mirror = Mirror(reflecting: builder)
      for child in mirror.children where child.label == "enrichers" {
         if let enrichers = child.value as? [any Enricher] {
            return enrichers
         }
      }
      return []
   }

   @Test("baseURL(_:) re-targets the HreflangEnricher the blueprint factory registered at compose time")
   func hreflangEnricherRetargeted() throws {
      let config = SiteConfig(
         name: "Fixture",
         baseURL: "https://old-base.example",
         localization: LocalizationConfig(defaultLanguage: "en", languages: ["de"])
      )
      let builder = SiteBuilder
         .blog(config: config, projectDirectory: URL(fileURLWithPath: "/tmp/sitekit-baseurl-test"))
         .baseURL("https://new-base.example")

      let hreflangEnricher = try #require(
         self.enrichers(of: builder).compactMap { $0 as? HreflangEnricher }.first,
         "blog blueprint registers a HreflangEnricher on multilingual configs"
      )

      let page = PageModel(
         title: "Hello World",
         slug: "hello-world",
         htmlContent: "<p>Hi</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/2024-01-15-hello-world.md"),
         extensions: ["translationMap": ["hello-world": Set(["en", "de"])]]
      )
      let enriched = try hreflangEnricher.enrich(page)
      let hreflang: [String: String] = try #require(enriched.extensionValue("hreflang"))

      #expect(hreflang["en"]?.hasPrefix("https://new-base.example/") == true)
      #expect(hreflang["de"]?.hasPrefix("https://new-base.example/de/") == true)
      #expect(hreflang.values.allSatisfy { !$0.contains("old-base.example") })
   }

   // MARK: - Full-build consumer completeness

   /// Writes a multilingual fixture site (article + translation, static page, home
   /// content, redirect rule) so a full build exercises every absolute-URL consumer:
   /// canonical/og:url, sitemap, RSS, llms.txt, nav/search index, hreflang, redirect stubs.
   private func makeFixtureSite() throws -> (config: SiteConfig, projectDirectory: URL) {
      let projectDirectory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-baseurl-fixture-\(UUID().uuidString)")
      let blogDirectory = projectDirectory.appendingPathComponent("Content/Blog")
      let pagesDirectory = projectDirectory.appendingPathComponent("Content/Pages")
      try FileManager.default.createDirectory(at: blogDirectory, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: pagesDirectory, withIntermediateDirectories: true)

      try """
      ---
      title: Hello World
      date: 2024-01-15
      tags: [welcome]
      ---
      A first article linking [home](/).
      """.write(to: blogDirectory.appendingPathComponent("2024-01-15-hello-world.md"), atomically: true, encoding: .utf8)

      try """
      ---
      title: Hallo Welt
      date: 2024-01-15
      tags: [welcome]
      ---
      Ein erster Artikel.
      """.write(to: blogDirectory.appendingPathComponent("2024-01-15-hello-world.de.md"), atomically: true, encoding: .utf8)

      try """
      ---
      title: About
      ---
      About this site.
      """.write(to: pagesDirectory.appendingPathComponent("about.md"), atomically: true, encoding: .utf8)

      try """
      ---
      title: Home
      ---
      Welcome home.
      """.write(to: pagesDirectory.appendingPathComponent("home.md"), atomically: true, encoding: .utf8)

      try """
      redirects:
        - from: /old-post/
          to: /blog/hello-world/
      """.write(to: projectDirectory.appendingPathComponent("redirects.yaml"), atomically: true, encoding: .utf8)

      let config = SiteConfig(
         name: "Base URL Fixture",
         baseURL: "https://old-base.example",
         description: "Fixture site for the base URL override",
         sections: [SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog")],
         localization: LocalizationConfig(defaultLanguage: "en", languages: ["de"]),
         redirectsFile: "redirects.yaml"
      )
      return (config, projectDirectory)
   }

   /// All text output files of a built site as (relative path, content) pairs.
   private func textOutputFiles(in outputDirectory: URL) throws -> [(path: String, content: String)] {
      let textExtensions: Set<String> = ["html", "xml", "txt", "json", "css", "js", "webmanifest", "md", "yaml"]
      var files: [(path: String, content: String)] = []
      let enumerator = FileManager.default.enumerator(at: outputDirectory, includingPropertiesForKeys: nil)
      while let url = enumerator?.nextObject() as? URL {
         guard textExtensions.contains(url.pathExtension) else { continue }
         let content = try String(contentsOf: url, encoding: .utf8)
         files.append((path: url.path.replacingOccurrences(of: outputDirectory.path, with: ""), content: content))
      }
      return files
   }

   @Test("--base-url override reaches every absolute-URL consumer in the rendered output")
   func overrideReachesAllConsumers() throws {
      let (config, projectDirectory) = try self.makeFixtureSite()
      defer { try? FileManager.default.removeItem(at: projectDirectory) }

      try SiteBuilder
         .blog(config: config, projectDirectory: projectDirectory)
         .baseURL("https://new-base.example")
         .buildPipeline()
         .build()

      let outputDirectory = projectDirectory.appendingPathComponent("_Site")
      let files = try self.textOutputFiles(in: outputDirectory)
      #expect(!files.isEmpty, "the fixture build must produce output files")

      // Core proof: the YAML base URL appears NOWHERE in the rendered site.
      let oldBaseHits = files.filter { $0.content.contains("old-base.example") }.map(\.path)
      #expect(oldBaseHits.isEmpty, "old base URL must not survive anywhere, found in: \(oldBaseHits)")

      // Positive proof per consumer family, so an accidentally-empty output cannot pass.
      func someFile(named suffix: String, contains needle: String) -> Bool {
         files.contains { $0.path.hasSuffix(suffix) && $0.content.contains(needle) }
      }
      // Canonical + og:url on the article page (PageShell).
      #expect(someFile(named: "hello-world/index.html", contains: "https://new-base.example/blog/hello-world/"))
      // Sitemap entries.
      #expect(someFile(named: "sitemap.xml", contains: "<loc>https://new-base.example"))
      // RSS feed channel and item URLs.
      #expect(someFile(named: "feed.xml", contains: "https://new-base.example"))
      // llms.txt resource links.
      #expect(someFile(named: "llms.txt", contains: "https://new-base.example"))
      // hreflang alternates: the de URL is absolute and locale-prefixed.
      #expect(files.contains { $0.content.contains("https://new-base.example/de/blog/hello-world/") })
      // Redirect stub canonical.
      #expect(someFile(named: "old-post/index.html", contains: "https://new-base.example/blog/hello-world/"))
   }

   @Test("Without an override the YAML baseURL stays in effect")
   func withoutOverrideKeepsYAMLBaseURL() throws {
      let (config, projectDirectory) = try self.makeFixtureSite()
      defer { try? FileManager.default.removeItem(at: projectDirectory) }

      try SiteBuilder
         .blog(config: config, projectDirectory: projectDirectory)
         .buildPipeline()
         .build()

      let outputDirectory = projectDirectory.appendingPathComponent("_Site")
      let files = try self.textOutputFiles(in: outputDirectory)

      // Regression guard, and proof that the all-consumers scan above is meaningful:
      // the very same fixture DOES emit the YAML base URL when no override is applied.
      let oldBaseFiles = files.filter { $0.content.contains("https://old-base.example") }.map(\.path)
      #expect(oldBaseFiles.contains { $0.hasSuffix("sitemap.xml") })
      #expect(oldBaseFiles.contains { $0.hasSuffix("llms.txt") })
      #expect(oldBaseFiles.contains { $0.hasSuffix("hello-world/index.html") })
      #expect(!files.contains { $0.content.contains("new-base.example") })
   }
}
