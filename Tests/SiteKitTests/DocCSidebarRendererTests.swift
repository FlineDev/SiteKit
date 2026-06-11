import Foundation
import Testing

@testable import SiteKit

@Suite("DocCSidebarRenderer")
struct DocCSidebarRendererTests {
   private let tree: [DocCNavNode] = [
      DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
         DocCNavNode(title: "Session A", url: "/documentation/wwdc25-1-a/"),
      ]),
      DocCNavNode(title: "WWDC24", url: "/documentation/wwdc24/", children: [
         DocCNavNode(title: "Meet X", url: "/documentation/wwdc24-10060-meet-x/"),
         DocCNavNode(title: "What's New", url: "/documentation/wwdc24-10061-whats-new/"),
      ]),
      DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
   ]

   @Test("Only the active year expands its sessions into the DOM")
   func activeBranchOnlyDOM() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      // Active year's sessions are present...
      #expect(html.contains("Meet X"))
      #expect(html.contains("What's New"))
      #expect(html.contains("sk-docc-nav-sessions"))
      // ...the other year's session is NOT in the DOM (no 2183-node dump).
      #expect(!html.contains("Session A"))
      // All year nodes are still listed as links.
      #expect(html.contains("WWDC25"))
      #expect(html.contains("WWDC24"))
      #expect(html.contains("Contributing"))
   }

   @Test("A curated loose-page group renders as its own labelled section, not under Articles")
   func rendersCuratedGroupSection() {
      let tree: [DocCNavNode] = [
         DocCNavNode(title: "WWDC24", url: "/documentation/wwdc24/", children: [
            DocCNavNode(title: "Meet X", url: "/documentation/wwdc24-10060-meet-x/"),
         ]),
         DocCNavNode(title: "Guides", url: "", children: [
            DocCNavNode(title: "Getting Started", url: "/documentation/gettingstarted/"),
            DocCNavNode(title: "Reference", url: "/documentation/reference/"),
         ], isGroup: true),
         DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
      ]
      let html = DocCSidebarRenderer().render(tree: tree, currentSlug: "gettingstarted")
      // The group title appears as a nav section header.
      #expect(html.contains("<p class=\"sk-docc-nav-section\">Guides</p>"))
      // Its curated children are links under that section.
      #expect(html.contains("href=\"/documentation/gettingstarted/\""))
      #expect(html.contains("href=\"/documentation/reference/\""))
      // The default Articles section still hosts the uncurated loose page.
      #expect(html.contains("<p class=\"sk-docc-nav-section\">Articles</p>"))
      #expect(html.contains("Contributing"))
      // A group node is never rendered as an expandable year (no twist/branch for it).
      #expect(!html.contains("data-docc-branch=\"\""))
   }

   @Test("Current page is marked aria-current")
   func marksCurrentPage() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc24-10061-whats-new")
      #expect(html.contains("href=\"/documentation/wwdc24-10061-whats-new/\" aria-current=\"page\""))
      // The active year is expanded.
      #expect(html.contains("sk-docc-nav-expanded"))
   }

   @Test("A year-overview current page expands that year and marks it current")
   func yearOverviewCurrent() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("href=\"/documentation/wwdc25/\" aria-current=\"page\""))
      #expect(html.contains("Session A"))
      // WWDC24 sessions stay collapsed.
      #expect(!html.contains("Meet X"))
   }

   @Test("Sidebar hosts no full-text search box (search lives in the appbar overlay)")
   func sidebarOmitsSearchBox() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      // The single search affordance is the appbar ⌘K overlay; the sidebar carries no
      // search input or results list of its own.
      #expect(!html.contains("class=\"sk-docc-search-input\""))
      #expect(!html.contains("class=\"sk-docc-search-results\""))
      // The bottom tree-filter is a distinct affordance and remains.
      #expect(html.contains("sk-docc-filter-input"))
      // The theme switch belongs in the appbar, not the sidebar.
      #expect(!html.contains("sk-docc-themeswitch"))
   }

   @Test("A loose leaf expands no branch: every year subtree is an empty, hidden placeholder")
   func looseLeaf() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "contributing")
      #expect(html.contains("href=\"/documentation/contributing/\" aria-current=\"page\""))
      // No branch is active on a loose page, so no session (or contributor) row is in the DOM…
      #expect(!html.contains("class=\"sk-docc-nav-session\""))
      // …yet every year still emits its placeholder subtree, hidden + collapsed (#6: a twist
      // on every top item). The years carry the unified row + stable subtree ids regardless.
      #expect(html.contains("data-docc-branch-sessions=\"wwdc25\" hidden"))
      #expect(html.contains("data-docc-branch-sessions=\"wwdc24\" hidden"))
   }

   @Test("Renders a sidebar header with a mobile close button and no visible title")
   func sidebarHeader() {
      let html = DocCSidebarRenderer(title: "Docs").render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("class=\"sk-docc-sidebar-head\""))
      // The accessible name is the nav's aria-label, not a visible title heading.
      #expect(!html.contains("sk-docc-sidebar-title"))
      #expect(html.contains("aria-label=\"Docs\""))
      // The close affordance + the hook the toggle JS targets.
      #expect(html.contains("class=\"sk-docc-sidebar-close\""))
      #expect(html.contains("data-docc-sidebar-close"))
      // The icon-only close button needs an accessible name for screen readers.
      #expect(html.contains("aria-label=\"Close navigation\""))
      // The id the burger's aria-controls points at.
      #expect(html.contains("id=\"sk-docc-sidebar\""))
   }

   @Test("Loose pages are grouped under their own section eyebrow")
   func looseSectionEyebrow() {
      let html = DocCSidebarRenderer(looseSectionTitle: "Guides").render(tree: self.tree, currentSlug: "wwdc25")
      // The eyebrow groups the loose "Contributing" page away from the year tree.
      #expect(html.contains("class=\"sk-docc-nav-section\">Guides</p>"))
      #expect(html.contains("sk-docc-nav-loose"))
      #expect(html.contains("Contributing"))
   }

   @Test("Session rows carry an icon slot and a text span")
   func sessionRowStructure() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      #expect(html.contains("class=\"sk-docc-nav-icon\""))
      #expect(html.contains("class=\"sk-docc-nav-text\">Meet X</span>"))
   }

   // MARK: - B3: Framework icons

   @Test("Framework icon renders as a data-framework chip carrying the FA glyph, no inline color")
   func frameworkIconSingleColor() {
      let icons: [String: DocCFrameworkIcon] = [
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      ]
      let treeWithFW: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "SwiftUI Talk", url: "/documentation/wwdc25-swiftui/", framework: "swiftui"),
         ]),
      ]
      let renderer = DocCSidebarRenderer(frameworkIcons: icons)
      let html = renderer.render(tree: treeWithFW, currentSlug: "wwdc25-swiftui")
      // The chip is a bare glyph keyed by data-framework. The tile color and the white glyph
      // come from CSS, so the glyph carries no inline color/background style.
      #expect(html.contains("<i class=\"fa-solid fa-layer-group\" aria-hidden=\"true\">"))
      #expect(html.contains("data-framework=\"swiftui\""))
      #expect(html.contains("sk-docc-nav-fw-icon"))
      #expect(!html.contains("color:#1e88e5"))
   }

   @Test("Framework icon's tile is data-framework keyed, not an inline gradient")
   func frameworkIconGradient() {
      let icons: [String: DocCFrameworkIcon] = [
         "swift": DocCFrameworkIcon(glyph: "fa-brands fa-swift", colors: ["#f05138", "#ff8a3d"]),
      ]
      let treeWithFW: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Swift Talk", url: "/documentation/wwdc25-swift/", framework: "swift"),
         ]),
      ]
      let renderer = DocCSidebarRenderer(frameworkIcons: icons)
      let html = renderer.render(tree: treeWithFW, currentSlug: "wwdc25-swift")
      #expect(html.contains("fa-brands fa-swift"))
      #expect(html.contains("data-framework=\"swift\""))
      // The 2-color tile is painted by the generated [data-framework] CSS, not an inline style.
      #expect(!html.contains("linear-gradient"))
   }

   @Test("Neutral placeholder rendered when no framework or registry entry")
   func frameworkIconNeutralFallback() {
      let treeNoFW: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Some Talk", url: "/documentation/wwdc25-some/"),
         ]),
      ]
      // No frameworkIcons registry.
      let html = DocCSidebarRenderer().render(tree: treeNoFW, currentSlug: "wwdc25-some")
      // The generic sk-docc-nav-icon placeholder is used, no FA glyph.
      #expect(html.contains("class=\"sk-docc-nav-icon\""))
      #expect(!html.contains("sk-docc-nav-fw-icon"))
      #expect(!html.contains("fa-solid"))
   }

   // MARK: - B3: Year glyph

   @Test("Year glyph image rendered from glyphImageURL when present")
   func yearGlyphImage() {
      let treeWithGlyph: [DocCNavNode] = [
         DocCNavNode(
            title: "WWDC25",
            url: "/documentation/wwdc25/",
            children: [DocCNavNode(title: "Some Talk", url: "/documentation/wwdc25-some/")],
            glyphImageURL: "/assets/WWDC25.webp"
         ),
      ]
      let html = DocCSidebarRenderer().render(tree: treeWithGlyph, currentSlug: "wwdc25-some")
      // The year image now shares the unified 24px top-glyph footprint.
      #expect(html.contains("class=\"sk-docc-nav-yearglyph sk-docc-nav-top-glyph\""))
      #expect(html.contains("src=\"/assets/WWDC25.webp\""))
   }

   @Test("Year glyph placeholder rendered when no glyphImageURL")
   func yearGlyphPlaceholder() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("sk-docc-nav-yearglyph-placeholder"))
      // The placeholder shares the top-glyph footprint but is not the <img> variant.
      #expect(html.contains("sk-docc-nav-top-glyph"))
      #expect(!html.contains("class=\"sk-docc-nav-yearglyph sk-docc-nav-top-glyph\""))
   }

   // MARK: - B3: Contributors subtree

   @Test("Contributors subtree renders top-N avatars and note counts")
   func contributorsSubtree() {
      let contribs: [(handle: String, noteCount: Int)] = [
         ("Jeehut", 41),
         ("MarinRos", 28),
         ("DiegoVeg", 15),
      ]
      let renderer = DocCSidebarRenderer(contributorsLimit: 2, contributors: contribs)
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      // Top 2 contributors only (limit = 2).
      #expect(html.contains("Jeehut"))
      #expect(html.contains("MarinRos"))
      #expect(!html.contains("DiegoVeg"))
      // Avatar URL from GitHub.
      #expect(html.contains("github.com/Jeehut.png"))
      // Note count shown.
      #expect(html.contains("(41)"))
      // Contributors group element present, and the label is a real link to the
      // overview page (a separate twist link toggles the subtree with JS, navigates without).
      #expect(html.contains("sk-docc-nav-contrib-group"))
      #expect(html.contains("href=\"/documentation/contributors/\""))
      #expect(html.contains("data-docc-subtree-toggle"))
   }

   @Test("Avatar fallback attribute is set when avatarFallbackPath provided")
   func avatarFallbackAttr() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41)]
      let renderer = DocCSidebarRenderer(avatarFallbackPath: "avatar-fallback.svg", contributors: contribs)
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("data-avatar-fallback"))
      #expect(html.contains("/assets/avatar-fallback.svg"))
   }

   @Test("Contributors subtree absent when no contributors provided")
   func noContributorsSubtree() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      #expect(!html.contains("sk-docc-nav-contrib-group"))
      #expect(!html.contains("Contributors"))
   }

   // MARK: - Contributors feature gate (via make(from:))

   /// A BuildContext whose single note credits two contributors, so the only thing deciding the
   /// subtree's presence is the `contributors` feature flag (not data presence).
   private func contributorContext(enabled: Bool) -> BuildContext {
      let section = SectionConfig(name: "Docs", slug: "docs", contentDirectory: "Docs", urlPrefix: "documentation")
      let note = PageModel(
         title: "Meet X",
         slug: "wwdc25-1-a",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/wwdc25-1-a.md"),
         pageType: .article,
         extensions: ["doccNote": true, "doccContributors": ["Jeehut", "MarinRos"]]
      )
      return BuildContext(
         config: SiteConfig(
            name: "Docs",
            baseURL: "https://example.com",
            sections: [section],
            docc: DocCConfig(contributors: enabled)
         ),
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: [note])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   @Test("make(from:) suppresses the contributors subtree when the feature is off, even with contributor data")
   func makeGatesContributorsSubtreeOff() {
      let html = DocCSidebarRenderer.make(from: self.contributorContext(enabled: false))
         .render(tree: self.tree, currentSlug: "wwdc25")
      #expect(!html.contains("sk-docc-nav-contrib-group"))
      #expect(!html.contains("Jeehut"))
   }

   @Test("make(from:) renders the contributors subtree when the feature is on")
   func makeGatesContributorsSubtreeOn() {
      let html = DocCSidebarRenderer.make(from: self.contributorContext(enabled: true))
         .render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("sk-docc-nav-contrib-group"))
      #expect(html.contains("Jeehut"))
   }

   // MARK: - B3: Topic subgroups

   @Test("Topic subgroups render group headers under the active year")
   func topicSubgroups() {
      let groups = [
         DocCTopicGroup(title: "Design", slugs: ["wwdc25-1-a"]),
         DocCTopicGroup(title: "Swift", slugs: ["wwdc25-swift-talk"]),
      ]
      let treeWithGroups: [DocCNavNode] = [
         DocCNavNode(
            title: "WWDC25",
            url: "/documentation/wwdc25/",
            children: [
               DocCNavNode(title: "Session A", url: "/documentation/wwdc25-1-a/"),
               DocCNavNode(title: "Swift Talk", url: "/documentation/wwdc25-swift-talk/"),
            ],
            topicSubgroups: groups
         ),
      ]
      let html = DocCSidebarRenderer().render(tree: treeWithGroups, currentSlug: "wwdc25-1-a")
      // Subgroup headers are present.
      #expect(html.contains("sk-docc-nav-subgroup-h"))
      #expect(html.contains("Design"))
      #expect(html.contains("Swift"))
      // Sessions appear under their respective groups.
      #expect(html.contains("Session A"))
      #expect(html.contains("Swift Talk"))
      // The grouped sessions container.
      #expect(html.contains("sk-docc-nav-grouped"))
   }

   @Test("Flat session list rendered when no topic subgroups defined")
   func noSubgroupsFlatList() {
      let html = DocCSidebarRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      // A flat sk-docc-nav-sessions list, no grouped wrapper.
      #expect(html.contains("sk-docc-nav-sessions"))
      #expect(!html.contains("sk-docc-nav-grouped"))
      #expect(!html.contains("sk-docc-nav-subgroup-h"))
   }

   // MARK: - B3: Stub dimming

   @Test("Stub session row carries is-stub class and title affordance")
   func stubDimming() {
      let treeWithStub: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Normal Session", url: "/documentation/wwdc25-normal/"),
            DocCNavNode(title: "Stubbed Session", url: "/documentation/wwdc25-stub/", isStub: true),
         ]),
      ]
      let html = DocCSidebarRenderer().render(tree: treeWithStub, currentSlug: "wwdc25-normal")
      #expect(html.contains("sk-docc-nav-stub"))
      #expect(html.contains("title=\"No notes yet\""))
      // Non-stub session has no is-stub class.
      let normalRange = html.range(of: "Normal Session")!
      let stubRange = html.range(of: "sk-docc-nav-stub")!
      // Normal session anchor should appear before the stub marker for it.
      #expect(normalRange.lowerBound < stubRange.lowerBound || !html.contains("sk-docc-nav-stub\">Normal"))
   }

   // MARK: - B3: Filter box

   @Test("Pinned filter box present in sidebar output")
   func filterBoxPresent() {
      let html = DocCSidebarRenderer(filterPlaceholder: "Filter sessions & years").render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("sk-docc-filter"))
      #expect(html.contains("sk-docc-filter-input"))
      #expect(html.contains("sk-docc-filter-clear"))
      #expect(html.contains("Filter sessions &amp; years"))
   }

   @Test("Filter box uses localizable placeholder text")
   func filterBoxPlaceholder() {
      let html = DocCSidebarRenderer(filterPlaceholder: "Sessionen filtern").render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("Sessionen filtern"))
   }

   // MARK: - B3: Contributor href + isActive

   @Test("Contributor row href is real contributor detail URL (not #)")
   func contributorRowHref() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41)]
      let renderer = DocCSidebarRenderer(
         contributors: contribs,
         urlPrefix: "documentation"
      )
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      // Must point at the real contributor detail page, not the dead "#" placeholder.
      #expect(html.contains("href=\"/documentation/contributors/jeehut/\""))
      #expect(!html.contains("href=\"#\""))
   }

   @Test("Contributor row is marked active when currentSlug matches")
   func contributorRowActive() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41)]
      let renderer = DocCSidebarRenderer(
         contributors: contribs,
         urlPrefix: "documentation"
      )
      let html = renderer.render(tree: self.tree, currentSlug: "contributors/jeehut")
      #expect(html.contains("aria-current=\"page\""))
   }

   @Test("Contributor row is NOT marked active when currentSlug does not match")
   func contributorRowNotActive() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41)]
      let renderer = DocCSidebarRenderer(
         contributors: contribs,
         urlPrefix: "documentation"
      )
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      // The contributor row must NOT carry aria-current when we are on a year page.
      #expect(!html.contains("href=\"/documentation/contributors/jeehut/\" aria-current"))
   }

   // MARK: - B3: Localised strings

   @Test("contributorsLabel renders in sidebar instead of hardcoded English")
   func contributorsLabelLocalised() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41)]
      let renderer = DocCSidebarRenderer(
         contributors: contribs,
         contributorsLabel: "Mitwirkende"
      )
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("Mitwirkende"))
      // The hardcoded English word must not appear when a localised label is set.
      #expect(!html.contains(">Contributors<"))
   }

   @Test("stubTitle renders in session tooltip instead of hardcoded English")
   func stubTitleLocalised() {
      let treeWithStub: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Stubbed Session", url: "/documentation/wwdc25-stub/", isStub: true),
         ]),
      ]
      let renderer = DocCSidebarRenderer(
         stubTitle: "Noch keine Notizen"
      )
      let html = renderer.render(tree: treeWithStub, currentSlug: "wwdc25")
      #expect(html.contains("title=\"Noch keine Notizen\""))
      #expect(!html.contains("No notes yet"))
   }

   // MARK: - B3: Wordmark token (B2 follow-up)

   @Test("docc.css token block declares --color-docc-wordmark-2 and sk-docc-brand-2 references it")
   func wordmarkToken() throws {
      // Read the docc.css resource bundled with SiteKit using DocCStylesheetRenderer's own
      // loader. A missing resource now throws, failing the test instead of skipping it.
      let cssContent = try DocCStylesheetRenderer.loadDocCCSS()
      // The token must be declared in the .sk-docc-layout block.
      #expect(cssContent.contains("--color-docc-wordmark-2"))
      // The token must default to --color-accent.
      #expect(cssContent.contains("--color-docc-wordmark-2: var(--color-accent)"))
      // The .sk-docc-brand-2 rule must consume the token (not hard-code --color-accent directly).
      #expect(cssContent.contains("var(--color-docc-wordmark-2"))
   }

   // MARK: - #4-7: Unified two-target top items (Phase 1)

   /// A standard tree (2 years) rendered with a Contributors top item via `contributors:`.
   private func unifiedRenderer() -> DocCSidebarRenderer {
      DocCSidebarRenderer(contributors: [("Jeehut", 41), ("MarinRos", 28)])
   }

   private func count(_ needle: String, in haystack: String) -> Int {
      haystack.components(separatedBy: needle).count - 1
   }

   @Test("Every top item (years + Contributors) has a twist, a glyph and a nav link")
   func everyTopItemHasTwistGlyphLink() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // One twist per top item: 2 years + Contributors = 3 (regression: years had none).
      #expect(self.count("data-docc-subtree-toggle", in: html) == 3)
      // Years now sit in the shared row wrapper, each with its own twist.
      #expect(html.contains("sk-docc-nav-row"))
      #expect(html.contains("aria-controls=\"sk-docc-subtree-wwdc25\""))
      #expect(html.contains("aria-controls=\"sk-docc-subtree-wwdc24\""))
      #expect(html.contains("aria-controls=\"sk-docc-contrib-subtree\""))
      // Each top item carries a glyph and a nav link.
      #expect(html.contains("sk-docc-nav-top-glyph"))
      #expect(html.contains("sk-docc-nav-link sk-docc-nav-year"))
   }

   @Test("A year subtree has a stable id matching its twist's aria-controls")
   func yearSubtreeStableId() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      #expect(html.contains("id=\"sk-docc-subtree-wwdc24\""))
      #expect(html.contains("aria-controls=\"sk-docc-subtree-wwdc24\""))
      // The branch key is exposed on the <li> and on the subtree for the accordion JS.
      #expect(html.contains("data-docc-branch=\"wwdc24\""))
      #expect(html.contains("data-docc-branch-sessions=\"wwdc24\""))
   }

   @Test("Active branch is server-rendered open; the non-active branch is hidden")
   func activeBranchOpenNonActiveHidden() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc24-10060-meet-x")
      // Active year: subtree carries no `hidden`, twist is aria-expanded="true".
      #expect(html.contains("data-docc-branch-sessions=\"wwdc24\">"))
      #expect(html.contains("aria-controls=\"sk-docc-subtree-wwdc24\" aria-expanded=\"true\""))
      // Non-active year: subtree is hidden, twist is aria-expanded="false".
      #expect(html.contains("data-docc-branch-sessions=\"wwdc25\" hidden>"))
      #expect(html.contains("aria-controls=\"sk-docc-subtree-wwdc25\" aria-expanded=\"false\""))
   }

   @Test("Contributor detail pages nest under Contributors, never in the flat Articles list")
   func contributorDetailNests() {
      let treeWithDetail: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Session A", url: "/documentation/wwdc25-1-a/"),
         ]),
         DocCNavNode(title: "Jeehut", url: "/documentation/contributors/jeehut/"),
         DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
      ]
      let renderer = DocCSidebarRenderer(contributors: [("Jeehut", 41)])
      let html = renderer.render(tree: treeWithDetail, currentSlug: "wwdc25")
      // The handle is reachable inside the Contributors subtree (built from `contributors`)…
      #expect(html.contains("sk-docc-contrib-subtree"))
      // …and the detail link appears exactly once – the loose `contributors/jeehut` node was
      // pulled OUT of Articles, so it is not duplicated as a flat row.
      #expect(self.count("href=\"/documentation/contributors/jeehut/\"", in: html) == 1)
      // Non-contributor loose pages are unaffected.
      #expect(html.contains("href=\"/documentation/contributing/\""))
   }

   @Test("Contributors index is not duplicated in Articles")
   func contributorsIndexNotDuplicated() {
      let treeWithIndex: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Session A", url: "/documentation/wwdc25-1-a/"),
         ]),
         DocCNavNode(title: "Contributors Overview", url: "/documentation/contributors/"),
      ]
      let renderer = DocCSidebarRenderer(contributors: [("Jeehut", 41)])
      let html = renderer.render(tree: treeWithIndex, currentSlug: "wwdc25")
      // The loose `contributors` index node is dropped (the top item represents it): its title
      // never appears and no Articles loose list is emitted for it.
      #expect(!html.contains("Contributors Overview"))
      #expect(!html.contains("sk-docc-nav-loose"))
      // The overview URL appears exactly twice inside the single Contributors top item – once
      // on the twist (now a real <a> so it navigates with no JS) and once on the row link –
      // never a third time as a duplicated Articles row.
      #expect(self.count("href=\"/documentation/contributors/\"", in: html) == 2)
   }

   @Test("Contributing and Missing Sessions stay in the Articles loose list")
   func articlesKeepNonContributorPages() {
      let treeWithArticles: [DocCNavNode] = [
         DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
            DocCNavNode(title: "Session A", url: "/documentation/wwdc25-1-a/"),
         ]),
         DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
         DocCNavNode(title: "Missing Sessions", url: "/documentation/missingnotes/"),
      ]
      let renderer = DocCSidebarRenderer(contributors: [("Jeehut", 41)])
      let html = renderer.render(tree: treeWithArticles, currentSlug: "wwdc25")
      #expect(html.contains("sk-docc-nav-loose"))
      // Both remain reachable as loose Articles links.
      let loosePart = html.components(separatedBy: "sk-docc-nav-loose").last ?? ""
      #expect(loosePart.contains("href=\"/documentation/contributing/\""))
      #expect(loosePart.contains("href=\"/documentation/missingnotes/\""))
   }

   @Test("Contributors glyph is a real icon, not the empty placeholder circle")
   func contributorsGlyphIsRealIcon() {
      let html = DocCSidebarRenderer(contributors: [("Jeehut", 41)]).render(tree: self.tree, currentSlug: "wwdc25")
      // The default Contributors glyph is a real FA icon on the shared top-glyph tile.
      #expect(html.contains("<i class=\"fa-solid fa-users\""))
      #expect(html.contains("sk-docc-nav-top-glyph sk-docc-nav-contrib-glyph"))
      // The old empty-span placeholder must be gone.
      #expect(!html.contains("sk-docc-nav-contrib-glyph\" aria-hidden=\"true\"></span>"))
   }

   @Test("Custom contributorsGlyph overrides the default users icon")
   func contributorsGlyphOverride() {
      let renderer = DocCSidebarRenderer(contributorsGlyph: "fa-solid fa-user-group", contributors: [("Jeehut", 41)])
      let html = renderer.render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("<i class=\"fa-solid fa-user-group\""))
      #expect(!html.contains("fa-solid fa-users\""))
   }

   @Test("Contributor avatars are sized 20px with a 40px retina source")
   func avatarsSized20() {
      let html = DocCSidebarRenderer(contributors: [("Jeehut", 41)]).render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains("class=\"sk-docc-nav-avatar\""))
      #expect(html.contains("width=\"20\" height=\"20\""))
      #expect(html.contains("?size=40"))
      // The old 15px footprint is gone.
      #expect(!html.contains("width=\"15\" height=\"15\""))
   }

   @Test("All contributors shown when uncapped; an explicit positive cap is still honored")
   func contributorsCapOptional() {
      let contribs: [(handle: String, noteCount: Int)] = [("Jeehut", 41), ("MarinRos", 28), ("DiegoVeg", 15)]
      // Default (nil) = no cap: every contributor is nested.
      let uncapped = DocCSidebarRenderer(contributors: contribs).render(tree: self.tree, currentSlug: "wwdc25")
      #expect(uncapped.contains("Jeehut"))
      #expect(uncapped.contains("MarinRos"))
      #expect(uncapped.contains("DiegoVeg"))
      // A positive limit still caps the nested list.
      let capped = DocCSidebarRenderer(contributorsLimit: 2, contributors: contribs).render(tree: self.tree, currentSlug: "wwdc25")
      #expect(capped.contains("Jeehut"))
      #expect(capped.contains("MarinRos"))
      #expect(!capped.contains("DiegoVeg"))
   }

   @Test("Every top <li> carries the sk-docc-nav-top marker class")
   func topMarkerOnEveryTopItem() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // Active year, non-active year, and Contributors all carry sk-docc-nav-top.
      #expect(html.contains("class=\"sk-docc-nav-item sk-docc-nav-top sk-docc-nav-expanded\""))
      #expect(html.contains("class=\"sk-docc-nav-item sk-docc-nav-top\""))
      #expect(html.contains("class=\"sk-docc-nav-item sk-docc-nav-top sk-docc-nav-contrib-group\""))
      // One data-docc-branch per top item: 2 years + Contributors = 3.
      #expect(self.count("data-docc-branch=\"", in: html) == 3)
   }

   @Test("A non-active year subtree is emitted empty + marked for lazy-hydration")
   func nonActiveSubtreeIsEmpty() {
      // wwdc25 is active (open, holds its session); wwdc24 is non-active.
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // The non-active subtree's opening tag is immediately closed: zero rows inside. The
      // hydration marker sits before `data-docc-branch-sessions`, so that attribute stays
      // directly adjacent to `hidden` (the empty-subtree contract docc-sidebar.js keys on).
      #expect(html.contains("data-docc-branch-sessions=\"wwdc24\" hidden></ul>"))
      // Phase 2: the non-active subtree carries `data-docc-unhydrated="wwdc24"` so the twist
      // fetches docc-sidebar-nav.json and fills the rows on first open instead of navigating.
      #expect(html.contains("data-docc-unhydrated=\"wwdc24\""))
      // The active year is already populated, so it is NOT marked for hydration…
      #expect(!html.contains("data-docc-unhydrated=\"wwdc25\""))
      // …and the Contributors subtree is always server-rendered, so it never gets the marker.
      #expect(!html.contains("data-docc-unhydrated=\"contrib\""))
      // Sanity: the active subtree is NOT empty (its session is in the DOM) and not hidden.
      #expect(html.contains("Session A"))
      #expect(!html.contains("data-docc-branch-sessions=\"wwdc25\" hidden"))
   }

   // MARK: - Twist is a real link (no-JS navigate)

   @Test("A non-active year twist is an <a> linking to that year's overview (navigates with no JS)")
   func nonActiveYearTwistIsLink() {
      // wwdc25 is active, so wwdc24 is the non-active year under test.
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // The twist is a real link to the year overview – same href as the adjacent row link –
      // so with JS disabled the chevron natively navigates instead of being a dead control.
      // aria-controls + aria-expanded stay present (ARIA-valid on a link).
      #expect(html.contains(
         "<a class=\"sk-docc-nav-twist sk-docc-nav-twist-btn\""
            + " data-docc-subtree-toggle aria-controls=\"sk-docc-subtree-wwdc24\""
            + " aria-expanded=\"false\" aria-label=\"WWDC24\""
            + " href=\"/documentation/wwdc24/\">"
      ))
      // The twist must no longer be a <button> – that was the inert no-JS control.
      #expect(!html.contains("<button type=\"button\" class=\"sk-docc-nav-twist"))
   }

   @Test("The twist href matches the adjacent year row link (one shared navigation target)")
   func twistSharesRowLinkHref() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // Both the twist and the year-name row link point at the exact same overview URL.
      #expect(html.contains("class=\"sk-docc-nav-twist sk-docc-nav-twist-btn\" data-docc-subtree-toggle aria-controls=\"sk-docc-subtree-wwdc24\" aria-expanded=\"false\" aria-label=\"WWDC24\" href=\"/documentation/wwdc24/\""))
      #expect(html.contains("class=\"sk-docc-nav-link sk-docc-nav-year\" href=\"/documentation/wwdc24/\""))
   }

   @Test("The active year twist is also a link (uniform conversion) pointing at its own overview")
   func activeYearTwistIsLink() {
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      // For consistency every year twist is a link; the active one carries aria-expanded="true"
      // and links to its own overview.
      #expect(html.contains(
         "<a class=\"sk-docc-nav-twist sk-docc-nav-twist-btn\""
            + " data-docc-subtree-toggle aria-controls=\"sk-docc-subtree-wwdc25\""
            + " aria-expanded=\"true\" aria-label=\"WWDC25\""
            + " href=\"/documentation/wwdc25/\">"
      ))
   }

   @Test("The Contributors twist is a link to the contributors overview (no-JS navigate)")
   func contributorsTwistIsLink() {
      // The contributors overview page genuinely exists (DocCContributorsPage renders
      // /documentation/contributors/ whenever a contributor handle is present – the same
      // condition that makes this top item appear), so its twist is a real link too.
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "wwdc25")
      #expect(html.contains(
         "<a class=\"sk-docc-nav-twist sk-docc-nav-twist-btn\""
            + " data-docc-subtree-toggle aria-controls=\"sk-docc-contrib-subtree\""
            + " aria-expanded=\"false\" aria-label=\"Contributors\""
            + " href=\"/documentation/contributors/\">"
      ))
   }

   @Test("The Contributors branch is server-rendered open on a contributor detail page")
   func contributorsOpenOnDetailPage() {
      // On a contributors/<handle> detail page the Contributors branch must be open (no
      // `hidden`, twist aria-expanded="true") so the active row is visible with no JS.
      let html = self.unifiedRenderer().render(tree: self.tree, currentSlug: "contributors/jeehut")
      #expect(html.contains("aria-controls=\"sk-docc-contrib-subtree\" aria-expanded=\"true\""))
      // The contrib subtree is open: its branch marker is not followed by `hidden`.
      #expect(html.contains("data-docc-branch-sessions=\"contrib\">"))
      #expect(!html.contains("data-docc-branch-sessions=\"contrib\" hidden"))
      // Contributors is fully server-rendered, so it never carries the lazy-hydration marker
      // (only non-active YEAR subtrees do – here both years are non-active and get it).
      #expect(!html.contains("data-docc-unhydrated=\"contrib\""))
      #expect(html.contains("data-docc-unhydrated=\"wwdc25\""))
      // The active contributor row is marked current, and the top link gains contrib-active.
      #expect(html.contains("aria-current=\"page\" href=\"/documentation/contributors/jeehut/\""))
      #expect(html.contains("sk-docc-nav-contrib-active"))
   }

   @Test("A neutral (non-WWDC) tree emits no WWDCNotes-specific literal")
   func genericOutputNoWWDCLiteral() {
      let neutralTree: [DocCNavNode] = [
         DocCNavNode(title: "Guides", url: "/documentation/guides/", children: [
            DocCNavNode(title: "Intro", url: "/documentation/guides-intro/"),
         ]),
         DocCNavNode(title: "Reference", url: "/documentation/reference/"),
      ]
      let html = DocCSidebarRenderer().render(tree: neutralTree, currentSlug: "guides-intro")
      // The renderer must wire in nothing WWDCNotes-specific; only data-driven titles appear.
      #expect(!html.contains("WWDC"))
      #expect(!html.lowercased().contains("wwdcnotes"))
   }

   // MARK: - #101: Hidden framework-icon legend (lazy-hydrate / cross-year-filter clone source)

   /// A registry with two frameworks, used by the legend tests below.
   private let legendIcons: [String: DocCFrameworkIcon] = [
      "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      "metal": DocCFrameworkIcon(glyph: "fa-solid fa-bolt", colors: ["#9c27b0", "#673ab7"]),
   ]

   /// A two-year tree where `swiftui` lives only in the (active) WWDC25 branch and `metal` lives
   /// only in the (non-active) WWDC24 branch – the exact split the legend has to cover.
   private let legendTree: [DocCNavNode] = [
      DocCNavNode(title: "WWDC25", url: "/documentation/wwdc25/", children: [
         DocCNavNode(title: "SwiftUI Talk", url: "/documentation/wwdc25-swiftui/", framework: "swiftui"),
      ]),
      DocCNavNode(title: "WWDC24", url: "/documentation/wwdc24/", children: [
         DocCNavNode(title: "Metal Talk", url: "/documentation/wwdc24-metal/", framework: "metal"),
      ]),
   ]

   @Test("A hidden, aria-hidden legend carries an icon for every framework in the tree, including non-active years")
   func iconLegendCoversCrossYearFrameworks() {
      // The reader is on a WWDC25 page, so only WWDC25's sessions are server-rendered. `metal`
      // appears only in the non-active WWDC24 branch – without the legend a row hydrated for it
      // (lazy-hydrate or a cross-year filter match) would have no same-framework icon to clone.
      let html = DocCSidebarRenderer(frameworkIcons: self.legendIcons).render(tree: self.legendTree, currentSlug: "wwdc25-swiftui")
      // The legend exists, is hidden, and is aria-hidden so it never reaches the a11y tree or layout.
      #expect(html.contains("<div class=\"sk-docc-nav-icon-legend\" hidden aria-hidden=\"true\">"))
      // It carries a clone source for the cross-year framework (the red-green seam: comment out the
      // legend emission in `render` and this fails, because no `metal` row is in the DOM here).
      #expect(html.contains("data-framework=\"metal\""))
      #expect(html.contains("fa-solid fa-bolt"))
      // ...and for the active framework too, so every registry-backed framework has a clone source.
      #expect(html.contains("data-framework=\"swiftui\""))
   }

   @Test("Each legend icon is byte-identical to the icon the matching session row renders")
   func iconLegendIconMatchesServerRow() {
      let html = DocCSidebarRenderer(frameworkIcons: self.legendIcons).render(tree: self.legendTree, currentSlug: "wwdc25-swiftui")
      // The legend reuses `sessionIconHTML`, so the cloned icon is byte-for-byte the server-rendered
      // one – a hydrated/filtered cross-year row then looks identical to a server-rendered row.
      let swiftUIIcon = "<span class=\"sk-docc-nav-icon sk-docc-nav-fw-icon\" data-framework=\"swiftui\" aria-hidden=\"true\"><i class=\"fa-solid fa-layer-group\" aria-hidden=\"true\"></i></span>"
      let metalIcon = "<span class=\"sk-docc-nav-icon sk-docc-nav-fw-icon\" data-framework=\"metal\" aria-hidden=\"true\"><i class=\"fa-solid fa-bolt\" aria-hidden=\"true\"></i></span>"
      // The active framework's icon appears in BOTH the server-rendered row and the legend (the
      // duplicate is harmless – the JS keeps the first clone source it sees).
      #expect(self.count(swiftUIIcon, in: html) == 2)
      // The cross-year framework's icon appears only in the legend (no metal row is in the DOM).
      #expect(self.count(metalIcon, in: html) == 1)
   }

   @Test("The icon legend is purely additive: appended after the filter box, active rows untouched")
   func iconLegendIsPurelyAdditive() {
      let html = DocCSidebarRenderer(frameworkIcons: self.legendIcons).render(tree: self.legendTree, currentSlug: "wwdc25-swiftui")
      // The legend sits AFTER the bottom filter box, so the whole tree above it is unchanged.
      let filterIdx = html.range(of: "<div class=\"sk-docc-filter\">")!
      let legendIdx = html.range(of: "<div class=\"sk-docc-nav-icon-legend\"")!
      #expect(filterIdx.lowerBound < legendIdx.lowerBound)
      // Everything before the legend (the entire pre-change output) still carries the active-year
      // session row exactly as the renderer emits it – the legend rewrote nothing.
      let beforeLegend = String(html[html.startIndex..<legendIdx.lowerBound])
      #expect(!beforeLegend.contains("sk-docc-nav-icon-legend"))
      #expect(beforeLegend.contains(
         "<li class=\"sk-docc-nav-session\"><a class=\"sk-docc-nav-link\" href=\"/documentation/wwdc25-swiftui/\" aria-current=\"page\">"
            + "<span class=\"sk-docc-nav-icon sk-docc-nav-fw-icon\" data-framework=\"swiftui\" aria-hidden=\"true\"><i class=\"fa-solid fa-layer-group\" aria-hidden=\"true\"></i></span>"
            + "<span class=\"sk-docc-nav-text\">SwiftUI Talk</span></a></li>"
      ))
      // The non-active WWDC24 branch is still an empty, hidden, unhydrated placeholder above the
      // legend – the legend did not pull its rows into the DOM.
      #expect(beforeLegend.contains("data-docc-unhydrated=\"wwdc24\""))
      #expect(!beforeLegend.contains("Metal Talk"))
   }

   @Test("A framework with no registry entry is left out of the legend (it keeps the neutral placeholder)")
   func iconLegendOmitsUnregisteredFrameworks() {
      // Registry knows only `swiftui`; `metal` has no glyph, so it would hydrate to the neutral
      // placeholder with or without a legend entry – legending it would add a useless clone source.
      let icons: [String: DocCFrameworkIcon] = [
         "swiftui": DocCFrameworkIcon(glyph: "fa-solid fa-layer-group", colors: ["#1e88e5"]),
      ]
      let html = DocCSidebarRenderer(frameworkIcons: icons).render(tree: self.legendTree, currentSlug: "wwdc25-swiftui")
      #expect(html.contains("<div class=\"sk-docc-nav-icon-legend\""))
      #expect(html.contains("data-framework=\"swiftui\""))
      // `metal` has no registry glyph, so it never appears – not in a row (non-active) and not in
      // the legend.
      #expect(!html.contains("data-framework=\"metal\""))
   }

   @Test("No legend is emitted when there is no framework registry")
   func iconLegendAbsentWithoutRegistry() {
      // With no registry the tree has no framework glyphs at all, so there is nothing to legend –
      // the neutral-placeholder behavior (and its tests) stay exactly as before.
      let html = DocCSidebarRenderer().render(tree: self.legendTree, currentSlug: "wwdc25-swiftui")
      #expect(!html.contains("sk-docc-nav-icon-legend"))
      #expect(!html.contains("sk-docc-nav-fw-icon"))
   }

   // MARK: - Guide icons (loose-item glyphs)

   /// A loose-only tree (two guide pages, no years, no contributors), so the only icon spans in
   /// the output are the guide chips – which lets the default-fallback test assert that no empty
   /// `sk-docc-nav-icon` placeholder span survives anywhere.
   private let guideTree: [DocCNavNode] = [
      DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
      DocCNavNode(title: "Missing Sessions", url: "/documentation/missingnotes/"),
   ]

   @Test("A loose guide item with a configured icon renders that FA glyph on the guide chip")
   func guideIconConfiguredRendersGlyph() {
      let renderer = DocCSidebarRenderer(guideIcons: [
         "contributing": "fa-solid fa-pen-to-square",
         "missingnotes": "fa-solid fa-list-check",
      ])
      let html = renderer.render(tree: self.guideTree, currentSlug: "contributing")
      // Each loose item carries the guide chip with its slug's configured glyph.
      #expect(html.contains("sk-docc-nav-icon sk-docc-nav-guide-icon"))
      #expect(html.contains("<i class=\"fa-solid fa-pen-to-square\" aria-hidden=\"true\">"))
      #expect(html.contains("<i class=\"fa-solid fa-list-check\" aria-hidden=\"true\">"))
      // Both slugs are configured, so the generic default glyph is not used.
      #expect(!html.contains("fa-file-lines"))
   }

   @Test("A loose guide item with NO configured icon renders the default glyph, not an empty placeholder")
   func guideIconDefaultFallback() {
      // No guideIcons registry at all – the core of the fix: a fresh docs site still shows real glyphs.
      let html = DocCSidebarRenderer().render(tree: self.guideTree, currentSlug: "contributing")
      // Every loose item gets the shared default guide glyph on the guide chip…
      #expect(html.contains("sk-docc-nav-guide-icon"))
      #expect(html.contains("<i class=\"fa-solid fa-file-lines\" aria-hidden=\"true\">"))
      // …and the old empty icon-slot placeholder span is gone. The guideTree has no session rows
      // or year placeholders, so that empty signature must not appear anywhere in the output.
      #expect(!html.contains("<span class=\"sk-docc-nav-icon\" aria-hidden=\"true\"></span>"))
   }

   @Test("An unconfigured slug falls back to the default even when other slugs are configured")
   func guideIconPartialConfigFallsBack() {
      // Only "contributing" is configured; "missingnotes" must still get a real (default) glyph.
      let renderer = DocCSidebarRenderer(guideIcons: ["contributing": "fa-solid fa-pen-to-square"])
      let html = renderer.render(tree: self.guideTree, currentSlug: "contributing")
      #expect(html.contains("<i class=\"fa-solid fa-pen-to-square\" aria-hidden=\"true\">"))
      #expect(html.contains("<i class=\"fa-solid fa-file-lines\" aria-hidden=\"true\">"))
   }

   @Test("Curated group (Guides) items also carry real guide glyphs, never the empty placeholder")
   func guideIconOnCuratedGroupItems() {
      let tree: [DocCNavNode] = [
         DocCNavNode(title: "Guides", url: "", children: [
            DocCNavNode(title: "Contributing", url: "/documentation/contributing/"),
            DocCNavNode(title: "How AI Notes Work", url: "/documentation/aipipeline/"),
         ], isGroup: true),
      ]
      let renderer = DocCSidebarRenderer(guideIcons: ["aipipeline": "fa-solid fa-robot"])
      let html = renderer.render(tree: tree, currentSlug: "aipipeline")
      // The curated group renders as its own section, and its children carry guide chips.
      #expect(html.contains("<p class=\"sk-docc-nav-section\">Guides</p>"))
      #expect(html.contains("<i class=\"fa-solid fa-robot\" aria-hidden=\"true\">"))
      // The unconfigured child still gets the default glyph, never the empty placeholder.
      #expect(html.contains("<i class=\"fa-solid fa-file-lines\" aria-hidden=\"true\">"))
      #expect(!html.contains("<span class=\"sk-docc-nav-icon\" aria-hidden=\"true\"></span>"))
   }

   @Test("make(from:) wires docc.guideIcons through to the loose-item glyphs")
   func makeWiresGuideIcons() {
      let section = SectionConfig(name: "Docs", slug: "docs", contentDirectory: "Docs", urlPrefix: "documentation")
      let context = BuildContext(
         config: SiteConfig(
            name: "Docs",
            baseURL: "https://example.com",
            sections: [section],
            docc: DocCConfig(guideIcons: ["contributing": "fa-solid fa-pen-to-square"])
         ),
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: [])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
      let html = DocCSidebarRenderer.make(from: context).render(tree: self.guideTree, currentSlug: "contributing")
      // The configured slug flows from docc config to its loose-item glyph…
      #expect(html.contains("<i class=\"fa-solid fa-pen-to-square\" aria-hidden=\"true\">"))
      // …and the unconfigured loose item still gets the default, never empty.
      #expect(html.contains("<i class=\"fa-solid fa-file-lines\" aria-hidden=\"true\">"))
   }
}
