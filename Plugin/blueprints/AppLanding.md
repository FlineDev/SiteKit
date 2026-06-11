# Blueprint: App Landing Page

**A single-product landing page with hero, features, screenshots, pricing, reviews, and call-to-action.**

## Quick Start

```bash
swift run sitekit new my-app --blueprint AppLanding
cd my-app
swift run Site serve     # preview at http://localhost:8080
```

Edit `Content/Data/Landing.yaml` for all the page content. Ships with the **violet** color scheme + **professional** font pairing – change them in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `AppLanding` when your site is a dedicated landing page for a single app or product. Good for:

- iOS/macOS app marketing pages
- SaaS product landing pages
- Developer tool showcases
- Single-product companies

For a multi-app portfolio, see `Portfolio`. For a site with blog + app showcase, see `IndieDev`.

## Questions to Ask

1. **App name and base URL?** (e.g. "TranslateKit", "https://translatekit.app")
2. **App Store URL?** (for download badges and CTA buttons)
3. **App Store bundle ID?** (for fetching metadata via iTunes Lookup API)
4. **Which sections do you need?** hero (required), features, featureShowcase, testimonials, pricing, appStoreReviews, trustedBy, faq, cta, techSpecs
5. **Color scheme preference?** (violet, teal, indigo, etc.)
6. **Font pairing preference?** (professional, modern, geometric, etc.)
7. **Languages?** (for multilingual landing pages)

## What It Generates

- Landing page with configurable sections (all data-driven from Landing.yaml)
- Static pages (Privacy, Imprint/Terms)
- Sitemap, robots.txt, llms.txt
- Open Graph / SEO metadata
- Favicon: the blueprint ships an SVG icon (`Theme/images/favicon.svg`, declared in `theme.yaml`); for the full PNG set (apple-touch-icon, favicon.ico) add pre-generated files under `Content/Assets/Favicons/` (the build logs the ImageMagick recipe when absent)

(Multilingual sites add cross-locale redirects – see the Multilingual variation.)

**Default theme**: ships `colorScheme: violet` + `fontPairing: professional` (in `Theme/theme.yaml`) – top nav with logo, footer with social links.

## App Store Metadata

You can fetch app metadata automatically using the iTunes Lookup API:

```
https://itunes.apple.com/lookup?bundleId=BUNDLE_ID
```

No authentication required. Key fields in the response:
- `trackName` – app name
- `artworkUrl512` – app icon (change `512` to `1024` for high-res)
- `averageUserRating` – star rating
- `userRatingCount` – number of ratings
- `formattedPrice` – price display
- `screenshotUrls` – iPhone screenshots

For App Store download badges, use Apple Marketing Tools: https://tools.applemediaservices.com/app-store/

For structured data, add `schema.org/MobileApplication` JSON-LD in your `LandingPageRenderer` (via `PageShell.wrap(..., head:)`) – SiteKit does not auto-emit it for landing pages.

## SiteConfig.yaml Structure

```yaml
name: "MyApp"
baseURL: "https://myapp.com"
description: "Short description for SEO and social sharing"
contentDirectory: "Content"
outputDirectory: "_Site"

sections: []

navigation:
  logo:
    image: "/assets/theme/images/app-logo.webp"
    text: "MyApp"
  items:
    - title: "Features"
      url: "/#features"
    - title: "Pricing"
      url: "/#pricing"
    - title: "FAQ"
      url: "/#faq"
  showSearch: false
  showThemeToggle: true

footer:
  copyrightName: "Your Name"
  startYear: 2026
  social:
    - platform: "github"
      url: "https://github.com/yourname"
    - platform: "mastodon"
      url: "https://mastodon.social/@yourname"
      rel: "me"
  links:
    - title: "Privacy"
      url: "/privacy/"
    - title: "Imprint"
      url: "/impressum/"
```

## Entry Point

```swift
// Sources/Site/Main.swift
import SiteKit

@main struct Site {
   static func main() throws {
      try SiteBuilder.portfolio(configPath: "SiteConfig.yaml")
         .replacing(HomePageRenderer.self, with: LandingPageRenderer())
         .run()
   }
}
```

There is **no `SiteBuilder.appLanding()` factory** – AppLanding is `SiteBuilder.portfolio()` with a custom `LandingPageRenderer` (in your site's `Sources/`) replacing the default home page. The renderer loads `Content/Data/Landing.yaml` and produces the landing-page HTML. (For structured data, the `LandingPageRenderer` can inject `schema.org/MobileApplication` JSON-LD via `PageShell.wrap(..., head:)` – SiteKit provides the hook but does not auto-emit that schema.)

## Content Structure

```
Content/
├── Data/
│   └── Landing.yaml          # All landing page section data
├── Pages/
│   ├── Privacy.md
│   └── Impressum.md
└── Assets/
    └── Images/
        ├── AppIcon.webp
        ├── AppStoreBadge.svg
        └── Features/          # Feature screenshots
```

## Landing.yaml Schema

All sections are optional except `hero` and `appStoreURL`:

```yaml
appStoreURL: "https://apps.apple.com/app/id1234567890"

hero:
  title: "Your App Name"
  subtitle: "One compelling line about what your app does"

features:
  - title: "Feature One"
    description: "What this feature does for the user"
    imagePath: "/assets/images/Features/Feature1.webp"

featureBanner:
  title: "The Headline Feature"
  subtitle: "Longer description of your killer feature"
  ctaText: "Try It Free"
  videoPath: "/assets/videos/demo.mp4"

testimonials:
  - name: "Jane Developer"
    handle: "@jane"
    avatarPath: "/assets/images/Testimonials/jane.webp"
    quote: "This app changed my workflow completely."
    row: 1

pricing:
  title: "Simple Pricing"
  subtitle: "Start free, upgrade when you're ready"
  ctaText: "Download Now"
  tiers:
    - name: "Free"
      monthlyPrice: "$0"
      features: ["Feature A", "Feature B"]
    - name: "Pro"
      badge: "Popular"
      monthlyPrice: "$9.99"
      features: ["Everything in Free", "Feature C", "Feature D"]
      highlighted: true

appStoreReviews:
  - quote: "Best app in its category!"
    author: "Happy User"
    location: "United States"

trustedBy:
  - name: "Big App"
    url: "https://bigapp.com"
    iconPath: "/assets/images/TrustedBy/bigapp.webp"

faq:
  - question: "How does it work?"
    answer: "Simple explanation of your app."

cta:
  title: "Ready to Get Started?"
  buttonText: "Download Free"
```

## Variations

- **Without pricing**: Remove the `pricing` section from Landing.yaml.
- **Without testimonials**: Remove `testimonials` – feature grid fills the space.
- **Multilingual**: Add `Landing.de.yaml`, `Landing.ja.yaml` etc. with translated content. Add a `localization` block to SiteConfig.yaml. For cross-locale redirects, also add the redirect renderers to `Main.swift` (they're not in `.portfolio()`'s default set):
  ```swift
  .renderer(LanguageRedirectRenderer())
  .renderer(HTMLRedirectPageRenderer())
  .renderer(CloudflareRedirectsRenderer())
  ```
  Document per-language voice and rules in `Guidelines/Translations.md` (the default location read by the `localization` skill – override via `localization.styleGuidePath` if you keep the file elsewhere). Note: German marketing copy should typically use informal "du" (not formal "Sie") for indie/startup sites.
- **Multiple CTAs**: The `appStoreURL` is used throughout. For Google Play, add a `googlePlayURL` field to your custom data model.
- **Custom sections**: The `LandingPageRenderer` and `LandingData` model live in your site's Sources/ – add or remove sections freely.
