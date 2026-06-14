---
name: legal-pages
description: "Decide whether a SiteKit site needs an imprint (Impressum / mentions légales / 特定商取引法 page) and/or a privacy policy, and how to add one. Country-dependent: the rules differ by where the site owner is based and what the site does. Use when a site goes public, collects any personal data, or the user asks about legal pages, imprint, privacy, GDPR, or cookies."
---

# Legal Pages – Imprint & Privacy

> **Not legal advice.** This reference is orientation to help you and the site owner make a sensible first decision – it is **not legal advice**, and it can be out of date or incomplete. The site owner is responsible for what their site publishes. When the stakes are real (a business, paid products, processing personal data at scale), say so plainly and suggest they confirm the specifics for their country, ideally with a professional.

## Step 0: Ask where the owner is based – always first

Legal duties for a website follow the **country/jurisdiction of the person or business running it** (and sometimes where the visitors are). You cannot pick the right approach without it, so ask before adding or skipping any legal page:

> "Which country are you based in (and is this a personal site or a business/commercial one)? That decides whether you need an imprint or a privacy page, and in what form."

Capture the answer; it drives everything below. The shipped examples lean German because SiteKit's author is based in Germany – treat them as **a worked example to adapt or drop**, not a default.

## Imprint: is one needed, and in what form?

An "imprint" is a page (or footer block) disclosing who runs the site and how to reach them. Whether it is required – and how much it must contain – varies a lot. Pick the **form** that fits: a full **detail page**, a short **footer line**, or **nothing**.

| Country / region | Imprint typically required? | Usual form | Where to verify (official) |
|---|---|---|---|
| **Germany** | Yes for almost any non-purely-private site (business, ads, or journalistic content) | Full **Impressum** page (`§5 DDG`, ex-`§5 TMG`; journalistic: `§18 MStV`) | [gesetze-im-internet.de/ddg](https://www.gesetze-im-internet.de/ddg/) |
| **Austria** | Yes for business/media sites | Full Offenlegung/Impressum (`§5 ECG`, `§25 MedienG`) | [ris.bka.gv.at](https://www.ris.bka.gv.at/) |
| **Switzerland** | Yes for commercial/e-commerce sites | Identity + contact, page or footer (`Art. 3 UWG`) | [fedlex.admin.ch](https://www.fedlex.admin.ch/) |
| **France** | Yes (mentions légales) | Full page (`LCEN`, Loi n° 2004-575, Art. 6) | [legifrance.gouv.fr](https://www.legifrance.gouv.fr/) |
| **EU (general)** | Baseline disclosure duty for service providers | Identity + contact (e-Commerce Directive 2000/31/EC, Art. 5) | [eur-lex.europa.eu](https://eur-lex.europa.eu/) |
| **UK** | Companies/businesses must disclose set details; no "imprint" as such | Footer + about (company no., registered address; Companies Act 2006, e-Commerce Regs 2002) | [gov.uk](https://www.gov.uk/) |
| **USA** | No general imprint requirement | None (a contact/about page is customary, not mandated) | [ftc.gov](https://www.ftc.gov/) |
| **Japan** | Required for e-commerce / paid services; not for a personal blog | Disclosure page (特定商取引法, Act on Specified Commercial Transactions) | [caa.go.jp](https://www.caa.go.jp/) |
| **Other / not listed** | Unknown – do not guess | Ask + check locally | Search "[country] website imprint / legal notice requirement" |

**How to decide the form:**

- **Full detail page** – commercial or journalistic site in DE/AT/FR (and similar). Use the `Impressum.md` example in the AppLanding blueprint as a starting structure; rename/relabel for the locale ("Imprint" / "Mentions légales").
- **Footer line only** – a short legal line suffices (e.g. CH/UK small/personal commercial, or a business that just needs a contact + entity). Add it to `footer` in `SiteConfig.yaml` rather than a full page.
- **Nothing** – a purely personal, non-commercial site in a country that does not require it (e.g. a personal US/UK/JP blog with no ads, no shop, no business). Do not add a page just to have one.

When unsure between two forms, pick the more complete one and tell the user why, then let them decide.

## Privacy policy: driven by what the site does, not just where you are

A privacy policy is needed when the site **collects or processes personal data**. This is less about the owner's country and more about the site's content and the visitors' location: EU/EEA visitors bring GDPR into scope; California has CalOPPA (commercial sites collecting personal data) and the CCPA/CPRA (which apply to larger for-profit businesses above set thresholds, not to a small personal site). Match the obligations to what the site actually is and does.

Walk through what the site actually does:

| If the site… | Privacy implication |
|---|---|
| has analytics (Plausible, GA, etc.) | Needs a privacy policy; mention the tool and what it stores |
| has a contact or newsletter **signup form** (the Newsletter blueprint does) | Collects personal data → privacy policy + a clear consent note at the form |
| embeds third-party content (YouTube, Maps, a CDN, remote fonts) | Each embed can set cookies / leak IPs → disclose it |
| sets cookies | Disclose; EU visitors generally need consent first |
| has none of the above (a plain static site, self-hosted fonts, no forms, no analytics) | Often little or nothing is required – but say "often", not "never" |

**SiteKit defaults help here:** SiteKit **self-hosts fonts** (no Google Fonts call), ships **no analytics**, and inlines its icons – so a content-only site usually has a small privacy surface. The moment you add a signup form, analytics, or an embed, revisit this.

If a privacy policy is warranted, create it as a static page (`Content/Pages/Privacy.md`, slug `privacy`) and link it in the footer. Cover: who the controller is, what data is collected and why, third parties involved, retention, and the visitor's rights (access/deletion). Keep it specific to what the site genuinely does – a copy-pasted generic policy that describes data you don't collect is worse than a short honest one.

## Adding the pages

Both imprint and privacy are ordinary **static pages** (see `custom-pages.md` / `content-writing.md`):

1. Add `Content/Pages/Imprint.md` and/or `Content/Pages/Privacy.md` with a `title` and `slug` in the frontmatter.
2. Link them in `footer` in `SiteConfig.yaml` so they appear site-wide.
3. For multilingual sites, legal pages can carry `legalDocument: true` so a translation notice shows when viewed in a non-primary language (see `localization.md`).

Worked **German** examples with placeholders live in `Docs/Templates/Imprint.md` and `Docs/Templates/PrivacyPolicy.md` (the latter assumes Cloudflare Pages + cookieless analytics). Use them as a starting structure when the country table above points to a full page – adapt the wording, headings, and legal references to the owner's actual jurisdiction.

Put the **not-legal-advice** point to the user once, plainly, when you create these pages: you're giving them a useful starting point, the responsibility for accuracy is theirs.
