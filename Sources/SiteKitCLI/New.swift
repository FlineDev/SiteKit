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

      print("Scaffolded '\(chosen.name)' blueprint into \(target.path)")
      print("")
      print("Next steps:")
      print("  cd \(name)")
      print("  swift run Site build")
   }
}
