# Troubleshooting – Build & Runtime Errors

Common build, runtime, and deploy errors with the file that produces them and the fix. SiteKit prefers fail-fast errors over silent fallbacks, so most issues print a precise file/line in the build log.

For PageSpeed-specific findings, see `references/performance.md`. For deployment-host errors (Cloudflare, GitHub Pages, etc.) see `references/deployment/SKILL.md`.

## Build errors

### 1. `required frontmatter field 'X' is missing or empty`

```
Error: /Content/Blog/2026-01-01-test.md:2: required frontmatter field 'date' is missing or empty
```

Thrown by `MarkdownLoader` when a required field is absent or has an empty value. The defaults are `["title", "date"]`; podcast factories also require `audioURL` and `duration`.

**Fix:** add the missing field to the frontmatter. For `date:`, the filename convention `YYYY-MM-DD-slug.md` also satisfies the requirement. To relax the rule for one site, pass `requiredFields:` to `MarkdownLoader`:

```swift
SiteBuilder.blog(config: config, projectDirectory: dir)
   .articleLoader(MarkdownLoader(requiredFields: ["title"]))
```

### 2. YAML parse / decode error in `SiteConfig.yaml` / `theme.yaml` / `ImageManifest.yaml`

The build fails at load time when one of these files is not valid YAML or is missing a required key (`SiteConfig.load` surfaces a `SiteConfigError.invalidYAML`; the theme and manifest loaders fail similarly). Most common causes:

- Tab characters instead of spaces (YAML disallows tabs for indentation).
- Special characters (`:`, `#`, `'`, `"`, `&`, `*`) in unquoted strings.
- Inconsistent indentation between siblings of the same key.

**Fix:** run the file through any YAML linter (`yamllint`, an editor extension, or `python -c "import yaml; yaml.safe_load(open('SiteConfig.yaml'))"`). Quote values that contain special characters.

### 3. Malformed frontmatter / missing `---` delimiters

A Markdown file fails to load when its frontmatter block is malformed – a missing opening `---`, a missing closing `---`, or invalid YAML between them (`FrontmatterParser`). The frontmatter must be the first thing in the file, with no blank line before it.

**Fix:** ensure the file starts with:

```markdown
---
title: My Post
date: 2026-01-01
---

Body content here.
```

### 4. `invalid date format`

```
Invalid date format: 2026/01/01
```

`MarkdownLoader` accepts **only `YYYY-MM-DD`** (ISO-8601 full-date). Other separators (`/`, `.`), full date-time timestamps, or locale-specific orderings (`01-01-2026`) are rejected.

**Fix:** use `YYYY-MM-DD` in frontmatter, or rely on the filename convention (`2026-01-01-slug.md`).

### 5. Content / section directory issues

Two distinct things happen here – neither is a hard `contentDirectoryNotFound` crash:

- **Missing required config keys.** `contentDirectory` and `outputDirectory` are **required** in `SiteConfig.yaml` (the decoder uses non-optional decode – see siteconfig-reference.md). Omitting either fails YAML decoding at load time, not with a "directory not found" message.
- **A declared section's directory doesn't exist.** The build does **not** fail – it logs `Section directory '<dir>' not found, skipping` and continues, so that section simply produces no pages.

**Fix:** keep `contentDirectory: "Content"` + `outputDirectory: "_Site"` present in `SiteConfig.yaml`, and make sure each `sections[].contentDirectory` exists under `Content/`. The build runs with `projectDirectory` = the directory containing `Package.swift`; relative paths resolve against that. If a section is silently empty, check that its folder name matches `sections[].contentDirectory` exactly (case-sensitive on Linux/CI).

### 6. Wrong `preset:` in `theme.yaml` (preset vs. layout confusion)

The most common theme mistake is putting a **layout** name in the `preset:` field. They are different things:

