# Privacy Policy Template for SiteKit Websites

> **NOT LEGAL ADVICE** – This template is only a starting point for a website built with SiteKit and deployed to Cloudflare Pages with Cloudflare Web Analytics. Have it reviewed by a legal professional before publishing. Laws vary by jurisdiction and your specific use case may require additional disclosures.

This file contains two versions: a **German privacy policy** (the legally binding version under German/EU law) and an **English translation** (a courtesy, non-binding version). Both assume hosting on Cloudflare Pages with the cookieless Cloudflare Web Analytics.

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
| `{{SOCIAL_PLATFORMS}}` | Comma-separated social platforms you link to | `Mastodon, GitHub, LinkedIn` |

## Optional Sections

Sections wrapped in `<!-- OPTIONAL -->` … `<!-- END OPTIONAL -->` comments can be removed entirely if they don't apply to your site. Each carries a comment explaining when to keep or remove it. Headings are intentionally **not numbered**, so removing a section requires no renumbering.

## Using this template in SiteKit

Legal pages are **static pages**: put them in `Content/Pages/` (e.g. `Content/Pages/Privacy.md`). The `StaticPageLoader` requires `title` and `slug` in the frontmatter; set `legalDocument: true` so SiteKit treats the page as a legal document (it is kept out of feeds and shows a translation notice when viewed in a non-authoritative language).

For a bilingual policy, SiteKit uses a Hugo-style filename **suffix**: the file for your site's **default** language has **no** suffix, and each translation adds `.<locale>.md`. So if German is your default language, use `Privacy.md` (German) + `Privacy.en.md` (English); if English is your default, use `Privacy.md` (English) + `Privacy.de.md` (German). Keep the **same `slug`** in every language version so SiteKit links them as translations. Set `localization.legalLanguage` in `SiteConfig.yaml` to the language your legally binding version is written in (e.g. `"de"`).

---

# German Version (Legally Binding)

The legally binding document for visitors from Germany and the EU. Save it as `Content/Pages/Privacy.md` if German is your site's default language, or as `Content/Pages/Privacy.de.md` if it is a translation.

