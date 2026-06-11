import Foundation
import Testing
@testable import SiteKit

@Suite("CloudflareHeadersRenderer")
struct CloudflareHeadersRendererTests {
   // MARK: - Helpers

   private func makeContext() -> BuildContext {
      let config = SiteConfig(name: "Test", baseURL: "https://example.com")
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func renderHeaders() throws -> String {
      let files = try CloudflareHeadersRenderer().render(context: self.makeContext())
      let headers = try #require(files.first { $0.outputPath.lastPathComponent == "_headers" })
      return headers.content
   }

   /// Returns the `Cache-Control` directive for the rule whose path line equals `path`
   /// exactly (after trimming). A `_headers` rule is a non-indented path line followed by
   /// indented header lines; this grabs the first `Cache-Control` line under that path.
   private func cacheControl(forPath path: String, in headers: String) -> String? {
      let lines = headers.components(separatedBy: "\n")
      guard let pathIndex = lines.firstIndex(where: {
         $0.trimmingCharacters(in: .whitespaces) == path
      }) else {
         return nil
      }
      for line in lines[(pathIndex + 1)...] {
         let trimmed = line.trimmingCharacters(in: .whitespaces)
         if trimmed.hasPrefix("Cache-Control:") {
            return trimmed
         }
         // Stop at the next rule's (non-indented, non-empty) path line.
         if !trimmed.isEmpty && !line.hasPrefix(" ") {
            break
         }
      }
      return nil
   }

   // MARK: - HTML freshness

   /// With content-hashed assets, HTML must always revalidate against origin so a
   /// redeploy is visible immediately (no stale page served from a CDN cache window).
   @Test("HTML catch-all always revalidates (max-age=0, never max-age=3600)")
   func htmlAlwaysRevalidates() throws {
      let headers = try self.renderHeaders()
      let htmlCacheControl = try #require(self.cacheControl(forPath: "/*", in: headers))

      #expect(htmlCacheControl.contains("max-age=0"))
      #expect(!htmlCacheControl.contains("max-age=3600"))
      #expect(htmlCacheControl.contains("must-revalidate"))
   }

   // MARK: - Asset immutability (guard against accidental loosening)

   /// Fingerprinted assets carry a content hash in their path, so they are safe to cache
   /// forever. This guards the immutable directive from being weakened by the HTML change.
   @Test("Fingerprinted assets stay immutable for a year")
   func assetsStayImmutable() throws {
      let headers = try self.renderHeaders()
      let assetCacheControl = try #require(self.cacheControl(forPath: "/assets/*.css", in: headers))

      #expect(assetCacheControl.contains("max-age=31536000"))
      #expect(assetCacheControl.contains("immutable"))
   }

   // MARK: - Cloudflare glob model (no immutable on fixed-name mutable assets)

   /// One parsed `_headers` rule: its path glob and the `Cache-Control` value, if any.
   private struct Rule {
      let pattern: String
      let cacheControl: String?
   }

   /// Parses the `_headers` text into rules. A rule starts at a non-indented path line
   /// (begins with `/`) and owns the indented header lines beneath it until the next
   /// path line.
   private func parseRules(_ headers: String) -> [Rule] {
      var rules: [Rule] = []
      var currentPattern: String?
      var currentCacheControl: String?
      func flush() {
         if let pattern = currentPattern {
            rules.append(Rule(pattern: pattern, cacheControl: currentCacheControl))
         }
      }
      for line in headers.components(separatedBy: "\n") {
         if line.hasPrefix("/") {
            flush()
            currentPattern = line.trimmingCharacters(in: .whitespaces)
            currentCacheControl = nil
         } else {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Cache-Control:") {
               currentCacheControl = trimmed
            }
         }
      }
      flush()
      return rules
   }

   /// Models Cloudflare's `_headers` glob matching: a single `*` greedily matches any run
   /// of characters including path separators, every other character is literal, and the
   /// pattern is anchored to the full request path.
   private func globMatches(_ pattern: String, _ path: String) -> Bool {
      var regex = "^"
      for character in pattern {
         if character == "*" {
            regex += ".*"
         } else {
            regex += NSRegularExpression.escapedPattern(for: String(character))
         }
      }
      regex += "$"
      return path.range(of: regex, options: .regularExpression) != nil
   }

   /// Every rule whose glob matches `path` and whose `Cache-Control` carries `immutable`.
   /// Cloudflare merges the headers of all matching rules, so a path is cached immutable
   /// when *any* matching rule says so – this returns that full set, not just the first.
   private func immutableRules(forPath path: String, in headers: String) -> [String] {
      self.parseRules(headers)
         .filter { self.globMatches($0.pattern, path) && ($0.cacheControl?.contains("immutable") ?? false) }
         .map(\.pattern)
   }

   /// The core regression guard. `nav-index.json` and `search-index.json` are fixed-name,
   /// content-mutable files refetched at stable URLs every build. Under the old blanket
   /// `/assets/*` immutable rule, Cloudflare merged `immutable` onto them (no override by
   /// specificity), pinning stale navigation/search for a year. No immutable rule may match
   /// them; the fingerprinted CSS/JS must still be immutable.
   @Test("No immutable rule matches the mutable index JSONs, but hashed CSS/JS stay immutable")
   func immutableNeverMatchesMutableIndexJSONs() throws {
      let headers = try self.renderHeaders()

      // Fixed-name mutable files that are fetched at stable URLs: never immutable.
      for mutablePath in [
         "/assets/nav-index.json",
         "/assets/search-index.json",
         "/assets/docc-sidebar-nav.json",
         "/assets/search/docc-search.json",
         "/assets/Directives-Layout.png",
         "/assets/theme/images/site-logo.webp",
      ] {
         let matches = self.immutableRules(forPath: mutablePath, in: headers)
         #expect(matches.isEmpty, "\(mutablePath) must not be immutable, but matched: \(matches)")
      }

      // Representative content-hashed assets: still immutable for a year.
      for hashedPath in [
         "/assets/theme/css/theme.80524199.css",
         "/assets/css/docc.a8fe2a61.css",
         "/assets/js/docc-filter.0ed08814.js",
         "/assets/theme/js/theme.cf0e62f3.js",
      ] {
         let matches = self.immutableRules(forPath: hashedPath, in: headers)
         #expect(!matches.isEmpty, "\(hashedPath) must stay immutable, but no immutable rule matched")
      }
   }
}
