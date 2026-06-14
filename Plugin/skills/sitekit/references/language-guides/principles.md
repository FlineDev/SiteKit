# Localization Principles for Web Content

Universal guidance for translating a SiteKit site's **content** (articles, pages, navigation labels, calls to action) into another language. The per-language files in this folder add the specifics; this file is the shared baseline.

> **Web content, not app strings.** These guides target prose and site chrome. Apple ships excellent per-language *app-string* style guides with Xcode 26+ (the localization skill under Xcode's String Catalog tooling) – they go deep on UI-string mechanics (format specifiers, plural/device variations, key terminology). They are an authoritative complement: consult them for app-string-level detail. The guidance here is written for SiteKit and focuses on what matters for a website.

## The categories every language file covers

1. **Reader address & formality.** The single biggest decision. Many languages distinguish formal and informal "you" (German du/Sie, French tu/vous, Spanish tú/usted, Japanese politeness levels). Pick one register per site and keep it consistent. Match the source site's voice: an indie developer blog is usually informal; a corporate or legal page is usually formal.
2. **Tone & voice.** Translate the *meaning and feeling*, not word-for-word. Idioms, humour, and marketing punch rarely survive a literal translation – rewrite them so they land naturally for a native reader.
3. **Quotation marks.** Each language has its own: German „…“, French « … » (with spaces), Japanese 「…」, most English “…”. Use the target language's marks, not the source's.
4. **Punctuation & spacing.** Spacing rules differ (French puts a thin space before `: ; ! ?`; German uses non-breaking spaces in abbreviations and between number and unit). CJK uses full-width punctuation. Get these right – they are the clearest "translated by a native" signal.
5. **Numbers, dates, currency.** Decimal and thousands separators flip (1,234.50 vs 1.234,50 vs 1 234,50), date order changes (MM/DD vs DD.MM vs YYYY年MM月DD日), and currency placement varies. Spell out or localize formats in prose; never reformat numbers *inside* code or `%`-style placeholders.
6. **Units & measurements.** Localize to what readers expect (metric vs imperial), with the language's spacing rule between number and unit.
7. **Capitalization.** Title-case is an English habit. German capitalizes all nouns; French, Spanish, and most others use sentence case for headings and do not capitalize weekdays, months, or languages.
8. **Terminology consistency.** Decide each key term once (e.g. how "newsletter", "post", "subscribe" render) and use it everywhere. Keep product and brand names in their original form unless the brand localizes them.
9. **False friends & loanwords.** Watch for words that look similar but differ in meaning, and for English loanwords that are or aren't idiomatic in the target language.
10. **Inclusive & gendered language.** Where the language genders nouns, follow current, readable conventions (see the per-language file) rather than flooding text with split forms.

## Practical rules for SiteKit sites

- **Keep frontmatter keys in English**; translate only the *values* (`title`, `description`, `summary`, body). The same `id` links a file to its translations (see `localization.md`).
- **Translate alt text and image captions** – they are read by screen readers and search engines in the target language.
- **Localize the slug** only if the site wants language-specific URLs; otherwise keep a shared slug. Be consistent.
- **Don't translate code, commands, file paths, or API names** in code blocks.
- **Right-to-left (Arabic, Hebrew):** SiteKit sets `<html lang>` but does not auto-apply `dir="rtl"`. For an RTL site, add `dir="rtl"` and logical-property CSS in your `Theme/` (see `localization.md`).

## Source guides used

The per-language files were written for SiteKit from each language's web-writing conventions. Apple's Xcode 26+ localization style guides (ar, de, fi, fr, fr-CA, he, hi, it, ja, ms, nb, sv, uk, zh-Hans) were consulted as a reference for which conventions matter; they remain the authoritative source for app-string-level detail.
