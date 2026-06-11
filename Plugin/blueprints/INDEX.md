# Blueprint Catalog

Blueprints are starter templates for SiteKit sites. Each blueprint provides a `SiteConfig.yaml`, `Package.swift`, `Main.swift` (with `@main`), sample content, and an AI instruction file explaining when to use it, what questions to ask, and what variations exist.

## File Structure

Each blueprint has two parts at the same level inside `blueprints/`:

- **`<Name>.md`** – AI instructions: when to choose, questions to ask, variations
- **`<Name>/`** – Template files to copy into a new project

Blueprint names use **PascalCase** (e.g. `Blog.md` + `Blog/`, `IndieDev.md` + `IndieDev/`).

Read `<Name>.md` first, then copy files from `<Name>/`.

---

## Available Blueprints

| Blueprint | Description | Best For | Guide |
|---|---|---|---|
| `Blog` | Articles, optional categories, tags, RSS | Developer blogs, personal writing | [Blog.md](Blog.md) |
| `Snippets` | Short-form content, optional topic groups | Code tips, TIL sites, cheat sheets | [Snippets.md](Snippets.md) |
| `Portfolio` | App/project showcase, static pages only | Indie dev portfolios, freelancer sites | [Portfolio.md](Portfolio.md) |
| `IndieDev` | Combined blog + snippets + portfolio | Full indie developer websites | [IndieDev.md](IndieDev.md) |
| `Podcast` | Episode pages, audio player, chapters, iTunes RSS | Podcast shows, interview series | [Podcast.md](Podcast.md) |
| `Newsletter` | Email newsletter with issue archive, signup forms, email rendering | Topic newsletters, curated digests, weekly/monthly roundups | [Newsletter.md](Newsletter.md) |
| `AppLanding` | Single product landing page with hero, features, pricing, reviews | App marketing pages, SaaS products | [AppLanding.md](AppLanding.md) |
| `DocC` | DocC catalog → static, AI-fetchable HTML with a sidebar + full-text search | Documentation sites, API/guide docs | [DocC.md](DocC.md) |
| `Plain` | Minimal structure, no opinions | Experimentation, custom pipelines | [Plain.md](Plain.md) |

---

## Which Blueprint Should I Use?

Use this decision tree:

0. **Do you have a DocC catalog (`.docc` – Markdown notes with DocC directives)?**
   - Yes → **`DocC`** (renders it to static, AI-fetchable HTML with a sidebar + full-text search)
   - No, continue ↓

1. **Is your content audio episodes (a podcast)?**
   - Yes → **`Podcast`**
   - No, continue ↓

2. **Is your content a periodic newsletter with email delivery?**
   - Yes → **`Newsletter`**
   - No, continue ↓

3. **Is your site a single product/app landing page?**
   - Yes → **`AppLanding`**
   - No, continue ↓

4. **Do you have time-based content (articles, posts, tips)?**
   - No → **`Portfolio`** (if showcasing apps/projects) or **`Plain`** (if you want a blank canvas)
   - Yes, continue ↓

5. **Is your content long-form (articles, tutorials) or short-form (code snippets, tips)?**
   - Long-form → **`Blog`**
   - Short-form → **`Snippets`**
   - Both → continue ↓

6. **Want both long- and short-form content? → `IndieDev`** – the only blueprint that combines a blog and snippets. Its apps/projects showcase is optional: keep it to feature your apps, or drop that section if you only want blog + snippets.

### Quick Comparison

| Feature | `Plain` | `Blog` | `Snippets` | `Portfolio` | `Newsletter` | `AppLanding` | `IndieDev` | `Podcast` | `DocC` |
|---|---|---|---|---|---|---|---|---|---|
| Static pages | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – (catalog guides) |
| Blog articles | – | ✅ | – | – | ✅ (issues) | – | ✅ | – | – (catalog notes) |
| Short-form snippets | – | – | ✅ | – | – | – | ✅ | – | – |
| Episode pages | – | – | – | – | – | – | – | ✅ | – |
| Audio player | – | – | – | – | – | – | – | ✅ | – |
| Chapter markers | – | – | – | – | – | – | – | ✅ | – |
| Email HTML rendering | – | – | – | – | ✅ | – | – | – | – |
| Signup forms | – | – | – | – | ✅ | – | – | – | – |
| Categories | – | Optional | – | – | – | – | Optional | – | – |
| Tags | – | ✅ | ✅ | – | ✅ | – | ✅ | ✅ | – |
| RSS feeds | – | ✅ | ✅ | – | ✅ | – | ✅ | iTunes RSS | – |
| Landing page sections | – | – | – | – | – | ✅ | – | – | – |
| App showcase pages | – | – | – | ✅ | – | – | ✅ | – | – |
| Host showcase | – | – | – | – | – | – | – | ✅ | – |
| Home page config | – | ✅ | ✅ | ✅ | ✅ | YAML-driven | ✅ | ✅ | YAML-driven |
| Draft previews | – | ✅ | ✅ | – | ✅ | – | ✅ | ✅ | – |

`DocC`'s documentation-specific features (sidebar tree, full-text search with facets, contributors pages, missing-sessions coverage, DocC directive rendering) have no row here – see [DocC.md](DocC.md) for its feature set.

### Navigation Strategy

**Standalone blueprints** (`Blog`, `Snippets`) use their categories/topics as top-level nav items – since there's no other content type, categories can be the primary navigation. `Newsletter` uses a flat "Archive + About" nav pattern (no categories).

**Multi-section blueprints** (`IndieDev`) use sections as top-level nav items (Apps, Blog, Snippets, About). Categories and topics are accessible within each section but aren't in the main nav.

| Standalone blog nav | IndieDev nav |
|---|---|
| Developer · Personal · About | Apps · Blog · Snippets · About |

---

## Naming Conventions

SiteKit uses consistent naming across all user-facing files:

| What | Convention | Examples |
|---|---|---|
| Folders | PascalCase | `Content/`, `Blog/`, `Pages/`, `Assets/` |
| Static pages | PascalCase | `About.md`, `Home.md`, `Apps.md` |
| Blog/snippet posts | Date + underscore + PascalCase | `2026-01-01_Hello-World.md` |
| Config files | PascalCase | `SiteConfig.yaml`, `Package.swift` |
| Swift entry point | PascalCase with `@main` | `Sources/Site/Main.swift` |
| Output directory | Underscore + PascalCase (gitignored) | `_Site/` |
| Generated URLs | Always lowercase | `/blog/hello-world/`, `/about/` |

**Why PascalCase source → lowercase URLs?** Source files are maintained by humans and follow PascalCase for readability. Generated URLs are always lowercase because search engines treat `/About` and `/about` as different pages (causing duplicate content issues). SiteKit's slug generation handles this mapping automatically.

The only lowercase exceptions are files required by external tools: `main.swift` (SPM requirement – we use `@main` + `Main.swift` to avoid this), `.gitignore` (Git requirement).

---

## How to Use a Blueprint

1. Read `<Name>.md` for context and questions to ask
2. Copy all files from `<Name>/` into the new project root
3. Fill in `SiteConfig.yaml` with the user's answers
4. Run `swift run Site build` to verify
5. Run `swift run Site serve` for local preview

All blueprints use the same `Package.swift`. The differences are in `SiteConfig.yaml`, the `@main` entry point recipe, and the content structure.