- **Presets** (`theme.yaml` `preset:`) are token bundles: **`default`, `warm`, `minimal`, `bold`** (`TokenCSSGenerator.availablePresets`). An unrecognized name simply contributes no preset tokens – your theme falls back to layout defaults + whatever `colorScheme`/`fontPairing`/`tokens` you set, which usually looks "unstyled" or off.
- **Layouts** (`Classic`, `Sidebar`, `Minimal`) are the CSS/JS templates under `Plugin/themes/templates/<Name>/`. You select a layout by **copying its files into `<site>/Theme/`** (referenced via `css:` / `js:`), **not** via `preset:`.

**Fix:** in `theme.yaml`, set `preset:` to one of `default` / `warm` / `minimal` / `bold` (or omit it and define tokens directly). To switch layout, copy a different template from `Plugin/themes/templates/` into your `Theme/`. See themes.md for both catalogs.

### 7. PageShell call with missing parameter

```
error: missing argument for parameter 'context' in call
```

Swift compile error when a custom `Page.renderHTML(_:context:)` calls `PageShell.wrap(...)` but forgets an argument. `PageShell.wrap(content:page:context:)` takes three required arguments (plus optional `head:`, `bodyClass:`, `dataAttributes:`, `chrome:`).

**Fix:** the canonical call is:

```swift
return PageShell.wrap(content: bodyHTML, page: page, context: context)
```

The optional parameters default to "derive from the page": `head:` and `bodyClass:` REPLACE the derived `<head>` / body class when set (see `custom-pages.md`), `dataAttributes:` adds `data-*` attributes, and `chrome: .appShell` suppresses the generic site header/footer for self-contained layouts.

### 8. Image conversion fails / image variant skipped

```
[SiteKit] No image resize tool found on PATH (tried `magick`, `convert`). Install imagemagick to enable responsive image generation. Skipping.
```

`ImageResizer` (Phase 6 `OutputProcessor`) generates responsive variants with **ImageMagick** – `magick` (v7) or `convert` (v6). When neither is on `PATH`, the resizer logs the warning above and the site still builds, just shipping the un-resized source images.

**Fix:** install ImageMagick.

- macOS: `brew install imagemagick`.
- CI / Linux: `apt-get install -y imagemagick`.
- Verify with `which magick convert`. Add the install step to your deploy workflow so CI isn't shipping full-size images.

### 9. Multilingual content count mismatch / translation gap warnings

```
Translations: 3 missing
  [de] Blog/2026-01-01_Hello-World.md → Blog/2026-01-01_Hello-World.de.md
```

`swift run Site validate` flags missing translations like the above (and exits non-zero). During a normal build the pipeline instead logs per item `Missing translation: <expectedFile> (<locale>)`. SiteKit does not fail the build on missing translations – they ship as default-language pages with no hreflang alternates – but the validator reports the gap so authors can close it.

**Fix:** add the missing translations. If a post is intentionally English-only, no action needed; `HreflangEnricher` skips hreflang for partial translations.

### 10. URL routing surprise on multilingual sites

`context.router` returns a path with a locale prefix you didn't expect, or omits one you did.

`LocaleAwareURLRouter` (the default for multilingual sites) prefixes non-default locales with `/<locale>/…` and leaves the default locale unprefixed. The default locale comes from `SiteConfig.language` (preferred) or `defaultLanguage` (legacy).

**Fix:** call `context.router.pagePath(for:in:)` rather than concatenating strings. If you must build a URL by hand, branch on `context.uiStrings.locale == context.config.effectiveDefaultLanguage`.

### 11. `snippetPath` / `snippetsListingPath` deprecation warning

```
warning: 'snippetPath(for:)' is deprecated: use 'pagePath(for:in:)' with the snippets SectionConfig
```

`URLRouter` no longer hardcodes a "snippets" section. The old methods remain as deprecated extensions on the default routers for back-compat.

**Fix:** pass the snippets `SectionConfig` to the section-aware API:

```swift
let snippets = config.effectiveSections.first { $0.slug == "snippets" }!
let path = router.pagePath(for: page, in: snippets)
```

### 12. SPM resolve fails on the SiteKit dependency

```
error: package 'sitekit' could not be resolved
```

After v1.0, the package URL is `https://github.com/FlineDev/SiteKit.git` (formerly `SiteKit-Package.git`).

