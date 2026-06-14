---
name: localization
description: "Set up and manage multi-language content in a SiteKit site. Guides through language configuration, content translation, and validation."
---

# Localization

## When to Use
When the user wants to add translations to their site or manage existing multi-language content.

## Localization Model

How multilingual sites work in SiteKit, before the step-by-step workflow below.

**Configuration (full schema → `siteconfig-reference.md`).** A site is single-language until you add a `localization` block:

- `language:` (top-level) – the primary language as a BCP 47 code (e.g. `en`). Legacy alias `defaultLanguage` is still accepted; if neither is set it defaults to `en`.
- `localization.languages: ["de", "ja"]` – the ADDITIONAL languages to build, excluding the default (listing the default again would build it twice). `localization.defaultLanguage` – the default within the block. Both are **required** in the block, as is `translationMode`. Also under `localization`: `styleGuidePath`, `legalLanguage`, `translationNotice`, `localeOverrides` (per-locale nav/footer/homePage/description – **not** UI strings).

**Content convention.** Translations use a Hugo-style locale **suffix** on the filename: `About.md` (default) → `About.de.md` (German). Only *configured* language codes are recognized as suffixes, so `my-post.v2.md` is not mistaken for a locale file. Keep the same frontmatter `id` across a file's translations (links them together) and set `originalLanguage: "en"` on the translated copies.

**URLs.** Each non-default locale is served under a prefix (`/de/...`) via `LocaleAwareURLRouter`; the default language is unprefixed. Every page is emitted with `<html lang="…">` for the active locale.

**hreflang.** On multilingual builds the pipeline injects a `translationMap` (base slug → available locales); `HreflangEnricher` (Phase 3) turns it into `page.extensions["hreflang"]`, and `PageShell` emits the `<link rel="alternate" hreflang="…">` tags automatically.

**Per-locale vs global output.** `.perLocale` renderers run once per locale (article pages, per-locale RSS, per-locale `sitemap.xml`); `.global` renderers run once per build (sitemap index, `robots.txt`, `llms.txt`). See `architecture.md` / `themes.md` for `RenderScope`.

**Missing-translation fallback.** You do **not** need to pre-translate everything: when a locale is missing a file, the build falls back to the default-language source for that page, so the locale still has a complete site. Legal pages (`legalDocument: true`) additionally show a translation notice when viewed in a non-primary language.

**Translation status.** Every multilingual build writes `translation-status.json` at the site root – a machine-readable list of missing translations for AI agents. `swift run Site validate` reports the same gaps per language and exits non-zero when any are missing.

**UI strings.** SiteKit bundles translations for the theme chrome ("Read more", nav labels, dates, etc.) in **36 locales**: ar, bg, ca, cs, da, de, el, en, es, eu, fi, fr, he, hi, hr, hu, id, it, ja, ko, ms, nb, nl, pl, pt, ro, ru, sk, sl, sv, th, tr, uk, vi, zh-Hans, zh-Hant. To add a locale or override a string, create `Strings/Localizable.json` in the project root – it is merged over the bundled set.

**Known limitation – RTL.** UI strings for `ar` and `he` are bundled and `<html lang>` is set per locale, but SiteKit does **not** automatically apply `dir="rtl"` or RTL layout. For a right-to-left site, add the `dir` attribute and logical-property CSS in your `Theme/`.

## Step 0: Load Project-Local Guidelines (always first)
Before translating, locate the project's translation style guide:

1. If `SiteConfig.yaml` has `localization.styleGuidePath` set, read that file.
2. Otherwise read `Guidelines/Translations.md` at the project root if it exists.
3. For the **per-language conventions** (formality, quotation marks, punctuation and spacing, number and date formats, capitalization, common pitfalls), read `references/language-guides/principles.md` and the file for each target language (e.g. `references/language-guides/de.md`). These are the baseline for web prose.

The project guide captures per-language translation rules, terminology choices, formality preferences, and the author's voice in each target language. Project overrides take precedence over both the generic defaults and the per-language baseline guides – apply them throughout the workflow below.