```markdown
---
title: "Datenschutzerklärung"
slug: "privacy"
legalDocument: true
---

<h2 id="verantwortliche-stelle">Verantwortliche Stelle</h2>
<p>{{OWNER_NAME}}<br>{{ADDRESS_LINE_1}}<br>{{ADDRESS_LINE_2}}</p>
<p>E-Mail: {{EMAIL_DE}}<br>Telefon: {{PHONE}}</p>

<h2 id="cloudflare">Hosting und Web Analytics (Cloudflare)</h2>
<p>Diese Website wird über Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA, gehostet. Beim Aufruf unserer Seiten werden technische Daten (IP-Adresse, Browsertyp, Betriebssystem, aufgerufene Seite, Zeitpunkt des Zugriffs) an Cloudflare-Server übermittelt. Dies ist erforderlich, um die Website auszuliefern.</p>
<p>Wir nutzen außerdem <strong>Cloudflare Web Analytics</strong> zur Erfassung anonymisierter Seitenaufrufe. Dieser Dienst setzt keine Cookies, speichert keine IP-Adressen und verwendet kein Fingerprinting. Es werden lediglich aggregierte Statistiken erhoben (z.&nbsp;B. Seitenaufrufe, Referrer, Land).</p>
<p>Die Datenverarbeitung erfolgt auf Grundlage unseres berechtigten Interesses an einem sicheren und effizienten Betrieb der Website (Art. 6 Abs. 1 lit. f DSGVO). Da Cloudflare Daten in den USA verarbeiten kann, erfolgt die Übermittlung auf Basis des EU-U.S. Data Privacy Framework. Weitere Informationen: <a href="https://www.cloudflare.com/privacypolicy/">https://www.cloudflare.com/privacypolicy/</a>.</p>

<!-- OPTIONAL: Remove this entire section if you don't embed YouTube videos on your site -->
<h2 id="youtube">YouTube-Einbindung</h2>
<p>Auf einigen Seiten binden wir Videos von YouTube ein. Betreiber ist die Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Irland. Beim Aufrufen einer Seite mit YouTube-Video wird eine Verbindung zu YouTube-Servern hergestellt. Dabei wird YouTube mitgeteilt, welche Seite Sie besucht haben. YouTube kann Cookies auf Ihrem Gerät setzen oder vergleichbare Technologien zur Wiedererkennung verwenden.</p>
<p>Wenn Sie in Ihrem YouTube-/Google-Konto eingeloggt sind, kann YouTube Ihr Surfverhalten Ihrem Profil zuordnen. Sie können dies verhindern, indem Sie sich vorher ausloggen.</p>
<p>Die Einbindung erfolgt im Interesse einer ansprechenden Darstellung unserer Inhalte (Art. 6 Abs. 1 lit. f DSGVO). Weitere Informationen: <a href="https://policies.google.com/privacy?hl=de">https://policies.google.com/privacy?hl=de</a>.</p>
<!-- END OPTIONAL: YouTube -->

<!-- OPTIONAL: Remove this section if you don't have newsletter signup functionality -->
<h2 id="newsletter">Newsletter</h2>
<p>Wenn Sie unseren Newsletter abonnieren, speichern wir Ihre E-Mail-Adresse zum Zweck des Newsletterversands. Die Verarbeitung erfolgt auf Grundlage Ihrer Einwilligung (Art. 6 Abs. 1 lit. a DSGVO). Sie können den Newsletter jederzeit abbestellen. Die Rechtmäßigkeit der bis zum Widerruf erfolgten Datenverarbeitung bleibt davon unberührt.</p>
<!-- END OPTIONAL: Newsletter -->

<h2 id="soziale-medien">Soziale Medien</h2>
<p>Diese Website enthält Links zu externen Profilen auf {{SOCIAL_PLATFORMS}}. Es handelt sich um einfache Hyperlinks – beim Aufruf unserer Seite werden keine Daten an diese Dienste übertragen. Erst wenn Sie einen Link anklicken und die externe Seite aufrufen, gelten deren Datenschutzbestimmungen.</p>

<h2 id="cookies">Cookies</h2>
<p><strong>Diese Website verwendet keine Cookies.</strong> Es werden weder eigene noch Drittanbieter-Cookies gesetzt (mit Ausnahme von YouTube-Embeds, siehe oben). Ein Cookie-Banner ist daher nicht erforderlich.</p>
<!-- NOTE: If you removed the YouTube section above, also remove the parenthetical
     "(mit Ausnahme von YouTube-Embeds, siehe oben)" from this paragraph and simplify to:
     "Es werden weder eigene noch Drittanbieter-Cookies gesetzt." -->

<h2 id="ssl-tls">SSL/TLS-Verschlüsselung</h2>
<p>Diese Website nutzt eine TLS-Verschlüsselung (erkennbar an "https://"). Dadurch können Daten, die zwischen Ihrem Browser und unserem Server übertragen werden, nicht von Dritten mitgelesen werden.</p>

<h2 id="ihre-rechte">Ihre Rechte</h2>
<p>Nach der DSGVO haben Sie folgende Rechte:</p>
<ul>
<li><strong>Auskunft</strong> über Ihre bei uns gespeicherten Daten (Art. 15 DSGVO)</li>
<li><strong>Berichtigung</strong> unrichtiger Daten (Art. 16 DSGVO)</li>
<li><strong>Löschung</strong> Ihrer Daten (Art. 17 DSGVO)</li>
<li><strong>Einschränkung</strong> der Verarbeitung (Art. 18 DSGVO)</li>
<li><strong>Datenübertragbarkeit</strong> (Art. 20 DSGVO)</li>
<li><strong>Widerspruch</strong> gegen die Verarbeitung auf Basis berechtigter Interessen (Art. 21 DSGVO)</li>
</ul>
<p>Sie haben außerdem das Recht, sich bei einer <strong>Aufsichtsbehörde</strong> zu beschweren, insbesondere in dem Mitgliedstaat Ihres gewöhnlichen Aufenthalts oder des mutmaßlichen Verstoßes.</p>

<h3 id="widerspruchsrecht">Widerspruchsrecht (Art. 21 DSGVO)</h3>
<p><strong>Sofern die Datenverarbeitung auf Grundlage von Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse) erfolgt, haben Sie jederzeit das Recht, aus Gründen, die sich aus Ihrer besonderen Situation ergeben, Widerspruch gegen die Verarbeitung einzulegen. Wir werden die Verarbeitung dann einstellen, es sei denn, es liegen zwingende schutzwürdige Gründe vor, die Ihre Interessen überwiegen.</strong></p>

<h2 id="kontakt-per-email">Kontakt per E-Mail</h2>
<p>Wenn Sie uns per E-Mail kontaktieren, werden Ihre Angaben (Name, E-Mail-Adresse, Inhalt der Anfrage) zur Bearbeitung Ihres Anliegens gespeichert. Diese Daten geben wir nicht ohne Ihre Einwilligung weiter. Die Verarbeitung erfolgt auf Grundlage von Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse an der Bearbeitung von Anfragen). Die Daten werden gelöscht, sobald der Zweck entfällt, es sei denn, gesetzliche Aufbewahrungsfristen stehen dem entgegen.</p>
```

---

# English Version (Courtesy Translation)

A non-binding courtesy translation. Save it as `Content/Pages/Privacy.md` if English is your site's default language, or as `Content/Pages/Privacy.en.md` if it is a translation. This version omits the full postal address and phone number since it is not the legally binding version.

