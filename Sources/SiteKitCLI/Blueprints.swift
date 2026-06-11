import ArgumentParser
import Foundation

/// `sitekit blueprints` – lists the starter site templates under `Plugin/blueprints/`.
struct Blueprints: ParsableCommand {
   static let configuration = CommandConfiguration(
      abstract: "List the available site blueprints."
   )

   func run() throws {
      try Self.printCatalog()
   }

   /// Prints the blueprint catalog. Shared with `sitekit new --list-blueprints`.
   static func printCatalog() throws {
      let blueprints = try BlueprintCatalog.all(in: PackageRoot.blueprintsDirectory)
      print("Available blueprints (\(blueprints.count)):")
      print("")
      let width = blueprints.map(\.name.count).max() ?? 0
      for blueprint in blueprints {
         let name = blueprint.name.padding(toLength: width, withPad: " ", startingAt: 0)
         print("  \(name)  \(blueprint.description)")
      }
   }
}
