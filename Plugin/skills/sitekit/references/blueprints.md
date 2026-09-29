# Blueprints – Catalog & Decision Tree

Blueprints are starter templates for SiteKit sites. Each blueprint ships under `Plugin/blueprints/<Name>/` with a `SiteConfig.yaml`, `Package.swift`, `Sources/Site/Main.swift`, sample `Content/`, and a sibling `<Name>.md` instruction file that documents which questions to ask the user before scaffolding.

When a user installs the SiteKit plugin and asks Claude Code to "build me a website", the plugin reads this catalog plus the per-blueprint `.md` to pick the right starter.

## Decision tree

Walk top-to-bottom; pick the first match.

```
Do you have an OpenAPI / Swagger spec (.yaml/.json, 3.0 or 3.1)?
   yes ──► OpenAPI
   no
Do you have a DocC catalog (.docc with DocC directives)?
   yes ──► DocC
   no
Is the content audio episodes?
   yes ──► Podcast
   no
Is it a periodic email newsletter (with delivery, not just RSS)?
   yes ──► Newsletter
   no
Is the whole site a single product/app marketing page?
   yes ──► AppLanding  (beta – see below)
   no
Is there any time-based content (articles, posts, snippets)?
   no
       Showcasing apps or projects?  ──► Portfolio
       Just a few static pages?      ──► Plain
   yes
       Long-form articles only?      ──► Blog
       Short snippets only?          ──► Snippets
       Mix of articles + snippets    ──► IndieDev
       (+ optional app showcase)
```

## Catalog

| Blueprint | Status | SiteBuilder factory | Best for |
|---|---|---|---|
| `Plain` | stable | `.portfolio(...)` | Experimentation, custom pipelines, minimal scaffolding |
| `Blog` | stable | `.blog(...)` | Personal / developer blogs, periodic article writing |
| `Snippets` | stable | `.blog(...)` (with snippets section config) | Code tips, TIL sites, cheat sheets |
| `Portfolio` | stable | `.blog(...)` (portfolio section config) | Indie dev portfolios, freelancer/agency sites |
| `IndieDev` | stable | `.blog(...)` (multi-section) | Full indie sites – blog + snippets + apps + about |
| `Newsletter` | stable | `.newsletter(...)` | Curated newsletters with web archive + email rendering |
| `Podcast` | stable | `.podcast(...)` | Podcast shows, interview series (iTunes RSS, audio player, chapters) |
| `AppLanding` | beta | site-custom Swift | Single-product marketing pages (hero, features, pricing, reviews) |
| `DocC` | stable | `.docc(...)` | Documentation sites from a `.docc` catalog – sidebar, full-text search, AI-fetchable static HTML |
| `OpenAPI` | stable | `.openAPI(...)` | API reference docs from an OpenAPI 3.0/3.1 spec – operation + schema pages, nav rail, search, sitemap/llms.txt. Deep: [openapi.md](openapi.md) |

### Beta status – `AppLanding`

`AppLanding` ships custom Swift code per site (a per-blueprint `LandingPageRenderer`) rather than a `.appLanding()` factory on `SiteBuilder`. It is marked **beta** because the renderer pattern is still being iterated on across the first couple of real-world app-landing sites. v1.1 will promote it to a built-in factory once the pattern stabilises.

The blueprint is fully usable today – it just means the customisation surface lives in your site's `Sources/Site/LandingPageRenderer.swift`, not in SiteKit itself.

## Quick-start per blueprint

Every blueprint ships the same shape of `Sources/Site/Main.swift` – `run()` is synchronous (`throws`, not `async`), and the config is loaded by path:

```swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()
   }
}
```

Which factory each blueprint actually calls (verified against each `Main.swift`):

- **Blog, Snippets, IndieDev, Portfolio** → `.blog(configPath:)` – the full renderer set; the differences are purely in `SiteConfig.yaml`'s `sections:`.
- **Plain** → `.portfolio(configPath:)` – the *leaner* set (static pages + home + sitemap/robots/favicon/llms, no RSS/tags/listings).
- **Newsletter** → `.newsletter(configPath:)`; **Podcast** → `.podcast(configPath:)`.
- **AppLanding** → `.portfolio(configPath:).replacing(HomePageRenderer.self, with: LandingPageRenderer())` – the custom `LandingPageRenderer` lives in the site's `Sources/Site/Renderers/`.

Counterintuitive but real: "Portfolio" uses the fuller `.blog` set while "Plain" uses the leaner `.portfolio` set. A `.docs(config:projectDirectory:)` factory also exists (portfolio-shaped, for documentation sites) – note it has no `configPath:` convenience overload (unlike `.blog`/`.portfolio`/`.newsletter`/`.podcast`), so call it with an explicit `config`. There is no dedicated `Docs` on-disk blueprint, so use `.portfolio`/`.blog` and configure sections, or call `.docs(...)` directly.

For the minimum `SiteConfig.yaml` per blueprint, see the matching `Plugin/blueprints/<Name>/SiteConfig.yaml` – those files are kept as runnable references.

## Customising a blueprint after scaffolding

Each factory pre-composes the plugin list, but every plugin is swappable. For the exact renderer + enricher set each factory composes (and how `.blog` vs `.portfolio`/`.docs` vs `.podcast`/`.newsletter` differ), see `references/architecture.md` → "Default plugin chains". To extend a blueprint with a custom `Page`, see `references/custom-pages.md`; to replace a built-in `Loader`, `Enricher`, `Renderer`, or `OutputProcessor`, see `references/architecture.md`.

Most common customisations:

- **Different theme** – edit `Theme/theme.yaml` to pick a different layout template, color scheme, or font pairing. See `references/themes.md`.
- **Different content sections** – edit `SiteConfig.yaml`'s `sections:` list. The blueprint's renderer set works for any section count.
- **Custom page type** – add a `Page` conformer and register with `.renderer(...)`. See `references/custom-pages.md`.
- **Different email-sending stack** (Newsletter only) – see `references/newsletter-setup.md`.

## Naming convention

Blueprint folders and files use **PascalCase** – `Blog/` + `Blog.md`, `IndieDev/` + `IndieDev.md`. Generated URLs from the blueprint output are always lowercase (`/blog/hello-world/`, `/about/`). The mapping is handled by `URLRouter`; you do not have to think about it when authoring content.

## See also

- `Plugin/blueprints/INDEX.md` – the broader on-disk catalog (feature comparison matrix, navigation patterns)
- `Plugin/blueprints/<Name>.md` – per-blueprint questions and variations
- `references/architecture.md` – phase-oriented pipeline that every blueprint composes
