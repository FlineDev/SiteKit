import Foundation
import Testing
@testable import PreviewGeneratorKit

@Suite("PreviewRoute")
struct RouteTests {
   private let variant = PreviewVariant(
      layoutTemplate: "Classic",
      colorScheme: "indigo",
      fontPairing: "editorial",
      mode: .light
   )

   @Test("Home route keeps the bare <variant>.html legacy filename")
   func homeRouteUsesBareFilename() {
      let route = PreviewRoute(id: "home", label: "Home", sourcePath: "index.html")
      #expect(route.outputFilename(for: self.variant) == "Classic-indigo-editorial-light.html")
   }

   @Test("Non-home routes append a hyphenated suffix")
   func nonHomeRouteAppendsSuffix() {
      let route = PreviewRoute(
         id: "article",
         label: "Article",
         sourcePath: "blog/some-slug/index.html"
      )
      #expect(route.outputFilename(for: self.variant) == "Classic-indigo-editorial-light-article.html")
   }

   @Test("A future tag-listing route would append its id verbatim")
   func tagRouteAppendsIdVerbatim() {
      let route = PreviewRoute(id: "tags", label: "Tags", sourcePath: "tags/index.html")
      #expect(route.outputFilename(for: self.variant) == "Classic-indigo-editorial-light-tags.html")
   }

   @Test("Canonical previewRoutes catalog declares home + article")
   func canonicalCatalogShape() {
      #expect(previewRoutes.count == 2)
      #expect(previewRoutes.map(\.id) == ["home", "article"])
      #expect(previewRoutes[0].sourcePath == "index.html")
      #expect(previewRoutes[1].sourcePath == "blog/working-with-async-sequences-in-swift/index.html")
   }
}
