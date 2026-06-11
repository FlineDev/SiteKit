# Host: Cloudflare Pages

**Why:** unlimited bandwidth (free forever), global CDN, automatic free SSL, free custom domains, per-branch preview deployments – and it reads the `_headers` and `_redirects` files SiteKit emits **natively, with zero extra config** (see below).

## How it works (read this first)

Cloudflare Pages serves a **pre-built static folder** – it does **not** run Swift, so it cannot build your SiteKit site on push. The flow is always the same two stages:

1. **Build** your site into the `_Site/` directory (locally, or in CI):
   ```bash
   swift run -c release Site build
   ```
2. **Upload** that `_Site/` folder to Cloudflare Pages.

There are two ways to do stage 2 – pick one:

- **Path 1 – manual one-off** (fastest way to a first live site): build locally, upload with the Wrangler CLI. Best for the first deploy or an occasional manual publish.
- **Path 2 – automated push-to-deploy** (recommended for ongoing): GitHub Actions installs Swift, runs the build, and uploads `_Site/` on every push. Set it up once, then just `git push`.

**Bonus you get for free on Cloudflare:** SiteKit writes `_Site/_headers` (long-cache for assets + security headers) and, when you configure redirects, `_Site/_redirects`. Cloudflare Pages consumes both formats natively – you don't configure caching or redirects anywhere in the dashboard; uploading `_Site/` is enough.

---

## Path 1 – manual deploy (≈ 5 minutes to a live site)

```bash
# 1. Build the site → produces ./_Site/
swift run -c release Site build

# 2. Install the Cloudflare CLI (once)
npm install -g wrangler      # or: brew install wrangler

# 3. Authenticate (opens a browser to authorize)
wrangler login

# 4. Deploy the built folder
wrangler pages deploy _Site --project-name=my-site
```

That's it – your site is live at `https://my-site.pages.dev`.

- **You do not need to create the project first.** The first `wrangler pages deploy --project-name=my-site` **creates** the project automatically if it doesn't exist. (If you prefer to pre-create it: `wrangler pages project create my-site`.)
- The project name becomes the subdomain (`my-site.pages.dev`) and **cannot be changed later** – choose it deliberately.
- To publish updates later, just re-run steps 1 and 4.

---

## Path 2 – automated push-to-deploy (recommended for ongoing)

Here GitHub Actions does the Swift build and the upload. The full workflow file (installing Swift, running `swift run -c release Site build`) lives in **[`../ci/github-actions.md`](../ci/github-actions.md)** – this section covers the Cloudflare-specific pieces it needs: an API token, your Account ID, and the deploy step.

### Get your Account ID

**Via Wrangler** (if authenticated): `wrangler whoami` prints it.
**Via dashboard:** it's in the dashboard URL (`https://dash.cloudflare.com/<ACCOUNT_ID>/...`) or any domain's **Overview** page → right sidebar.

### Create an API token (browser only – cannot be created via CLI)

At [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens):

1. **Create Token** → scroll to **Custom token** → **Get started**
2. Token name: `GitHub Actions - Pages Deploy`
3. Permissions: **Account → Cloudflare Pages → Edit**
4. Account Resources: **Include →** select your account
5. **Continue to summary → Create Token** – copy it immediately (shown only once)

> Do **not** use the "Global API Key" on that page – it grants full account access. The scoped token above is all the deploy needs.

(Even in "agent does it" mode, the user must create this token themselves in the browser – the agent should explain the steps and wait for the value.)

### Store the credentials as CI secrets

```bash
gh secret set CLOUDFLARE_API_TOKEN      # paste the token from above
gh secret set CLOUDFLARE_ACCOUNT_ID     # paste your Account ID
```

Verify with `gh secret list`.

### The deploy step

Add this as the final step of the CI workflow (it runs after the Swift build, on a push to your default branch):

**Remote package** (standard – `_Site/` is at the repo root):
```yaml
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy _Site --project-name=MY_PROJECT_NAME
```

**Local-dev** (the SiteKit dependency is a local `path:`, so `_Site/` sits inside a subdirectory):
```yaml
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy <path-to-site>/_Site --project-name=MY_PROJECT_NAME
```

Replace `MY_PROJECT_NAME` with your project name and `<path-to-site>` with the checkout path (e.g. `Content/Website`).

---

## Set `baseURL` to match the deployed URL

In `SiteConfig.yaml`, `baseURL` must be the URL the site is actually served from (no trailing slash) – e.g. `https://my-site.pages.dev` or `https://example.com`. A mismatch silently breaks canonical URLs, the sitemap, and Open Graph image URLs. If you serve the site under a subpath, include it. (See `../../siteconfig-reference.md`.)

---

## Custom domain (optional)

1. Cloudflare Pages → your project → **Custom domains** → **Set up a custom domain**
2. Enter the domain – use the bare apex where you can (e.g. `example.com`)
3. DNS:
   - Domain already on Cloudflare DNS → the record is added automatically
   - External DNS (Namecheap, IONOS, etc.) → add a `CNAME` pointing to `MY_PROJECT_NAME.pages.dev`
4. SSL provisions automatically once DNS propagates – a **"pending"** state for a few minutes (up to ~30) is normal.

Then update `baseURL` in `SiteConfig.yaml` to the custom domain and redeploy.

---

## Verification

After a deploy, open the live URL and confirm:

- `https://MY_PROJECT_NAME.pages.dev` (or your custom domain) renders
- `/feed.xml` and `/sitemap.xml` load
- a missing path (e.g. `/nope`) shows the `/404` page
- assets load (no broken images/CSS) – if they 404, `baseURL` is likely wrong

---

## Troubleshooting & next steps

- **Empty / broken site:** the upload directory must be **`_Site`** (not `dist` or `public`). Deploying the wrong folder ships an empty site.
- **Assets 404 / wrong links:** `baseURL` doesn't match the deployed URL – fix it in `SiteConfig.yaml` and redeploy.
- **Preview deployments:** with Path 2, pushes to non-production branches deploy to `<branch>.<project>.pages.dev` automatically – handy for reviewing before merging.
- **Rollback:** dashboard → your Pages project → **Deployments** → pick a previous deployment → **Rollback**.
- **Free tier:** unlimited bandwidth and a generous build/deploy allowance – ample for a typical SiteKit site; it does not silently upgrade you to a paid plan.

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator (choose CI + host, wire them together).
- [`../ci/github-actions.md`](../ci/github-actions.md) – the GitHub Actions workflow that installs Swift, builds, and runs the deploy step above.
- `../../performance.md` – CDN / cache-header considerations; `../../seo-aso.md` – sitemap/robots discoverability.
