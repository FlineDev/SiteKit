# CI: Xcode Cloud

> Placeholder – contributions welcome.

## Limitation

Xcode Cloud runs on Apple-silicon macOS and **does** have Swift available (via Xcode). But it is built around **Xcode projects and App Store Connect**: a workflow attaches to an `.xcodeproj`/`.xcworkspace` and is driven by `xcodebuild`. A SiteKit site is a pure SwiftPM package with **no Xcode project** – so you'd have to add an `.xcodeproj` you never actually build, just to host the workflow. That's the core reason it's an awkward fit.

## Pattern (if you want to try)

Xcode Cloud supports custom build scripts (`ci_scripts/ci_post_clone.sh`, `ci_scripts/ci_post_xcodebuild.sh`). You could potentially:
1. In `ci_post_clone.sh`: run `swift run -c release Site build`
2. In `ci_post_xcodebuild.sh`: upload `_Site/` to your host via CLI

This is unsupported and untested. **GitHub Actions is strongly recommended instead.**

## Contributing

If you successfully set up Xcode Cloud for SiteKit deployment, please contribute a guide. See `ci/README.md` for guidelines.

## See also

- [`github-actions.md`](github-actions.md) – the recommended CI for SiteKit (no Xcode project required).
- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
