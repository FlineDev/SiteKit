# Blueprint: IndieDev

**A multi-section site combining blog, snippets, and an apps page – the full indie developer website.**

This is a composition guide. Each section is based on a standalone blueprint (`Blog`, `Snippets`, `Portfolio`). Refer to those blueprints for section-specific options like categories, topics, and variations.

## Quick Start

```bash
swift run sitekit new my-site --blueprint IndieDev
cd my-site
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **teal** color scheme and the **modern** font pairing – change them in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `IndieDev` when you need more than one content type on the same site. Good for:

- Indie developers who blog, share code, and showcase apps
- Developer advocates with articles + code examples + project portfolio
- Anyone whose content doesn't fit a single blog

If you only need one of these, use the standalone blueprint instead.

## Questions to Ask

1. **Site name and base URL?**
2. **Author name?**
3. **Which sections?** Pick at least 2:
   - **Blog** – long-form articles (see `Blog` blueprint for category options)
   - **Snippets** – short-form code tips (see `Snippets` blueprint for topic options)
   - **Apps/Portfolio** – static showcase pages (see `Portfolio` blueprint)
4. **Home page headline and subtitle?**
5. **Navigation order?** Which sections appear first in the nav bar?

## How It Differs from Standalone Blueprints

Standalone blueprints (Blog, Snippets, Portfolio) are designed to be the **only** content on the site, so they use their categories/topics as top-level navigation items. The IndieDev blueprint adds a **section-switcher level** on top:

| Standalone blog nav | IndieDev nav |
|---|---|
| Developer · Personal · About | Apps · Blog · Snippets · About |

Each section becomes a single nav item. Categories and topics are still accessible within each section, but they're no longer the top-level navigation.

## Composition Concerns

### Navigation Strategy

All sections appear as top-level nav items. Order them by priority:

```yaml
navigation:
  items:
    - title: "Apps"
      url: "/apps/"
    - title: "Blog"
      url: "/blog/"
    - title: "Snippets"
      url: "/snippets/"
    - title: "About"
      url: "/about/"
```

### URL Prefix Strategy

Each section gets its own URL prefix to avoid slug collisions:

- Blog articles: `/blog/<slug>/`
- Snippets: `/snippets/<slug>/`
- Static pages: `/<slug>/` (top-level)

Each section's URL comes from its own `urlPrefix:` in the `sections:` list (e.g. `urlPrefix: "blog"` → `/blog/<slug>/`, flat, no category in the path). The legacy top-level `blogURLPrefix` is **ignored** once you declare `sections` explicitly – set the prefix on the section instead.

### Home Page

The home page typically shows recent posts from the blog section. Configure with:

```yaml
homePage:
  title: "My Dev Site"
  subtitle: "Apps, articles, and code snippets"
  recentPostsCount: 6
```

### Cross-Section Promotions (Optional)

You can promote apps/packages within blog posts using the `promotions:` config block. See the `promotions:` section in the SiteConfig reference for a full example. This is entirely optional.

## SiteConfig.yaml Structure

See `IndieDev/SiteConfig.yaml` for the full template. Key differences from standalone blueprints:

- Multiple `sections:` entries (Blog + Snippets)
- Navigation lists all sections as top-level items
- `homePage:` configured for multi-section landing
- `footer:` with copyright and social links

For section-specific options:
- **Blog categories**: See `Blog` blueprint
- **Snippet topics**: See `Snippets` blueprint
- **Portfolio pages**: See `Portfolio` blueprint

## Entry Point

```swift
// Sources/Site/Main.swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()
   }
}
```

Same entry point as the Blog blueprint – `SiteBuilder.blog()` handles all section types.

## Content Structure

Example end state of a grown site – the scaffold ships sample files for Blog/, Snippets/, and Pages/ (Home, Apps, About); `Privacy.md` and `Assets/` are added as the site grows:

```
Content/
├── Blog/
│   └── 2026-01-15_My-First-Article.md
├── Snippets/
│   └── 2026-01-15_My-Quick-Tip.md
├── Pages/
│   ├── Home.md
│   ├── Apps.md
│   ├── About.md
│   └── Privacy.md
└── Assets/
    └── Images/
```

## Variations

- **Blog + Portfolio (no snippets)**: Remove the Snippets section from `sections:` and navigation. Keep Blog + Apps + About.
- **Blog + Snippets (no portfolio)**: Remove the Apps page and nav item. Keep Blog + Snippets + About.
- **With promotions**: Add a `promotions:` block to cross-promote apps within blog posts. See the SiteConfig reference for the full promotion schema.
- **Multi-language**: Add a `localization:` block with the three required keys `defaultLanguage`, `languages` (additional languages, excluding the default), and `translationMode`. Each locale can override navigation titles and home page text via `localeOverrides`.
