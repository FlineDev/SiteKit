# Architecture – Phase-Oriented Pipeline

SiteKit builds a site by walking a **fixed sequence of phases**. Each phase is one Swift protocol; every shipped plugin (and every plugin you add) implements one of them. The phase you want to extend tells you which protocol to conform to and which `SiteBuilder` swap point to use.

There is one ordered list of phases, each with one protocol. `Page` is a sub-protocol of `Renderer` so HTML page rendering and system rendering share one routing surface.

This file is the **AI-deep** reference: protocol detail, the data model (`PageModel`), the `BuildPipeline` executor walk, and the default plugin chains. AGENTS.md §2 is the contributor-facing **orientation** version of the same pipeline – the two agree on the phase model; this one goes deeper on executor internals and per-blueprint composition.

## Phases

| # | Phase | Protocol | One-line role | `SiteBuilder` swap point |
|---|---|---|---|---|
| 0 | Asset teleport (content-independent) | `Teleporter` | Copy assets from source dirs to output | `.teleporter(_:)` |
| 1 | Discovery | `ContentDiscovery` | Find source files for each section | `.contentDiscovery(_:)` |
| 2 | Loading | `Loader<Source, Output>` | Parse Markdown / YAML into typed models | `.articleLoader(_:)`, `.staticPageLoader(_:)` |
| 3 | Enrichment | `Enricher` | Add hreflang, promotions, reading time, etc. | `.enricher(_:)` |
| 4 | Per-locale HTML pages | `Page : Renderer` | Render HTML pages with site chrome | `.renderer(_:)` |
| 5 | System rendering | `Renderer` (with `RenderScope`) | RSS, sitemap, robots, headers, redirects | `.renderer(_:)` |
| 6 | Output processing | `OutputProcessor` | Image variants, font inlining, minification | `.processor(_:)` |

Phase 0 runs before the content phases and is independent of the content graph – assets never wait on (or feed into) discovery and loading. Phases 1–6 are strictly ordered.

## `RenderScope` and locale routing

Phases 4 and 5 both use `Renderer` conformers. The pipeline routes them by their declared `scope`, not by type-name matching:

```swift
public enum RenderScope: Sendable {
   case perLocale   // runs once per locale's BuildContext (default for Renderer)
   case global      // runs exactly once per build, regardless of locale count
}
```

- `.perLocale` is the default declared in the `Renderer` extension. Pick it for outputs that vary by language: HTML pages, per-locale RSS feeds, per-locale sitemaps, per-locale `content-index.json`.
- `.global` is for site-wide singletons: the sitemap *index*, `robots.txt`, `llms.txt`, Cloudflare `_headers`, language-redirect HTML pages.

Why a runtime field and not a parent protocol? Because some renderers (favicons, redirect pages) flip between `.perLocale` and `.global` depending on `SiteConfig`. A protocol-level split would have forced a brittle "global if the type name contains X" hardcoded list – the `scope` property lets each renderer declare its routing explicitly.

## `BuildContext`

The read-only state passed to every Phase 3–6 plugin:

| Property | Type | Description |
|---|---|---|
| `config` | `SiteConfig` | Site configuration (name, baseURL, sections, author, etc.) |
| `themeConfig` | `ThemeConfig?` | Theme tokens and CSS/JS paths |
| `sections` | `[ContentSection]` | All content sections; each has `.config` and `.pages` |
| `staticPages` | `[PageModel]` | Static pages (About, Home, etc.) |
| `tags` | `[String: [PageModel]]` | All tags mapped to their pages |
| `homeContent` | `String?` | Home page HTML content (if `Home.md` exists) |
| `outputDirectory` | `URL` | Where to write output files (`_Site/`) |
| `projectDirectory` | `URL` | Project root |
| `router` | `any URLRouter` | Generates locale-aware URL paths |
| `uiStrings` | `UIStrings` | Localized UI strings for the current locale |
| `draftPages` | `[PageModel]` | Drafts separated out during loading (rendered only by `DraftPreviewRenderer`) |

Plugins read from it; they do not mutate it. On a multilingual build the pipeline constructs one `BuildContext` per locale for `.perLocale` renderers and a single default-locale context for `.global` renderers. Two convenience accessors exist for backward compatibility: `articles` (pages of the first/`"blog"` section) and the deprecated `snippets` (use `sections` instead).

## `PageModel`

The universal content model – the result of loading + enriching one source file. Every Markdown article, static page, and podcast episode page is a `PageModel`; kind-specific data rides on `pageType` and `extensions` rather than fragmenting into many model types.

