# Themes

SiteKit uses a **token-based theming system** that generates CSS custom properties from layered YAML configuration. You control the visual identity of your site by choosing presets, color schemes, font pairings, and optionally overriding individual tokens.

**Accessibility invariant.** The shipped color schemes and presets are pre-validated for WCAG AA contrast on body text in both light and dark modes – this is one of the four cross-cutting concerns SiteKit guarantees across the pipeline. If you override `colorTextMuted`, `colorTextSecondary`, or `colorBg` under `theme.tokens`, you take on responsibility for verifying the resulting contrast – run `swift run Site validate` and the `accessibility.md` checklist to confirm.

---

## How the Token System Works

Tokens are resolved in a strict order. Each layer overrides values from the previous one:

1. **Layout defaults** – sensible fallback values for layout tokens (max-width, border-radius, transitions)
2. **Preset** – a complete starting point with colors, fonts, and layout
3. **Color scheme** – overrides color tokens only (leaves fonts and layout untouched)
4. **Font pairing** – overrides font tokens only (leaves colors and layout untouched)
5. **Token overrides** – individual token values set directly in `Theme/theme.yaml` under `tokens:`

This means you can start with a preset and swap just the colors or just the fonts without touching anything else. Or skip presets entirely and build up from individual tokens.

### Example: resolution in practice

```yaml
# Theme/theme.yaml
name: "my-theme"
preset: warm              # Step 2: warm preset (ivory bg, teal accent, Sora + Nunito Sans)
colorScheme: violet       # Step 3: swap all colors to violet scheme
fontPairing: editorial    # Step 4: swap fonts to editorial (serif headings)
tokens:                   # Step 5: override just the accent color
   colorAccent:
      any: "#e11d48"
      dark: "#fb7185"
```

Result: violet color scheme + editorial fonts + custom accent color, with layout values from the warm preset.

---

## `theme.yaml` structure

Theme configuration lives in a **standalone `Theme/theme.yaml`** file at the project root – **not** inside `SiteConfig.yaml`. The build decodes it into `ThemeConfig` (the theme directory defaults to `Theme/`). All keys are top-level:

| Key | Type | Required | Purpose |
|---|---|---|---|
| `name` | string | **yes** | Theme display name |
| `preset` | string | no | Starting token bundle – `default` / `warm` / `minimal` / `bold` |
| `colorScheme` | string | no | One of the 15 color schemes (overrides color tokens) |
| `fontPairing` | string | no | One of the 6 font pairings (overrides font tokens) |
| `tokens` | map | no | Per-token overrides – `colorAccent`, `maxWidth`, … each with `any` + optional `dark` |
| `css` | list of strings | no | Theme CSS files to include (paths relative to `Theme/`, e.g. `css/theme.css`) |
| `js` | list of strings | no | Theme JS files to include (e.g. `js/theme.js`) |
| `externalCSS` | list of strings | no | External stylesheet URLs (e.g. a Font Awesome CDN link) |
| `headInlineScript` | string | no | Tiny inline `<head>` script – used for the no-flash dark-mode bootstrap |
| `selfHostedFonts` | bool | no | `true` → emit local `@font-face` from `Theme/fonts/` instead of Google Fonts |
| `inlineFontAwesome` | bool | no | `false` → keep the Font Awesome CDN stylesheet instead of inlining used icons |
| `resizeImages` | bool | no | `false` → disable the responsive-image variant pipeline |

A real minimal `theme.yaml` (from the blueprints):

```yaml
# Theme/theme.yaml
name: "Blog"
colorScheme: "teal"
fontPairing: "modern"
css:
   - "css/theme.css"
js:
   - "js/theme.js"
headInlineScript: "(function(){var t=localStorage.getItem('theme')||(window.matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light');document.documentElement.setAttribute('data-theme',t)})()"
```

The token CSS itself is generated at build time (Phase 5) by `TokenCSSOutputRenderer` (the `--color-*` / `--font-*` / layout custom properties) and `BaseCSSOutputRenderer` (the base reset) – see `architecture.md`.

---

## Available Presets

Presets provide a complete set of all tokens – colors, fonts, and layout. Choose one as your starting point.

