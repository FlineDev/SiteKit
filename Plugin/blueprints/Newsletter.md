# Blueprint: Newsletter

**A newsletter website with issue archive, email signup forms, email-renderable HTML, and RSS feed.**

## Quick Start

```bash
swift run sitekit new my-newsletter --blueprint Newsletter
cd my-newsletter
swift run Site serve     # preview at http://localhost:8080
```

Then wire up a delivery service (see "Newsletter Service" below) and deploy (`references/deployment/hosts/cloudflare-pages.md`). Unlike the other blueprints, Newsletter ships with the **indigo** color scheme and the **geometric** font pairing – the indigo matches `EmailRenderer`'s accent so web and email look continuous. Change them in `Theme/theme.yaml` (see `references/themes.md`).

## When to Choose This

Choose `Newsletter` when your primary content is periodic newsletter issues delivered via email, with a web archive. Good for:

- Topic-focused newsletters (technology, design, business, etc.)
- Curated link digests and roundups
- Weekly or monthly industry analysis
- Community newsletters with a growing subscriber base

For a general blog without email delivery, see `Blog`. For a podcast, see `Podcast`.

## Questions to Ask

1. **Newsletter name and base URL?** (e.g. "Swift Weekly", "https://swiftweekly.dev")
2. **What topic does the newsletter cover?** (Used for homepage subtitle, About page, and signup form copy)
3. **Author name and optional profile image?**
4. **Publish frequency?** (weekly, biweekly, monthly)
5. **Newsletter delivery service?** See "Newsletter Service" below for options.
6. **Signup form URL?** (The form action URL from your delivery service – can be configured later)
7. **Color scheme and font pairing?** (See theme options in the onboarding flow)
8. **Existing subscribers to import?** (If migrating from Substack, Buttondown, etc.)

## What It Generates

- Issue archive page (`/blog/`) listing all published issues
- Individual issue pages (`/blog/<slug>/`) with full article layout
- Email-renderable HTML at `_Site/email/<slug>.html` via EmailRenderer – self-contained HTML with inline styles, dark mode support, and preview toggle for every issue
- Homepage with hero section and embedded newsletter signup form
- Signup form injected after each issue (via theme JS, excluded from legal pages)
- Tag listing pages (`/tags/<tag>/`)
- RSS feed for the issue archive
- Static pages (About, Privacy, Imprint)
- Sitemap, robots.txt, llms.txt, search index
- Open Graph / SEO metadata on every page
- Draft preview support
- Dark mode with theme toggle

## SiteConfig.yaml Structure

```yaml
name: "My Newsletter"
baseURL: "https://example.com"
description: "A newsletter about your topic – subscribe to get the latest issues."
language: "en"
categories: []                             # Newsletters typically don't use categories

author:
   name: "Your Name"
   imageURL: "/assets/images/profile.webp"
   url: "/about/"

sections:
   - name: "Issues"
     slug: "issues"
     contentDirectory: "Blog"
     urlPrefix: "blog"
     description: "Newsletter issues"

navigation:
   logo:
      image: "/assets/images/logo.webp"
      text: "My Newsletter"
   items:
      - title: "Archive"
        url: "/blog/"
        icon: "fa-solid fa-box-archive"
      - title: "About"
        url: "/about/"
        icon: "fa-solid fa-circle-info"

homePage:
   title: "My Newsletter"
   subtitle: "Your tagline here"
   recentPostsCount: 6

footer:
   copyrightName: "Your Name"
   startYear: 2026
   social:
      - platform: "bluesky"
        url: "https://bsky.app/profile/your-handle"
      - platform: "mastodon"
        url: "https://mastodon.social/@your-handle"
        rel: "me"
   links:
      - title: "Privacy Policy"
        url: "/privacy/"
      - title: "Imprint"
        url: "/imprint/"

tagDisplayNames:
   swift: "Swift"
   news: "News"
   updates: "Updates"
```

## Entry Point

```swift
// Sources/Site/Main.swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.newsletter(configPath: "SiteConfig.yaml").run()
   }
}
```

`SiteBuilder.newsletter()` includes all standard blog renderers plus `EmailRenderer`, which generates email-safe HTML for every non-draft issue.

