# Custom Pages and System Renderers

The most common way to extend SiteKit is to add a new **`Page`** – a custom HTML page type that participates in per-locale rendering and inherits standard site chrome. Less frequently, you add a **system `Renderer`** for non-HTML output (JSON indexes, custom feeds, redirect files).

Both protocols live in the same family: `Page` is a sub-protocol of `Renderer`. Pick `Page` when you are emitting HTML pages that should look like the rest of the site; pick `Renderer` directly when you are emitting machine-readable or site-wide output that does not need page chrome.

---

## When to write a custom Page or Renderer

| You want to… | Use |
|---|---|
| Change colors, fonts, spacing | CSS / theme tokens in `SiteConfig.yaml` / `theme.yaml` |
| Restyle existing page types | CSS (the HTML structure is already there) |
| Generate a new HTML page type (podcast episode, recipe, gallery item) | Custom `Page` |
| Generate a new output file (RSS variant, JSON feed, redirect list) | Custom `Renderer` |
| Change how an existing output file is generated | `.replacing(Old.self, with: New())` |

**Rule of thumb:** If SiteKit already generates the right HTML and you only want it to look different, use CSS. If you need different HTML or a new file type, write a `Page` (HTML) or a `Renderer` (everything else).

Custom plugins live in **your site repo** (e.g., `Sources/Site/Pages/` or `Sources/Site/Renderers/`), not inside SiteKit itself.

---

## Quick start: a complete custom `Page`

A recipe blog wants its own page type – `Content/Recipes/*.md` files rendered with a custom layout that adds prep-time and serving-size metadata above the article body. Here is the full conformer.

```swift
import Foundation
import SiteKit

public struct RecipePage: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      context.sections
         .first(where: { $0.config.slug == "recipes" })?
         .pages
         .filter { !$0.draft }
         ?? []
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let prepTime: String = page.extensionValue("prepTime") ?? "–"
      let servings: Int = page.extensionValue("servings") ?? 1

      let body = """
      <article class="recipe">
         <header>
            <h1>\(page.title.htmlEscaped)</h1>
            <p class="recipe-meta">
               🕒 Prep: \(prepTime.htmlEscaped) · 🍽️ Serves: \(servings)
            </p>
         </header>
         \(page.htmlContent)
      </article>
      """

      return PageShell.wrap(content: body, page: page, context: context)
   }
}
```

Wire it up in `Main.swift`:

```swift
try SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .renderer(RecipePage())
   .run()
```

That is the entire integration. `RecipePage` participates in per-locale rendering automatically (`Page` inherits `scope: .perLocale` from `Renderer`), routes through the standard URL router, and inherits `<head>`, `<header>`, `<footer>`, JSON-LD, Open Graph, hreflang – all of it – from `PageShell.wrap(...)`.

### What each piece does

- **`pages(in:)`** selects which pages this renderer is responsible for. Common pattern: pull pages from one declared section by `slug`, filter out drafts.
- **`renderHTML(_:context:)`** returns the *fully assembled* HTML page **including chrome**. Build the body, then wrap it with `PageShell.wrap(content:page:context:)` so it inherits the standard `<head>` / `<header>` / `<footer>`.
- **`extensionValue(...)`** reads custom frontmatter fields. Anything not in the standard `PageModel` field set is stored on `extensions` and accessible by typed lookup.
- **No `outputURL(for:context:)` override needed** for the common case – the default extension on `Page` dispatches by `page.pageType` (article path or static-page path). Override it only when you need a non-standard path (e.g., gallery items under `/gallery/<year>/<slug>/`).

### Frontmatter for a recipe page

```yaml
---
id: a2816b44
title: "Miso Glazed Salmon"
date: 2026-03-15
prepTime: "25 minutes"
servings: 4
tags: [japanese, fish, weeknight]
image: "/assets/images/recipes/miso-salmon.webp"
imageAlt: "Sliced miso-glazed salmon on a bed of rice"
summary: "A quick weeknight salmon with a sweet-savoury miso glaze."
---
```

Standard fields (`title`, `date`, `tags`, `summary`, `image`, `imageAlt`, `id`) are direct properties on `PageModel`. Custom fields (`prepTime`, `servings`) land in `extensions` and are read via `extensionValue(...)`.

---

## When you need a system `Renderer` instead

