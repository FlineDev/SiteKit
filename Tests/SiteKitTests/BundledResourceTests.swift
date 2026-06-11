import Foundation
import Testing

@testable import SiteKit

@Suite("BundledResource")
struct BundledResourceTests {
   @Test("Missing resource URL throws an error naming the resource file")
   func missingResourceThrows() {
      #expect(throws: BundledResourceError.missingResource("docc-missing.js")) {
         try BundledResource.loadText(named: "docc-missing.js", at: nil)
      }
   }

   @Test("The error message names the file and points at a rebuild")
   func errorMessageIsActionable() {
      let message = "\(BundledResourceError.missingResource("docc-filter.js"))"
      #expect(message.contains("docc-filter.js"))
      #expect(message.contains("swift build"))
   }

   @Test("Unreadable resource URL throws instead of returning empty content")
   func unreadableURLThrows() {
      let missingFile = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-bundled-resource-\(UUID().uuidString).js")
      #expect(throws: BundledResourceError.missingResource("gone.js")) {
         try BundledResource.loadText(named: "gone.js", at: missingFile)
      }
   }

   @Test("A readable resource URL returns its UTF-8 contents")
   func readableURLReturnsContents() throws {
      let file = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-bundled-resource-\(UUID().uuidString).js")
      try "console.log('ok')".write(to: file, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: file) }
      #expect(try BundledResource.loadText(named: "ok.js", at: file) == "console.log('ok')")
   }
}
