import ArgumentParser
import Foundation

/// `sitekit new <name> --blueprint <X>` – scaffolds a new site by copying a blueprint.
///
/// The copy excludes build / VCS / output cruft (`.build/`, `.git/`, `_Site/`,
/// `.sitekit-cache/`, …) so a fresh site never inherits local development state from the
/// blueprint's working copy, e.g. a multi-megabyte SPM `.build/` directory.
struct New: ParsableCommand {
   static let configuration = CommandConfiguration(
      abstract: "Scaffold a new SiteKit site from a blueprint."
   )

   @Argument(help: "Directory to create for the new site.")
   var name: String?

   @Option(name: .long, help: "Blueprint to scaffold from (default: Blog).")
   var blueprint: String = "Blog"

   @Flag(name: .long, help: "List the available blueprints and exit (alias for `sitekit blueprints`).")
   var listBlueprints: Bool = false

   func run() throws {
      if self.listBlueprints {
         try Blueprints.printCatalog()
         return
      }

      guard let name = self.name else {
         throw ValidationError("Missing expected argument '<name>'. Run `sitekit new <name> --blueprint <X>`.")
      }

      let catalogDirectory = PackageRoot.blueprintsDirectory
      let chosen = try BlueprintCatalog.blueprint(named: self.blueprint, in: catalogDirectory)

      let source = catalogDirectory.appendingPathComponent(chosen.name)
      let target = URL(fileURLWithPath: name, isDirectory: true)

      try ScaffoldCopier.copy(from: source, to: target)
      try Self.writeAgentGuidance(into: target)

      print("Scaffolded '\(chosen.name)' blueprint into \(target.path)")
      print("")
      print("Next steps:")
      print("  cd \(name)")
      print("  swift run Site build")
   }

   /// Drops an `AGENTS.md` into the new site so the AI assistant working on the live site knows
   /// to load the `sitekit` skill and which reference to consult for each task. An existing file
   /// is never overwritten – a blueprint that ships its own guidance keeps it.
   ///
   /// No `CLAUDE.md` is written: Claude Code reads `AGENTS.md` directly, but ignores it as soon as
   /// a `CLAUDE.md` exists, so an `@AGENTS.md` stub would only get in the way.
   static func writeAgentGuidance(into target: URL) throws {
      let manager = FileManager.default
      let destination = target.appendingPathComponent("AGENTS.md")
      guard !manager.fileExists(atPath: destination.path) else { return }
      let templateURL = PackageRoot.templatesDirectory.appendingPathComponent("SiteAGENTS.md")
      guard manager.fileExists(atPath: templateURL.path) else { return }
      try manager.copyItem(at: templateURL, to: destination)
   }
}
