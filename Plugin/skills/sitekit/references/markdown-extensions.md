# SiteKit Markdown Extensions (DocC-compatible directives)

SiteKit's documentation design (the `.docc()` blueprint) understands a small set of **optional Markdown extensions** – block directives written as `@Name { … }`. They are **inspired by and compatible with Apple's Swift-DocC** directive syntax, so two audiences are served by one feature:

- **DocC catalog authors** get drop-in rendering. An existing `.docc` catalog – `@Metadata`, `@Row`/`@Column`, `@TabNavigator`, `@Image`, `@Links`, and friends – renders to static HTML with no changes.
- **Plain-Markdown authors** can opt into the same power-ups when they want a tab group, a multi-column row, or an inline video, without adopting the rest of DocC.

These extensions are **purely additive**. Plain Markdown without any directive renders exactly as normal Markdown. A pure-Markdown author never encounters a directive they did not write, and an unused or unknown directive never breaks a page (see the contract below). The directives are a documentation-design feature, not a WWDC-only feature – they work for any docs site built on the `.docc()` blueprint.

> Scope: this reference documents the **body and metadata directives** the DocC design ships today. It does not cover upcoming configuration (navigation modes, a contributors opt-in flag) – those are documented when they land.

---

## The graceful-degradation contract (the v1 guarantee)

The directive renderer makes one hard promise, so a catalog can never render broken directive syntax to a reader:

1. **A known directive renders its styled component** (a row, a tab group, a figure, a video, …).
2. **An unknown or not-yet-styled directive degrades to its readable inner content** – the wrapper is dropped, the inner blocks render normally, and the raw `@Name` is **never** emitted to the page.
3. **An arg-only directive that carries no inner content** (e.g. a future `@Video(source:)` whose source cannot be resolved) **falls back to a link** to its `url:` or `source:` argument, so the content is never silently lost – a vanished video is worse than an unstyled link.
4. **Nested unknown directives also degrade** – degradation recurses, so a known directive containing an unknown child still renders the child's content.
5. **A directive never throws.** Every note in a catalog renders, even one using a directive this renderer does not specifically handle.

One parser detail makes this safe: Swift-style attributes such as `@State` inside a fenced `swift` code block live in a code-block node, never a block-directive node, so code examples are passed through untouched – only real block directives reach the renderer.

---

## DocC compatibility

