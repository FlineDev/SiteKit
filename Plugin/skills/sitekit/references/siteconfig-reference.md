# SiteConfig.yaml Reference

Complete reference for all fields in `SiteConfig.yaml` – the central configuration file for every SiteKit site.

> **Required vs. optional.** Only four keys are required (the decoder fails the build if they are missing): `name`, `baseURL`, `contentDirectory`, `outputDirectory`. Everything else is optional and decodes to a sensible default (shown in parentheses below). `language` is optional and defaults to `en`. Theme configuration is **not** here – it lives in `Theme/theme.yaml` (see themes.md); per-article frontmatter is documented in content-writing.md.

---

## Top-Level Fields

| Field | Type | Required / Default | Description |
|-------|------|---------|-------------|
| `name` | String | **required** | Site display name, used in the `<title>` tag and RSS feeds |
| `baseURL` | String | **required** | Canonical base URL (no trailing slash), e.g. `https://example.com` |
| `contentDirectory` | String | **required** | Root directory containing all content subdirectories (blueprints set `Content`) |
| `outputDirectory` | String | **required** | Directory where the built site is written (blueprints set `_Site`) |
| `language` | String | `en` | BCP 47 language code for the primary language. (Legacy alias: `defaultLanguage` – still accepted, but `language` is the current key.) |
| `description` | String | `""` | Short site description for SEO meta tags and RSS |
| `assetsDirectory` | String | `Content/Assets` | Path to static assets copied verbatim to `_Site/assets/` |
| `redirectsFile` | String | – | Path to a YAML file listing URL redirects (e.g. `redirects.yaml`) – see *Redirects file* below |
| `blogURLPrefix` | String | – | **Legacy.** When `sections` is omitted, synthesizes a `Blog` section using this URL prefix. Prefer declaring `sections` explicitly. |
| `snippetsURLPrefix` | String | – | **Legacy.** Pairs with `blogURLPrefix`: when set (and `sections` omitted), synthesizes a short-style `Snippets` section. Prefer `sections`. |

**Example:**

```yaml
name: "My Dev Blog"
baseURL: "https://example.com"
description: "Swift development articles by Your Name"
outputDirectory: "_Site"
contentDirectory: "Content"
language: "en"
assetsDirectory: "Content/Assets"
```

---

## `author`

Author information used in RSS feeds, Open Graph tags, and article bylines.

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Full display name |
| `email` | String | Email address (used in RSS `<author>` element) |
| `imageURL` | String | URL to a profile image |
| `url` | String | URL to the author's about/profile page |

**Example:**

```yaml
author:
  name: "Your Name"
  email: "you@example.com"
  imageURL: "/assets/images/profile.webp"
  url: "/about/"
```

---

## `sections[]`

Defines content sections – each maps to a content directory and generates listing pages, RSS feeds, and article pages.

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name (e.g. "Blog") |
| `slug` | String | URL-safe identifier (e.g. `blog`) |
| `contentDirectory` | String | Subdirectory under `contentDirectory` containing this section's files |
| `urlPrefix` | String | URL path prefix for this section's pages (e.g. `blog` → `/blog/slug/`) |
| `description` | String | Short description of the section (also used as the RSS `<channel>` description; the channel title uses `name`) |
| `style` | String | `standard` (default) or `short` for snippet-style sections |
| `backLinkText` | String | Optional label for the "back to section" link on article pages |
| `categories[]` | Array | List of category definitions (see below) |
| `topics[]` | Array | Topic groupings for short-style sections (see below) |

**`categories[]` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Display name (e.g. "Developer") |
| `slug` | String | URL-safe identifier (e.g. `developer`) |
| `description` | String | Short description used in category listing pages |

**`topics[]` fields (for `style: short` sections):**

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Display label for this topic group |
| `tags` | Array | Tags that belong to this topic group |

**Example:**

```yaml
sections:
  - name: "Blog"
    slug: "blog"
    contentDirectory: "Blog"
    urlPrefix: "blog"
    description: "Articles on Swift and indie development"
    categories:
      - name: "Developer"
        slug: "developer"
        description: "Swift development articles"
      - name: "Indie"
        slug: "indie"
        description: "Indie app development"

  - name: "Snippets"
    slug: "snippets"
    contentDirectory: "Snippets"
    urlPrefix: "snippets"
    style: "short"
    topics:
      - title: "SwiftUI"
        tags: [swiftui, animation, navigation]
      - title: "Swift"
        tags: [swift, concurrency]
```

