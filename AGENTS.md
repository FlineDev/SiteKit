# SiteKit – Contributor reference

> The canonical reference for AI agents and humans who want to **modify SiteKit itself**. If you want to **build a website with SiteKit**, start at the user-facing [README](README.md) and the [`Plugin/`](Plugin/) subfolder instead.

## 1. What SiteKit is

SiteKit is an AI-first Swift static site generator: a phase-oriented build pipeline composed of swappable plugins (Discovery → Loading → Enrichment → Page rendering → System rendering → Output processing, plus content-independent asset teleporting), plus a Claude Code plugin under `Plugin/` that guides agents through building websites for users. The Swift library and the AI plugin live in the same repo so the two evolve together.

## 2. Pipeline

Every build walks a fixed sequence of phases. Each phase is one protocol; each plugin implements one protocol. The phase you want to extend tells you which protocol to conform to and which `SiteBuilder` swap point to use.

| Phase | Protocol | One-line description | `SiteBuilder` swap point |
|---|---|---|---|
| **0. Asset teleporting** | `Teleporter` | Copy assets from source dirs to output | `.teleporter(_:)` |
| **1. Discovery** | `ContentDiscovery` | Find source files for each section | `.contentDiscovery(_:)` |
| **2. Loading** | `Loader<Source, Output>` | Parse Markdown / YAML into typed models | `.articleLoader(_:)`, `.staticPageLoader(_:)` |
| **3. Enrichment** | `Enricher` | Add hreflang, promotions, reading time, etc. | `.enricher(_:)` |
| **4. Per-locale page rendering** | `Page : Renderer` | Render HTML pages with site chrome | `.renderer(_:)` (or `.defaultBlogRenderers()`) |
| **5. System rendering** | `Renderer` (with `RenderScope`) | RSS, sitemap, robots, headers, redirects, etc. | `.renderer(_:)` (same list) |
| **6. Output processing** | `OutputProcessor` | Image variants, font inlining, minification | `.processor(_:)` |

Phase 0 (Teleporter) runs before the content phases and is independent of the content graph – assets never wait on (or feed into) discovery and loading. Phases 1–6 are strictly ordered. Per-locale phases (4 + most of 5) execute once per locale on multilingual sites; `.global` renderers (sitemap index, robots, llms.txt, Cloudflare `_headers`, language redirects) execute exactly once per build regardless of locale count – see `RenderScope`.

### `BuildContext`

The shared, read-only state passed to every Phase 3–6 plugin. Holds the loaded `SiteConfig`, the `ThemeConfig` (if any), the `ContentSection` list (one entry per declared section, each with its loaded `[PageModel]`), `staticPages`, `tags`, `homeContent`, `draftPages`, the locale-aware `URLRouter`, the `UIStrings` bundle for the current locale, and the `outputDirectory` / `projectDirectory` URLs. Plugins read from it; they do not mutate it.

### `SiteBuilder`

A fluent, immutable builder that composes a `BuildPipeline` from the plugins above. Every configuration method (`.renderer`, `.enricher`, `.teleporter`, …) returns a new `SiteBuilder`. Blueprint factory methods like `SiteBuilder.blog(...)`, `.podcast(...)`, `.newsletter(...)`, `.portfolio(...)`, `.docs(...)`, `.docc(...)` pre-compose the default plugin list for a site type. `.run()` reads CLI arguments (`build`, `serve`, `validate`) and executes the pipeline.

### `BuildPipeline`

The executor. Takes the composed plugin list and walks Phases 0–6 in order, dispatching renderers by their declared `scope`. Phase 6 (`OutputProcessor`s) runs after every renderer has written its output files; processors mutate the output directory in place.

## 3. Two-level vocabulary

Two words to keep straight when talking about SiteKit:

