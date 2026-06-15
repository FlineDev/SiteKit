# German (de) – Web Content Style Guide

Read `principles.md` first. This file adds German-specific rules for translating a SiteKit site's content.

## Address & formality
- **Informal "du"** fits most indie, developer, and personal sites – lowercase (`du`, `dein`, `dir`), not capitalized in body text. **Formal "Sie"** fits business, legal, and institutional sites. Decide once per site and never mix.
- Prefer impersonal phrasing where it reads better than addressing the reader directly ("Die Datei wurde gespeichert" over "Du hast die Datei gespeichert").

## Quotation marks
- Use German quotes „ … “ (low-high, `„` … `“`), not English "…". Nested: ‚ … ‘.
- Names of UI elements and buttons get German quotes; established English product names (Safari, GitHub) usually do not.

## Punctuation & spacing
- Non-breaking space between number and unit (`3 %`, `2 GB`, `5 km`) and inside abbreviations (`z. B.`, `u. a.`).
- An ellipsis `…` (real character, preceded by a non-breaking space) signals an ongoing process or a follow-up dialog.
- Compound nouns are closed (`Servereinstellungen`); compounds with a product name take a hyphen (`Mail-Einstellungen`).

## Numbers & dates
- Decimal **comma**, thousands **point** or non-breaking space: `1.234,50 €`, `1 000 000`. Version numbers keep the point (`iOS 17.2`). Never touch numbers inside `%`-placeholders.
- Dates: `14. Juni 2026` or `14.06.2026`. Months and weekdays are nouns (capitalized).

## Capitalization & terminology
- **All nouns are capitalized** – the most common error in machine output. Headings are sentence case otherwise.
- Common web terms: `Beitrag`/`Artikel` (post), `Abonnieren` (subscribe), `Newsletter` (kept), `Datenschutz` (privacy), `Impressum` (imprint). Keep "Newsletter", "Blog", "Podcast" as loanwords – they are idiomatic.

## Inclusive language
- The gender colon (`Benutzer:in`, `Entwickler:innen`) is widely used; prefer neutral terms (`Person`, `Studierende`, `Team`) or plurals where they read more cleanly. Don't overload a sentence with split forms.

## Common pitfalls
- Don't add a genitive `-s` to product names (`die Funktion von iOS`, not `iOS's Funktion`).
- "aktuell" means *current*, not *actual* (which is `eigentlich`/`tatsächlich`). "eventuell" means *possibly*, not *eventually*.
