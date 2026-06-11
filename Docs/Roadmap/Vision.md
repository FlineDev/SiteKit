# SiteKit Vision

## The Dream

SiteKit is an **AI-guided website building system**. It provides the structure, building blocks, and documentation so that an agentic AI can build *any* static website for *anyone* – regardless of the person's technical skill level.

The user describes what they want. The AI reads SiteKit's documentation to understand what's possible and how to do it. The AI builds a draft. The user reviews, requests corrections, and the AI iterates. This loop continues until the website meets the user's needs.

SiteKit's job is to make sure the AI always knows exactly what building blocks exist, how they work, how data flows through the pipeline, and where custom work belongs.

---

## Primitives, Not Features

Under the hood, SiteKit is a small set of **swappable primitives** – one protocol per pipeline phase (`ContentDiscovery`, `Loader`, `Enricher`, `Renderer`, `OutputProcessor`, `Teleporter`), one enum for renderer routing (`RenderScope`), and one chrome helper (`PageShell`). These primitives compose into a phase-oriented pipeline; the contributor reference [`AGENTS.md` §2 (Pipeline) + §3 (Two-level vocabulary)](../../AGENTS.md) maps the phases, protocols, and `SiteBuilder` swap points side by side so any AI agent can locate *where* a new behavior plugs in without re-deriving the architecture.

The framing is deliberate: SiteKit is a **hackable harness**, not a closed product. It does not ship "blog mode" or "podcast mode" as features baked into the engine. It ships the primitives, and a `Blueprint` is a pre-composed recipe of primitives for a common site type – opinions stacked *on top of* the harness, never inside it. An AI agent (or a human) reads the reference, picks the phase that needs a new behavior, conforms to one protocol, and registers the new primitive with `SiteBuilder`. Everything else in the pipeline stays untouched.

Cross-cutting invariants – SEO/ASO, performance, accessibility, AI-friendliness – are protected by the harness regardless of which primitives you swap in. That is the bargain: replace any primitive, keep every guarantee.

---

## The Real Differentiators

### 1. AI-Guided Onboarding

The single most important user experience is getting started. Someone who has never built a website should be able to go from zero to a live, deployed website – guided entirely by an AI agent – without needing to understand Git, deployment, Swift, or HTML.

SiteKit ships as a **Claude Code plugin**. The user installs it, runs a command (`/sitekit start` or similar), and the AI takes over:

- "Do you already have a Git repository? No? Should I create one? Do you know what Git is?"
- "Do you have a GitHub account? No? Here's how to create one – I'll wait."
- "What kind of website do you want? Describe it in your own words."
- The AI maps the description to a blueprint and building blocks
- "Do you want the website translated into multiple languages so more people can find it?"
- "I've started a preview server – click this link to see what it looks like so far."
- AI presents design options, user gives feedback, AI iterates

Technical users can specify frameworks, CSS systems, or custom requirements. Non-technical users just describe what they want and react to what they see.

### 2. AI-Guided Deployment

Deployment is the second critical moment. Once configured, deployment is automatic – every push deploys the site. Getting to that state is what the AI handles.

SiteKit offers two deployment modes based on user preference:

#### Mode A: Guided (Technical Users)
The AI explains the options: Cloudflare Pages, GitHub Pages, Netlify, Vercel – with their limitations, free tiers, and a clear recommendation. It then gives step-by-step instructions:
- "Click Settings → Pages → Connect repository"
- Explains what each screen is and why you're doing it
- User takes the actions themselves, AI talks them through it

#### Mode B: Automated (Non-Technical Users)
Claude Code takes over using browser-use CLI to click through the hosting provider UI on the user's behalf:

1. **Before starting:** The AI explains exactly what it will do, what screens will appear, and roughly how long it will take. "I'm going to open Cloudflare's signup page, fill in your project name, connect your GitHub repo, and set up the build command. I'll take a few seconds between each step – I'm not as fast as a human. You can watch me, or go do something else and I'll notify you when it's done."
2. **Account creation:** User creates their own account and logs in using their password manager. Credentials never pass through Claude Code – security is maintained.
3. **After login:** Claude Code takes over, navigates the dashboard, configures everything, and returns with a live URL.
4. **Security transparency:** Claude Code explains before each action what it's about to do and why.

