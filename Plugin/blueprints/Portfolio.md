# Blueprint: Portfolio

**An app and project showcase site with static pages – no blog, no time-based content.**

## Quick Start

```bash
swift run sitekit new my-portfolio --blueprint Portfolio
cd my-portfolio
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **stone** color scheme + **professional** font pairing – change in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `Portfolio` when your site is primarily a showcase for apps, projects, or work. Good for:

- Indie developer app portfolios
- Freelancer project showcases
- Agency "our work" sites
- Open source project overviews

For a minimal blank canvas, see the `Plain` blueprint. For a site with blog + portfolio, see `IndieDev`.

## Questions to Ask

1. **Site name and base URL?** (e.g. "Jane's Apps", "https://janedev.com")
2. **Author name?**
3. **Which sections?** Apps is included by default. Also Open Source? Services?
4. **Home page headline and subtitle?**

## What It Generates

- Home page with title and subtitle
- Static pages (Apps, About, optionally Open Source, Privacy)
- Sitemap, robots.txt
- Open Graph / SEO metadata on every page

No blog listing, no RSS, no tags – this is a pure static-page site optimized for showcasing work.

## SiteConfig.yaml Structure

```yaml
name: "Jane's Apps"
baseURL: "https://janedev.com"

sections: []   # No content sections – pure static pages

navigation:
  items:
    - title: "Apps"
      url: "/apps/"
    # - title: "Open Source"
    #   url: "/open-source/"
    - title: "About"
      url: "/about/"

homePage:
  title: "Jane's Apps"
  subtitle: "Beautiful tools for everyday life"
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

Uses `SiteBuilder.blog()` (not `.portfolio()`) so all generators are available if you later decide to add a blog section.

## Content Structure

Example end state – the scaffold ships `Pages/Home.md`, `Pages/Apps.md`, and `Pages/About.md`; `Privacy.md` and `Assets/` are added as the site grows:

```
Content/
├── Pages/
│   ├── Home.md
│   ├── Apps.md
│   ├── About.md
│   └── Privacy.md
└── Assets/
    └── Images/
```

## Variations

- **With Open Source section**: Add an `OpenSource.md` page and uncomment the nav item.
- **With blog**: Add a `sections:` block and switch navigation to include a "Blog" link. At that point, consider using the `IndieDev` blueprint instead.
- **With footer**: Add a `footer:` block with `copyrightName`, `startYear`, social links, and legal page links.
