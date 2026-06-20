---
name: sitekit
description: Build, customize, and deploy websites using SiteKit – an AI-first Swift static site generator. Use when creating a new website, scaffolding a SiteKit project, writing content, deploying, customizing the theme, or extending an existing SiteKit site with a custom Page or Renderer.
metadata:
  keywords: "sitekit, static site, swift website, blueprint, blog, newsletter, podcast, portfolio, theme tokens, deploy, page renderer"
---

# SiteKit

SiteKit is an AI-first Swift static site generator built around a **phase-oriented pipeline**: Discovery → Loading → Enrichment → Page rendering → System rendering → Output processing, plus content-independent asset teleporting. Each phase is one Swift protocol; sites are composed with `SiteBuilder` factory methods (`.blog()`, `.podcast()`, `.newsletter()`, `.portfolio()`, `.docs()`, `.docc()`, `.openAPI()`) and customized fluently by swapping or appending plugins.

## Process

Route the user's intent to the right reference. Read only the references you need for the current task.

| If the user asks about… | Then read… |
|---|---|
| Installing SiteKit + scaffolding the first site (the `sitekit` CLI) | `references/bootstrap.md` |
| Setting up a new site from scratch | `references/onboarding.md` |
| Picking a blueprint (Blog, Newsletter, Podcast, Portfolio, AppLanding, Snippets, IndieDev, DocC, OpenAPI, Plain) | `references/blueprints.md` |
| Building API docs from an OpenAPI / Swagger spec (3.0 or 3.1) | `references/openapi.md` |
| Writing content (blog posts, newsletter issues, static pages) | `references/content-writing.md` |
| Imprint / privacy / legal pages (country-dependent, GDPR, cookies) | `references/legal-pages.md` |
| DocC / Markdown directive extensions (`@Metadata`, `@Row`, `@TabNavigator`, `@Video`, `@Image`, `@Links`, …) + the graceful-degradation contract | `references/markdown-extensions.md` |
| Multi-language sites (translations, locale suffixes, validation) | `references/localization.md` |
| Accessibility audit (WCAG AA contrast, alt text, keyboard nav) | `references/accessibility.md` |
| SEO + ASO + AI discoverability (canonical URLs, OG, JSON-LD, llms.txt) | `references/seo-aso.md` |
| Performance / PageSpeed findings (LCP, CLS, render-blocking) | `references/performance.md` |
| Deploying the site (host + CI provider matrix) – **start here** | `references/deployment/SKILL.md` |
| Theme customization (presets, color schemes, font pairings, tokens) | `references/themes.md` |
| Adding a custom `Page` for a new HTML page type | `references/custom-pages.md` |
| Extending the pipeline (`Loader`, `Enricher`, `Renderer`, `OutputProcessor`, `Teleporter`) | `references/architecture.md` |
| Build / runtime troubleshooting | `references/troubleshooting.md` |
| Self-hosted newsletter setup (Keila + SMTP) | `references/newsletter-setup.md` |
| Choosing external services (email sending, integrations) | `references/external-services.md` |
| `SiteConfig.yaml` field reference | `references/siteconfig-reference.md` |

### Deployment – jump straight to a provider

`references/deployment/SKILL.md` is the orchestrator: it detects the `Package.swift` variant, asks setup-mode, and walks CLI auth before routing to one CI + one host file. Start there for a fresh deployment. If you already know the target (e.g. re-configuring an existing deploy), jump directly:

| If the user asks about… | Then read… |
|---|---|
| CI on GitHub Actions | `references/deployment/ci/github-actions.md` |
| CI on GitLab CI | `references/deployment/ci/gitlab-ci.md` (community; placeholder) |
| CI on Xcode Cloud | `references/deployment/ci/xcode-cloud.md` (community; placeholder) |
| CI on Bitrise | `references/deployment/ci/bitrise.md` (community; placeholder) |
| Hosting on Cloudflare Pages | `references/deployment/hosts/cloudflare-pages.md` |
| Hosting on GitHub Pages | `references/deployment/hosts/github-pages.md` |
| Hosting on Netlify | `references/deployment/hosts/netlify.md` |
| Hosting on Vercel | `references/deployment/hosts/vercel.md` |
| Which CI providers are supported / adding a new CI provider | `references/deployment/ci/README.md` |
| Which hosts are supported / adding a new hosting provider | `references/deployment/hosts/README.md` |

Jumping direct skips the orchestrator's setup-mode and `Package.swift` detection – only do it when those have already been settled.

## Core vocabulary (always available)

- **Blueprint** – a recipe for a site type. `SiteBuilder` exposes factory methods (`.blog()`, `.podcast()`, `.newsletter()`, `.portfolio()`, `.docs()`, `.docc()`) that pre-compose the default plugin list for each kind of site. On-disk blueprints under `Plugin/blueprints/` are starter sites the plugin can clone.
- **Page** – the user-facing protocol for HTML page rendering. It is a sub-protocol of `Renderer`. Conformers implement `pages(in:)` and `renderHTML(_:context:)`; `PageShell.wrap(content:page:context:)` auto-applies the standard `<head>` / `<header>` / `<footer>` chrome.
- **Renderer** – system-level output protocol. Declares `scope: .perLocale` (default – runs once per locale) or `.global` (runs exactly once per build, used for sitemap, robots, llms.txt, Cloudflare `_headers`). The pipeline dispatches by `scope`.
- **`SiteBuilder`** – immutable, fluent builder. Every configuration method (`.renderer`, `.enricher`, `.processor`, `.teleporter`, …) returns a new `SiteBuilder`. `.run()` reads CLI verbs (`build`, `serve`, `validate`) and executes the pipeline.
- **`BuildContext`** – read-only state passed to every Phase 3–6 plugin. Holds `config`, `themeConfig`, `sections`, `staticPages`, `tags`, `homeContent`, `router`, `uiStrings`, `outputDirectory`, `projectDirectory`.
- **Build commands** – `swift run Site build` writes the site to `_Site/`. `swift run Site serve` runs the dev server (default `:8080`). `swift run Site validate` checks translation completeness on multilingual sites (single-language sites pass trivially). `--base-url <url>` on build/serve overrides `SiteConfig.baseURL` for that pass (staging deploys).

## Style note

When generating site content via this skill, keep an authentic indie voice. Short paragraphs. Personal pronouns. No corporate hedging. The full author-voice guide and learning-loop instructions live in `references/content-writing.md`.

## Pipeline at a glance

| Phase | Protocol | Where to extend |
|---|---|---|
| 0. Asset teleport (content-independent) | `Teleporter` | `.teleporter(_:)` |
| 1. Discovery | `ContentDiscovery` | `.contentDiscovery(_:)` |
| 2. Loading | `Loader<Source, Output>` | `.articleLoader(_:)`, `.staticPageLoader(_:)` |
| 3. Enrichment | `Enricher` | `.enricher(_:)` |
| 4. Per-locale HTML pages | `Page` (sub-protocol of `Renderer`) | `.renderer(_:)` |
| 5. System rendering | `Renderer` + `RenderScope` | `.renderer(_:)` |
| 6. Output processing | `OutputProcessor` | `.processor(_:)` |

For the full architecture rationale and worked examples of each extension point, read `references/architecture.md` and `references/custom-pages.md`.

## See also

If a task isn't covered by any reference above – you're modifying SiteKit's own Swift library rather than building a site with it – escalate to the contributor reference at the repo root: `AGENTS.md` (pipeline internals, phase protocols, `SiteBuilder` swap points, build & test commands).

For a task → doc index that spans both the human-facing docs and these references, see `../../../USE-CASES.md` at the repo root.
