# SiteKit use-case matrix

**"I want to do X → go here."** A fast lookup for everyone – new users, AI agents, and contributors.

This is the index, not the explanation. For a guided walkthrough read [README.md](README.md); if you're an AI agent driving SiteKit, [SKILL.md](Plugin/skills/sitekit/SKILL.md) routes every task to the right reference. Where a task has both a human entry point and a deeper reference, both are listed.

## Get going

| I want to… | Go to |
|---|---|
| Decide whether SiteKit fits my project | [README – Is SiteKit for you?](README.md#is-sitekit-for-you) |
| Pick a blueprint | [Blueprint catalog](Plugin/blueprints/INDEX.md) · deep: [blueprints.md](Plugin/skills/sitekit/references/blueprints.md) |
| Install SiteKit + scaffold my first site | [README – Get started](README.md#get-started) · deep: [bootstrap.md](Plugin/skills/sitekit/references/bootstrap.md) |
| Set up a new site end-to-end (the judgment-heavy flow) | [onboarding.md](Plugin/skills/sitekit/references/onboarding.md) |
| Build a documentation site from a DocC catalog | [DocC blueprint](Plugin/blueprints/DocC.md) · deep: [markdown-extensions.md](Plugin/skills/sitekit/references/markdown-extensions.md) |

## Author your site

| I want to… | Go to |
|---|---|
| Write posts, newsletter issues, or static pages | [content-writing.md](Plugin/skills/sitekit/references/content-writing.md) |
| Configure site metadata (name, URL, navigation, author) | [siteconfig-reference.md](Plugin/skills/sitekit/references/siteconfig-reference.md) |
| Use DocC / Markdown directives (`@Metadata`, `@Row`, `@TabNavigator`, `@Video`, …) | [markdown-extensions.md](Plugin/skills/sitekit/references/markdown-extensions.md) |
| Configure the DocC home page, appbar, sidebar, and search (the `docc:` block) | [siteconfig-reference.md – docc](Plugin/skills/sitekit/references/siteconfig-reference.md#docc) |
| Decide whether you need an imprint / privacy page (per country) | [legal-pages.md](Plugin/skills/sitekit/references/legal-pages.md) |
| Add legal pages (German example templates) | [Imprint template](Docs/Templates/Imprint.md) · [Privacy Policy template](Docs/Templates/PrivacyPolicy.md) |

## Customize & localize

| I want to… | Go to |
|---|---|
| Change colors, fonts, or layout | [README – Customise the look](README.md#customise-the-look) · deep: [themes.md](Plugin/skills/sitekit/references/themes.md) |
| Make the site multi-language | [localization.md](Plugin/skills/sitekit/references/localization.md) |
| Audit accessibility (WCAG AA, alt text, keyboard nav) | [accessibility.md](Plugin/skills/sitekit/references/accessibility.md) |
| Improve SEO / ASO / AI-discoverability | [seo-aso.md](Plugin/skills/sitekit/references/seo-aso.md) |
| Improve performance / PageSpeed (LCP, CLS, render-blocking) | [performance.md](Plugin/skills/sitekit/references/performance.md) |

## Ship it

| I want to… | Go to |
|---|---|
| Deploy to Cloudflare Pages (canonical, free) | [cloudflare-pages.md](Plugin/skills/sitekit/references/deployment/hosts/cloudflare-pages.md) |
| Deploy elsewhere or set up CI | [deployment – start here](Plugin/skills/sitekit/references/deployment/SKILL.md) |
| Run a self-hosted newsletter (Keila + SMTP) | [newsletter-setup.md](Plugin/skills/sitekit/references/newsletter-setup.md) |
| Choose external services (email sending, integrations) | [external-services.md](Plugin/skills/sitekit/references/external-services.md) |
| Fix a failing build | [README – When something goes wrong](README.md#when-something-goes-wrong) · deep: [troubleshooting.md](Plugin/skills/sitekit/references/troubleshooting.md) |

## Extend with Swift

| I want to… | Go to |
|---|---|
| Add a custom `Page` (a new HTML page type) | [custom-pages.md](Plugin/skills/sitekit/references/custom-pages.md) |
| Extend the build pipeline (Loader / Enricher / Renderer / OutputProcessor / Teleporter) | [architecture.md](Plugin/skills/sitekit/references/architecture.md) · [AGENTS.md](AGENTS.md) |
| Drive SiteKit with another AI tool (Copilot, Codex, Gemini, …) | [Cross-Tool-Guide.md](Docs/Cross-Tool-Guide.md) |

## Reference & meta

| I want to… | Go to |
|---|---|
| Understand SiteKit's architecture / contribute to it | [AGENTS.md](AGENTS.md) |
| Update a site to a newer SiteKit version | [bootstrap.md – `sitekit update`](Plugin/skills/sitekit/references/bootstrap.md) |
| (AI agent) Route any task to the right reference | [SKILL.md](Plugin/skills/sitekit/SKILL.md) |