---

## `categories[]`

Top-level category list (mirrors or supplements section categories). Used by generators that need a flat list of all categories across the site.

Same fields as `sections[].categories[]`: `name`, `slug`, `description`.

---

## `navigation`

Controls the site-wide navigation bar.

| Field | Type | Description |
|-------|------|-------------|
| `logo.text` | String | Text shown as the logo/site name |
| `logo.image` | String | URL to a logo image (shown instead of or alongside text) |
| `logo.imageWidth` | Int | Optional intrinsic logo width (px) – set both dimensions to reserve space and avoid layout shift |
| `logo.imageHeight` | Int | Optional intrinsic logo height (px) |
| `items[]` | Array | Navigation links |
| `items[].title` | String | Link label |
| `items[].url` | String | Link URL |
| `items[].icon` | String | Optional Font Awesome icon class (e.g. `fa-solid fa-pen-to-square`) |
| `showSearch` | Bool | Whether the nav bar shows the search control |
| `showThemeToggle` | Bool | Whether the nav bar shows the light/dark theme toggle |

**Example:**

```yaml
navigation:
  logo:
    text: "MySite"
    image: "/assets/theme/images/logo.webp"
  items:
    - title: "Blog"
      url: "/blog/"
      icon: "fa-solid fa-pen-to-square"
    - title: "About"
      url: "/about/"
      icon: "fa-solid fa-user"
```

---

## `footer`

Controls the site footer.

| Field | Type | Description |
|-------|------|-------------|
| `copyright` | String | Raw copyright string (full override). Prefer `copyrightName` + `startYear` for auto-generated year ranges. |
| `copyrightName` | String | Name shown in the copyright notice |
| `startYear` | Int | First copyright year; auto-generates a range (e.g. `2024–2026`) if not current year |
| `showAttribution` | Bool | Whether to show "Built with SiteKit" (default: `true`) |
| `social[]` | Array | Social media links |
| `social[].platform` | String | Platform key (e.g. `bluesky`, `mastodon`, `github`, `twitter`) |
| `social[].url` | String | Profile URL |
| `social[].rel` | String | Optional `rel` attribute (e.g. `me` for Mastodon verification) |
| `links[]` | Array | Footer navigation links |
| `links[].title` | String | Link label |
| `links[].url` | String | Link URL |

**Example:**

```yaml
footer:
  copyrightName: "Your Name"
  startYear: 2024
  showAttribution: true
  social:
    - platform: "bluesky"
      url: "https://bsky.app/profile/you.bsky.social"
    - platform: "mastodon"
      url: "https://mastodon.social/@you"
      rel: "me"
  links:
    - title: "Privacy Policy"
      url: "/privacy/"
    - title: "Imprint"
      url: "/imprint/"
```

---

## `homePage`

Configuration for the generated home page.

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Heading shown on the home page |
| `subtitle` | String | Subheading / tagline |
| `recentPostsCount` | Int | Optional. Number of recent posts shown in the "Recent Posts" section. When absent, the blog home shows 5 and the podcast home shows 10. |

**Example:**

```yaml
homePage:
  title: "My Blog"
  subtitle: "Swift and indie development by Your Name"
  recentPostsCount: 5
```

---

## `errorPages`

Configuration for generated error pages.

| Field | Type | Description |
|-------|------|-------------|
| `"404".title` | String | Title shown on the 404 page |
| `"404".message` | String | Message shown on the 404 page |

**Example:**

```yaml
errorPages:
  "404":
    title: "Page Not Found"
    message: "The page you're looking for doesn't exist or has been moved."
```

---

## `theme`

Points at the theme directory. This is the **only** theme-related key in `SiteConfig.yaml`:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `directory` | String | `Theme` | Directory holding `theme.yaml`, theme CSS, JS, and images |

```yaml
theme:
  directory: "Theme"
```

All actual theme configuration – `preset`, `colorScheme`, `fontPairing`, `tokens`, `css`, `js`, `selfHostedFonts`, etc. – lives in **`Theme/theme.yaml`**, a separate file with its own top-level schema. See **themes.md** for the full theme schema and token catalog. Do not put `preset`/`tokens` under `theme:` in `SiteConfig.yaml` – they are ignored there.

