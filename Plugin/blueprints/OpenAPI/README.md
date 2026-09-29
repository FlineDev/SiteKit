# Tasks API – SiteKit OpenAPI starter

A ready-to-build API-documentation site generated from an OpenAPI spec with SiteKit's `.openAPI` blueprint.

## Build it

```bash
swift run Site build      # renders the site into _Site/
swift run Site serve      # local preview at http://localhost:8080
```

Open `_Site/api/index.html` (via `serve`) to see the landing page, then the per-tag, per-operation, and per-schema pages.

## What's here

- `Content/openapi.yaml` – the spec (OpenAPI 3.1; 3.0 works too, auto-detected). Replace it with yours.
- `Content/api-intro.md` – optional prose shown above the landing tag cards. Delete it to omit.
- `SiteConfig.yaml` – site name, base URL, the single `api` section, and the footer.
- `Theme/theme.yaml` – the color scheme and font pairing. The API surface brings its own layout, so any of the 15 schemes work in light and dark.
- `Sources/Site/Main.swift` – one line: `SiteBuilder.openAPI(configPath: "SiteConfig.yaml").run()`.

## Make it yours

Drop your own `Content/openapi.yaml` in place (keep the file name, or point `specPath` at another location), update `SiteConfig.yaml`, and rebuild. Every operation and schema page, the nav rail, search, sitemap, and `llms.txt` come from the spec – there is nothing to author per endpoint.

The pages render request/response shapes and examples (static-first); there is no interactive "try it" request widget in this version.
