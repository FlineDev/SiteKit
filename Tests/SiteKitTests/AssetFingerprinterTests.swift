import Foundation
import Testing

@testable import SiteKit

@Suite("AssetFingerprinter")
struct AssetFingerprinterTests {
   private func makeTempDir(suffix: String = "") -> URL {
      let name = "SiteKitAssetFingerprinterTests-\(UUID().uuidString)\(suffix)"
      let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      return dir
   }

   private func write(_ content: String, to url: URL) throws {
      try FileManager.default.createDirectory(
         at: url.deletingLastPathComponent(),
         withIntermediateDirectories: true,
         attributes: nil
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
   }

   private func read(_ url: URL) -> String {
      (try? String(contentsOf: url, encoding: .utf8)) ?? ""
   }

   private func exists(_ url: URL) -> Bool {
      FileManager.default.fileExists(atPath: url.path)
   }

   // MARK: - Core behaviour

   @Test("A referenced theme CSS gets a hashed filename and the <head> link is rewritten to match")
   func hashesReferencedThemeCSS() throws {
      let output = self.makeTempDir(suffix: "-out")
      defer { try? FileManager.default.removeItem(at: output) }

      try self.write("body{color:red}", to: output.appendingPathComponent("assets/theme/css/theme.css"))
      try self.write(
         #"<!DOCTYPE html><html><head><link rel="stylesheet" href="/assets/theme/css/theme.css"/></head><body></body></html>"#,
         to: output.appendingPathComponent("index.html")
      )

      try AssetFingerprinter().process(outputDirectory: output, projectDirectory: output, themeConfig: nil)

      let html = self.read(output.appendingPathComponent("index.html"))

      // The head link uses the `<name>.<hash>.css` form.
      let hashedRefPattern = #/href="\/assets\/theme\/css\/theme\.[0-9a-f]{8}\.css"/#
      #expect(html.contains(hashedRefPattern))
      // The un-hashed reference is gone.
      #expect(!html.contains(#"href="/assets/theme/css/theme.css""#))

      // The emitted FILE was renamed to exactly the referenced hashed name (zero 404s).
      let match = html.firstMatch(of: #/\/assets\/theme\/css\/theme\.[0-9a-f]{8}\.css/#)
      let referenced = String(match!.output)
      let referencedFile = output.appendingPathComponent(String(referenced.dropFirst()))
      #expect(self.exists(referencedFile))
      // The old file no longer exists.
      #expect(!self.exists(output.appendingPathComponent("assets/theme/css/theme.css")))
      // Bytes are untouched – only the name changed.
      #expect(self.read(referencedFile) == "body{color:red}")
   }

   @Test("Hashed name is derived from the file's final bytes – changing content changes the hash")
   func contentChangeChangesHash() throws {
      func hashedNameAfterFingerprint(forCSS css: String) throws -> String {
         let output = self.makeTempDir(suffix: "-out")
         defer { try? FileManager.default.removeItem(at: output) }
         try self.write(css, to: output.appendingPathComponent("assets/theme/css/theme.css"))
         try self.write(
            #"<link rel="stylesheet" href="/assets/theme/css/theme.css"/>"#,
            to: output.appendingPathComponent("index.html")
         )
         try AssetFingerprinter().process(outputDirectory: output, projectDirectory: output, themeConfig: nil)
         let html = self.read(output.appendingPathComponent("index.html"))
         return String(html.firstMatch(of: #/theme\.[0-9a-f]{8}\.css/#)!.output)
      }

      let nameA = try hashedNameAfterFingerprint(forCSS: "body{color:red}")
      let nameAagain = try hashedNameAfterFingerprint(forCSS: "body{color:red}")
      let nameB = try hashedNameAfterFingerprint(forCSS: "body{color:blue}")

      // Deterministic: identical bytes → identical hash.
      #expect(nameA == nameAagain)
      // Content-sensitive: different bytes → different hash.
      #expect(nameA != nameB)
   }

   @Test("Emitted-but-unreferenced files (tokens.css / base.css) are left untouched")
   func leavesUnreferencedFilesAlone() throws {
      let output = self.makeTempDir(suffix: "-out")
      defer { try? FileManager.default.removeItem(at: output) }

      try self.write("body{color:red}", to: output.appendingPathComponent("assets/theme/css/theme.css"))
      // Emitted but never linked (PageShell inlines these instead).
      try self.write(":root{--x:1}", to: output.appendingPathComponent("assets/theme/css/tokens.css"))
      try self.write("*{margin:0}", to: output.appendingPathComponent("assets/css/base.css"))
      try self.write(
         #"<link rel="stylesheet" href="/assets/theme/css/theme.css"/>"#,
         to: output.appendingPathComponent("index.html")
      )

      try AssetFingerprinter().process(outputDirectory: output, projectDirectory: output, themeConfig: nil)

      // theme.css (referenced) is hashed away; tokens.css / base.css (unreferenced) stay put.
      #expect(!self.exists(output.appendingPathComponent("assets/theme/css/theme.css")))
      #expect(self.exists(output.appendingPathComponent("assets/theme/css/tokens.css")))
      #expect(self.exists(output.appendingPathComponent("assets/css/base.css")))
   }

   @Test("A reference whose target file does not exist is left verbatim (no invented 404)")
   func leavesDanglingReferenceVerbatim() throws {
      let output = self.makeTempDir(suffix: "-out")
      defer { try? FileManager.default.removeItem(at: output) }

      try self.write(
         #"<link rel="stylesheet" href="/assets/css/syntax.css"/>"#,
         to: output.appendingPathComponent("index.html")
      )

      try AssetFingerprinter().process(outputDirectory: output, projectDirectory: output, themeConfig: nil)

      // No file to hash → reference is unchanged.
      #expect(self.read(output.appendingPathComponent("index.html")).contains(#"href="/assets/css/syntax.css""#))
   }

   @Test("Every rewritten hashed reference resolves to a real file (zero-404 invariant)")
   func zeroDanglingReferencesAfterFingerprint() throws {
      let output = self.makeTempDir(suffix: "-out")
      defer { try? FileManager.default.removeItem(at: output) }

      // Mix of theme CSS (preload + stylesheet), theme JS, and a DocC-style script + css.
      try self.write("a{}", to: output.appendingPathComponent("assets/theme/css/theme.css"))
      try self.write("b{}", to: output.appendingPathComponent("assets/theme/fonts.css"))
      try self.write("console.log(1)", to: output.appendingPathComponent("assets/theme/js/theme.js"))
      try self.write("c{}", to: output.appendingPathComponent("assets/css/docc.css"))
      try self.write("console.log(2)", to: output.appendingPathComponent("assets/js/docc-theme.js"))
      let pageHTML = """
      <head>
      <link rel="preload" as="style" href="/assets/theme/css/theme.css"/>
      <link rel="preload" as="style" href="/assets/theme/fonts.css"/>
      <link rel="stylesheet" href="/assets/theme/css/theme.css"/>
      <link rel="stylesheet" href="/assets/css/docc.css"/>
      <script src="/assets/theme/js/theme.js" defer></script>
      <script defer src="/assets/js/docc-theme.js"></script>
      <link rel="search" href="/assets/nav-index.json"/>
      <link rel="stylesheet" href="https://cdn.example.com/font-awesome.css"/>
      </head>
      """
      try self.write(pageHTML, to: output.appendingPathComponent("page.html"))

      try AssetFingerprinter().process(outputDirectory: output, projectDirectory: output, themeConfig: nil)

      let html = self.read(output.appendingPathComponent("page.html"))
      // Every local /assets/*.css|js reference in the final HTML must point at an existing file.
      // (Same boundary lookahead as production, so `nav-index.json` is not mistaken for a `.js`.)
      for match in html.matches(of: #/\/assets\/[A-Za-z0-9._\/\-]*\.(?:css|js)(?![A-Za-z0-9._\/\-])/#) {
         let file = output.appendingPathComponent(String(String(match.output).dropFirst()))
         #expect(self.exists(file), "Dangling reference: \(String(match.output))")
      }
      // The external CDN URL and the JSON index are untouched.
      #expect(html.contains("https://cdn.example.com/font-awesome.css"))
      #expect(html.contains("/assets/nav-index.json"))
      // The two references to the same asset resolve to the SAME hashed name.
      let themeMatches = html.matches(of: #/\/assets\/theme\/css\/theme\.[0-9a-f]{8}\.css/#).map { String($0.output) }
      #expect(themeMatches.count == 2)
      #expect(Set(themeMatches).count == 1)
   }

   // MARK: - Pure helpers

   @Test("fingerprintedPath inserts the hash before the extension")
   func fingerprintedPathShape() {
      #expect(
         AssetFingerprinter.fingerprintedPath(for: "/assets/theme/css/theme.css", hash: "1a2b3c4d")
            == "/assets/theme/css/theme.1a2b3c4d.css"
      )
      #expect(
         AssetFingerprinter.fingerprintedPath(for: "/assets/js/docc-theme.js", hash: "deadbeef")
            == "/assets/js/docc-theme.deadbeef.js"
      )
   }

   @Test("shortHash is 8 lowercase hex chars, deterministic and content-sensitive")
   func shortHashShape() {
      let a = AssetFingerprinter.shortHash(of: Data("hello".utf8))
      let aAgain = AssetFingerprinter.shortHash(of: Data("hello".utf8))
      let b = AssetFingerprinter.shortHash(of: Data("hellp".utf8))
      #expect(a == aAgain)
      #expect(a != b)
      #expect(a.count == 8)
      #expect(a.allSatisfy { $0.isHexDigit && !$0.isUppercase })
   }

   @Test("isAlreadyFingerprinted detects the .<hash>.ext segment")
   func detectsAlreadyFingerprinted() {
      #expect(AssetFingerprinter.isAlreadyFingerprinted("/assets/theme/css/theme.1a2b3c4d.css"))
      #expect(!AssetFingerprinter.isAlreadyFingerprinted("/assets/theme/css/theme.css"))
      #expect(!AssetFingerprinter.isAlreadyFingerprinted("/assets/theme/css/fline-overrides.css"))
   }

   @Test("referencedAssetPaths finds local css/js, strips queries, ignores json and external URLs")
   func referencedAssetPathScan() {
      let html = """
      <link rel="preload" href="/assets/theme/css/theme.css"/>
      <link rel="stylesheet" href="/assets/theme/css/theme.css?v=abc12345"/>
      <script src="/assets/theme/js/theme.js?v=abc12345"></script>
      <link rel="search" href="/assets/nav-index.json"/>
      <link rel="stylesheet" href="https://cdn.example.com/all.min.css"/>
      """
      let paths = AssetFingerprinter.referencedAssetPaths(in: html)
      #expect(paths == ["/assets/theme/css/theme.css", "/assets/theme/js/theme.js"])
   }

   @Test("rewriteReferences swaps mapped paths (dropping any query) and leaves others verbatim")
   func rewriteReferencesBehaviour() {
      let map = ["/assets/theme/css/theme.css": "/assets/theme/css/theme.1a2b3c4d.css"]
      let html = #"<link href="/assets/theme/css/theme.css?v=abc12345"/><link href="/assets/css/other.css"/>"#
      let out = AssetFingerprinter.rewriteReferences(in: html, using: map)
      #expect(out.contains(#"href="/assets/theme/css/theme.1a2b3c4d.css""#))
      #expect(!out.contains("?v=abc12345"))
      // Unmapped reference untouched.
      #expect(out.contains(#"href="/assets/css/other.css""#))
   }
}