| Field | Type | Notes |
|---|---|---|
| `id` | `String?` | Stable id from frontmatter; a build warns when missing |
| `title` | `String` | Required |
| `date` | `Date?` | Drives `sortedByDate()` |
| `slug` | `String` | Locale suffix (e.g. `.de`) is stripped during loading |
| `htmlContent` | `String` | Rendered Markdown body (no chrome) |
| `sourcePath` | `URL` | Originating file |
| `category` | `String` | Non-optional; defaults to `""` |
| `tags` | `[String]` | |
| `summary` / `description` | `String?` | Listing summary / meta description |
| `author` | `Person?` | |
| `image` / `imageAlt` | `String?` | Social/LCP image + required alt text |
| `draft` | `Bool` | Drafts are filtered out of published output |
| `pageType` | `PageType` | `.article` or `.staticPage` – `Page.outputURL(for:)` dispatches on it |
| `locale` | `String` | Defaults to `"en"` |
| `originalLanguage` | `String?` | Set when content is a fallback from the default language |
| `legalDocument` | `Bool` | Marks privacy/imprint pages |
| `extensions` | `[String: any Sendable]` | Typed-key bag for enricher-computed fields |

`extensions` is how enrichers attach computed fields (`readingTime`, `hreflang`, promotion slots, `sectionSlug`, `translationMap`) **without** changing the public initializer. Read them back type-safely with `extensionValue(_:)`:

```swift
let minutes: Int? = page.extensionValue("readingTime")
```

`PageModel` also ships `readTimeMinutes` (a computed estimate: 238 wpm prose, 100 wpm code, plus per-image seconds) and `Array<PageModel>.sortedByDate()` (newest first, slug as the same-date tiebreak). `PageType` is `String, Codable, Sendable` – adding a new page kind means adding a case here *and* extending the router.

## `SiteBuilder`

`SiteBuilder` is a fluent, immutable builder that composes a `BuildPipeline` from the plugins above. Every configuration method returns a new `SiteBuilder`. Preset factory methods like `SiteBuilder.blog(...)`, `.podcast(...)`, `.newsletter(...)`, `.portfolio(...)`, `.docs(...)`, `.docc(...)` pre-compose the default plugin list for a site type.

```swift
try SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .renderer(MyEpisodePage())          // append a per-locale Page
   .renderer(MyMetaIndexRenderer())    // append a .global system renderer
   .enricher(ReadingTimeEnricher())    // append an Enricher
   .processor(CustomMinifier())        // ⚠️ first .processor call REPLACES the default Phase-6 chain (see below)
   .run()
```

`.removing(_:)` removes a shipped plugin by type; `.replacing(_:, with:)` swaps one out by type (with `removingEnricher(_:)` / `replacingEnricher(_:, with:)` mirrors for the enricher list). `.run()` reads CLI arguments (`build`, `serve`, `validate`; plus `--no-clean` and `--port`) and executes the pipeline.

Enrichers run in registration order. The factory methods append SiteKit's built-ins **last**: user-supplied enrichers first, then `PromotionEnricher` (blog/newsletter only – gated at runtime by `config.promotions`), then `HreflangEnricher` (only when `config.isMultilingual`).

## `BuildPipeline` – the executor

`SiteBuilder.buildPipeline()` produces a `BuildPipeline`; `.run()` calls `build()` on it. The walk:

1. **Clean** the output directory (skipped with `--no-clean`).
2. **Teleport assets** – copy content assets, then theme assets into `_Site/assets/theme/` (the `Teleporter` phase; independent of the content graph).
3. **Build content** – branches on `config.isMultilingual`:
   - **Single-language:** discover → load → tag with `sectionSlug` → enrich → split drafts from published → sort → assemble one `BuildContext` → run every renderer.
   - **Multilingual:** partition renderers by `scope`. Loop over all languages, building a locale-aware `BuildContext` (`LocaleAwareURLRouter`, locale `UIStrings`, untranslated files falling back to the default language) and running only the `.perLocale` renderers each pass. After the loop, run the `.global` renderers **once** against a default-locale context, then emit the translation-status JSON.
4. **Output processors** run **once** at the very end (not per locale), each seeing the final on-disk HTML/CSS/assets. A renderer that throws is logged and counted (the build fails if any renderer errored); a processor that throws is logged as a warning and the build continues.

## Default plugin chains

The canonical renderer lists live on `SiteBuilder` (`blogRenderers`, `podcastRenderers`, `newsletterRenderers`) so `SiteBuilder.blog(...)` and a hand-built `BuildPipeline(...)` stay in sync. What distinguishes each preset:

| Preset | Article loader | Distinguishing renderers | Enricher chain |
|---|---|---|---|
| `blog` | `MarkdownLoader(requiredFields: title, date)` | Section pages + listings, Category/Tag listings, `RSSFeedRenderer`, Sitemap, Robots, Nav index, CSS renderers, Cloudflare headers + redirects, Favicon, Llms, ContentIndex, DraftPreview | user → `PromotionEnricher` → `HreflangEnricher`* |
| `newsletter` | same as blog | **`blogRenderers` + `EmailRenderer`** (email-safe HTML at `_Site/email/<slug>.html`) | same as blog |
| `podcast` | `MarkdownLoader(requiredFields: title, date, audioURL, duration)` | `PodcastEpisodeRenderer`, `PodcastListingRenderer`, `PodcastHomePageRenderer`, `PodcastRSSRenderer` (iTunes RSS), `TemplateStaticPageRenderer`, Tag listing – **no** blog section renderers, **no** category listing, **no** `RSSFeedRenderer` | user → `HreflangEnricher`* (no `PromotionEnricher`) |
| `portfolio` | `MarkdownLoader(requiredFields: title, date)` | Static pages + home + error + sitemap + robots + CSS + Cloudflare headers + favicon + llms – **no** RSS, tags, listings, content-index, or draft preview | `HreflangEnricher`* only |
| `docs` | *(none registered)* | same renderer set as `portfolio` ("same as portfolio for now") | `HreflangEnricher`* only |
| `docc` | `DocCLoader` (DocC Markdown + directives) | the DocC page/system stack (see below) | `DocCCrossReferenceEnricher` → `DocCFrameworkEnricher`† → `HreflangEnricher`* |

