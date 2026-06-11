---
id: a1b2c3d4
title: "Building a static site generator in Swift"
date: 2026-03-15
tags: [swift, web]
summary: "Why the build pipeline is a sequence of swappable plugins, and what that buys you."
---

Most static site generators assume a human writes every template by hand. SiteKit takes a different bet: the generator itself is a sequence of well-named phases, and each phase is one swappable plugin.

## The pipeline

Every build walks the same fixed sequence – discovery, loading, enrichment, rendering, output processing. To add behaviour you conform to the phase's protocol and register your plugin on the SiteBuilder. Nothing else has to change.

A custom renderer is small. It declares which pages it owns and returns fully assembled HTML:

```swift
struct RecipePage: Page {
   func pages(in context: BuildContext) -> [PageModel] {
      context.sections.first { $0.config.slug == "recipes" }?.pages ?? []
   }

   func renderHTML(_ page: PageModel, context: BuildContext) -> String {
      PageShell.wrap(content: "<h1>\(page.title)</h1>", page: page, context: context)
   }
}
```

> The best developer tools disappear into the workflow – you think about your content, not your tooling.

The pieces worth remembering:

- Phases are strictly ordered; plugins inside a phase are not.
- The build context is read-only – plugins compose, they don't mutate shared state.
- Presets pre-compose a sensible plugin list so most sites never touch the pipeline.
