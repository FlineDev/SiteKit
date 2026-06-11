# Imprint (Impressum) Template for SiteKit Websites

> **NOT LEGAL ADVICE** – This template is only a starting point for a website built with SiteKit. Have it reviewed by a legal professional before publishing. German law requires an Impressum for commercial or journalistic websites (under the DDG, which replaced the former TMG as of May 2024).

This file contains two versions: a **German Impressum** (the legally binding version under German law) and an **English translation** (a courtesy, non-binding version). The German version references the DDG (Digitale-Dienste-Gesetz) and, for content responsibility, the MStV (Medienstaatsvertrag).

## Placeholders

Replace the following placeholders throughout both versions:

| Placeholder | Description | Example |
|---|---|---|
| `{{OWNER_NAME}}` | Full legal name of the site operator | `Max Mustermann` |
| `{{ADDRESS_LINE_1}}` | Street address | `Musterstraße 1` |
| `{{ADDRESS_LINE_2}}` | City and postal code | `12345 Berlin` |
| `{{EMAIL_DE}}` | Contact email (German version) | `kontakt@example.de` |
| `{{EMAIL_EN}}` | Contact email (English version) | `contact@example.com` |
| `{{PHONE}}` | Phone number with country code | `+49 (0) 30 12345678` |

## Notes

- A German Impressum must include a full postal address and at least one additional contact method (email or phone). It references the **DDG**, not the former TMG.
- Content responsibility is governed by the **MStV** (Medienstaatsvertrag), not the DDG – hence the separate "Verantwortlich für den Inhalt" block.
- The English version is a courtesy translation and may omit the full postal address.
- Many German imprints include the EU Online Dispute Resolution (ODR) link. Whether it currently applies to your site is a question for your lawyer – verify before relying on it, and add or remove the block accordingly.

## Using this template in SiteKit

Legal pages are **static pages**: put them in `Content/Pages/` (e.g. `Content/Pages/Imprint.md`). The `StaticPageLoader` requires `title` and `slug` in the frontmatter; set `legalDocument: true` so SiteKit treats the page as a legal document (it is kept out of feeds and shows a translation notice when viewed in a non-authoritative language).

For a bilingual imprint, SiteKit uses a Hugo-style filename **suffix**: the file for your site's **default** language has **no** suffix, and each translation adds `.<locale>.md`. So if German is your default language, use `Imprint.md` (German) + `Imprint.en.md` (English); if English is your default, use `Imprint.md` (English) + `Imprint.de.md` (German). Keep the **same `slug`** in every language version so SiteKit links them as translations. Set `localization.legalLanguage` in `SiteConfig.yaml` to the language your legally binding version is written in (e.g. `"de"`).

---

# German Version (Legally Binding)

The legally binding Impressum under German law. Save it as `Content/Pages/Imprint.md` if German is your site's default language, or as `Content/Pages/Imprint.de.md` if it is a translation.

