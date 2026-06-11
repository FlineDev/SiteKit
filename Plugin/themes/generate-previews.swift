import Foundation
import PreviewGeneratorKit

// Real-build SiteKit preview generator. Drives one Blog fixture through nine
// real `swift run Site build` invocations – one per layout-template × color-scheme
// × font-pairing × mode variant – and writes each `_Site/index.html` to a single
// self-contained `Plugin/themes/preview/<variant>.html` (CSS + JS + local images
// inlined). The committed `Plugin/themes/ThemePreview.html` iframe-grid still
// drives the previews; only their *quality* changes from emulated to real.
//
// Why the single-fixture / single-compile strategy: the only thing that varies
// across the nine variants is `Theme/theme.yaml` + the chosen layout template's
// theme.css / theme.js. The Markdown content, navigation, and `SiteConfig.yaml`
// are identical. By copying the fixture into `preview-build/` once and running
// `swift build -c release` once, the per-variant cost collapses to "swap
// theme.yaml, copy template assets, run the binary, inline." Targeting ≤ 25 s
// cold and ≤ 15 s warm.

@main
struct PreviewGenerator {
   static func main() throws {
      let runner = DriverRunner()
      try runner.run()
   }
}

struct DriverRunner {
   let layout: Layout

   init() {
      self.layout = Layout()
   }

   func run() throws {
      let totalStart = Date()
      print("Theme preview generator – \(previewVariants.count) variants")
      print("Repo: \(self.layout.repoRoot.path)")
      print()

      try self.prepareBuildDirectory()
      let binaryURL = try self.compileSiteBinary()

      var variantTimings: [(id: String, seconds: Double)] = []
      for (index, variant) in previewVariants.enumerated() {
         let variantStart = Date()
         try self.applyVariant(variant)
         try self.runSiteBuild(binaryURL: binaryURL)
         try self.captureInlinedPreviews(for: variant)
         let elapsed = Date().timeIntervalSince(variantStart)
         variantTimings.append((variant.id, elapsed))
         print("  [\(index + 1)/\(previewVariants.count)] \(variant.id) – \(String(format: "%.2fs", elapsed))")
      }

      try self.writeComparisonIndex()

      let totalElapsed = Date().timeIntervalSince(totalStart)
      print()
      print("Per-variant timings (build + inline only, excludes initial compile):")
      let variantsTotal = variantTimings.reduce(0.0) { $0 + $1.seconds }
      let labelWidth = 44
      for timing in variantTimings {
         print("   \(timing.id.padding(toLength: labelWidth, withPad: " ", startingAt: 0)) \(String(format: "%6.2fs", timing.seconds))")
      }
      print("   \("variants subtotal".padding(toLength: labelWidth, withPad: " ", startingAt: 0)) \(String(format: "%6.2fs", variantsTotal))")
      print("   \("total (incl. fixture copy + compile)".padding(toLength: labelWidth, withPad: " ", startingAt: 0)) \(String(format: "%6.2fs", totalElapsed))")
   }

   // MARK: - Pipeline steps

   /// Refreshes `preview-build/` from the committed fixture: the fixture's
   /// content trees (`Sources/`, `Content/`, `Theme/`, `Package.swift`,
   /// `SiteConfig.yaml`) are mirrored every run, but `.build/` and
   /// `Package.resolved` are kept across runs so SPM's compile cache is reused
   /// on warm reruns. Files with byte-identical content are skipped so their
   /// mtime doesn't drift – SPM uses mtimes for incremental decisions.
   ///
   /// To force a true cold rerun, delete `Plugin/themes/preview-build/` first.
   private func prepareBuildDirectory() throws {
      let manager = FileManager.default
      let buildDir = self.layout.buildDirectory
      try manager.createDirectory(at: buildDir, withIntermediateDirectories: true)
      try self.mirrorContents(of: self.layout.fixtureDirectory, into: buildDir)
      // Stale `_Site/` from a previous variant should not bleed into the current
      // run – wipe it before SiteBuilder.cleanBeforeBuild does its own clean.
      let staleSite = buildDir.appendingPathComponent("_Site")
      if manager.fileExists(atPath: staleSite.path) {
         try manager.removeItem(at: staleSite)
      }
   }

