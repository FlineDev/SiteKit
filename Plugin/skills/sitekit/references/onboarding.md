---
name: onboarding
description: "Create a new SiteKit website from scratch. Use when the user wants to start a new site, pick a blueprint, scaffold the project, and run their first build. Guides through prerequisites, blueprint selection, configuration, and local preview."
---

# Onboarding Skill – New SiteKit Site Setup

Guides a new user from zero to a running SiteKit project. Run all steps interactively; do not skip ahead.

> **Where this fits:** `bootstrap.md` covers the mechanical substrate – cloning SiteKit and running `sitekit doctor` / `sitekit new` to produce a clean scaffold. This skill is the judgment-heavy continuation that picks up once a project exists (blueprint reasoning, theme/font/colour, config fill-in, content, verification). If SiteKit isn't cloned and scaffolded yet, start at `bootstrap.md`, then return here.

---

## Step 1: Prerequisites Check

Run each check and handle failures before continuing.

### Git

```bash
git --version
```

If missing: "Git is not installed. Install it from https://git-scm.com or run `xcode-select --install` on macOS."

### GitHub CLI

```bash
gh --version
```

If missing: "GitHub CLI is not installed. Install it with `brew install gh`, then run `gh auth login`."

### Swift

```bash
swift --version
```

If missing: "Swift is not installed. Install Xcode from the Mac App Store or download the Swift toolchain from https://swift.org/download." SiteKit requires **Swift ≥ 6.2** – if `swift --version` reports older, update before continuing.

> **One-command alternative:** from a SiteKit clone, `swift run sitekit doctor` runs all three checks at once (git, swift ≥ 6.2, gh) and prints a pass/fail report – see `bootstrap.md`. The manual checks above are the standalone fallback.

---

## Step 2: GitHub Repository

Ask: "Do you already have a GitHub repository for your site, or should I create one?"

**If creating:**
```bash
gh repo create <name> --public --description "<description>" --clone
cd <name>
```

**If existing:** ask for the URL and clone it:
```bash
git clone <url>
cd <repo-name>
```

---

## Step 3: Blueprint Selection

Read `blueprints/INDEX.md` to get the list of available blueprints and the decision guide.

Ask: "What kind of site do you want to build?"

| Choice | Blueprint | Use When |
|--------|-----------|----------|
| Blog / personal site with articles | `Blog` | Long-form articles, optional categories |
| Code snippets / tips / TIL | `Snippets` | Short-form content, topic groups |
| App/project showcase | `Portfolio` | Static pages, no time-based content |
| Email newsletter with web archive | `Newsletter` | Periodic issues, signup forms, email rendering |
| Blog + snippets + portfolio | `IndieDev` | Full indie developer website |
| Podcast with episodes | `Podcast` | Audio episodes, iTunes RSS, chapter markers |
| Single product landing page | `AppLanding` | Hero, features, pricing, reviews |
| Minimal / custom | `Plain` | Blank canvas, full control |

Read `blueprints/<Selected>.md` for details on what the blueprint generates and which questions to ask.

### Step 3a: Newsletter-Specific Configuration (only if Newsletter selected)

If the user selected the `Newsletter` blueprint, ask these additional questions:

1. **Newsletter delivery service?**
   - **Self-hosted (Keila + SES)**: Cost-effective (~$5-7/mo). Requires VPS setup. Read `newsletter-setup.md` and guide the user through the full setup (VPS provisioning → Keila Docker installation → Amazon SES domain verification → double opt-in configuration). This is a significant setup process – suggest completing it before or after the site scaffold.
   - **Managed service** (Buttondown, ConvertKit, Resend, Substack): Simpler setup, higher cost. Ask which service they're using and get their form embed URL.

2. **Signup form action URL?** This is the URL the signup form POSTs to. For Keila: `https://your-keila-instance/forms/<form-id>`. For Buttondown: `https://buttondown.com/api/emails/embed-subscribe/<username>`. If they don't have one yet, leave as `YOUR_FORM_ACTION_URL` – they can configure it later.

3. **Existing subscribers to import?** If migrating from another platform (Substack, Buttondown, etc.), note that Keila supports CSV import via the web UI. Managed services typically offer their own import tools.

After scaffolding, replace `YOUR_FORM_ACTION_URL` in both:
- `Content/Pages/home.md` (homepage signup form)
- `Theme/js/theme.js` (after-article signup injection, the `NEWSLETTER_FORM_URL` variable at the top)

---

## Step 3b: Layout Theme Selection

Ask: "What layout style do you prefer?"

