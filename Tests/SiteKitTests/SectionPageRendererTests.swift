import Foundation
import Testing
@testable import SiteKit

@Suite("SectionPageRenderer")
struct SectionPageRendererTests {
   // MARK: - Helpers

   private func makeContext(sections: [ContentSection]) -> BuildContext {
      let config = SiteConfig(name: "Test", baseURL: "https://example.com")
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: sections,
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: URL(fileURLWithPath: "/tmp/_Site"),
         projectDirectory: URL(fileURLWithPath: "/tmp")
      )
   }

   private func makePage(slug: String, title: String) -> PageModel {
      PageModel(
         title: title,
         date: Date(timeIntervalSince1970: 1_700_000_000),
         slug: slug,
         htmlContent: "<p>Body</p>",
         sourcePath: URL(fileURLWithPath: "/tmp/Content/\(slug).md")
      )
   }

   // MARK: - Slug-collision disambiguation

   @Test("pages(in:) stamps each flattened page with its owning section slug")
   func pagesInStampsSectionSlug() {
      let blog = ContentSection(
         config: SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog"),
         pages: [self.makePage(slug: "intro", title: "Blog Intro")]
      )
      let notes = ContentSection(
         config: SectionConfig(name: "Notes", slug: "notes", contentDirectory: "Notes", urlPrefix: "notes"),
         pages: [self.makePage(slug: "intro", title: "Notes Intro")]
      )
      let context = self.makeContext(sections: [blog, notes])

      let renderer = SectionPageRenderer()
      let pages = renderer.pages(in: context)

      #expect(pages.count == 2)
      let blogPage = pages.first { $0.title == "Blog Intro" }
      let notesPage = pages.first { $0.title == "Notes Intro" }
      #expect(blogPage?.extensionValue("sectionSlug") == "blog")
      #expect(notesPage?.extensionValue("sectionSlug") == "notes")
   }

   @Test("outputURL routes slug-colliding pages to their respective sections")
   func outputURLDisambiguatesSlugCollision() {
      let blog = ContentSection(
         config: SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog"),
         pages: [self.makePage(slug: "intro", title: "Blog Intro")]
      )
      let notes = ContentSection(
         config: SectionConfig(name: "Notes", slug: "notes", contentDirectory: "Notes", urlPrefix: "notes"),
         pages: [self.makePage(slug: "intro", title: "Notes Intro")]
      )
      let context = self.makeContext(sections: [blog, notes])

      let renderer = SectionPageRenderer()
      let flattened = renderer.pages(in: context)
      let blogStamped = flattened.first { $0.title == "Blog Intro" }!
      let notesStamped = flattened.first { $0.title == "Notes Intro" }!

      // Without the section stamp, both URLs would resolve to /blog/intro/
      // because `locate` returned the first matching section. With the stamp
      // each goes to its real section.
      let blogURL = renderer.outputURL(for: blogStamped, context: context)
      let notesURL = renderer.outputURL(for: notesStamped, context: context)
      #expect(blogURL.path.contains("/blog/intro/"))
      #expect(notesURL.path.contains("/notes/intro/"))
      #expect(!notesURL.path.contains("/blog/intro/"))
   }

   @Test("Legacy slug-only path keeps working for unstamped PageModels")
   func legacyUnstampedPageFallsBackToSlugSearch() {
      let blog = ContentSection(
         config: SectionConfig(name: "Blog", slug: "blog", contentDirectory: "Blog", urlPrefix: "blog"),
         pages: [self.makePage(slug: "intro", title: "Blog Intro")]
      )
      let context = self.makeContext(sections: [blog])

      // A page passed in WITHOUT the section stamp (e.g. constructed by a
      // custom caller) still resolves via the legacy slug-only search.
      let unstamped = self.makePage(slug: "intro", title: "Blog Intro")
      let renderer = SectionPageRenderer()
      let url = renderer.outputURL(for: unstamped, context: context)
      #expect(url.path.contains("/blog/intro/"))
   }
}
