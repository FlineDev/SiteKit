/// The SiteKit release this CLI ships with.
///
/// The `sitekit` CLI lives inside SiteKit's own `Package.swift` and evolves with the library,
/// so the CLI version *is* the SiteKit version. `sitekit update` bumps a site's dependency to
/// this value when no explicit `--to` is given – running `update` from a SiteKit clone at vX
/// pins the site to vX.
let siteKitVersion = "1.0.0"
