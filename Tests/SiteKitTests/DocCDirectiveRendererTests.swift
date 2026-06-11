import Foundation
import Markdown
import Testing

@testable import SiteKit

@Suite("DocCDirectiveRenderer")
struct DocCDirectiveRendererTests {
   private func directives(in markdown: String) -> [BlockDirective] {
      let doc = Document(parsing: markdown, options: [.parseBlockDirectives])
      return doc.children.compactMap { $0 as? BlockDirective }
   }

   @Test("@Image renders a figure with src and alt")
   func imageRenders() {
      let dirs = self.directives(in: "@Image(source: \"hero.png\", alt: \"A hero\")")
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("<img"))
      #expect(html.contains("alt=\"A hero\""))
      #expect(html.contains("hero.png"))
   }

   @Test("Unknown directive degrades to its inner content, never leaks @Name")
   func unknownDegrades() {
      let markdown = """
      @SomeFutureDirective {
         Readable inner text.
      }
      """
      let dirs = self.directives(in: markdown)
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("Readable inner text."))
      #expect(!html.contains("@SomeFutureDirective"))
   }

   @Test("Gotcha #1: @State inside a swift code fence is not parsed as a directive")
   func codeFenceAttributesAreNotDirectives() {
      let markdown = """
      @Image(source: "x.png", alt: "x")

      ```swift
      @State private var count = 0
      ```
      """
      let doc = Document(parsing: markdown, options: [.parseBlockDirectives])
      let directiveNames = doc.children.compactMap { ($0 as? BlockDirective)?.name }
      #expect(directiveNames.contains("Image"))
      #expect(!directiveNames.contains("State"))
      let codeBlocks = doc.children.compactMap { $0 as? CodeBlock }
      #expect(codeBlocks.contains { $0.code.contains("@State") })
   }

   @Test("Arg-only directive with no inner content degrades to a source link, never empty")
   func argOnlyDirectiveDegradesToLink() {
      let dirs = self.directives(in: "@FutureMedia(source: \"clip.mp4\")")
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(!html.isEmpty)
      #expect(html.contains("clip.mp4"))
      #expect(html.contains("<a "))
      #expect(!html.contains("@FutureMedia"))
   }

   @Test("@Comment is dropped entirely")
   func commentDropped() {
      let dirs = self.directives(in: "@Comment { auto-generated below }")
      #expect(dirs.count == 1)
      #expect(DocCDirectiveRenderer().render(dirs[0]).isEmpty)
   }

   @Test("@Row/@Column nest and render as grid containers")
   func rowColumnNest() {
      let markdown = """
      @Row {
         @Column {
            Left content.
         }
         @Column {
            Right content.
         }
      }
      """
      let dirs = self.directives(in: markdown)
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("sk-docc-row"))
      #expect(html.contains("sk-docc-column"))
      #expect(html.contains("Left content."))
      #expect(html.contains("Right content."))
   }

   // MARK: – Image source resolution (BUG B fix)

   @Test("@Image with no sourcePath degrades to /assets/<name> (never /images/)")
   func imageWithoutSourcePathDegradesCleanly() {
      let dirs = self.directives(in: "@Image(source: \"MyImage\", alt: \"desc\")")
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      // Without a sourcePath the resolver cannot find a file, but must never produce /images/.
      #expect(html.contains("/assets/MyImage"), "Bare name must degrade to /assets/<name>")
      #expect(!html.contains("/images/"), "Old broken /images/ path must not appear")
   }

   @Test("@Image with a sourcePath and a real file on disk resolves to /assets/<name>.<ext>")
   func imageWithSourcePathResolvesToAssets() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCDirectiveRendererE2E-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("Test.docc")
      let wwdcDir = catalogDir.appendingPathComponent("WWDC25")
      let noteSubfolder = wwdcDir.appendingPathComponent("WWDC25-361-Note")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      try "jpeg".write(to: noteSubfolder.appendingPathComponent("WWDC25-361-Hero.jpeg"), atomically: true, encoding: .utf8)

      let sourcePath = wwdcDir.appendingPathComponent("WWDC25-361-Note.md")
      let renderer = DocCDirectiveRenderer(sourcePath: sourcePath)
      let dirs = self.directives(in: "@Image(source: \"WWDC25-361-Hero\", alt: \"Hero image\")")
      #expect(dirs.count == 1)
      let html = renderer.render(dirs[0])
      #expect(html.contains("src=\"/assets/WWDC25-361-Hero.jpeg\""),
         "@Image with sourcePath must resolve to /assets/<name>.<ext>")
      #expect(!html.contains("/images/"), "Old broken /images/ path must not appear")
   }

   @Test("@Image with an already-absolute src passes through untouched")
   func imageAbsoluteSrcPassesThrough() {
      let dirs = self.directives(in: "@Image(source: \"/assets/hero.png\", alt: \"hero\")")
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("src=\"/assets/hero.png\""), "Absolute src must pass through unchanged")
   }

   // MARK: – @Row / @Column size weights (#104 Gap 1)

   @Test("@Column(size:) emits flex-grow; @Row(numberOfColumns:) is carried; size-less column is unchanged")
   func columnSizeWeights() {
      let markdown = """
      @Row(numberOfColumns: 3) {
         @Column(size: 2) {
            Wide.
         }
         @Column(size: 1) {
            Narrow.
         }
         @Column {
            Plain.
         }
      }
      """
      let dirs = self.directives(in: markdown)
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("data-columns=\"3\""), "@Row(numberOfColumns:) must be carried as data-columns")
      #expect(html.contains("<div class=\"sk-docc-column\" style=\"flex-grow: 2\">"), "size:2 → flex-grow:2")
      #expect(html.contains("<div class=\"sk-docc-column\" style=\"flex-grow: 1\">"), "size:1 → flex-grow:1")
      // The size-less column must carry no style attribute (byte-identical to a plain column).
      #expect(html.contains("<div class=\"sk-docc-column\"><p>Plain."), "size-less column must carry no style attr")
   }

   // MARK: – @Video player (#104 Gap 2)

   @Test("@Video emits a real <video> player with a resolved source + DocC attributes")
   func videoRendersPlayer() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCVideoE2E-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("Test.docc")
      let noteSubfolder = catalogDir.appendingPathComponent("WWDC24").appendingPathComponent("WWDC24-188-Note")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      try "mp4".write(to: noteSubfolder.appendingPathComponent("WWDC24-188-Clip.mp4"), atomically: true, encoding: .utf8)
      try "png".write(to: noteSubfolder.appendingPathComponent("WWDC24-188-Poster.png"), atomically: true, encoding: .utf8)

      let sourcePath = catalogDir.appendingPathComponent("WWDC24").appendingPathComponent("WWDC24-188-Note.md")
      let renderer = DocCDirectiveRenderer(sourcePath: sourcePath)
      let dirs = self.directives(in: "@Video(source: \"WWDC24-188-Clip.mp4\", poster: \"WWDC24-188-Poster\")")
      #expect(dirs.count == 1)
      let html = renderer.render(dirs[0])
      #expect(html.contains("<video "), "must emit a real <video> element, not a link")
      #expect(!html.contains("<a "), "must not degrade to an <a> link when the source resolves")
      #expect(html.contains("autoplay"))
      #expect(html.contains("loop"))
      #expect(html.contains("muted"))
      #expect(html.contains("playsinline"))
      #expect(html.contains("<source src=\"/assets/WWDC24-188-Clip.mp4\" type=\"video/mp4\">"),
         "resolved source must point to the teleported /assets/<name>.mp4")
      #expect(html.contains("poster=\"/assets/WWDC24-188-Poster.png\""), "poster: must resolve to an image asset")
   }

   @Test("@Video derives video/quicktime for .mov and degrades an unresolvable bare name to a link")
   func videoMimeAndFallback() {
      // Explicit .mov extension (no sourcePath): still emits a player at the plausible /assets path.
      let mov = DocCDirectiveRenderer().render(self.directives(in: "@Video(source: \"clip.mov\")")[0])
      #expect(mov.contains("<video "))
      #expect(mov.contains("<source src=\"/assets/clip.mov\" type=\"video/quicktime\">"))

      // Bare extension-less, unresolvable source: degrade to a link, never a broken empty <video>.
      let bare = DocCDirectiveRenderer().render(self.directives(in: "@Video(source: \"mysteryclip\")")[0])
      #expect(!bare.contains("<video"), "an unresolvable extension-less source must not emit a <video>")
      #expect(bare.contains("<a "), "it must fall back to a graceful link instead")
   }

   // MARK: – @TabNavigator interactive tabs (#104 Gap 3)

   @Test("@TabNavigator emits a tab bar with labels, exactly one checked radio, and one panel per tab")
   func tabNavigatorRenders() {
      let markdown = """
      @TabNavigator {
         @Tab("Declared") {
            First panel.
         }
         @Tab("Resolved") {
            Second panel.
         }
      }
      """
      let dirs = self.directives(in: markdown)
      #expect(dirs.count == 1)
      let html = DocCDirectiveRenderer().render(dirs[0])
      #expect(html.contains("sk-docc-tab-bar"))
      #expect(html.contains(">Declared</label>"), "the @Tab label must appear in the tab bar")
      #expect(html.contains(">Resolved</label>"))
      #expect(html.contains("First panel."))
      #expect(html.contains("Second panel."))
      // Exactly one radio starts checked → CSS shows exactly one panel at a time.
      #expect(html.components(separatedBy: " checked").count - 1 == 1, "exactly one tab must start checked")
      // One panel per tab (the wrapper class `sk-docc-tab-panels` does not match the trailing quote).
      #expect(html.components(separatedBy: "sk-docc-tab-panel\"").count - 1 == 2, "one panel per tab")
      // Each label is associated with its input via for/id (keyboard + a11y).
      #expect(html.contains("<label class=\"sk-docc-tab-label\" for="))
   }

   @Test("Two tab groups on one page get distinct, deterministic radio names (independent switching)")
   func tabNavigatorGroupUniqueness() {
      let groupA = """
      @TabNavigator {
         @Tab("Declared") { A1. }
         @Tab("Resolved") { A2. }
      }
      """
      let groupB = """
      @TabNavigator {
         @Tab("Light") { B1. }
         @Tab("Dark") { B2. }
      }
      """
      let renderer = DocCDirectiveRenderer()
      let nameA = Self.firstRadioName(in: renderer.render(self.directives(in: groupA)[0]))
      let nameB = Self.firstRadioName(in: renderer.render(self.directives(in: groupB)[0]))
      #expect(nameA != nil && nameB != nil)
      #expect(nameA != nameB, "two distinct tab groups must not share a radio name")
      // Stable across renders: same input → same name (deterministic, no randomness).
      let nameARepeat = Self.firstRadioName(in: renderer.render(self.directives(in: groupA)[0]))
      #expect(nameARepeat == nameA, "a tab group's radio name must be stable across renders")
   }

   /// Extracts the value of the first `name="…"` attribute in an HTML string.
   private static func firstRadioName(in html: String) -> String? {
      guard let range = html.range(of: "name=\"") else { return nil }
      let rest = html[range.upperBound...]
      guard let end = rest.firstIndex(of: "\"") else { return nil }
      return String(rest[..<end])
   }
}
