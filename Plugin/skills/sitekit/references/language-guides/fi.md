# Finnish (fi) – Web Content Style Guide

Read `principles.md` first. Finnish-specific rules for SiteKit content.

## Address & formality
- Informal **"sinä"** (and the implied second person) is the norm for most modern, indie, and product sites. Formal **"te"** is for institutional or official tone. Finnish also leans on impersonal and passive constructions (`voit tehdä` → `voidaan tehdä`) to avoid addressing the reader directly. Pick a register and keep it.

## Quotation marks
- Use ” … ” (right-high on both sides), the same shape as Swedish. Nested quotes use ’ … ’.

## Punctuation & spacing
- No space before `: ; ! ?`. Finnish has no articles and no grammatical gender, so don't invent them when translating from English.

## Numbers & dates
- Decimal **comma**, thousands **non-breaking space**: `1 234,50 €` (currency after, with a space). Don't reformat numbers inside placeholders.
- Dates: `14.6.2026` (day.month.year, with periods) or `14. kesäkuuta 2026` – **months lowercase**.

## Capitalization & terminology
- **Sentence case** for headings; do not capitalize months, weekdays, languages, or nationalities (`suomi`, `maanantai`, `kesäkuu`).
- Common web terms: `artikkeli`/`kirjoitus` (post), `tilaa` (subscribe), kept `uutiskirje`/`newsletter`, `tietosuoja` (privacy).

## Common pitfalls
- Finnish is **agglutinative**: grammatical roles are suffixes/cases, not prepositions – do not translate English preposition-by-preposition; let the case carry the meaning.
- Compounds are written **closed** (`käyttäjänimi`, `tietosuojakäytäntö`); splitting them is a common, meaning-changing error.
- Word order is flexible but the partitive/case system is not – machine output often picks the wrong case; have a native check key UI labels.