| Theme | Description | Best for |
|-------|-------------|----------|
| **Classic** | Top navigation bar, centered content, card-based post listings | Most sites – blogs, newsletters, portfolios |
| **Sidebar** | Fixed left sidebar navigation, table-of-contents on articles | Documentation, learning sites, detailed blogs |
| **Minimal** | No header bar, centered title, typography-focused, generous whitespace | Writing-focused sites, essays, simple newsletters |

Copy the selected layout theme's CSS and JS from `themes/templates/<Theme>/` into the project's `Theme/css/theme.css` and `Theme/js/theme.js`.

## Step 3c: Color Scheme & Font Pairing

Want to see how each layout template looks before picking? Open `Plugin/themes/ThemePreview.html` – an iframe grid of full-layout previews grouped by layout template (Classic / Sidebar / Minimal), each shown with a representative color scheme, font pairing, and light/dark mode. Compare layouts side-by-side; click any tile to open that variant full size.

Provide a clickable link so the user can open it (point it at the actual repo path), and tell the user to **Cmd-click** (on Mac) to open in their browser. For mobile review, Tailshare it instead – `file:///` links do not work on iPhone.

Each preview tile is a complete page: home hero, article cards, a sample article with a code block and a figure, and the footer – so the user sees real layout, not palette swatches.

The preview is a static comparison grid – it shows representative combinations, not every permutation. For the full catalog of all 15 color schemes and all 6 font pairings (with the exact `theme.yaml` token values), see `themes.md`. The blueprint catalog (`references/blueprints.md`) describes which themes pair best with each blueprint type.

Ask the user to open the preview, decide on a layout template + color scheme + font pairing, then update `Theme/theme.yaml` with their selection.

Do NOT describe fonts/colors in text only – visual comparison is essential.

### Self-hosted fonts (recommended)

After the user picks a font pairing, **automatically set up self-hosting** – it's a privacy + performance win with no user-visible cost. SiteKit supports this via a `selfHostedFonts: true` flag in `theme.yaml`.

1. Read the chosen `fontPairing` (e.g., `modern`, `geometric`) and their preset/overrides to determine which font families are used. See `themes.md` § *Self-hosting Google Fonts* for the mapping.
2. Run the download script:
   ```bash
   Plugin/scripts/download-fonts.sh <site-root> "Font1:weights" "Font2:weights"
   ```
   This fetches woff2 files from the public `gwfh.mranftl.com` API (Google Fonts re-distributed under SIL OFL / Apache 2.0) into `Theme/fonts/`.
3. Add `selfHostedFonts: true` to `Theme/theme.yaml`.

If the user uses the `system` font pairing, skip this – no web fonts to host.

Do NOT ask the user whether to self-host – do it silently and mention it in the final summary ("I've set up self-hosted fonts for privacy – no third-party font requests").

---

## Step 4: Language Setup

Ask: "Will your site be in a single language, or do you want multi-language support?"

- **Single-language:** Set `defaultLanguage` in `SiteConfig.yaml` and leave `localization` section out
- **Multi-language:** Ask which languages (e.g. `["en", "de", "ja"]`), set `localization.languages` in config

---

## Step 4b: Legal Pages & Jurisdiction

Whether the site needs an **imprint** or a **privacy policy** depends on the owner's country and what the site does, so ask now:

> "Which country are you based in, and is this a personal site or a business/commercial one?"

Then load `references/legal-pages.md` and follow it: it has a per-country table and decides the form – a full legal page, just a footer line, or nothing. Privacy is driven by what the site collects (forms, analytics, embeds). Add any resulting `Content/Pages/Imprint.md` / `Content/Pages/Privacy.md` and link them in `footer` during the scaffold step below. State once, plainly, that this is orientation, **not legal advice** – accuracy is the owner's responsibility.

---

## Step 5: Project Scaffold

Scaffold the project with the `sitekit` CLI – do **not** copy blueprint files by hand. From a SiteKit clone (see `references/bootstrap.md` if SiteKit is not cloned yet):

```bash
swift run sitekit new <site-name> --blueprint <Selected>
```

The CLI copies the blueprint into a fresh `<site-name>/` directory, excluding build / VCS / output cruft (`.build/`, `.git/`, `_Site/`, `.DS_Store`, `*.xcodeproj`, `.swiftpm/`), and refuses to scaffold into a non-empty directory. The result is a clean project root with `Package.swift`, `SiteConfig.yaml`, `.gitignore`, `Sources/`, and `Content/`.

Then fill in these fields in `SiteConfig.yaml`:

| Field | Question to Ask |
|-------|----------------|
| `name` | "What's the name of your site?" |
| `baseURL` | "What will the live URL be? (e.g. https://example.com)" |
| `author.name` | "What's your name?" |
| `author.imageURL` | "Do you have a profile photo URL?" (for article bylines – e.g. `/assets/images/profile.webp`) |
| `author.email` | "What's your email address?" (optional, can be omitted) |
| `footer.social` | "What social media accounts should appear in the footer?" (ask for platform + URL pairs – do NOT default to personal accounts) |
| `navigation.logo.image` | "Do you have a logo image? If not, I'll create a placeholder." (create a simple SVG placeholder with the site's initial and accent color) |
| `footer.copyrightName` | Usually same as author name |
| `footer.startYear` | Current year |

**Homepage hero image:** Ask the user: "Would you like a background image for the homepage hero section? Describe what you'd like and I can find one from Unsplash, or we can use a solid color for now." If they want an image, download from Unsplash, convert to webp, and set it as a CSS background with a semi-transparent accent color overlay.

**Always host images locally.** Every image the site references – profile photos, app icons, hero backgrounds, avatars – must live under `Content/Assets/` (or `Theme/images/` if theme-owned), not hotlinked from GitHub, Gravatar, or other third-party CDNs. Reasons: third-party CDNs send short cache TTLs (GitHub avatars = 5 min), can't be touched by the responsive image pipeline (so they ship at their source resolution), and each extra origin costs a DNS+TCP+TLS roundtrip on mobile. When the user provides a remote URL, download it once (`curl -o Content/Assets/images/<name>.webp <url>`) and use the local path. Document this in the site's README/AGENTS so the user keeps the rule after onboarding.

**Tag display names:** After content is added, extract all unique tag slugs from frontmatter and add a `tagDisplayNames` mapping in `SiteConfig.yaml` with properly cased display names for each tag. Without this, tags render as raw slugs (e.g. `swift-6` instead of `Swift 6`). Example:
```yaml
tagDisplayNames:
   swift-6: "Swift 6"
   async-await: "Async/Await"
   objective-c: "Objective-C"
```

For multi-language sites, also configure `localization.languages` and `localization.defaultLanguage`.

See `siteconfig-reference.md` for all available fields.

---

## Step 5b: Project Context Files

`sitekit new` already drops an `AGENTS.md` (skill-loading guidance: which `sitekit` reference to load for which task) and a `CLAUDE.md` (`@AGENTS.md`) into the new site. Do **not** replace that SiteKit guidance – personalize it instead:

- At the top of the generated `AGENTS.md`, add a one-line **Overview** of what this site is and a short **Content Structure** note (directories + file-naming convention), based on the user's earlier answers.
- Leave the "When to load which reference" table and the commands intact – they keep future AI sessions pointed at the right guidance.

**If the repo already had its own `AGENTS.md`** (the CLI never overwrites one): add a short "SiteKit" section at the end with the build commands and a pointer to the `sitekit` skill. Do not overwrite existing content.

---

## Step 5c: Author Voice Bootstrap

Create a `Guidelines/` folder at the project root with starter files that match the chosen blueprint. These files are mostly-empty skeletons – they fill in over time as the user corrects AI-drafted content (the `content-writing` and `localization` skills propose additions after each session).

```bash
mkdir -p Guidelines
```

Then copy the relevant templates from `Plugin/templates/Guidelines/` into the project's `Guidelines/` folder, based on the blueprint:

| Blueprint | Files to copy |
|---|---|
| `Blog`, `Newsletter`, `Podcast`, `IndieDev` | `BlogPosts.md` |
| `Snippets`, `IndieDev` | `Snippets.md` |
| `IndieDev` (and any blueprint, on user request) | `SocialPosts.md` |
| Any blueprint when multi-language | `Translations.md` |
| `AppLanding`, `Portfolio`, `Plain` | None by default – add later if the user starts publishing posts |

After copying, tell the user:

> "I've created a `Guidelines/` folder with starter templates. They're mostly empty on purpose – every time I draft content for you and you edit it, I'll propose additions to the matching file based on patterns in your edits. Over time these files become a living reflection of your voice – derived from real corrections, not a one-time questionnaire."

Do NOT prompt the user to fill in the templates manually. The whole point is that they grow organically through the learning loop.

---

## Step 6: First Build

```bash
swift run Site build
```

If the build succeeds, proceed. If it fails:
- Check for missing Swift version (`swift --version` should show 6.2+)
- Check that `Package.swift` references `SiteKit` correctly
- Read the error output and fix the root cause before retrying

---

## Step 7: Browser Verification Setup

Before previewing the site, set up browser automation so you can verify the site looks correct autonomously – catching layout issues, broken links, and rendering problems before the user has to review manually.

### Why browser-use CLI?

Explain to the user:

> "I recommend installing **browser-use CLI** – a lightweight browser automation tool. It lets me open your site in a real browser, take screenshots, click through pages, and verify everything works – all without you having to check every page manually.
>
> It's much more token-efficient than alternatives like Playwright MCP (10–50× fewer tokens per page inspection), runs as a simple terminal command, and needs no extra server configuration."

### Check Installation

```bash
which browser-use || which bu || which browser || which browseruse
```

**If installed:** Tell the user: "browser-use CLI is already installed – we're all set for visual verification." Then skip to the permission check below.

**If not installed:** Ask:

> "browser-use CLI is not installed yet. It takes about 30 seconds to set up and lets me verify your site automatically during development – catching broken layouts, missing images, and navigation issues before you have to check manually. Want me to install it?"

If the user agrees, install:

```bash
curl -fsSL https://browser-use.com/cli/install.sh | bash
```

Then verify:

```bash
browser-use doctor
```

If the user declines, acknowledge and skip to Step 8 (Local Preview) without browser verification: "No problem – I'll start the dev server and you can check the site manually in your browser."

### Check Bash Permissions

Read `~/.claude/settings.json` and check if the `allow` list contains a rule that permits `Bash(browser-use *)`. This is satisfied by any of:
- `"Bash(browser-use *)"` – explicit browser-use permission
- `"Bash(*)"` – all Bash commands allowed
- `"Bash"` – all Bash commands allowed

**If no matching permission exists:** Explain and offer to add it:

> "For browser verification to run smoothly during development, I need permission to run `browser-use` commands without asking each time. I'd like to add `Bash(browser-use *)` to your Claude Code settings – this only allows browser-use commands, nothing else. OK?"

If the user agrees, add `"Bash(browser-use *)"` to the `allow` list in the appropriate `settings.json` (user-level if the user works across multiple SiteKit projects, project-level if they prefer per-project control).

---

## Step 8: Local Preview

```bash
swift run Site serve
```

Share the local URL: **http://localhost:8080**

### Autonomous Verification (if browser-use is available)

Use browser-use CLI to take screenshots and verify the site before asking the user to review:

```bash
browser-use open http://localhost:8080          # open the local site
browser-use screenshot homepage.png             # full-page screenshot of homepage
browser-use state                               # discover clickable elements
browser-use click <post-card-index>             # click post cards to verify they work
browser-use back                                # return to homepage
browser-use eval "JSON.stringify(               # verify search and archive structure
   Array.from(document.querySelectorAll('a'))
      .filter(a => /search|archive|rss/i.test(a.href))
      .map(a => ({text: a.textContent.trim(), href: a.href}))
)"
```

Check for broken images and missing assets:

```bash
browser-use eval "JSON.stringify(
   Array.from(document.querySelectorAll('img'))
      .filter(img => !img.complete || img.naturalWidth === 0)
      .map(img => ({src: img.src, alt: img.alt}))
)"
```

Check for console errors:

```bash
browser-use eval "window.__errors = window.__errors || []; window.addEventListener('error', e => window.__errors.push(e.message))"
# ... navigate through pages ...
browser-use eval "JSON.stringify(window.__errors)"
```

Close the browser session when done:

```bash
browser-use close
```

Present a summary of findings to the user: what looks good, what might need attention (broken images, missing links, layout issues).

### Manual Verification (if browser-use is not available)

If browser-use was not installed, tell the user:

> "Your site is running at http://localhost:8080 – open it in your browser and check:
> - Does the homepage look right? (hero, post cards, navigation)
> - Do post cards link to the correct articles?
> - Does the search work?
> - Does the footer show the right social links?"

Then ask the user to review and confirm the site looks as expected.

---

## Step 9: Next Steps

Once the site is running locally, route the user:

- **Deploy the site:** Run `/sitekit:deploy` to set up CI/CD with Cloudflare Pages, GitHub Pages, or another host
- **Customize the theme:** See `themes.md` for the full token system, presets, color schemes, and font pairings
- **Write content:** Create `Content/Blog/YYYY-MM-DD_Title-Slug.md` files with YAML frontmatter
- **Full reference:** See `siteconfig-reference.md` for every `SiteConfig.yaml` field

---

## See also

- `bootstrap.md` – the mechanical prequel: clone SiteKit, `sitekit doctor`, `sitekit new`, `sitekit update`.
- `Plugin/blueprints/INDEX.md` – the blueprint picker (decision tree + feature comparison).
- `deployment/SKILL.md` – set up push-to-deploy (host + CI matrix); or run `/sitekit:deploy`.
- `troubleshooting.md` – build/runtime issues encountered during any step above.
