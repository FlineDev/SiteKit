# CI: GitHub Actions

## Workflow File Location

Create `.github/workflows/deploy.yml` in the website repo.

---

## Template: Remote Package (Standard)

For sites using SiteKit as a remote SPM dependency:

```yaml
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.2"

      - name: Cache SwiftPM build
        uses: actions/cache@v4
        with:
          path: .build
          key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}
          restore-keys: ${{ runner.os }}-spm-

      - name: Build site
        run: swift run -c release Site build

      - name: Deploy
        # Replace this step with the one from your host file
        run: echo "Add deploy step from hosts/<provider>.md"
```

The `actions/cache@v4` step is optional but cuts a cold ~2-3 min build to well under a minute on repeat runs by reusing the compiled `.build/` (the key invalidates when `Package.resolved` changes). The local-dev template below can add the same step after Setup Swift.

---

## Template: Local Dev (Local Path Dependency)

For sites using `.package(path: "../../SiteKit/Package")` – typically SiteKit contributors. Both repos are checked out into matching subdirectories so the relative path resolves correctly on CI:

```yaml
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.PAT_TOKEN }}
          path: Content/Website

      - uses: actions/checkout@v4
        with:
          repository: FlineDev/SiteKit
          token: ${{ secrets.PAT_TOKEN }}
          path: SiteKit/Package

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.2"

      - name: Build site
        working-directory: Content/Website
        run: swift run -c release Site build

      - name: Deploy
        # Replace this step with the one from your host file
        # Note: _Site is at Content/Website/_Site, not _Site
        run: echo "Add deploy step from hosts/<provider>.md"
```

**Why this works:** The local path `../../SiteKit/Package` from `Content/Website/` resolves to `$GITHUB_WORKSPACE/SiteKit/Package` – matching where we checked it out.

Requires `PAT_TOKEN` secret (GitHub Personal Access Token, **repo** scope):
```bash
gh secret set PAT_TOKEN
```

---

## Common Linux Build Failures

| Error | Fix |
|---|---|
| `URLSession` / networking types not found | Add `#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif` |
| macOS-only framework used | Wrap in `#if os(macOS)` or use Linux-compatible alternative |
| `unknown package` (local path) | Use the local-dev template above |
| Build times out | Increase `timeout-minutes` to 20 |

---

## Cost

Ubuntu runners cost $0.008/min. A typical SiteKit build takes 2–3 min. Never use macOS runners ($0.08/min) unless required.

---

## Forgejo Actions

Forgejo Actions is GitHub-Actions-workflow-compatible: the same YAML works with the file placed at `.forgejo/workflows/deploy.yml` instead of `.github/workflows/deploy.yml`. Ensure your Forgejo runner uses a Swift-capable image (or the Setup Swift step succeeds on its base image), and store the deploy secrets in the repo's Forgejo Actions secrets.

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
- [`README.md`](README.md) – CI provider index + the universal build pattern.
- [`../hosts/cloudflare-pages.md`](../hosts/cloudflare-pages.md) – the recommended host; copy its `wrangler-action@v3` step into the `Deploy` placeholder above.