```markdown
---
title: "Privacy Policy"
slug: "privacy"
legalDocument: true
---

<h2 id="responsible-party">Responsible Party</h2>
<p>{{OWNER_NAME}}<br>E-Mail: {{EMAIL_EN}}</p>

<h2 id="cloudflare">Hosting and Web Analytics (Cloudflare)</h2>
<p>This website is hosted by Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA. When you visit our pages, technical data (IP address, browser type, operating system, page visited, time of access) is transmitted to Cloudflare servers. This is necessary to deliver the website.</p>
<p>We also use <strong>Cloudflare Web Analytics</strong> to collect anonymized page view statistics. This service does not set cookies, does not store IP addresses, and does not use fingerprinting. Only aggregated statistics are collected (e.g. page views, referrers, country).</p>
<p>Data processing is based on our legitimate interest in secure and efficient website operation (Art. 6(1)(f) GDPR). As Cloudflare may process data in the USA, the transfer is based on the EU-U.S. Data Privacy Framework. More information: <a href="https://www.cloudflare.com/privacypolicy/">https://www.cloudflare.com/privacypolicy/</a>.</p>

<!-- OPTIONAL: Remove this entire section if you don't embed YouTube videos on your site -->
<h2 id="youtube">YouTube Embeds</h2>
<p>Some pages embed videos from YouTube, operated by Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Ireland. When you visit a page with an embedded YouTube video, a connection to YouTube servers is established. YouTube is informed which page you visited and may set cookies or use similar technologies on your device.</p>
<p>If you are logged into your YouTube/Google account, YouTube may associate your browsing behavior with your profile. You can prevent this by logging out beforehand.</p>
<p>The embedding is based on our legitimate interest in an appealing presentation of our content (Art. 6(1)(f) GDPR). More information: <a href="https://policies.google.com/privacy?hl=en">https://policies.google.com/privacy?hl=en</a>.</p>
<!-- END OPTIONAL: YouTube -->

<!-- OPTIONAL: Remove this section if you don't have newsletter signup functionality -->
<h2 id="newsletter">Newsletter</h2>
<p>If you subscribe to our newsletter, we store your email address for the purpose of sending the newsletter. Processing is based on your consent (Art. 6(1)(a) GDPR). You can unsubscribe at any time. The lawfulness of processing carried out before revocation remains unaffected.</p>
<!-- END OPTIONAL: Newsletter -->

<h2 id="social-media">Social Media</h2>
<p>This website contains links to external profiles on {{SOCIAL_PLATFORMS}}. These are plain hyperlinks – no data is transmitted to these services when you load our pages. Their privacy policies apply only when you click a link and visit the external site.</p>

<h2 id="cookies">Cookies</h2>
<p><strong>This website does not use cookies.</strong> No first-party or third-party cookies are set (except by YouTube embeds, see above). No cookie consent banner is required.</p>
<!-- NOTE: If you removed the YouTube section above, also remove the parenthetical
     "(except by YouTube embeds, see above)" from this paragraph and simplify to:
     "No first-party or third-party cookies are set." -->

<h2 id="ssl-tls">TLS Encryption</h2>
<p>This website uses TLS encryption (indicated by "https://"). This ensures that data transmitted between your browser and our server cannot be read by third parties.</p>

<h2 id="your-rights">Your Rights</h2>
<p>Under the GDPR, you have the right to:</p>
<ul>
<li><strong>Access</strong> your stored data (Art. 15 GDPR)</li>
<li><strong>Rectification</strong> of inaccurate data (Art. 16 GDPR)</li>
<li><strong>Erasure</strong> of your data (Art. 17 GDPR)</li>
<li><strong>Restriction</strong> of processing (Art. 18 GDPR)</li>
<li><strong>Data portability</strong> (Art. 20 GDPR)</li>
<li><strong>Object</strong> to processing based on legitimate interests (Art. 21 GDPR)</li>
</ul>
<p>You also have the right to lodge a <strong>complaint with a supervisory authority</strong>, particularly in the EU member state of your habitual residence or the place of the alleged infringement.</p>

<h3 id="right-to-object">Right to Object (Art. 21 GDPR)</h3>
<p><strong>Where data processing is based on Art. 6(1)(f) GDPR (legitimate interest), you have the right to object at any time for reasons relating to your particular situation. We will then cease processing unless there are compelling legitimate grounds that override your interests.</strong></p>

<h2 id="contact-by-email">Contact by Email</h2>
<p>If you contact us by email, your details (name, email address, content of your inquiry) will be stored to handle your request. We will not share this data without your consent. Processing is based on Art. 6(1)(f) GDPR (legitimate interest in handling inquiries). Data will be deleted once the purpose no longer applies, unless statutory retention periods require otherwise.</p>
```

---

# Customization Checklist

Before publishing, verify:

- [ ] All `{{PLACEHOLDERS}}` have been replaced with real values
- [ ] You kept only the optional sections (YouTube, Newsletter) that apply to your site
- [ ] The cookie section text matches whether you kept or removed YouTube embeds
- [ ] Social media platform names are listed correctly
- [ ] Both language versions are consistent in content
- [ ] The default-language file has no locale suffix and each translation uses `.<locale>.md`, with the same `slug` in every version
- [ ] A legal professional has reviewed the final text