   /// Recursively mirrors every entry under `source` into `destination`. Files
   /// with byte-identical content are left untouched (mtime preserved). Entries
   /// in `destination` with no counterpart in `source` are deleted, EXCEPT the
   /// SPM artifacts (`.build/`, `Package.resolved`) – those are kept on the
   /// destination side so SPM's compile cache survives between runs, and skipped
   /// on the source side so a stray Xcode/LSP-created `.build/` inside the
   /// fixture never bleeds into preview-build.
   ///
   /// At depth 0 we also skip `Theme/`: the variant loop overwrites
   /// `Theme/theme.yaml`, `Theme/css/theme.css`, and `Theme/js/theme.js` every
   /// iteration, and re-copying the placeholder fixture versions only to have
   /// them clobbered seconds later invalidates SPM's cache for no reason. The
   /// `applyVariant` step is the single source of truth for `Theme/`.
   private func mirrorContents(of source: URL, into destination: URL, depth: Int = 0) throws {
      let manager = FileManager.default
      let spmArtifacts: Set<String> = [".build", "Package.resolved"]
      let placeholdersAtRoot: Set<String> = depth == 0 ? ["Theme"] : []
      let sourceSkips: Set<String> = depth == 0 ? spmArtifacts.union(placeholdersAtRoot) : []

      let rawSourceEntries = try manager.contentsOfDirectory(atPath: source.path)
      let sourceEntries = rawSourceEntries.filter { !sourceSkips.contains($0) }
      for child in sourceEntries {
         let sourceChild = source.appendingPathComponent(child)
         let destinationChild = destination.appendingPathComponent(child)
         var isDir: ObjCBool = false
         _ = manager.fileExists(atPath: sourceChild.path, isDirectory: &isDir)
         if isDir.boolValue {
            try manager.createDirectory(at: destinationChild, withIntermediateDirectories: true)
            try self.mirrorContents(of: sourceChild, into: destinationChild, depth: depth + 1)
         } else {
            try self.copyIfChanged(from: sourceChild, to: destinationChild, manager: manager)
         }
      }

      // First-time scaffold: when destination doesn't have `Theme/` yet (the very
      // first cold run), bootstrap it from the fixture so the variant loop has a
      // target to overwrite. After bootstrap, applyVariant owns it.
      if depth == 0 {
         let themeDestination = destination.appendingPathComponent("Theme")
         if !manager.fileExists(atPath: themeDestination.path) {
            let themeSource = source.appendingPathComponent("Theme")
            try manager.copyItem(at: themeSource, to: themeDestination)
         }
      }

      let destinationEntries = (try? manager.contentsOfDirectory(atPath: destination.path)) ?? []
      let sourceSet = Set(sourceEntries)
      let keepAtRoot = placeholdersAtRoot.union(spmArtifacts)
      for child in destinationEntries where !sourceSet.contains(child) && !keepAtRoot.contains(child) {
         try manager.removeItem(at: destination.appendingPathComponent(child))
      }
   }

   private func copyIfChanged(from source: URL, to destination: URL, manager: FileManager) throws {
      if manager.fileExists(atPath: destination.path) {
         let same = manager.contentsEqual(atPath: source.path, andPath: destination.path)
         if same { return }
         try manager.removeItem(at: destination)
      }
      try manager.copyItem(at: source, to: destination)
   }

   /// Compiles the fixture's `Site` executable. Always shells out to `swift build`
   /// so SPM's own incremental-build logic decides whether a recompile is needed –
   /// in particular, SPM tracks the parent SiteKit Swift tree reached via the
   /// `path: "../../.."` dep, which a homegrown mtime cache cannot see without
   /// scanning ~150 source files. `swift build` of an unchanged workspace finishes
   /// in 1-2 s, well inside the warm-budget target. Debug configuration is chosen
   /// over release because the dependency closure (Yams + swift-markdown +
   /// swift-crypto + swift-log) compiles ~3× faster, and the runtime difference
   /// across nine ~0.5 s builds of a tiny fixture is irrelevant. The per-variant
   /// builds invoke the produced binary directly so SPM workspace setup pays only
   /// once per driver run.
   private func compileSiteBinary() throws -> URL {
      let compileStart = Date()
      print("Compiling Site executable (debug – SPM decides incremental)…")
      try self.runSwift(["build"], in: self.layout.buildDirectory)
      let binaryURL = try self.locateSiteBinary()
      let elapsed = Date().timeIntervalSince(compileStart)
      print("   compiled in \(String(format: "%.2fs", elapsed)) (binary: \(binaryURL.path))")
      print()
      return binaryURL
   }