```markdown
---
title: "Impressum"
slug: "imprint"
legalDocument: true
---

<h3 id="angaben-gemaess-ddg">Angaben gemäß § 5 DDG</h3>
<p>{{OWNER_NAME}}<br>{{ADDRESS_LINE_1}}<br>{{ADDRESS_LINE_2}}</p>

<h3 id="kontakt">Kontakt</h3>
<p>E-Mail: {{EMAIL_DE}}<br>Telefon: {{PHONE}}</p>

<h3 id="verantwortlich">Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV</h3>
<p>{{OWNER_NAME}}<br>{{ADDRESS_LINE_1}}<br>{{ADDRESS_LINE_2}}</p>

<h3 id="eu-streitschlichtung">EU-Streitschlichtung</h3>
<p>Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: <a href="https://ec.europa.eu/consumers/odr/">https://ec.europa.eu/consumers/odr/</a></p>
<p>Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.</p>

<h3 id="haftung-fuer-inhalte">Haftung für Inhalte</h3>
<p>Als Diensteanbieter sind wir gemäß § 7 Abs. 1 DDG für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 DDG sind wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde Informationen zu überwachen oder nach Umständen zu forschen, die auf eine rechtswidrige Tätigkeit hinweisen. Verpflichtungen zur Entfernung oder Sperrung der Nutzung von Informationen nach den allgemeinen Gesetzen bleiben hiervon unberührt. Eine diesbezügliche Haftung ist jedoch erst ab dem Zeitpunkt der Kenntnis einer konkreten Rechtsverletzung möglich. Bei Bekanntwerden von entsprechenden Rechtsverletzungen werden wir diese Inhalte umgehend entfernen.</p>

<h3 id="haftung-fuer-links">Haftung für Links</h3>
<p>Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen. Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich. Die verlinkten Seiten wurden zum Zeitpunkt der Verlinkung auf mögliche Rechtsverstöße überprüft. Rechtswidrige Inhalte waren zum Zeitpunkt der Verlinkung nicht erkennbar. Eine permanente inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne konkrete Anhaltspunkte einer Rechtsverletzung nicht zumutbar. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Links umgehend entfernen.</p>

<h3 id="urheberrecht">Urheberrecht</h3>
<p>Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers. Downloads und Kopien dieser Seite sind nur für den privaten, nicht kommerziellen Gebrauch gestattet. Soweit die Inhalte auf dieser Seite nicht vom Betreiber erstellt wurden, werden die Urheberrechte Dritter beachtet. Insbesondere werden Inhalte Dritter als solche gekennzeichnet. Sollten Sie trotzdem auf eine Urheberrechtsverletzung aufmerksam werden, bitten wir um einen entsprechenden Hinweis. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Inhalte umgehend entfernen.</p>
```

---

# English Version (Courtesy Translation)

A non-binding courtesy translation. Save it as `Content/Pages/Imprint.md` if English is your site's default language, or as `Content/Pages/Imprint.en.md` if it is a translation.

```markdown
---
title: "Imprint"
slug: "imprint"
legalDocument: true
---

<h3 id="site-operator">Site Operator</h3>
<p>{{OWNER_NAME}}<br>E-Mail: {{EMAIL_EN}}</p>

<h3 id="liability-for-content">Liability for Content</h3>
<p>As a service provider, we are responsible for our own content on these pages according to general laws. However, we are not obligated to monitor transmitted or stored third-party information or to investigate circumstances that indicate unlawful activity. Obligations to remove or block the use of information under general laws remain unaffected. Liability in this regard is only possible from the time of knowledge of a concrete legal violation. Upon becoming aware of such violations, we will remove this content immediately.</p>

<h3 id="liability-for-links">Liability for Links</h3>
<p>Our website contains links to external websites of third parties, over whose content we have no influence. Therefore, we cannot assume any liability for this third-party content. The respective provider or operator of the linked pages is always responsible for their content. The linked pages were checked for possible legal violations at the time of linking. Upon becoming aware of legal violations, we will remove such links immediately.</p>

<h3 id="copyright">Copyright</h3>
<p>The content and works created by the site operator on these pages are subject to German copyright law. Reproduction, editing, distribution, and any kind of exploitation outside the limits of copyright require the written consent of the respective author or creator. Downloads and copies of these pages are permitted only for private, non-commercial use.</p>
```

---

# Customization Checklist

Before publishing, verify:

- [ ] All `{{PLACEHOLDERS}}` have been replaced with real values
- [ ] The DDG reference is correct (not TMG – TMG was replaced by the DDG in May 2024)
- [ ] The MStV reference for content responsibility is included
- [ ] You checked with your lawyer whether the EU dispute resolution link applies to your site, and kept or removed the block accordingly
- [ ] Both language versions are consistent in content
- [ ] The default-language file has no locale suffix and each translation uses `.<locale>.md`, with the same `slug` in every version
- [ ] A legal professional has reviewed the final text
