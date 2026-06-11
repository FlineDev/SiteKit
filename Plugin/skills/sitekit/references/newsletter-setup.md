# Self-Hosted Newsletter Setup Guide

This guide walks you through setting up a self-hosted newsletter stack using a VPS, Keila (open-source newsletter software), and Amazon SES for email delivery. The result is a production-ready newsletter system for under $7/month that scales to 20K+ subscribers.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  VPS (e.g., Hetzner CX23)                       │
│                                                  │
│  ┌──────────┐   ┌──────────┐   ┌─────────────┐  │
│  │  Caddy   │──▶│  Keila   │──▶│ PostgreSQL  │  │
│  │ (HTTPS)  │   │ (App)    │   │ (Database)  │  │
│  └──────────┘   └──────────┘   └─────────────┘  │
│       ▲               │                          │
│       │               ▼                          │
│    :443,:80     Amazon SES                       │
│                 (Email Delivery)                 │
└─────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **VPS** | Hosts all services via Docker. Any provider works; Hetzner CX23 recommended. |
| **Keila** | Self-hosted newsletter software built on Elixir/BEAM. Handles subscribers, campaigns, forms, analytics. |
| **PostgreSQL** | Database for Keila. Runs as a Docker container with persistent volume. |
| **Caddy** | Reverse proxy with automatic HTTPS via Let's Encrypt. Zero-config TLS. |
| **Amazon SES** | Email sending service. ~$0.10 per 1,000 emails. High deliverability. |

**Total cost: ~$5-7/month** for up to 20K subscribers with monthly sends.

## Step 1: VPS Setup

### Choose a VPS

Any Linux VPS provider works. Recommended starting point:

- **Hetzner CX23**: 2 vCPU, 4GB RAM, 40GB SSD, ~$3.56-3.92/mo
- **Hetzner CAX11**: ARM-based alternative, similar specs
- **OS**: Ubuntu 24.04 LTS
- **Enable backups** (+20% cost, worth it)

### Initial Server Configuration

SSH into your new server and run:

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install Docker and Docker Compose
apt-get install -y docker.io docker-compose-v2

# Enable Docker to start on boot
systemctl enable docker

