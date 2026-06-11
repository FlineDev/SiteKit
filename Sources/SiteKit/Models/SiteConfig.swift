import Foundation

/// Failures while loading `SiteConfig.yaml`.
public enum SiteConfigError: Error {
   /// No configuration file exists at the given URL.
   case fileNotFound(URL)
   /// The file exists but does not decode; the payload keeps the decoder's
   /// structured detail (key, type, coding path).
   case invalidYAML(String)
}

extension SiteConfigError: CustomStringConvertible {
   public var description: String {
      switch self {
      case .fileNotFound(let url):
         return "Site configuration not found at \(url.path)."
      case .invalidYAML(let detail):
         return "Site configuration could not be decoded: \(detail)"
      }
   }
}

/// A named group of tags used to cluster a section's pages on its listing
/// pages (e.g. "Networking" covering `urlsession` and `http`).
public struct TopicGroup: Codable, Sendable {
   /// Heading shown above the group's pages.
   public let title: String
   /// The tags whose pages belong to this group.
   public let tags: [String]

   /// Memberwise initializer.
   public init(title: String, tags: [String]) {
      self.title = title
      self.tags = tags
   }
}

/// Declares one content section: its name, slug, source directory, URL
/// prefix, and optional taxonomies.
///
/// A section is the unit of content organisation on a SiteKit site – "Blog",
/// "Snippets", "Podcast", "Recipes" are all sections. The pipeline produces
/// one `ContentSection` per declared `SectionConfig`. `urlPrefix` controls
/// the section's URL root (e.g. `urlPrefix: "blog"` ⇒ pages live under
/// `/blog/<slug>/`).
public struct SectionConfig: Codable, Sendable {
   /// Display name shown in headings and navigation (e.g. "Blog").
   public let name: String

   /// Stable identifier renderers use to locate the section (e.g. "blog") –
   /// independent of `urlPrefix` so URLs can change without breaking lookups.
   public let slug: String

   /// Directory under `Content/` holding this section's source files.
   public let contentDirectory: String

   /// URL root of the section: pages live under `/<urlPrefix>/<slug>/`.
   public let urlPrefix: String

   /// Listing-page intro text; also the per-section RSS channel description
   /// fallback.
   public let description: String?

   /// Optional category taxonomy – enables per-category listing pages and
   /// feeds within this section.
   public let categories: [CategoryConfig]?

   /// Optional topic groups for clustering the section's listing pages.
   public let topics: [TopicGroup]?

   /// Rendering style switch: `"short"` renders pages snippet-style (compact
   /// article chrome, one promotion end slot, no inline slots). Nil is the
   /// standard article style.
   public let style: String?

   /// Custom label of the back-link from a page to this section's listing;
   /// nil falls back to the localized UI string.
   public let backLinkText: String?

   /// Memberwise initializer.
   public init(
      name: String,
      slug: String,
      contentDirectory: String,
      urlPrefix: String,
      description: String? = nil,
      categories: [CategoryConfig]? = nil,
      topics: [TopicGroup]? = nil,
      style: String? = nil,
      backLinkText: String? = nil
   ) {
      self.name = name
      self.slug = slug
      self.contentDirectory = contentDirectory
      self.urlPrefix = urlPrefix
      self.description = description
      self.categories = categories
      self.topics = topics
      self.style = style
      self.backLinkText = backLinkText
   }
}

/// One category in a section's taxonomy – drives the `/<slug>/` category
/// listing page and its feed.
public struct CategoryConfig: Codable, Sendable {
   /// Display name shown in headings and links.
   public let name: String
   /// URL path segment of the category listing page; pages reference it via
   /// `category:` frontmatter.
   public let slug: String
   /// Listing-page intro text; also the category feed's channel description
   /// fallback.
   public let description: String?

   /// Memberwise initializer.
   public init(name: String, slug: String, description: String? = nil) {
      self.name = name
      self.slug = slug
      self.description = description
   }
}

/// The site logo in the header: text, image, or both side by side.
public struct NavigationLogoConfig: Codable, Sendable {
   /// Wordmark text next to (or instead of) the logo image.
   public let text: String?
   /// Site-relative path of the logo image.
   public let image: String?
   /// Rendered width of the logo image in CSS pixels.
   public let imageWidth: Int?
   /// Rendered height of the logo image in CSS pixels.
   public let imageHeight: Int?

   /// Memberwise initializer.
   public init(text: String? = nil, image: String? = nil, imageWidth: Int? = nil, imageHeight: Int? = nil) {
      self.text = text
      self.image = image
      self.imageWidth = imageWidth
      self.imageHeight = imageHeight
   }
}

/// One link in the header navigation or the footer link row.
public struct NavigationItemConfig: Codable, Sendable {
   /// Link label.
   public let title: String
   /// Link target – a site-relative path (`/blog/`) or absolute URL.
   public let url: String
   /// Optional Font Awesome class string rendered before the label.
   public let icon: String?

   /// Memberwise initializer.
   public init(title: String, url: String, icon: String? = nil) {
      self.title = title
      self.url = url
      self.icon = icon
   }
}

/// The site header: logo, nav links, and the built-in header widgets.
public struct NavigationConfig: Codable, Sendable {
   /// The site logo; nil renders the site name as plain text.
   public let logo: NavigationLogoConfig?
   /// The header navigation links, in order.
   public let items: [NavigationItemConfig]
   /// Whether the header shows the search trigger; nil defaults to `true`.
   public let showSearch: Bool?
   /// Whether the header shows the light/dark theme toggle; nil defaults to
   /// `true`.
   public let showThemeToggle: Bool?

   /// Memberwise initializer.
   public init(logo: NavigationLogoConfig? = nil, items: [NavigationItemConfig] = [], showSearch: Bool? = nil, showThemeToggle: Bool? = nil) {
      self.logo = logo
      self.items = items
      self.showSearch = showSearch
      self.showThemeToggle = showThemeToggle
   }
}

/// One social profile link in the footer, rendered with the platform's icon.
public struct SocialLinkConfig: Codable, Sendable {
   /// Platform key selecting the icon and display name (e.g. `github`,
   /// `mastodon`, `bluesky`); unknown keys get a generic link icon.
   public let platform: String
   /// Absolute URL of the profile.
   public let url: String
   /// Optional `rel` attribute for the anchor – e.g. `"me"` for Mastodon
   /// profile verification.
   public let rel: String?

   /// Memberwise initializer.
   public init(platform: String, url: String, rel: String? = nil) {
      self.platform = platform
      self.url = url
      self.rel = rel
   }
}

