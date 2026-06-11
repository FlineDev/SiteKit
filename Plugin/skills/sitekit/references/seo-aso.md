# SEO, ASO, AEO & LLM Discoverability

SiteKit ships discoverability features as a built-in cross-cutting concern, not a bolt-on. Every HTML page goes through `PageShell` which emits canonical URLs, Open Graph, Twitter Card, JSON-LD, hreflang and RSS-discovery links. Site-wide singletons (`sitemap.xml`, `robots.txt`, `llms.txt`, machine-readable indexes) are produced by dedicated `.global` renderers.

This reference explains what is produced for you, what you can customise, and where each piece of the discoverability surface lives in the codebase. See AGENTS.md §4 *Cross-cutting concerns* for the architectural commitment.

## What every page gets, for free

`PageShell.wrap(content:page:context:)` builds a complete `<head>` for every HTML page produced by a `Page` renderer. The contributing parts:

| Piece | Source |
|---|---|
| `<title>`, `<meta description>` | Page frontmatter (`title:`, `summary:` / `description:`) |
| Canonical URL (`<link rel="canonical">`) | `context.router` per locale |
| Open Graph (`og:title`, `og:type`, `og:url`, `og:description`, `og:image`, `og:image:alt`, `og:locale`, `og:site_name`) | Page frontmatter + `SiteConfig` |
| Article-only OG (`article:published_time`, `article:author`, `article:section`) | Page frontmatter when `pageType == .article` |
| Twitter Card (`twitter:card` = `summary_large_image` if image present else `summary`, + `twitter:title`/`description`/`image`/`image:alt`) | Page frontmatter |
| JSON-LD `BlogPosting` | Built by `buildArticleJSONLD(page:canonicalURL:)` for article pages |
| JSON-LD `WebPage` | Built by `buildWebPageJSONLD(page:canonicalURL:)` for static pages (`isPartOf` the site's `WebSite`) |
| JSON-LD `WebSite` (with `SearchAction`) | Built once for the home page via `buildWebSiteJSONLD()` |
| Hreflang `<link rel="alternate" hreflang="…">` (incl. `x-default`) | `HreflangEnricher` (registered automatically on multilingual factory presets) |
| RSS auto-discovery (`<link rel="alternate" type="application/rss+xml">`) | The current section's feed URL when one is passed to `buildHead(...)` |
| Content-index discovery (`<link rel="search">` → `/assets/nav-index.json`; plus an AI-readable HTML comment) | Hardcoded in `buildHead(...)`; the comment lists the RSS feed, `/assets/nav-index.json`, `/assets/search-index.json`, and `/llms.txt` |
| Favicon links | `FaviconRenderer` output + `themeConfig.favicons` |

**Invariant:** every page produced by a `Page` renderer passes through `PageShell.wrap(...)`, so every page carries the required meta and the right canonical URL. The only escape hatch is explicitly bypassing `PageShell` in a custom `Page.renderHTML(_:context:)` – and that bypass should be documented in the renderer itself.

## Sitemap (`SitemapRenderer`)

`scope: .perLocale`. Each locale gets its own `<lang>/sitemap.xml`; multilingual sites also get a `sitemap_index.xml` at the root listing every locale's sitemap. Entries include `<lastmod>` for pages whose source file has a stable modification date.

- One entry per published page across all sections, plus listings (home, section listings, category listings, tag pages).
- Drafts are excluded automatically.
- `robots.txt` references the locale-specific sitemap so crawlers find the right entry point.

To customise (e.g. add image extensions, exclude a path), replace `SitemapRenderer` via `.renderer(...)` with your own conformer. The default `DefaultSitemapDataAdapter` is private; subclassing means producing the XML yourself.

## Robots.txt (`RobotsTxtRenderer`)

`scope: .global`. One file at the root. Defaults to `Allow: /` plus a `Sitemap:` line pointing at the appropriate sitemap (root for monolingual sites, sitemap index for multilingual).

To customise: register a replacement renderer of the same type via `.renderer(...)`; SiteKit deduplicates by type at registration, so the latest one wins.

## llms.txt (`LlmsTxtRenderer`)

`scope: .global`. An [llmstxt.org](https://llmstxt.org)-spec-compliant directory of the site's machine-readable surface – full-text RSS feeds, per-section feeds, the JSON content index, and the navigation structure. Always emitted at the site root, regardless of locale count.

This is the canonical entry point for AI agents and LLM-powered tools. It's referenced from `PageShell`'s "AI navigation" HTML comment so a crawler that lands on any HTML page can find the index in one hop.

## Content maps (`ContentIndexRenderer`)

`ContentIndexRenderer` writes a `README.md` index into each section's source directory (and `Content/Pages/`) – a read-only, human- and AI-readable map of what content exists, living in the source tree rather than the built output.

## Machine-readable JSON indexes

The JSON indexes an AI agent uses to discover content programmatically (without parsing HTML) are emitted into the built site under `/assets/`:

- **`/assets/nav-index.json`** (`NavIndexRenderer`) – the navigation/content index; it is the target of every page's `<link rel="search">`.
- **`/assets/search-index.json`** – the full-text search index referenced in each page's AI-navigation HTML comment.

Both are surfaced from `PageShell`'s `<head>` so a crawler landing on any page finds them in one hop (alongside `/llms.txt` and the RSS feed).

## RSS feeds (`RSSFeedRenderer`)

`scope: .perLocale`. Feeds are generated automatically (no per-section opt-in flag): a site-wide `feed.xml` at the root, one per section at `<urlPrefix>/feed.xml`, and one per category at `<category-slug>/feed.xml`. Items include full-text content (`<content:encoded>`), summary (`<description>`), pub date, author, and the standard RSS 2.0 channel + Atom self-link.

Podcast sections use `PodcastRSSRenderer` instead, which adds the `itunes:` namespace, episode metadata, and enclosures.

Customising RSS content (excerpt vs full-text, category mapping, custom item fields): the `DefaultFeedDataAdapter` is private to `RSSFeedRenderer`; the supported path is to write your own `Renderer` that produces the feed XML directly. Most sites do not need this – the default full-text feed is what AI agents and RSS readers expect.

## Hreflang (`HreflangEnricher`)

A Phase 3 enricher that populates `PageModel.extensions["hreflang"]` with `{locale → URL}` for every page that exists in all configured languages. `OutputFileRenderer`'s `buildHead(...)` (the head-assembly helper `PageShell.wrap` calls under the hood) reads that map and emits one `<link rel="alternate" hreflang="…">` per locale, sorted, plus an `x-default` entry pointing at the default-language URL.

`HreflangEnricher` is registered automatically by `SiteBuilder.blog`, `.podcast`, `.newsletter`, `.portfolio` and other multilingual-ready factories. To disable for a specific site, use `.removingEnricher(HreflangEnricher.self)`.

## Cloudflare `_headers` and `_redirects`

`CloudflareHeadersRenderer` (`scope: .global`) writes a root `_headers` file with sensible cache controls (immutable assets, short HTML cache, CSP-friendly defaults). `CloudflareRedirectsRenderer` writes `_redirects` from `SiteConfig.redirectsFile` if present. Both are read by Cloudflare Pages at deploy time.

## Common gotchas

**Missing OG image** – when a page has no `image:` frontmatter, `PageShell` falls back to `themeConfig.defaultImage`. Set it in `Theme/theme.yaml` so social shares always have a card image. Without a default, Twitter and Facebook fall back to text-only "summary" cards.

**Oversized meta descriptions** – keep `summary:` (or `description:`) under ~160 characters. Search engines truncate at that length and PageShell does not auto-truncate.

**Duplicate canonical URLs on multilingual sites** – `URLRouter` is locale-aware. If you build canonical URLs by hand (in a custom Page renderer that bypasses `PageShell`), make sure you derive the path through `context.router`, not by concatenating strings. The default `LocaleAwareURLRouter` already prefixes non-default locales (`/de/…`, `/ja/…`) and leaves the default locale unprefixed.

**Hreflang missing on multilingual sites** – `HreflangEnricher` only marks a page with alternates when *every* configured locale has a translation. If a post is English-only, the hreflang map is empty by design (sending crawlers to a non-existent `/de/...` would be worse than no signal at all). Use `swift run Site validate` to surface translation gaps.

**llms.txt not picked up by an AI tool** – confirm the tool actually reads `/llms.txt`. Many do, but most fall back to `sitemap.xml` or `robots.txt`. SiteKit emits all three; you do not need to choose between them.

**JSON-LD validation warnings** – Google's Rich Results Test sometimes warns about missing `image` on `BlogPosting`. Add `image:` to the article's frontmatter (or rely on `themeConfig.defaultImage`). The schema technically allows omitting it but rich-result eligibility requires it.

## ASO and AEO notes

- **ASO** (App Store Optimization): SiteKit doesn't directly affect ASO, but the AppLanding blueprint produces well-structured landing pages whose canonical URLs, OG images, and JSON-LD make them indexable, which feeds back into App Store search through web signals.
- **AEO** (Answer Engine Optimization): the JSON-LD `BlogPosting` + `WebSite` + clear h1/h2 hierarchy emitted by `PageShell` is what Google, Bing, and answer engines parse to build featured snippets. No additional configuration needed for the common cases.
- **LLM discoverability**: `/llms.txt` + `content-index.json` + the AI-navigation HTML comment in every page's `<head>` triple-redundantly tell an LLM-driven agent where to find structured data without scraping.

## Extending

To add a custom JSON-LD `@type` (e.g. `Recipe`, `Product`, `Event`) on top of the built-in `BlogPosting`:

1. Subclass or replace `ArticlePageRenderer` (it's a `Page` conformer).
2. In `renderHTML(_:context:)`, build your custom JSON-LD string and pass it through `OutputFileRenderer(context: context).buildHead(..., jsonLD: yourJSONLD)` before calling the body builder, or call `PageShell.wrap(...)` and pre-set the JSON-LD via your renderer's own head builder.

For a worked example of a custom `Page`, see `references/custom-pages.md`. The architecture and protocol semantics live in `references/architecture.md`.