# Configure firewall
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Caddy needs this for ACME challenges)
ufw allow 443/tcp   # HTTPS
ufw enable
```

### Important: Outbound Port Restrictions

Some VPS providers (including Hetzner) block outbound port 465 (SMTPS) on new servers to prevent spam. This is not a problem if you use **port 587 with STARTTLS**, which is the recommended configuration throughout this guide.

## Step 2: DNS

Add an A record pointing your chosen subdomain to the VPS IP address:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `keila.your-domain.com` | `<VPS-IP-ADDRESS>` | 300 |

Wait for DNS propagation before proceeding (typically a few minutes, up to 48 hours).

## Step 3: Email Sending Service

Keila needs an SMTP-compatible email sending service. Any service that provides SMTP credentials works.

### Recommended: Scaleway Transactional Email (TEM)

**Best for EU-based newsletters.** French company, GDPR-native, pay-as-you-go at €0.25/1K emails. No sandbox – instant access.

| Volume | Monthly Cost |
|--------|-------------|
| 3,600 emails | ~€0.83 |
| 20,000 emails | ~€4.93 |

**Setup:**
1. Create an account at [scaleway.com](https://www.scaleway.com)
2. Go to **Transactional Email** in the console
3. Add your domain and verify it (SPF + DKIM + DMARC DNS records)
4. Go to **IAM > API Keys**, create a new API key
5. SMTP host: `smtp.tem.scw.cloud`, port 587, STARTTLS
6. SMTP username: your **Project ID** (NOT the Access Key!)
7. SMTP password: the API **Secret Key**

> **Important:** Scaleway TEM uses the Project ID as the SMTP username, not the Access Key. This is different from most SMTP services. The Project ID is shown in the Scaleway console under your project settings.

### Alternative: Brevo (formerly Sendinblue)

**EU-based (France), established reputation.** Starter plan from ~€8/mo for 5K emails.

- SMTP relay is a core feature
- Strong deliverability, especially for EU senders
- Good dashboard and analytics

### Alternative: Amazon SES

**Cheapest at high volume** ($0.10/1K emails) but requires sandbox approval that can be denied for new accounts.

**Setup:**
1. Create an AWS account, navigate to Amazon SES
2. Choose a region (EU: `eu-central-1` Frankfurt)
3. Create a domain identity with DKIM verification
4. Add DNS records: 3 DKIM CNAMEs + MAIL-FROM MX/TXT + DMARC TXT
5. Request production access (sandbox limits sending to verified addresses only)
6. Create SMTP credentials (SES > SMTP settings) – these are different from IAM API keys

> **Warning:** New AWS accounts are frequently denied production access via automated review, even for legitimate newsletters. If denied, appeal with detailed use case information. If denied again, switch to Scaleway TEM or Brevo.

### Alternative: Other SMTP Services

Any SMTP service works with Keila. Other options sorted by cost:

| Service | 3,600/mo | 20,000/mo | EU | Notes |
|---------|----------|-----------|-----|-------|
| **Scaleway TEM** | ~€0.83 | ~€4.93 | France | Recommended. Pay-as-you-go. |
| **Mailgun Flex** | ~$5 | ~$38 | EU region | Pay-per-email. Can have approval friction. |
| **Brevo Starter** | ~$8 | ~$25 | France | Established. Good deliverability. |
| **SMTP2GO** | $10 | $10+ | No | Simple. Flat pricing. |
| **Postmark** | $15 | ~$33 | No | Best-in-class deliverability. Premium price. |
| **Resend Pro** | $20 | $20 | No | Modern API. Excellent DX. Flat pricing. |

**Avoid for newsletters:** ZeptoMail (blocks marketing email), Elastic Email (mixed deliverability reputation).

## Step 4: Docker Compose Setup

Create a project directory on your VPS:

```bash
mkdir -p /opt/keila && cd /opt/keila
```

### docker-compose.yml

```yaml
services:
   db:
      image: postgres:16-alpine
      restart: always
      environment:
         POSTGRES_USER: keila
         POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
         POSTGRES_DB: keila
      volumes:
         - postgres_data:/var/lib/postgresql/data
      healthcheck:
         test: ["CMD-SHELL", "pg_isready -U keila"]
         interval: 10s
         timeout: 5s
         retries: 5

   keila:
      image: pentacent/keila:latest
      restart: always
      depends_on:
         db:
            condition: service_healthy
      environment:
         DB_URL: postgres://keila:${POSTGRES_PASSWORD}@db/keila
         SECRET_KEY_BASE: ${SECRET_KEY_BASE}
         URL_HOST: keila.your-domain.com
         URL_SCHEMA: https
         PORT: 4000
         DISABLE_REGISTRATION: "false"
         ERL_MAX_PORTS: "1024"
         MAILER_SMTP_HOST: ${MAILER_SMTP_HOST}
         MAILER_SMTP_PORT: ${MAILER_SMTP_PORT}
         MAILER_SMTP_USER: ${MAILER_SMTP_USER}
         MAILER_SMTP_PASSWORD: ${MAILER_SMTP_PASSWORD}
         MAILER_SMTP_FROM_EMAIL: ${MAILER_SMTP_FROM_EMAIL}
         MAILER_ENABLE_STARTTLS: "true"
      ports:
         - "127.0.0.1:4000:4000"

   caddy:
      image: caddy:2-alpine
      restart: always
      ports:
         - "80:80"
         - "443:443"
      volumes:
         - ./Caddyfile:/etc/caddy/Caddyfile:ro
         - caddy_data:/data
         - caddy_config:/config

volumes:
   postgres_data:
   caddy_data:
   caddy_config:
```

### .env

```bash
# Generate secure values for these:
#   openssl rand -hex 24    (for POSTGRES_PASSWORD)
#   openssl rand -hex 64    (for SECRET_KEY_BASE)

POSTGRES_PASSWORD=<generate with: openssl rand -hex 24>
SECRET_KEY_BASE=<generate with: openssl rand -hex 64>

# SMTP settings – replace with your email sending service credentials
# Examples for common services:
#   Scaleway TEM:  smtp.tem.scw.cloud / port 587
#   Amazon SES:    email-smtp.eu-central-1.amazonaws.com / port 587
#   Brevo:         smtp-relay.brevo.com / port 587
#   Mailgun:       smtp.eu.mailgun.org / port 587
#   Resend:        smtp.resend.com / port 465
MAILER_SMTP_HOST=smtp.tem.scw.cloud
MAILER_SMTP_PORT=587
MAILER_SMTP_USER=YOUR_SMTP_USERNAME
MAILER_SMTP_PASSWORD=YOUR_SMTP_PASSWORD
MAILER_SMTP_FROM_EMAIL=newsletter@your-domain.com
```

### Caddyfile

```
keila.your-domain.com {
   reverse_proxy keila:4000
}
```

### Start the Stack

```bash
cd /opt/keila
docker compose up -d
```

Caddy automatically obtains a TLS certificate from Let's Encrypt. After a few seconds, your Keila instance should be accessible at `https://keila.your-domain.com`.