/// The site footer: link row, social icons, copyright, attribution.
public struct FooterConfig: Codable, Sendable {
   /// Footer links (privacy, imprint, …).
   public let links: [NavigationItemConfig]?
   /// Social profile links rendered as an icon row.
   public let social: [SocialLinkConfig]?
   /// Raw copyright string. Use `copyrightName` + `startYear` for auto-generated year ranges instead.
   public let copyright: String?
   /// Rights-holder name for the auto-generated copyright line.
   public let copyrightName: String?
   /// First year of the auto-generated copyright range (e.g. `2019` →
   /// "© 2019–<current year>").
   public let startYear: Int?
   /// Whether the "Built with SiteKit" attribution line renders; nil defaults
   /// to `true`.
   public let showAttribution: Bool?

   /// Memberwise initializer.
   public init(
      links: [NavigationItemConfig]? = nil,
      social: [SocialLinkConfig]? = nil,
      copyright: String? = nil,
      copyrightName: String? = nil,
      startYear: Int? = nil,
      showAttribution: Bool? = nil
   ) {
      self.links = links
      self.social = social
      self.copyright = copyright
      self.copyrightName = copyrightName
      self.startYear = startYear
      self.showAttribution = showAttribution
   }
}

/// The home page hero and recent-posts block.
public struct HomePageConfig: Codable, Sendable {
   /// Hero title of the home page.
   public let title: String
   /// Hero subtitle below the title.
   public let subtitle: String?
   /// How many recent posts the home page lists; nil when not set in YAML –
   /// the renderers then use their own default (5 on the blog home, 10 on the
   /// podcast home).
   public let recentPostsCount: Int?

   /// Memberwise initializer; `recentPostsCount` defaults to 5 here, but a
   /// YAML config without the key decodes to nil.
   public init(title: String, subtitle: String? = nil, recentPostsCount: Int? = 5) {
      self.title = title
      self.subtitle = subtitle
      self.recentPostsCount = recentPostsCount
   }
}

/// Custom copy for one error page, keyed by status code in
/// `SiteConfig.errorPages` (currently only `"404"` is consumed).
public struct ErrorPageConfig: Codable, Sendable {
   /// Error page heading.
   public let title: String
   /// Explanation text below the heading.
   public let message: String

   /// Memberwise initializer.
   public init(title: String, message: String) {
      self.title = title
      self.message = message
   }
}

/// Points the build at the theme directory.
public struct ThemeRefConfig: Codable, Sendable {
   /// Theme directory relative to the project root; `"Theme"` by convention.
   public let directory: String

   /// Memberwise initializer.
   public init(directory: String = "Theme") {
      self.directory = directory
   }
}

/// One promotion card the `PromotionEnricher` can place into article slots.
public struct PromotionItemConfig: Codable, Sendable {
   /// Stable identifier – feeds the per-article stable selection hash and the
   /// variety rules.
   public let id: String

   /// Audience key this promo targets: eligible when the article's category
   /// maps to the same key via `PromotionsConfig.audienceMapping`, or when the
   /// value is `"general"`. Nil or empty makes the promo eligible on every
   /// article; a `targetTags` match also bypasses the audience check.
   public let audience: String?

   /// Selection weight – multiplies the item's score in the stable weighted
   /// pick, so higher weights surface more often. Required in YAML (the
   /// memberwise default `1` applies only to programmatic construction).
   public let weight: Int

   /// Visual style of the card, emitted as CSS class `sk-promo-<style>`
   /// (e.g. `highlight`). Required in YAML (the memberwise default applies
   /// only to programmatic construction).
   public let style: String

   /// Emoji rendered as the card's leading visual.
   public let emoji: String?

   /// Card headline.
   public let title: String

   /// Card body text (Markdown links supported).
   public let text: String

   /// Call-to-action target URL; without it the card renders no link.
   public let linkURL: String?

   /// Call-to-action label for `linkURL`.
   public let linkText: String?

   /// Tags that make the promo eligible on matching articles regardless of
   /// audience.
   public let targetTags: [String]?

   /// Tags that always block this promo, overriding every other rule.
   public let excludeTags: [String]?

   /// Tags that prioritize this promo to the front of the selection on
   /// matching articles.
   public let boostTags: [String]?

   /// Per-locale overrides for `title`/`text`/`linkText`, keyed by language
   /// code.
   public let localized: [String: LocalizedPromotionFields]?

   /// Memberwise initializer.
   public init(
      id: String,
      audience: String? = nil,
      weight: Int = 1,
      style: String = "highlight",
      emoji: String? = nil,
      title: String,
      text: String,
      linkURL: String? = nil,
      linkText: String? = nil,
      targetTags: [String]? = nil,
      excludeTags: [String]? = nil,
      boostTags: [String]? = nil,
      localized: [String: LocalizedPromotionFields]? = nil
   ) {
      self.id = id
      self.audience = audience
      self.weight = weight
      self.style = style
      self.emoji = emoji
      self.title = title
      self.text = text
      self.linkURL = linkURL
      self.linkText = linkText
      self.targetTags = targetTags
      self.excludeTags = excludeTags
      self.boostTags = boostTags
      self.localized = localized
   }
}

/// The promotion system: slot counts, audience mapping, and the card pool.
public struct PromotionsConfig: Codable, Sendable {
   /// Number of promo slots at the end of an article. Sections with
   /// `style: "short"` always use 1 end slot regardless.
   public let endSlots: Int?
   /// Number of promo slots placed inline within an article's body.
   public let inlineSlots: Int?
   /// Maps an article's `category` to an audience key, connecting articles to
   /// promos declared with `audience:`.
   public let audienceMapping: [String: String]?
   /// The promotion card pool the enricher selects from.
   public let items: [PromotionItemConfig]

   /// Memberwise initializer.
   public init(endSlots: Int? = nil, inlineSlots: Int? = nil, audienceMapping: [String: String]? = nil, items: [PromotionItemConfig] = []) {
      self.endSlots = endSlots
      self.inlineSlots = inlineSlots
      self.audienceMapping = audienceMapping
      self.items = items
   }
}

/// One redirect rule from the site's redirects YAML (see
/// `SiteConfig.redirectsFile`).
public struct RedirectRuleConfig: Codable, Sendable {
   /// Site-relative source path to redirect away from.
   public let from: String
   /// Destination – a site-relative path or absolute URL.
   public let to: String
   /// HTTP status code for the Cloudflare `_redirects` line; nil defaults to
   /// 301.
   public let status: Int?