| Preset | Description |
|--------|-------------|
| `default` | Clean modern, system fonts, indigo accent |
| `warm` | Warm ivory background, Sora + Nunito Sans, teal accent |
| `minimal` | Editorial feel, serif headings, stone accent |
| `bold` | High contrast, Space Grotesk + Inter, rose accent |

```yaml
# Theme/theme.yaml
preset: warm
```

---

## Available Color Schemes

Color schemes override all color tokens. They work with any preset or on their own.

| Scheme | Accent | Character |
|--------|--------|-----------|
| `teal` | Cyan/teal | Warm ivory, approachable |
| `orange` | Orange | Energetic, playful |
| `violet` | Purple | Creative, modern |
| `indigo` | Deep blue | Professional, trustworthy |
| `rose` | Pink/rose | Bold, expressive |
| `stone` | Neutral gray | Understated, editorial |
| `ocean` | Deep teal | Calm, spacious |
| `forest` | Green | Natural, organic |
| `sunset` | Warm orange/red | Dramatic, warm |
| `lavender` | Light purple | Soft, gentle |
| `amber` | Gold/amber | Warm, premium |
| `emerald` | Rich green | Fresh, confident |
| `slate` | Blue-gray | Neutral, technical |
| `coral` | Coral/salmon | Friendly, inviting |
| `midnight` | Dark blue | Dark-first, dramatic |

```yaml
# Theme/theme.yaml
preset: default
colorScheme: forest
```

---

## Available Font Pairings

Font pairings override the heading, body, and monospace font tokens.

| Pairing | Heading | Body | Character |
|---------|---------|------|-----------|
| `system` | System fonts | System fonts | No external fonts, fast loading |
| `modern` | Sora | Nunito Sans | Clean, contemporary |
| `editorial` | Serif (Lora-style) | Sans-serif | Magazine feel, authoritative |
| `geometric` | Space Grotesk | Inter | Technical, precise |
| `friendly` | Rounded sans | Rounded sans | Approachable, casual |
| `professional` | Classic sans | Classic sans | Corporate, polished |

```yaml
# Theme/theme.yaml
preset: default
fontPairing: modern
```

---

## Choosing a Color Scheme and Font Pairing

Open `ThemePreview.html` (in `Plugin/themes/`) in a browser. It renders a live preview of every combination of preset, color scheme, and font pairing. Use it to visually compare options before committing your choice to `Theme/theme.yaml`.

---

## Creating a Custom Color Scheme

A color scheme is a YAML file defining color tokens with `any` (light mode) and optional `dark` variants.

Define the tokens inline in `Theme/theme.yaml` under `tokens:`.

### Inline custom colors

```yaml
# Theme/theme.yaml
name: "my-theme"
preset: default
tokens:
   colorAccent:
      any: "#0891b2"
      dark: "#22d3ee"
   colorAccentHover:
      any: "#0e7490"
      dark: "#06b6d4"
   colorAccentLight:
      any: "#ecfeff"
      dark: "#083344"
   colorBg:
      any: "#fafaf8"
      dark: "#1a1917"
```

### Full color scheme format

Every built-in color scheme defines all 16 color tokens. Here is the structure:

```yaml
# Each token has `any` (light mode) and optional `dark` variant
colorBg:
   any: "#ffffff"
   dark: "#111827"
colorBgAlt:
   any: "#f9fafb"
   dark: "#1f2937"
colorBgCard:
   any: "#ffffff"
   dark: "#1f2937"
colorText:
   any: "#111827"
   dark: "#f9fafb"
colorTextSecondary:
   any: "#4b5563"
   dark: "#d1d5db"
colorTextMuted:
   any: "#9ca3af"
   dark: "#6b7280"
colorAccent:
   any: "#4f46e5"
   dark: "#818cf8"
colorAccentHover:
   any: "#4338ca"
   dark: "#6366f1"
colorAccentLight:
   any: "#eef2ff"
   dark: "#1e1b4b"
colorBorder:
   any: "#e5e7eb"
   dark: "#374151"
colorBorderLight:
   any: "#f3f4f6"
   dark: "#1f2937"
colorCodeBg:
   any: "#1f2937"
   dark: "#0f172a"
colorCodeText:
   any: "#e5e7eb"
   dark: "#e5e7eb"
colorSuccess:
   any: "#059669"
colorShadow:
   any: "rgba(17, 24, 39, 0.06)"
   dark: "rgba(0, 0, 0, 0.25)"
colorShadowLg:
   any: "rgba(17, 24, 39, 0.12)"
   dark: "rgba(0, 0, 0, 0.4)"
```

