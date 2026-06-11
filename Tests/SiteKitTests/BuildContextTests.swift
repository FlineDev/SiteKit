import Foundation
import Testing
@testable import SiteKit

@Suite("BuildContext")
struct BuildContextTests {
   private func makeConfig(sections: [SectionConfig]) -> SiteConfig {
      SiteConfig(
         name: "Test",
         baseURL: "https://example.com",
         sections: sections
      )
   }

   private var tempDir: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }

   @Test("Construction with custom section slug exposes that section verbatim")
   func customSectionSlug() {
      let section = SectionConfig(
         name: "Learning Paths",
         slug: "learning-paths",
         contentDirectory: "LearningPaths",
         urlPrefix: "learning-paths"
      )
      let config = self.makeConfig(sections: [section])

      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: [])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: self.tempDir,
         projectDirectory: self.tempDir
      )

      #expect(context.sections.count == 1)
      #expect(context.sections.first?.config.slug == "learning-paths")
      #expect(context.sections.first?.config.contentDirectory == "LearningPaths")
   }

   @Test("articles convenience accessor falls back to first section when no 'blog' slug is configured")
   func articlesFallsBackToFirstSection() {
      let section = SectionConfig(
         name: "Articles",
         slug: "articles",
         contentDirectory: "Articles",
         urlPrefix: "articles"
      )
      let page = PageModel(
         id: "p1",
         title: "Hello",
         slug: "hello",
         htmlContent: "",
         sourcePath: URL(fileURLWithPath: "/tmp/hello.md")
      )
      let config = self.makeConfig(sections: [section])

      let context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [ContentSection(config: section, pages: [page])],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: self.tempDir,
         projectDirectory: self.tempDir
      )

      #expect(context.articles.count == 1)
      #expect(context.articles.first?.slug == "hello")
   }
}