---

## `promotions`

Build-time promotion distribution – inserts contextual calls-to-action into articles at build time.

| Field | Type | Description |
|-------|------|-------------|
| `endSlots` | Int | How many promotions to insert at the end of an article |
| `inlineSlots` | Int | How many promotions to insert inline within an article body |
| `audienceMapping` | Map | Maps category slugs to audience types (`developer` or `consumer`) |
| `items[]` | Array | List of promotion definitions |

**`items[]` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | **Required.** Unique identifier for this promotion |
| `audience` | String | Optional. Target audience: `developer`, `consumer`, or `general` (matches everything). When absent, the promo is eligible on every article |
| `weight` | Int | **Required.** Relative weight for the stable weighted selection – higher surfaces more often |
| `style` | String | **Required.** Visual style: `highlight` (callout box) or `oss` (subtle inline mention) – emitted as CSS class `sk-promo-<style>` |
| `emoji` | String | Optional emoji shown before the title |
| `title` | String | Promotion heading |
| `text` | String | Promotion body (supports Markdown links) |
| `linkURL` | String | Optional explicit call-to-action URL (alternative to a Markdown link in `text`) |
| `linkText` | String | Optional label for `linkURL` |
| `targetTags` | Array | Only show in articles with at least one of these tags |
| `excludeTags` | Array | Never show in articles with any of these tags |
| `boostTags` | Array | Show more frequently in articles with these tags |
| `localized` | Map | Per-language overrides for `title`, `text`, and `linkText` |

**Example:**

```yaml
promotions:
  audienceMapping:
    developer: developer
    indie: consumer
  items:
    - id: "my-tool"
      audience: "developer"
      weight: 1
      style: "highlight"
      emoji: "🛠️"
      title: "Try My Tool!"
      text: "Check out [MyTool](https://example.com) – it does the thing."
      excludeTags: ["my-tool"]
      boostTags: ["swift", "productivity"]
```

---

## `localization`

Multi-language configuration. Omit this section entirely for single-language sites.

| Field | Type | Description |
|-------|------|-------------|
| `defaultLanguage` | String | **Required.** Primary language code (BCP 47, e.g. `en`) |
| `languages` | Array | **Required.** The ADDITIONAL language codes to build, excluding `defaultLanguage` (e.g. `["de", "ja"]` on an English-default site) |
| `translationMode` | String | **Required.** How translations are produced, e.g. `manual` (author-provided) – informational for tooling, surfaced in the generated translation status JSON |
| `styleGuidePath` | String | Override for the translation style guide location. Defaults to `Guidelines/Translations.md` at the project root – only set this if you keep the file elsewhere. |
| `legalLanguage` | String | Language in which legally binding pages (Privacy, Imprint) are authoritative |
| `translationNotice.enabled` | Bool | Whether to show a notice on translated pages |
| `translationNotice.verifiedLanguages` | Array | Languages reviewed by a native speaker (no notice shown for these) |
| `localeOverrides` | Map | Per-language overrides for `description`, `homePage`, `navigation`, `footer` |

**Example:**

```yaml
localization:
  defaultLanguage: "en"
  languages: ["de", "ja"]
  translationMode: "manual"
  legalLanguage: "de"
  translationNotice:
    enabled: true
    verifiedLanguages: ["en", "de"]
  localeOverrides:
    de:
      description: "Swift-Artikel auf Deutsch"
      homePage:
        title: "Mein Blog"
        subtitle: "Swift-Entwicklung von Your Name"
```

---

## `tagDisplayNames`

A map from tag slugs to human-readable display names. Used in tag listing pages and article metadata.

```yaml
tagDisplayNames:
  swift: "Swift"
  swiftui: "SwiftUI"
  in-app-purchases: "In-App Purchases"
  wwdc24: "WWDC24"
```

Add an entry here whenever you introduce a new tag in your content.

---

## `podcast`

Podcast-feed configuration (used by the Podcast blueprint to generate the iTunes RSS feed and episode chrome). All fields optional.

