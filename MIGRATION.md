# Migrating from v0.9.0 to v1.0.0

**Who this is for:** you have an existing SiteKit site whose `Package.swift` depends on SiteKit `< 1.0` (a `0.9.x` version or a pre-1.0 `main`-branch pin). If you're starting a brand-new site, skip this file – scaffold a fresh v1.0 site from the [README](README.md) instead.

**What v1.0 means:** the public API surface (the `SiteBuilder` factories, the phase protocols, the model types) is now stable and versioned with semver – breaking changes from here on get a major bump and a migration entry like the ones below. Each entry states what changed, why, the impact on *your* code, and a find/replace recipe an AI agent can act on.

## At a glance

Triage table – scan the **Action** column and skip every row that says "None". The two hard breaks that affect *every* site are the **dependency URL** and the **`Page` → `PageModel`** rename; most other breaks only apply if you wrote custom renderers or constructed `BuildPipeline` directly. Severity legend: 🔴 breaking · 🟡 breaking only for specific callers / deprecation · 🟢 additive (no action) · ⚪ internal (no action).

| Area | Change | Type | Action needed |
|---|---|---|---|
| Public API | Dependency URL `SiteKit-Package` → `SiteKit` | 🔴 Breaking (all) | Update the `.package(url:)` in `Package.swift` |
| Public API | `Page` model → `PageModel` | 🔴 Breaking (all) | Rename `Page` (the model) → `PageModel` across your code |
| Architecture | `Page: Renderer` sub-protocol for HTML pages | 🔴 Breaking (custom HTML renderers) | Migrate `Renderer` → `Page`; implement `pages(in:)` + `renderHTML` |
| Architecture | `RenderScope` on `Renderer` | 🔴 Breaking (custom system renderers) | Declare `scope: .global` on site-wide renderers |
| Public API | `BuildContext` legacy `articles:`/`snippets:` init removed | 🔴 Breaking (direct constructors) | Build `sections: [ContentSection]` and pass `sections:` |
| Public API | `Adapter` protocol deleted | 🔴 Breaking (if conformed) | Replace/subclass `RSSFeedRenderer` / `SitemapRenderer` |
| Public API | `MarkdownLoaderError.missingRequiredField` payload changed | 🔴 Breaking (if caught) | Catch `(field, path, line)` or use `localizedDescription` |
| Public API | `BuildPipeline.init` label `assetProcessor:` → `teleporter:` | 🔴 Breaking (direct `BuildPipeline`) | Rename the argument label |
| Architecture | `StaticPageLoader` error aligned with `MarkdownLoader` | 🔴 Breaking (if caught) | Catch `MarkdownLoaderError.missingRequiredField` |
| Architecture | `PromotionSelector` → `PromotionEnricher` | 🔴 Breaking (if used directly) | Read `page.extensions["promotion"]` or register a custom `Enricher` |
| Architecture | `TranslationStatus.check` gains `sections:` | 🟡 Breaking (direct callers) | Pass `config.effectiveSections` |
| Skills | Skill folders consolidated into one `sitekit` skill | 🟡 Breaking (skill invocation) | Replace `/onboarding:setup-new-site` with the `sitekit` skill |
| Public API | `URLRouter` snippet methods deprecated | 🟡 Deprecation (warns, still compiles) | Move to section-aware `pagePath` / `sectionListingPath` |
| Architecture | Required-field validation at `MarkdownLoader` | 🟡 Behavioral | Ensure posts have `title:` + `date:` (or filename date) |
| Public API | `BuildPipeline` default renderer list reconciled | 🟡 Behavioral (direct `BuildPipeline`) | Expect extra output files, or pass `renderers:` explicitly |
| Public API | `loadBaseCSS()` / `loadDocCCSS()` / `loadScript()` bundled-resource loaders: `-> String?` → `throws -> String` | 🟡 Breaking (direct callers) | Wrap in `try`; a missing bundled resource now fails the build instead of silently skipping output |
| Public API | `Page.pagesIn(context:)` → `pages(in:)` | 🔴 Breaking (custom HTML renderers) | Rename the method in `Page` conformers; call sites become `pages(in: context)` |
| Public API | `Teleporter.copyDirect(from:to:)` → `copy(from:into:)` | 🔴 Breaking (custom teleporters) | Rename the method in `Teleporter` conformers |
| Public API | `configPath:` factories now load the named file | 🟡 Behavioral (non-default paths only) | None for the standard `"SiteConfig.yaml"`; a custom path now actually loads that file |
| Public API | CLI errors report one line and exit 1 | 🟡 Behavioral | None – replaces the Swift runtime's top-level trap (exit 133) |
| Public API | Renderer failures throw `BuildPipelineError.renderersFailed` | 🟡 Breaking (if matched) | Match the new case instead of `NSError` domain `"BuildPipeline"` |
| Public API | Internal helper types demoted from `public` | 🟡 Breaking (direct users) | See the demotion list – these were undocumented implementation detail |
| Architecture | `HreflangEnricher` via public enricher chain | 🟢 Additive | None (factories still wire it) |
| Architecture | Optional `slug:` frontmatter override | 🟢 Additive | None |
| Architecture | `PageShell.wrap` dispatches canonical / JSON-LD by `pageType` | 🟢 Additive | None (custom renderers get correct output for free) |
| Architecture | `CloudflareHeadersRenderer` no longer per-locale | 🟢 Additive | None |
| Architecture | `SiteConfig` accepts `language` / `defaultLanguage` + optional fields | 🟢 Additive | None |
| Public API | `YAMLLoader` is the canonical YAML path | 🟢 Additive (recommended) | Optional: route custom YAML loads through `YAMLLoader` |
| Public API | `S-I-R` marker protocols deleted | 🟢 Additive | None |
| Tooling | `sitekit` CLI added | 🟢 Additive | None (new capability) |
| Documentation | `Agents/` deleted entirely; Theme Preview HTML added | ⚪ Internal | None – contributor-facing only |