System renderers emit non-HTML output (JSON, XML, plain text, redirect files) or site-wide HTML singletons (404 page, language-redirect index). They conform to `Renderer` directly and declare a `scope`:

```swift
import Foundation
import SiteKit

public struct ArticleIndexRenderer: Renderer {
   public var scope: RenderScope { .perLocale }  // one per locale

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let articles = context.sections.flatMap(\.pages).filter { !$0.draft }

      let entries = articles.map { page in
         """
         {"title": "\(page.title.htmlEscaped)", "url": "\(context.router.articlePath(for: page))"}
         """
      }

      let json = "[\(entries.joined(separator: ",\n"))]"
      let outputPath = context.outputDirectory.appendingPathComponent("articles.json")
      return [OutputFile(outputPath: outputPath, content: json)]
   }
}
```

- Choose **`scope: .perLocale`** (the default) when the output should vary by language – per-locale RSS, per-locale `content-index.json`, the article-index above.
- Choose **`scope: .global`** when the output is a site-wide singleton – sitemap index, `robots.txt`, `llms.txt`, Cloudflare `_headers`, language-redirect HTML.

See `references/architecture.md` for the full `RenderScope` discussion.

---

## The `Page` and `Renderer` protocols

```swift
public protocol Renderer {
   var scope: RenderScope { get }
   func render(context: BuildContext) throws -> [OutputFile]
}

public protocol Page: Renderer {
   func pages(in context: BuildContext) -> [PageModel]
   func renderHTML(_ page: PageModel, context: BuildContext) -> String
   func outputURL(for page: PageModel, context: BuildContext) -> URL
}
```

`Page` provides a default `render(context:)` that walks `pages(in:)`, calls `renderHTML(...)` for each, writes to `outputURL(...)`, and returns the `OutputFile` list. You almost never override `render(context:)` on a `Page` – implement `pages(in:)` + `renderHTML` and let the protocol do the rest.

---

## `PageModel` reference

Each page (article, snippet, static page, custom-type) has these properties:

| Property | Type | Description |
|---|---|---|
| `id` | `String?` | 8-char hex identifier (unique per post) |
| `title` | `String` | Page title from frontmatter |
| `date` | `Date?` | Publication date |
| `slug` | `String` | URL slug (from filename or title) |
| `htmlContent` | `String` | Pre-rendered HTML from the Markdown body |
| `category` | `String` | Category slug (empty string if none) |
| `tags` | `[String]` | Tag slugs |
| `summary` | `String?` | Short description for listings and social sharing |
| `description` | `String?` | Longer description (falls back to summary) |
| `author` | `Person?` | Author name and optional email |
| `image` | `String?` | Featured image URL |
| `imageAlt` | `String?` | Image alt text |
| `draft` | `Bool` | Draft pages are excluded from listings |
| `pageType` | `.article` / `.staticPage` | Content type |
| `locale` | `String` | Language code (e.g., `"en"`, `"de"`) |
| `originalLanguage` | `String?` | Source language (for translations) |
| `legalDocument` | `Bool` | Whether this is a legal page (privacy, imprint) |
| `extensions` | `[String: any Sendable]` | Custom frontmatter fields (see below) |
| `readTimeMinutes` | `Int` | Computed reading time (238 wpm prose, 100 wpm code) |
| `sourcePath` | `URL` | Path to the original Markdown file |

---

## Custom frontmatter fields

Any YAML field in frontmatter that is not a standard `PageModel` field is stored in `extensions` and accessible via typed lookup:

```yaml
---
title: "Episode 42: App Store Insights"
date: 2026-03-15
audioURL: "https://example.com/ep42.mp3"
duration: "45:30"
guest: "Jane Doe"
episodeNumber: 42
---
```

```swift
let audioURL: String? = page.extensionValue("audioURL")
let duration: String? = page.extensionValue("duration")
let episodeNumber: Int? = page.extensionValue("episodeNumber")
```

Standard fields (`title`, `date`, `category`, `tags`, `summary`, `author`, `image`, `imageAlt`, `id`, `draft`, `originalLanguage`) are direct properties on `PageModel`. Everything else goes to `extensions`.

To **fail-fast** on missing required custom fields, declare them on `MarkdownLoader.requiredFields`.

---

## `BuildContext` reference

