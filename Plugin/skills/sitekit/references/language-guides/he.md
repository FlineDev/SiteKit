# Hebrew (he) – Web Content Style Guide

Read `principles.md` first. Modern Hebrew rules for SiteKit content. Apple's Xcode 26+ Hebrew guide is the authoritative app-string complement.

## Direction (critical for the web)
- Hebrew is **right-to-left**. SiteKit sets `<html lang="he">` but does **not** auto-apply `dir="rtl"`. Add `dir="rtl"` and use CSS logical properties (`margin-inline-start`, `text-align: start`) in your `Theme/` so the layout mirrors. Test the rendered page.
- Latin terms, code, and numbers stay left-to-right within the RTL flow; correct markup lets the browser's bidi algorithm handle the mix.

## Tone & register
- Modern Hebrew is fairly direct and informal online; address the reader in second person naturally. Gender matters – Hebrew verbs and adjectives inflect for gender. When the reader's gender is unknown, prefer neutral phrasing, plural, or infinitive constructions rather than defaulting to masculine throughout.

## Script & orthography
- Body text is normally written **without niqqud** (vowel points). Use full spelling (ktiv male) as standard online.
- Final letter forms (ך ם ן ף ץ) are handled by the text engine; write correctly.

## Numbers & dates
- Western Arabic numerals (1, 2, 3), left-to-right, are standard. Dates: `14 ביוני 2026` (Gregorian, common in tech).

## Terminology
- Many tech terms are borrowed; keep widely-understood loanwords, and keep brand/product names in Latin script unless an official Hebrew name exists.

## Common pitfalls
- As with Arabic, the #1 failure is **layout, not translation** – RTL text in an LTR layout. Fix `dir`/CSS first.
- Don't mirror code, paths, or URLs. Punctuation glyphs stay standard; the bidi algorithm positions them.
