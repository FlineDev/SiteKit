# CI Providers

Each file in this directory covers one CI provider. They all do the same job: build the site and upload `_Site/` to the host. **Recommended starting point: GitHub Actions** ([`github-actions.md`](github-actions.md)) – free for public repos, 2,000 free minutes/month for private. **Forgejo Actions** is GitHub-Actions-workflow-compatible, so the same [`github-actions.md`](github-actions.md) template runs on a Forgejo instance too.

For the end-to-end deploy flow see [`../SKILL.md`](../SKILL.md); for hosting provider options see [`../hosts/README.md`](../hosts/README.md).

## Current Status

| Provider | File | Status |
|---|---|---|
| GitHub Actions | `github-actions.md` | Complete |
| GitLab CI | `gitlab-ci.md` | Placeholder |
| Xcode Cloud | `xcode-cloud.md` | Placeholder |
| Bitrise | `bitrise.md` | Placeholder |

## Adding a New Provider

Create `<provider-name>.md` (lowercase-hyphenated) with:

1. **Workflow file** – complete, copy-pasteable config (both remote and local-dev variants if relevant)
2. **Secrets/variables** – how to store credentials in that CI's secret manager
3. **Common failures** – Linux-specific build errors and fixes
4. **Cost notes** – free tier limits, runner pricing

Then add it to the table above and to the provider table in `../SKILL.md`.

## The Universal Build Pattern

Every CI provider follows the same three steps regardless of syntax:

```
1. Install Swift 6.2+   (swift-actions/setup-swift, swiftly, Docker image, etc.)
2. swift run -c release Site build
3. Upload _Site/ to host  (wrangler, gh-pages action, netlify-cli, etc.)
```

The CI file only needs to show how to express these three steps in that provider's config format.
