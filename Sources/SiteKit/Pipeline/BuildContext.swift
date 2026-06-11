import Foundation

/// One content section (e.g. "blog", "snippets", "podcast") paired with the
/// pages that belong to it.
///
/// `ContentSection` is the unit `BuildContext.sections` is built out of. The
/// `config` carries the section's declared slug, URL prefix, category list,
/// and topic groups; `pages` is the loaded + enriched `PageModel` set for
/// that section. Renderers locate "their" section by `config.slug`.
public struct ContentSection {
   /// The section's declaration from `SiteConfig` – slug, URL prefix, name,
   /// categories, topic groups.
   public let config: SectionConfig

   /// The section's loaded + enriched pages, drafts excluded, sorted newest
   /// first.
   public let pages: [PageModel]

   /// Pairs a section declaration with its loaded pages.
   public init(config: SectionConfig, pages: [PageModel]) {
      self.config = config
      self.pages = pages
   }
}

/// Read-only snapshot of the site, passed to every phase-3-through-6 plugin.
///
/// `BuildContext` is the shared, immutable state that lets `Renderer`s,
/// `Page`s, `Enricher`s, and `OutputProcessor`s read what the build has
/// discovered and loaded without re-touching the filesystem. It bundles the
/// decoded `SiteConfig`, the optional `ThemeConfig`, the loaded
/// `ContentSection`s, static pages, the tag inverse-index, the per-locale
/// `URLRouter` and `UIStrings`, plus the project + output directories.
///
/// Plugins read from it; they do not mutate it. On multilingual sites, the
/// pipeline constructs one `BuildContext` per locale for `.perLocale`
/// renderers and uses the default-locale context for `.global` renderers.
public struct BuildContext {
   /// The decoded `SiteConfig.yaml` – site identity, sections, localization,
   /// promotions, feature config.
   public let config: SiteConfig

   /// The decoded `Theme/theme.yaml`; nil when no theme config could be loaded.
   public let themeConfig: ThemeConfig?

   /// One entry per declared content section, each carrying its loaded pages
   /// (drafts excluded, sorted newest first).
   public let sections: [ContentSection]

   /// The loaded top-level pages from the static `Pages/` directory (about,
   /// privacy, …), drafts excluded. The home page is not among them – its body
   /// is `homeContent`.
   public let staticPages: [PageModel]

   /// Inverse index tag → pages carrying that tag, across all sections. Powers
   /// the `/tags/<slug>/` listing pages.
   public let tags: [String: [PageModel]]

   /// The rendered HTML body of `Pages/home.md` (locale-specific `home.<lang>.md`
   /// when present); nil when the site has no home Markdown file.
   public let homeContent: String?

   /// Locale-aware URL builder for every internal link. On multilingual sites
   /// this is a `LocaleAwareURLRouter` that prefixes non-default locales
   /// (`/de/...`); always route URLs through it instead of concatenating paths.
   public let router: any URLRouter

   /// Localized UI strings (nav labels, notices, date formats) for the locale
   /// this context was built for.
   public let uiStrings: UIStrings

   /// Absolute URL of the output directory (`_Site/` by default) that all
   /// `OutputFile.outputPath`s should live under.
   public let outputDirectory: URL

   /// Absolute URL of the site project root – the directory containing
   /// `SiteConfig.yaml`, `Content/`, and `Theme/`.
   public let projectDirectory: URL

   /// All pages marked `draft: true`, kept out of `sections`/`staticPages`.
   /// Consumed by `DraftPreviewRenderer` to emit tokenized preview URLs.
   public let draftPages: [PageModel]

   /// Backward-compatible: articles from the first section (typically "blog").
   public var articles: [PageModel] {
      self.sections.first(where: { $0.config.slug == "blog" })?.pages ?? self.sections.first?.pages ?? []
   }

   /// Backward-compatible: snippets from the "snippets" section.
   @available(*, deprecated, message: "Use sections instead")
   public var snippets: [PageModel] {
      self.sections.first(where: { $0.config.slug == "snippets" })?.pages ?? []
   }

   /// Assembles a context for one build pass. `router` defaults to a
   /// `DefaultURLRouter` over `config`; `uiStrings` defaults to the bundle for
   /// `config.language` – the multilingual pipeline passes locale-specific
   /// values for both.
   public init(
      config: SiteConfig,
      themeConfig: ThemeConfig?,
      sections: [ContentSection],
      staticPages: [PageModel],
      tags: [String: [PageModel]],
      homeContent: String?,
      router: (any URLRouter)? = nil,
      uiStrings: UIStrings? = nil,
      outputDirectory: URL,
      projectDirectory: URL,
      draftPages: [PageModel] = []
   ) {
      self.config = config
      self.themeConfig = themeConfig
      self.sections = sections
      self.staticPages = staticPages
      self.tags = tags
      self.homeContent = homeContent
      self.router = router ?? DefaultURLRouter(config: config)
      self.uiStrings = uiStrings ?? UIStrings(locale: config.language, projectDirectory: projectDirectory)
      self.outputDirectory = outputDirectory
      self.projectDirectory = projectDirectory
      self.draftPages = draftPages
   }
}