- **Blueprint** – a factory-method *recipe* for a site type: `SiteBuilder.blog`, `.podcast`, `.newsletter`, `.portfolio`, `.docs`, `.docc`. Pre-composes the default plugin list and the enricher chain for that kind of site. Blueprints also exist as on-disk site templates under `Plugin/blueprints/` (Blog, IndieDev, Podcast, Newsletter, Portfolio, AppLanding, DocC, Plain, Snippets) – those are the starter sites the Claude Code plugin can clone for a user.
- **Plugin** – any swappable component conforming to a phase protocol (`ContentDiscovery`, `Loader`, `Enricher`, `Page`, `Renderer`, `OutputProcessor`, `Teleporter`). The phase order tells you where it plugs in.

The Claude Code plugin under `Plugin/` is a different sense of "plugin" (the kebab-case Claude Code packaging). Context disambiguates.

## 4. Cross-cutting concerns

Four concerns span multiple phases. For each, here are the phases that contribute and the invariants the framework guarantees.

### SEO / ASO

`PageShell.wrap(content:page:context:)` builds canonical URLs, OG, Twitter Card, JSON-LD, hreflang, and RSS discovery for every page. Per-Page `Renderer`s contribute meta from frontmatter (title, description, image, category). Global `Renderer`s produce `sitemap.xml`, `robots.txt`, and `llms.txt`. The `HreflangEnricher` (Phase 3) populates the per-page `hreflang` table on multilingual sites.

**Invariant:** every `Page`-produced HTML output passes through `PageShell` (or explicitly bypasses it for a documented reason), so every page carries the required meta and canonical URL.

### Performance

`PageShell` orders `<head>` resources for FCP/LCP (theme-critical CSS before everything else; preloads for the LCP image and primary font; non-critical CSS deferred). `OutputProcessor`s in Phase 6 generate responsive image variants (`ImageResizer`), inline FontAwesome SVGs once (`FontAwesomeInliner`), rewrite CSS background-image URLs to variants (`CSSBackgroundImageProcessor`), and minify (`AssetMinifier`). The theme system distinguishes critical vs. non-critical stylesheets.

**Invariant:** non-critical CSS never blocks the initial render; the LCP image is always preloaded; image variants ship per-locale only when locale-divergent content demands it.

### Accessibility

Theme tokens guarantee WCAG AA contrast across the 15 color schemes. `PageShell` emits semantic HTML (`<main>`, `<article>`, `<nav>`, proper heading hierarchy). Theme JavaScript is keyboard-navigable. (The `validate` command does not check accessibility – it checks translation completeness; accessibility rests on the authoring guarantees above.)

**Invariant:** required `alt` text comes from page frontmatter (`image`/`imageAlt`); the 15 shipped color schemes are hand-tuned to meet WCAG AA contrast (this is an authoring guarantee on the bundled schemes, not a build-time check – a custom token override is not validated).

### AI-friendliness

`llms.txt` (`LlmsTxtRenderer`), the `/assets/nav-index.json` + `/assets/search-index.json` machine-readable indexes (`NavIndexRenderer`), and per-section `README.md` content maps (`ContentIndexRenderer`, written into the source tree) are standard outputs. `TranslationStatus` surfaces translation gaps to AI agents driving the site. Frontmatter is machine-readable YAML with `requiredFields` validation. `RenderScope` is explicit per renderer. The `SiteBuilder` API is declarative and short-doc-commented on every public symbol across the core surfaces (`SiteBuilder`, the phase protocols, `BuildContext`, the model and config types); remaining doc gaps on shipped plugin conformers are tracked for 1.x.

**Invariant:** the build outputs everything an AI assistant needs to understand and extend the site without reading project-internal config.

## 5. Adding a custom `Page`

The most common extension point. Conform to `Page` to add an HTML page type that participates in the per-locale rendering phase and inherits standard site chrome.

```swift
import SiteKit
import Foundation

public struct RecipePage: Page {
   public init() {}

   public func pages(in context: BuildContext) -> [PageModel] {
      context.sections
         .first(where: { $0.config.slug == "recipes" })?
         .pages ?? []
   }

   public func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      let body = """
      <article class="recipe">
         <h1>\(page.title)</h1>
         <p>By \(page.author?.name ?? "Anonymous")</p>
         \(page.htmlContent)
      </article>
      """
      return PageShell.wrap(content: body, page: page, context: context)
   }
}
```