The per-change detail follows, grouped by subsystem.

## Architecture

### HreflangEnricher now runs through the public enricher chain

Previously `HreflangEnricher` was hardwired into `BuildPipeline.buildMultilingual()`, bypassing the user-registered enricher chain. It is now registered like any other Enricher when a multilingual `SiteBuilder` is constructed.

**Impact for external users:** none if you used the `SiteBuilder.blog(...)` factory – hreflang continues to work for multilingual sites. If you constructed a `BuildPipeline` directly without `HreflangEnricher` in the enricher list, you must add it explicitly.

To disable hreflang generation:

```swift
SiteBuilder.blog(config: config, projectDirectory: projectDirectory)
    .removingEnricher(HreflangEnricher.self)
    // ...
```

*Note:* The same `HreflangEnricher` registration also applies to the other preset factories (`podcast`, `newsletter`, `portfolio`, `docs`) when the site is multilingual. The recipe above shows blog as the most common case; substitute the matching factory name for other site types.

### Translation status now covers all sections, not just Blog and Pages

`TranslationStatus.check` previously hardcoded the literal section names `"Blog"` and `"Pages"`. It now takes a `sections: [SectionConfig]` parameter (typically `SiteConfig.effectiveSections`) and walks each section's `contentDirectory` plus an optional `staticPagesDirectory` (defaulting to `"Pages"` for back-compat). Duplicate directories are visited only once.

**Impact for external users:** if your site has a section other than `"Blog"` or `"Pages"` (e.g. `"Articles"`, `"Lessons"`, `"Notes"`), translation status now reports on it correctly. No code change required when going through `SiteBuilder` – the builder passes `effectiveSections` for you. Direct callers of `TranslationStatus.check(...)` must add the new `sections:` argument:

```swift
// Before
let missing = TranslationStatus.check(
    contentDirectory: contentDir,
    defaultLanguage: "en",
    targetLanguages: ["de"],
    localizedDiscovery: discovery
)

// After
let missing = TranslationStatus.check(
    contentDirectory: contentDir,
    defaultLanguage: "en",
    targetLanguages: ["de"],
    localizedDiscovery: discovery,
    sections: config.effectiveSections
)
```

### Required-field validation at Loader level

`MarkdownLoader` now accepts a `requiredFields: [String]` parameter (default `["title", "date"]`). After parsing frontmatter, the loader rejects any markdown file that is missing a required field – or whose value is an empty string – with a build error of the form:

```
Error: <path>:<line>: required frontmatter field 'X' is missing or empty
```

`"date"` is a special case: it is also accepted when the filename matches the `YYYY-MM-DD-slug.md` convention even if the frontmatter omits `date:`.

Each `SiteBuilder` preset factory now wires the appropriate required fields automatically:

| Factory | Required fields |
|---|---|
| `.blog(...)` | `["title", "date"]` |
| `.newsletter(...)` | `["title", "date"]` |
| `.portfolio(...)` | `["title", "date"]` |
| `.podcast(...)` | `["title", "date", "audioURL", "duration"]` |

**Customising required fields:**

```swift
SiteBuilder.blog(config: config, projectDirectory: dir)
    .articleLoader(MarkdownLoader(requiredFields: ["title", "date", "category"]))
```

To disable validation entirely (not recommended):

```swift
SiteBuilder.blog(config: config, projectDirectory: dir)
    .articleLoader(MarkdownLoader(requiredFields: []))
```

**Impact for external users:** none if your articles already declare `title:` and `date:` (or rely on the filename-date convention). Any post that previously rendered with a silently-missing field now fails the build with the file path and line number – fix the typo and rebuild.

### Optional `slug:` frontmatter override

`MarkdownLoader` now honours an explicit `slug:` field in the frontmatter, allowing content authors to override the auto-derived slug. The resolution order is:

1. `frontmatter["slug"]` if set
2. Filename-derived slug if the file matches `YYYY-MM-DD-slug.md`
3. `title.slugified(language:)` as the last fallback

```markdown
---
title: "AsyncMutex one-liner"
date: 2026-04-12
slug: async-mutex-one-liner
---
```

