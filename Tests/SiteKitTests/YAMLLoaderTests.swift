import Foundation
import Testing
@testable import SiteKit

@Suite("YAMLLoader")
struct YAMLLoaderTests {
   private struct LandingDataFixture: Codable, Sendable, Equatable {
      let title: String
      let subtitle: String
      let features: [String]
   }

   @Test("Decodes a Decodable struct from a YAMLSource")
   func decodesStructFromYAMLSource() throws {
      let yaml = """
      title: Hello
      subtitle: Welcome
      features:
        - Fast
        - Reliable
      """
      let url = URL(fileURLWithPath: "/tmp/Landing.yaml")
      let source = YAMLSource(filePath: url, content: yaml)
      let loader = YAMLLoader<LandingDataFixture>()
      let data = try loader.load(source: source)
      #expect(data.title == "Hello")
      #expect(data.subtitle == "Welcome")
      #expect(data.features == ["Fast", "Reliable"])
   }

}
