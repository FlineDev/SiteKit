import ArgumentParser
import Foundation

/// `sitekit update` – bumps a site's SiteKit dependency and resolves it.
///
/// Deliberately limited (F03): it detects the version-pinned SiteKit dependency in
/// `Package.swift`, bumps it (to `--to`, or to the version this CLI ships with), runs
/// `swift package update`, then points at the CHANGELOG. It does NOT auto-apply migration
/// recipes – that is v1.1+. If the build then breaks, it says so and stops.
struct Update: ParsableCommand {
   static let configuration = CommandConfiguration(
      abstract: "Bump the SiteKit dependency and resolve it (no auto-migration)."
   )

   @Option(name: .long, help: "Version to bump the SiteKit dependency to (default: this CLI's version).")
   var to: String?

   func run() throws {
      let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let manifestURL = directory.appendingPathComponent("Package.swift")

      guard let manifest = try? String(contentsOf: manifestURL, encoding: .utf8) else {
         throw ValidationError("No Package.swift in the current directory. Run `sitekit update` inside a SiteKit site.")
      }

      let targetVersion = self.to ?? siteKitVersion
      let currentVersion = PackageManifestEditor.currentVersion(in: manifest)
      let updated = try PackageManifestEditor.bumped(manifest, to: targetVersion)

      if currentVersion == targetVersion {
         print("SiteKit dependency already pinned to \(targetVersion). Re-resolving anyway.")
      } else {
         print("Bumping SiteKit dependency \(currentVersion ?? "?") → \(targetVersion)")
         try updated.write(to: manifestURL, atomically: true, encoding: .utf8)
      }

      print("Running `swift package update`…")
      guard let resolveResult = Shell.run("swift", ["package", "update"], in: directory) else {
         throw ValidationError("Could not run `swift package update` – is the Swift toolchain installed?")
      }
      if !resolveResult.combinedOutput.isEmpty {
         print(resolveResult.combinedOutput)
      }
      guard resolveResult.exitCode == 0 else {
         throw ValidationError("`swift package update` failed. Resolve the dependency error above, then retry.")
      }

      print("")
      print("Building to verify…")
      guard let buildResult = Shell.run("swift", ["build"], in: directory) else {
         throw ValidationError("Could not run `swift build` – is the Swift toolchain installed?")
      }
      guard buildResult.exitCode == 0 else {
         print(buildResult.combinedOutput)
         print("")
         throw ValidationError(
            """
            Build failed after the version bump. This usually means a breaking change needs a \
            manual migration step – check the CHANGELOG entry for the new version in the SiteKit \
            repo and apply the documented steps, then run `swift build` again. `sitekit update` \
            does not auto-apply migration steps.
            """
         )
      }

      print("")
      print("SiteKit updated to \(targetVersion) and the site still builds.")
      print("Review the CHANGELOG for any optional manual migration steps.")
   }
}