Without the `slug:` override the same file would yield `asyncmutex-one-liner` (because `slugified` lowercases the PascalCase token without splitting it).

**Impact for external users:** purely additive – articles that don't set `slug:` keep their existing behaviour byte-for-byte. The override exists so authors can publish a stable URL even when the title is later edited.

### `PageShell.wrap` now dispatches canonical URL + JSON-LD by `pageType`

Custom `Page` renderers that follow the documented recipe of calling `PageShell.wrap(content:page:context:)` previously received a `<head>` that always used `context.router.articlePath(for:)` for the canonical URL and emitted no `<script type="application/ld+json">` at all. Two consequences:

- A custom `.staticPage` renderer (e.g. an "About" or "Privacy" page) shipped a wrong canonical URL pointing inside the blog section.
- All custom renderers – both `.article` and `.staticPage` – lost the structured-data block that the built-in renderers attach via their own `buildHead` calls.

`PageShell.defaultHead` now switches on `page.pageType`:

- `.article` → canonical from `articlePath(for:)`, JSON-LD from `buildArticleJSONLD(page:canonicalURL:)` (a `BlogPosting` schema).
- `.staticPage` → canonical from `staticPagePath(for:)`, JSON-LD from the new `buildWebPageJSONLD(page:canonicalURL:)` (a `WebPage` schema).

**Impact for external users:** no change for built-in `Page` renderers (they already build their own `<head>` and never went through the `defaultHead` path). Custom renderers that call `PageShell.wrap` without passing `head:` start producing the correct canonical and a populated JSON-LD block immediately on the next build. Custom renderers that already pass an explicit `head:` argument continue to use that override verbatim.

### `StaticPageLoader` validation aligned with `MarkdownLoader`

`StaticPageLoader` now accepts a `requiredFields: [String]` parameter (default `["title", "slug"]`) that mirrors `MarkdownLoader`'s contract, and raises the same `MarkdownLoaderError.missingRequiredField(field:sourcePath:line:)` shape on a missing or empty field. The error message format `Error: <path>:<line>: required frontmatter field 'X' is missing or empty` is identical across both loaders.

The previous `StaticPageLoaderError.missingRequiredField(String)` enum is removed.

```swift
// Default – same as v0.9
SiteBuilder.blog(config: config, projectDirectory: dir)
    .staticPageLoader(StaticPageLoader())

// Require an additional field on every static page
SiteBuilder.blog(config: config, projectDirectory: dir)
    .staticPageLoader(StaticPageLoader(requiredFields: ["title", "slug", "description"]))
```

**Impact for external users:** if you currently `catch StaticPageLoaderError.missingRequiredField(let field)`, switch to `catch MarkdownLoaderError.missingRequiredField(let field, _, _)`. If you have no such catch block – most callers don't – your build behaviour is unchanged: static pages still require `title` and `slug` by default, and a missing field still fails the build with a file path and line number.

### Page sub-protocol introduced

The `Renderer` protocol now has a sub-protocol `Page: Renderer` for HTML page rendering. `Page` conformers implement two methods – `pages(in:)` (which pages this renderer handles) and `renderHTML(_:context:)` (the fully-rendered HTML for one page) – plus an optional `outputURL(for:context:)` (the destination path; default dispatches by `page.pageType`).

The default `render(context:)` extension iterates `pages(in:)`, calls `renderHTML` for each page, and emits one `OutputFile` per page via `outputURL`. Cross-cutting page chrome (`<head>` with SEO/OG/JSON-LD/hreflang, `<header>` nav, `<footer>`, theme CSS, performance preloads) is applied by `PageShell.wrap(...)`, which renderers call inside `renderHTML`. AI agents writing custom HTML pages get a clear customisation surface: conform to `Page`, write `renderHTML`, optionally call `PageShell.wrap(...)`.

The method is named `renderHTML` (not `renderContent`) because the return value is the full HTML document including chrome – what gets written to disk. `PageShell.wrap(content:page:context:)` is a separate helper whose `content:` argument *is* the body-only content; callers wanting the body+chrome split use `wrap` from inside their `renderHTML` implementation. Keeping the two terms distinct makes the API contract self-documenting: `renderHTML` returns HTML, `PageShell.wrap` accepts content and returns HTML.

The 12 built-in HTML page renderers of the blog/podcast/portfolio blueprints now conform to `Page`: `HomePageRenderer`, `ArticlePageRenderer`, `StaticPageRenderer`, `TemplateStaticPageRenderer`, `SectionListingRenderer`, `SectionPageRenderer`, `CategoryListingRenderer`, `ErrorPageRenderer`, `PodcastHomePageRenderer`, `PodcastEpisodeRenderer`, `PodcastListingRenderer`, `DraftPreviewRenderer` – as do the 7 DocC pages that shipped with the DocC blueprint (`DocCHomePage`, `DocCYearListingPage`, `DocCArticlePage`, `DocCContributorsPage`, `DocCContributorPage`, `DocCMissingPage`, `DocCSearchPage`).

