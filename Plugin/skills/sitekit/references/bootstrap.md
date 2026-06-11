---
name: bootstrap
description: "Install SiteKit and scaffold a user's first site using the `sitekit` CLI. Use at the very start of a new-site flow – it covers cloning SiteKit, running `sitekit doctor` / `sitekit new`, and updating an existing site with `sitekit update`. Hands off to `onboarding.md` for the judgment-heavy continuation."
---

# Bootstrap – Install SiteKit and Scaffold the First Site

This reference covers the **mechanical substrate** of starting a SiteKit site: getting SiteKit onto the machine and producing a clean scaffolded project. The `sitekit` CLI does the deterministic, judgment-free work; once a project exists, hand off to `onboarding.md` for the judgment-heavy continuation (blueprint reasoning, theme/font/image decisions, `SiteConfig.yaml` fill-in, context files).

Do not re-implement scaffold-copying logic in prose – that is exactly what the CLI exists to remove. Call `sitekit new`, then continue with `onboarding.md`.

## The two layers

- **The `sitekit` CLI** – a deterministic, scriptable substrate. It ships as an `executableTarget` inside SiteKit's own `Package.swift`, so it always matches the SiteKit version and blueprint set it was cloned with. Run it with `swift run sitekit <command>` from a SiteKit clone.
- **This skill (the judgment layer)** – calls the CLI for the mechanical steps, then does the work the CLI cannot: reasoning about which blueprint fits, theme/colour/font choices, content authoring, user-specific config.

## Step 1: Get SiteKit

"Easier than cloning the repo" means *no manual clone and no manual file copying* – a clone still happens, the bootstrap flow just automates it. Clone SiteKit so the `sitekit` CLI is available:

```bash
git clone https://github.com/FlineDev/SiteKit.git
cd SiteKit
```

`swift run sitekit …` builds-and-runs the CLI in one step – there is no separate install dance. (Installing the built binary globally via `swift build -c release` is allowed but is not required and not the canonical flow.)

## Step 2: `sitekit doctor`

Check the prerequisites before scaffolding anything:

```bash
swift run sitekit doctor
```

It checks `git`, `swift` (≥ 6.2, a hard requirement), and `gh` (optional – only a warning if missing). It prints a clear pass/fail report and exits non-zero when a hard prerequisite is missing. Fix anything marked `✗` before continuing.

## Step 3: Pick a blueprint

List what is available:

```bash
swift run sitekit blueprints
```

This prints the 9 starter blueprints with one-line descriptions. **Choosing between them is judgment work** – read `references/blueprints.md` for the decision guide and the per-blueprint question lists. Do not pick a blueprint mechanically; reason about the user's actual content and goals.

## Step 4: `sitekit new`

Scaffold the chosen blueprint into a fresh directory:

```bash
swift run sitekit new <site-name> --blueprint <Blueprint>
```

`--blueprint` defaults to `Blog` when omitted. The CLI copies the blueprint while excluding build / VCS / output cruft (`.build/`, `.git/`, `_Site/`, `.DS_Store`, `*.xcodeproj`, `.swiftpm/`), and refuses to scaffold into a non-empty directory. The result is a clean project directory ready for configuration.

**What you get** – the scaffolded layout (file contents come from the blueprint and the CLI, so they are not duplicated here):

```
<site-name>/
├── Package.swift            # executable target named "Site", depends on SiteKit
├── SiteConfig.yaml          # site config to fill in (full schema → siteconfig-reference.md)
├── .gitignore
├── Sources/Site/main.swift  # try SiteBuilder.<blueprint>(configPath: "SiteConfig.yaml").run()
├── Content/
│   ├── <section>/           # e.g. Blog/ – your Markdown posts
│   └── Pages/               # static pages (home.md, About.md, …)
├── Theme/
│   ├── theme.yaml           # layout template + colorScheme + fontPairing (full catalog → themes.md)
│   ├── css/
│   └── js/
├── .github/workflows/       # CI starter (deploy → deployment/SKILL.md)
└── _Site/                   # build output, gitignored
```

To build a site **without** a preset factory, replace the `main.swift` factory call with a hand-composed `SiteBuilder` (see `architecture.md` for the pipeline and `blueprints.md` for composing manually).

## Step 5: Hand off to onboarding

The mechanical scaffold is done. Continue with **`onboarding.md`** for everything that needs judgment: filling in `SiteConfig.yaml`, layout/colour/font selection, language setup, project context files (`CLAUDE.md` / `AGENTS.md`), the author-voice `Guidelines/` folder, the first build, and browser verification. `onboarding.md` Step 5 ("Project Scaffold") now points back at `sitekit new` instead of prose copy instructions – the rest of its steps are the judgment continuation.

## Updating an existing site: `sitekit update`

When a user already has a SiteKit site and wants to move to a newer SiteKit version, run `sitekit update` **from inside the site directory** – it reads `Package.swift` from the current working directory. The CLI binary lives in the SiteKit clone, so point `swift run` at it with `--package-path`:

```bash
cd <existing-site>
# bumps to the version this SiteKit clone ships:
swift run --package-path /path/to/SiteKit sitekit update
# or bump to a specific version:
swift run --package-path /path/to/SiteKit sitekit update --to 1.2.0
```

(If the `sitekit` binary has been installed globally – e.g. via `swift build -c release` and copied onto `PATH` – just run `sitekit update` directly from the site directory.)

`sitekit update` is deliberately limited: it detects the version-pinned SiteKit dependency in `Package.swift`, bumps it, runs `swift package update`, then points at `MIGRATION.md`. If the build then fails, it says so and stops.

**It does NOT auto-apply `MIGRATION.md` recipes.** When a bump introduces a breaking change, that is where judgment work resumes: read `MIGRATION.md`, apply the relevant find/replace recipes by hand, and rebuild. Auto-migration is explicitly out of scope for v1.0.

If the dependency is declared by `branch:` or a local `path:` rather than a released version, `sitekit update` cannot bump it – edit `Package.swift` by hand in that case.

## See also

- `onboarding.md` – the narrative continuation after scaffold: config fill-in, theme/font/colour, language, context files, first build, browser verification.
- `blueprints.md` – choosing a blueprint and composing a pipeline manually (non-factory).
- `siteconfig-reference.md` – the full `SiteConfig.yaml` field schema.
- `themes.md` – the full layout / colour-scheme / font-pairing catalog and `theme.yaml` tokens.
