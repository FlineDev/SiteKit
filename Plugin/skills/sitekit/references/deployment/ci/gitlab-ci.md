# CI: GitLab CI

> Placeholder – contributions welcome.

## Pattern

The build pattern is the same as all CI providers:
1. Install Swift (use a Swift Docker image or install manually)
2. Run `swift run -c release Site build`
3. Deploy the `_Site/` directory to your chosen host

## Swift on GitLab CI

Use the official Swift Docker image:

```yaml
image: swift:6.2

stages:
  - deploy

deploy:
  stage: deploy
  cache:
    key:
      files:
        - Package.resolved
    paths:
      - .build/
  script:
    - swift run -c release Site build
    # Add deploy step for your host here
  only:
    - main
```

## Notes

- The `cache:` block (keyed on `Package.resolved`) reuses the compiled `.build/` across pipelines – optional, but it turns a ~2-3 min cold build into well under a minute on repeat runs.
- Store credentials as **CI/CD Variables** in GitLab (Settings → CI/CD → Variables); mask + protect them.
- Use `$VARIABLE_NAME` syntax to reference them in `.gitlab-ci.yml`.
- For deployment steps, see `../hosts/<provider>.md` – adapt the deploy command to GitLab's `script:` syntax (e.g. install Wrangler and run `wrangler pages deploy _Site …` for Cloudflare).

## See also

- [`../SKILL.md`](../SKILL.md) – the full deploy orchestrator.
- [`README.md`](README.md) – CI index + universal build pattern.
- [`../hosts/cloudflare-pages.md`](../hosts/cloudflare-pages.md) – the recommended host.

## Contributing

To add a complete GitLab CI guide, create a PR to the SiteKit Plugin repo adding a full `.gitlab-ci.yml` example with at least one host integration. See `ci/README.md` for guidelines.