   /// Memberwise initializer.
   public init(from: String, to: String, status: Int? = nil) {
      self.from = from
      self.to = to
      self.status = status
   }
}

/// The decoded shape of the redirects YAML file named by
/// `SiteConfig.redirectsFile`.
public struct RedirectsFileConfig: Codable, Sendable {
   /// The declared redirect rules, in file order.
   public let redirects: [RedirectRuleConfig]

   /// Memberwise initializer.
   public init(redirects: [RedirectRuleConfig]) {
      self.redirects = redirects
   }
}

/// Per-locale replacements for chrome configuration, declared under
/// `localization.localeOverrides.<lang>`. Only the set pieces are replaced.
public struct LocaleOverride: Codable, Sendable {
   /// Replacement header navigation for this locale.
   public let navigation: NavigationConfig?
   /// Replacement footer for this locale.
   public let footer: FooterConfig?
   /// Replacement home hero for this locale.
   public let homePage: HomePageConfig?
   /// Replacement site meta description for this locale.
   public let description: String?

   /// Memberwise initializer.
   public init(navigation: NavigationConfig? = nil, footer: FooterConfig? = nil, homePage: HomePageConfig? = nil, description: String? = nil) {
      self.navigation = navigation
      self.footer = footer
      self.homePage = homePage
      self.description = description
   }
}

/// Translated copy for one promotion card in one locale; unset fields keep
/// the default-language value.
public struct LocalizedPromotionFields: Codable, Sendable {
   /// Translated card headline.
   public let title: String?
   /// Translated card body text.
   public let text: String?
   /// Translated call-to-action label.
   public let linkText: String?

   /// Memberwise initializer.
   public init(title: String? = nil, text: String? = nil, linkText: String? = nil) {
      self.title = title
      self.text = text
      self.linkText = linkText
   }
}

/// Controls the machine-translation notice shown on translated articles.
public struct TranslationNoticeConfig: Codable, Sendable {
   /// Whether the notice renders at all; nil defaults to enabled.
   public let enabled: Bool?
   /// Locales whose translations are human-verified – the notice is skipped
   /// there; nil treats only the default language as verified.
   public let verifiedLanguages: [String]?

   /// Memberwise initializer.
   public init(enabled: Bool? = nil, verifiedLanguages: [String]? = nil) {
      self.enabled = enabled
      self.verifiedLanguages = verifiedLanguages
   }
}

/// The multilingual setup under the `localization:` key. Its presence with a
/// non-empty `languages` list switches the build to the per-locale pipeline.
public struct LocalizationConfig: Codable, Sendable {
   /// The site's primary language (BCP 47 code). Required in YAML when the
   /// `localization:` block is present.
   public let defaultLanguage: String

   /// The additional languages to build, excluding the default. Required in
   /// YAML (an empty list keeps the site effectively single-language).
   public let languages: [String]

   /// How translations are produced – informational for tooling (surfaced in
   /// the generated translation status JSON), e.g. `"manual"` or `"ai"`.
   /// Required in YAML.
   public let translationMode: String

   /// Project-relative path to a translation style guide, surfaced in the
   /// translation status JSON for AI translators.
   public let styleGuidePath: String?

   /// Per-locale chrome replacements (navigation, footer, home hero,
   /// description), keyed by language code.
   public let localeOverrides: [String: LocaleOverride]?

   /// Configuration of the machine-translation notice on translated articles.
   public let translationNotice: TranslationNoticeConfig?

   /// The legally binding language for `legalDocument:` pages; nil falls back
   /// to the default language.
   public let legalLanguage: String?

   /// Memberwise initializer. The defaults exist for programmatic
   /// construction only – when decoding YAML, `defaultLanguage`, `languages`,
   /// and `translationMode` must all be present.
   public init(
      defaultLanguage: String = "en",
      languages: [String] = [],
      translationMode: String = "manual",
      styleGuidePath: String? = nil,
      localeOverrides: [String: LocaleOverride]? = nil,
      translationNotice: TranslationNoticeConfig? = nil,
      legalLanguage: String? = nil
   ) {
      self.defaultLanguage = defaultLanguage
      self.languages = languages
      self.translationMode = translationMode
      self.styleGuidePath = styleGuidePath
      self.localeOverrides = localeOverrides
      self.translationNotice = translationNotice
      self.legalLanguage = legalLanguage
   }
}

/// One host or guest shown in the podcast site's host showcase.
public struct PodcastHostConfig: Codable, Sendable {
   /// Display name.
   public let name: String
   /// Site-relative path of the host's photo.
   public let image: String?
   /// Role line below the name (e.g. "Host", "Co-Host").
   public let role: String?
   /// Profile URL the host card links to.
   public let href: String?

   /// Memberwise initializer.
   public init(name: String, image: String? = nil, role: String? = nil, href: String? = nil) {
      self.name = name
      self.image = image
      self.role = role
      self.href = href
   }
}

/// One podcast-platform subscribe link (Apple Podcasts, Spotify, …).
public struct SubscribeLinkConfig: Codable, Sendable {
   /// Platform key selecting icon and default label.
   public let platform: String
   /// Absolute URL of the show on that platform.
   public let url: String
   /// Custom label overriding the platform's display name.
   public let label: String?

   /// Memberwise initializer.
   public init(platform: String, url: String, label: String? = nil) {
      self.platform = platform
      self.url = url
      self.label = label
   }
}

/// Podcast-site specifics under the `podcast:` key – feed metadata for the
/// iTunes RSS plus the host showcase and subscribe links.
public struct PodcastConfig: Codable, Sendable {
   /// Site-relative path of the show artwork used as the feed's channel image.
   public let artworkPath: String?
   /// Output path of the podcast RSS feed; nil defaults to `/podcast.xml`.
   public let feedPath: String?
   /// Former feed paths that each receive a full copy of the feed XML so
   /// existing subscriptions keep working.
   public let legacyFeedPaths: [String]?
   /// Primary iTunes category (e.g. "Technology").
   public let itunesCategory: String?
   /// iTunes subcategory within `itunesCategory`.
   public let itunesSubcategory: String?
   /// The feed-level `<itunes:explicit>` flag.
   public let explicit: Bool?
   /// The `<itunes:type>` value – `"episodic"` or `"serial"`.
   public let itunesType: String?
   /// Hosts/guests for the host showcase on the podcast home page.
   public let hosts: [PodcastHostConfig]?
   /// Stable `<podcast:guid>` identifying the show across feed URL changes.
   public let podcastGuid: String?
   /// Podcast-platform links rendered as subscribe buttons.
   public let subscribeLinks: [SubscribeLinkConfig]?