`pages(in:)` selects the pages this renderer is responsible for. `renderHTML(_:context:)` returns the *fully assembled* HTML page including chrome – call `PageShell.wrap(content:page:context:)` to wrap your body with the standard `<head>` / `<header>` / `<footer>`. The default `outputURL(for:context:)` extension dispatches by `page.pageType` (article path or static-page path); override it when you need a non-standard path.

Register it on a `SiteBuilder`:

```swift
try SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .renderer(RecipePage())
   .run()
```

See `Page.swift` and the default conformers (`ArticlePageRenderer`, `HomePageRenderer`, `SectionPageRenderer`, `StaticPageRenderer`, …) for working examples. `Page` is a sub-protocol of `Renderer` so HTML page rendering and system rendering share one routing surface – every renderer declares `scope` and the pipeline dispatches uniformly.

## 6. Adding a system renderer

For non-HTML output files or site-wide JSON / XML / text files (RSS, sitemap, robots, llms.txt, indexes, CSS bundles, Cloudflare `_headers`, redirects), conform to `Renderer` directly and declare a `scope`.

```swift
import SiteKit
import Foundation

public struct MetaIndexRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let summaries = context.sections.flatMap { section in
         section.pages.map { page in
            ["slug": page.slug, "title": page.title, "section": section.config.slug]
         }
      }
      let json = try JSONSerialization.data(withJSONObject: summaries, options: [.prettyPrinted, .sortedKeys])
      let outputPath = context.outputDirectory.appendingPathComponent("meta-index.json")
      return [OutputFile(outputPath: outputPath, content: String(decoding: json, as: UTF8.self))]
   }
}
```

`scope: .global` means this renderer runs exactly once per build, regardless of locale count. `scope: .perLocale` (the default – declared in the `Renderer` extension) means it runs once per locale's `BuildContext`. Choose `.global` for site-wide singletons (sitemap index, robots, llms.txt, Cloudflare `_headers`); choose `.perLocale` for outputs that should vary by language. The pipeline dispatches each renderer by its declared `scope` – no per-type-name routing.

Register the same way as a `Page`:

```swift
try SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .renderer(MetaIndexRenderer())
   .run()
```

## 7. Adding an `OutputProcessor`

`OutputProcessor` runs in Phase 6 (after every renderer has written its files) and mutates the output directory in place. Use it for cross-cutting transformations that need to see the *final* HTML / CSS / asset state – inlining tiny resources, minification, image variants, dead-CSS purging.

```swift
import SiteKit
import Foundation

public struct CriticalFontInliner: OutputProcessor {
   public init() {}

   public func process(
      outputDirectory: URL,
      projectDirectory: URL,
      themeConfig: ThemeConfig?
   ) throws {
      let manager = FileManager.default
      let enumerator = manager.enumerator(at: outputDirectory, includingPropertiesForKeys: nil)
      while let url = enumerator?.nextObject() as? URL {
         guard url.pathExtension == "html" else { continue }
         var html = try String(contentsOf: url, encoding: .utf8)
         // Find <link rel="preload" as="font" ...>, inline if asset is < 2 KB,
         // and rewrite the link to a data: URL. Implementation omitted for brevity.
         try html.write(to: url, atomically: true, encoding: .utf8)
      }
   }
}
```

Register:

```swift
try SiteBuilder.blog(config: config, projectDirectory: projectDir)
   .processor(CriticalFontInliner())
   .run()
```

The default processor chain (`ImageResizer` → `FontAwesomeInliner` → `CSSBackgroundImageProcessor` → `AssetMinifier` → `AssetFingerprinter`) applies only while no processor is configured explicitly: the first `.processor(_:)` call starts a fresh list, so registering a single custom processor builds with that one alone – image variants, minification, and fingerprinting will NOT run. To extend the defaults, pass the full chain plus your processor to `.processors(_:)`; pass `nil` there to restore the default chain.

## 8. Adding a `Loader` / `Enricher` / `ContentDiscovery`

These are less-frequently-customised phases. Concise examples:

**Custom `ContentDiscovery`** – for non-flat content layouts:

