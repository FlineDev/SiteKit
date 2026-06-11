# Performance – Troubleshoot PageSpeed Findings

SiteKit handles Core Web Vitals automatically – self-hosted fonts, responsive images via `ImageManifest.yaml`, non-blocking stylesheets for Font Awesome / Highlight.js, preloaded LCP images, deferred JS, inlined critical CSS, Cloudflare cache headers. You generally do not need to think about performance when building a site.

**Use this guide only when the user reports a specific PageSpeed finding.** It maps each common finding to the file(s) that are likely responsible, so you can diagnose in one read rather than trial-and-error.

---

## What `PageShell` does automatically – `<head>` resource order

`PageShell` orders `<head>` for fast First Contentful / Largest Contentful Paint. Knowing the order makes render-blocking findings easy to reason about:

1. `charset` / `viewport` / `<title>`, then (multilingual default-locale only) a tiny inline language-redirect script.
2. **LCP image preload** – `<link rel="preload" as="image" fetchpriority="high">` when the renderer passes `preloadImageURL`.
3. **Critical theme CSS preload** – `<link rel="preload" as="style">` for each render-critical `theme.css` (non-critical bundles like Font Awesome / Highlight.js are skipped here).
4. **Fonts, async** – self-hosted `fonts.css` or Google Fonts via the `preload as=style` + `onload` swap pattern (with `font-display: swap`); preconnects for any external hosts.
5. **Critical CSS inlined** – `tokens.css` + `base.css` are minified and inlined as `<style>` (no extra round-trips), then the theme's own CSS `<link>`s.
6. **Theme JS** – `<script ... defer>` **in `<head>`** (not at end of `<body>`); favicons; the `headInlineScript` (no-flash dark-mode bootstrap).
7. Meta: description, canonical, Open Graph, Twitter, hreflang, RSS discovery, JSON-LD, the content-index `<link rel="search">`, and the AI-navigation comment.

So critical CSS never blocks on a network round-trip, the LCP image is discovered before `<body>` parses, and non-critical CSS + all JS stay off the critical path.

---

## How to map a finding to a cause

PageSpeed findings come from one of four places. In order of likelihood:

1. **Site's `Theme/` CSS or JS** – custom code, specific to this site. Most "forced reflow", "unused CSS", and layout-shift issues start here.
2. **Site's `Content/ImageManifest.yaml`** – missing role, or declared width doesn't match the actual CSS display width.
3. **Site's `SiteConfig.yaml` / `Theme/theme.yaml`** – e.g., an unused `externalCSS` entry, a missing `navigation.logo.imageWidth`, `selfHostedFonts: false` that could be `true`.
4. **SiteKit Package** – rare; only if you've verified it's not one of the above. File an issue rather than patching blindly.

---

## Finding → likely cause

### Critical request chain / Render-blocking resources
> "Vermeide die Verkettung kritischer Anfragen" / "Eliminate render-blocking resources"

- **Points at a SiteKit-emitted stylesheet** (e.g. `tokens.css`, `base.css`) → these are inlined already; finding is stale, re-audit.
- **Points at a file in `Theme/css/`** → SiteKit already emits a `<link rel="preload" as="style">` for each render-critical theme stylesheet. If still flagged, the theme CSS is likely large – consider splitting above-the-fold rules into a smaller critical stylesheet.
- **Points at an external CDN CSS/JS (`cdnjs.cloudflare.com`, `fonts.googleapis.com`)** → check that the matching preconnect is emitted. FA/Highlight are media-swap loaded automatically.

### LCP image not preloaded / not in initial HTML
> "Optimiere den LCP, indem du das LCP-Bild im HTML-Code direkt sichtbar machst" / "Largest Contentful Paint image was lazily loaded"

The page's renderer must call `buildHead(..., preloadImageURL: <url>)` AND mark the rendered `<img>` with `fetchpriority="high"`. Already wired up for:

- Article pages (`renderArticle` uses `page.image`)
- Blog/portfolio listing first card (via ArticleCard renderer)
- Podcast home (first host avatar)

If the finding is on a **custom page type** added to a site, the site's custom renderer must do the same two steps.

### Unused preconnect
> "Nicht verwendete Vorverbindung" / "Avoid unused preconnects"

- **`cdnjs.cloudflare.com`** → SiteKit's `FontAwesomeInliner` already strips this preconnect when it fully inlines FA. If the finding persists, inlining was disabled or skipped for dynamic-JS reasons – check build log for `[SiteKit] Font Awesome icons used dynamically in theme JS – keeping FA stylesheet`.
- **Other host** → look at the site's `Theme/theme.yaml`: `externalCSS` / `externalJS` entries trigger preconnects. Remove entries that are no longer used.

### Properly size images
> "Bilder in passender Größe bereitstellen" / "Properly size images"

Always an image pipeline issue. Three distinct causes:

- **The flagged image lives on a third-party CDN** (`avatars.githubusercontent.com`, Gravatar, someone else's S3). The pipeline can't touch files we don't own. **Fix**: download the image into `Content/Assets/images/` and reference the local path.
- **The flagged image is a CSS `background-image`** → add a `"css:<selector>"` role to `ImageManifest.yaml`. The `CSSBackgroundImageProcessor` picks it up, generates variants, and rewrites the CSS to use `image-set()` + `@media` mobile override.
- **The flagged image is an `<img>`** → either no role matches (add one) or declared widths are too generous (tighten to the actual CSS display width).

See `themes.md` → "Responsive images: commit high-res, ship right-sized".

### Forced reflow / Layout thrashing
> "Erzwungener dynamischer Umbruch" / "Avoid forced synchronous layouts"

Always in the **site's `Theme/theme.js`** (or a custom inline script). Look for loops that read layout (`getBoundingClientRect`, `offsetWidth`, `clientHeight`, `scrollTop`) and write style/class in the same iteration. Fix: batch all reads into an array first, then loop again to apply writes.

### Cumulative Layout Shift (CLS)
> "Verschiebungen des Layouts vermeiden" / "Avoid large layout shifts"

- **On images** → SiteKit's `ImageResizer` always emits `width` + `height`. If the image is still shifting, check that its role in the manifest matches and that the variant exists on disk.
- **On fonts** → `font-display: swap` is already on. Shift is unavoidable unless you accept FOUT vs FOIT tradeoff; current setup favors FOUT (better LCP).
- **On ads / dynamic widgets** → site-specific. The theme must reserve space with explicit height or `aspect-ratio`.

### First Contentful Paint > 1.0s / Speed Index high
> "Erhöhe First Contentful Paint"

SiteKit ships ~3 KB of critical inlined CSS + a preloaded critical stylesheet. If FCP is still high:

- **Network**: CI may not have imagemagick → giant source images ship. Check build log for `No image resize tool found on PATH`.
- **Huge theme.css**: the theme's own stylesheet is bloated. Audit with `css-size-analyzer` or similar.
- **Server TTFB**: not a SiteKit issue – check Cloudflare Pages dashboard.

### Reduce unused JavaScript / CSS

- **JavaScript** → SiteKit's own JS footprint is zero. Any flagged JS is from the theme or an external include.
- **CSS** → Font Awesome loads many unused icons when not inlineable. The `FontAwesomeInliner` inlines static references and strips the full stylesheet when possible – check the build log summary for which icons inlined. If FA is flagged, the theme JS is probably adding icons dynamically, which prevents stripping.

### Serve static assets with an efficient cache policy / stale CSS or JS after a deploy
> "Statische Assets mit einer effizienten Cache-Richtlinie bereitstellen" / "Use efficient cache lifetimes"

SiteKit ships `Cache-Control: public, max-age=31536000, immutable` for `/assets/*.css` and `/assets/*.js` (via the Cloudflare `_headers` file). Safe year-long caching only works because the **`AssetFingerprinter`** output processor runs **last in the Phase 6 chain** (after `AssetMinifier`) and content-hashes every *referenced* CSS/JS filename – `theme.css` → `theme.<hash>.css` – rewriting every reference in the same pass. When an asset's bytes change, its filename changes, so the URL is genuinely new and every cache refetches it; when the bytes do not change, the filename is identical across deploys, so unchanged assets stay cached. This is why a returning visitor never gets stale theme CSS after a redeploy, and why a hashed-filename approach is used instead of a `?v=` query (an `immutable` response ignores the query string).

- **A finding still flags long cache lifetimes** → the asset is likely *not* fingerprinted: only local `/assets/*.css` and `/assets/*.js` referenced from a rendered `.html`/`.css` file are hashed. Images (which get responsive variants), fonts, JSON indexes, and favicons (fixed root paths) keep stable paths by design.
- **Stale CSS after a deploy, despite a code change** → confirm the changed stylesheet is actually *referenced* (emitted-but-unreferenced files like `tokens.css`/`base.css` are inlined by `PageShell`, not linked, so they are intentionally left unhashed – there is nothing to bust if nothing fetches them).

---

## What NOT to do

- **Don't touch SiteKit's renderers to fix a single site's problem.** If a site needs a custom tweak, it belongs in the site's `Theme/` or its own custom renderer.
- **Don't downgrade features to "fix" a finding.** PageSpeed sometimes warns about edge cases that don't affect real-world performance. Measure real mobile scores on `pagespeed.web.dev` before committing changes.
- **Don't add preconnects speculatively.** Only for hosts whose resources are on the critical path. Unused preconnects waste connections.

---

## When in doubt

Run the site locally with `swift run Site build` and inspect the actual rendered HTML for the page the finding flags. 90% of the time the answer is visible in the first 30 lines of `<head>`.

## See also

- `themes.md` – "Responsive images: commit high-res, ship right-sized" (the canonical image-pipeline / `ImageManifest.yaml` reference) and the self-hosted-fonts setup.
- `accessibility.md` – the sibling quality-invariant guide.
- `deployment/hosts/cloudflare-pages.md` – CDN + `_headers` cache configuration.