   /// Memberwise initializer.
   public init(
      artworkPath: String? = nil,
      feedPath: String? = nil,
      legacyFeedPaths: [String]? = nil,
      itunesCategory: String? = nil,
      itunesSubcategory: String? = nil,
      explicit: Bool? = nil,
      itunesType: String? = nil,
      hosts: [PodcastHostConfig]? = nil,
      podcastGuid: String? = nil,
      subscribeLinks: [SubscribeLinkConfig]? = nil
   ) {
      self.artworkPath = artworkPath
      self.feedPath = feedPath
      self.legacyFeedPaths = legacyFeedPaths
      self.itunesCategory = itunesCategory
      self.itunesSubcategory = itunesSubcategory
      self.explicit = explicit
      self.itunesType = itunesType
      self.hosts = hosts
      self.podcastGuid = podcastGuid
      self.subscribeLinks = subscribeLinks
   }
}

/// A call-to-action card rendered in the DocC home page footer, declared in
/// `SiteConfig.yaml` so authors can wire footer cards without writing Swift.
/// All four fields are required – a card with no link or no label is a dead end.
public struct DocCFooterCardConfig: Codable, Sendable {
   /// Card heading.
   public let heading: String
   /// Card body text.
   public let body: String
   /// Label of the card's call-to-action link.
   public let ctaLabel: String
   /// Destination URL of the call-to-action.
   public let href: String

   /// Memberwise initializer.
   public init(heading: String, body: String, ctaLabel: String, href: String) {
      self.heading = heading
      self.body = body
      self.ctaLabel = ctaLabel
      self.href = href
   }
}

/// One "way to use the site" item for the Overview section of the DocC home page.
/// Each item is auto-numbered in the rendered list.
public struct DocCHomeWayConfig: Codable, Sendable {
   /// Short headline, e.g. "Search anything".
   public let title: String
   /// One-sentence explanation, e.g. "Press ⌘K to search across every note.".
   public let body: String

   /// Memberwise initializer.
   public init(title: String, body: String) {
      self.title = title
      self.body = body
   }
}

/// Call-to-action block for the Contributing section of the DocC home page.
/// Rendered as a lead sentence with a trailing inline link. Omitted when nil.
public struct DocCHomeContributingConfig: Codable, Sendable {
   /// Introductory sentence, e.g. "Missing something? Spotted a mistake?".
   public let lead: String
   /// Anchor text for the contributing guide link, e.g. "Contributions are welcome".
   public let linkText: String
   /// Destination URL for the contributing guide or pull-request page.
   public let linkHref: String

   /// Memberwise initializer.
   public init(lead: String, linkText: String, linkHref: String) {
      self.lead = lead
      self.linkText = linkText
      self.linkHref = linkHref
   }
}

/// Per-year editorial metadata keyed by year label (e.g. "WWDC25") for the Topics
/// card grid on the DocC home page. All fields are optional so partial overrides are valid.
public struct DocCYearCardConfig: Codable, Sendable {
   /// Tech-stack summary line, e.g. "Xcode 26 · Swift 6.2 · iOS 26".
   public let stack: String?
   /// One or two sentence summary of the year's highlights.
   public let blurb: String?
   /// Comma-separated key APIs or framework names, e.g. "Foundation Models, AlarmKit".
   public let apis: String?
   /// Explicit path to the key-visual banner image (relative to the site's `/assets/` root).
   /// When nil, core tries the convention path `/assets/<label>.jpeg`, then falls back to a
   /// hue-derived generative gradient so the card always looks polished.
   public let keyVisual: String?

   /// Memberwise initializer.
   public init(stack: String? = nil, blurb: String? = nil, apis: String? = nil, keyVisual: String? = nil) {
      self.stack = stack
      self.blurb = blurb
      self.apis = apis
      self.keyVisual = keyVisual
   }
}

/// Optional 2-tone brand for the DocC appbar. When declared, the wordmark splits
/// into a primary span (uses `--color-text`) and an accent span (uses `--color-accent`)
/// rather than rendering the plain site name. An optional logo image path adds a
/// glyph to the left of the wordmark.
///
/// Example YAML:
/// ```yaml
/// docc:
///   brand:
///     prefix: "WWDC"
///     accent: "Notes"
///     logoPath: "logo.svg"
///     logoWidth: 36
///     logoHeight: 36
/// ```
public struct DocCBrandConfig: Codable, Sendable {
   /// The first (primary) part of the wordmark, rendered in the default text color.
   public let prefix: String
   /// The second (accent) part of the wordmark, rendered with `--color-accent`.
   public let accent: String
   /// Optional path to a logo image, relative to the site's `/assets/` output root
   /// (e.g. `"logo.svg"` resolves to `/assets/logo.svg`). When present, an `<img>` is
   /// rendered to the left of the wordmark.
   public let logoPath: String?
   /// Optional logo width in CSS pixels. When set, it wins over the stylesheet's
   /// default logo box via an inline style on the `<img>` – plain width/height
   /// attributes would lose against the CSS rule. When absent, the stylesheet owns
   /// the size. Values of zero or below are ignored like an absent value. Naming
   /// mirrors the `navigation.logo` width/height pair.
   public let logoWidth: Int?
   /// Optional logo height in CSS pixels. See `logoWidth`. The two dimensions are
   /// independent: setting only one overrides just that axis and the stylesheet
   /// keeps the other, with `object-fit: contain` preserving the image's aspect.
   /// That also means a square logo only grows when BOTH dimensions are set –
   /// widening just one axis leaves the glyph at the stylesheet size inside a
   /// larger box.
   public let logoHeight: Int?

   /// Memberwise initializer.
   public init(
      prefix: String,
      accent: String,
      logoPath: String? = nil,
      logoWidth: Int? = nil,
      logoHeight: Int? = nil
   ) {
      self.prefix = prefix
      self.accent = accent
      self.logoPath = logoPath
      self.logoWidth = logoWidth
      self.logoHeight = logoHeight
   }
}