\* `HreflangEnricher` is appended only when `config.isMultilingual`.
† `DocCFrameworkEnricher` is appended only when `docc.sessionFrameworksPath` points at a readable JSON map.

### The `.docc` plugin stack

`SiteBuilder.docc(...)` composes a dedicated stack so a `.docc` catalog of Markdown notes (plus DocC directives) renders to AI-fetchable static HTML – unlike DocC's own client-side SPA, where `curl`/crawlers see an empty shell. The component set, in phase order:

- **Discovery** – `DocCCatalogDiscovery` walks the `.docc` catalog (notes carry no YAML frontmatter; structure comes from a leading `# Title`, an abstract, and a `@Metadata` block).
- **Loading** – `DocCLoader` parses each note into a `PageModel`, rendering the body through `MarkdownRenderer` plus `DocCDirectiveRenderer` (the DocC body directives, with the graceful-degradation guarantee). DocC metadata lands in `extensions` under `docc…` keys.
- **Teleporting** – `DocCCatalogImageTeleporter` copies every `*.docc/Images/` asset into `/assets/` so `@Image`/`@PageImage` URLs resolve.
- **Enrichment** – `DocCCrossReferenceEnricher` resolves `<doc:…>` links to internal URLs; `DocCFrameworkEnricher` (optional) bulk-assigns framework keys from the central JSON map.
- **Page rendering** – `DocCHomePage`, `DocCYearListingPage`, `DocCContributorsPage`, `DocCContributorPage`, `DocCMissingPage`, `DocCSearchPage`, and `DocCArticlePage`, all wrapped by the shared `DocCShell` (appbar + sidebar). `DocCReservedRoutes` is the single source of truth for which catalog notes are superseded by a specialized page (year roots, `contributors`, `missingnotes`, `search`).
- **System rendering** – the navigation/search infrastructure (`DocCSidebarNavRenderer`, `DocCSearchIndexRenderer` + the search/sidebar/toc/theme/filter script renderers, `NavIndexRenderer`, `DocCStylesheetRenderer`) plus the standard sitemap, robots, CSS, favicon, and llms.txt renderers.

For the directive vocabulary these renderers understand, see `markdown-extensions.md`; for the `docc:` configuration block, see `siteconfig-reference.md`.

### Default `OutputProcessor` chain

When no processors are supplied, `BuildPipeline` installs this chain, in this order:

```
ImageResizer → FontAwesomeInliner → CSSBackgroundImageProcessor → AssetMinifier → AssetFingerprinter
```

Order is load-bearing (documented in `BuildPipeline.swift`): `ImageResizer` runs before `FontAwesomeInliner` (the inliner emits `<svg>`, not `<img>`, so resizing after it would be a no-op); `CSSBackgroundImageProcessor` must run **before** `AssetMinifier`, because minification strips the CSS whitespace its regex declaration-scanner relies on; `AssetFingerprinter` runs last because it hashes the final minified bytes and rewrites every reference.

⚠️ The default chain applies only while NO processor is configured explicitly. The first `.processor(_:)` call starts a fresh list – a single `.processor(X)` on a blueprint-composed builder means the site builds with `[X]` alone, silently dropping image variants, minification, and fingerprinting. To extend the defaults, pass the full chain plus your processor to `.processors(_:)`; `.processors(nil)` restores the default chain.

## Where to go next

- Add a custom HTML page type → `custom-pages.md` (concrete `Page` example end-to-end).
- Add a `.global` system renderer (sitemap variant, JSON index, redirect file) → same file, "Adding a system renderer" section.
- Wrap up a Phase-6 transformation (minifier, inliner, image processor) → see `OutputProcessor` examples under `Sources/SiteKit/Plugins/`.

Source layout for the facts above:

- `Sources/SiteKit/Pipeline/` – the phase protocols, `BuildContext`, `SiteBuilder`, `BuildPipeline`, `RenderScope`.
- `Sources/SiteKit/Plugins/` – every shipped `Loader` / `Enricher` / `Renderer` / `OutputProcessor` / `Teleporter` conformer.
- `Sources/SiteKit/Models/` – `PageModel`, `SiteConfig`, `ThemeConfig`, `UIStrings`, `Person`, `FeedData`, `ImageManifest`.
- AGENTS.md §2 – the contributor-orientation version of this pipeline (phase overview without the executor/chain depth).