You don't need to define every token – missing tokens inherit from the preset or layout defaults.

---

## Overriding Individual Tokens

Override any token in `Theme/theme.yaml` under `tokens:`:

```yaml
# Theme/theme.yaml
name: "my-theme"
preset: warm
colorScheme: teal
tokens:
   # Override just the accent
   colorAccent:
      any: "#e11d48"
      dark: "#fb7185"
   # Override layout values
   maxWidth: "1400px"
   radius: "4px"
```

---

## Layout Themes

Layout themes control the page structure – where the header, navigation, and content live. They are independent of the token system (colors, fonts). A layout is **not** a Swift type – it is a pre-built directory of CSS + JS under `Plugin/themes/templates/<name>/` that you copy into your project's `Theme/`. There are three:

### Classic

Top navigation bar, centered content, card-based post listings. Best for blogs, personal sites, and general-purpose sites. This is the default.

### Sidebar

Persistent sidebar with navigation, content in the main area. Best for documentation sites, multi-section sites, and sites with deep navigation hierarchies.

### Minimal

Stripped-down layout with minimal chrome. Best for landing pages, single-page sites, and sites where content should dominate.

### Using a layout theme

During onboarding, the AI copies the appropriate theme template into your project's `Theme/` directory. To switch later, replace the contents of `Theme/` with the files from the desired template in `Plugin/themes/templates/`.

---

## Customizing a Theme Template

Each theme template provides CSS files in your `Theme/` directory. The key CSS classes to target:

| Class / Element | Purpose |
|---|---|
| `.site-header` | Top navigation bar |
| `.site-nav` | Navigation links container |
| `.site-content` | Main content area |
| `.site-footer` | Footer |
| `.article-card` | Blog post card in listings |
| `.article-content` | Article body content |
| `.page-title` | Page/article title |
| `.tag-list` | Tag pills |
| `.category-nav` | Category navigation |

All styling uses CSS custom properties from the token system, so changing tokens automatically updates the theme.

---

## CSS Custom Properties Reference

The token system generates these CSS custom properties on `:root`:

### Colors

| Property | Token | Description |
|----------|-------|-------------|
| `--color-bg` | `colorBg` | Page background |
| `--color-bg-alt` | `colorBgAlt` | Alternate/section background |
| `--color-bg-card` | `colorBgCard` | Card/panel background |
| `--color-text` | `colorText` | Primary text |
| `--color-text-secondary` | `colorTextSecondary` | Secondary text |
| `--color-text-muted` | `colorTextMuted` | Muted/placeholder text |
| `--color-accent` | `colorAccent` | Primary accent (links, buttons) |
| `--color-accent-hover` | `colorAccentHover` | Accent hover state |
| `--color-accent-light` | `colorAccentLight` | Light accent (highlights, badges) |
| `--color-border` | `colorBorder` | Default border |
| `--color-border-light` | `colorBorderLight` | Subtle border |
| `--color-code-bg` | `colorCodeBg` | Code block background |
| `--color-code-text` | `colorCodeText` | Code block text |
| `--color-success` | `colorSuccess` | Success indicators |
| `--color-shadow` | `colorShadow` | Small shadow |
| `--color-shadow-lg` | `colorShadowLg` | Large shadow |

### Typography

| Property | Token | Description |
|----------|-------|-------------|
| `--font-heading` | `fontHeading` | Heading font family |
| `--font-sans` | `fontBody` | Body text font family (token is `fontBody`; emitted CSS var is `--font-sans`) |
| `--font-mono` | `fontMono` | Monospace/code font family |

### Layout

| Property | Token | Description |
|----------|-------|-------------|
| `--max-width` | `maxWidth` | Maximum page width |
| `--content-width` | `contentWidth` | Content column width |
| `--wide-content-width` | `wideContentWidth` | Wide content width (images, tables) |
| `--header-height` | `headerHeight` | Header bar height |
| `--radius` | `radius` | Default border radius |
| `--radius-lg` | `radiusLg` | Large border radius |
| `--transition` | `transition` | Default transition timing |

