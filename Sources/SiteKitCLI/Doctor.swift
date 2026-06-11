import ArgumentParser
import Foundation

/// `sitekit doctor` – checks the prerequisites for building a SiteKit site.
///
/// `git` and `swift` (≥ 6.2) are hard requirements; `gh` is optional and only warned about.
/// Exits non-zero when a hard prerequisite is missing or too old.
struct Doctor: ParsableCommand {
   static let configuration = CommandConfiguration(
      abstract: "Check that git, swift, and gh are available."
   )

   func run() throws {
      let git = PrerequisiteChecker.evaluateGit(versionOutput: Shell.run("git", ["--version"])?.combinedOutput)
      let swift = PrerequisiteChecker.evaluateSwift(versionOutput: Shell.run("swift", ["--version"])?.combinedOutput)
      let gh = PrerequisiteChecker.evaluateGitHubCLI(versionOutput: Shell.run("gh", ["--version"])?.combinedOutput)

      print("SiteKit prerequisite check")
      print("")
      for result in [git, swift, gh] {
         print("  \(Self.symbol(for: result.status)) \(result.tool): \(result.detail)")
      }
      print("")

      let failures = [git, swift, gh].filter { $0.status == .failure }
      if failures.isEmpty {
         print("All hard prerequisites satisfied.")
      } else {
         print("\(failures.count) hard prerequisite(s) missing – fix the items marked ✗ above.")
         throw ExitCode.failure
      }
   }

   private static func symbol(for status: PrerequisiteResult.Status) -> String {
      switch status {
      case .ok: return "✓"
      case .warning: return "!"
      case .failure: return "✗"
      }
   }
}
