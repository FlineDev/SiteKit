# Host: Netlify

**Generous free tier, simple setup.** The closest "as good as Cloudflare" alternative – though [Cloudflare Pages](cloudflare-pages.md) is the recommended default for its unlimited bandwidth.

**How it works:** Netlify serves a **pre-built `_Site/` folder** – it does **not** run Swift. Build the site first (`swift run -c release Site build`), then upload `_Site/`.

**Native `_headers` + `_redirects`:** Netlify reads both files directly from `_Site/` – and SiteKit emits both (Netlify actually originated the `_redirects` format). So the cache/security headers and any redirects you configure just work, with zero Netlify-side setup.

## Quick deploy (manual, ≈ 5 minutes)

```bash
swift run -c release Site build       # produces ./_Site/
npm install -g netlify-cli            # once
netlify login                         # opens a browser
netlify deploy --dir=_Site --prod     # first run links/creates the site
```

For automated push-to-deploy, set up the CI path below.

---

## 1. Create the Netlify Site

1. Go to [app.netlify.com](https://app.netlify.com) → **Add new site → Deploy manually**
2. Drag and drop your local `_Site/` folder to deploy initially
3. Note the **Site ID** from Site settings → General → Site details

---

## 2. Get Credentials

### Auth Token
Go to [app.netlify.com/user/applications](https://app.netlify.com/user/applications) → **Personal access tokens → New access token**

### Site ID
Site settings → General → Site ID (looks like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

---

## 3. Set GitHub Secrets

```bash
gh secret set NETLIFY_AUTH_TOKEN
gh secret set NETLIFY_SITE_ID
```

---

## 4. Deploy Step for CI Workflow

```yaml
      - name: Deploy to Netlify
        uses: nwtgck/actions-netlify@v3
        with:
          publish-dir: _Site
          production-branch: main
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
```

For local-dev (path dependency), change `publish-dir` to `Content/Website/_Site`.

---

## Custom Domain

Netlify dashboard → Domain settings → Add custom domain (use the bare domain, e.g. `example.com`). SSL configures automatically via Let's Encrypt once DNS propagates. Then set `baseURL` in `SiteConfig.yaml` to the custom domain and redeploy.

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
- [`cloudflare-pages.md`](cloudflare-pages.md) – the recommended default host.
- [`../ci/github-actions.md`](../ci/github-actions.md) – the GitHub Actions workflow that builds Swift before the deploy step.
