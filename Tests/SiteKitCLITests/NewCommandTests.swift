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

   @Test("Writes an AGENTS.md and a CLAUDE.md that point at the sitekit skill")
   func writesAgentGuidance() throws {
      let manager = FileManager.default
      let target = try self.makeEmptyTarget()
      defer { try? manager.removeItem(at: target) }

      try New.writeAgentGuidance(into: target)

      let agents = target.appendingPathComponent("AGENTS.md")
      let claude = target.appendingPathComponent("CLAUDE.md")
      #expect(manager.fileExists(atPath: agents.path))
      #expect(manager.fileExists(atPath: claude.path))

      let agentsBody = try String(contentsOf: agents, encoding: .utf8)
      #expect(agentsBody.contains("sitekit"))
      #expect(agentsBody.contains("legal-pages"))
      let claudeBody = try String(contentsOf: claude, encoding: .utf8)
      #expect(claudeBody.contains("@AGENTS.md"))
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