Non-HTML / system output renderers (sitemap, robots.txt, RSS feeds, JSON indexes, CSS, redirects, headers) continue to conform to `Renderer` directly.

**Find/replace recipe for custom HTML page renderers:**

```swift
// Before
public struct MyCustomPageRenderer: Renderer {
   public func render(context: BuildContext) throws -> [OutputFile] {
      var outputs: [OutputFile] = []
      for page in /* your filter */ {
         let body = /* your body HTML */
         let html = OutputFileRenderer(context: context).renderPageShell(
            head: /* head string you built */,
            bodyClass: "my-page",
            content: body
         )
         let outputPath = context.outputDirectory
            .appendingPathComponent(/* your path */)
            .appendingPathComponent("index.html")
         outputs.append(OutputFile(outputPath: outputPath, content: html))
      }
      return outputs
   }
}

// After
public struct MyCustomPageRenderer: Page {
   public func pages(in context: BuildContext) -> [PageModel] {
      /* your filter */
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let body = /* your body HTML */
      return PageShell.wrap(content: body, page: page, context: context, bodyClass: "my-page")
   }

   // Optional – override only if your output path differs from the
   // pageType default (`.article` → articlePath, `.staticPage` → staticPagePath).
   public func outputURL(for page: PageModel, context: BuildContext) -> URL {
      /* your custom path */
   }
}
```

The `Page` model struct is renamed to `PageModel`; the `Page` name is now the user-facing protocol for HTML page rendering. See the *Public API* section below.

### RenderScope on Renderer

The `Renderer` protocol now declares `var scope: RenderScope { get }` with a protocol-extension default of `.perLocale`. The new `RenderScope` enum has two cases:

- `.perLocale` – the renderer runs once per locale on multilingual builds and produces per-locale output files (article HTML, listings, per-locale feeds, per-locale JSON indexes).
- `.global` – the renderer runs exactly once per build, regardless of locale count, and produces site-wide output files (sitemap.xml, robots.txt, llms.txt, Cloudflare `_headers` and `_redirects`, theme CSS/fonts/favicons, translation-status.json).

System renderers that declared `.global` at this migration: `RobotsTxtRenderer`, `LlmsTxtRenderer`, `CloudflareHeadersRenderer`, `CloudflareRedirectsRenderer`, `TranslationStatusRenderer`, `BaseCSSOutputRenderer`, `TokenCSSOutputRenderer`, `FontsFaceCSSRenderer`, `FaviconRenderer`, `HTMLRedirectPageRenderer`, `LanguageRedirectRenderer`. (The DocC blueprint later added its own `.global` renderers – the sidebar/search/script/stylesheet set – so this list is the migration-time snapshot, not the current total.) `SitemapRenderer` is `.perLocale` because its `render(context:)` derives the output path from `context.router.homePath()` to emit one `<lang>/sitemap.xml` per locale plus a single `sitemap_index.xml` listing them all.

**Find/replace recipe for custom system renderers:**

```swift
// Before
public struct MyCustomSystemRenderer: Renderer {
   public func render(context: BuildContext) throws -> [OutputFile] {
      // produces a single file regardless of locale
   }
}

// After
public struct MyCustomSystemRenderer: Renderer {
   public var scope: RenderScope { .global }
   public func render(context: BuildContext) throws -> [OutputFile] {
      // unchanged
   }
}
```

Per-locale renderers (the default) do not need to declare `scope`. `BuildPipeline.buildMultilingual` uses the declared scope to decide invocation cardinality: `.global` renderers run exactly once after the per-locale loop, `.perLocale` renderers run inside the loop with each locale's `BuildContext`.

### CloudflareHeadersRenderer no longer regenerated per locale

`CloudflareHeadersRenderer` declares `scope: .global` (it produces a single root-level `_headers` file with no locale-specific content). On multilingual sites it is invoked exactly once per build, regardless of locale count.

`BuildPipeline.buildMultilingual` now partitions `self.renderers` by `Renderer.scope`: `.perLocale` renderers run inside the per-locale loop, `.global` renderers run exactly once after it. The hardcoded type-name set is gone.

**Impact for external users:** none for output content. Build logs no longer show `CloudflareHeadersRenderer` (and other `.global` system renderers) repeating per locale.

### PromotionSelector is now PromotionEnricher

The static utility `PromotionSelector` is replaced by a real `Enricher` conformer named `PromotionEnricher`. It writes the selected promotion into `Page.extensions["promotion"]`, which renderers read.

**Impact for external users:**

- If you used `PromotionSelector.select(...)` directly, that call site no longer exists. Read `page.extensions["promotion"]` instead.
- To customise promotion logic, write a custom `Enricher` and register it in place of `PromotionEnricher` in the chain.

### SiteConfig now accepts both `language` and `defaultLanguage` keys

`SiteConfig`'s `init(from:)` accepts:

- The canonical `language:` key (preferred).
- The legacy/alternative `defaultLanguage:` key (fallback when `language` is absent).