| Property | Type | Description |
|---|---|---|
| `config` | `SiteConfig` | Site configuration |
| `themeConfig` | `ThemeConfig?` | Theme token values and CSS/JS paths |
| `sections` | `[ContentSection]` | All content sections; each has `.config` and `.pages` |
| `staticPages` | `[PageModel]` | Static pages (About, Home, etc.) |
| `tags` | `[String: [PageModel]]` | All tags mapped to their pages |
| `homeContent` | `String?` | Home page HTML content (if `Home.md` exists) |
| `outputDirectory` | `URL` | Where to write output files (`_Site/`) |
| `projectDirectory` | `URL` | Project root |
| `router` | `any URLRouter` | Generates locale-aware URL paths |
| `uiStrings` | `UIStrings` | Localized UI strings |
| `draftPages` | `[PageModel]` | Drafts split out during loading; only `DraftPreviewRenderer` renders them |

**Iterating all published articles:**

```swift
let allArticles = context.sections.flatMap(\.pages).filter { !$0.draft }
```

---

## `URLRouter`

**Never hard-code URL paths.** Use `context.router` to generate consistent locale-aware paths:

| Method | Returns | Example |
|---|---|---|
| `articlePath(for: page)` | Article URL | `"/blog/my-post/"` |
| `pagePath(for: page, in: section)` | Page URL within a section | `"/snippets/my-tip/"` |
| `sectionListingPath(for: section)` | Section index | `"/blog/"` |
| `categoryPath(for: category)` | Category listing | `"/developer/"` |
| `tagPath(for: tag)` | Tag listing | `"/tags/swift/"` |
| `tagsIndexPath()` | Tags index | `"/tags/"` |
| `staticPagePath(for: page)` | Static page | `"/about/"` |
| `blogListingPath()` | Blog index | `"/blog/"` |
| `homePath()` | Home page | `"/"` |

Build full URLs by prepending `config.baseURL`:

```swift
let fullURL = "\(context.config.baseURL)\(context.router.articlePath(for: page))"
```

---

## `PageShell` – the chrome namespace

`PageShell` is the public namespace that wraps a rendered body in the standard site chrome. The primary entry point:

```swift
PageShell.wrap(content: bodyHTML, page: page, context: context)
```

It builds the `<head>` (title, description, canonical URL, Open Graph, Twitter Card, JSON-LD, hreflang, RSS discovery, preload hints for the LCP image and primary font, theme CSS in critical-path order), wraps the body in `<header>` + `<main>` + `<footer>`, and returns the full HTML page. You do not call into a "renderer helper" object – `PageShell` is a stateless namespace exposed at the top level of the SiteKit module.

### Per-page `<head>` and body customisation

`wrap(...)` takes four optional parameters beyond the common three – this is the supported way to customise page chrome (there is **no** `extensions["headHTML"]` field):

```swift
public static func wrap(
   content: String,
   page: PageModel,
   context: BuildContext,
   head: String? = nil,              // REPLACES the entire derived <head> when set
   bodyClass: String? = nil,         // REPLACES the derived <body> class when set
   dataAttributes: [String: String] = [:],  // data-* attributes on <body>
   chrome: PageChrome = .standard    // .standard = site header/footer; .appShell = body owns its own chrome
) -> String
```

- `head:` – the **complete** `<head>` content for this page. When non-nil, the standard derived head (title, description, canonical, OG, Twitter Card, JSON-LD, hreflang, theme CSS, preloads) is **not** emitted – you own the whole head. To add page-specific markup on top of the standard meta, build the base via `OutputFileRenderer(context: context).buildHead(...)` and append your extras to its return value. Pass `nil` (the default) to get the standard head.
- `bodyClass:` – the `<body>` class attribute. When non-nil it replaces the derived default (`sk-page-article` / `sk-page-static`) – include those yourself if theme CSS should keep applying, e.g. `bodyClass: "sk-page-article recipe-page"`.
- `dataAttributes:` – additional `data-*` attributes on `<body>` (e.g. `["data-layout": "wide"]`), independent of the class.
- `chrome:` – `.standard` (default) wraps the body in the generic site `<header>`/`<footer>`; `.appShell` suppresses both so a self-contained layout (like the DocC docs shell) can render its own chrome without doubling the site nav.

Optional: skip `PageShell.wrap(...)` entirely and build HTML strings from scratch – it is a convenience, not a requirement. But you lose the SEO / accessibility / preload work that the shell does for you.

### Translated strings inside a renderer (multilingual)

