---
name: content-writing
description: "Help write blog posts, newsletters, and pages with authentic voice. Elicits the author's style and provides structured content templates."
---

# Content Writing

## When to Use
When the user wants help writing a blog post, newsletter issue, or static page.

## Step 0: Load Project-Local Guidelines (always first)
Before drafting, check the project root for a `Guidelines/` folder and read any files relevant to the task:

- `Guidelines/BlogPosts.md` – voice, tone, structure, do's/don'ts for blog articles
- `Guidelines/Snippets.md` – code snippet conventions
- `Guidelines/SocialPosts.md` – social adaptation rules
- Any other `*.md` file with a name matching the content type being written

These are project-specific overrides authored by the site owner. They take precedence over the generic guidance in the rest of this skill – use them as the authoritative voice and structure reference. The generic steps below only apply where the project's guidelines are silent.

If no `Guidelines/` folder exists, fall back entirely to the generic steps below and Step 1 (eliciting voice from the author).

## Frontmatter reference

Every content file is Markdown with a YAML frontmatter block on top. Two loaders read frontmatter and they accept **different field subsets**: articles/section posts (`Content/<section>/…`, parsed by `MarkdownLoader`) and static pages (`Content/Pages/…`, parsed by `StaticPageLoader`).

Minimal examples:

```yaml
---
# Article – Content/Blog/2026-03-15_Miso-Salmon.md
title: "Miso Glazed Salmon"
date: 2026-03-15
tags: [japanese, weeknight]
summary: "A quick weeknight salmon with a sweet-savoury miso glaze."
---
```

```yaml
---
# Static page – Content/Pages/About.md
title: "About"
slug: "about"
description: "Who I am and what I write about."
---
```

| Field | Articles | Static pages | Notes |
|---|---|---|---|
| `title` | **required** | **required** | the only field both loaders require by default |
| `date` | **required** | – (ignored) | `YYYY-MM-DD` only (no time component) |
| `slug` | optional | **required** | articles default the slug from `title`; static pages must set it (it is the URL) |
| `category` | optional | – | matches a section's category |
| `tags` | optional | – | YAML list `[a, b]` or a comma-separated string |
| `summary` | optional | – | listing blurb + social/meta description for articles |
| `description` | – (ignored) | optional | meta description for static pages – **articles ignore it; use `summary`** |
| `author` | optional | – | a name string, or a map `{name, url, imageURL, email}` |
| `image` | optional | optional | hero / social image – host it locally under `Content/Assets/` |
| `imageAlt` | optional | – | alt text for `image`; required only if a blueprint adds it to `requiredFields` |
| `draft` | optional | optional | `draft: true` excludes the file from published output |
| `id` | optional | optional | stable 8-char id; a missing `id` on an article only logs a build warning |
| `originalLanguage` | optional | – | translation provenance (set by the localization flow) |
| `legalDocument` | – (ignored) | optional | static pages only – flags privacy/imprint pages |
| *any other key* | → `extensions` | – (ignored) | custom fields land in `PageModel.extensions` for custom `Page` renderers (see `custom-pages.md`) |

**Required fields are configurable.** Each loader has a `requiredFields` list – default `["title", "date"]` for articles, `["title", "slug"]` for static pages. Blueprints extend it (the podcast blueprint additionally requires `audioURL` and `duration`). A missing or empty required field fails the build with `…required frontmatter field '<x>' is missing or empty` (with file path + line). For articles, `date` is also satisfied by a `YYYY-MM-DD-<slug>.md` (hyphen) filename – but the conventional `YYYY-MM-DD_Title-Slug.md` (underscore) does **not** auto-derive it, so keep `date:` in frontmatter.

**Markdown support.** The body is rendered with Apple's [swift-markdown](https://github.com/swiftlang/swift-markdown): CommonMark plus GFM tables. Fenced code blocks with a language (```` ```swift ````) emit `<pre><code class="language-swift">` – visual syntax highlighting is applied by the theme's CSS/JS, not at build time. SiteKit also supports a `@LinkCard(url: "…", title: "…")` block directive for rich link cards. Always give images meaningful alt text (`![alt](path)` and the `imageAlt:` hero field) – it is an accessibility requirement, and a blueprint may enforce it via `requiredFields`. For multi-language file naming, see `localization.md`.