/// Describes how to render a framework icon in the sidebar tree: a Font Awesome glyph class
/// plus a 1–2 color tuple (1 = solid color, 2 = linear-gradient(145deg, c[0], c[1])).
///
/// Declared in `SiteConfig.yaml` under `docc.frameworks`, keyed by the framework slug:
/// ```yaml
/// docc:
///   frameworks:
///     swiftui:
///       glyph: fa-solid fa-layer-group
///       colors:
///         - "#1e88e5"
///         - "#42a5f5"
///       displayName: SwiftUI
/// ```
///
/// The FontAwesome icon is inlined by `FontAwesomeInliner` (Phase 6), so no external
/// CDN request is needed. Use any valid FA class string that your site's FA bundle contains.
public struct DocCFrameworkIcon: Codable, Sendable {
   /// A Font Awesome class string, e.g. `"fa-solid fa-layer-group"`.
   public let glyph: String
   /// 1 or 2 hex color strings. One color → plain color; two colors → 145deg gradient.
   public let colors: [String]
   /// Human-readable label for the registry key, e.g. `"App Intents"` for `appintents`.
   /// Used wherever the framework appears as visible text (the search page's Topic chips);
   /// URL params, JS filtering, and the color registry keep using the raw key. When absent,
   /// the raw key itself is displayed.
   public let displayName: String?

   /// Memberwise initializer.
   public init(glyph: String, colors: [String], displayName: String? = nil) {
      self.glyph = glyph
      self.colors = colors
      self.displayName = displayName
   }
}

/// DocC-blueprint-specific configuration. Optional – a DocC site renders fine
/// with none of it set; these fields only customize the generated home page and appbar.
public struct DocCConfig: Codable, Sendable {
   /// Optional eyebrow text rendered above the home hero title.
   public let homeEyebrow: String?
   /// Optional call-to-action cards rendered in the footer of every DocC page. When omitted,
   /// the footer is not emitted. Cards are config-driven so authors can declare them in
   /// `SiteConfig.yaml` without writing Swift.
   public let footerCards: [DocCFooterCardConfig]?
   /// Optional disclaimer paragraph rendered in the footer legal block, below the brand
   /// mark. Typical usage: trademark notices, "not affiliated with" statements, or other
   /// brand-content notes. Rendered as plain text (HTML-escaped). When absent the legal
   /// block is omitted; when present it always shows the site name as the brand mark.
   public let footerDisclaimer: String?
   /// Optional legal small print rendered in the footer legal block, below the disclaimer.
   /// Typical usage: copyright lines and full trademark notices that are too long for the
   /// one-sentence `footerDisclaimer`. Rendered as plain text (HTML-escaped); line breaks
   /// in the value (e.g. from a YAML block scalar) separate paragraphs. When absent the
   /// footer is unchanged, so existing sites without this key render exactly as before.
   public let footerLegalNotice: String?
   /// Optional 2-tone brand for the appbar wordmark. When absent, the appbar falls back
   /// to rendering `config.name` as a plain single-color label.
   public let brand: DocCBrandConfig?
   /// Optional registry mapping framework slug → icon descriptor. Session notes declare
   /// their framework via `<!-- framework: <slug> -->` or via the central map at
   /// `sessionFrameworksPath`. The sidebar renders the matching FontAwesome glyph in the
   /// session-icon slot. When a note has no framework (or its key is absent from this map),
   /// the neutral placeholder is rendered instead.
   public let frameworks: [String: DocCFrameworkIcon]?
   /// Optional registry mapping a loose guide page's slug → a Font Awesome glyph class, e.g.
   /// `["contributing": "fa-solid fa-pen-to-square"]`. The sidebar renders the matching glyph
   /// in the icon slot of each loose (non-year) nav item, on a neutral chip tile. A guide whose
   /// slug is absent here (or any guide when this is `nil`) falls back to a sensible default
   /// glyph, never an empty placeholder, so a fresh docs site without this config still shows
   /// real icons. Inlined by `FontAwesomeInliner` (Phase 6), like the framework icons.
   public let guideIcons: [String: String]?
   /// Maximum number of top contributors shown in the collapsible Contributors subtree.
   /// When absent there is no cap – every contributor is shown.
   public let sidebarContributorsLimit: Int?
   /// Asset path for the avatar fallback image used when a contributor's GitHub avatar
   /// fails to load (e.g. `"avatar-fallback.svg"` → served from `/assets/avatar-fallback.svg`).
   /// When absent, broken avatars simply disappear (browser default for `onerror`).
   public let avatarFallbackPath: String?
   /// Path (relative to the project directory) to a flat JSON file mapping session ids to
   /// framework keys, e.g. `Sources/session-frameworks.json`. The key format is
   /// `wwdcYY-<code>` – the first two dash-separated segments of the note slug
   /// (e.g. `wwdc25-101-keynote` → key `wwdc25-101`, value `"design"`).
   ///
   /// When a note's `doccFramework` is already set (via a per-note comment or directive),
   /// the central map does NOT override it – per-note always wins.
   /// When the file is missing or unreadable the enricher is skipped gracefully.
   public let sessionFrameworksPath: String?
   /// Hero subtitle shown on the home page, separate from the SEO `description` so the
   /// hero copy can differ from the meta tag. Falls back to `SiteConfig.description` when nil.
   public let homeAbstract: String?
   /// Lead sentence below the Overview section heading ("three ways to navigate...").
   /// Omitted when nil. Has no effect unless `homeWays` is also populated.
   public let homeOverviewLead: String?
   /// Numbered "ways to use the site" items for the Overview section. The whole section is
   /// omitted when this is nil or empty so plain docs sites stay uncluttered.
   public let homeWays: [DocCHomeWayConfig]?
   /// Copy for the Contributing section (lead sentence + call-to-action link). The whole
   /// section is omitted when nil.
   public let homeContributing: DocCHomeContributingConfig?
   /// Blurb shown in the Contributors mosaic card in the Topics grid. Omitted when nil.
   public let homeContributorsBlurb: String?
   /// Per-year editorial data keyed by year label (e.g. "WWDC25"). Each entry can supply
   /// a stack line, blurb, highlighted APIs, and an explicit key-visual path.
   public let years: [String: DocCYearCardConfig]?
   /// URL for the "Become a contributor" button on the contributors page. When nil, the
   /// button is omitted entirely – safe for plain docs sites with no contributing guide.
   public let contributorsBecomeHref: String?
   /// URL for the "Learn how to contribute" call-to-action on the missing-sessions page.
   /// When nil, the CTA is omitted – plain docs sites without a contribution guide stay clean.
   public let missingContributeHref: String?
   /// Pre-populated search suggestion chip values shown in the search overlay below the
   /// input field when it is empty ("Try: …"). Consumed by the search overlay script.
   /// When nil or empty, no suggestions are shown.
   public let searchSuggestions: [String]?
   /// Default syntax-highlighting language for fenced code blocks that carry no language
   /// tag (e.g. a bare ` ``` ` fence). When set, untagged blocks are highlighted as if
   /// they were tagged with this language. When nil, untagged blocks render as plain
   /// escaped text (no coloring). Does not affect blocks that already carry an explicit
   /// language tag – those are always highlighted with their declared language.
   ///
   /// For WWDCNotes set this to `"swift"` since the majority of code examples are Swift.
   public let defaultCodeLanguage: String?
   /// Enables the contributors feature: the `/contributors/` overview page, per-contributor
   /// profile pages (`/contributors/<handle>/`), and the collapsible Contributors subtree in the
   /// sidebar. Defaults to `false` (see `contributorsEnabled`) so a generic docs site stays clean;
   /// catalogs that credit authors (e.g. WWDCNotes) opt in with `contributors: true`. Contributor
   /// parsing (`@Contributors`) always runs regardless of this flag – only the pages and routes gate.
   public let contributors: Bool?
   /// Enables the missing-sessions feature: the `/missingnotes/` page that lists catalog entries
   /// without notes yet. Defaults to `false` (see `missingSessionsEnabled`) – only catalogs that
   /// track coverage (e.g. WWDCNotes) need it.
   public let missingSessions: Bool?
   /// Enables the full-text search feature: the dedicated `/search/` page plus the sharded search
   /// index and its client scripts. Defaults to `true` (see `searchEnabled`) because search is
   /// broadly useful for any docs site. Set `search: false` to ship a search-free docs site.
   public let search: Bool?
   /// Enables the Note-type facet group (All/AI/Community/Stub) in the search page's filter aside.
   /// Defaults to `false` (see `searchNoteTypeFilterEnabled`): most catalogs hold a single note
   /// type, where the filter is noise. The note-type badges on result rows are unaffected –
   /// they render regardless of this flag.
   public let searchNoteTypeFilter: Bool?
   /// Visual style of the article/guide page header. `card` (the default, see
   /// `articleHeroStyle`) renders the gradient hero as a rounded card with inner padding and
   /// the decorative prism art panel – the same surface language as the home and contributors
   /// heroes. `band` renders it as a square-cornered color band that spans the full content
   /// pane (classic DocC look) with the text staying on the readable column width.
   /// Decoding fails loudly on any other value so a typo cannot silently fall back.
   public let articleHero: DocCArticleHeroStyle?

