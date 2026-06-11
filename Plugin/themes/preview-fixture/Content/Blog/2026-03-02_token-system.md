---
id: b2c3d4e5
title: "A token system for themeable sites"
date: 2026-03-02
tags: [design, css]
summary: "Color schemes and font pairings cascade into one generated stylesheet."
---

Themes used to mean hand-rolled stylesheets. SiteKit treats theming as a small set of token vectors – colors, fonts, layout dimensions – that compose into a single `tokens.css` at build time.

Three layers compose:

1. The chosen color scheme provides resolved values for light and dark mode.
2. The chosen font pairing provides heading, sans, and mono families.
3. Per-site overrides win last.

The cascade is deterministic, the output is one tiny stylesheet, and the rules are visible in the theme.yaml.
