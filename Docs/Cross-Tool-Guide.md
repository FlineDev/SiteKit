# Using SiteKit with Other AI Tools

SiteKit ships as a Claude Code plugin, but its agent-facing guidance follows the
open [Agent Skills](https://agentskills.io) shape. Any AI coding tool that can
read a `SKILL.md` file can use the same SiteKit instructions, blueprints, and
reference material.

The plugin lives inside the main SiteKit repository under `Plugin/`. There is
one consolidated skill:

```
Plugin/
├── .claude-plugin/plugin.json
├── skills/
│   └── sitekit/
│       ├── SKILL.md              ← Start here. Routes to references as needed.
│       └── references/           ← Task-specific reference material.
├── blueprints/
│   ├── INDEX.md
│   ├── AppLanding.md + AppLanding/
│   ├── Blog.md + Blog/
│   ├── DocC.md + DocC/
│   ├── IndieDev.md + IndieDev/
│   ├── Newsletter.md + Newsletter/
│   ├── Plain.md + Plain/
│   ├── Podcast.md + Podcast/
│   ├── Portfolio.md + Portfolio/
│   └── Snippets.md + Snippets/
└── themes/
    ├── README.md
    └── templates/
        ├── Classic/
        ├── Minimal/
        └── Sidebar/
```

## Installing SiteKit

Claude Code users can install the plugin from the marketplace:

```text
/plugin marketplace add FlineDev/SiteKit
/plugin install sitekit@sitekit
```

Other tools usually need a local checkout so they can read `Plugin/`:

```bash
git clone https://github.com/FlineDev/SiteKit.git .sitekit
cd .sitekit
swift run sitekit doctor
```

The `sitekit` CLI is available from that checkout:

```bash
swift run sitekit doctor
swift run sitekit new
swift run sitekit update
```

Generated sites still use their own executable target for site builds:

```bash
swift run Site build
swift run Site serve
swift run Site validate
```

## Generic Setup

For tools with Agent Skills support, expose the single SiteKit skill through the
standard `.agents/skills/` directory:

```bash
mkdir -p .agents/skills
ln -s ../../.sitekit/Plugin/skills/sitekit .agents/skills/sitekit
```

If your tool does not follow `.agents/skills/`, use the equivalent workspace or
global skills folder for that tool. The important part is that the tool can load
`Plugin/skills/sitekit/SKILL.md`; that file is the entry point and routing table
for the reference files.

Then add short project instructions for your tool:

```markdown
This project uses SiteKit. For SiteKit-specific guidance, read
.sitekit/Plugin/skills/sitekit/SKILL.md first.

Blueprints are in .sitekit/Plugin/blueprints/INDEX.md.
Theme templates are in .sitekit/Plugin/themes/templates/.
```

Add the checkout to `.gitignore` unless you intentionally vendor SiteKit:

```gitignore
.sitekit/
```

## Tool-Specific Setup

### GitHub Copilot

Copilot in VS Code supports Agent Skills.

**Skills discovery:** Use the `.agents/skills/sitekit` symlink from the generic
setup.

**Project instructions:** Create `.github/copilot-instructions.md`:

```markdown
This project uses SiteKit. Read .sitekit/Plugin/skills/sitekit/SKILL.md before
creating, modifying, deploying, or auditing the site.
```

**Invocation:** Ask Copilot to use the `sitekit` skill, or reference the skill
file directly in the task.

### Codex CLI

Codex reads project instructions and can use Agent Skills.

**Skills discovery:** Use the `.agents/skills/sitekit` symlink from the generic
setup.

**Project instructions:** Add this to the site's root `AGENTS.md`:

```markdown
This project uses SiteKit.
Read .sitekit/Plugin/skills/sitekit/SKILL.md for SiteKit-specific guidance.
```

**Invocation:** Ask Codex to use the `sitekit` skill, or mention the file path
when you want deterministic routing.

### Gemini CLI

Gemini CLI can load skill-style instructions through its own activation flow.

**Skills discovery:** If your Gemini setup scans `.agents/skills/`, use the
generic symlink. Otherwise point it directly at
`.sitekit/Plugin/skills/sitekit/SKILL.md`.

**Project instructions:** Create `GEMINI.md`:

```markdown
This project uses SiteKit. Start with
.sitekit/Plugin/skills/sitekit/SKILL.md, then follow its references for the
specific task.
```

**Invocation:** Ask Gemini to activate or read the `sitekit` skill before doing
SiteKit work.

### Cline

Cline uses its own workspace skill folder.

**Skills discovery:** Create a workspace symlink:

```bash
mkdir -p .cline/skills
ln -s ../../.sitekit/Plugin/skills/sitekit .cline/skills/sitekit
```

**Project instructions:** Create `.clinerules`:

```markdown
This project uses SiteKit. Read .sitekit/Plugin/skills/sitekit/SKILL.md before
SiteKit work.
```

**Invocation:** Ask Cline to use the `sitekit` skill or read the skill file.

### Amp

Amp reads repository instructions and can work from explicit file references.

**Skills discovery:** Use `.agents/skills/sitekit` if your Amp environment is
configured for skills. Otherwise keep `.sitekit/Plugin/skills/sitekit/SKILL.md`
available and reference it in prompts.

**Project instructions:** Add a short instruction file in the format your Amp
workspace already uses:

```markdown
This project uses SiteKit. Start with
.sitekit/Plugin/skills/sitekit/SKILL.md for SiteKit-specific tasks.
```

**Invocation:** Mention the `sitekit` skill or the skill file path in the task.

### Cursor

Cursor project rules can point at the SiteKit skill even without native skill
activation.

**Skills discovery:** If your Cursor setup supports `.agents/skills/`, use the
generic symlink. Otherwise rely on project rules.

**Project instructions:** Create `.cursor/rules/sitekit.mdc`:

```markdown
---
description: SiteKit website guidance
alwaysApply: false
---

For SiteKit work, read .sitekit/Plugin/skills/sitekit/SKILL.md first. Use
.sitekit/Plugin/blueprints/INDEX.md when choosing or updating a blueprint.
```

**Invocation:** Attach or mention the rule when asking Cursor to create,
modify, deploy, or audit a SiteKit site.

## Autonomous Agents

Autonomous agents should follow the same setup with fewer interactive pauses:

- Start at `Plugin/skills/sitekit/SKILL.md`.
- Use `Plugin/blueprints/INDEX.md` to choose among AppLanding, Blog, IndieDev,
  Newsletter, Plain, Podcast, Portfolio, and Snippets.
- Use `swift run sitekit doctor` before scaffolding or updating.
- Use `swift run Site build` to verify generated sites.
- Use the reference files under `Plugin/skills/sitekit/references/` only when
  the skill routes to them or the task clearly needs that topic.

## Tools Without Skills Support

Tools without Agent Skills support can still use SiteKit by reading the same
files as ordinary project documentation. Put the short instruction from the
generic setup into the tool's rule or memory system, then explicitly ask it to
start with:

```text
.sitekit/Plugin/skills/sitekit/SKILL.md
```

The main limitation is that the tool will not auto-activate the skill. The
blueprints, theme templates, CLI, and reference files remain normal repository
files that any code-aware tool can inspect.
