# Host: GitHub Pages

**Free, no account needed beyond GitHub. Best for simple personal sites.** **[Cloudflare Pages](cloudflare-pages.md) is the recommended default** – pick GitHub Pages only if you want to stay entirely within GitHub and don't need custom cache/redirect rules.

**How it works:** like every host, GitHub Pages serves a **pre-built `_Site/` folder** – it does **not** run Swift. The workflow below builds the site in GitHub Actions (`swift run -c release Site build`) and uploads `_Site/` as the Pages artifact.

**Limitations to know:**
- **No `_headers` support** – GitHub Pages cannot apply the cache/security headers SiteKit writes to `_Site/_headers` (the file is just served as a static file, ignored as config). Cloudflare Pages and Netlify do honor it.
- **No native `_redirects`** – server-side redirects aren't supported; SiteKit's HTML `<meta http-equiv="refresh">` redirect pages still work (they're plain HTML), but the `_redirects` file is ignored.
- 1 GB repo size, 100 GB bandwidth/month (soft limit), no per-branch preview deploys.

---

## 1. Enable GitHub Pages

Repo → **Settings → Pages → Source → GitHub Actions**

---

## 2. Deploy Step for CI Workflow

Replace the placeholder deploy step with this full job (GitHub Pages uses a two-step artifact upload + deploy pattern):

```yaml
permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.2"

      - name: Build site
        run: swift run -c release Site build

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: _Site

      - id: deployment
        uses: actions/deploy-pages@v4
```

No secrets needed – GitHub Pages uses the built-in `GITHUB_TOKEN`.

> **Jekyll / `.nojekyll`:** this Actions-artifact deploy does **not** run Jekyll, so `_`-prefixed paths are served fine – nothing to do. Only if you switch to the legacy "deploy from a branch" source would Jekyll run and strip `_`-prefixed paths; in that case add an empty `.nojekyll` file at the output root (SiteKit does not emit one).

---

## Custom domain (optional)

1. Repo **Settings → Pages → Custom domain** → enter the bare domain (e.g. `example.com`)
2. DNS: apex → four `A` records to GitHub's IPs (or an `ALIAS`/`ANAME` if your DNS supports it); a `www`/subdomain → `CNAME` to `<username>.github.io`
3. Tick **Enforce HTTPS** once the certificate provisions (a few minutes)
4. Update `baseURL` in `SiteConfig.yaml` to the custom domain and redeploy.

---

## Verification

After deploy, check `https://<username>.github.io/<repo>/` (or your custom domain), plus `/feed.xml`, `/sitemap.xml`, and a missing path for the `/404` page. If assets 404, `baseURL` likely doesn't match the served URL.

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
- [`cloudflare-pages.md`](cloudflare-pages.md) – the recommended default host (honors `_headers`/`_redirects`, has preview deploys).
- [`../ci/github-actions.md`](../ci/github-actions.md) – the GitHub Actions workflow this builds on.
