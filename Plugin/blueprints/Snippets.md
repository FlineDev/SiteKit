# Blueprint: Snippets

**A short-form content site for code snippets, tips, and quick tutorials.**

## Quick Start

```bash
swift run sitekit new my-snippets --blueprint Snippets
cd my-snippets
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **teal** color scheme + **modern** font pairing – change in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `Snippets` when your content is short and code-focused. Good for:

- Code snippet collections
- Quick tips and how-tos
- TIL (Today I Learned) sites
- Cheat sheet blogs

For long-form articles, see the `Blog` blueprint. For a site combining blog + snippets + portfolio, see `IndieDev`.

## Questions to Ask

1. **Site name and base URL?** (e.g. "Swift Tips", "https://tips.example.com")
2. **Author name?**
3. **Topics?** If yes, which ones? (Optional groupings like "SwiftUI", "Concurrency", "Testing")
4. **Any static pages?** (About is included by default)

## What It Generates

- Snippet listing page (`/snippets/`)
- Individual snippet pages (`/snippets/<slug>/`)
- Tag listing pages (`/tags/<tag>/`)
- RSS feed
- Home page with recent snippets
- Static pages (About)
- Sitemap, robots.txt, llms.txt
- Open Graph / SEO metadata on every page
- Draft preview support

## SiteConfig.yaml Structure

```yaml
name: "Swift Tips"
baseURL: "https://tips.example.com"

sections:
  - name: "Snippets"
    slug: "snippets"
    contentDirectory: "Snippets"
    urlPrefix: "snippets"             # controls URLs: /snippets/<slug>/
    style: "short"
    description: "Quick Swift and SwiftUI code snippets"
    # Optional – remove for a flat snippet site without topic groups
    topics:
      - title: "SwiftUI"
        tags: [swiftui, animation, navigation]
      - title: "Swift"
        tags: [swift, concurrency, generics]
      - title: "Testing"
        tags: [testing, xctest, swift-testing]

navigation:
  items:
    - title: "Snippets"
      url: "/snippets/"
    - title: "About"
      url: "/about/"
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

Example end state – the scaffold ships a sample snippet and `Pages/About.md`; `Home.md` and `Assets/` are added as the site grows:

```
Content/
├── Snippets/
│   └── 2026-01-15_My-Quick-Tip.md
├── Pages/
│   ├── About.md
│   └── Home.md
└── Assets/
    └── Images/
```

## Variations

- **Flat snippets (no topics)**: Remove the `topics:` block. All snippets appear in one list, navigable by tags.
- **Topics as nav**: Replace the single "Snippets" nav link with individual topic links pointing to tag pages (e.g. `/tags/swiftui/`).
- **With footer**: Add a `footer:` block with `copyrightName`, `startYear`, and social links.
