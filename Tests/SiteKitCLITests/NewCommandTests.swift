import Foundation
import Testing
@testable import SiteKitCLI

@Suite("New – agent guidance")
struct NewCommandTests {
   private func makeEmptyTarget() throws -> URL {
      let manager = FileManager.default
      let target = manager.temporaryDirectory.appendingPathComponent("sitekit-new-test-\(UUID().uuidString)")
      try manager.createDirectory(at: target, withIntermediateDirectories: true)
      return target
   }

   @Test("Writes an AGENTS.md that points at the sitekit skill, and no CLAUDE.md")
   func writesAgentGuidance() throws {
      let manager = FileManager.default
      let target = try self.makeEmptyTarget()
      defer { try? manager.removeItem(at: target) }

      try New.writeAgentGuidance(into: target)

      let agents = target.appendingPathComponent("AGENTS.md")
      #expect(manager.fileExists(atPath: agents.path))

      let agentsBody = try String(contentsOf: agents, encoding: .utf8)
      #expect(agentsBody.contains("sitekit"))
      #expect(agentsBody.contains("legal-pages"))

      // A CLAUDE.md would make Claude Code ignore the AGENTS.md above.
      #expect(!manager.fileExists(atPath: target.appendingPathComponent("CLAUDE.md").path))
   }

   @Test("Never overwrites a blueprint's own AGENTS.md")
   func doesNotOverwriteExisting() throws {
      let manager = FileManager.default
      let target = try self.makeEmptyTarget()
      defer { try? manager.removeItem(at: target) }

      let agents = target.appendingPathComponent("AGENTS.md")
      try "custom blueprint guidance".write(to: agents, atomically: true, encoding: .utf8)

      try New.writeAgentGuidance(into: target)

      #expect(try String(contentsOf: agents, encoding: .utf8) == "custom blueprint guidance")
   }
}