## Content Structure

Example end state – the scaffold ships the sample issue and the `Pages/` set (home, About, Privacy, Imprint); `Assets/` images are added as the site grows:

```
Content/
├── Blog/
│   ├── 2026-01-01-welcome-to-my-newsletter.md
│   ├── 2026-02-01-february-issue.md
│   └── ...
├── Pages/
│   ├── home.md          ← Homepage with signup form (lowercase!)
│   ├── About.md
│   ├── Privacy.md
│   └── Imprint.md
└── Assets/
    └── images/
        ├── logo.webp
        └── profile.webp
```

**Note:** `home.md` must be lowercase – SiteKit loads it specially for homepage content injection.

## Issue Frontmatter Schema

```yaml
---
id: a1b2c3d4                    # 8-char hex, unique per issue
title: "Issue #1 – Welcome"
date: 2026-01-01
tags: [welcome, introduction]
summary: "What this issue covers in one sentence."
draft: true                      # Optional: set to true for preview-only
---

Issue content goes here as regular Markdown.
```

## Newsletter Service

SiteKit generates the static website and email HTML. A separate service handles subscriber management and email delivery.

**Self-hosted (recommended for cost and control):**

| Component | Choice | Cost |
|-----------|--------|------|
| Newsletter software | **Keila** (Elixir/BEAM, open-source) | Free |
| VPS hosting | **Hetzner CX23** or similar | ~€3-4/mo |
| Email delivery | **Scaleway TEM** (EU, pay-as-you-go) | ~€0.25/1K emails |
| **Total** | | **~€5-6/mo** |

See `references/newsletter-setup.md` for the complete setup guide (VPS provisioning, Keila Docker Compose, email service configuration, double opt-in).

**Alternative sending services** (all work with Keila via SMTP):

| Service | 3,600/mo | 20,000/mo | EU | Notes |
|---------|----------|-----------|-----|-------|
| **Scaleway TEM** | ~€0.83 | ~€4.93 | France | Recommended. Cheapest, EU-native. |
| **Amazon SES** | ~$0.36 | ~$2.00 | EU regions | Cheapest at volume, but sandbox approval often denied. |
| **Brevo** | ~$8 | ~$25 | France | Established, good deliverability. |
| **Postmark** | $15 | ~$33 | No | Best-in-class deliverability. |
| **Resend** | $20 | $20 | No | Modern API, flat pricing. |

**Managed alternatives (no VPS needed, simpler setup, higher cost):**

| Service | Free tier | Paid |
|---------|-----------|------|
| Buttondown | 100 subscribers | $9/mo (1K subs) |
| ConvertKit (Kit) | 10K subscribers (no API) | $25+/mo |
| Substack | Unlimited | Revenue share on paid |

For managed services, replace the form action URL and field names in `home.md` and `theme.js` according to the service's documentation.

## Signup Form Integration

### Why a Direct HTML Form (Not an Iframe)

The signup form is a **plain HTML `<form>`** embedded directly on your website that POSTs to your newsletter service's form endpoint. This is better than using an iframe or redirecting to Keila's hosted form page because:

- The form matches your site's design perfectly (styled by your theme CSS)
- No third-party branding or Keila UI visible to subscribers
- No iframe sizing/scrolling issues
- Faster – no additional page load

This works because Keila (and most newsletter services) accept standard HTML form submissions. The key is using the correct form action URL and field names.

### How It Works (Full Flow)

```
1. User fills in email on YOUR website
   └─ <form action="https://keila.your-domain.com/forms/FORM_ID" method="post">

2. Form POSTs directly to Keila
   └─ Keila stores pending subscription
   └─ Keila sends confirmation email via SMTP (Scaleway TEM / your sending service)
   └─ Keila shows "Almost there! Check your inbox" page (only Keila page the user sees)

3. User clicks confirmation link in email
   └─ Keila confirms the subscription
   └─ Keila sends the welcome email
   └─ Keila redirects to YOUR website: https://your-domain.com/?subscribed=true

4. Your website detects ?subscribed=true
   └─ JS swaps signup form for "Welcome aboard!" message
   └─ URL cleaned up (query param removed from history)
```

