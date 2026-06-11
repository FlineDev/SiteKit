<p align="center">
  <img src="https://github.com/FlineDev/SiteKit/blob/main/Logo.png?raw=true" height="256" />
  <br><br>
  <a href="#is-sitekit-for-you">Is it for you?</a> · <a href="#what-you-can-build">Blueprints</a> · <a href="#get-started">Get started</a> · <a href="#deploy">Deploy</a> · <a href="#contributing">Contributing</a>
</p>

# SiteKit

**An AI-native static site generator for Swift developers.**

SiteKit is a Swift static site generator plus a Claude Code plugin: you can hand the whole job to an AI that scaffolds, themes, writes, and deploys your site for you – or drive the `sitekit` CLI yourself. Either way the output is a fast, SEO-complete, accessible static site you host anywhere.

> **Looking for something specific?** The [use-case matrix](USE-CASES.md) maps every task – author, customize, deploy, extend – to the doc that answers it.

---

## Is SiteKit for you?

**Yes, if you want to:**
- Ship a blog, podcast, newsletter, portfolio, or app-landing site as plain static files.
- Stay in the Swift / Apple-platform world – your site is a Swift package, your content is Markdown.
- Let an AI assistant do the heavy lifting (scaffolding, theming, content drafting, deployment).

**Probably not, if you need:**
- A server-rendered CMS with a database, user logins, or live dynamic pages.
- A no-code, point-and-click WYSIWYG editor.
- A non-Swift toolchain – SiteKit builds with `swift`, and authoring assumes you're comfortable editing text files.

---

## What you can build

SiteKit ships **9 blueprints** – starter sites you scaffold and customise. Each has a short guide:

| Blueprint | For | Guide |
|---|---|---|
| **Blog** | Articles with categories, tags, RSS | [Blog.md](Plugin/blueprints/Blog.md) |
| **Snippets** | Short-form tips, TILs, cheat sheets | [Snippets.md](Plugin/blueprints/Snippets.md) |
| **Portfolio** | App / project showcase | [Portfolio.md](Plugin/blueprints/Portfolio.md) |
| **IndieDev** | Blog + snippets + portfolio combined | [IndieDev.md](Plugin/blueprints/IndieDev.md) |
| **Podcast** | Episode pages, audio player, iTunes RSS | [Podcast.md](Plugin/blueprints/Podcast.md) |
| **Newsletter** | Issue archive, signup forms, email rendering | [Newsletter.md](Plugin/blueprints/Newsletter.md) |
| **AppLanding** | Single product landing page (hero, features, pricing) | [AppLanding.md](Plugin/blueprints/AppLanding.md) |
| **DocC** | DocC catalog → docs site with sidebar + full-text search | [DocC.md](Plugin/blueprints/DocC.md) |
| **Plain** | Minimal, no opinions – a blank canvas | [Plain.md](Plugin/blueprints/Plain.md) |

Not sure which to pick? The [blueprint catalog](Plugin/blueprints/INDEX.md) has a decision tree and a feature comparison.

---

## Get started

**Prerequisites:** macOS 26 or later with the Swift 6.2 toolchain (`swift --version`). Git. Optionally the GitHub CLI (`gh`) for publishing.

### The AI-guided way (recommended)

SiteKit is built to be driven by an AI. Install the Claude Code plugin, then just ask:

```
/plugin marketplace add FlineDev/SiteKit
/plugin install sitekit@sitekit-dev
```

Then tell Claude what you want – *"build me a developer blog with SiteKit"* – and it walks you through blueprint choice, theme, content, and deployment.

### The manual CLI way

Clone SiteKit and use the `sitekit` CLI directly:

```bash
git clone https://github.com/FlineDev/SiteKit.git
cd SiteKit
swift run sitekit doctor                          # check git + swift toolchain
swift run sitekit new MySite --blueprint Blog     # scaffold (defaults to Blog)
```

Then run your new site locally:

```bash
cd MySite
swift run Site serve                              # dev server on http://localhost:8080
```

`swift run Site build` produces the static output in `_Site/`; `swift run Site validate` checks for missing translations on multilingual sites.

---

## Where things live (in your new site)

| Path | What it holds |
|---|---|
| `Content/<section>/*.md` | Your posts, episodes, pages – Markdown with YAML frontmatter |
| `Theme/theme.yaml` | Color scheme, font pairing, layout template |
| `SiteConfig.yaml` | Site metadata: name, URL, author, navigation |
| `Content/Assets/` | Images and logo; pre-generated favicons go in `Content/Assets/Favicons/` |
| `_Site/` | Build output (gitignored) – what you deploy |

Deeper references: [content writing](Plugin/skills/sitekit/references/content-writing.md) · [SiteConfig reference](Plugin/skills/sitekit/references/siteconfig-reference.md).

---

## Customise the look

Open `Theme/theme.yaml` and pick a **color scheme** (15 to choose from), a **font pairing** (6 options), and a **layout template** (Classic, Sidebar, Minimal). Override individual design tokens for full control. See the [theming guide](Plugin/skills/sitekit/references/themes.md).

---

## Deploy

**Cloudflare Pages** is the canonical path – free, fast, and the deployment is fully documented: [Cloudflare Pages walkthrough](Plugin/skills/sitekit/references/deployment/hosts/cloudflare-pages.md).

Because the build is plain static files in `_Site/`, **any static host works** – GitHub Pages, Netlify, Vercel, or your own server. See [all deployment guides](Plugin/skills/sitekit/references/deployment/).

---

## When something goes wrong

Build failing or output not what you expected? Start with the [troubleshooting guide](Plugin/skills/sitekit/references/troubleshooting.md) – it covers frontmatter errors, missing fields, and the most common build failures.

---

## Extending with custom Swift

The blueprints cover the common cases. When you need something they don't ship – a custom page type, a new output file, a bespoke content transform – that's Swift territory. SiteKit's pipeline is a set of swappable plugins you conform to: see [AGENTS.md](AGENTS.md) for the architecture and the [custom-pages reference](Plugin/skills/sitekit/references/custom-pages.md) for a worked example.

---

## Status & versioning

SiteKit is **v1.0**. Already running a v0.9 site? [MIGRATION.md](MIGRATION.md) documents every breaking change and the find/replace recipes to upgrade.

---

## Contributing

Issues and pull requests welcome. Start with [AGENTS.md](AGENTS.md) – the contributor reference for how SiteKit is built and how to extend it.

**License:** [MIT](LICENSE).
