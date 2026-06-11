# Layout Protocol

SiteKit does not have a Swift `Layout` or `SiteLayout` protocol.

Layouts today are pre-built CSS/JS template directories under:

```text
Plugin/themes/templates/
├── Classic/
├── Minimal/
└── Sidebar/
```

Each template contains `theme.css` and `theme.js`. A site's `Theme/theme.yaml`
selects a layout template and applies token overrides. The Swift rendering layer
still emits semantic HTML through page renderers and `PageShell`; layouts change
presentation through CSS, JavaScript, and theme tokens rather than through Swift
types.

## Historical Note

Early SiteKit planning explored a Swift layout protocol for replacing page HTML
structure. That direction was not implemented.

The current decision is to keep layout customization in the theme system. CSS
tokens, template stylesheets, and `theme.css` cover the common layout needs:
sidebars, grids, spacing, typography, component styling, dark mode, and small
interactive behavior. A Swift protocol would add a larger API surface and make
every page-structure change a compatibility concern for external layout
implementations.

If a site needs a genuinely custom page structure, implement a custom `Page` or
`Renderer` and register it with `SiteBuilder`. Do not look for a layout protocol
in `Sources/`; it is not part of the shipped architecture.

## See Also

- `Plugin/themes/README.md`
- `Plugin/themes/templates/Classic/`
- `Plugin/themes/templates/Minimal/`
- `Plugin/themes/templates/Sidebar/`
- `Plugin/skills/sitekit/references/themes.md`
- `Plugin/skills/sitekit/references/custom-pages.md`