Check logs if something goes wrong:

```bash
docker compose logs -f        # All services
docker compose logs -f keila   # Keila only
docker compose logs -f caddy   # Caddy only
```

## Step 5: Keila Configuration

### Initial Setup

1. Open `https://keila.your-domain.com` in your browser
2. Register an admin account (first registration becomes admin)
3. After registering, set `DISABLE_REGISTRATION: "true"` in `docker-compose.yml` and restart to prevent unauthorized signups

### Create a Project

Projects in Keila are organizational containers. Create one for your newsletter.

### Set Up a Sender

Under your project, go to **Senders** and create a new sender:

**Option A: SES Native Sender (recommended)**
1. Select the **SES** tab
2. Enter your **IAM API** Access Key and Secret Access Key
3. Select the correct AWS region
4. Set the sender name (e.g., "Your Name from Newsletter Name")
5. Set the sender email (e.g., `newsletter@your-domain.com`)

**Option B: SMTP Sender**
1. Select the **SMTP** tab
2. Host: `email-smtp.<region>.amazonaws.com`
3. Port: `587`
4. Enable **STARTTLS**
5. Enter your **SES SMTP** credentials (not IAM API credentials)
6. Set sender name and email

### Configure Double Opt-In

Double opt-in is required by law in the EU/Germany and recommended everywhere:

1. Go to your project's **Forms** settings
2. Enable double opt-in
3. Customize the confirmation email template

### Set Up a Welcome Email

Optionally configure an automated welcome email for new subscribers under the project settings.

## Step 6: Website Integration

### Embed a Signup Form (Direct HTML, No Iframe)

Instead of using Keila's hosted form page or an iframe, embed a **plain HTML form** directly on your website. This gives you full design control and a seamless user experience.

1. In Keila, go to **Forms** and create a signup form
2. Note the form ID from the URL (e.g., `nfrm_BzLMaLXv`)
3. In your `Content/Pages/home.md`, add a form that POSTs to Keila:

```html
<form action="https://keila.your-domain.com/forms/YOUR_FORM_ID" method="post">
   <input type="email" name="contact[email]" placeholder="your@email.com" required />
   <button type="submit">Subscribe</button>
</form>
```

The `contact[email]` field name is Keila's expected format. No iframe or JavaScript SDK needed – just a standard HTML form submission.

**Important Keila form settings:**
- Enable **"Allow embedding as HTML"** – this disables CSRF validation so cross-origin form submissions work
- Disable **captcha** – double opt-in already prevents spam
- Set **"Thank you Redirect URL"** to `https://your-domain.com/?subscribed=true` – redirects users back to your site after confirmation

The theme JS in the Newsletter blueprint detects `?subscribed=true` and shows a welcome message instead of the signup form. See `blueprints/Newsletter.md` for the full flow documentation.

### EmailRenderer: Generating HTML Emails from Markdown

SiteKit's `EmailRenderer` generates newsletter-ready HTML from the same Markdown content used for website articles. This enables a write-once, publish-everywhere workflow.

SiteKit's responsibility ends at producing that HTML – it has **no send command**. You send by pasting/importing the generated HTML into a Keila campaign (or via a small script that prepends the absolute base URL and posts to Keila). The build emits the email HTML under `_Site/email/<slug>.html`.

#### URL Handling

