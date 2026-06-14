# Japanese (ja) – Web Content Style Guide

Read `principles.md` first. Japanese-specific rules for SiteKit content. Apple's Xcode 26+ Japanese guide is the authoritative app-string complement.

## Tone & politeness
- Use **です・ます (polite/desu-masu)** for almost all website content – it is the neutral register for addressing readers. Plain form (だ・である) suits a deliberately casual personal blog or essay voice. Keep one register throughout a page.
- Japanese rarely uses an explicit "you" (あなた); phrase around it. Translate meaning and flow, not word order.

## Script & orthography
- Mix 漢字 / ひらがな / カタカナ naturally; don't over-convert to kanji. Loanwords and many product/tech terms go in カタカナ (`ブログ`, `ニュースレター`, `ダウンロード`).
- No spaces between words. Use spaces only around Latin-script terms for legibility where natural.

## Punctuation & special characters
- Use **full-width** punctuation: `。` (period), `、` (comma), `「…」` (quotes), `（…）` (parentheses). Nested quotes: `『…』`.
- Full-width `？` `！` are used in casual/marketing copy; formal prose often omits them.
- Use the middle dot `・` to separate items or transliterated foreign names.

## Numbers, dates & measurements
- Half-width digits for figures. Dates: `2026年6月14日`. Counters matter – use the right one (`3つ`, `5人`, `2件`).
- Currency: `¥1,200` or `1,200円`.

## Interface & terminology
- Quote UI labels with `「」`: 「次へ」をタップ. On iOS say タップ (tap); for desktop クリック (click).
- Keep terminology consistent; reuse established Apple-Japanese terms where the audience is Apple-platform developers.

## Common pitfalls
- Don't translate literally from English sentence structure – Japanese is topic-comment and verb-final; rewrite.
- Avoid excessive katakana English where a native word is clearer.
- Line breaks: avoid breaking a number from its counter or a foreign name from its `・`.
