import Foundation
import Testing
@testable import PreviewGeneratorKit

@Suite("ComparisonIndex")
struct ComparisonIndexTests {
   private let classicLight = PreviewVariant(
      layoutTemplate: "Classic",
      colorScheme: "indigo",
      fontPairing: "editorial",
      mode: .light
   )
   private let sidebarDark = PreviewVariant(
      layoutTemplate: "Sidebar",
      colorScheme: "slate",
      fontPairing: "modern",
      mode: .dark
   )
   private let homeRoute = PreviewRoute(id: "home", label: "Home", sourcePath: "index.html")
   private let articleRoute = PreviewRoute(
      id: "article",
      label: "Article",
      sourcePath: "blog/sample/index.html"
   )

   @Test("Grid tile carries the per-variant href and label")
   func gridTileShape() {
      let tile = ComparisonIndex.gridTile(for: self.classicLight, route: self.articleRoute)
      #expect(tile.contains("preview/Classic-indigo-editorial-light-article.html"))
      #expect(tile.contains("Article"))
      #expect(tile.contains("colorScheme: indigo"))
      #expect(tile.contains("fontPairing: editorial"))
      #expect(tile.contains("light"))
   }

   @Test("Grid tile encodes the variant's mode in title and params")
   func gridTileEncodesMode() {
      let tile = ComparisonIndex.gridTile(for: self.sidebarDark, route: self.homeRoute)
      #expect(tile.contains("dark"))
      #expect(tile.contains("Sidebar – Home"))
   }

   @Test("HTML document includes h2 per template in first-appearance order")
   func documentGroupsByTemplate() {
      let variants = [self.sidebarDark, self.classicLight]
      let html = ComparisonIndex.html(variants: variants, routes: [self.homeRoute])
      let sidebarPos = html.range(of: "<h2>Sidebar</h2>")?.lowerBound
      let classicPos = html.range(of: "<h2>Classic</h2>")?.lowerBound
      #expect(sidebarPos != nil)
      #expect(classicPos != nil)
      if let sidebarPos, let classicPos {
         #expect(sidebarPos < classicPos)
      }
   }

   @Test("Document includes one tile per variant × route pairing")
   func tileCountEqualsCrossProduct() {
      let variants = [self.classicLight, self.sidebarDark]
      let routes = [self.homeRoute, self.articleRoute]
      let html = ComparisonIndex.html(variants: variants, routes: routes)
      let tileCount = html.components(separatedBy: "<div class=\"preview-card\">").count - 1
      #expect(tileCount == variants.count * routes.count)
   }

   @Test("Unknown templates fall through in first-appearance order – no hard-coded allow-list")
   func unknownTemplatesFallThrough() {
      let futureVariant = PreviewVariant(
         layoutTemplate: "Magazine",
         colorScheme: "warm",
         fontPairing: "editorial",
         mode: .light
      )
      let variants = [self.classicLight, futureVariant]
      let html = ComparisonIndex.html(variants: variants, routes: [self.homeRoute])
      #expect(html.contains("<h2>Classic</h2>"))
      #expect(html.contains("<h2>Magazine</h2>"))
   }
}