Image paths in the generated HTML are **relative** by default (matching what's in the Markdown source). Absolute base URLs are prepended at send time (e.g., by the sending script), not by the renderer. This keeps the renderer output portable across environments.

#### Dark Mode Support

The generated HTML includes full dark mode support via two mechanisms:
- `@media (prefers-color-scheme: dark)` – for modern email clients (Apple Mail, most mobile)
- `[data-ogsc]` attribute selectors – for Outlook on Windows

Accent color shifts from `#4f46e5` (indigo-600, light mode) to `#818cf8` (indigo-400, dark mode) for contrast.

> **Note:** the email accent is **hardcoded to indigo** (`#4f46e5` / `#818cf8`) and does **not** follow your site's theme `colorScheme`. If your website uses a different accent (e.g. `forest` or `coral`), the email headers and links will still be indigo – this is deliberate, to keep email rendering consistent across clients independent of the web theme.

#### Browser Preview Toggle

The renderer embeds a JS-powered 🌙/☀️ button in the top-right corner for toggling dark/light mode in browser preview. It injects a `<style>` override that beats `@media` queries. Email clients ignore this element entirely.

#### Typography and Layout

- **Hyphenation**: `hyphens: auto; -webkit-hyphens: auto;` on body and content cell. Requires the `lang` attribute to be set on `<html>`.
- **Padding**: 24px top, 24px bottom on the content cell.
- **Header**: Site name in accent color + short tagline (text before " – " or "." extracted from the site description).
- **Hero image**: Placed below title and date, without border-radius.

#### Content Blocks

- **Code blocks**: Dark background (`#1e1e2e`), no language badge, no syntax highlighting (not possible in email without pre-rendering inline `<span style="color:...">` – deferred to future). Uses `white-space: pre-wrap; word-break: break-all`.
- **Inline code**: Pink (`#d63384`) on light gray (`#f0f0f0`). Shifts to `#f472b6` on `#333333` in dark mode.
- **Blockquotes (callouts)**: Emoji-prefixed blocks get accent-colored left border + tinted background.
- **Blockquotes (actual quotes)**: Thin gray border, italic text, and a trailing `"` mark (36px, top-aligned, right column via table layout).
- **Ad/promo stripping**: Blockquotes containing "Want to see your ad" or "Enjoyed this article? Check out" are automatically removed from email output.
- **Copy button**: Not included (no JS in email clients).

#### Footer

Includes an unsubscribe link and a subscription notice explaining how the recipient subscribed.

## Gotchas and Troubleshooting

### Environment Variable Names

The Keila environment variable for STARTTLS is `MAILER_ENABLE_STARTTLS`, **not** `MAILER_SMTP_STARTTLS`. Using the wrong name silently fails.

### BEAM VM Memory Usage

Without `ERL_MAX_PORTS=1024`, the Erlang/BEAM VM may allocate 1.5-2GB of memory on startup. Setting this value keeps memory usage reasonable for a small VPS.

### Port 465 Blocked

Some VPS providers (including Hetzner) block outbound port 465 on new servers. Always use port 587 with STARTTLS instead of port 465 with implicit TLS.

### SES Sandbox Limitations (Amazon SES only)

Until your account is approved for production access, you can only send emails to individually verified addresses. Request production access early – approval can take 24+ hours and new accounts are frequently denied. If denied, provide a detailed appeal with your newsletter history, subscriber consent, and bounce handling strategy. If denied repeatedly, switch to Scaleway TEM or Brevo.

### SES SMTP vs IAM API Credentials (Amazon SES only)

SES has two types of credentials – mixing them up is a common error:

| Credential Type | Created Via | Used For |
|----------------|-------------|----------|
| SMTP credentials | SES > SMTP settings | Keila SMTP sender, any SMTP client |
| IAM API credentials | IAM > Users > Access keys | Keila SES native sender, AWS SDK/CLI |

Using SMTP credentials in the SES sender tab (or vice versa) will result in authentication errors.

### DNS TXT Record Quoting

Some DNS providers automatically add surrounding quotes to TXT record values. If yours does, enter the value without quotes to avoid double-quoting (e.g., `v=DMARC1; p=none;` not `"v=DMARC1; p=none;"`).

### Applying Configuration Changes

After modifying `docker-compose.yml` or `.env`:

```bash
cd /opt/keila
docker compose down && docker compose up -d
```

## Cost Breakdown

**With Scaleway TEM (recommended):**

| Component | Monthly Cost |
|-----------|-------------|
| VPS (e.g., Hetzner CX23) | ~€3.56 |
| Backups (+20%) | ~€0.71 |
| IPv4 address | ~€0.60 |
| Scaleway TEM (3,600 emails) | ~€0.83 |
| **Total** | **~€5.70/mo** |

At 20K subscribers: Scaleway TEM increases to ~€5/mo, total ~€10/mo.

**With Amazon SES (if approved):**

| Component | Monthly Cost |
|-----------|-------------|
| VPS + backups + IPv4 | ~€4.87 |
| Amazon SES (3,600 emails) | ~€0.36 |
| **Total** | **~€5.23/mo** |

**For comparison:** Hosted newsletter services (Buttondown, ConvertKit, Beehiiv) charge $20-100/mo for the same subscriber counts.

## See also

- `Plugin/blueprints/Newsletter.md` – the Newsletter blueprint guide: signup-form flow, the `?subscribed=true` welcome handling, and what to ask the user before scaffolding.
- `external-services.md` – how SiteKit relates to external services (newsletter is the one bundled integration; other third-party scripts go through `theme.yaml` hooks).
- `content-writing.md` – issue/article frontmatter (`title`, `date`, `summary`, `image`).
- `siteconfig-reference.md` – the `SiteConfig.yaml` schema.
