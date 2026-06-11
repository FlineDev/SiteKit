import ArgumentParser
import Testing
@testable import SiteKitCLI

@Suite("Argument parsing")
struct ArgumentParsingTests {
   @Test("`new` defaults the blueprint to Blog when --blueprint is omitted")
   func newDefaultsToBlog() throws {
      let command = try New.parse(["MySite"])
      #expect(command.name == "MySite")
      #expect(command.blueprint == "Blog")
      #expect(command.listBlueprints == false)
   }

   @Test("`new` accepts an explicit --blueprint")
   func newAcceptsBlueprint() throws {
      let command = try New.parse(["MySite", "--blueprint", "Podcast"])
      #expect(command.name == "MySite")
      #expect(command.blueprint == "Podcast")
   }

   @Test("`new --list-blueprints` parses without a positional name")
   func newListBlueprintsNeedsNoName() throws {
      let command = try New.parse(["--list-blueprints"])
      #expect(command.listBlueprints == true)
      #expect(command.name == nil)
   }

   @Test("`update` defaults --to to nil and accepts an explicit version")
   func updateParsesToOption() throws {
      #expect(try Update.parse([]).to == nil)
      #expect(try Update.parse(["--to", "1.2.0"]).to == "1.2.0")
   }

   @Test("The root command exposes exactly the four subcommands and a version")
   func rootCommandSurface() {
      let subcommands = SiteKitCommand.configuration.subcommands
      #expect(subcommands.count == 4)
      #expect(subcommands.contains { $0 == Doctor.self })
      #expect(subcommands.contains { $0 == Blueprints.self })
      #expect(subcommands.contains { $0 == New.self })
      #expect(subcommands.contains { $0 == Update.self })
      #expect(SiteKitCommand.configuration.version == siteKitVersion)
   }
}