| Field | Type | Description |
|-------|------|-------------|
| `artworkPath` | String | Path to the podcast cover artwork (iTunes requires ≥ 1400×1400) |
| `feedPath` | String | Output path for the generated RSS feed |
| `legacyFeedPaths` | Array | Old feed paths to emit redirects from (feed-migration continuity) |
| `itunesCategory` | String | Apple Podcasts primary category |
| `itunesSubcategory` | String | Apple Podcasts subcategory |
| `explicit` | Bool | iTunes explicit flag |
| `itunesType` | String | `episodic` or `serial` |
| `podcastGuid` | String | Stable `<podcast:guid>` for the feed |
| `hosts[]` | Array | Show hosts – each `{ name, image?, role?, href? }` |
| `subscribeLinks[]` | Array | Subscribe buttons – each `{ platform, url, label? }` |

**Example:**

```yaml
podcast:
  artworkPath: "Content/Assets/images/cover.png"
  feedPath: "feed.xml"
  itunesCategory: "Technology"
  explicit: false
  itunesType: "episodic"
  hosts:
    - name: "Your Name"
      role: "Host"
      href: "/about/"
  subscribeLinks:
    - platform: "apple"
      url: "https://podcasts.apple.com/..."
      label: "Apple Podcasts"
```

---

## `docc`

DocC-blueprint-specific configuration (used by the `.docc()` blueprint). **The whole block is optional** – a DocC site renders fine with none of it set; these fields only customize the generated home page, the appbar, the sidebar, the footer, and the search overlay. Every field is optional.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `homeEyebrow` | String | – | Eyebrow text rendered above the home hero title. |
| `homeAbstract` | String | `description` | Hero subtitle on the home page, separate from the SEO `description` so the hero copy can differ from the meta tag. Falls back to `SiteConfig.description` when absent. |
| `homeOverviewLead` | String | – | Lead sentence below the Overview section heading. Has no effect unless `homeWays` is also populated. |
| `homeWays[]` | Array | – | Numbered "ways to use the site" items for the Overview section. The whole section is omitted when this is absent or empty. See sub-fields below. |
| `homeContributing` | Map | – | Copy for the Contributing section (lead sentence + call-to-action link). The whole section is omitted when absent. See sub-fields below. |
| `homeContributorsBlurb` | String | – | Blurb shown in the Contributors mosaic card in the Topics grid. Omitted when absent. |
| `footerCards[]` | Array | – | Call-to-action cards rendered in the footer of every DocC page. When omitted, the footer is not emitted. See sub-fields below. |
| `footerDisclaimer` | String | – | Disclaimer paragraph rendered in the footer legal block, below the brand mark (trademark notices, "not affiliated with" statements). Rendered as HTML-escaped plain text. When present, the legal block always shows the site name as the brand mark; when absent, the legal block is omitted. |
| `footerLegalNotice` | String | – | Legal small print rendered in the footer legal block below the disclaimer – copyright lines and full trademark notices too long for the one-sentence `footerDisclaimer`. HTML-escaped plain text; line breaks (e.g. from a YAML block scalar) separate paragraphs. |
| `brand` | Map | – | 2-tone brand for the appbar wordmark. When absent, the appbar renders `name` as a plain single-color label. See sub-fields below. |
| `frameworks` | Map | – | Registry mapping a framework slug to an icon descriptor. Session notes declare their framework via `<!-- framework: <slug> -->`, a `@CustomAttribute(name: "framework", value: …)`, or the central `sessionFrameworksPath` map. The sidebar renders the matching Font Awesome glyph; notes with no framework (or an unknown key) get a neutral placeholder. See sub-fields below. |
| `sessionFrameworksPath` | String | – | Path (relative to the project directory) to a flat JSON file mapping session ids to framework keys, e.g. `Sources/session-frameworks.json`. The key format is `wwdcYY-<code>` (the first two dash-separated segments of the note slug, e.g. `wwdc25-101-keynote` → key `wwdc25-101`). A per-note framework value always wins over this map. A missing or unreadable file is skipped gracefully (the enricher is just not added). |
| `guideIcons` | Map | – | Maps a loose guide page's slug to a Font Awesome glyph class, e.g. `contributing: "fa-solid fa-pen-to-square"`. Guides without an entry (or when the map is absent) get a sensible default glyph, never an empty placeholder. |
| `sidebarContributorsLimit` | Int | – | Optional. Maximum number of top contributors shown in the collapsible Contributors subtree. When absent there is no cap – every contributor is shown. |
| `contributors` | Bool | `false` | Enables the contributors feature: the `/contributors/` overview page, per-contributor profile pages, and the sidebar Contributors subtree. `@Contributors` parsing always runs – only the pages and routes gate. |
| `missingSessions` | Bool | `false` | Enables the missing-sessions feature: the `/missingnotes/` coverage page listing catalog entries without notes yet. |
| `search` | Bool | `true` | Enables full-text search: the `/search/` page plus the sharded search index and its client scripts. Set `false` for a search-free docs site. |
| `searchNoteTypeFilter` | Bool | `false` | Enables the Note-type facet group (All/AI/Community/Stub) on the search page. Result-row badges render regardless. |
| `articleHero` | String | `card` | Article/guide header style: `card` (rounded gradient card with prism art, matching the other heroes) or `band` (square-cornered full-width color band, classic DocC look). Any other value fails decoding loudly. |
| `avatarFallbackPath` | String | – | Asset path for the avatar fallback image used when a contributor's GitHub avatar fails to load (e.g. `"avatar-fallback.svg"` → `/assets/avatar-fallback.svg`). When absent, a broken avatar simply disappears (browser `onerror` default). |
| `years` | Map | – | Per-year editorial data keyed by year label (e.g. `"WWDC25"`), feeding the Topics card grid on the home page. See sub-fields below. |
| `contributorsBecomeHref` | String | – | URL for the "Become a contributor" button on the contributors page. When absent, the button is omitted (safe for plain docs sites with no contributing guide). |
| `missingContributeHref` | String | – | URL for the "Learn how to contribute" call-to-action on the missing-sessions page. When absent, the CTA is omitted. |
| `searchSuggestions[]` | Array of String | – | Pre-populated search suggestion chips shown in the search overlay below the input when it is empty ("Try: …"). When absent or empty, no suggestions are shown. |
| `defaultCodeLanguage` | String | – | Default syntax-highlighting language for fenced code blocks that carry no language tag (a bare opening fence with no language). When set, untagged blocks are highlighted as if tagged with this language; when absent, untagged blocks render as plain escaped text. Does not affect blocks that already carry an explicit language tag. For WWDCNotes-style catalogs set this to `"swift"`. |

