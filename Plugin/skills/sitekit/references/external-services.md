# External Services

SiteKit builds **static** sites and is **privacy-first**: it ships **no third-party JavaScript by default** – no analytics, no comment widgets, no tracking. There is exactly one bundled external integration (newsletter delivery, below); everything else is added explicitly by you via theme hooks.

Concretely, SiteKit's external surface is small and honest:

- **Newsletter delivery** – a recommended self-hosted stack (below). The one first-class integration.
- **Web fonts & Font Awesome** – optional external CDNs you can also self-host / inline.
- **Podcast directories** – the generated iTunes RSS feed + subscribe links.
- **Anything else** (analytics, comments, chat, consent banners, forms) – added through the generic `theme.yaml` hooks. There are no dedicated `analytics`/`comments`/`search` config fields.

## Newsletter / Email

SiteKit's recommended newsletter stack is **self-hosted Keila** (Elixir/BEAM) paired with an SMTP email sending service. Keila handles subscribers, forms, and campaigns; the sending service handles delivery.

**Recommended sending services** (sorted by cost for ~3,600 emails/month):

| Service | Cost | EU | Notes |
|---------|------|-----|-------|
| **Scaleway TEM** | ~€0.83/mo | France | Cheapest, EU-native, pay-as-you-go |
| **Amazon SES** | ~$0.36/mo | EU regions | Cheapest at volume, but sandbox approval often denied for new accounts |
| **Brevo** | ~$8/mo | France | Established, good deliverability |
| **Postmark** | $15/mo | No | Best-in-class deliverability |
| **Resend** | $20/mo | No | Modern API, excellent DX |

Any SMTP-compatible service works – just update the SMTP credentials in Keila's configuration.

For the full setup guide (VPS provisioning, Keila configuration, SES domain verification, double opt-in), see **[Newsletter Setup](newsletter-setup.md)**.

### EmailRenderer

SiteKit's `EmailRenderer` generates email-safe HTML from the same Markdown content used for your website. This means you can author once and publish to both web and email without maintaining separate templates. The renderer produces inline-styled HTML compatible with major email clients.

## Adding any other third-party service (analytics, comments, chat, consent banners…)

SiteKit has **no dedicated config field** for analytics, comments, search providers, or embeds – and that's by design. You add any third-party service through the generic hooks in **`Theme/theme.yaml`** (see themes.md for the full schema):

| Hook | Type | Use for |
|---|---|---|
| `headInlineScript` | String | A small inline `<script>` injected into `<head>` (the privacy-analytics / consent-bootstrap pattern) |
| `externalJS` | list of URLs | Third-party `<script defer>` bundles (analytics, chat/comment widgets, etc.) – a `preconnect` is emitted per host |
| `externalCSS` | list of URLs | Third-party stylesheets |

Example – a privacy-analytics snippet (vendor-neutral; substitute your provider's real URL):

```yaml
# Theme/theme.yaml
externalJS:
   - "https://analytics.example.com/script.js"
# or, for an inline initialiser:
headInlineScript: "window.myAnalytics=window.myAnalytics||function(){};"
```

The same pattern covers comment widgets (e.g. a `<script>`-based embed), live-chat, cookie-consent banners, and form backends – drop the provider's script/stylesheet into these fields. SiteKit does not validate or sandbox them; you own their privacy/CSP implications.

## Web fonts & Font Awesome

Two external dependencies SiteKit can load for you, both of which you can keep off third-party origins:

- **Web fonts** – Google Fonts by default; set `selfHostedFonts: true` (+ run the font-download script) to serve woff2 from your own origin instead.
- **Font Awesome** – opt-in CDN (`includesFontAwesome: true`) or, by default, the icons you actually use are inlined as SVG at build time and the stylesheet is stripped.

Full details and the privacy/performance trade-offs are in **themes.md**.

## Podcast directories

Podcast sites generate an iTunes-compatible RSS feed and surface subscribe buttons via `SiteConfig.yaml`'s `podcast.subscribeLinks` (platform / url / label) – the integration point for Apple Podcasts, Overcast, and other directories that ingest the feed. See **siteconfig-reference.md** → `podcast`.

## Search is built-in (not an external service)

Site search is **client-side and self-contained** – the build emits `nav-index.json` / `search-index.json` under `/assets/` and the theme's search button reads them. There is **no** integration with (or need for) an external search service like Algolia or Pagefind.

## Not built-in – use the hooks

Contact forms, comment systems, analytics dashboards, and external search are **not first-class SiteKit features** and are not on a committed roadmap. That is not a gap: add any of them with a provider script/stylesheet via the `theme.yaml` hooks above. When asked to "add Plausible / Giscus / a contact form," reach for `headInlineScript` / `externalJS` – not a (non-existent) SiteConfig field.

## See also

- `newsletter-setup.md` – the full self-hosted newsletter walkthrough.
- `themes.md` – the `theme.yaml` hook schema, fonts, and Font Awesome.
- `siteconfig-reference.md` – `podcast.subscribeLinks` and the rest of the config schema.
