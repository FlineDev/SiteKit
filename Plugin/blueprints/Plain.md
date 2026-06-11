# Blueprint: Plain

**A minimal starting point – static pages only, no blog, no opinions.**

## Quick Start

```bash
swift run sitekit new my-site --blueprint Plain
cd my-site
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **indigo** color scheme + **system** font pairing (system fonts = no web-font downloads, fitting the minimal goal) – change in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `Plain` when you want full control over what gets generated. Good for:

- Landing pages or product pages
- Sites where you'll add a custom pipeline
- Experimenting with SiteKit before committing to a structure

For an opinionated app/project showcase, see the `Portfolio` blueprint instead.

## Questions to Ask

1. **Site name and base URL?** (e.g. "My Site", "https://example.com")
2. **Author name?**
3. **Which static pages?** (Home and About are included by default)

## What It Generates

- Home page
- Static pages (add your own under `Content/Pages/`)
- Sitemap, robots.txt
- Open Graph / SEO metadata on every page

No blog listing, no categories, no RSS – add those manually via the `SiteBuilder` fluent API if needed.

## SiteConfig.yaml Structure

```yaml
name: "My Site"
baseURL: "https://example.com"

sections: []   # No blog sections – add manually if needed
```

## Entry Point

```swift
// Sources/Site/Main.swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.portfolio(configPath: "SiteConfig.yaml").run()
   }
}
```

The `portfolio` recipe includes only static page generation, home page, and sitemap. To add blog support, switch to `SiteBuilder.blog()` or compose a custom pipeline.

## Content Structure

```
Content/
├── Pages/
│   ├── About.md
│   └── Home.md
└── Assets/
    └── Images/
```

## Variations

- **Single landing page**: Remove all pages except `Home.md`, strip navigation down to just the home link.
- **Multi-page marketing site**: Add pages like `Features.md`, `Pricing.md`, `Contact.md` and corresponding nav items.