When both are present, `language:` wins.

Also: `description`, `assetsDirectory`, and `categories` are now optional in the YAML (decode with sensible defaults: empty string, `"Content/Assets"`, empty array respectively). The Swift property types remain non-optional.

**Impact for external users:** none. Existing strict-shaped `SiteConfig.yaml` files continue to decode identically. The lenience only adds new accepted shapes for minimal/scaffolded configs.

**Find/replace recipe:** none needed – this is a decoder-side lenience addition.

## Public API

### Page model renamed to PageModel

The struct previously called `Page` (the loaded page data model) is renamed to `PageModel`. The `Page` name is now the user-facing protocol for HTML page rendering (see the *Architecture* section above).

**Find/replace recipe (codebase-wide):**

| Before | After |
|---|---|
| `struct Page` | `struct PageModel` (the SiteKit model, not your code) |
| `let page: Page` | `let page: PageModel` |
| `[Page]` | `[PageModel]` |
| `func enrich(_ page: Page) -> Page` | `func enrich(_ page: PageModel) -> PageModel` |
| `Loader<MarkdownSource, Page>` | `Loader<MarkdownSource, PageModel>` |
| `: Page` (when you meant to use the model as a value type) | `let page = PageModel(...)` – use as a value, not a conformance |
| `: Page` (when you intend to conform to the new protocol) | unchanged – implement `pages(in:)` and `renderHTML(_:context:)` |

A safe approach is a word-boundary find/replace across your project (`\bPage\b` → `PageModel`), then revert any matches that occur in English string literals (e.g. log messages that read "Page 'My Title' has no id") or in cases where the new `Page` protocol is what you mean. The compiler will catch any missed sites.

### Dependency URL changed

The Swift package previously lived at `https://github.com/FlineDev/SiteKit-Package.git`. It now lives in the merged umbrella repo at `https://github.com/FlineDev/SiteKit.git`. Both `Package.swift` and the Claude Code marketplace manifest (`.claude-plugin/marketplace.json`) are at the repo root; the plugin itself lives under `Plugin/` with its own `.claude-plugin/plugin.json`.

**Find/replace recipe for sites:**

```swift
// Before
.package(url: "https://github.com/FlineDev/SiteKit-Package.git", branch: "main")

// After
.package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0")
```

The old `SiteKit-Package` repo will remain in archived state with a redirect notice until the next minor release, then it will be deleted.

### URLRouter protocol surface shrank

`snippetPath(for:)` and `snippetsListingPath()` are removed from the `URLRouter` protocol declaration. They remain as `@available(*, deprecated, ...)` methods on `DefaultURLRouter` and `LocaleAwareURLRouter` so v0.9.0 callers still compile, but emit a compile-time deprecation warning pointing at the modern section-aware API.

**Find/replace recipe for sites using snippets:**

```swift
// Before – implicitly tied to a "snippets" hardcoding
let path = urlRouter.snippetPath(for: page)
let listing = urlRouter.snippetsListingPath()

// After – pass the SectionConfig the site already declares
let snippetsSection = config.effectiveSections.first { $0.slug == "snippets" }!
let path = urlRouter.pagePath(for: page, in: snippetsSection)
let listing = urlRouter.sectionListingPath(for: snippetsSection)
```

If you implemented a custom `URLRouter`, you can drop your `snippetPath` / `snippetsListingPath` overrides – the protocol no longer requires them.

### BuildContext legacy init removed

The `BuildContext` initialiser that accepted `articles:` / `snippets:` arrays and synthesised hardcoded `Blog` / `Snippets` `SectionConfig`s is removed. All construction must go through the modern `BuildContext.init(config:themeConfig:sections:staticPages:tags:homeContent:router:uiStrings:outputDirectory:projectDirectory:draftPages:)` which reads sections from the supplied `SiteConfig`.

**Find/replace recipe:**

```swift
// Before
let context = BuildContext(
    config: config,
    themeConfig: themeConfig,
    articles: articles,
    snippets: snippets,
    staticPages: staticPages,
    tags: tags,
    homeContent: homeContent,
    outputDirectory: outputDirectory,
    projectDirectory: projectDirectory
)

// After
let sections: [ContentSection] = [
    ContentSection(config: blogSection, pages: articles),
    ContentSection(config: snippetsSection, pages: snippets),
]
let context = BuildContext(
    config: config,
    themeConfig: themeConfig,
    sections: sections,
    staticPages: staticPages,
    tags: tags,
    homeContent: homeContent,
    outputDirectory: outputDirectory,
    projectDirectory: projectDirectory
)
```

If you only constructed `BuildContext` via `SiteBuilder`, no action needed – the builder already passes `sections`.

### Adapter public protocol deleted

The `Adapter` protocol was documented as a peer pipeline concept but had no `.adapter()` swap point on `SiteBuilder`. The two conformers (`DefaultFeedDataAdapter`, `DefaultSitemapDataAdapter`) are now private nested types inside `RSSFeedRenderer` and `SitemapRenderer` respectively.