   /// Whether the contributors feature is enabled. Absent ⇒ `false` (clean default for generic docs).
   public var contributorsEnabled: Bool { self.contributors ?? false }
   /// Whether the missing-sessions feature is enabled. Absent ⇒ `false`.
   public var missingSessionsEnabled: Bool { self.missingSessions ?? false }
   /// Whether the full-text search feature is enabled. Absent ⇒ `true` (search is on by default).
   public var searchEnabled: Bool { self.search ?? true }
   /// Whether the search page offers the Note-type filter group. Absent ⇒ `false`.
   public var searchNoteTypeFilterEnabled: Bool { self.searchNoteTypeFilter ?? false }
   /// The article header style in effect. Absent ⇒ `.card` – the card matches the surface
   /// language of every other hero on the site, so it is the coherent default.
   public var articleHeroStyle: DocCArticleHeroStyle { self.articleHero ?? .card }

   /// Memberwise initializer; every feature defaults to "not configured".
   public init(
      homeEyebrow: String? = nil,
      footerCards: [DocCFooterCardConfig]? = nil,
      footerDisclaimer: String? = nil,
      footerLegalNotice: String? = nil,
      brand: DocCBrandConfig? = nil,
      frameworks: [String: DocCFrameworkIcon]? = nil,
      guideIcons: [String: String]? = nil,
      sidebarContributorsLimit: Int? = nil,
      avatarFallbackPath: String? = nil,
      sessionFrameworksPath: String? = nil,
      homeAbstract: String? = nil,
      homeOverviewLead: String? = nil,
      homeWays: [DocCHomeWayConfig]? = nil,
      homeContributing: DocCHomeContributingConfig? = nil,
      homeContributorsBlurb: String? = nil,
      years: [String: DocCYearCardConfig]? = nil,
      contributorsBecomeHref: String? = nil,
      missingContributeHref: String? = nil,
      searchSuggestions: [String]? = nil,
      defaultCodeLanguage: String? = nil,
      contributors: Bool? = nil,
      missingSessions: Bool? = nil,
      search: Bool? = nil,
      searchNoteTypeFilter: Bool? = nil,
      articleHero: DocCArticleHeroStyle? = nil
   ) {
      self.homeEyebrow = homeEyebrow
      self.footerCards = footerCards
      self.footerDisclaimer = footerDisclaimer
      self.footerLegalNotice = footerLegalNotice
      self.brand = brand
      self.frameworks = frameworks
      self.guideIcons = guideIcons
      self.sidebarContributorsLimit = sidebarContributorsLimit
      self.avatarFallbackPath = avatarFallbackPath
      self.sessionFrameworksPath = sessionFrameworksPath
      self.homeAbstract = homeAbstract
      self.homeOverviewLead = homeOverviewLead
      self.homeWays = homeWays
      self.homeContributing = homeContributing
      self.homeContributorsBlurb = homeContributorsBlurb
      self.years = years
      self.contributorsBecomeHref = contributorsBecomeHref
      self.missingContributeHref = missingContributeHref
      self.searchSuggestions = searchSuggestions
      self.defaultCodeLanguage = defaultCodeLanguage
      self.contributors = contributors
      self.missingSessions = missingSessions
      self.search = search
      self.searchNoteTypeFilter = searchNoteTypeFilter
      self.articleHero = articleHero
   }
}

/// The two header styles an article/guide page hero can render as, selected via the
/// `docc.articleHero` config key. Both are first-class blueprint options: `card` for sites
/// whose chrome speaks the rounded-card language, `band` for the classic full-width DocC look.
public enum DocCArticleHeroStyle: String, Codable, Sendable {
   /// Rounded gradient card with inner padding and the decorative prism art panel,
   /// matching the home/contributors hero surface.
   case card
   /// Square-cornered gradient band spanning the full content pane; the text keeps
   /// the readable column width.
   case band
}

