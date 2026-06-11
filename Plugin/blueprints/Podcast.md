# Blueprint: Podcast

**A podcast website with episode pages, audio player, chapter markers, and iTunes-compatible RSS feed.**

## Quick Start

```bash
swift run sitekit new my-show --blueprint Podcast
cd my-show
swift run Site serve     # preview at http://localhost:8080
```

Ships with the **orange** color scheme + **friendly** font pairing – change them in `Theme/theme.yaml` (see `references/themes.md`). Audio files are hosted separately (see Audio Hosting below).

## When to Choose This

Choose `Podcast` when you want a website for an audio podcast. Good for:

- Interview shows and panel discussions
- Solo commentary podcasts
- Audio journals and serialized storytelling
- Any show that publishes episodes with MP3 files

For a blog with written articles, see `Blog`. For a combined blog + podcast site, start with `Podcast` and add a blog section later.

## Questions to Ask

1. **Show name and base URL?** (e.g. "Tech Talk", "https://techtalk.fm")
2. **Show description?** (Used in RSS feed and homepage subtitle)
3. **Host(s)?** Names and optional avatar images for the homepage
4. **Language?** (e.g. "en", "de" -- affects date formatting and UI labels)
5. **iTunes category?** (e.g. "Technology", "Society & Culture", "Comedy")
6. **Where are the MP3 files hosted?** SiteKit generates the website and RSS feed but does not host audio files. MP3s must be served from a CDN or object storage (see Audio Hosting below).

## What It Generates

- Episode detail pages (`/episode/<slug>/`) with HTML5 audio player, chapter markers (click-to-seek), show notes, and prev/next navigation
- Episode listing page (`/episode/`) with episode cards
- Home page with hero section, host showcase, and recent episodes
- iTunes/Podlove/PodcastIndex-compatible RSS feed (`/podcast.xml`)
- Tag listing pages (`/tags/<tag>/`)
- Static pages (About, Imprint, etc.)
- Sitemap, robots.txt, llms.txt, search index
- Open Graph / SEO metadata on every page
- Draft preview support

## SiteConfig.yaml Structure

```yaml
name: "My Podcast"
baseURL: "https://example.com"
description: "A podcast about..."
language: "en"

author:
  name: "Host Name"
  email: "host@example.com"

podcast:
  artworkPath: "/assets/artwork.jpg"    # Show artwork (used in RSS + pages)
  feedPath: "/podcast.xml"              # RSS feed output path
  itunesCategory: "Technology"          # iTunes primary category
  itunesSubcategory: "Tech News"        # Optional subcategory
  itunesType: "episodic"                # "episodic" (default) or "serial"
  explicit: false                       # iTunes explicit flag
  podcastGuid: "a1b2c3d4-..."           # Optional: from podcastindex.org/add (preserves identity across feed migrations)
  hosts:                                # Shown on homepage + in RSS <podcast:person>
    - name: "Host One"
      image: "/assets/host-one.webp"
      role: host                        # Optional: host, guest, editor (Podcast Index spec)
      href: "https://host-one.com"      # Optional: host's website
    - name: "Host Two"
      image: "/assets/host-two.webp"
  legacyFeedPaths:                      # Optional: output feed to extra paths
    - "/feed/mp3/index.xml"             # (useful for migrations)
  subscribeLinks:                       # Optional: listen-on buttons on homepage hero
    - platform: "apple"                 # Built-in: apple, spotify, overcast, pocketcasts, rss
      url: "https://podcasts.apple.com/podcast/id1234567890"
    - platform: "spotify"
      url: "https://open.spotify.com/show/..."
    - platform: "overcast"
      url: "https://overcast.fm/itunes1234567890"
    - platform: "pocketcasts"
      url: "https://pca.st/itunes/1234567890"
    - platform: "rss"                   # RSS button copies feed URL to clipboard
      url: "https://example.com/podcast.xml"
      # label: "Custom"                 # Optional: override default display name

navigation:
  logo:
    image: "/assets/artwork.jpg"
    text: "My Podcast"
  items:
    - title: "Episodes"
      url: "/episode/"
    - title: "About"
      url: "/about/"

sections:
  - name: "Podcast"
    slug: "podcast"
    contentDirectory: "Podcast"
    urlPrefix: "episode"             # controls episode URLs: /episode/<slug>/
    description: "A podcast about..."

footer:
  copyrightName: "My Podcast"
  startYear: 2026
```

## Entry Point

```swift
// Sources/Site/Main.swift
import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.podcast(configPath: "SiteConfig.yaml").run()
   }
}
```

## Content Structure

Example end state – the scaffold ships one sample episode and `Pages/About.md`; `Imprint.md` and `Assets/` (artwork, host photo) are added as the show grows:

```
Content/
├── Podcast/
│   ├── 2026-01-01_001-Pilot-Episode.md
│   ├── 2026-02-01_002-Second-Episode.md
│   └── ...
├── Pages/
│   ├── About.md
│   └── Imprint.md
└── Assets/
    ├── artwork.jpg
    └── host.webp
```

## Episode Frontmatter Schema

The podcast blueprint **requires** `title`, `date`, `audioURL`, and `duration` on every episode (the build fails fast if any is missing); the rest are optional.

```yaml
---
id: a1b2c3d4                            # 8-char hex, unique per episode
title: "001 -- Pilot Episode"
date: 2026-01-01
summary: "What this episode is about."
tags: [topic-a, topic-b]
episode: 1                               # Episode number (Int)
duration: "00:30:00"                     # Duration in HH:MM:SS
audioURL: "https://cdn.example.com/EP001.mp3"  # Full URL to MP3
audioSize: 28800000                      # File size in bytes
guid: "unique-persistent-id"            # Persistent GUID for RSS (falls back to URL)
episodeType: full                        # iTunes: full, trailer, or bonus
chapters:                                # Optional chapter markers
  - start: "00:00:00"
    title: "Introduction"
  - start: "00:05:30"
    title: "Main Topic"
---

Show notes go here as regular Markdown.

## Links

- [Example](https://example.com)
```

## Audio Hosting

SiteKit generates the static website and RSS feed. Audio files (MP3s) require separate hosting on a CDN or object storage that serves files over HTTPS with range request support.

**Options:**

| Service | Cost | Notes |
|---|---|---|
| Cloudflare R2 | Free (10 GB, 10M reads) | Zero egress fees, S3-compatible, CLI upload via `wrangler` |
| AWS S3 + CloudFront | ~$1-5/month | Most flexible, pay per GB |
| Backblaze B2 + Cloudflare | ~$0.04/month | Cheapest storage, free egress via Bandwidth Alliance |
| Bunny CDN | ~$2-3/month | Simple setup, good EU performance |

Upload example (Cloudflare R2):
```bash
wrangler r2 object put "my-bucket/episodes/EP001.mp3" \
  --file=EP001.mp3 --content-type="audio/mpeg" --remote
```

The `audioURL` in each episode's frontmatter should point to the full public URL of the hosted MP3 file.

## Guest Episodes

For episodes with guests, add a `guests` field to the episode frontmatter:

```yaml
guests:
  - name: "Jane Appleseed"
    role: guest
    image: "https://example.com/jane.jpg"
    href: "https://jane.dev"
```

Guests appear as `<podcast:person>` tags in the RSS feed alongside the regular hosts. All fields except `name` are optional.

## RSS Feed Validation

After building your site, validate the RSS feed before submitting to podcast directories:

1. **Build**: `swift run Site build`
2. **Validate**: Upload `_Site/podcast.xml` to one of these validators:
   - [Cast Feed Validator](https://castfeedvalidator.com) – checks Apple Podcasts requirements
   - [Podbase Validator](https://podba.se/validate/) – checks iTunes + Podcast Index specs
3. **Test in apps**: Subscribe to the feed URL in Apple Podcasts, Spotify, or Pocket Casts before going live

**Common validation issues and how SiteKit handles them:**

| Requirement | SiteKit behavior |
|-------------|-----------------|
| `<itunes:type>` | Defaults to `"episodic"`. Set `itunesType: "serial"` for chronological shows. |
| `<itunes:author>` per episode | Automatically added from `author.name` in SiteConfig |
| `<lastBuildDate>` | Automatically set to build time |
| `<podcast:person>` for hosts | Generated from `podcast.hosts` config |
| `<podcast:guid>` | Optional – set `podcastGuid` for feed migration resilience |
| Episode `<guid>` | Uses `guid` from episode frontmatter (falls back to episode URL) |
| Artwork dimensions | Apple requires 1400×1400 to 3000×3000 px, JPEG or PNG |

**Podcast GUID for migrations:** If you're migrating from another host (WordPress, Anchor, etc.), get your podcast's permanent GUID from [podcastindex.org](https://podcastindex.org) – search for your show, copy the GUID, and add it to `SiteConfig.yaml` as `podcastGuid`. This ensures podcast apps don't lose track of your show when the feed URL changes.

## Variations

- **Without chapters**: Simply omit the `chapters` field from episode frontmatter. The chapter section will not render.
- **Single host**: Set one entry in `podcast.hosts`, or omit entirely to skip the host showcase on the homepage.
- **Non-English**: Set `language` to your locale (e.g. `"de"`, `"ja"`). UI labels (chapters, show notes, etc.) adapt automatically.
- **Custom feed path**: Change `podcast.feedPath` (default: `/podcast.xml`).
- **Legacy feed migration**: Add old feed URLs to `podcast.legacyFeedPaths` to output the same RSS at multiple paths during migration.
- **Podcast GUID**: Set `podcast.podcastGuid` with your UUID from podcastindex.org for cross-platform identity persistence.
