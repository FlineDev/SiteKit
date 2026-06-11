# SiteKit Theme Templates

Theme templates are **CSS scaffolds** – starting points for your site's visual design. They are not frameworks or runtime dependencies. Every starter blueprint ships with a template already copied into its `Theme/css/theme.css`, so `sitekit new` gives you a working layout out of the box. From that point on, **you own the file** and can customize it however you like.

## Picking a Template

To switch layouts (or to build a theme without a blueprint), copy the template's CSS from `Plugin/themes/templates/<Name>/` into your site's `Theme/css/` and reference it from `Theme/theme.yaml`. The template provides structural CSS for that layout – positioning, spacing, navigation, footer – while leaving colors, fonts, and content-specific styles to your theme tokens and custom CSS.

## Available Templates

| Template | Layout | Best For |
|----------|--------|----------|
| `Classic` | Sticky header, horizontal nav, three-section footer | Blogs, documentation, editorial sites |
| `Sidebar` | Persistent left sidebar nav, content column to the right | Docs, knowledge bases, reference sites |
| `Minimal` | Stripped-back chrome, generous whitespace, single-column focus | Landing pages, portfolios, link-in-bio sites |

Each template lives in its own directory under `themes/templates/<Name>/` and ships a `theme.css` (structural styles) plus a `theme.js` (theme toggle, language picker, search, mobile nav). The per-site `Theme/theme.yaml` selects one template and overrides tokens where needed.

## What Templates Include

Templates provide **structural CSS only**:

- Site header (sticky, backdrop blur)
- Navigation (flex layout, logo + nav items, mobile hamburger)
- Theme toggle button
- Language picker dropdown
- Search button
- Main content area (max-width, padding)
- Footer (left/center/right sections, social links)
- Static page layout
- Translation notice
- Draft preview banner
- Typography scale (h1–h4, paragraphs, blockquotes)
- Error page layout
- Dark mode structural overrides
- Responsive breakpoints (768px, 640px, 480px)

Templates do **not** include:

- CSS reset or base styles (provided by SiteKit's `base.css`)
- Color values or font declarations (provided by your `tokens.css` from `theme.yaml`)
- Blog listing or article card styles
- Code syntax highlighting
- Homepage-specific layouts
- Search modal/overlay
- App promotion or CMS-specific styles

## Customizing After Scaffolding

The template file lives at `Theme/css/theme.css` in your site. Common customizations:

1. **Adjust spacing** – Change padding/margin values to match your design
2. **Modify the header** – Switch from sticky to fixed, change blur amount, adjust height
3. **Restyle navigation** – Center vs. left-aligned, add icons, change active indicators
4. **Redesign the footer** – Add more columns, change the layout pattern
5. **Tune breakpoints** – Adjust the responsive thresholds for your content
6. **Add sections** – Article cards, listing grids, hero sections – whatever your site needs

All values reference CSS custom properties (`var(--token-name)`) defined in your `tokens.css`, so changing your theme colors or fonts in `theme.yaml` automatically flows through the template styles.

## Contributing a New Template

To add a new template:

1. Create a new directory `themes/templates/<Name>/` (PascalCase, e.g. `Dashboard/`) holding a `theme.css` (structural styles) and a `theme.js` (theme toggle, language picker, search, mobile nav)
2. Use only `sk-` prefixed class names for SiteKit structural elements
3. Reference CSS custom properties – never hardcode colors or font families
4. Include the standard comment header identifying it as a SiteKit theme template
5. Cover all responsive breakpoints (at minimum 768px and 480px)
6. Document what layout pattern the template targets in this README