A `Page`/`Renderer` runs once per locale on a multilingual site, and `context` is already scoped to the current locale – `context.uiStrings` resolves chrome strings (labels, section headings) in that locale, and `context.router` emits locale-prefixed paths. Read translated UI text from `context.uiStrings` rather than hard-coding English; everything you pull off `context` (pages, tags, home content) is already the current locale's data. No per-locale branching is needed in your renderer.

---

## Output path construction

The standard pattern for emitting an HTML page:

```swift
// URL path from router (e.g. "/blog/my-post/")
let urlPath = context.router.articlePath(for: page)

// Drop leading "/" and append "index.html"
let relativePath = String(urlPath.dropFirst())
let outputPath = context.outputDirectory
   .appendingPathComponent(relativePath)
   .appendingPathComponent("index.html")

// Result: _Site/blog/my-post/index.html
```

For non-HTML files, use the filename directly:

```swift
let outputPath = context.outputDirectory.appendingPathComponent("feed.xml")
```

When conforming to `Page`, the default `outputURL(for:context:)` already does this for `.article` and `.staticPage` page types – override it only when you need a custom layout.

---

## HTML escaping

Always escape user-provided text when inserting into HTML:

```swift
page.title.htmlEscaped       // Escapes &, <, >
page.summary?.htmlEscaped    // Safe for attribute values too
```

`page.htmlContent` is already rendered HTML from the Markdown body – do **not** escape it (that would double-escape).

---

## Custom enrichers

Enrichers add computed data to pages **before** rendering. Use them when multiple renderers need the same derived data – reading time, episode number, hreflang table, promotion slot.

```swift
public protocol Enricher {
   func enrich(_ page: PageModel) throws -> PageModel
}
```

Example: adding a reading-time extension to every page:

```swift
public struct ReadingTimeEnricher: Enricher {
   public init() {}

   public func enrich(_ page: PageModel) throws -> PageModel {
      var extensions = page.extensions
      extensions["readingTimeMinutes"] = page.readTimeMinutes
      return PageModel(
         id: page.id, title: page.title, date: page.date, slug: page.slug,
         htmlContent: page.htmlContent, sourcePath: page.sourcePath,
         category: page.category, tags: page.tags, summary: page.summary,
         description: page.description, author: page.author, image: page.image,
         imageAlt: page.imageAlt, draft: page.draft, pageType: page.pageType,
         locale: page.locale, originalLanguage: page.originalLanguage,
         legalDocument: page.legalDocument, extensions: extensions
      )
   }
}
```

Wire up enrichers via `.enricher()` – they run before all renderers:

```swift
SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .enricher(ReadingTimeEnricher())
   .renderer(RecipePage())
   .run()
```

Enrichers run in registration order; SiteKit's built-in `PromotionEnricher` and `HreflangEnricher` are appended last by the blueprint factory methods.

---

## `SiteBuilder` customisation API

| Method | What it does |
|---|---|
| `.renderer(MyRenderer())` | Append a `Renderer` (`Page` included) to the pipeline |
| `.enricher(MyEnricher())` | Append an `Enricher` (runs before all renderers) |
| `.processor(MyProcessor())` | Add an `OutputProcessor` (Phase 6) – ⚠️ the first call replaces the default chain; pass the full chain to `.processors(_:)` to extend it |
| `.teleporter(MyTeleporter())` | Replace the primary `Teleporter` (Phase 0, content-independent asset copy); `.additionalTeleporter(_:)` appends one instead |
| `.removing(SomeRenderer.self)` | Remove a built-in renderer by type |
| `.replacing(Old.self, with: New())` | Replace a built-in renderer (appends if not found) |

---

## Testing a custom Page

A `Page` is two pure functions plus a default `render`, so it unit-tests without a full build. SiteKit's own tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`). The easiest target is `renderHTML(_:context:)`: build one `PageModel`, hand it a `BuildContext` assembled from a fixture config, and assert on the returned HTML.

```swift
import Testing
@testable import SiteKit

@Test func recipePageRendersMeta() throws {
   let page = PageModel(
      title: "Test Recipe", slug: "test-recipe",
      htmlContent: "<p>Body</p>", sourcePath: URL(fileURLWithPath: "/tmp/x.md"),
      extensions: ["prepTime": "10 minutes", "servings": 2]
   )
   let context = BuildContext(
      config: try SiteConfig.load(from: fixtureDir),
      themeConfig: nil, sections: [], staticPages: [], tags: [:],
      homeContent: nil,
      outputDirectory: URL(fileURLWithPath: "/tmp/out"),
      projectDirectory: fixtureDir
   )

   let html = RecipePage().renderHTML(page, context: context)
   #expect(html.contains("Prep: 10 minutes"))
   #expect(html.contains("Serves: 2"))
}
```

