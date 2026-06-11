import Foundation
import Testing
@testable import SiteKitCLI

@Suite("PrerequisiteChecker")
struct PrerequisiteCheckerTests {
   @Test("Parses major.minor from git, gh, and the swift --version banner")
   func parsesVersions() {
      #expect(PrerequisiteChecker.parseVersion(from: "git version 2.50.1") == ToolVersion(major: 2, minor: 50))
      #expect(PrerequisiteChecker.parseVersion(from: "gh version 2.89.0 (2026-03-26)") == ToolVersion(major: 2, minor: 89))
      let swiftBanner = """
         swift-driver version: 1.148.6 Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
         Target: arm64-apple-macosx26.0
         """
      #expect(PrerequisiteChecker.parseVersion(from: swiftBanner) == ToolVersion(major: 6, minor: 3))
   }

   @Test("Returns nil for output with no version number")
   func parseVersionReturnsNilWhenAbsent() {
      #expect(PrerequisiteChecker.parseVersion(from: "command not found") == nil)
   }

   @Test("evaluateSwift fails when Swift is missing or below 6.2, passes at 6.2+")
   func evaluatesSwift() {
      #expect(PrerequisiteChecker.evaluateSwift(versionOutput: nil).status == .failure)
      #expect(PrerequisiteChecker.evaluateSwift(versionOutput: "Apple Swift version 6.1").status == .failure)
      #expect(PrerequisiteChecker.evaluateSwift(versionOutput: "Apple Swift version 6.2").status == .ok)
      #expect(PrerequisiteChecker.evaluateSwift(versionOutput: "Apple Swift version 6.3").status == .ok)
   }

   @Test("evaluateGit fails only when git is missing")
   func evaluatesGit() {
      #expect(PrerequisiteChecker.evaluateGit(versionOutput: nil).status == .failure)
      #expect(PrerequisiteChecker.evaluateGit(versionOutput: "git version 2.50.1").status == .ok)
   }

   @Test("evaluateGitHubCLI warns (never fails) when gh is missing")
   func evaluatesGitHubCLI() {
      #expect(PrerequisiteChecker.evaluateGitHubCLI(versionOutput: nil).status == .warning)
      #expect(PrerequisiteChecker.evaluateGitHubCLI(versionOutput: "gh version 2.89.0").status == .ok)
   }

   @Test("ToolVersion compares major then minor")
   func toolVersionOrdering() {
      #expect(ToolVersion(major: 6, minor: 1) < ToolVersion(major: 6, minor: 2))
      #expect(ToolVersion(major: 5, minor: 9) < ToolVersion(major: 6, minor: 0))
      #expect(!(ToolVersion(major: 6, minor: 3) < ToolVersion(major: 6, minor: 2)))
   }
}