## Step 1: Language Configuration
Check `SiteConfig.yaml` for:
- `language:` – the primary language (top-level; legacy alias `defaultLanguage`)
- `localization.languages:` – the ADDITIONAL languages to build, excluding the default, e.g. `["de", "ja"]` (listing the default again would build it twice; there is no top-level `supportedLanguages` key)
If no `localization` block exists, ask which languages to support and add one (`languages` + `defaultLanguage`). See `siteconfig-reference.md` for the full `localization` schema.

## Step 2: Content Structure
Explain the locale suffix pattern:
- `About.md` -- primary language (English)
- `About.de.md` -- German translation
- `About.ja.md` -- Japanese translation
- Blog posts: `2026-01-01-hello.md` -> `2026-01-01-hello.de.md`

## Step 3: Create Translation Files
For each page/post to translate:
1. Copy the original file
2. Add locale suffix to filename
3. Keep the same frontmatter id (important for linking translations)
4. Translate the content
5. Set `originalLanguage: "en"` in frontmatter if this is a translation

## Step 4: Translation Notices
Legal pages (privacy, imprint) get automatic translation notices when:
- `legalDocument: true` is in frontmatter
- The page is viewed in a non-primary language

## Step 5: Validate
Run: `swift run Site validate`
This reports every page that is **missing a translation** in one of the configured languages (per language), and exits non-zero if any are missing. The same data is written to `translation-status.json` at the site root on each build. (Validation covers missing translations only – it does not check frontmatter consistency or flag orphaned files.)

## Step 6: UI Strings
SiteKit ships UI-chrome translations (nav labels, date formatting, "Read more", etc.) for **36 locales** (see the Localization Model section above for the full list – including `en`, `de`, `ja`, `tr`, and RTL `ar`/`he`).
To add a locale that isn't bundled, or to override any bundled string, create `Strings/Localizable.json` in the project root – it merges over the built-in set. (Note: `localization.localeOverrides` in `SiteConfig.yaml` overrides nav/footer/homePage/description per locale – it does **not** provide UI-chrome strings.)

## Step 7: Capture Translation Learnings (after the user has edited the translation)

When the user has edited an AI-translated post and approved it, review the *full session* of edits:

- Compare the **first translation** you produced against the **current state** of the translated file. Not the most recent diff – the cumulative delta across all the rounds of correction.
- Re-read the conversation history. Direct corrections in chat ("'Ich entdeckte' is too analytical, use 'Mir ist aufgefallen'", "this sounds too literal, restructure freely") are often clearer than the diff alone.

Look for **generalizable per-language patterns**:

- Phrase replacements applied multiple times in the target language
- Register or formality corrections (e.g., dropping a too-formal pronoun for an informal one consistently)
- Idiom translations the user established (source idiom → target-language equivalent)
- Calques the user rejected (English compounds the user refused to mirror in the target language)
- Restructurings the user preferred (e.g., always splitting long subordinate clauses in German)
- **Confirmations of non-obvious choices** – translations the user kept unusual and explicitly approved.

Do NOT propose:

- One-off content corrections (specific to this article)
- Patterns already documented in `Guidelines/Translations.md`

When you find 1–3 worthwhile patterns, propose specific additions to `Guidelines/Translations.md` (under the relevant language section), quoting before/after where it helps. **Always propose, never write silently.**

If no `Guidelines/Translations.md` exists yet, offer to create one from `Plugin/templates/Guidelines/Translations.md` so the file has a place to live.

## See also

- `siteconfig-reference.md` – the full `localization` config schema (`language`, `languages`, `defaultLanguage`, `translationNotice`, `localeOverrides`, …).
- `content-writing.md` – per-article frontmatter (`originalLanguage`, `legalDocument`, the locale suffix).
- `seo-aso.md` – how hreflang feeds SEO.
- `themes.md` – UI-string consumption and `RenderScope` (per-locale vs global output).