## Step 1: Understand the Author's Voice
Skip or shorten this step when `Guidelines/BlogPosts.md` already documents the voice. Otherwise ask about:
- Target audience (developers? designers? general public?)
- Tone (casual/professional/academic?)
- Perspective (first person? third person? tutorial style?)
- Do they have existing content to analyze? (read 2-3 existing posts to extract patterns)

## Step 2: Content Planning
- Ask for the topic/idea
- Suggest a title (follow SEO best practices: 50-60 chars)
- Outline the structure (intro -> sections -> conclusion)
- Suggest tags from existing tagDisplayNames in SiteConfig.yaml

## Step 3: Draft the Content
- Write in the author's established voice
- Use proper frontmatter – `title` + `date` are the only fields required for an article (see the Frontmatter reference above); add `summary`, `tags`, and a stable `id` as recommended extras, and an optional `slug:` to pin the URL when the title is volatile
- Include code blocks with language annotations if technical
- Add meaningful alt text to any images
- Keep paragraphs short (3-4 sentences)
- Use headings to break up long content

## Step 4: SEO & Meta
- Summary should be 120-160 chars (used for meta description)
- Title should be compelling and specific
- Tags should match existing site taxonomy (check tagDisplayNames)

## Step 5: Review Checklist
- Required frontmatter present? (`title` + `date` for articles, `title` + `slug` for static pages – plus any field the blueprint's `requiredFields` adds; `id`/`summary`/`tags` recommended)
- Links working? (no broken URLs)
- Code blocks have language annotations?
- Images have alt text?
- No spelling/grammar issues?
- Draft mode? (set draft: true for preview)

## Step 6: Capture Learnings (after the user has edited the draft)

When the user has edited an AI-drafted post and the session is wrapping up – they're publishing, committing, moving on, or explicitly say they're done – review the *full session* of edits:

- Compare the **first draft** you produced against the **current state** of the file. Not the most recent diff – the cumulative delta. Users iterate in many rounds; the patterns only become visible across the whole session.
- Re-read the conversation history. Concrete corrections the user typed in chat ("don't say X", "this section is too long", "rephrase to sound more personal") are often clearer than the diff alone.

Look for **generalizable patterns** – things that should apply to *future* posts, not just this one:

- Phrase replacements applied multiple times (e.g., the user replaced "I discovered" with personal-workflow framing in three places)
- Structural moves (e.g., they consistently moved the conclusion to be more concrete and actionable)
- Sections cut entirely (e.g., they removed every technical deep-dive that drifted from the main story)
- Framings rewritten (e.g., they replaced "analytical" framing with "personal experience" framing)
- **Confirmations of non-obvious choices** – when the user kept something unusual that you wrote without pushback, and explicitly approved it, that is a positive learning worth capturing too. Don't only learn from corrections.

Do NOT propose:

- Pure typo fixes
- One-off factual corrections (those are about *this article*, not the voice)
- Style preferences already documented in `Guidelines/<file>.md`

When you find 1–3 worthwhile patterns, propose specific additions or refinements to `Guidelines/<ContentType>.md` – quote before/after where it helps, and ask: *"I noticed you replaced X with Y three times. Should I add this to `Guidelines/BlogPosts.md` as a phrase rule?"*

**Always propose, never write silently.** The user has final say on what enters their living style guide.

If no `Guidelines/` folder exists yet, offer to create one with a starter template before adding the learning, so the file has a place to live.

## See also

- `siteconfig-reference.md` – the `SiteConfig.yaml` schema (authors map, sections, `tagDisplayNames`).
- `localization.md` – multi-language content: file naming, locale suffixes, translation status.
- `custom-pages.md` – how a custom `Page` renderer consumes frontmatter via `PageModel` + `extensionValue(_:)`.
- `themes.md` – the typography and layout that render this content.