```swift
public struct NestedContentDiscovery: ContentDiscovery {
   public init() {}

   public func discover(in directory: URL) throws -> [MarkdownSource] {
      let manager = FileManager.default
      let enumerator = manager.enumerator(at: directory, includingPropertiesForKeys: nil)
      var sources: [MarkdownSource] = []
      while let url = enumerator?.nextObject() as? URL {
         guard url.pathExtension == "md" else { continue }
         let content = try String(contentsOf: url, encoding: .utf8)
         sources.append(MarkdownSource(filePath: url, content: content))
      }
      return sources.sorted { $0.filePath.path < $1.filePath.path }
   }
}
```

Register via `SiteBuilder.contentDiscovery(NestedContentDiscovery())`.

**Custom `Loader`** – for non-Markdown sources, or for tweaking the Markdown→`PageModel` translation. SiteKit ships `MarkdownLoader` (Markdown → `PageModel` with `requiredFields` validation) and the generic `YAMLLoader<Output>` (YAML → any `Decodable` type). To add a third source format, conform to `Loader<YourSource, YourOutput>`:

```swift
public struct JSONFeedLoader: Loader {
   public typealias Source = URL
   public typealias Output = [PageModel]

   public init() {}

   public func load(source: URL) throws -> [PageModel] {
      let data = try Data(contentsOf: source)
      // Decode + map to PageModel – implementation omitted.
      return []
   }
}
```

**Custom `Enricher`** – for adding computed fields to every `PageModel`:

