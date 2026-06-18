# Changelog

All notable changes to SiteKit are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and SiteKit adheres to [Semantic Versioning](https://semver.org) from 1.0.0 onward: breaking changes get a major bump and documented migration steps in this changelog.

## [1.0.1] – 2026-06-18

### Fixed

- DocC theme: linked inline code is clearly distinguishable from plain inline code again. A linked `<code>` renders in the accent color with an underline, restoring the link affordance that the inline-code pill styling had flattened.
- DocC theme: Swift syntax highlighting in code blocks now uses a fixed Apple/Xcode-style palette (pink keywords, purple types, red strings, blue numbers, and so on) on a pinned code surface, instead of accent-derived shades that collapsed to near-monochrome on strongly saturated accents.

### Added

- An optional SwiftSyntax-based Swift code highlighter for DocC sites (the `SiteKitSyntaxHighlighting` product, opt-in via `SiteBuilder.docc(…, highlighter:)`). It classifies Swift tokens by syntactic role, coloring variable references green plus calls, members, and parameters, for a richer Xcode-like look. It lives in its own product, so sites that do not opt in never compile swift-syntax.

**Full Changelog**: https://github.com/FlineDev/SiteKit/compare/1.0.0...1.0.1

## [1.0.0] – 2026-06-15

Initial public release: an AI-first Swift static site generator with a phase-oriented build pipeline of swappable plugins, nine starter blueprints (Blog, IndieDev, Podcast, Newsletter, Portfolio, AppLanding, DocC, Plain, Snippets), a theming system with 3 layout templates, 15 color schemes, and 6 font pairings, and a Claude Code plugin that guides AI agents through building and maintaining sites.

### Added

- Nine starter blueprints: Blog, IndieDev, Podcast, Newsletter, Portfolio, AppLanding, DocC, Plain, and Snippets.
- A phase-oriented build pipeline of swappable plugins, composed through `SiteBuilder` factory methods.
- A theming system with 3 layout templates, 15 color schemes, and 6 font pairings.
- SEO-complete output: canonical URLs, Open Graph, JSON-LD, hreflang, sitemap, robots, and `llms.txt`.
- Built-in client-side search, responsive images, dark and light mode, and accessibility-minded semantic HTML.
- AI-assisted localization with hreflang and fallbacks across 36 locales.
- The `sitekit` command-line interface to scaffold new sites and manage the toolchain (`new`, `doctor`, `blueprints`, `update`).
- An installable agent skill (`npx skills add FlineDev/SiteKit`) and a Claude Code plugin, also usable from Codex, Cursor, Windsurf, and Xcode 26.
