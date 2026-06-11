---
name: deployment
description: "Set up push-to-deploy for a SiteKit website. Use when the user wants to deploy their site or set up CI/CD. Guides through choosing a host, choosing a CI provider, and wiring them together."
metadata:
  keywords: "deploy, hosting, CI, CD, Cloudflare, GitHub Actions, publish, live"
---

# Deployment Skill

**Goal:** Push to `main` → site rebuilds and deploys automatically.

**What gets deployed:** `swift run -c release Site build` produces a static **`_Site/`** directory – that single folder *is* the deploy artifact. Every host below serves the same `_Site/` (including the `_headers`, `_redirects`, `sitemap.xml`, `robots.txt`, and `llms.txt` SiteKit emits into it); there is no server runtime.

---

## Step 0: Detect Package.swift Setup

Read the user's `Package.swift`. Two variants exist:

| `Package.swift` dependency | Variant |
|---|---|
| `.package(url: "https://github.com/FlineDev/SiteKit.git", ...)` | **remote** |
| `.package(path: "../../SiteKit/Package")` or similar local path | **local-dev** |

Keep this in mind – the CI workflow template differs between the two. The relevant CI file explains both.

---

## Step 1: Setup Mode

Ask the user how they want to proceed:

> "Would you like me to set up the deployment for you (I'll handle as much as possible automatically), or would you prefer I guide you through each step so you do it yourself?"

- **Agent does it:** The agent runs CLI commands (`wrangler`, `gh`) directly, creates files, and sets secrets. The user only needs to intervene for steps that require the browser (e.g., creating API tokens).
- **Guided:** The agent explains each step and tells the user what to do. The user runs all commands and creates all files themselves.

---

## Step 2: Choose a CI Provider

Ask the user which CI they use, or recommend **GitHub Actions** if they have no preference:

> "Which CI service do you use? I recommend GitHub Actions – it's free for public repos and has 2,000 free minutes/month for private repos."

Then read the appropriate file:

| CI Provider | File to read |
|---|---|
| GitHub Actions | `ci/github-actions.md` |
| GitLab CI | `ci/gitlab-ci.md` |
| Bitrise | `ci/bitrise.md` |
| Xcode Cloud | `ci/xcode-cloud.md` |
| Other / unsupported | Tell the user: the pattern is always "install Swift, run `swift run -c release Site build`, deploy `_Site/`" |

---

## Step 3: Choose a Hosting Platform

Ask the user which host they want, or recommend **Cloudflare Pages** if they have no preference:

> "Where do you want to host? I recommend Cloudflare Pages – unlimited bandwidth, global CDN, free SSL, and free custom domains."

Then read the appropriate file:

| Host | File to read |
|---|---|
| Cloudflare Pages | `hosts/cloudflare-pages.md` |
| GitHub Pages | `hosts/github-pages.md` |
| Netlify | `hosts/netlify.md` |
| Vercel | `hosts/vercel.md` |

---

## Step 4: Install and Authenticate CLI Tools

Before proceeding, ensure required CLI tools are installed and authenticated.

### `gh` (GitHub CLI) – always needed
```bash
gh --version
```
If missing, install: `brew install gh` (macOS), `sudo apt install gh` (Linux), `winget install --id GitHub.cli` (Windows).
Authenticate: `gh auth login` → choose GitHub.com, HTTPS, browser auth. Verify: `gh auth status`.

### `wrangler` (Cloudflare CLI) – only if using Cloudflare Pages in "agent does it" mode
```bash
wrangler --version
```
If missing, install: `brew install wrangler` (macOS) or `npm install -g wrangler`.
Authenticate: `wrangler login` → opens browser for OAuth. Verify: `wrangler whoami`.

**Note:** Wrangler authentication (OAuth) is separate from the API token created for CI. The agent uses Wrangler for project creation and Account ID lookup. The API token for GitHub Actions must still be created manually in the Cloudflare dashboard.

---

## Step 5: Follow the Provider Files

Read the CI and host files from Steps 2–3, then follow them in order. They cover:
- Workflow file content (CI file)
- Project creation, credentials, and secrets (host file)
- Custom domain setup (host file)

---

## Step 6: Watch the First Deployment

After pushing the workflow file:

```bash
gh run watch --exit-status
```

If it fails: `gh run view --log-failed` → fix → commit → push → watch again.

---

## See also

- `hosts/README.md` – index + status of the four documented hosts (Cloudflare Pages, GitHub Pages, Netlify, Vercel).
- `ci/README.md` – index + status of the four documented CI providers (GitHub Actions, GitLab CI, Bitrise, Xcode Cloud) and the universal build pattern.
- `../external-services.md` – post-deploy analytics and other third-party scripts (via `theme.yaml` hooks).
- `../performance.md` – CDN / cache-header considerations once the site is live.
