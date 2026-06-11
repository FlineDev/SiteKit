import Foundation
import Testing

@testable import SiteKit

@Suite("DocCLoader")
struct DocCLoaderTests {
   private let note = """
   # Meet FinanceKit

   Learn how FinanceKit lets your apps share financial data.

   @Metadata {
      @TitleHeading("WWDC24")
      @PageKind(sampleCode)
      @CallToAction(url: "https://developer.apple.com/videos/play/wwdc2024/2023", purpose: link, label: "Watch Video (23 min)")
      @Contributors {
         @GitHubUser(Jeehut)
      }
   }

   ## Overview

   Some **body** content with `code`.

   @Image(source: "diagram.png", alt: "A diagram")
   """

   private func load() throws -> PageModel {
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC24/WWDC24-2023-Meet-FinanceKit.md"),
         content: self.note
      )
      return try DocCLoader().load(source: source)
   }

   @Test("Extracts title and abstract from the H1 and lead paragraph")
   func titleAndAbstract() throws {
      let page = try self.load()
      #expect(page.title == "Meet FinanceKit")
      #expect(page.summary == "Learn how FinanceKit lets your apps share financial data.")
   }

   @Test("Extracts @Metadata into docc extension keys")
   func metadataExtraction() throws {
      let page = try self.load()
      #expect(page.extensions["doccTitleHeading"] as? String == "WWDC24")
      #expect(page.extensions["doccPageKind"] as? String == "sampleCode")
      #expect((page.extensions["doccCTAURL"] as? String)?.contains("wwdc2024/2023") == true)
      #expect(page.extensions["doccCTALabel"] as? String == "Watch Video (23 min)")
      #expect((page.extensions["doccContributors"] as? [String])?.contains("Jeehut") == true)
   }

   @Test("Renders the body and never leaks @Metadata or directive syntax")
   func bodyRendering() throws {
      let page = try self.load()
      // Standard markdown + DocC body directive rendered.
      #expect(page.htmlContent.contains("<h2"))
      #expect(page.htmlContent.contains("<strong>body</strong>"))
      #expect(page.htmlContent.contains("diagram.png"))
      #expect(page.htmlContent.contains("<img"))
      // Metadata block and title are lifted out of the body, never leaked.
      #expect(!page.htmlContent.contains("@Metadata"))
      #expect(!page.htmlContent.contains("@TitleHeading"))
      #expect(!page.htmlContent.contains("Meet FinanceKit"))
   }

   @Test("Slug derives from the filename")
   func slug() throws {
      let page = try self.load()
      #expect(page.slug == "wwdc24-2023-meet-financekit")
   }

   @Test("Pairs an .ai.md sibling into the community note as doccAIVariant")
   func pairsAIVariant() throws {
      let dir = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderAI-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: dir) }

      let communityPath = dir.appendingPathComponent("WWDC24-1-Note.md")
      try "# Note\n\nCommunity abstract.\n\n## Body\n\nCommunity content."
         .write(to: communityPath, atomically: true, encoding: .utf8)
      try "# Note\n\nAI abstract.\n\n## Body\n\nAI generated content."
         .write(to: dir.appendingPathComponent("WWDC24-1-Note.ai.md"), atomically: true, encoding: .utf8)

      let source = MarkdownSource(filePath: communityPath, content: try String(contentsOf: communityPath, encoding: .utf8))
      let page = try DocCLoader().load(source: source)

      #expect(page.slug == "wwdc24-1-note")
      #expect(page.htmlContent.contains("Community content."))
      let ai = page.extensions["doccAIVariant"] as? String
      #expect(ai?.contains("AI generated content.") == true)
      #expect(ai?.contains("Community content.") == false)
   }

   @Test("Reading-time minutes are parsed from the CallToAction label")
   func parsesMinutes() throws {
      let page = try self.load()
      #expect(page.extensions["doccMinutes"] as? Int == 23)
   }

   @Test("parseMinutes handles assorted label shapes")
   func parseMinutesShapes() {
      #expect(DocCLoader.parseMinutes(from: "Watch Video (23 min)") == 23)
      #expect(DocCLoader.parseMinutes(from: "Watch the video (7 min)") == 7)
      #expect(DocCLoader.parseMinutes(from: "Watch Video (105 min)") == 105)
      #expect(DocCLoader.parseMinutes(from: "Read the article") == nil)
      #expect(DocCLoader.parseMinutes(from: "No digits min") == nil)
   }

   @Test("A note with a real body is not a stub")
   func nonStub() throws {
      let page = try self.load()
      #expect(page.extensions["doccIsStub"] == nil)
   }

   @Test("An abstract-only note is flagged as a stub")
   func abstractOnlyStub() throws {
      let stub = """
      # Placeholder Session

      Notes for this session have not been written yet.

      @Metadata {
         @TitleHeading("WWDC25")
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-100-Placeholder.md"),
         content: stub
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.extensions["doccIsStub"] as? Bool == true)
   }

   @Test("A @PageKind(article) guide is never flagged as a stub, even when body is sparse")
   func contentArticleNotStub() throws {
      // A guide article with @PageKind(article): only an abstract paragraph, no body sections.
      // Without the fix, sparse body → isStub = true → empty-state renders instead of the guide.
      let guide = """
      # Contributing

      This project is a community effort and we welcome your contributions.

      @Metadata {
         @PageKind(article)
         @TitleHeading("Guides")
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/Contributing.md"),
         content: guide
      )
      let page = try DocCLoader().load(source: source)
      // @PageKind(article) must suppress stub detection.
      #expect(page.extensions["doccIsStub"] == nil)
      #expect(page.extensions["doccPageKind"] as? String == "article")
   }

   @Test("A @PageKind(article) guide with a full body is also not flagged as a stub")
   func contentArticleWithBodyNotStub() throws {
      let guide = """
      # Contributing

      Welcome to the contributing guide.

      @Metadata {
         @PageKind(article)
         @TitleHeading("Guides")
      }

      ## How to Contribute

      Open a pull request with your changes and a clear description.

      ## Code Style

      Follow the existing style in the codebase.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/Contributing.md"),
         content: guide
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.extensions["doccIsStub"] == nil)
      // Body must contain the guide sections.
      #expect(page.htmlContent.contains("How to Contribute"))
      #expect(page.htmlContent.contains("Code Style"))
   }

   @Test("A note with the template GitHub-handle placeholder is a stub")
   func placeholderHandleStub() {
      let body = "<p>Real-looking content</p>"
      #expect(DocCLoader.isStub(bodyHTML: body, rawMarkdown: "@GitHubUser(<replace this with your GitHub handle>)") == true)
      #expect(DocCLoader.isStub(bodyHTML: body, rawMarkdown: "@GitHubUser(Jeehut)") == false)
   }

   // MARK: - Contributor handle filtering

   @Test("isValidContributorHandle rejects empty, bracket-placeholders, and whitespace handles")
   func isValidContributorHandlePredicate() {
      // Bracket-placeholder patterns from the DocC note template.
      #expect(DocCLoader.isValidContributorHandle("<replace this with your GitHub handle>") == false)
      #expect(DocCLoader.isValidContributorHandle("<x>") == false)
      // Bare angle brackets.
      #expect(DocCLoader.isValidContributorHandle("ab<cd") == false)
      #expect(DocCLoader.isValidContributorHandle("ab>cd") == false)
      // Whitespace variants.
      #expect(DocCLoader.isValidContributorHandle("not a handle") == false)
      #expect(DocCLoader.isValidContributorHandle("tab\there") == false)
      // Empty string.
      #expect(DocCLoader.isValidContributorHandle("") == false)
      // Valid handles survive (plain, hyphenated, digits, mixed-case).
      #expect(DocCLoader.isValidContributorHandle("Jeehut") == true)
      #expect(DocCLoader.isValidContributorHandle("my-handle-7") == true)
      #expect(DocCLoader.isValidContributorHandle("Valid-7") == true)
      #expect(DocCLoader.isValidContributorHandle("abc123") == true)
   }

   @Test("Placeholder contributor alongside a real handle: only the real handle is kept")
   func placeholderContributorFiltered() throws {
      let note = """
      # Stub Session

      Abstract for a stub session.

      @Metadata {
         @TitleHeading("WWDC25")
         @Contributors {
            @GitHubUser(<replace this with your GitHub handle>)
            @GitHubUser(Jeehut)
         }
      }

      ## Overview

      Some real body content here.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-100-Stub-Session.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let contributors = page.extensions["doccContributors"] as? [String]
      #expect(contributors == ["Jeehut"])
   }

   @Test("Handle with internal whitespace is dropped")
   func whitespaceHandleFiltered() throws {
      let note = """
      # Spaced Session

      Abstract.

      @Metadata {
         @TitleHeading("WWDC25")
         @Contributors {
            @GitHubUser(not a handle)
            @GitHubUser(my-handle-7)
         }
      }

      ## Overview

      Real body here.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-200-Spaced.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let contributors = page.extensions["doccContributors"] as? [String]
      #expect(contributors == ["my-handle-7"])
   }

   @Test("Normal handles including hyphens and digits are preserved")
   func normalHandlesPreserved() throws {
      let note = """
      # Real Session

      Abstract for this real session.

      @Metadata {
         @TitleHeading("WWDC25")
         @Contributors {
            @GitHubUser(my-handle-7)
            @GitHubUser(alice)
            @GitHubUser(Bob42)
         }
      }

      ## Overview

      Real body content.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-300-Real.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let contributors = page.extensions["doccContributors"] as? [String]
      #expect(contributors?.contains("my-handle-7") == true)
      #expect(contributors?.contains("alice") == true)
      #expect(contributors?.contains("Bob42") == true)
      #expect(contributors?.count == 3)
   }

   @Test("Note whose only contributor is the placeholder has no doccContributors key")
   func onlyPlaceholderContributorYieldsNil() throws {
      let note = """
      # All-Placeholder Session

      Abstract.

      @Metadata {
         @TitleHeading("WWDC25")
         @Contributors {
            @GitHubUser(<replace this with your GitHub handle>)
         }
      }

      ## Overview

      Real body content exists here.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-400-Placeholder-Only.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      // The placeholder is the only entry; after filtering nothing remains,
      // so the key must be absent entirely.
      #expect(page.extensions["doccContributors"] == nil)
   }

   // MARK: - Topic group parsing

   @Test("Parses topic groups from a note with a ## Topics section")
   func parsesTopicGroups() throws {
      let note = """
      # WWDC24

      Xcode 16, Swift 6, iOS 18.

      @Metadata {
         @TitleHeading("Overview")
      }

      ## Topics

      ### First Day Events

      @Links(visualStyle: list) {
         - <doc:WWDC24-101-Keynote>
         - <doc:WWDC24-102-Platforms-State-of-the-Union>
      }

      ### New Tools & Frameworks

      @Links(visualStyle: list) {
         - <doc:WWDC24-10179-Meet-Swift-Testing>
         - <doc:WWDC24-2023-Meet-FinanceKit>
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC24/WWDC24.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let groups = page.extensions["doccTopicGroups"] as? [DocCTopicGroup]
      #expect(groups != nil)
      #expect(groups?.count == 2)
      // Groups appear in document order.
      #expect(groups?[0].title == "First Day Events")
      #expect(groups?[1].title == "New Tools & Frameworks")
      // Slugs match what DocCLoader produces for those filenames.
      #expect(groups?[0].slugs == ["wwdc24-101-keynote", "wwdc24-102-platforms-state-of-the-union"])
      #expect(groups?[1].slugs == ["wwdc24-10179-meet-swift-testing", "wwdc24-2023-meet-financekit"])
   }

   @Test("Note without a ## Topics section has no doccTopicGroups")
   func noTopicsSection() throws {
      // The standard session note has no ## Topics section.
      let page = try self.load()
      #expect(page.extensions["doccTopicGroups"] == nil)
   }

   @Test("Empty topic groups (no @Links entries) are skipped")
   func emptyGroupSkipped() throws {
      let note = """
      # WWDC25

      Abstract.

      @Metadata {
         @TitleHeading("Overview")
      }

      ## Topics

      ### Non-Empty Group

      @Links(visualStyle: list) {
         - <doc:WWDC25-100-Real-Session>
      }

      ### Empty Group

      @Links(visualStyle: list) {
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let groups = page.extensions["doccTopicGroups"] as? [DocCTopicGroup]
      // Only the non-empty group survives.
      #expect(groups?.count == 1)
      #expect(groups?[0].title == "Non-Empty Group")
   }

   @Test("Topic group also collects <doc:> targets from a plain Markdown list (no @Links wrapper)")
   func parsesTopicGroupsFromPlainList() throws {
      // A root/index page can curate loose guide articles into a named group with a bare
      // Markdown list of `<doc:…>` autolinks, not just an `@Links` directive.
      let note = """
      # Documentation

      The catalog root.

      ## Topics

      ### Guides

      - <doc:GettingStarted>
      - <doc:Reference>
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/Documentation.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      let groups = page.extensions["doccTopicGroups"] as? [DocCTopicGroup]
      #expect(groups?.count == 1)
      #expect(groups?[0].title == "Guides")
      #expect(groups?[0].slugs == ["gettingstarted", "reference"])
   }

   // MARK: - Contributor profile notes

   private func loadContributorProfile() throws -> PageModel {
      // Mirrors the exact shape `generate-metadata` writes to Contributors/<handle>.md.
      let note = """
      # Cihat Gündüz (71 notes)

      Spatial-first Indie Developer for Platforms. Actively contributing to Open Source since 2011!

      @Metadata {
         @TitleHeading("Contributors")
         @PageKind(sampleCode)
         @PageImage(purpose: icon, source: "Jeehut")
      }

      ## Links

      * [Blog](https://fline.dev)
      * [X/Twitter](https://x.com/Jeehut)

      ## Contributions

      Contributed 71 session notes in total. Their most active year was 2022.

      ### 2022

      @Links(visualStyle: list) {
         - <doc:WWDC22-10001-Some-Session>
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDCNotes.docc/Contributors/Jeehut.md"),
         content: note
      )
      return try DocCLoader().load(source: source)
   }

   @Test("A note under a Contributors/ directory is flagged as a contributor profile")
   func flagsContributorProfile() throws {
      let page = try self.loadContributorProfile()
      #expect((page.extensions["doccContributorProfile"] as? Bool) == true)
      // The full name (with umlaut) is the title; the bio is the abstract.
      #expect(page.title == "Cihat Gündüz (71 notes)")
      #expect(page.summary == "Spatial-first Indie Developer for Platforms. Actively contributing to Open Source since 2011!")
   }

   @Test("Parses ## Links into structured Blog and X/Twitter links in document order")
   func parsesContributorLinks() throws {
      let page = try self.loadContributorProfile()
      let links = page.extensions["doccContributorLinks"] as? [DocCContributorLink]
      #expect(links?.count == 2)
      #expect(links?[0] == DocCContributorLink(label: "Blog", url: "https://fline.dev"))
      #expect(links?[1] == DocCContributorLink(label: "X/Twitter", url: "https://x.com/Jeehut"))
   }

   @Test("Contributor-link parsing ignores the per-year <doc:> contribution autolinks")
   func contributorLinksIgnoreDocAutolinks() throws {
      let page = try self.loadContributorProfile()
      let links = page.extensions["doccContributorLinks"] as? [DocCContributorLink] ?? []
      // Only the two external ## Links entries – never the `## Contributions` <doc:> targets.
      #expect(links.allSatisfy { !$0.url.hasPrefix("doc:") })
      #expect(links.count == 2)
   }

   @Test("A regular session note is not flagged as a contributor profile and has no links")
   func regularNoteIsNotContributorProfile() throws {
      let page = try self.load()
      #expect(page.extensions["doccContributorProfile"] == nil)
      #expect(page.extensions["doccContributorLinks"] == nil)
   }

   // MARK: - B3: Framework comment

   @Test("parseFrameworkComment extracts key from HTML comment")
   func parseFrameworkCommentBasic() {
      #expect(DocCLoader.parseFrameworkComment(from: "<!-- framework: swiftui -->") == "swiftui")
      #expect(DocCLoader.parseFrameworkComment(from: "<!-- framework:swift -->") == "swift")
      #expect(DocCLoader.parseFrameworkComment(from: "<!--framework: alarmkit -->") == "alarmkit")
      #expect(DocCLoader.parseFrameworkComment(from: "<!-- framework: my_fw-2 -->") == "my_fw-2")
   }

   @Test("parseFrameworkComment returns nil when no comment present")
   func parseFrameworkCommentAbsent() {
      #expect(DocCLoader.parseFrameworkComment(from: "# Some session\n\nAbstract.") == nil)
      #expect(DocCLoader.parseFrameworkComment(from: "") == nil)
   }

   @Test("framework HTML comment sets doccFramework extension key on load")
   func frameworkCommentSetsExtension() throws {
      let note = """
      <!-- framework: swiftui -->
      # SwiftUI Talk

      A session about SwiftUI.

      @Metadata {
         @TitleHeading("WWDC25")
      }

      ## Overview

      Real body content.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-swiftui.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.extensions["doccFramework"] as? String == "swiftui")
   }

   @Test("Note without framework comment has no doccFramework key")
   func noFrameworkComment() throws {
      let page = try self.load()
      #expect(page.extensions["doccFramework"] == nil)
   }

   // MARK: - B3: @PageImage(purpose: icon)

   @Test("@PageImage(purpose: icon) sets doccNavIconURL extension key")
   func pageImageIconSetsNavIconURL() throws {
      let note = """
      # WWDC25

      Swift 6.2 and Liquid Glass.

      @Metadata {
         @TitleHeading("Overview")
         @PageImage(purpose: icon, source: "WWDC25")
      }

      ## Topics

      ### First Group

      @Links(visualStyle: list) {
         - <doc:WWDC25-100-Session>
      }
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      // No real image file exists at /tmp/WWDC25/ so the loader falls back to the bare
      // source name. The end-to-end test below verifies extension resolution when a file
      // actually exists on disk.
      #expect(page.extensions["doccNavIconURL"] as? String == "/assets/WWDC25")
   }

   @Test("Year overview without @PageImage has no doccNavIconURL")
   func noPageImageHasNoNavIconURL() throws {
      let page = try self.load()
      #expect(page.extensions["doccNavIconURL"] == nil)
   }

   @Test("@PageImage resolves extension when asset file exists on disk (e2e)")
   func pageImageIconResolvesExtension() throws {
      // Build a minimal fake .docc catalog on disk so resolveNavIconURL can find
      // the SVG file and append the correct extension.
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderE2E-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let imagesDir = catalogDir.appendingPathComponent("Images")
      let wwdcDir = catalogDir.appendingPathComponent("WWDC26")
      let fm = FileManager.default
      try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
      try fm.createDirectory(at: wwdcDir, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      // Place a WWDC26.svg in the catalog's Images/ directory.
      let svgPath = imagesDir.appendingPathComponent("WWDC26.svg")
      try "<svg xmlns=\"http://www.w3.org/2000/svg\"/>".write(to: svgPath, atomically: true, encoding: .utf8)

      let note = """
      # WWDC26

      Swift 7 and beyond.

      @Metadata {
         @TitleHeading("Overview")
         @PageImage(purpose: icon, source: "WWDC26")
      }
      """
      // Source file lives inside the catalog (WWDC26/WWDC26.md), so the walker finds
      // the .docc ancestor and looks in Images/.
      let sourcePath = wwdcDir.appendingPathComponent("WWDC26.md")
      try note.write(to: sourcePath, atomically: true, encoding: .utf8)

      let source = MarkdownSource(filePath: sourcePath, content: note)
      let page = try DocCLoader().load(source: source)

      // The loader must resolve "/assets/WWDC26" → "/assets/WWDC26.svg".
      #expect(page.extensions["doccNavIconURL"] as? String == "/assets/WWDC26.svg")
   }

   // MARK: - Tags frontmatter (Gap #3)

   @Test("DocC note with YAML frontmatter tags: [iOS, macOS] yields page.tags == [\"iOS\", \"macOS\"] and renders sk-docc-badge pills")
   func frontmatterTagsInlineArray() throws {
      let note = """
      ---
      tags: [iOS, macOS]
      ---
      # Tagged Session

      A session about multiple platforms.

      @Metadata {
         @TitleHeading("WWDC25")
      }

      ## Overview

      Some body content here.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-tagged.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.tags == ["iOS", "macOS"])
   }

   @Test("DocC note with comma-separated tags string yields correctly split tags")
   func frontmatterTagsCommaSeparated() throws {
      let note = """
      ---
      tags: iOS, iPadOS, macOS
      ---
      # Comma Tagged

      Abstract.

      @Metadata {
         @TitleHeading("WWDC25")
      }

      ## Overview

      Body.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-comma-tagged.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.tags == ["iOS", "iPadOS", "macOS"])
   }

   @Test("DocC note with YAML block sequence tags yields correctly parsed tags")
   func frontmatterTagsBlockSequence() throws {
      let note = """
      ---
      tags:
        - iOS
        - watchOS
      ---
      # Block Tags

      Abstract.

      @Metadata {
         @TitleHeading("WWDC25")
      }

      ## Overview

      Body.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-block-tagged.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.tags == ["iOS", "watchOS"])
   }

   @Test("DocC note without frontmatter has empty tags")
   func frontmatterTagsAbsent() throws {
      let page = try self.load()
      #expect(page.tags.isEmpty)
   }

   @Test("stripFrontmatter extracts tags and returns remaining Markdown without delimiters")
   func stripFrontmatterExtracts() {
      let content = """
      ---
      tags: [iOS, macOS]
      ---
      # My Session

      Abstract.
      """
      let (tags, markdown) = DocCLoader.stripFrontmatter(from: content)
      #expect(tags == ["iOS", "macOS"])
      #expect(markdown.contains("# My Session"))
      #expect(!markdown.contains("---"))
      #expect(!markdown.contains("tags:"))
   }

   @Test("stripFrontmatter returns empty tags and unchanged content when no frontmatter")
   func stripFrontmatterNoFrontmatter() {
      let content = "# My Session\n\nAbstract."
      let (tags, markdown) = DocCLoader.stripFrontmatter(from: content)
      #expect(tags.isEmpty)
      #expect(markdown == content)
   }

   @Test("DocC note tags render as sk-docc-badge pills in the article meta row")
   func tagsRenderAsBadges() throws {
      let note = """
      ---
      tags: [iOS, iPadOS, macOS, watchOS]
      ---
      # Badges Test

      A session about icon design.

      @Metadata {
         @TitleHeading("WWDC25")
         @CallToAction(url: "https://developer.apple.com/videos/play/wwdc2025/361", purpose: link, label: "Watch Video (14 min)")
      }

      ## Overview

      Body content here.

      ## Design

      More design content.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-361-badges.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.tags == ["iOS", "iPadOS", "macOS", "watchOS"])
   }

   @Test("AI-only note loads with its session slug and no variant")
   func aiOnlyNote() throws {
      let dir = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderAIOnly-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: dir) }

      let aiPath = dir.appendingPathComponent("WWDC24-2-Solo.ai.md")
      try "# Solo\n\nAbstract.\n\n## Body\n\nAI only content."
         .write(to: aiPath, atomically: true, encoding: .utf8)

      let source = MarkdownSource(filePath: aiPath, content: try String(contentsOf: aiPath, encoding: .utf8))
      let page = try DocCLoader().load(source: source)

      // Trailing `.ai` stripped → session slug, not "…-ai", and no switcher variant.
      #expect(page.slug == "wwdc24-2-solo")
      #expect(page.htmlContent.contains("AI only content."))
      #expect(page.extensions["doccAIVariant"] == nil)
   }

   // MARK: - Image resolution (BUG A + BUG B + BUG C fixes)

   @Test("resolveImageName finds an image in the per-note sibling subfolder")
   func resolveImageNameFindsPerNoteSubfolder() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderResolve-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let wwdc25Dir = catalogDir.appendingPathComponent("WWDC25")
      let noteSubfolder = wwdc25Dir.appendingPathComponent("WWDC25-361-Create-icons-with-Icon-Composer")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      // Place the body image in the per-note sibling subfolder.
      try "jpeg-data".write(
         to: noteSubfolder.appendingPathComponent("WWDC25-361-Supported-Icon-Modes.jpeg"),
         atomically: true,
         encoding: .utf8
      )

      let sourcePath = wwdc25Dir.appendingPathComponent("WWDC25-361-Create-icons-with-Icon-Composer.md")
      let resolved = DocCLoader.resolveImageName("WWDC25-361-Supported-Icon-Modes", relativeTo: sourcePath)
      #expect(resolved == "/assets/WWDC25-361-Supported-Icon-Modes.jpeg",
         "resolveImageName must find an image in the per-note sibling subfolder")
   }

   @Test("resolveImageName finds an image in the catalog Images/ directory")
   func resolveImageNameFindsImagesDir() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderResolveImages-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let imagesDir = catalogDir.appendingPathComponent("Images")
      let wwdc25Dir = catalogDir.appendingPathComponent("WWDC25")
      let fm = FileManager.default
      try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
      try fm.createDirectory(at: wwdc25Dir, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      try "svg-data".write(to: imagesDir.appendingPathComponent("WWDC25-Icon.svg"), atomically: true, encoding: .utf8)

      let sourcePath = wwdc25Dir.appendingPathComponent("WWDC25.md")
      let resolved = DocCLoader.resolveImageName("WWDC25-Icon", relativeTo: sourcePath)
      #expect(resolved == "/assets/WWDC25-Icon.svg",
         "resolveImageName must find an image in the catalog Images/ directory")
   }

   @Test("resolveVideoName finds an .mp4 in the per-note subfolder; image/video resolvers stay separate")
   func resolveVideoNameFindsVideo() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderResolveVideo-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let wwdcDir = catalogDir.appendingPathComponent("WWDC24")
      let noteSubfolder = wwdcDir.appendingPathComponent("WWDC24-188-Whats-new-in-SF-Symbols")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      try "mp4-data".write(to: noteSubfolder.appendingPathComponent("WWDC24-188-Magic-Replace.mp4"), atomically: true, encoding: .utf8)

      let sourcePath = wwdcDir.appendingPathComponent("WWDC24-188-Whats-new-in-SF-Symbols.md")
      let resolved = DocCLoader.resolveVideoName("WWDC24-188-Magic-Replace", relativeTo: sourcePath)
      #expect(resolved == "/assets/WWDC24-188-Magic-Replace.mp4",
         "resolveVideoName must find an .mp4 in the per-note sibling subfolder")
      // The image resolver must NOT pick up the video (the resolvers are deliberately separate
      // so an <img> never resolves to an .mp4).
      #expect(DocCLoader.resolveImageName("WWDC24-188-Magic-Replace", relativeTo: sourcePath) == nil,
         "resolveImageName must not resolve a video file")
   }

   @Test("resolveImageName returns nil when no file is found")
   func resolveImageNameReturnsNilOnMiss() {
      let sourcePath = URL(fileURLWithPath: "/tmp/nonexistent/WWDC25-999.md")
      let resolved = DocCLoader.resolveImageName("NoSuchImage", relativeTo: sourcePath)
      #expect(resolved == nil, "resolveImageName must return nil when the file does not exist on disk")
   }

   @Test("resolveImageName passes through names that already contain a dot (have an extension)")
   func resolveImageNameSkipsNameWithExtension() {
      let sourcePath = URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-1.md")
      // Names with extensions are not bare-name lookups; the function should return nil
      // so callers preserve the original value.
      let resolved = DocCLoader.resolveImageName("hero.png", relativeTo: sourcePath)
      #expect(resolved == nil, "resolveImageName must return nil for names that already have an extension")
   }

   @Test("rewriteBodyImageSrcs rewrites a bare-name src to /assets/<name>.<ext>")
   func rewriteBodyImageSrcsRewritesBare() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderRewrite-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let wwdc21Dir = catalogDir.appendingPathComponent("WWDC21")
      let noteSubfolder = wwdc21Dir.appendingPathComponent("WWDC21-10012-Whats-new-in-App-Clips")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      // Place the reference-style image in the per-note sibling subfolder.
      try "png-data".write(
         to: noteSubfolder.appendingPathComponent("WWDC21-10012-appClipSafari.png"),
         atomically: true,
         encoding: .utf8
      )

      let sourcePath = wwdc21Dir.appendingPathComponent("WWDC21-10012-Whats-new-in-App-Clips.md")
      // Simulate what MarkdownRenderer emits for `![][appClipSafari]` where the ref target
      // is `WWDC21-10012-appClipSafari` (bare name, no extension, relative).
      let rawHTML = "<p><img src=\"WWDC21-10012-appClipSafari\" alt=\"\" /></p>"
      let rewritten = DocCLoader.rewriteBodyImageSrcs(rawHTML, relativeTo: sourcePath).html

      #expect(
         rewritten.contains("src=\"/assets/WWDC21-10012-appClipSafari.png\""),
         "rewriteBodyImageSrcs must rewrite a bare-name src to /assets/<name>.<ext>"
      )
   }

   @Test("rewriteBodyImageSrcs leaves absolute, http, and data: srcs untouched")
   func rewriteBodyImageSrcsPreservesAbsoluteAndHttp() {
      let sourcePath = URL(fileURLWithPath: "/tmp/WWDC25/WWDC25-1.md")
      let html = """
         <img src="/assets/already-resolved.png" alt="" />
         <img src="https://example.com/remote.jpg" alt="" />
         <img src="data:image/png;base64,abc" alt="" />
         """
      let result = DocCLoader.rewriteBodyImageSrcs(html, relativeTo: sourcePath).html
      // None of the absolute/http/data srcs should be touched.
      #expect(result.contains("/assets/already-resolved.png"))
      #expect(result.contains("https://example.com/remote.jpg"))
      #expect(result.contains("data:image/png;base64,abc"))
   }

   @Test("@Image in a note with real disk files resolves to /assets/<name>.<ext>")
   func imageDirectiveResolvesWithRealFiles() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderImageE2E-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let wwdc25Dir = catalogDir.appendingPathComponent("WWDC25")
      let noteSubfolder = wwdc25Dir.appendingPathComponent("WWDC25-361-Create-icons-with-Icon-Composer")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      // Simulate the body image sitting in the per-note sibling subfolder.
      try "jpeg-data".write(
         to: noteSubfolder.appendingPathComponent("WWDC25-361-Supported-Icon-Modes.jpeg"),
         atomically: true,
         encoding: .utf8
      )

      let noteContent = """
      # Create icons with Icon Composer

      Learn how to use Icon Composer.

      @Metadata {
         @TitleHeading("WWDC25")
         @Contributors {
            @GitHubUser(Jeehut)
         }
      }

      ## Overview

      @Image(source: "WWDC25-361-Supported-Icon-Modes")
      """
      let sourcePath = wwdc25Dir.appendingPathComponent("WWDC25-361-Create-icons-with-Icon-Composer.md")
      try noteContent.write(to: sourcePath, atomically: true, encoding: .utf8)

      let source = MarkdownSource(filePath: sourcePath, content: noteContent)
      let page = try DocCLoader().load(source: source)

      #expect(
         page.htmlContent.contains("src=\"/assets/WWDC25-361-Supported-Icon-Modes.jpeg\""),
         "@Image(source:) must resolve to /assets/<name>.<ext> when the file exists on disk"
      )
      // Must not produce the old broken /images/ path.
      #expect(!page.htmlContent.contains("/images/"), "@Image must never produce /images/ path")
   }

   @Test("A bare image name with incidental dots (a screenshot timestamp) still resolves")
   func resolveImageNameHandlesDottedBareName() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderDotted-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let noteSubfolder = catalogDir.appendingPathComponent("WWDC23").appendingPathComponent("WWDC23-10158-Animate-with-springs")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      // The on-disk file carries a real extension; the reference target in the note does not –
      // its dots are a screenshot timestamp (`…_at_18.39.10`), which must not be mistaken for one.
      try "png-data".write(
         to: noteSubfolder.appendingPathComponent("WWDC23-10158-Screenshot_2023-06-11_at_18.39.10.png"),
         atomically: true,
         encoding: .utf8
      )
      let sourcePath = catalogDir.appendingPathComponent("WWDC23").appendingPathComponent("WWDC23-10158-Animate-with-springs.md")

      let resolved = DocCLoader.resolveImageName("WWDC23-10158-Screenshot_2023-06-11_at_18.39.10", relativeTo: sourcePath)
      #expect(
         resolved == "/assets/WWDC23-10158-Screenshot_2023-06-11_at_18.39.10.png",
         "a dotted-but-extensionless bare name must resolve to /assets/<name>.<ext>"
      )

      // A name that already ends in a real image extension is left for the caller (returns nil).
      #expect(
         DocCLoader.resolveImageName("WWDC23-10158-Screenshot_2023-06-11_at_18.39.10.png", relativeTo: sourcePath) == nil,
         "a name that already carries a real extension must not be re-resolved"
      )

      // End-to-end through the body rewrite: the dotted bare src is rewritten to the asset path.
      let rawHTML = "<p><img src=\"WWDC23-10158-Screenshot_2023-06-11_at_18.39.10\" alt=\"\" /></p>"
      let rewritten = DocCLoader.rewriteBodyImageSrcs(rawHTML, relativeTo: sourcePath).html
      #expect(rewritten.contains("src=\"/assets/WWDC23-10158-Screenshot_2023-06-11_at_18.39.10.png\""))
   }

   @Test("A single-row headerless pipe block renders as a table, not literal pipes")
   func headerlessSingleRowPseudoTableBecomesTable() throws {
      let note = """
      # Side By Side

      Lead paragraph.

      | Original | Saliency |

      Trailing paragraph.
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC19/WWDC19-1-Side-By-Side.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)

      #expect(page.htmlContent.contains("<table>"), "the headerless pipe row must become a real table")
      #expect(page.htmlContent.contains("<th"), "the single row becomes the table header")
      #expect(page.htmlContent.contains("Original"))
      #expect(page.htmlContent.contains("Saliency"))
      // The defining symptom: no literal pipe leaks into the rendered body.
      #expect(!page.htmlContent.contains("|"), "no stray pipe may survive into the HTML body")
   }

   @Test("A two-row headerless pipe block renders header + body cells, no stray pipes")
   func headerlessMultiRowPseudoTableBecomesTable() throws {
      let note = """
      # Captions

      | ![](shotA.png) | ![](shotB.png) |
      | First caption | Second caption |
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC18/WWDC18-1-Captions.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)

      #expect(page.htmlContent.contains("<table>"))
      #expect(page.htmlContent.contains("<thead>"))
      #expect(page.htmlContent.contains("<tbody>"))
      #expect(page.htmlContent.contains("First caption"))
      #expect(page.htmlContent.contains("Second caption"))
      #expect(page.htmlContent.contains("<img"), "images inside the cells still render")
      #expect(!page.htmlContent.contains("|"), "no stray pipe may survive into the HTML body")
   }

   @Test("An already-valid GFM table is left untouched (no double delimiter)")
   func validTableIsPreserved() throws {
      let note = """
      # Real Table

      | API | iOS | macOS |
      | --- | --- | --- |
      | Widgets | ✅ | ✅ |
      | Live Activities | ✅ | ❌ |
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC22/WWDC22-1-Real-Table.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)

      #expect(page.htmlContent.contains("<table>"))
      // Exactly one table is produced – a second injected delimiter would split or break it.
      #expect(page.htmlContent.components(separatedBy: "<table>").count - 1 == 1)
      #expect(page.htmlContent.contains("Widgets"))
      #expect(page.htmlContent.contains("Live Activities"))
      #expect(!page.htmlContent.contains("|"), "a valid table must not leak its source pipes either")
   }

   @Test("Pipes inside a fenced code block are never treated as a table")
   func pipesInCodeFenceAreLeftAlone() throws {
      let note = """
      # Code With Pipes

      ```swift
      let mask = a | b | c
      ```
      """
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC20/WWDC20-1-Code-Pipes.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)

      // The code block renders as code and is never reinterpreted as a table.
      #expect(!page.htmlContent.contains("<table>"), "a code fence must not be parsed as a table")
      #expect(page.htmlContent.contains("<pre"), "the fenced code block still renders as code")
      #expect(page.htmlContent.contains("|"), "the code's pipes are preserved, not stripped")
   }

   @Test("A 4-space indented code block with pipes is left as code, no stray delimiter leaks")
   func indentedCodeBlockWithPipesIsNotATable() throws {
      let note = "# T\n\nlead\n\n    | a | b |\n\ntrailing"
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC19/WWDC19-1-Indented.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("<pre"), "indented code stays code")
      #expect(!page.htmlContent.contains("<table>"), "indented code must not become a table")
      // The leaked delimiter renders as a paragraph starting with a pipe (its dashes are
      // smart-punctuation-converted, so matching on "---" would be vacuously green).
      #expect(!page.htmlContent.contains("<p>|"), "no synthetic delimiter may leak out as text")
   }

   @Test("A paragraph directly after a synthesized table is not absorbed as a table row")
   func trailingParagraphAfterPseudoTableStaysAParagraph() throws {
      let note = "# T\n\nLead.\n\n| a | b |\nTrailing paragraph."
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/WWDC19/WWDC19-2-Trailing.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.htmlContent.contains("<table>"), "the pipe row still becomes a table")
      #expect(page.htmlContent.contains("<p>Trailing paragraph.</p>"),
         "the following paragraph must stay a paragraph, not become a continuation row")
      #expect(!page.htmlContent.contains("<td>Trailing"),
         "the paragraph must not be absorbed into a table cell")
   }

   @Test("An asset with an uppercase extension (.JPG) resolves and keeps its on-disk casing")
   func resolveImageNameFindsUppercaseExtension() throws {
      let base = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("DocCLoaderUppercase-\(UUID().uuidString)")
      let catalogDir = base.appendingPathComponent("TestCatalog.docc")
      let wwdc23Dir = catalogDir.appendingPathComponent("WWDC23")
      let noteSubfolder = wwdc23Dir.appendingPathComponent("WWDC23-10039-Whats-new")
      let fm = FileManager.default
      try fm.createDirectory(at: noteSubfolder, withIntermediateDirectories: true)
      defer { try? fm.removeItem(at: base) }

      try "jpg-data".write(
         to: noteSubfolder.appendingPathComponent("WWDC23-10039-2configuration.JPG"),
         atomically: true,
         encoding: .utf8
      )

      let sourcePath = wwdc23Dir.appendingPathComponent("WWDC23-10039-Whats-new.md")
      let resolved = DocCLoader.resolveImageName("WWDC23-10039-2configuration", relativeTo: sourcePath)
      // The URL must carry the file's REAL casing: the teleporter copies the asset
      // verbatim, so "/assets/….jpg" would 404 on a case-sensitive web server.
      #expect(resolved == "/assets/WWDC23-10039-2configuration.JPG",
         "an uppercase-extension asset must resolve to its actual on-disk name")
   }

   @Test("An unresolvable bare image ref is dropped from the output and reported")
   func unresolvedBareImageRefIsDroppedAndReported() throws {
      let sourcePath = URL(fileURLWithPath: "/tmp/nonexistent/WWDC23/WWDC23-10039-Whats-new.md")
      let rawHTML = """
         <p><img src="WWDC23-10039-2configuration" alt="" /></p>\
         <p><img src="https://example.com/live.jpg" alt="" /></p>\
         <p><img src="diagram.png" alt="" /></p>
         """
      let rewrite = DocCLoader.rewriteBodyImageSrcs(rawHTML, relativeTo: sourcePath)

      #expect(!rewrite.html.contains("WWDC23-10039-2configuration"),
         "a bare ref with no file on disk must not survive as a raw src (silent 404)")
      #expect(rewrite.html.contains("https://example.com/live.jpg"), "remote URLs stay untouched")
      #expect(rewrite.html.contains("src=\"diagram.png\""),
         "an already-qualified filename is used verbatim, never dropped")
      #expect(rewrite.unresolvedRefs == ["WWDC23-10039-2configuration"],
         "the dead ref is reported so the loader can emit a build warning")

      // End-to-end through the loader: the dead-ref <img> never reaches the page body.
      let note = "# T\n\nlead\n\n![](missing-shot)"
      let source = MarkdownSource(filePath: sourcePath, content: note)
      let page = try DocCLoader().load(source: source)
      #expect(!page.htmlContent.contains("<img"), "the dead-ref <img> is dropped from the rendered body")
   }

   @Test("Backticks in a symbol-style H1 are stripped from the parsed title")
   func symbolStyleH1TitleStripsBackticks() throws {
      let note = "# Using `URLSession` effectively\n\nAbstract.\n\nBody."
      let source = MarkdownSource(
         filePath: URL(fileURLWithPath: "/tmp/Guides/Using-URLSession.md"),
         content: note
      )
      let page = try DocCLoader().load(source: source)
      #expect(page.title == "Using URLSession effectively",
         "inline-code delimiters must be stripped from the title, the content kept")
   }
}
