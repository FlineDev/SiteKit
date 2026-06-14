# Simplified Chinese (zh-Hans) – Web Content Style Guide

Read `principles.md` first. Mainland-China Simplified Chinese rules for SiteKit content. Apple's Xcode 26+ zh-Hans guide is the authoritative app-string complement.

## Tone & address
- Neutral, clear, and concise. Address the reader with **您** for formal/business sites, **你** for casual/personal ones – pick one. Often the pronoun is dropped entirely; rephrase rather than forcing it.
- Translate meaning, not word order; Chinese is far more concise than English – cut filler.

## Script & spacing
- Simplified characters only (not Traditional – that is `zh-Hant`).
- **No spaces between Chinese characters.** Add a space between Chinese and inline Latin-script words/numbers for legibility (`使用 SiteKit 构建`), which is the common modern convention.

## Punctuation & special characters
- Use **full-width** punctuation: `。`(period) `，`(comma) `、`(list comma) `：` `；` `！` `？` `（…）`(parentheses) and quotes `“…”` / nested `‘…’`. Book/title marks: `《…》`.
- Do not use the half-width Latin `,` `.` between Chinese text.

## Numbers, dates & measurements
- Half-width Arabic digits for data. Dates: `2026年6月14日`. Large numbers may use 万/亿 in prose (`1.2 万`), but keep digits for precise data.
- Currency: `¥1,200` or `1200 元`.

## Interface & terminology
- Quote UI labels and keep terminology consistent across the site. Reuse established Apple-Chinese terms when the audience is Apple developers.
- Common web terms: `文章`/`博文` (post), `订阅` (subscribe), `通讯`/kept `Newsletter`, `隐私` (privacy).

## Common pitfalls
- Don't translate English idioms literally; find the idiomatic Chinese equivalent or drop the metaphor.
- Keep product/brand names in their original Latin form unless an official localized name exists.
- Watch full-width vs half-width: data and code stay half-width; sentence punctuation is full-width.