/// The top-level configuration for a SiteKit site, decoded from
/// `SiteConfig.yaml`.
///
/// `SiteConfig` is the single declarative source of truth for the site's
/// identity (`name`, `baseURL`, `language`, `author`), its content layout
/// (`sections`, `categories`, legacy `blogURLPrefix` / `snippetsURLPrefix`),
/// its chrome (`navigation`, `footer`, `homePage`, `errorPages`), and its
/// optional integrations (`theme`, `promotions`, `localization`,
/// `redirectsFile`, `podcast`). Every plugin sees the decoded config through
/// `BuildContext.config`.
///
/// Decoding is lenient about legacy field names (`defaultLanguage` →
/// `language`). Section resolution has a backward-compatible synthesis path:
/// if `sections` is omitted the `effectiveSections` getter builds one from
/// the legacy fields.
public struct SiteConfig: Codable, Sendable {
   /// Site name – header brand text, feed channel titles, title-tag suffix.
   public let name: String

   /// Absolute production origin (e.g. `https://example.com`, no trailing
   /// slash). Every emitted absolute URL – canonical, OG, sitemap, feeds –
   /// derives from it; the `--base-url` CLI option overrides it per build.
   public let baseURL: String

   /// Primary language as a BCP 47 code; `"en"` when neither `language:` nor
   /// the legacy `defaultLanguage:` is set.
   public let language: String

   /// Site-wide author – default page author, feed-level author, podcast
   /// owner contact.
   public let author: Person?

   /// Site-wide meta description; empty string when not set.
   public let description: String

   /// Directory holding all content sources, relative to the project root –
   /// `"Content"` by convention. Required in YAML.
   public let contentDirectory: String

   /// Directory the build writes into, relative to the project root –
   /// `"_Site"` by convention. Required in YAML; wiped before each build
   /// unless `--no-clean`.
   public let outputDirectory: String

   /// Directory of static assets teleported into the output, relative to the
   /// project root; defaults to `"Content/Assets"`.
   public let assetsDirectory: String

   /// Legacy top-level category taxonomy, consumed by the synthesized blog
   /// section when no `sections:` are declared; empty when absent. New
   /// configs declare categories per section.
   public let categories: [CategoryConfig]

   /// Header navigation (logo, links, widget toggles); nil renders default
   /// chrome.
   public let navigation: NavigationConfig?

   /// Footer (links, social icons, copyright); nil renders a minimal footer.
   public let footer: FooterConfig?

   /// Home page hero and recent-posts settings.
   public let homePage: HomePageConfig?

   /// Custom error page copy keyed by status code; only `"404"` is consumed.
   public let errorPages: [String: ErrorPageConfig]?

   /// Theme directory reference; nil uses the `Theme/` convention path.
   public let theme: ThemeRefConfig?

   /// Maps tag slugs to display names (e.g. `swiftui` → "SwiftUI") wherever
   /// tags render as visible text.
   public let tagDisplayNames: [String: String]?

   /// The declared content sections. Nil or empty falls back to a synthesized
   /// blog (+ optional snippets) section from the legacy fields – see
   /// `effectiveSections`.
   public let sections: [SectionConfig]?

   /// Legacy URL prefix for blog articles, used only by the synthesized
   /// section path and the section-less router methods.
   public let blogURLPrefix: String?

   /// Legacy URL prefix for snippets; its presence adds a snippets section to
   /// the synthesized fallback.
   public let snippetsURLPrefix: String?

   /// The promotion system (slots, audiences, card pool); nil disables
   /// promotions.
   public let promotions: PromotionsConfig?

   /// Multilingual setup; nil (or an empty `languages` list) keeps the build
   /// single-language.
   public let localization: LocalizationConfig?

   /// Project-relative path of a redirects YAML (`RedirectsFileConfig` shape).
   /// Feeds both the Cloudflare `_redirects` renderer and the HTML redirect
   /// stubs; nil emits neither.
   public let redirectsFile: String?

   /// Podcast feed and showcase settings; nil on non-podcast sites.
   public let podcast: PodcastConfig?

   /// DocC blueprint settings; nil on non-DocC sites (a DocC build then uses
   /// the `DocCConfig()` defaults).
   public let docc: DocCConfig?

   /// Resolved sections array – uses explicit `sections` if provided,
   /// otherwise synthesizes from legacy `blogURLPrefix`/`categories`/`snippetsURLPrefix`.
   public var effectiveSections: [SectionConfig] {
      if let sections, !sections.isEmpty {
         return sections
      }
      // Backward compatibility: synthesize from legacy fields
      var result: [SectionConfig] = []
      result.append(SectionConfig(
         name: "Blog",
         slug: "blog",
         contentDirectory: "Blog",
         urlPrefix: self.blogURLPrefix ?? "blog",
         categories: self.categories.isEmpty ? nil : self.categories
      ))
      if self.snippetsURLPrefix != nil {
         result.append(SectionConfig(
            name: "Snippets",
            slug: "snippets",
            contentDirectory: "Snippets",
            urlPrefix: self.snippetsURLPrefix ?? "snippets",
            style: "short"
         ))
      }
      return result
   }

   /// The effective default language, considering both `language` and `localization.defaultLanguage`.
   public var effectiveDefaultLanguage: String {
      self.localization?.defaultLanguage ?? self.language
   }

   /// All configured languages including the default.
   public var allLanguages: [String] {
      guard let locConfig = self.localization, !locConfig.languages.isEmpty else {
         return [self.language]
      }
      return [locConfig.defaultLanguage] + locConfig.languages
   }

   /// The legal jurisdiction language for legal documents (e.g. imprint, privacy policy).
   /// Falls back to `effectiveDefaultLanguage` when not explicitly set.
   public var effectiveLegalLanguage: String {
      self.localization?.legalLanguage ?? self.effectiveDefaultLanguage
   }

   /// Whether this site has multiple languages configured.
   public var isMultilingual: Bool {
      guard let locConfig = self.localization else { return false }
      return !locConfig.languages.isEmpty
   }

