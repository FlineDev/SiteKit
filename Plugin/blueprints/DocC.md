# Blueprint: DocC

**A documentation site from a DocC catalog – static, AI-fetchable HTML with a left sidebar and full-text search.**

## Quick Start

```bash
swift run sitekit new my-docs --blueprint DocC
cd my-docs
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **ocean** color scheme + **modern** font pairing – change in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `DocC` when you have (or want) a `.docc` catalog – Markdown notes with DocC directives – and need it as a fast, accessible, **AI-fetchable** static site. Unlike DocC's own output (a client-side SPA that serves an empty shell to `curl`/crawlers), SiteKit renders every note to plain server-rendered HTML with:

- a left **sidebar** navigating the catalog (a flat Year→Session tree for WWDC-style catalogs, a flat list otherwise),
- native **full-text search** over the note bodies (sharded, lazy-loaded, no external service),
- DocC directive support (`@Metadata`, `@CallToAction`, `@Contributors`, `@Image`, `@Row`/`@Column`, `@TabNavigator`, …) with graceful degradation – full list in `references/markdown-extensions.md`,
- `<doc:>` cross-reference resolution to internal URLs,
- an optional Community↔AI variant switcher via the `<name>.ai.md` sibling convention.

For a marketing or product site, see `Portfolio` or `AppLanding` instead; for a blog, see `Blog`.

## How It Works

`Sources/Site/Main.swift` calls `SiteBuilder.docc(configPath: "SiteConfig.yaml")`. `SiteConfig.yaml` declares one section pointing at the `.docc` catalog:

```yaml
sections:
  - name: "Documentation"
    slug: "documentation"
    contentDirectory: "Documentation.docc"
    urlPrefix: "documentation"     # notes live under /documentation/<slug>/
```

Drop your `.docc` catalog in place of the sample `Documentation.docc/` (each `.md` file is one page). Notes render under `urlPrefix`; `<doc:>` references resolve under the same prefix.

## Full-text search

The blueprint ships **two** search surfaces over one shared, sharded, lazy-loaded index (no external service):

- The **⌘K overlay** – a quick-jump modal for fast navigation, with no facets and no URL of its own.
- A dedicated **`/search/` page** at `/<prefix>/search/` (e.g. `/documentation/search/`) – a first-class page you can land on, bookmark, and share. The query and facets are baked into the URL (`?q=…&year=wwdc25&type=community&framework=swiftui`), and three facet groups (Year, Note type, Framework) are derived from the catalog, so there are no dead chips for values that have no notes. The overlay's "See all results" footer deep-links here carrying the current query.

The `/search/` page is **progressively enhanced**: with JavaScript disabled it still renders the search box, the facet chips, and the suggestion chips as inert markup, and the sidebar still navigates the whole catalog. Pre-populated suggestion chips ("Try: …", shown while the query is empty) come from the `docc.searchSuggestions` config (see `references/siteconfig-reference.md`).

## Curating the sidebar with `## Topics`

By default the sidebar is a flat Year→Session tree for WWDC-style catalogs and a flat list otherwise. A `## Topics` section curates pages into **named subgroups**, mirroring real Swift-DocC's `## Topics` curation. Under `## Topics`, each `### Group Heading` followed by a `@Links` block (or a plain Markdown list of `<doc:…>` autolinks – no wrapper required) becomes one labelled group:

```markdown
## Topics

### Essentials

@Links(visualStyle: list) {
   - <doc:GettingStarted>
   - <doc:Configuration>
}

### Guides

- <doc:Deployment>
- <doc:Theming>
```

On a **year-overview** note, the groups become subgroups within that year's sidebar branch. On a **loose index/root** page, the listed loose pages nest under the labelled group instead of dangling in the flat list. Either form keeps year/session grouping untouched. The directive syntax is documented in full in `references/markdown-extensions.md`.

## Questions to Ask

1. **Site name and base URL?** (e.g. "My Docs", "https://docs.example.com")
2. **Author name?**
3. **Where is the `.docc` catalog?** (point `contentDirectory` at it; default `Documentation.docc`)
4. **URL prefix for the docs?** (default `documentation`, matching DocC's convention)
5. **Color scheme / font pairing?** (default ocean + modern; see `references/themes.md`)