Dark-mode token values are emitted under a **`[data-theme="dark"]`** selector (light values live on `:root`). The active mode is set by toggling the `data-theme` attribute on `<html>`, not by a `@media (prefers-color-scheme: dark)` query alone: the theme's `headInlineScript` reads a persisted `localStorage` preference (falling back to `prefers-color-scheme` for the first visit) and applies it before first paint to avoid a flash; the theme's `js/theme.js` provides the toggle button that updates both the attribute and `localStorage`.

---

## Creating a Theme from Scratch

1. Start with a layout theme template (Classic, Sidebar, or Minimal) as your base
2. Choose a preset, color scheme, and font pairing in `Theme/theme.yaml` – or define all tokens manually
3. Add custom CSS files in your `Theme/` directory, listed under `css:` in `Theme/theme.yaml`
4. Use the CSS custom properties (`var(--color-accent)`, `var(--font-heading)`, etc.) in your CSS
5. Override specific tokens as needed under `tokens:`

```yaml
# Theme/theme.yaml
name: "my-custom-theme"
preset: minimal
colorScheme: midnight
fontPairing: editorial
css:
   - "css/main.css"
   - "css/components.css"
js:
   - "js/theme.js"
tokens:
   maxWidth: "960px"
   radius: "0px"
```

**Theme JavaScript.** The files listed under `js:` (plus the tiny `headInlineScript`) provide the theme's runtime behaviour – the dark-mode toggle (writes `localStorage` + flips `data-theme`), search UI, mobile-nav menu, and code-block interactions. The shipped templates under `Plugin/themes/templates/<name>/js/theme.js` are the reference implementation; copy and adapt rather than writing from scratch.

Build and preview with `swift run Site serve` to iterate on the design.

---

## Self-hosting Google Fonts

By default, SiteKit loads Google Fonts from `fonts.googleapis.com` (using a non-blocking preload+onload pattern for speed). Self-hosting keeps font data on your own origin, which avoids third-party requests, protects user privacy (no Google tracking), and – on fast CDN hosting like Cloudflare Pages with HTTP/2 + long `Cache-Control` – performs as well as or better than the Google CDN on repeat visits.

### When to self-host

- Privacy is a priority (GDPR, no third-party analytics/tracking)
- You want zero external dependencies (no SPOF from Google Fonts)
- Your hosting supports HTTP/2 and long-cache `_headers` (Cloudflare Pages, Netlify, Vercel)

### Setup (one-time, per site)