#### Browser Automation Setup
browser-use CLI is the recommended tool for browser automation – it uses 10–50× fewer tokens than Playwright MCP and requires no MCP server configuration. A setup check during onboarding ensures it's available:
- Detects whether browser-use CLI is installed (`which browser-use`)
- If missing, guides installation: `curl -fsSL https://browser-use.com/cli/install.sh | bash`
- Verifies Bash permissions in `settings.json` cover `browser-use *` commands
- Falls back to Playwright MCP if the user already has it configured and prefers it

#### After Deployment
Once live, the AI explains: "From now on, every time you push changes to GitHub, your site rebuilds and deploys automatically. You never need to do this setup again."

### 3. Localization Built In

Language is the number one accessibility barrier. Most websites are published in one language and never translated. SiteKit treats localization as a default, not an afterthought.

During onboarding, the AI asks: "Do you want the website translated into multiple languages?" If yes, SiteKit handles:
- Locale-aware URL structure
- hreflang metadata
- Language switcher UI
- Missing translation detection and warnings

A dedicated localization skill auto-loads whenever a site is multilingual, so the AI always knows the current localization state and how to fill gaps.

**Tooling (planned):**
- Linter/checker that detects missing translations for any locale
- CI/CD pipeline check: fail build if required translations are missing
- AI skill with localization best practices, common pitfalls, and SiteKit-specific patterns

### 4. Accessibility Built In – No Questions Asked

The second accessibility barrier is disability: screen readers, keyboard navigation, contrast ratios, semantic HTML. Accessibility is **not optional and not asked about during onboarding** – it is simply the default.

Users who are not affected by disability typically don't think to ask for it. SiteKit ensures it happens regardless.

**Tooling (planned):**
- HTML accessibility linter (tools like axe-core or pa11y) run as part of the build
- Headless browser checks for rendered accessibility issues (via browser-use CLI or Playwright)
- AI skill with accessibility best practices (ARIA labels, alt text, heading structure, color contrast)
- CI/CD pipeline step: fail or warn on WCAG violations
- Auto-fixes where possible: AI adds missing alt text, ARIA roles, semantic wrappers

The localization and accessibility skills are loaded automatically when relevant – the AI doesn't need to be told to care about them.

Both surfaces are **cross-cutting invariants** of the pipeline: no matter which primitives a site swaps in, the harness preserves the language coverage and accessibility guarantees across every phase that contributes to them.

---

## Scope: Any Static Website

If a website can be built as static HTML/CSS/JS on a CDN – SiteKit can build it:
- Personal blogs
- App landing pages (iOS, macOS, visionOS, Android, cross-platform)
- Portfolios
- Restaurant websites
- Podcast sites
- Conference sites
- Club and community sites
- Children's creative sites with animations and interactive elements
- Documentation sites
- Indie developer sites (apps + open-source + blog combined)

Dynamic features are supported through JavaScript integrations: search (already built), contact forms, reservation systems, analytics, maps, audio players, newsletter signups, and payment links – all via embeds or client-side JS, no backend needed.

**Out of scope:** Server-side authentication, database-backed user content, real-time personalized content, e-commerce checkout.

---

## The Build Loop: Smart Iteration

Between onboarding and deployment lies the build loop – equally core to the experience.

### Self-Validation Before User Review

The AI should not ask the user to check something until it has already validated it itself. Before presenting a result:
- Run the build and check for errors
- Run accessibility checks
- Run localization completeness checks
- Visually verify the page looks correct (`browser-use screenshot` if needed)
- Only then say: "Here's what I've built – here's the link."

This respects the user's time. The user should only ever be asked to give *design and content* feedback, never to spot technical issues the AI should have caught itself.

### Smart Questioning

The AI should ask questions at the right time, in the right amount. Principles:
- Never ask multiple things at once – one question, wait for answer
- Don't ask about things the user doesn't need to care about (technical details, accessibility settings, deployment internals)
- Batch low-stakes questions together only if they're clearly related
- Prefer showing over asking: show a preview rather than asking "what color do you want?"
- Ask for feedback after a meaningful change, not after every small tweak

### Content Creation Skills

A major part of any website is its written content – and this is where most AI-generated content falls flat. SiteKit should have dedicated skills for:

**Writing skills:**
- Blog post writing
- Article writing
- App feature descriptions
- Marketing copy (landing pages, store listings)
- Short-form content (snippets, quotes, social posts)

**The core principle:** Content should sound like the user, not like AI. Honest, authentic, with the user's own voice. Not marketing-speechy, not generic, not over-polished.

**The content capture technique:** Rather than asking the user to write, the AI guides them to *speak* – to explain their feelings, their motivation, their struggles, their fun moments. For example:
- For an app landing page: "Tell me about the moment you decided to build this. What problem were you having? How bad was it?"
- For a blog article: "What was the moment that made you go 'wait, that's interesting'? What surprised you?"
- For a feature description: "How would you explain this to a friend who just asked what it does?"

The AI then shapes that raw authentic input into polished content that still sounds like the user. The skill of *extracting that content from the user* is itself a skill – knowing which questions unlock genuine expression.

---

## Theming

SiteKit should make design accessible to non-technical users too:

- **Theme picker** – A static HTML page (part of the plugin) showing all available themes with screenshots, color palettes, and live previews. During onboarding, the AI opens this file directly in the browser (`open theme-picker.html`) and asks the user to choose. The chosen theme is copied into the project as a starting point.
- **Theme templates** – Each theme is a complete CSS template covering the full site shell. They are not blueprint-specific – any theme works with any blueprint. The AI copies the chosen template into `Theme/` and adjusts colors, fonts, and spacing based on the user's description.
- **AI-guided iteration** – After showing a first preview, the AI asks: "Does this feel right, or did you want to go in a different direction?" The user can describe what they want ("more minimal", "warmer colors", "less padding") and the AI adjusts. No flavor selection needed – the AI adapts to each user.
- **Color customization** – Change accent color, background, text color at any time via SiteConfig.yaml. No CSS required.
- **Custom CSS** – Technical users can override or extend anything. Fully flexible.

---

## Blueprints

A **Blueprint** is a documented, reusable recipe – a pre-composed set of SiteKit primitives for a specific type of website. Blueprints are the opinionated entry point: they stack opinions on top of the primitive harness, they do not bake opinions into the engine. Anyone – AI or human – can adopt a blueprint as-is, fork it, or compose a new one from the same protocols.

When a user says "I want a restaurant website," the AI reads the Restaurant blueprint and knows exactly which primitives to assemble: which renderers to register on `SiteBuilder`, which enrichers to chain, which content types each loader produces, and which CSS theme to start from – without re-deriving the composition from scratch.

### What a Blueprint Contains

- `blueprint.md` – AI-readable description of the site type, what to build, how to customize, what content is needed
- `content-schema.md` – Frontmatter fields for each content type (MenuItem, PodcastEpisode, AppFeature, etc.)
- `SiteConfig.template.yaml` – Config template with placeholders
- `generators.swift` – The SiteBuilder composition for this site type
- `sample/` – 2–3 sample content files showing the expected format
- Optional **Flavors** – Variations (tech podcast vs. music podcast, fine dining vs. café)

### Planned Blueprints (Initial Set)

**Content Sites:**
- Blog – standard blog with categories and tags
- Indie Developer Site – apps + open-source packages + blog (fline.dev is the reference implementation)
- Podcast Site – episodes, show notes, iTunes RSS

**App Landing Pages:**
- iOS App Landing Page
- macOS App Landing Page
- visionOS App Landing Page
- Apple Platforms App Landing Page (iOS + macOS + visionOS)
- Cross-Platform App Landing Page (iOS + Android)

**Business Sites:**
- Restaurant Website – menu, hours, reservations embed, photos
- Product + Docs Site – landing page with integrated documentation

**Community Sites:**
- Portfolio
- Conference Website

### Community Blueprints

The community contributes additional blueprints over time. Every finalized website is a potential blueprint.

---

## Blueprint Creation Skill (Future)

Once a website is built and live, the owner can run a Claude Code skill to turn it into a reusable blueprint:

1. The skill analyzes the site: what kind of site is it, what content types does it use, what custom generators were written, what problems were solved and how?
2. It generates `blueprint.md`, `content-schema.md`, and sample content from the existing site
3. The owner reviews and names/describes the blueprint
4. The blueprint is ready to share with the community

This closes the loop: building a website automatically produces knowledge that future builders can reuse.

