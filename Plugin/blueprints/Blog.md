# Blueprint: Blog

**A full-featured blog with articles, optional categories, tags, and RSS feeds.**

## Quick Start

```bash
swift run sitekit new my-blog --blueprint Blog
cd my-blog
swift run Site serve     # preview at http://localhost:8080
```

Then edit `SiteConfig.yaml`, add posts under `Content/Blog/`, and deploy (see `references/deployment/hosts/cloudflare-pages.md`). The blueprint ships with the **teal** color scheme and the **modern** font pairing – change them in `Theme/theme.yaml` (see `references/themes.md` for the full catalog).

## When to Choose This

Choose `Blog` when you want to publish articles regularly. Good for:

- Developer blogs
- Personal sites with writing
- Sites that need categories and per-section RSS feeds
- Multi-language sites

For short-form content (code snippets, tips), see the `Snippets` blueprint. For a site combining blog + snippets + portfolio, see `IndieDev`.

## Questions to Ask

1. **Site name and base URL?** (e.g. "My Dev Blog", "https://example.com")
2. **Author name?**
3. **Categories?** If yes, which ones? (These become the main nav items by default)
4. **Any static pages?** (About is included; Privacy, Imprint, etc. are optional)

## What It Generates

- Blog listing page (`/blog/`)
- Individual article pages (`/blog/<slug>/`)
- Category listing pages (`/blog/<category>/`) – if categories are configured
- Tag listing pages (`/tags/<tag>/`)
- RSS feed per section (auto-generated – there's no `rssTitle`/`rssDescription` to set; each feed titles itself `"<Section name> – <Site name>"` and uses the site `description`)
- Home page with recent posts
- Static pages (About, optionally Privacy, Imprint)
- Sitemap, robots.txt, llms.txt
- Open Graph / SEO metadata on every page
- Draft preview support

## SiteConfig.yaml Structure

```yaml
name: "My Blog"
baseURL: "https://example.com"

sections:
  - name: "Blog"
    slug: "blog"
    contentDirectory: "Blog"
    urlPrefix: "blog"        # controls the URL: /blog/<slug>/
    description: "Latest posts from My Blog"
    # Optional – remove for a flat blog without categories
    categories:
      - name: "Developer"
        slug: "developer"
      - name: "Personal"
        slug: "personal"

# Option A: Categories as top-level nav (recommended for standalone blog)
navigation:
  items:
    - title: "Developer"
      url: "/blog/developer/"
    - title: "Personal"
      url: "/blog/personal/"
    - title: "About"
      url: "/about/"

# Option B: Single blog link (use this for a flat blog without categories)
# navigation:
#   items:
#     - title: "Blog"
#       url: "/blog/"
#     - title: "About"
#       url: "/about/"
```

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

## Content Structure

Example end state of a grown site – the scaffold itself ships only `Blog/` (one sample article) and `Pages/About.md`; `Home.md`, `Privacy.md`, and `Assets/` are added as the site grows:

```
Content/
├── Blog/
│   └── 2026-01-15_My-First-Article.md
├── Pages/
│   ├── About.md
│   ├── Home.md
│   └── Privacy.md
└── Assets/
    └── Images/
```

## Variations

- **Flat blog (no categories)**: Remove the `categories:` block from the section config and use Option B navigation (single "Blog" link).
- **Categories as nav**: Use Option A – each category appears as a top-level nav item. Best for standalone blog sites.
- **Multi-language**: Add a `localization:` block with the three required keys `defaultLanguage`, `languages` (additional languages, excluding the default), and `translationMode`, then add locale-suffixed content files. See `references/localization.md`.
- **With footer**: Add a `footer:` block with `copyrightName`, `startYear`, social links, and legal page links.