Only **one** Keila-hosted page is visible to the user (the "Almost there" message after step 2). Everything else happens on your website or in email.

### Form Placement

The signup form appears in two places:

**1. Homepage (`Content/Pages/home.md`)**

A direct HTML form with two panels – signup and welcome:

```html
<div class="newsletter-signup" id="newsletter-signup">
   <h2>Subscribe to My Newsletter</h2>
   <p>Get the latest issues delivered straight to your inbox.</p>
   <form action="YOUR_FORM_ACTION_URL" method="post">
      <input type="email" name="contact[email]" placeholder="your@email.com" required />
      <button type="submit">Subscribe</button>
   </form>
</div>
<div class="newsletter-signup newsletter-welcome" id="newsletter-welcome" style="display: none;">
   <h2>Welcome aboard!</h2>
   <p>Your subscription is confirmed.</p>
   <p><a href="/blog/">Browse the archive →</a></p>
</div>
```

The `contact[email]` field name is the Keila convention. For other services, adjust the field name (e.g. `email` for Buttondown, `email_address` for ConvertKit).

**2. After Each Issue (`Theme/js/theme.js`)**

The theme JS injects a signup form after every issue article, except on legal pages (privacy, imprint). The form URL is configured via the `NEWSLETTER_FORM_URL` variable at the top of `theme.js`:

```javascript
var NEWSLETTER_FORM_URL = 'YOUR_FORM_ACTION_URL';
```

Replace `YOUR_FORM_ACTION_URL` with your actual form endpoint in both `home.md` and `theme.js`.

**3. Welcome Message (`?subscribed=true`)**

After confirmation, Keila redirects to `/?subscribed=true`. The theme JS detects this parameter and swaps the signup panel for the welcome panel, then cleans the URL via `history.replaceState`.

### Keila Form Configuration Checklist

After creating a form in Keila's web UI:

1. **Disable captcha** – double opt-in already prevents spam signups
2. **Enable double opt-in** – required for GDPR compliance (EU/Germany)
3. **Set a custom confirmation email** – branded subject and body with `{{ double_opt_in_link }}`
4. **Create and assign a sender** – SMTP tab with your sending service credentials
5. **Assign the sender to the form** – in the Double Opt-in tab, select your sender
6. **Enable welcome email** – with a branded welcome message
7. **Set "Thank you Redirect URL"** (Settings tab) to `https://your-domain.com/?subscribed=true`
8. **Leave "Double Opt-in Info Redirect URL" empty** – so users see the "check your inbox" message on Keila
9. **Enable "Allow embedding as HTML"** – so CSRF is disabled for cross-origin form submissions

## Email HTML Output

`SiteBuilder.newsletter()` includes `EmailRenderer`, which generates email-safe HTML for every non-draft issue at `_Site/email/<slug>.html`. These files feature:

- Inline CSS (no external stylesheets)
- Table-based layout for email client compatibility
- Dark mode support via `@media (prefers-color-scheme: dark)`
- Automatic hyphenation
- Code block styling (dark background, monospace)
- Callout boxes (emoji-prefixed blockquotes) and quote styling
- Ad/promo blockquote stripping
- Browser preview toggle (JS, ignored by email clients)

Use these HTML files as the content for email campaigns in your newsletter service.

## Variations

- **Without email delivery**: Use `SiteBuilder.blog()` instead of `.newsletter()` to skip email HTML generation. The site works as a plain web archive.
- **Without signup form**: Remove the form from `home.md` and the JS injection from `theme.js`.
- **With promotions**: Add a `promotions:` block in SiteConfig.yaml to show cross-promotion banners in issues. See the blog blueprint for the promotion schema.
- **Multi-language**: Same pattern as Blog – add locale-suffixed content files and a `localization:` block with the three required keys `defaultLanguage`, `languages` (additional languages, excluding the default), and `translationMode` (there is no top-level `supportedLanguages` key). See `references/localization.md`.
- **Custom email design**: The EmailRenderer's inline styles can be customized by modifying the renderer. For advanced customization, create a custom renderer that extends or replaces `EmailRenderer`.
