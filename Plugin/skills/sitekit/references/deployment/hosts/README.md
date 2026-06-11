# Hosting Providers

Each file in this directory covers one hosting provider. Every host serves the same build artifact – the `_Site/` directory. **Recommended starting point: Cloudflare Pages** ([`cloudflare-pages.md`](cloudflare-pages.md)) – unlimited bandwidth, native `_headers`/`_redirects` support, free SSL + custom domains.

For the end-to-end deploy flow (choose CI + host, wire them together) see [`../SKILL.md`](../SKILL.md); for CI provider options see [`../ci/README.md`](../ci/README.md).

## Current Status

| Provider | File | Status |
|---|---|---|
| Cloudflare Pages | `cloudflare-pages.md` | Complete |
| GitHub Pages | `github-pages.md` | Complete |
| Netlify | `netlify.md` | Complete |
| Vercel | `vercel.md` | Complete (commercial use warning) |

## Adding a New Provider

Create `<provider-name>.md` (lowercase-hyphenated) with:

1. **Why / limitations** – one sentence on tradeoffs
2. **Create project** – initial manual setup steps
3. **Credentials** – what secrets are needed and where to get them
4. **Set GitHub secrets** – `gh secret set` commands
5. **Deploy step** – the exact YAML snippet to paste into the CI workflow, for both `_Site` (remote pkg) and `Content/Website/_Site` (local-dev) paths
6. **Custom domain** – brief instructions if supported

Then add it to the table above and to the provider table in `../SKILL.md`.

## The Universal Deploy Pattern

Every host receives the built `_Site/` directory. The CI workflow always ends with an upload/deploy step that pushes that directory to the host. The host file only needs to show:
- How to authenticate (secrets)
- The exact deploy step YAML