   /// Finds the produced `Site` binary inside `.build/<triple>/debug/`. We don't
   /// hard-code the triple because it varies across hosts (arm64 vs x86_64) and
   /// SPM occasionally changes its conventions; instead we glob the `.build/`
   /// folder.
   private func locateSiteBinary() throws -> URL {
      let manager = FileManager.default
      let buildPath = self.layout.buildDirectory.appendingPathComponent(".build")
      let entries = (try? manager.contentsOfDirectory(atPath: buildPath.path)) ?? []
      for entry in entries where entry.contains("-apple-") {
         let candidate = buildPath
            .appendingPathComponent(entry)
            .appendingPathComponent("debug")
            .appendingPathComponent("Site")
         if manager.fileExists(atPath: candidate.path) {
            return candidate
         }
      }
      throw DriverError.siteBinaryNotFound(searchedIn: buildPath.path)
   }

   /// Overwrites the fixture's `Theme/theme.yaml` and copies the chosen layout
   /// template's `theme.css` / `theme.js` into the fixture's `Theme/{css,js}/`. The
   /// SiteKit blog renderers pick these up on the next `Site build`.
   private func applyVariant(_ variant: PreviewVariant) throws {
      let manager = FileManager.default

      // Write theme.yaml with the variant's color scheme + font pairing + mode.
      let yamlURL = self.layout.buildDirectory.appendingPathComponent("Theme/theme.yaml")
      try variant.themeYAML().write(to: yamlURL, atomically: true, encoding: .utf8)

      // Copy the layout-template assets so the rendered chrome matches a real
      // production build of the same template.
      let templateDir = self.layout.themesDirectory
         .appendingPathComponent("templates")
         .appendingPathComponent(variant.layoutTemplate)
      let cssDestination = self.layout.buildDirectory.appendingPathComponent("Theme/css/theme.css")
      let jsDestination = self.layout.buildDirectory.appendingPathComponent("Theme/js/theme.js")
      try replaceFile(at: cssDestination, with: templateDir.appendingPathComponent("theme.css"), using: manager)
      try replaceFile(at: jsDestination, with: templateDir.appendingPathComponent("theme.js"), using: manager)
   }

   /// Runs the pre-compiled `Site` binary against the fixture, producing `_Site/`.
   /// Calling the binary directly (rather than `swift run`) skips dependency
   /// re-resolution on every variant – saving a couple of seconds per build.
   private func runSiteBuild(binaryURL: URL) throws {
      let process = Process()
      process.currentDirectoryURL = self.layout.buildDirectory
      process.executableURL = binaryURL
      process.arguments = ["build"]
      let stderrPipe = Pipe()
      process.standardError = stderrPipe
      process.standardOutput = Pipe()
      try process.run()
      process.waitUntilExit()
      if process.terminationStatus != 0 {
         let errorOutput = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
         throw DriverError.siteBuildFailed(exitCode: process.terminationStatus, stderr: errorOutput)
      }
   }