**Impact for external users:** if you wrote a custom type conforming to `Adapter`, that conformance no longer compiles. Customising RSS/Sitemap data shaping now means subclassing or replacing the entire `RSSFeedRenderer` / `SitemapRenderer`.

### YAMLLoader is the canonical YAML loading path

`SiteConfig.load(...)` already routes through `YAMLLoader<SiteConfig>`. The `LandingPageRenderer` templates in `Plugin/blueprints/AppLanding/` and TranslateKit's site now follow the same pattern – no more direct `YAMLDecoder()` calls in renderers.

**Find/replace recipe for custom renderers loading YAML:**

```swift
// Before
let yamlData = try Data(contentsOf: yamlPath)
let decoder = YAMLDecoder()
let value = try decoder.decode(MyType.self, from: yamlData)

// After
let source = try YAMLSource(url: yamlPath)
let loader = YAMLLoader<MyType>()
let value = try loader.load(source: source)
```

Both forms produce identical results; the new form goes through the SiteKit pipeline's structured-data loader and removes the implicit `import Yams` dependency from renderer code.

### MarkdownLoaderError.missingRequiredField enum shape changed

`MarkdownLoaderError.missingRequiredField` previously carried a single `String` payload (the field name). It now carries `field`, `sourcePath`, and `line`, and conforms to `LocalizedError` so that printing the error (e.g. via `print(error.localizedDescription)`) produces a build-friendly message that pinpoints the offending file and line.

**Find/replace recipe:**

```swift
// Before
} catch MarkdownLoaderError.missingRequiredField(let name) {
    print("missing: \(name)")
}

// After
} catch MarkdownLoaderError.missingRequiredField(let field, let path, let line) {
    print("missing: \(field) at \(path):\(line)")
}

// Or just let LocalizedError do the formatting:
} catch let error as MarkdownLoaderError {
    print(error.localizedDescription)
    // → "Error: /Content/Blog/2026-01-01-test.md:2: required frontmatter field 'date' is missing or empty"
}
```

If the YAML parser doesn't track precise line positions, the line number is best-effort and defaults to `2` (the standard frontmatter convention). `MarkdownSource` now exposes an optional `frontmatterStartLine: Int?` for parsers that do track it.

### S-I-R marker protocols deleted

`SourceType`, `IntermediateType`, and `ResultType` were marker protocols that constrained nothing – they appeared nowhere as type bounds. They've been deleted. The concrete types (`MarkdownSource`, `YAMLSource`, `Page`, `OutputFile`) stay; only their phantom conformances disappear.

**Impact for external users:** none expected. If you happened to reference these protocols (`where T: SourceType`), remove the constraint – your code probably worked anyway.

### BuildPipeline.init parameter label renamed assetProcessor → teleporter

The parameter type is `Teleporter` and the storing property in `SiteBuilder` is `teleporter`; the `assetProcessor:` argument label was a residue from the pre-Teleporter rename and is renamed to match.

**Find/replace recipe (only relevant if you construct `BuildPipeline` directly, not via `SiteBuilder`):**

```swift
// Before
BuildPipeline(/* ... */, assetProcessor: myTeleporter, /* ... */)

// After
BuildPipeline(/* ... */, teleporter: myTeleporter, /* ... */)
```

### BuildPipeline default renderer list reconciled

`BuildPipeline.init`'s default `renderers:` parameter now references `SiteBuilder.blogRenderers` instead of an inline 17-element list. The inline list silently omitted five renderers (`BaseCSSOutputRenderer`, `FontsFaceCSSRenderer`, `CloudflareHeadersRenderer`, `ContentIndexRenderer`, `DraftPreviewRenderer`) – anyone constructing `BuildPipeline` directly without supplying `renderers:` got a thinner default than `SiteBuilder.blog(...)`. Two sources of truth, future bug source.

**Impact for external users:**

- Sites using `SiteBuilder.blog(...)` (or any other preset factory) see no change – the preset already passed `blogRenderers` explicitly.
- Direct callers of `BuildPipeline(siteConfig: ..., projectDirectory: ...)` without an explicit `renderers:` now produce additional output files: `assets/css/base.css`, `assets/theme/fonts.css`, `_headers`, `assets/nav-index.json` plus content-index/draft-preview artifacts. If you actively want a thinner set, pass `renderers:` explicitly.

### Bundled-resource loaders now throw instead of returning an optional

`BaseCSSOutputRenderer.loadBaseCSS()`, `DocCStylesheetRenderer.loadDocCCSS()`, and the seven `DocC*ScriptRenderer.loadScript()` methods changed from `-> String?` to `throws -> String`. Previously a missing bundled resource – typically an incomplete or mid-build-modified `.build` directory – made these loaders return `nil`, and the build silently skipped the affected CSS or JavaScript output. They now throw a `BundledResourceError` that names the missing file, so the same build run fails with a nonzero exit instead of deploying a site without its styles or scripts.

**Find/replace recipe (only relevant if you call a loader directly – the built-in renderers are already updated):**