```swift
public struct ReadingTimeEnricher: Enricher {
   public init() {}

   public func enrich(_ page: PageModel) throws -> PageModel {
      var extensions = page.extensions
      extensions["readingTime"] = page.readTimeMinutes
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

Register via `SiteBuilder.enricher(ReadingTimeEnricher())`. Enrichers run in registration order; SiteKit's built-in `PromotionEnricher` and `HreflangEnricher` are appended last by the blueprint factory methods (see `SiteBuilder.blog(...)`).

## 9. Token system

The theming layer ships **3 layout templates** (Classic, Sidebar, Minimal – under `Plugin/themes/templates/`; the per-site `Theme/theme.yaml` selects one and overrides where needed), **15 color schemes**, and **6 font pairings**. ("Layout template" is deliberate: SiteKit reserves the word *preset* for the 4 token bundles in `references/themes.md`, a separate concept – do not conflate the two.) Token values feed into the generated `base.css` and `tokens.css` via the `BaseCSSOutputRenderer` and `TokenCSSOutputRenderer` plugins (Phase 5 renderers). The `ThemeConfig` decoded from `Theme/theme.yaml` is passed into `BuildContext.themeConfig` and used by `PageShell` to emit the right `<link>` order.

For full token vocabulary, color/font catalogs, and how to author a custom theme, see `Plugin/themes/README.md` and the consolidated SiteKit skill under `Plugin/skills/sitekit/`. For why there is no Swift `Layout` protocol (layouts are CSS/JS template directories, not pipeline plugins), see `Docs/LayoutProtocol.md`.

## 10. Performance, Accessibility, Favicons

Short per-domain notes; depth lives in the Plugin-side skill references.

**Performance.** `PageShell` controls `<head>` resource order: critical CSS inline → preloads (LCP image, primary font) → deferred non-critical CSS → theme JS at end of `<body>`. `ImageResizer` (Phase 6) emits responsive variants from the largest source; `FontAwesomeInliner` strips one MB of icon font into per-page inline SVGs; `AssetMinifier` strips comments and whitespace.

**Accessibility.** Required `alt` text comes from `image:` / `imageAlt:` frontmatter – `MarkdownLoader.requiredFields` can include `imageAlt` to fail-fast on missing values. `PageShell` emits semantic landmarks. The 15 bundled color schemes are hand-tuned by their authors to pass WCAG AA contrast; there is no build-time contrast check, so a custom token override is the author's responsibility to verify.

**Favicons.** `FaviconRenderer` (a `Renderer`, declared `.global`) copies pre-generated favicon files from `<assetsDirectory>/Favicons/` (`Content/Assets/Favicons/` in the standard layout) to the output root – deliberately no image processing at build time, so builds stay fast, reproducible, and CI-friendly. The files (`apple-touch-icon.png`, `favicon-32x32.png`, `favicon-16x16.png`, `favicon.ico`, optionally `site.webmanifest`) are generated once locally from a raster logo – the ImageMagick recipe lives in the `FaviconRenderer` doc comment – and committed. When the directory is missing or empty, the build logs a warning with the recipe. Theme-level icons (e.g. an SVG in `Theme/images/`) are declared separately via `theme.yaml`'s `favicons:` list.

For exhaustive per-domain detail, see `Plugin/skills/sitekit/references/performance.md` and `references/accessibility.md`. The favicon pipeline is covered inline above (`FaviconRenderer`) – there is no separate favicons reference.

## 11. Where things live

Directory tour. Names with no path are at the repo root.

```
SiteKit/
├── .claude-plugin/        ← marketplace.json (must sit at the repo root for `/plugin marketplace add`)
├── AGENTS.md              ← you are reading it
├── CLAUDE.md              ← one line: @AGENTS.md (Claude Code reads AGENTS.md)
├── README.md              ← user-facing entry point
├── USE-CASES.md           ← task → doc matrix
├── LICENSE                ← MIT
├── Logo.png
├── Package.swift          ← Swift package manifest
├── Package.resolved       ← pinned dependency versions (reproducible contributor builds)
├── Docs/                  ← cross-tool guide, layout-protocol notes, vision, templates
├── Sources/
│   ├── SiteKit/           ← the Swift library
│   │   ├── Pipeline/      ← phase protocols + BuildContext / SiteBuilder / BuildPipeline
│   │   ├── Plugins/       ← shipped Loader / Enricher / Renderer / OutputProcessor / Teleporter / ContentDiscovery conformers
│   │   ├── Models/        ← PageModel, SiteConfig, ThemeConfig, UIStrings, Person, FeedData, ImageManifest
│   │   ├── Theme/         ← PageShell (the public chrome namespace)
│   │   ├── Utilities/     ← parsing / string / URL helpers
│   │   └── Resources/     ← bundled localizations
│   └── SiteKitCLI/        ← the `sitekit` command-line tool (doctor / blueprints / new / update)
├── Tests/
│   ├── SiteKitTests/      ← library tests
│   ├── SiteKitCLITests/   ← CLI tests
│   └── PreviewGeneratorTests/ ← theme-preview generator tests
└── Plugin/                ← the Claude Code plugin (kebab-case world)
    ├── .claude-plugin/plugin.json
    ├── skills/sitekit/    ← consolidated AI guidance skill – SKILL.md routes to references/*.md
    ├── blueprints/        ← starter sites the plugin clones for a user
    ├── themes/            ← Classic / Sidebar / Minimal layout templates + preview generator
    ├── templates/         ← shared per-blueprint scaffolding
    └── scripts/           ← download-fonts.sh and other plugin tooling
```

The Claude Code plugin world (kebab-case dirs) is quarantined under `Plugin/` to avoid APFS case-insensitive collisions with `Docs/` and `Sources/`.

## 12. Build and test

```bash
swift build                                # build the Swift library
swift test                                 # run the SiteKit test target

cd <site>/ && swift run Site build         # build a site to _Site/
cd <site>/ && swift run Site serve         # local dev server (default :8080)
cd <site>/ && swift run Site validate      # run validation checks (translations, etc.)
```

`swift run Site <command>` dispatches through `SiteBuilder.run()` – the same builder you use to compose plugins. `--no-clean` skips the output-directory wipe; `--port <n>` overrides the dev server port; `--base-url <url>` overrides `SiteConfig.baseURL` for one build/serve pass (absolute http(s) URL – lets a deploy workflow target a staging origin while the YAML keeps the production truth).

For end-to-end testing of a custom plugin, scaffold a minimal site under the test target, register the plugin, and assert on the `OutputFile`s it produces.

---

## See also

- **Use-case matrix:** `USE-CASES.md` – every task → the doc that answers it (spans the human docs and the AI reference bundle).
- **Vision:** `Docs/Roadmap/Vision.md`.
