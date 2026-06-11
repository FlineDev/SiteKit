import Foundation
import Testing

@testable import SiteKit

/// A renderer that always fails – drives the pipeline's aggregate error path.
private struct FailingRenderer: Renderer {
   struct Boom: Error, CustomStringConvertible {
      var description: String { "boom: fixture renderer failure" }
   }

   func render(context: BuildContext) throws -> [OutputFile] {
      throw Boom()
   }
}

@Suite("BuildPipelineErrorReporting")
struct BuildPipelineErrorTests {
   private func makeEmptyProject() throws -> URL {
      let directory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-pipeline-error-fixture-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
   }

   @Test("Renderer failures aggregate into renderersFailed, preserving each underlying error")
   func rendererFailuresArePreserved() throws {
      let projectDirectory = try self.makeEmptyProject()
      defer { try? FileManager.default.removeItem(at: projectDirectory) }
      let config = SiteConfig(name: "Fixture", baseURL: "https://example.org")

      let pipeline = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .renderer(FailingRenderer())
         .buildPipeline()

      do {
         try pipeline.build()
         Issue.record("build() must throw when a renderer fails")
      } catch let error as BuildPipelineError {
         guard case .renderersFailed(let failures) = error else {
            Issue.record("expected renderersFailed, got \(error)")
            return
         }
         #expect(failures.count == 1)
         #expect(failures.first?.renderer == "FailingRenderer")
         #expect(failures.first.map { String(describing: $0.error) }?.contains("boom") == true)
         // The aggregate's own description names the renderer AND its cause, so a
         // top-level catch printing the error keeps the underlying failures visible.
         #expect(String(describing: error).contains("FailingRenderer"))
         #expect(String(describing: error).contains("boom"))
      }
   }

   @Test("cliDescription renders Swift errors via their description and NSError via localizedDescription")
   func cliDescriptionShape() {
      #expect(SiteBuilder.cliDescription(of: FailingRenderer.Boom()) == "boom: fixture renderer failure")

      let nsError = NSError(domain: "Fixture", code: 7, userInfo: [NSLocalizedDescriptionKey: "clean line"])
      #expect(SiteBuilder.cliDescription(of: nsError) == "clean line")
   }

   @Test("SiteConfigError renders as a clean, path-bearing line")
   func siteConfigErrorDescription() {
      let missing = URL(fileURLWithPath: "/tmp/some-site/SiteConfig.yaml")
      let description = String(describing: SiteConfigError.fileNotFound(missing))
      #expect(description.contains("/tmp/some-site/SiteConfig.yaml"))
      #expect(!description.contains("fileNotFound"), "the enum case name is not a user-facing message")
   }
}
