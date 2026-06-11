# CI: Bitrise

> Placeholder – contributions welcome.

**When to pick:** choose Bitrise only if you already use it for your iOS apps and want the site on the same CI – otherwise GitHub Actions ([`github-actions.md`](github-actions.md)) is lighter for a static site.

## Pattern

1. Get a Swift toolchain:
   - **macOS stack** (the standard iOS-dev stack) – Swift is **pre-installed** via Xcode; no install step needed.
   - **Linux stack** – add a Script step that installs Swift (`swiftly`, or `apt`).
2. Run `swift run -c release Site build` (produces `_Site/`)
3. Deploy `_Site/` to your host (a Script step running the host's CLI – e.g. Wrangler for Cloudflare)

## Notes

- Store credentials as **Secrets** in Bitrise (App → Secrets); reference as `$VARIABLE_NAME` in `bitrise.yml`.
- Bitrise has a generous free tier for open-source projects.
- For the deploy command, see [`../hosts/<provider>.md`](../hosts/cloudflare-pages.md).

## Contributing

To add a complete Bitrise guide with a working `bitrise.yml` example, create a PR to the SiteKit Plugin repo. See `ci/README.md` for guidelines.
