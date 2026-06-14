# Working on this site

This website is built with **SiteKit** – a static site generator written in Swift, driven by AI agents. You (the AI assistant) do the work through SiteKit's skill; this file tells you when to load which part of it, so the guidance is always at hand while the site is live.

## Load the SiteKit skill first

The guidance lives in the `sitekit` agent skill. If it isn't already available in your environment, install it once – it works across Claude Code, Codex, Cursor, Windsurf, Xcode 26, and more:

```
npx skills add FlineDev/SiteKit
```

In Claude Code you can instead install the plugin: `/plugin marketplace add FlineDev/SiteKit` then `/plugin install sitekit@sitekit`.

## When to load which reference

Before you act, load the matching reference from the `sitekit` skill:

| The user wants to… | Load this reference |
|---|---|
| Write or edit a post or page | `content-writing` |
| Add or manage a language | `localization` |
| Add an imprint, privacy, or other legal page | `legal-pages` |
| Change colours, fonts, or layout | `themes` |
| Deploy, or fix a broken deploy | `deployment` |
| Improve SEO / metadata | `seo-aso` |
| Understand a build error or unexpected output | `troubleshooting` |
| Add a custom page type or output file (Swift) | the SiteKit `AGENTS.md` and `custom-pages` |

When in doubt, the skill's `SKILL.md` routes any task to the right reference.

## Everyday commands

```bash
swift run Site serve      # local preview at http://localhost:8080
swift run Site build      # build the static output into _Site/
swift run Site validate   # check translations on multilingual sites
```

Content lives in `Content/`, the look in `Theme/theme.yaml`, and site metadata in `SiteConfig.yaml`.
