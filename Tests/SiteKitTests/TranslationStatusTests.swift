import Foundation
import Testing
@testable import SiteKit

@Suite("TranslationStatus")
struct TranslationStatusTests {
   private func makeTempDir() -> URL {
      let dir = URL(fileURLWithPath: NSTemporaryDirectory())
         .appendingPathComponent("SiteKitTranslationStatusTests-\(UUID().uuidString)")
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      return dir
   }

   private func write(_ contents: String, to url: URL) throws {
      try FileManager.default.createDirectory(
         at: url.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
      try contents.write(to: url, atomically: true, encoding: .utf8)
   }

   @Test("Reports missing translations for arbitrary section content directories")
   func reportsForCustomSection() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      // Section "Learning Paths" with one default-language file and no German translation.
      try self.write("# Lesson 1\n", to: root.appendingPathComponent("LearningPaths/lesson-1.md"))

      let section = SectionConfig(
         name: "Learning Paths",
         slug: "learning-paths",
         contentDirectory: "LearningPaths",
         urlPrefix: "learning-paths"
      )

      let discovery = LocalizedContentDiscovery(defaultLanguage: "en", additionalLanguages: ["de"])
      let missing = TranslationStatus.check(
         contentDirectory: root,
         defaultLanguage: "en",
         targetLanguages: ["de"],
         localizedDiscovery: discovery,
         sections: [section],
         staticPagesDirectory: nil
      )

      #expect(missing.contains(where: { $0.expectedFile == "lesson-1.de.md" && $0.locale == "de" }))
   }

   @Test("Skips sections whose content directory does not exist")
   func skipsAbsentSectionDirectory() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      let section = SectionConfig(
         name: "Articles",
         slug: "articles",
         contentDirectory: "Articles",
         urlPrefix: "articles"
      )

      let discovery = LocalizedContentDiscovery(defaultLanguage: "en", additionalLanguages: ["de"])
      let missing = TranslationStatus.check(
         contentDirectory: root,
         defaultLanguage: "en",
         targetLanguages: ["de"],
         localizedDiscovery: discovery,
         sections: [section],
         staticPagesDirectory: nil
      )

      #expect(missing.isEmpty)
   }

   @Test("Static-pages directory is checked when provided")
   func staticPagesChecked() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      try self.write("# About\n", to: root.appendingPathComponent("Pages/about.md"))

      let discovery = LocalizedContentDiscovery(defaultLanguage: "en", additionalLanguages: ["de"])
      let missing = TranslationStatus.check(
         contentDirectory: root,
         defaultLanguage: "en",
         targetLanguages: ["de"],
         localizedDiscovery: discovery,
         sections: [],
         staticPagesDirectory: "Pages"
      )

      #expect(missing.contains(where: { $0.expectedFile == "about.de.md" }))
   }

   @Test("Does not double-scan when a section already targets the static-pages directory")
   func deduplicatesStaticPagesAndSection() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      try self.write("# About\n", to: root.appendingPathComponent("Pages/about.md"))

      let pagesSection = SectionConfig(
         name: "Pages",
         slug: "pages",
         contentDirectory: "Pages",
         urlPrefix: ""
      )

      let discovery = LocalizedContentDiscovery(defaultLanguage: "en", additionalLanguages: ["de"])
      let missing = TranslationStatus.check(
         contentDirectory: root,
         defaultLanguage: "en",
         targetLanguages: ["de"],
         localizedDiscovery: discovery,
         sections: [pagesSection],
         staticPagesDirectory: "Pages"
      )

      let aboutHits = missing.filter { $0.expectedFile == "about.de.md" }
      #expect(aboutHits.count == 1)
   }

   @Test("Returns empty when no target languages are configured")
   func emptyWhenSingleLanguage() throws {
      let root = self.makeTempDir()
      defer { try? FileManager.default.removeItem(at: root) }

      try self.write("# Lesson 1\n", to: root.appendingPathComponent("Blog/lesson-1.md"))

      let blogSection = SectionConfig(
         name: "Blog",
         slug: "blog",
         contentDirectory: "Blog",
         urlPrefix: "blog"
      )

      let discovery = LocalizedContentDiscovery(defaultLanguage: "en", additionalLanguages: [])
      let missing = TranslationStatus.check(
         contentDirectory: root,
         defaultLanguage: "en",
         targetLanguages: [],
         localizedDiscovery: discovery,
         sections: [blogSection],
         staticPagesDirectory: nil
      )

      #expect(missing.isEmpty)
   }
}