The directives use the same grammar Swift-DocC uses (parsed by swift-markdown's block-directive parser). The practical promise:

- An existing `.docc` catalog works **without changes** – drop it into the `.docc()` blueprint's content directory and build.
- Directive names, argument labels, and nesting match DocC's, so content authored for DocC's own renderer renders here too.
- Where SiteKit does not yet style a DocC directive, the graceful-degradation contract keeps its content readable rather than failing the build.

---

## Directive reference

Each directive below lists what it does, a short real example, and the one-line rendered result.

### `@Metadata`

A container placed near the top of a note that carries page-level metadata. It renders **no body HTML of its own** – its sub-directives populate page chrome (the title eyebrow, the call-to-action button, contributor avatars, the navigation glyph, the framework icon).

```markdown
@Metadata {
   @TitleHeading("WWDC25")
   @PageKind(article)
   @CallToAction(url: "https://developer.apple.com/videos/play/wwdc2025/101", label: "Watch the video (14 min)")
   @PageImage(purpose: icon, source: "WWDC25")
   @Contributors {
      @GitHubUser(Jeehut)
   }
}
```

→ The block itself emits nothing inline; it configures the page's heading area, CTA button, contributor list, and sidebar/year glyph.

Sub-directives of `@Metadata`:

| Sub-directive | Example | What it does |
|---|---|---|
| `@TitleHeading` | `@TitleHeading("WWDC25")` | Sets the small eyebrow/kicker line shown above the page title. |
| `@PageKind` | `@PageKind(article)` | Marks the page kind. `@PageKind(article)` flags a guide/content page – such pages are explicitly excluded from "stub" detection even when their body is short. |
| `@CallToAction` | `@CallToAction(url: "https://…", label: "Watch the video (14 min)")` | Renders a primary call-to-action button. A trailing `(N min)` in the label is also lifted into the page's reading-time so listing pages can show it. |
| `@Contributors` | `@Contributors { @GitHubUser(Jeehut) }` | Lists contributors via one `@GitHubUser(handle)` child each. Placeholder handles containing `<`, `>`, or whitespace (e.g. the template stub `<replace this…>`) are rejected. |
| `@PageImage` | `@PageImage(purpose: icon, source: "WWDC25")` | Declares a glyph image for a year-overview page. The bare `source` name resolves to `/assets/<name>.<ext>` for the sidebar/year visual. |
| `@CustomAttribute` | `@CustomAttribute(name: "framework", value: "swiftui")` | Declares the note's framework key for the sidebar icon, without a non-standard syntax. Equivalent lightweight form: an HTML comment `<!-- framework: swiftui -->` anywhere in the note. |

### `@Row` and `@Column`

A flexible multi-column layout. `numberOfColumns:` on the row is a sizing hint; a `size:` weight on a column sets its relative width (a `size: 2` column next to a `size: 1` column renders ~2:1). Columns wrap and stack on narrow viewports.

```markdown
@Row(numberOfColumns: 2) {
   @Column(size: 2) {
      The main column, twice as wide.
   }
   @Column {
      A narrower sidebar column.
   }
}
```

→ `<div class="sk-docc-row" data-columns="2">` containing `<div class="sk-docc-column">` children; a `size:` becomes an inline `flex-grow`.

### `@TabNavigator`

An interactive, **no-JavaScript** tab group. Each `@Tab("Label")` child becomes one tab; the first is selected by default. Tabs are keyboard-operable (native radio inputs) and the selected panel is revealed purely via CSS.

```markdown
@TabNavigator {
   @Tab("Declarative") {
      SwiftUI example here.
   }
   @Tab("Imperative") {
      UIKit example here.
   }
}
```

→ A `<div class="sk-docc-tabs">` with a tab bar and panels; only the checked tab's panel is shown, no script required.

### `@Video`

A real inline video player matching DocC. The `source:` resolves against the catalog (or passes through for absolute paths and full URLs); an optional `poster:` is resolved as an image. When the source cannot be resolved to a usable URL, it degrades to a link rather than emitting a broken `<video>`.

```markdown
@Video(source: "demo.mp4", poster: "demo-poster")
```

→ `<figure class="sk-docc-video">` wrapping `<video autoplay loop muted playsinline>` with a typed `<source>` (`.mp4`/`.mov`).

### `@Image`

A figure image. `source:` is required; `alt:` supplies alt text. Bare names (no leading slash, no scheme) resolve against the catalog's `Images/` directory, the note's own directory, and the per-note sibling subfolder.

```markdown
@Image(source: "architecture-diagram", alt: "The build pipeline's six phases")
```

→ `<figure class="sk-docc-image"><img src="/assets/architecture-diagram.svg" alt="…" loading="lazy" /></figure>`. A malformed `@Image` with no `source` degrades to its inner content rather than emitting a broken tag.

### `@Small`

Wraps ancillary content (legal notices, attribution footnotes) in a visually de-emphasized block. The inner content renders normally.

```markdown
@Small {
   Not affiliated with Apple Inc. Trademarks belong to their respective owners.
}
```

→ `<div class="sk-docc-small">…</div>` (reduced size, muted color via CSS).

### `@Links`

Curates a list of `<doc:…>` cross-references into a named group inside a `## Topics` section. Each `### Heading` under `## Topics`, followed by a `@Links` block of `<doc:…>` items, becomes one sidebar subgroup / grouped listing.

```markdown
## Topics

### Essentials

@Links(visualStyle: list) {
   - <doc:GettingStarted>
   - <doc:Configuration>
}
```

→ SiteKit reads the `<doc:…>` targets and groups those pages under the heading title. The `visualStyle:` argument is accepted for DocC compatibility; SiteKit groups by the `<doc:>` targets it finds. A plain Markdown list of `<doc:…>` autolinks under a `### Heading` (no `@Links` wrapper) is also accepted, for the lightest possible curation.

### `@Comment`

An authoring note that is **never rendered**. Use it for TODOs or generator markers that should not reach the page.

```markdown
@Comment {
   TODO: expand once the session recording is published.
}
```

→ Emits nothing at all.

---

## Related: blockquote-based asides

The docs design also recognizes two DocC-compatible **blockquote** conventions. These are not `@`-directives, but they are part of the same Markdown vocabulary and degrade to plain blockquotes when unrecognized.

**Callouts** – a blockquote whose first line begins with one of five recognized kinds (case-insensitive, optional `**bold**` wrapping): `Tip:`, `Note:`, `Important:`, `Warning:`, `Experiment:`. The colon is required.

```markdown
> Tip: Enable dark mode in Settings to reduce eye strain at night.
```

→ `<div class="sk-docc-callout sk-docc-callout--tip">` with a localized badge label and the body. Any blockquote that does not start with a recognized kind renders as a normal `<blockquote>`.

**Quick Read** – a blockquote whose first paragraph starts with `Quick Read` (e.g. `> **Quick Read** (AI): …`) is rendered as a TLDR summary card. A bullet list of in-page anchor links inside it is promoted to a row of jump pills.

```markdown
> **Quick Read** (AI): A one-paragraph summary of the note.
>
> - [Overview](#overview)
> - [Details](#details)
```

→ `<aside class="sk-docc-quickread sk-docc-tldr" id="quick-read">` with the summary and anchor jump pills.

---

## Cross-references: `<doc:Identifier>`

Inside a `.docc()` site, a `<doc:OtherNote>` autolink resolves to the other note's internal URL under the catalog's URL prefix (default `documentation`). This is the standard DocC cross-reference syntax, resolved at build time, and is what `@Links` and the `## Topics` plain-list form collect when grouping pages.

---

## Where this is implemented (source pointers)

For contributors verifying or extending this set:

- **Body directives** (`@Image`, `@Row`/`@Column`, `@TabNavigator`/`@Tab`, `@Video`, `@Small`, `@Comment`, plus the degradation default): `Sources/SiteKit/Plugins/DocCDirectiveRenderer.swift`.
- **`@Metadata` and its sub-directives** (`@TitleHeading`, `@PageKind`, `@CallToAction`, `@Contributors`/`@GitHubUser`, `@PageImage`, `@CustomAttribute`), plus the `## Topics` parsing: `Sources/SiteKit/Plugins/DocCLoader.swift`.
- **`@Links` / `## Topics` grouping into the navigation tree**: `Sources/SiteKit/Plugins/DocCNavigationTree.swift`.
- **Callouts and Quick Read**: `Sources/SiteKit/Plugins/DocCCalloutRenderer.swift`, `Sources/SiteKit/Plugins/DocCQuickReadRenderer.swift`.

## See also

- `../../../blueprints/DocC.md` – the DocC blueprint (when to choose it, the catalog layout, the `/search/` page, `## Topics` curation).
- `siteconfig-reference.md` – the `docc:` configuration block.
- `architecture.md` – the `.docc()` plugin stack (discovery → loader → renderers).
</content>
</invoke>