```swift
// Before
if let css = BaseCSSOutputRenderer.loadBaseCSS() {
    // use css
}

// After
let css = try BaseCSSOutputRenderer.loadBaseCSS()
```

**Related behavioral change:** `serve` now applies the default output-directory clean exactly like `build` always did when `--no-clean` is absent – overriding a programmatic `cleanBeforeBuild: false` set through a factory (e.g. `.docc(configPath:cleanBeforeBuild:)`), which `serve` previously left in effect. Pass `--no-clean` on the command line to keep a pre-built output directory.

### Page requirement renamed: pagesIn(context:) → pages(in:)

The `Page` protocol requirement `pagesIn(context:)` is now `pages(in:)`, following the Swift API Design Guidelines (the preposition moves into the argument label, so the call site reads `renderer.pages(in: context)`).

**Find/replace recipe for custom `Page` conformers:**

```swift
// Before
public func pagesIn(context: BuildContext) -> [PageModel] { ... }

// After
public func pages(in context: BuildContext) -> [PageModel] { ... }
```

Call sites change from `pagesIn(context: context)` to `pages(in: context)`. The compiler enforces completeness: a conformer still declaring `pagesIn(context:)` no longer satisfies the protocol and fails to build.

### Teleporter requirement renamed: copyDirect(from:to:) → copy(from:into:)

The `Teleporter` protocol requirement `copyDirect(from:to:)` is now `copy(from:into:)`. "copyDirect" was not a natural verb phrase; the renamed pair reads grammatically at the call site and the preposition encodes the destination semantics: `copy(from:to:)` targets the site output root and applies the default asset layout, `copy(from:into:)` writes directly into the given directory.

**Find/replace recipe for custom `Teleporter` conformers:**

```swift
// Before
public func copyDirect(from sourceDirectory: URL, to destinationDirectory: URL) throws { ... }

// After
public func copy(from sourceDirectory: URL, into destinationDirectory: URL) throws { ... }
```

### configPath: convenience factories now honor their path argument

`SiteBuilder.blog/portfolio/newsletter/podcast/docc(configPath:)` previously ignored the `configPath` parameter and always loaded `SiteConfig.yaml` from the working directory. The parameter is now honored: the path resolves relative to the working directory (absolute paths are honored as-is) and the named file is loaded via the new `SiteConfig.load(contentsOf:)`. Sites passing the standard `"SiteConfig.yaml"` literal – every scaffolded blueprint – see no change; a site that passed a different path now gets the configuration it asked for.

### CLI errors now exit 1 with a single error line

`run()` catches every error thrown by the dispatched command (build, serve, validate), reports it as one error line, and exits with code 1 – the same surface as argument errors like a malformed `--base-url`. The `configPath:` factories do the same for configuration loading failures (missing file, YAML decode error). Previously these errors escaped the site's top-level `try ….run()` and the Swift runtime trapped with SIGTRAP (exit 133) and a "Fatal error: Error raised at top level" line. Exit-code-gated deploys behave the same (nonzero either way); log scrapers see a cleaner line.

### Renderer failures aggregate into BuildPipelineError.renderersFailed

When one or more renderers fail, `BuildPipeline.build()` now throws `BuildPipelineError.renderersFailed([(renderer: String, error: any Error)])` instead of an `NSError` with domain `"BuildPipeline"` whose message only carried the failure count. The new case preserves every underlying error, and its description names each failing renderer with its cause – so the final error line stays actionable even when the per-renderer log lines scrolled away.

### Internal helper types are no longer public

These types were `public` by accident – no documentation example, blueprint, or skill reference ever used them – and are now `internal`, shrinking the semver-stable 1.0 surface: `SelectorMatcher`, `TokenCSSGenerator`, `DocCSearchIndex` / `DocCSearchRecord` / `DocCNoteType`, `DocCNavigationTree` / `DocCNavNode` / `DocCTopicGroup` / `DocCContributorLink`, `DocCReservedRoutes`, `DocCSidebarRenderer`, `CodeHighlighter`, `FrontmatterParser` / `FrontmatterParserError`. If you relied on one of them, copy the implementation into your site or open an issue describing the use case – the documented extension surface (`Page`, `Renderer`, `OutputFileRenderer`, `PageShell`, the phase protocols) is unchanged.

## Tooling

### `sitekit` command-line tool added

SiteKit's `Package.swift` now ships an executable product, `sitekit`, alongside the `SiteKit` library. It is the deterministic, scriptable substrate for installing SiteKit and scaffolding sites – the mechanical counterpart to the judgment-heavy `sitekit` Claude Code skill. Run it from a SiteKit clone with `swift run sitekit <command>`.

v1.0 surface (a deliberately conservative, durable public contract):

