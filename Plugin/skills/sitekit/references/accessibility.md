---
name: accessibility
description: "Audit a SiteKit site for WCAG AA accessibility. Checks images, contrast, keyboard nav, focus styles, and semantic HTML."
---

# Accessibility Audit

## When to Use
Run this after building your site, before deploying. Also run after major design changes.

> **This audit is the accessibility path – `swift run Site validate` does not check a11y** (it only reports missing translations). Accessibility is verified by running the steps below, not by the build.

## What SiteKit gives you (and what you still must check)

SiteKit ships these as built-in defaults – but they are *defaults that work*, not *enforcement that rejects bad input*:

- **WCAG AA color contrast** – the 15 shipped color schemes (and 4 presets) are **hand-tuned and pre-validated** to pass WCAG AA for body text in light and dark mode. There is **no build-time contrast check**: if you override `colorTextMuted`/`colorTextSecondary`/`colorBg`/`colorAccent` under `theme.tokens`, nothing rejects a sub-AA combination – you own verifying it (Step 2).
- **Semantic landmarks** – `PageShell` emits a skip-link (`.sk-skip-link`), `<header role="banner">`, `<nav aria-label>`, a `#main-content` wrapper, `<footer role="contentinfo">`, and `<html lang="…">` on every page.
- **Keyboard-navigable theme JS** – the shipped search, theme-toggle, and language-picker controls are real `<button>`s with `aria-label`s and visible focus styles.
- **Alt text from frontmatter** – hero images use `image:` + `imageAlt:`; add `imageAlt` to `MarkdownLoader.requiredFields` to fail the build when it's missing (see content-writing.md).

The steps below are what an AI/human still verifies – especially for custom theme CSS/JS and any overridden tokens, which SiteKit cannot guarantee.

## Step 1: Image Alt Text Audit
- Search all markdown files for images: `![`
- Verify every image has meaningful alt text (not empty, not "image", not filename)
- For decorative images: alt="" is correct
- Check hero images in frontmatter: `image:` should have corresponding `imageAlt:`

## Step 2: Color Contrast Check
- SiteKit's built-in presets and color schemes are tuned to pass WCAG AA for `colorTextMuted`/`colorTextSecondary` on both light and dark backgrounds. If the site only uses built-ins, contrast is already handled.
- If the site **overrides** `colorTextMuted`, `colorTextSecondary`, or `colorBg` under `theme.tokens`, check the contrast ratio of every muted/secondary color vs every bg variant (≥4.5:1 for normal text).
- Look up accent color from the scheme and check contrast vs background (accent links should be ≥4.5:1 in content text, ≥3:1 as decorative affordance).
- Check dark mode contrast too – users set `data-theme="dark"` via the theme toggle.
- Flag any custom token overrides with low contrast. Suggest darker alternatives (e.g., stone-500 `#78716c` instead of stone-400 `#a8a29e` on light ivory backgrounds).

### Computing contrast ratios

```python
def rel_lum(hex_color):
    h = hex_color.lstrip('#')
    r,g,b = [int(h[i:i+2],16)/255 for i in (0,2,4)]
    def c(v): return v/12.92 if v<=0.03928 else ((v+0.055)/1.055)**2.4
    return 0.2126*c(r) + 0.7152*c(g) + 0.0722*c(b)

def contrast(fg, bg):
    l1, l2 = rel_lum(fg), rel_lum(bg)
    return (max(l1,l2) + 0.05) / (min(l1,l2) + 0.05)
# WCAG AA: normal text ≥ 4.5, large text ≥ 3.0
```

## Step 3: Keyboard Navigation
- Verify skip-link exists (SiteKit's base.css includes .sk-skip-link)
- Check that all interactive elements (links, buttons) have visible focus styles
- Verify the search modal can be opened and closed via keyboard (Cmd+K, Escape)
- Check that the theme toggle is keyboard-accessible

## Step 4: Semantic HTML
- Verify heading hierarchy (h1 -> h2 -> h3, no skips)
- Check that nav elements use <nav> with aria-label
- Verify main content uses <main>
- Check forms have labels

## Step 5: Report
Generate a summary: passed / warning / failed for each check.

## Not covered automatically

SiteKit's defaults handle the structural basics, but these still need human/AI judgement and are out of scope for any automated check:

- Custom `Theme/` CSS or JS that introduces its own contrast, focus, or motion issues.
- Overridden color tokens that drift below AA (the build won't catch it).
- Meaningfulness of `alt` text (the build can require it present, not require it *good*).
- Cognitive accessibility, reading level, motion sensitivity, and a real screen-reader walkthrough – recommend manual testing for these.

## See also

- `themes.md` – color tokens, the 15 schemes, and authoring/overriding them.
- `performance.md` – the sibling quality-invariant guide (PageSpeed findings).
- `content-writing.md` – `image:`/`imageAlt:` frontmatter and `requiredFields`.
