# Host: Vercel

> **Important:** Vercel's free (Hobby) tier **prohibits commercial use**. Always tell the user this before proceeding.

[Cloudflare Pages](cloudflare-pages.md) is the recommended default; Vercel is a fine choice if you're already in that ecosystem.

**How it works:** Vercel serves a **pre-built `_Site/` folder** – it does **not** run Swift. Build first (`swift run -c release Site build`), then upload `_Site/`.

> **`_headers` / `_redirects` are NOT honored on Vercel.** Unlike Cloudflare Pages and Netlify, Vercel ignores those files – it configures headers and redirects through a **`vercel.json`** in the project root instead. SiteKit does not emit a `vercel.json`, so on Vercel the cache/security headers and redirects from `_Site/_headers` / `_Site/_redirects` will **not** take effect unless you author an equivalent `vercel.json` by hand. This is a real reason to prefer Cloudflare Pages or Netlify.

## Quick deploy (manual, ≈ 5 minutes)

```bash
swift run -c release Site build    # produces ./_Site/
npm install -g vercel              # once
vercel login                       # opens a browser
cd _Site && vercel --prod          # deploys the built folder; first run links/creates the project
```

For automated push-to-deploy, set up the CI path below.

---

## 1. Create the Vercel Project

1. Go to [vercel.com/new](https://vercel.com/new) → **Import Git Repository** or use the Vercel CLI
2. Note the **Project ID** and **Team/Org ID** from Project Settings

---

## 2. Get Credentials

Go to [vercel.com/account/tokens](https://vercel.com/account/tokens) → **Create** → name it `GitHub Actions Deploy`

---

## 3. Set GitHub Secrets

```bash
gh secret set VERCEL_TOKEN
gh secret set VERCEL_ORG_ID      # From Project Settings → General
gh secret set VERCEL_PROJECT_ID  # From Project Settings → General
```

---

## 4. Deploy Step for CI Workflow

```yaml
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: _Site
          vercel-args: '--prod'
```

For local-dev (path dependency), change `working-directory` to `Content/Website/_Site`.

---

## Custom domain (optional)

Project → **Settings → Domains** → add the bare domain (e.g. `example.com`); add the DNS records Vercel shows (apex `A` / `CNAME` for subdomains). SSL provisions automatically. Then set `baseURL` in `SiteConfig.yaml` to the custom domain and redeploy.

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
- [`cloudflare-pages.md`](cloudflare-pages.md) – the recommended default host (honors `_headers`/`_redirects` natively).
- [`../ci/github-actions.md`](../ci/github-actions.md) – the GitHub Actions workflow that builds Swift before the deploy step.