1. **Download the woff2 files** for your theme's fonts into `Theme/fonts/` using the file naming convention `{FamilyNameNoSpaces}-{weight}.woff2`:

   ```bash
   # Example: use the shared download script (uses google-webfonts-helper API)
   /tmp/download-fonts.sh <site-root> \
     "Sora:400,500,600,700,800" \
     "Nunito Sans:400,500,600,700" \
     "JetBrains Mono:400,500"
   ```

   Files produced:
   ```
   Theme/fonts/
     Sora-400.woff2  Sora-500.woff2  …
     NunitoSans-400.woff2  NunitoSans-500.woff2  …
     JetBrainsMono-400.woff2  JetBrainsMono-500.woff2
   ```

   Alternatively, download manually from [google-webfonts-helper](https://gwfh.mranftl.com/fonts) and rename accordingly. Google Fonts are free under SIL Open Font License / Apache 2.0 – commercial self-hosting is allowed.

2. **Enable in `theme.yaml`**:

   ```yaml
   selfHostedFonts: true
   ```

3. **Rebuild** – SiteKit will:
   - Emit `/assets/theme/fonts.css` with `@font-face` rules pointing at the local woff2 files
   - Emit a `<link rel="preload" as="style" onload>` tag loading `fonts.css` asynchronously
   - Skip the Google Fonts `<link>` and preconnect tags entirely
   - Copy `Theme/fonts/` to `/assets/theme/fonts/` automatically

### Trade-offs

- **First visit on slow connections**: slightly slower than Google CDN because Google's servers are globally optimized. On Cloudflare Pages with HTTP/2 this gap is negligible.
- **Repeat visits**: faster with `_headers` giving 1-year `immutable` caching.
- **Font selection locked in**: you commit the woff2 files to your repo. When you change your font pairing, re-run the download script.

---

## Cache headers for Cloudflare Pages / Netlify

SiteKit automatically generates a `_headers` file (via the `CloudflareHeadersRenderer`) at the root of `_Site/`. Fingerprinted assets cache for a year: `Cache-Control: public, max-age=31536000, immutable` is set for content-hashed CSS/JS (`/assets/*.css`, `/assets/*.js`), woff2 fonts, and root favicons. HTML always revalidates (`Cache-Control: public, max-age=0, must-revalidate`) so every deploy is served fresh, and the machine-readable indexes (`/assets/nav-index.json`, `/assets/search-index.json`) revalidate too since they change on every build. Feeds cache 15 minutes; sitemap/robots/llms.txt cache 1 day. The security headers (`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: SAMEORIGIN`) apply to every response.

Year-long immutable caching is safe because the `AssetFingerprinter` output processor content-hashes every referenced CSS/JS file (`theme.css` → `theme.<hash>.css`) and rewrites all references to match. A changed file ships under a new URL the browser is forced to fetch, so the immutable rule is scoped to those hashed filenames only – never to mutable fixed-name files like the index JSONs.

You don't need to configure this – it just works on Cloudflare Pages, Netlify, and any host that understands the `_headers` format. For Vercel, translate the rules into `vercel.json`.

---

## Font Awesome: use freely during dev, auto-inlined at build

You can reference Font Awesome icons anywhere in your markdown or theme – just `<i class="fa-solid fa-user">` or `<i class="fa-brands fa-github">`. During early theme work, all ~1,700 icons are available via the CDN's stylesheet. **When you run `swift run Site build`, SiteKit automatically inlines only the icons you actually use**, and strips the Font Awesome stylesheet from the HTML when nothing dynamic depends on it.

### How it works

A post-build step (`FontAwesomeInliner`) runs after all renderers. It:

1. Scans every `.html` file in `_Site/` for `<i class="fa-solid fa-*">` / `fa-regular` / `fa-brands` references (also legacy `fas`/`far`/`fab` forms).
2. For each unique icon, resolves the SVG:
   - Cache: `<project>/.sitekit-cache/fa-icons/<family>-<name>.svg`
   - On miss, downloads from `https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/svgs/{family}/{name}.svg` (Font Awesome Free, SIL OFL licensed) and writes to cache.
3. Replaces each `<i class="fa-…">` with the corresponding inline `<svg class="fa-icon" aria-hidden="true">`.
4. If every `<i>` on a page was inlined AND the theme JavaScript does not reference `fa-…` patterns (heuristic for runtime icon injection), the Font Awesome `<link rel="stylesheet">` tag is stripped from the HTML entirely.

Typical result: ~10–15 icons totaling ~10–30 KB of cache, ~90 KB of CSS + ~200 KB webfont **no longer shipped**.

### Development workflow

- **Try icons freely**: add `<i class="fa-solid fa-rocket"></i>` to content or theme → works on first build (icon fetched), all subsequent builds are offline-cache hits.
- **Keep the CDN during rapid theme iteration** if you prefer not to wait for the initial fetch – set `inlineFontAwesome: false` in `theme.yaml`.
- **Commit the `.sitekit-cache/`** if you want reproducible CI without needing network access (~10–30 KB, tiny). Default is gitignored – a line like `.sitekit-cache/` is added automatically.

### Dynamic icons (injected via JavaScript)

If your `theme.js` adds FA icons at runtime (e.g., copy-to-clipboard buttons, dynamically-rendered platform badges), SiteKit detects the `fa-…` class references in your JS and **keeps** the Font Awesome `<link>` tag in the HTML. Static icons are still inlined – you just still ship the CSS for the dynamic ones. To fully eliminate the FA stylesheet, refactor JS to emit inline SVGs directly (or use `Plugin/themes/templates/*` which already does this for search / theme-toggle / language-picker / social icons).

### Opt-out

Set `inlineFontAwesome: false` in `theme.yaml` to restore CDN-only behavior:

```yaml
name: "My Theme"
preset: "warm"
externalCSS:
   - "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.7.2/css/all.min.css"
inlineFontAwesome: false
```

Useful if:
- You inject FA icons dynamically in non-obvious ways the heuristic misses.
- You prefer the CDN's globally-cached browser entry.
- You're bisecting a visual regression and want to rule out the inliner.

### Licensing

Font Awesome Free is distributed under [SIL Open Font License 1.1](https://scripts.sil.org/OFL) (icons) + [MIT](https://opensource.org/licenses/MIT) (CSS). Self-hosting and inlining are explicitly permitted. SiteKit pins the version (6.7.2) to match what most theme templates reference.

---

## Responsive images: commit high-res, ship right-sized

You can commit source images at any resolution – hero images at 1600×1069, logos at 1400×1400, avatars at 1024×1024 – whatever's convenient for editing. SiteKit's `ImageResizer` post-processor uses a declarative `ImageManifest.yaml` to generate correctly-sized variants for every `<img>` on the site and rewrites tags to use `srcset` + `sizes`. Originals stay untouched in `Content/Assets/` for future editing; production ships lean.

### The manifest is authoritative

`Content/ImageManifest.yaml` declares the CSS display width of every image role on the site. The pipeline reads it at build time and plans variants per role. Without it, the resizer falls back to a generic heuristic – sufficient for a first build but not tuned to your layout.

```yaml
mobileBreakpoint: 768

roles:
  # Site logo (nav bar). Match the CSS width in your theme.
  - name: site-logo
    selector: "a.sk-site-logo img"
    desktopWidth: 40
    mobileWidth: 40

  # Article hero image – 720 CSS px in the article column; fills mobile viewport.
  - name: article-hero
    selector: "figure.sk-article-hero > img"
    desktopWidth: 720
    mobileWidth: 358

  # Inline images inside article bodies (markdown-rendered).
  - name: article-body-image
    selector: ".sk-article-body img"
    desktopWidth: 720
    mobileWidth: 358

  # Post listing card thumbnails.
  - name: post-card-thumb
    selector: ".sk-post-image"
    desktopWidth: 360
    mobileWidth: 358

  # Catch-all. Add a specific role above for any uncovered image.
  - name: default
    selector: "img"
    desktopWidth: 720
    mobileWidth: 358
```

### How to fill in the manifest

Read your theme CSS (`base.css` + `Theme/*.css`) and for each `<img>` role on the site, find the rule(s) that constrain its width:

1. **Explicit width** (`.app-detail-icon { width: 96px; }`) → use the px value.
2. **Percentage of a container** (`.sk-article-hero img { width: 100% }` inside `.sk-article { max-width: var(--content-width) }`) → use the container's max-width (typically `--content-width` 720px).
3. **Grid auto-sizing** (`.sk-post-list { grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)) }`) → use the min column width (320px) as desktopWidth; at mobile it becomes 1 column → full viewport.
4. **Mobile overrides** (`@media (max-width: 900px) { .home-avatar { width: 80px } }`) → use the mobile-width rule for `mobileWidth`.

Mobile's assumed viewport is the device's CSS viewport (iPhone ≈ 390px, with ~16px padding on each side → ≈ 358px content area).

### Selector grammar

The pipeline supports a minimal subset of CSS selectors for `<img>` matching:

| Form | Example | Meaning |
|------|---------|---------|
| `tag` | `img` | tag name |
| `.class` | `.sk-post-image` | element has the class |
| `tag.class` | `img.hero` | both |
| `A > B` | `figure.sk-article-hero > img` | immediate child |
| `A B` | `.sk-article-body img` | any descendant (ancestor anywhere above) |
| `a, b` | `.avatar, .home-avatar` | any branch matches |

First-match wins – keep specific roles above generic ones, and always end with `default` matching `img`.

### CSS `background-image` backgrounds

`<img>` isn't the only way to ship an image. Themes often use CSS:

```css
.sk-home-hero {
   background: url('/assets/hero-bg.webp') center/cover no-repeat;
}
```

For these, prefix the role's selector with `css:` – matches the **CSS rule's selector**, not an HTML element:

```yaml
roles:
  - name: hero-background
    selector: "css:.sk-home-hero"
    desktopWidth: 900
    mobileWidth: 358
```

The pipeline generates variants and rewrites the CSS to use `image-set()`:

```css
/* Original */
.sk-home-hero { background: url('/assets/hero-bg.webp') center/cover no-repeat; }

/* Rewritten */
.sk-home-hero {
   background: image-set(
      url("/assets/hero-bg-900w.webp") 1x,
      url("/assets/hero-bg.webp") 2x
   ) center/cover no-repeat;
}
@media (max-width: 640px) {
   .sk-home-hero {
      background-image: image-set(
         url("/assets/hero-bg-358w.webp") 1x,
         url("/assets/hero-bg-1074w.webp") 3x
      );
   }
}
```

`image-set()` is supported by Safari 17+, Chrome 88+, Firefox 88+ – every browser in current use.

Only top-level rules with a single local `url(...)` are rewritten. Rules nested inside `@media`, `@supports`, `@keyframes`, or `url()`s that already sit inside `image-set()` are skipped – author keeps full control over complex cases.

### Always host images locally

Every image referenced by a page (or theme CSS) should live in the repo – `Content/Assets/` for content images, `Theme/images/` for theme-owned images. Hotlinking from third-party CDNs (GitHub avatars, Gravatar, social OG images) triggers three problems Lighthouse flags:

1. **No Cache-Control you control** – third-party CDNs typically send short TTLs (GitHub avatars: 5 min) you can't change. Local assets ship under SiteKit's own `_headers` (fingerprinted CSS/JS cache a year immutable; other local assets revalidate under your control); a hotlinked image gets none of that.
2. **No responsive sizing** – ImageResizer can only touch local files. A 460×460 remote avatar displayed at 130×130 wastes bandwidth per visitor.
3. **DNS + TCP + TLS overhead** – every extra origin costs 100–300 ms on mobile.

When content links to someone else's image, download it once with `curl -o Content/Assets/images/<name>.webp <url>` and reference `/assets/images/<name>.webp`. The pipeline takes it from there.

### Density vs. responsive variants

For each role, the pipeline chooses one of two strategies based on how different the mobile width is from desktop:

- **Density** (mobile ≥ desktop / 2): two variants at 1× and 2× the desktop width. Simpler, good for icons, avatars, and cards whose mobile column is not much narrower than desktop.
- **Responsive** (mobile < desktop / 2): three variants with a `sizes` attribute – mobile retina (`mobileWidth × 3`), desktop retina (`desktopWidth × 2`), plus the desktop 1× fallback. Browser picks by viewport × DPR. Kicks in for full-bleed heroes and backgrounds where mobile is meaningfully narrower.

Both strategies always emit `width` and `height` to fix CLS.

### Typical savings

A 140 KB app icon at 1024×1024 displayed at 96×96 CSS px becomes ~4 KB at 1× and ~10 KB at 2×. A 900 KB hero at 2000×1125 displayed at 720 CSS px on desktop, 390 CSS px on mobile becomes ~60 KB (mobile retina, 1170w) or ~180 KB (desktop retina, 1440w). Lighthouse "Properly size images" drops off the opportunities list.

### When to re-visit the manifest

- **CSS changed** (new breakpoint, tweaked container max-width, new image class) → re-read affected rules, update the role.
- **New image class appears** (a theme template adds a new `<img class="...">`) → add a role for it.
- **Lint log warns** `N <img> fell through to the default role` → identify which images are uncovered and add specific roles for them.

Adding a new article via markdown typically needs **no** manifest edit – the `article-body-image` role's descendant selector covers it automatically.

### Tooling

ImageMagick must be on `PATH`:
- **macOS**: `brew install imagemagick`
- **Ubuntu / CI**: `sudo apt-get install -y imagemagick webp`

If neither `magick` (v7+) nor `convert` (v6) is found, a warning is logged and no variants are generated – the site still builds. Add the install step to your deploy workflow:

```yaml
# .github/workflows/deploy.yml (GitHub Actions)
- name: Install ImageMagick
  run: sudo apt-get update -qq && sudo apt-get install -y imagemagick webp
```

```yaml
# .forgejo/workflows/deploy.yml (Forgejo Actions)
- name: Install ImageMagick
  run: apt-get update -qq && apt-get install -y imagemagick webp
```

### Cache lifecycle

The `.sitekit-cache/images/` directory fills up with variants as you build. Each variant is 1–30 KB. A site with ~15 unique images ends up with ~30 cache entries totaling ~100–300 KB. Commit the cache for reproducible CI without network roundtrips, or gitignore it – both work.

### Opt-out

Set `resizeImages: false` in `theme.yaml` to disable. Useful if you pre-resize images by hand or have an external pipeline.