| Command | Behaviour |
|---|---|
| `sitekit doctor` | Checks `git`, `swift` (≥ 6.2), and `gh` (optional, warn-only). Exits non-zero on a missing hard prerequisite. |
| `sitekit blueprints` | Lists the 9 starter blueprints with one-line descriptions. |
| `sitekit new <name> --blueprint <X>` | Scaffolds a new site by copying a blueprint, excluding `.build/`, `.git/`, `_Site/`, `.DS_Store`, `*.xcodeproj`, `.swiftpm/`. `--blueprint` defaults to `Blog`; `--list-blueprints` is an alias for `sitekit blueprints`. Refuses a non-empty target. |
| `sitekit update` | In a site directory: bumps the version-pinned SiteKit dependency in `Package.swift` (to `--to <version>`, or to the version this CLI ships with), runs `swift package update`, points at this file. **Does not auto-apply migration recipes** – that is v1.1+. |
| `sitekit --version` | Prints the CLI version (which is the SiteKit version it ships with). |

**Impact for external users:** none – this is purely additive. The `SiteKit` library target is unchanged, so existing sites build identically. New users (and the AI agents driving them) get a deterministic scaffold path instead of manual blueprint copying.

**Implementation note for contributors:** the executable *product* is `sitekit` but its *target* is `SiteKitCLI` (sources under `Sources/SiteKitCLI/`). A target literally named `sitekit` collides with the `SiteKit` library target on a case-insensitive filesystem – at both the `Sources/` directory and the `.build/` intermediate level. `swift run sitekit` resolves the product name, so the public command is unaffected.

## Documentation

### Agents/ deleted entirely

The legacy `Agents/` directory is removed in two steps. First the `Agents/Core/` subtree went (10 files: Build.md, Content.md, ContentGuide.md, MigrationGuide.md, Onboarding.md, PluginReference.md, README.md, Recipes.md, SocialSharingGuide.md, ThemeGuide.md) – its content was pre-rename stale and taught non-existent protocol names. The remaining four files (README.md, Advanced/README.md, Advanced/Localization.md, Optional/README.md) followed for the 1.0 release: they still described the deleted S-I-R architecture, advertised never-written "planned skills", and duplicated the maintained localization reference. The architectural reference is the umbrella `AGENTS.md` plus the consolidated `Plugin/skills/sitekit/` skill (localization detail: `references/localization.md`).

### Theme Preview HTML system added

`Plugin/themes/ThemePreview.html` lets users compare full-layout themes (Classic, Sidebar, Minimal) × representative colorSchemes × fontPairings × light/dark mode at a glance. Per-variant HTML files live in `Plugin/themes/preview/` and are produced by real SiteKit builds of a committed Blog fixture: contributors regenerate them by running `swift run PreviewGenerator` (the driver lives at `Plugin/themes/generate-previews.swift`). Regenerate after adding a layout template, color scheme, or font pairing, after `PageShell.swift` changes structurally, or before tagging a release. Users never run the driver – the committed `preview/*.html` files are the deliverable, opened directly in a browser.

Onboarding skill (`Plugin/skills/sitekit/references/onboarding.md`) references the preview page so AI agents can show it during theme selection. The preview pipeline is internal build-tooling under `Plugin/themes/`; no SiteKit library code is touched.

## Skills

### Skill folders consolidated into one entry point

The previously-separate `Plugin/skills/onboarding/`, `accessibility/`, `content-writing/`, `localization/`, and `deployment/` folders are consolidated into a single skill at `Plugin/skills/sitekit/`. The new structure:

- `Plugin/skills/sitekit/SKILL.md` – top-level routing entry (frontmatter + routing table)
- `Plugin/skills/sitekit/references/*.md` – focused reference files for each topic (16 references)

The old folders and the migrated `Plugin/docs/` files are removed. Custom plugin installations that depended on the old paths need to update to read from `Plugin/skills/sitekit/SKILL.md` instead.

**Find/replace recipe for users invoking skills:**

```diff
- /onboarding:setup-new-site
+ /sitekit (then describe your task; the skill routes via its SKILL.md table)
```

The `sitekit` skill is auto-discovered by Claude Code when the SiteKit plugin is installed. No manual invocation required.

## Recommended upgrade order

1. **Update `Package.swift`** – change the SiteKit dependency URL to `https://github.com/FlineDev/SiteKit.git` (see *Dependency URL changed*) and pin it to `from: "1.0.0"`.
2. **`swift build`** – let the compiler surface every breaking change. Fix each using the matching row in the *At a glance* table; start with the `Page` → `PageModel` rename, since it touches the most sites.
3. **Check your content** – confirm every post declares `title:` + `date:` (or follows the `YYYY-MM-DD-slug.md` filename convention). The loader now fails the build on a missing required field with a file path and line number.
4. **`swift run Site validate`** – runs translation-status and the other build-time checks.
5. **`swift run Site build`** – then spot-check the output in `_Site/` (open it locally with `swift run Site serve`).
6. **Redeploy** – push the rebuilt `_Site/` to your host.

## Where to ask for help

If a migration step doesn't work or a recipe is unclear, open an issue at [github.com/FlineDev/SiteKit/issues](https://github.com/FlineDev/SiteKit/issues) with your `Package.swift` dependency line and the compiler error.