---

## Release Goal

SiteKit's public debut is planned for a **Swift conference presentation** – a talk introducing SiteKit as the AI-native static site generator for the Swift ecosystem.

The pitch:
> Anyone builds any website – in any language, accessible to everyone – guided by AI, built on Swift.

The demo: a live AI session building a real website from scratch, guided through onboarding, with localization and accessibility handled automatically, deployed to a live URL – all without the presenter writing a single line of code manually.

---

## Two-Part System

SiteKit is two distinct things that work together:

### 1. SiteKit (Swift library + CLI)

The **primitives layer**. A Swift package that websites depend on as a library. The public surface is small on purpose: one protocol per pipeline phase (`ContentDiscovery`, `Loader`, `Enricher`, `Renderer`, `OutputProcessor`, `Teleporter`), one enum for renderer routing (`RenderScope`), one chrome helper (`PageShell`), and the fluent `SiteBuilder` for composing them. Each website is itself a Swift package with a build executable target (`Sources/Site/Main.swift`) that imports SiteKit and runs the build:

```swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()   // handles: build, serve, validate
   }
}
```

Commands: `swift run Site build`, `swift run Site serve`, `swift run Site validate`. The `sitekit` CLI (doctor / blueprints / new / update) covers scaffolding and maintenance around that per-site executable.

Custom plugins (when SiteKit's built-ins aren't enough) live as Swift files in the website's own `Sources/Site/`. The AI writes these – the user never touches them.

### 2. SiteKit Claude Code Plugin (the AI layer)

The **composition layer**. Contains everything the AI needs to compose the primitives into a working website for the user:

**Skill** – one consolidated `sitekit` skill: its `SKILL.md` is the routing entry point that loads focused reference files on demand (`references/onboarding.md`, `deployment/`, `content-writing.md`, `localization.md`, `accessibility.md`, `themes.md`, and more). New site → onboarding reference. Deploying → deployment reference. Writing content → content-writing reference.

**Blueprints** – the site-type recipes:
- `blueprints/INDEX.md` – catalog of all available blueprints with selection guidance
- `blueprints/<Name>/` – complete starter sites the `sitekit new` command clones

**Reference docs** – pipeline documentation (`references/architecture.md`), config reference (`references/siteconfig-reference.md`), and per-domain pattern guides

### How the Two Parts Interact

The Claude Code plugin's skills do the work directly – scaffolding files, editing config, running builds. For example: the onboarding skill determines which blueprint to use, writes the project files directly, then runs `swift run Site build` to verify everything works. The deployment skill walks the user through hosting setup, then runs `swift run Site build` to confirm before going live.

---

## How SiteKit Achieves This

### Clear Documentation for AI
Every feature, pattern, and extension point is documented so an AI agent reading the docs can always determine:
- What is already possible
- Which building block to use
- How data flows (source → pipeline → output)
- Where custom work belongs (new generator? enricher? YAML config? CSS?)

### Primitives, Not Opinions
SiteKit ships **primitives**, not opinions: one protocol per phase, one enum (`RenderScope`) for renderer routing, one chrome helper (`PageShell`), and the `SiteBuilder` that composes them. The phase-oriented pipeline tells you where any new behavior plugs in; the cross-cutting invariants tell you what holds regardless of which primitives you swap. Blueprints stack opinions on top of the harness for specific site types; the core never grows feature flags, the harness stays hackable.

### The Iterative Build Loop
1. User describes what they want
2. AI reads relevant blueprint and SiteKit docs
3. AI scaffolds the project and builds a draft
4. AI starts preview server, user reviews in browser
5. User requests corrections
6. AI iterates
7. Repeat until satisfied
8. AI deploys to live hosting

SiteKit's structure makes this loop fast: config-driven customization (YAML, no code), protocol-based extensibility (one protocol for a new generator), and clear output organization.

---

## One-Line Summary

**SiteKit = AI guides anyone through onboarding → building any static website → deployment, with localization and accessibility built in, blueprints for every use case, content skills that capture your authentic voice, and smart iteration that respects your time.**

**Under the hood: a hackable harness of swappable primitives – one protocol per pipeline phase, one routing enum, one chrome helper – that AI agents compose into any site, with SEO, performance, accessibility, and AI-friendliness preserved across every swap.**