**Fix:** update `Package.swift` to pin a released version:

```swift
.package(url: "https://github.com/FlineDev/SiteKit.git", from: "1.0.0")
```

Then `swift package update`. The old `SiteKit-Package` repo redirects (archived until the next minor release) but the dependency URL in `Package.swift` must point at the new host.

## Deploy failures

### 13. Cloudflare Pages: build succeeded, page 404s

Check, in order:

- Does `_Site/<expected-path>/index.html` exist? If not, the renderer never wrote it – re-check `pages(in:)` or the section configuration.
- Does `_Site/_headers` accidentally redirect the path? `CloudflareHeadersRenderer` shouldn't generate redirects, but a `_redirects` file from `CloudflareRedirectsRenderer` might.
- Is `SiteConfig.baseURL` correct for the deployed site? A wrong baseURL breaks canonical URLs but should not 404; if 404s only happen on certain paths, baseURL is unlikely to be the cause.

### 14. GitHub Pages: assets not loading (404 on `/assets/...`)

Usually a `baseURL` or path-prefix mismatch. GitHub Pages serves user/org pages at the apex and project pages at `<user>.github.io/<repo>/`. If the project is at a subpath, `baseURL` in `SiteConfig.yaml` must end with the subpath and renderers must produce URLs relative to it.

**Fix:** set `baseURL: https://<user>.github.io/<repo>` (no trailing slash) in `SiteConfig.yaml`, or move the project to a custom domain at the apex.

### 15. Newsletter not sending

The Keila + SES path is documented in `references/newsletter-setup.md`. Common issues:

- SES still in sandbox mode (can only send to verified addresses).
- DKIM not propagated yet (DNS TTL).
- Keila API token missing or expired – regenerate from Keila admin.

## Common logic issues

### 16. Hreflang missing on a translated page

`HreflangEnricher` is registered automatically by the multilingual factory presets (`.blog(...)`, `.podcast(...)`, etc.). If it's not in the enricher chain, hreflang is empty.

**Fix:** the multilingual factory presets register it for you – if you use `SiteBuilder.blog(...)` / `.podcast(...)` / etc. on a multilingual site it is already in the chain. If you constructed `BuildPipeline` manually, add `HreflangEnricher()` to the enricher list explicitly.

### 17. Promotion slots render empty

`PromotionEnricher` writes the selected promotion into `Page.extensions["promotion"]`. If the slot is empty, either no matching promotion exists in `SiteConfig.promotions`, or the enricher isn't registered.

**Fix:** verify `PromotionEnricher` is in the chain (default for `.blog(...)`) and that `SiteConfig.promotions` has at least one entry whose `audience:` matches the page.

### 18. `TranslationStatus` reports gaps that aren't real

`TranslationStatus.check` takes a `sections:` argument and walks each section's `contentDirectory`. If a section uses a non-default `contentDirectory` (anything other than `"Blog"`, `"Snippets"`, or `"Pages"`), the check needs the explicit `sections: config.effectiveSections` parameter.

**Fix:** if you call `TranslationStatus.check` directly (not via `SiteBuilder`), pass `sections: config.effectiveSections`. The builder does this for you.

## Getting help

If none of the above matches, open an issue at [github.com/FlineDev/SiteKit/issues](https://github.com/FlineDev/SiteKit/issues) with:

- The SiteKit version (the `from:`/`branch:` in your `Package.swift` dependency line).
- Your Swift toolchain (`swift --version` – SiteKit requires ≥ 6.2).
- The exact command and the full error output (file path + line, when present).
- A minimal reproduction if you can – the smallest `SiteConfig.yaml` + one content file that triggers it.

## See also

- `siteconfig-reference.md` – required vs. optional `SiteConfig.yaml` keys.
- `content-writing.md` – frontmatter fields and the `requiredFields` contract.
- `localization.md` – multilingual config and translation status.
- `themes.md` – presets vs. layouts, tokens, and the image pipeline.
- `performance.md` – PageSpeed findings; `deployment/SKILL.md` – host/CI errors.
