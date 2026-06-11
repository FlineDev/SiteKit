import Foundation

/// A semantic version reduced to `major.minor`, comparable for prerequisite checks.
struct ToolVersion: Comparable, CustomStringConvertible {
   let major: Int
   let minor: Int

   var description: String { "\(self.major).\(self.minor)" }

   static func < (lhs: ToolVersion, rhs: ToolVersion) -> Bool {
      lhs.major != rhs.major ? lhs.major < rhs.major : lhs.minor < rhs.minor
   }
}

/// The outcome of one prerequisite check.
struct PrerequisiteResult {
   enum Status { case ok, warning, failure }

   let tool: String
   let status: Status
   let detail: String
}

/// Parses tool-version output and decides whether a SiteKit prerequisite is satisfied.
///
/// `sitekit doctor` shells out to `git`, `swift`, and `gh`; the version-string parsing and the
/// minimum-version decision live here so they are testable without spawning processes.
enum PrerequisiteChecker {
   /// The minimum Swift toolchain SiteKit requires.
   static let minimumSwiftVersion = ToolVersion(major: 6, minor: 2)

   /// Extracts a `major.minor` version from arbitrary tool output.
   ///
   /// Handles `git version 2.50.1`, `gh version 2.89.0 (…)`, and the multi-line
   /// `swift --version` banner. The Swift banner leads with an unrelated `swift-driver
   /// version: 1.148.6`, so the `Swift version X.Y` token is preferred when present;
   /// otherwise the first `major.minor` in the string is used.
   static func parseVersion(from output: String) -> ToolVersion? {
      let versionString: Substring?
      if let swiftRange = output.range(of: #"Swift version \d+\.\d+(\.\d+)?"#, options: .regularExpression) {
         versionString = output[swiftRange].split(separator: " ").last
      } else if let range = output.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
         versionString = output[range]
      } else {
         versionString = nil
      }

      guard let versionString else { return nil }
      let components = versionString.split(separator: ".")
      guard components.count >= 2, let major = Int(components[0]), let minor = Int(components[1]) else {
         return nil
      }
      return ToolVersion(major: major, minor: minor)
   }

   /// Classifies a Swift toolchain: failure when missing or below `minimumSwiftVersion`, else ok.
   static func evaluateSwift(versionOutput: String?) -> PrerequisiteResult {
      guard let output = versionOutput, let version = self.parseVersion(from: output) else {
         return PrerequisiteResult(
            tool: "swift",
            status: .failure,
            detail: "Swift is not installed. Install Xcode from the Mac App Store or get the toolchain from https://swift.org/download."
         )
      }
      if version < self.minimumSwiftVersion {
         return PrerequisiteResult(
            tool: "swift",
            status: .failure,
            detail: "Swift \(version) found, but SiteKit needs \(self.minimumSwiftVersion) or newer."
         )
      }
      return PrerequisiteResult(tool: "swift", status: .ok, detail: "Swift \(version)")
   }

   /// Classifies `git`: failure when missing, else ok.
   static func evaluateGit(versionOutput: String?) -> PrerequisiteResult {
      guard let output = versionOutput, let version = self.parseVersion(from: output) else {
         return PrerequisiteResult(
            tool: "git",
            status: .failure,
            detail: "Git is not installed. Install it from https://git-scm.com or run `xcode-select --install`."
         )
      }
      return PrerequisiteResult(tool: "git", status: .ok, detail: "git \(version)")
   }

   /// Classifies `gh`: warning when missing (it is optional), else ok.
   static func evaluateGitHubCLI(versionOutput: String?) -> PrerequisiteResult {
      guard let output = versionOutput, let version = self.parseVersion(from: output) else {
         return PrerequisiteResult(
            tool: "gh",
            status: .warning,
            detail: "GitHub CLI not installed (optional). Install with `brew install gh` if you want repo automation."
         )
      }
      return PrerequisiteResult(tool: "gh", status: .ok, detail: "gh \(version)")
   }
}