   /// Memberwise initializer – primarily for tests and programmatic builds;
   /// sites declare their configuration in `SiteConfig.yaml` and load it via
   /// `load(from:)` / `load(contentsOf:)`.
   public init(
      name: String,
      baseURL: String,
      language: String = "en",
      author: Person? = nil,
      description: String = "",
      contentDirectory: String = "Content",
      outputDirectory: String = "_Site",
      assetsDirectory: String = "Content/Assets",
      categories: [CategoryConfig] = [],
      navigation: NavigationConfig? = nil,
      footer: FooterConfig? = nil,
      homePage: HomePageConfig? = nil,
      errorPages: [String: ErrorPageConfig]? = nil,
      theme: ThemeRefConfig? = nil,
      tagDisplayNames: [String: String]? = nil,
      sections: [SectionConfig]? = nil,
      blogURLPrefix: String? = nil,
      snippetsURLPrefix: String? = nil,
      promotions: PromotionsConfig? = nil,
      localization: LocalizationConfig? = nil,
      redirectsFile: String? = nil,
      podcast: PodcastConfig? = nil,
      docc: DocCConfig? = nil
   ) {
      self.name = name
      self.baseURL = baseURL
      self.language = language
      self.author = author
      self.description = description
      self.contentDirectory = contentDirectory
      self.outputDirectory = outputDirectory
      self.assetsDirectory = assetsDirectory
      self.categories = categories
      self.navigation = navigation
      self.footer = footer
      self.homePage = homePage
      self.errorPages = errorPages
      self.theme = theme
      self.tagDisplayNames = tagDisplayNames
      self.sections = sections
      self.blogURLPrefix = blogURLPrefix
      self.snippetsURLPrefix = snippetsURLPrefix
      self.promotions = promotions
      self.localization = localization
      self.redirectsFile = redirectsFile
      self.podcast = podcast
      self.docc = docc
   }

   /// Returns a copy of this configuration with `baseURL` replaced and every other
   /// field preserved. Backs the `--base-url` CLI override: the rest of the decoded
   /// YAML stays the single source of truth, only the deploy-target origin changes.
   func replacingBaseURL(with newBaseURL: String) -> SiteConfig {
      SiteConfig(
         name: self.name,
         baseURL: newBaseURL,
         language: self.language,
         author: self.author,
         description: self.description,
         contentDirectory: self.contentDirectory,
         outputDirectory: self.outputDirectory,
         assetsDirectory: self.assetsDirectory,
         categories: self.categories,
         navigation: self.navigation,
         footer: self.footer,
         homePage: self.homePage,
         errorPages: self.errorPages,
         theme: self.theme,
         tagDisplayNames: self.tagDisplayNames,
         sections: self.sections,
         blogURLPrefix: self.blogURLPrefix,
         snippetsURLPrefix: self.snippetsURLPrefix,
         promotions: self.promotions,
         localization: self.localization,
         redirectsFile: self.redirectsFile,
         podcast: self.podcast,
         docc: self.docc
      )
   }

   /// Loads the site configuration from `<directory>/SiteConfig.yaml`.
   public static func load(from directory: URL) throws -> SiteConfig {
      try self.load(contentsOf: directory.appendingPathComponent("SiteConfig.yaml"))
   }

   /// Loads the site configuration from the given YAML file, whatever its name.
   ///
   /// Backs the `configPath:` convenience factories on `SiteBuilder`, which resolve
   /// their path argument against the working directory and pass the result here – so
   /// a site can keep multiple configurations side by side (e.g. a staging variant)
   /// and select one per build.
   public static func load(contentsOf fileURL: URL) throws -> SiteConfig {
      guard FileManager.default.fileExists(atPath: fileURL.path) else {
         throw SiteConfigError.fileNotFound(fileURL)
      }

      do {
         let source = try YAMLSource(url: fileURL)
         return try YAMLLoader<SiteConfig>().load(source: source)
      } catch is SiteConfigError {
         throw SiteConfigError.fileNotFound(fileURL)
      } catch {
         // String(describing:) keeps the decoder's structured detail (key, type,
         // coding path); localizedDescription would flatten a DecodingError to the
         // unhelpful generic "The data couldn't be read" line.
         throw SiteConfigError.invalidYAML(String(describing: error))
      }
   }

   private enum CodingKeys: String, CodingKey {
      case name, baseURL, language, author, description
      case contentDirectory, outputDirectory, assetsDirectory, categories
      case navigation, footer, homePage, errorPages, theme, tagDisplayNames
      case sections, blogURLPrefix, snippetsURLPrefix, promotions
      case localization, redirectsFile, podcast, docc
   }

   private enum LegacyCodingKeys: String, CodingKey {
      case defaultLanguage
   }

   /// Decodes `SiteConfig.yaml`, accepting the legacy `defaultLanguage:` key
   /// as a fallback for `language:` and defaulting the optional scalars
   /// (`description` → empty, `assetsDirectory` → `Content/Assets`,
   /// `categories` → empty).
   public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.baseURL = try container.decode(String.self, forKey: .baseURL)
      if let lang = try container.decodeIfPresent(String.self, forKey: .language) {
         self.language = lang
      } else {
         let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
         self.language = try legacy.decodeIfPresent(String.self, forKey: .defaultLanguage) ?? "en"
      }
      self.author = try container.decodeIfPresent(Person.self, forKey: .author)
      self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
      self.contentDirectory = try container.decode(String.self, forKey: .contentDirectory)
      self.outputDirectory = try container.decode(String.self, forKey: .outputDirectory)
      self.assetsDirectory = try container.decodeIfPresent(String.self, forKey: .assetsDirectory) ?? "Content/Assets"
      self.categories = try container.decodeIfPresent([CategoryConfig].self, forKey: .categories) ?? []
      self.navigation = try container.decodeIfPresent(NavigationConfig.self, forKey: .navigation)
      self.footer = try container.decodeIfPresent(FooterConfig.self, forKey: .footer)
      self.homePage = try container.decodeIfPresent(HomePageConfig.self, forKey: .homePage)
      self.errorPages = try container.decodeIfPresent([String: ErrorPageConfig].self, forKey: .errorPages)
      self.theme = try container.decodeIfPresent(ThemeRefConfig.self, forKey: .theme)
      self.tagDisplayNames = try container.decodeIfPresent([String: String].self, forKey: .tagDisplayNames)
      self.sections = try container.decodeIfPresent([SectionConfig].self, forKey: .sections)
      self.blogURLPrefix = try container.decodeIfPresent(String.self, forKey: .blogURLPrefix)
      self.snippetsURLPrefix = try container.decodeIfPresent(String.self, forKey: .snippetsURLPrefix)
      self.promotions = try container.decodeIfPresent(PromotionsConfig.self, forKey: .promotions)
      self.localization = try container.decodeIfPresent(LocalizationConfig.self, forKey: .localization)
      self.redirectsFile = try container.decodeIfPresent(String.self, forKey: .redirectsFile)
      self.podcast = try container.decodeIfPresent(PodcastConfig.self, forKey: .podcast)
      self.docc = try container.decodeIfPresent(DocCConfig.self, forKey: .docc)
   }
}
