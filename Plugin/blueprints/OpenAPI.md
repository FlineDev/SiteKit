# Blueprint: OpenAPI

Generate a complete, static API-documentation site from an OpenAPI spec. The author provides one spec file; the blueprint renders every page.

## Quick Start

1. Copy the `OpenAPI/` template into a new project directory.
2. Replace `Content/openapi.yaml` with the user's spec (OpenAPI 3.0 or 3.1, YAML or JSON, auto-detected).
3. Edit `SiteConfig.yaml` (name, base URL, footer) and `Theme/theme.yaml` (color scheme, fonts).
4. `swift run Site build` → `_Site/`.

`Sources/Site/Main.swift` is one line: `try SiteBuilder.openAPI(configPath: "SiteConfig.yaml").run()`.

## When to Choose This

Choose `OpenAPI` when the user has an OpenAPI/Swagger spec (3.0 or 3.1) and wants browsable, linkable, search- and AI-indexed reference docs for it. If they want hand-written guides or a DocC catalog instead, use `DocC`; for narrative articles, use `Blog`.

The spec must be a single self-contained file. In-file component `$ref`s resolve; multi-file `$ref`s that point across files are out of scope.

## How It Works

One spec in, a full site out, all under the section's `urlPrefix` (default `api`):

- **Landing** (`/api/`) – the API title, version, the optional `Content/api-intro.md` prose, and a card per tag.
- **Tag pages** (`/api/<tag>/`) – each tag's operations, with method badges.
- **Operation pages** (`/api/<tag>/<operation>/`) – method + path, parameters, request body, per-status responses, referenced schemas, examples, and security. Static-first: shapes and examples, no interactive request widget in this version.
- **Schema pages** (`/api/schemas/<name>/`) – properties, composition (allOf/oneOf/anyOf), enums, and nullable/deprecated markers.

Slugs are ASCII-folded and collision-guarded, so non-ASCII tag/operation names and name clashes still produce distinct, stable URLs.

Around the pages the blueprint ships: a persistent **nav rail** (collapsible groups, a live filter, deprecated dimming, active-page tracking), full-text **search** (`/assets/search-index.json` + an appbar search box), per-page **SEO** (title, description, canonical), **sitemap.xml**, **llms.txt**, and **nav-index.json**, a config-driven **footer**, a styled **404**, and a light/dark **theme toggle** consistent with the rest of SiteKit.

## Style

The OpenAPI surface owns its own app-shell (the persistent rail + content area), so it looks consistent across all 15 color schemes in light and dark with no layout change. The layout *templates* (Classic / Sidebar / Minimal) do not alter it – only the chosen color scheme and font pairing do.

## Questions to Ask

- Where is the spec? (Default `Content/openapi.yaml`; pass `specPath:` to `.openAPI(...)` if it lives elsewhere.)
- What URL prefix? (Default `api`; set the section's `urlPrefix` in `SiteConfig.yaml`.)
- Any intro prose for the landing page? (Optional `Content/api-intro.md`.)
- Which color scheme and fonts? (Any of the 15 schemes / 6 font pairings in `Theme/theme.yaml`.)
