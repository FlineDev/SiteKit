# Arabic (ar) – Web Content Style Guide

Read `principles.md` first. Modern Standard Arabic rules for SiteKit content. Apple's Xcode 26+ Arabic guide is the authoritative app-string complement.

## Direction (critical for the web)
- Arabic is **right-to-left**. SiteKit sets `<html lang="ar">` but does **not** auto-apply `dir="rtl"`. For an Arabic site you must add `dir="rtl"` and use CSS logical properties (`margin-inline-start`, `padding-inline-end`, `text-align: start`) in your `Theme/` so layout, icons, and alignment mirror correctly. Test the rendered page, not just the text.
- Latin-script terms, code, and numbers stay left-to-right within the RTL flow (the browser's bidi algorithm handles this if the markup is correct).

## Tone & register
- Use **Modern Standard Arabic (MSA / فُصحى)** for written web content – it is understood across all regions; avoid dialect unless the site is deliberately regional. Keep tone clear and respectful.
- Translate meaning and rhythm; Arabic prose structure differs from English – rewrite, don't transliterate the grammar.

## Script & orthography
- Render correct connected forms (the text engine handles shaping); write proper hamza, taa marbuta (ة), and alef variants. Diacritics (tashkeel) are normally omitted in body text except to disambiguate.

## Numbers & dates
- Either Western Arabic numerals (1, 2, 3) or Eastern Arabic-Indic (١, ٢, ٣) are used; Western digits are common and safe online. Be consistent.
- Dates commonly use the Gregorian calendar in tech contexts: `١٤ يونيو ٢٠٢٦` or with Western digits.

## Terminology
- Keep widely-understood loanwords where natural; provide an Arabic term on first use for clarity. Keep brand/product names in Latin script unless an official Arabic name exists.

## Common pitfalls
- The #1 failure is **layout, not translation**: shipping RTL text in an LTR layout. Fix the `dir`/CSS first.
- Don't mirror code, file paths, or URLs.
- Punctuation has Arabic forms: comma `،` and question mark `؟` (mirrored).
