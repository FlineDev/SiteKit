import ArgumentParser

/// The `sitekit` command-line tool: the deterministic, scriptable substrate for installing
/// SiteKit and scaffolding sites. Judgment work (blueprint choice, theme/font decisions,
/// content authoring) stays in the `sitekit` Claude Code skill – see `references/bootstrap.md`.
@main
struct SiteKitCommand: ParsableCommand {
   static let configuration = CommandConfiguration(
      commandName: "sitekit",
      abstract: "Install SiteKit and scaffold static sites.",
      version: siteKitVersion,
      subcommands: [Doctor.self, Blueprints.self, New.self, Update.self]
   )
}