**`brand` fields** (a 2-tone appbar wordmark: a primary span in `--color-text` + an accent span in `--color-accent`):

| Field | Type | Description |
|-------|------|-------------|
| `prefix` | String | **Required.** The first (primary) part of the wordmark, rendered in the default text color. |
| `accent` | String | **Required.** The second part of the wordmark, rendered with `--color-accent`. |
| `logoPath` | String | Optional path to a logo image relative to `/assets/` (e.g. `"logo.svg"` → `/assets/logo.svg`). When present, an `<img>` is rendered to the left of the wordmark. |
| `logoWidth` | Int | Optional logo width in CSS pixels; overrides the stylesheet's logo box via an inline style. Zero or negative values are ignored. |
| `logoHeight` | Int | Optional logo height in CSS pixels; independent of `logoWidth` (setting only one overrides just that axis, `object-fit: contain` preserves the aspect). |

**`frameworks` value fields** (keyed by framework slug; describes how to render the sidebar icon):

| Field | Type | Description |
|-------|------|-------------|
| `glyph` | String | A Font Awesome class string, e.g. `"fa-solid fa-layer-group"`. Inlined by `FontAwesomeInliner` at build time (no CDN request). |
| `colors[]` | Array of String | 1 or 2 hex color strings. One color → plain color; two colors → a `linear-gradient(145deg, …)`. |
| `displayName` | String | Optional human-readable label shown wherever the framework appears as visible text (e.g. the search page's Topic chips), like `"App Intents"` for `appintents`. URL params and filtering keep the raw key; when absent, the raw key is displayed. |

**`footerCards[]` fields** (all four required – a card with no link or label is a dead end):

| Field | Type | Description |
|-------|------|-------------|
| `heading` | String | Card heading. |
| `body` | String | Card body text. |
| `ctaLabel` | String | Call-to-action label. |
| `href` | String | Call-to-action destination URL. |

**`homeWays[]` fields** (each item is auto-numbered in the rendered list):

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Short headline, e.g. "Search anything". |
| `body` | String | One-sentence explanation. |

**`homeContributing` fields** (rendered as a lead sentence with a trailing inline link):

| Field | Type | Description |
|-------|------|-------------|
| `lead` | String | Introductory sentence, e.g. "Missing something? Spotted a mistake?". |
| `linkText` | String | Anchor text for the contributing-guide link. |
| `linkHref` | String | Destination URL for the contributing guide or pull-request page. |

**`years` value fields** (keyed by year label; all optional, so partial overrides are valid):

| Field | Type | Description |
|-------|------|-------------|
| `stack` | String | Tech-stack summary line, e.g. "Xcode 26 · Swift 6.2 · iOS 26". |
| `blurb` | String | One or two sentence summary of the year's highlights. |
| `apis` | String | Comma-separated key APIs or framework names, e.g. "Foundation Models, AlarmKit". |
| `keyVisual` | String | Explicit path to the key-visual banner image (relative to `/assets/`). When absent, core tries the convention path `/assets/<label>.jpeg`, then falls back to a hue-derived generative gradient. |

**Example:**

```yaml
docc:
  homeEyebrow: "WWDC notes, by the community"
  homeAbstract: "Searchable, AI-fetchable notes for every session."
  brand:
    prefix: "WWDC"
    accent: "Notes"
    logoPath: "logo.svg"
  defaultCodeLanguage: "swift"
  sidebarContributorsLimit: 14
  avatarFallbackPath: "avatar-fallback.svg"
  sessionFrameworksPath: "Sources/session-frameworks.json"
  searchSuggestions: ["SwiftUI", "Concurrency", "Foundation Models"]
  frameworks:
    swiftui:
      glyph: "fa-solid fa-layer-group"
      colors: ["#1e88e5", "#42a5f5"]
  homeWays:
    - title: "Search anything"
      body: "Press ⌘K to search across every note."
  homeContributing:
    lead: "Missing something? Spotted a mistake?"
    linkText: "Contributions are welcome"
    linkHref: "https://github.com/your-org/your-notes"
  contributorsBecomeHref: "https://github.com/your-org/your-notes#contributing"
  missingContributeHref: "https://github.com/your-org/your-notes#contributing"
  footerCards:
    - heading: "Contribute"
      body: "Add or improve a note."
      ctaLabel: "Open the repo"
      href: "https://github.com/your-org/your-notes"
  footerDisclaimer: "Not affiliated with Apple Inc. WWDC is a trademark of Apple Inc."
  years:
    WWDC25:
      stack: "Xcode 26 · Swift 6.2 · iOS 26"
      blurb: "The year of on-device intelligence."
      apis: "Foundation Models, AlarmKit"
      keyVisual: "WWDC25.jpeg"
```

For the directive syntax authors use inside `.docc` notes (`@Metadata`, `@Row`, `@TabNavigator`, …), see **markdown-extensions.md**.

---

## Redirects file

`redirectsFile` (top-level) names a YAML file whose schema is a single `redirects:` list. Each rule has `from`, `to`, and an optional `status` (defaults to a permanent redirect when omitted):

```yaml
# redirects.yaml
redirects:
  - from: "/old-post/"
    to: "/blog/new-post/"
    status: 301
  - from: "/legacy/"
    to: "/"
```

These feed the host redirect emitters (Cloudflare `_redirects`, HTML redirect pages).

---

## Content frontmatter

Per-article and per-page YAML frontmatter (`title`, `date`, `tags`, `summary`, `draft`, …) is **not** part of `SiteConfig.yaml`. For the full frontmatter field contract – including which fields are required and how articles vs. static pages differ – see **content-writing.md**.

---

## See also

- **themes.md** – the `Theme/theme.yaml` schema (presets, color schemes, font pairings, tokens).
- **content-writing.md** – per-article frontmatter fields and authoring.
- **localization.md** – multi-language strategy behind the `localization` block.
- **newsletter-setup.md** – newsletter delivery behind the signup-form configuration.
- **markdown-extensions.md** – the DocC-compatible Markdown directives used inside `.docc` notes (the authoring counterpart to the `docc:` config block).
