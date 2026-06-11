import Foundation
import Testing

@testable import SiteKit

@Suite("DocCNavigationTree")
struct DocCNavigationTreeTests {
   private func page(_ slug: String, _ title: String) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md")
      )
   }

   @Test("Groups sessions under years, newest year first, with overview titles")
   func buildsTwoLevelTree() {
      let pages = [
         self.page("wwdc24", "WWDC24"),
         self.page("wwdc24-10061-whats-new", "What's New"),
         self.page("wwdc24-10060-meet-x", "Meet X"),
         self.page("wwdc23", "WWDC23"),
         self.page("wwdc23-100-a-session", "A Session"),
         self.page("contributing", "Contributing"),
      ]

      let tree = DocCNavigationTree.build(from: pages, urlPrefix: "documentation")

      // Years newest-first, then loose pages.
      #expect(tree.map(\.title) == ["WWDC24", "WWDC23", "Contributing"])

      // WWDC24 has two sessions, slug-sorted, with resolved URLs.
      let wwdc24 = tree[0]
      #expect(wwdc24.url == "/documentation/wwdc24/")
      #expect(wwdc24.children.map(\.title) == ["Meet X", "What's New"])
      #expect(wwdc24.children[0].url == "/documentation/wwdc24-10060-meet-x/")

      // Loose page is a top-level leaf.
      #expect(tree[2].children.isEmpty)
      #expect(tree[2].url == "/documentation/contributing/")
   }

   @Test("Synthesizes a year node even without an overview page")
   func yearWithoutOverview() {
      let tree = DocCNavigationTree.build(
         from: [self.page("wwdc22-1-x", "X")],
         urlPrefix: "documentation"
      )
      #expect(tree.count == 1)
      #expect(tree[0].title == "WWDC22")
      #expect(tree[0].children.map(\.title) == ["X"])
   }

   @Test("yearKey extracts the wwdc<year> prefix")
   func yearKeyExtraction() {
      #expect(DocCNavigationTree.yearKey(of: "wwdc24-10132-foo") == "wwdc24")
      #expect(DocCNavigationTree.yearKey(of: "wwdc24") == "wwdc24")
      #expect(DocCNavigationTree.yearKey(of: "contributing") == nil)
   }

   // MARK: - Contributor profile exclusion + ## Topics curation

   private func profilePage(_ slug: String, _ title: String) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/Contributors/\(slug).md"),
         extensions: ["doccContributorProfile": true]
      )
   }

   private func pageWithGroups(_ slug: String, _ title: String, _ groups: [DocCTopicGroup]) -> PageModel {
      PageModel(
         title: title,
         slug: slug,
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/\(slug).md"),
         extensions: ["doccTopicGroups": groups]
      )
   }

   @Test("Contributor profile notes never appear as flat article leaves")
   func excludesContributorProfiles() {
      let tree = DocCNavigationTree.build(
         from: [
            self.page("wwdc24", "WWDC24"),
            self.page("wwdc24-100-a", "A Session"),
            self.profilePage("jeehut", "Cihat Gündüz (1 note)"),
            self.profilePage("dasalexq", "Alexander Käßner (1 note)"),
         ],
         urlPrefix: "documentation"
      )
      // Only the year node remains at the top level – no per-contributor leaves.
      #expect(tree.map(\.title) == ["WWDC24"])
      #expect(!tree.contains { $0.title.contains("Gündüz") })
      #expect(!tree.contains { $0.url.hasSuffix("/jeehut/") })
   }

   @Test("A loose page curated under a ## Topics group nests under a group node")
   func curatesLoosePagesIntoGroup() {
      let groups = [DocCTopicGroup(title: "Guides", slugs: ["gettingstarted", "reference"])]
      let tree = DocCNavigationTree.build(
         from: [
            self.page("wwdc24", "WWDC24"),
            self.page("wwdc24-100-a", "A Session"),
            self.page("gettingstarted", "Getting Started"),
            self.page("reference", "Reference"),
            self.page("contributing", "Contributing"),    // uncurated → stays flat
            self.pageWithGroups("index", "Index", groups), // the curation source
         ],
         urlPrefix: "documentation"
      )

      // The "Guides" group node carries the two curated guides as children, marked isGroup.
      let guides = tree.first { $0.isGroup && $0.title == "Guides" }
      #expect(guides != nil)
      #expect(guides?.url == "")
      #expect(guides?.children.map(\.title) == ["Getting Started", "Reference"])

      // Curated guides are no longer flat top-level leaves.
      #expect(!tree.contains { !$0.isGroup && $0.title == "Getting Started" })
      #expect(!tree.contains { !$0.isGroup && $0.title == "Reference" })
      // The genuinely uncurated loose page (Contributing) stays flat after the group.
      #expect(tree.contains { !$0.isGroup && $0.title == "Contributing" })
      // The curation source itself (the ## Topics index/root) is structural chrome, surfaced via
      // its group and the home page, so it is no longer a dangling flat leaf.
      #expect(!tree.contains { !$0.isGroup && $0.title == "Index" })
   }

   @Test("A curated ## Topics group keeps the declared slug order, not alphabetical")
   func curatedGroupKeepsDeclaredOrder() {
      // Declared order: Contributing → Missing Sessions → How AI Notes Work. Sorting the
      // group children by slug would surface them as aipipeline < contributing < missingnotes,
      // i.e. "How AI Notes Work" first – the exact inversion this guards against. The group must
      // honour the author's `## Topics` order instead.
      let groups = [DocCTopicGroup(title: "Guides", slugs: ["contributing", "missingnotes", "aipipeline"])]
      let tree = DocCNavigationTree.build(
         from: [
            self.page("contributing", "Contributing"),
            self.page("missingnotes", "Missing Sessions"),
            self.page("aipipeline", "How AI Notes Work"),
            self.pageWithGroups("index", "Index", groups), // the curation source
         ],
         urlPrefix: "documentation"
      )

      let guides = tree.first { $0.isGroup && $0.title == "Guides" }
      #expect(guides?.children.map(\.title) == ["Contributing", "Missing Sessions", "How AI Notes Work"])
   }

   @Test("The catalog-root curation source never dangles as a flat article leaf")
   func curationSourceIsNotAFlatLeaf() {
      // The catalog/module root page carries the `## Topics` curation that groups the loose
      // guides; it is structural, not an article, so it must not also appear as a flat leaf
      // (which is what surfaced the stray monospace `WWDCNotes` entry under Articles).
      let groups = [DocCTopicGroup(title: "Guides", slugs: ["contributing", "aipipeline"])]
      let tree = DocCNavigationTree.build(
         from: [
            self.page("wwdc25", "WWDC25"),
            self.page("wwdc25-100-a", "A Session"),
            self.page("contributing", "Contributing"),
            self.page("aipipeline", "How AI Notes Work"),
            self.pageWithGroups("wwdcnotes", "WWDCNotes", groups), // catalog root + curation source
         ],
         urlPrefix: "documentation"
      )

      // The root is grouped its own children but is not itself a leaf anywhere.
      #expect(!tree.contains { !$0.isGroup && $0.title == "WWDCNotes" })
      #expect(!tree.contains { $0.url == "/documentation/wwdcnotes/" })
      // Its curated children still surface under the Guides group.
      let guides = tree.first { $0.isGroup && $0.title == "Guides" }
      #expect(guides?.children.map(\.title) == ["Contributing", "How AI Notes Work"])
   }
}