   /// Reads each preview route from `_Site/`, inlines its referenced assets, and
   /// writes the self-contained output to `Plugin/themes/preview/<variant>-<route>.html`.
   /// The legacy "home only" output keeps the bare `<variant>.html` filename so the
   /// existing ThemePreview iframe paths in older review notes still resolve.
   private func captureInlinedPreviews(for variant: PreviewVariant) throws {
      let siteDir = self.layout.buildDirectory.appendingPathComponent("_Site")
      for route in previewRoutes {
         let sourceURL = siteDir.appendingPathComponent(route.sourcePath)
         guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw DriverError.previewRouteMissing(route: route.id, expectedAt: sourceURL.path)
         }
         let html = try String(contentsOf: sourceURL, encoding: .utf8)
         let inlined = PreviewInliner.inline(html: html, siteDirectory: siteDir)
         let outputName = route.outputFilename(for: variant)
         let outputURL = self.layout.previewDirectory.appendingPathComponent(outputName)
         try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
         )
         try inlined.write(to: outputURL, atomically: true, encoding: .utf8)
      }
   }

   /// Regenerates `Plugin/themes/ThemePreview.html` so it lists both the Home and
   /// the Article tile for each of the nine variants. The grid is grouped by
   /// layout template (Classic / Sidebar / Minimal), and inside each group each
   /// variant occupies a pair of side-by-side tiles. Writing the file from the
   /// driver keeps the variant list, route list, and grid metadata in lockstep –
   /// adding a layout template or a route is now a one-place edit.
   private func writeComparisonIndex() throws {
      let html = ComparisonIndex.html(variants: previewVariants, routes: previewRoutes)
      let outputURL = self.layout.themesDirectory.appendingPathComponent("ThemePreview.html")
      try html.write(to: outputURL, atomically: true, encoding: .utf8)
   }


   // MARK: - Process plumbing

   private func runSwift(_ arguments: [String], in directory: URL) throws {
      let process = Process()
      process.currentDirectoryURL = directory
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["swift"] + arguments
      // SPM's stdout/stderr go to the inherited parent fds – that's the only
      // configuration where SPM consistently uses its on-disk plugin cache and
      // dependency-resolution snapshot. With piped fds (or even just
      // unconnected ones) it pessimistically re-resolves and re-compiles plugins
      // each invocation, costing ~8 s of warm overhead.
      try process.run()
      process.waitUntilExit()
      if process.terminationStatus != 0 {
         throw DriverError.swiftCommandFailed(arguments: arguments, exitCode: process.terminationStatus, stderr: "(stderr inherited; see output above)")
      }
   }

}

// MARK: - Layout

/// Resolved filesystem locations relative to this script's source file.
struct Layout {
   let repoRoot: URL
   let themesDirectory: URL
   let fixtureDirectory: URL
   let buildDirectory: URL
   let previewDirectory: URL

   init() {
      // The driver runs via `swift run` from the repo root, so `current directory`
      // is the SiteKit package root. We anchor every path off that to remain
      // independent of how the user invoked the binary.
      let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      self.repoRoot = repoRoot
      self.themesDirectory = repoRoot.appendingPathComponent("Plugin/themes")
      self.fixtureDirectory = self.themesDirectory.appendingPathComponent("preview-fixture")
      self.buildDirectory = self.themesDirectory.appendingPathComponent("preview-build")
      self.previewDirectory = self.themesDirectory.appendingPathComponent("preview")
   }
}

// MARK: - Errors

enum DriverError: Error, CustomStringConvertible {
   case swiftCommandFailed(arguments: [String], exitCode: Int32, stderr: String)
   case siteBuildFailed(exitCode: Int32, stderr: String)
   case siteBinaryNotFound(searchedIn: String)
   case previewRouteMissing(route: String, expectedAt: String)

   var description: String {
      switch self {
      case .swiftCommandFailed(let arguments, let exitCode, let stderr):
         return "swift \(arguments.joined(separator: " ")) failed (exit \(exitCode))\n\(stderr)"
      case .siteBuildFailed(let exitCode, let stderr):
         return "Site build failed (exit \(exitCode))\n\(stderr)"
      case .siteBinaryNotFound(let path):
         return "Could not locate the compiled Site binary under \(path)/<triple>/debug/Site"
      case .previewRouteMissing(let route, let path):
         return "Preview route '\(route)' did not produce an HTML file at \(path)"
      }
   }
}

// MARK: - File helpers

private func replaceFile(at destination: URL, with source: URL, using manager: FileManager) throws {
   if manager.fileExists(atPath: destination.path) {
      try manager.removeItem(at: destination)
   }
   try manager.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
   )
   try manager.copyItem(at: source, to: destination)
}