To exercise `pages(in:)` selection, populate `sections` with a `ContentSection(config:pages:)` whose `config.slug` matches your filter, then assert on the count `render(context:)` returns. For full-pipeline coverage, scaffold a minimal site under the test target and assert on the `_Site/` output files.

---

## `EmailRenderer` – newsletter email HTML

`EmailRenderer` is a built-in renderer (available via the SiteKit newsletter blueprint) that converts Markdown article content into newsletter-ready HTML. It is designed for the "write-once, publish-everywhere" workflow where the same Markdown source produces both a website article and an email edition.

Key characteristics:

- **Self-contained HTML**: a single HTML file with all styles inlined or in `<style>` blocks in `<head>` – no external CSS dependencies.
- **Image URLs**: kept relative in renderer output. Absolute base URL is prepended at send time, not by the renderer.
- **Dark mode**: full support via `@media (prefers-color-scheme: dark)` and Outlook `[data-ogsc]` attribute selectors.
- **Preview toggle**: a JS-powered 🌙/☀️ button for browser preview only; ignored by email clients.
- **Ad stripping**: blockquotes containing ad/promo phrases are automatically removed.
- **No copy buttons, no syntax highlighting**: both require JS or pre-rendered inline styles, neither of which is reliably supported in email clients.

See `newsletter-setup.md` for full design details and content-block behaviour.

---

## Built-in renderers shipped with `SiteBuilder.blog()`

The exact set `SiteBuilder.blog()` registers – in `SiteBuilder.blogRenderers` order:

| Renderer | Output | Scope |
|---|---|---|
| `SectionPageRenderer` | Individual content pages (articles/episodes) across every section | `.perLocale` |
| `SectionListingRenderer` | Paginated listings per section | `.perLocale` |
| `CategoryListingRenderer` | Category listing pages | `.perLocale` |
| `TagListingRenderer` | Tag listing pages | `.perLocale` |
| `StaticPageRenderer` | Static pages (About, etc.) | `.perLocale` |
| `HomePageRenderer` | Home page | `.perLocale` |
| `ErrorPageRenderer` | 404 error page | `.perLocale` |
| `RSSFeedRenderer` | RSS/Atom feeds | `.perLocale` |
| `SitemapRenderer` | Per-locale `sitemap.xml` | `.perLocale` |
| `RobotsTxtRenderer` | `robots.txt` | `.global` |
| `NavIndexRenderer` | `nav-index.json` (client-side navigation) | `.perLocale` |
| `TokenCSSOutputRenderer` | Theme CSS from token values | `.global` |
| `BaseCSSOutputRenderer` | SiteKit base CSS reset | `.global` |
| `FontsFaceCSSRenderer` | `@font-face` declarations | `.global` |
| `CloudflareHeadersRenderer` | Cloudflare `_headers` file | `.global` |
| `HTMLRedirectPageRenderer` | HTML-based redirect pages | `.global` |
| `CloudflareRedirectsRenderer` | Cloudflare `_redirects` file | `.global` |
| `LanguageRedirectRenderer` | Language-based redirect pages | `.global` |
| `FaviconRenderer` | Favicon files | `.global` |
| `LlmsTxtRenderer` | `llms.txt` (AI-readable site index) | `.global` |
| `ContentIndexRenderer` | Content search index | `.perLocale` |
| `DraftPreviewRenderer` | Draft preview pages (unlisted) | `.perLocale` |

The pipeline dispatches each renderer by its declared `scope`. Two related renderers are **not** in this list:

- **`TranslationStatusRenderer`** (`.global`) – the build instantiates it automatically on multilingual sites (writing the translation-completeness report); you do not register it.
- **`ArticlePageRenderer`** – a legacy single-blog `Page` conformer that **no preset registers**. On a `blog()` site, article pages are rendered by `SectionPageRenderer` (which handles arbitrary multi-section layouts). Target `SectionPageRenderer` – not `ArticlePageRenderer` – when using `.replacing(_:with:)` to override article rendering.
