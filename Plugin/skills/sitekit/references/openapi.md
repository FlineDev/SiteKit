# OpenAPI API-documentation sites

The `.openAPI` blueprint turns one OpenAPI spec into a complete, static, searchable API-reference site. The author supplies the spec; the blueprint renders every page. Zero per-operation authoring.

Starter template: `Plugin/blueprints/OpenAPI/` (clone it, swap in the user's spec). AI-instruction file: `Plugin/blueprints/OpenAPI.md`.

## Inputs the author provides

- **`Content/openapi.yaml`** (or `.json`) – the spec. **OpenAPI 3.0 or 3.1**, YAML or JSON, auto-detected by the loader. It must be a **single self-contained file**: in-file component `$ref`s resolve; multi-file `$ref`s pointing across files are out of scope.
- **`SiteConfig.yaml`** – site name, base URL, and one section (slug `api` by convention) whose `urlPrefix` is the URL root for the docs.
- **`Theme/theme.yaml`** – a color scheme and font pairing.
- **`Content/api-intro.md`** (optional) – Markdown prose rendered above the tag cards on the landing page.

Spec elsewhere? Pass `specPath:` to `.openAPI(...)` to override the conventional `Content/openapi.yaml` discovery.

## The factory

```swift
import SiteKit
import SiteKitOpenAPI

try SiteBuilder.openAPI(configPath: "SiteConfig.yaml").run()
```

`.openAPI` is in the optional **`SiteKitOpenAPI`** product (the OpenAPI parser pulls in only for builds that use it). `Package.swift` depends on both `SiteKit` and `SiteKitOpenAPI`. The `configPath:` overload loads the config and uses the current directory as the project root; the explicit form is `.openAPI(config:projectDirectory:specPath:)`.

## What it renders

All under the section's `urlPrefix` (default `api`):

| Page | URL | Contents |
|---|---|---|
| Landing | `/api/` | API title + version, optional `api-intro.md` prose, a card per tag |
| Tag | `/api/<tag>/` | the tag's operations, with method badges |
| Operation | `/api/<tag>/<operation>/` | method + path, parameters, request body, per-status responses, referenced schemas, examples, security |
| Schema | `/api/schemas/<name>/` | properties, composition (allOf/oneOf/anyOf), enums, nullable / deprecated markers |

A multi-tag operation appears under each of its tags but has one canonical page. Slugs are **ASCII-folded and collision-guarded**, so non-ASCII names and clashes still produce distinct, stable URLs.

Around the pages, the blueprint also ships:

- A persistent **nav rail** – collapsible tag groups, a live filter, deprecated dimming, active-page tracking.
- Full-text **search** – `/assets/search-index.json` plus an appbar search box.
- **SEO** – per-page `<title>`, `<meta name="description">`, and `<link rel="canonical">`.
- Machine indexes – **sitemap.xml**, **llms.txt**, and **nav-index.json**, each listing every operation and schema page.
- A config-driven **footer**, a styled **404** rendered in the full shell (with a link back to the landing), and a light/dark **theme toggle** consistent with the rest of SiteKit (follows the OS until the reader picks a mode).

## Static-first (no "try it" widget)

This version renders request and response **shapes and examples** – it does **not** include an interactive "try it" request widget that fires live calls. State this plainly so authors are not surprised; a seam exists for adding one later.

## Style and layout

The OpenAPI surface owns its own app-shell (the persistent rail + content area), so it looks consistent across all 15 color schemes in light and dark with **no layout change**. The layout *templates* (Classic / Sidebar / Minimal) do not alter the API surface – only the chosen color scheme and font pairing do. The whole surface stays decoupled from the parser: only the spec loader touches OpenAPIKit.
