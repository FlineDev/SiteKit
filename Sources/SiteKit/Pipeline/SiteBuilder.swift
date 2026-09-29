import Foundation
import Logging

/// Fluent builder for composing a BuildPipeline from phase plugins.
///
/// Use preset recipes for common site types, or compose a custom pipeline:
///
/// ```swift
/// // Preset recipe (returns SiteBuilder, call .run() to execute)
/// try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()
///
/// // Custom composition
/// try SiteBuilder(config: config, projectDirectory: dir)
///    .enricher(MyEnricher())
///    .renderer(ArticlePageRenderer())
///    .renderer(HomePageRenderer())
///    .renderer(SitemapRenderer())
///    .run()
/// ```
public struct SiteBuilder {
   private var config: SiteConfig
   private let projectDirectory: URL
   private var cleanBeforeBuild: Bool = true
   private var contentDiscovery: (any ContentDiscovery)?
   private var articleLoader: (any Loader<MarkdownSource, PageModel>)?
   private var staticPageLoader: (any Loader<MarkdownSource, PageModel>)?
   private var teleporter: (any Teleporter)?
   private var additionalTeleporters: [any Teleporter] = []
   private var enrichers: [any Enricher] = []
   private var renderers: [any Renderer] = []
   private var processors: [any OutputProcessor]?
   private var contentSectionProviders: [any ContentSectionProviding] = []

   /// Creates a bare builder with no plugins registered – the starting point for
   /// fully custom pipelines. Phases left unconfigured fall back to the pipeline
   /// defaults (`MarkdownContentDiscovery`, `MarkdownLoader`, `AssetCopier`, the
   /// blog renderer set, the default processor chain); prefer a blueprint factory
   /// like `blog(config:projectDirectory:)` when those presets fit.
   public init(config: SiteConfig, projectDirectory: URL) {
      self.config = config
      self.projectDirectory = projectDirectory
   }

   // MARK: - Fluent Configuration

   /// Returns a copy that wipes (`true`, the default) or keeps (`false`) the
   /// output directory before building. Backs the `--no-clean` CLI flag; keep
   /// the directory when an external step has already placed files there.
   public func cleanBeforeBuild(_ clean: Bool) -> SiteBuilder {
      var copy = self
      copy.cleanBeforeBuild = clean
      return copy
   }

   /// Returns a copy of this builder whose configuration uses the given base URL.
   ///
   /// Every absolute URL the pipeline emits (canonical and og:url tags, sitemap,
   /// RSS feeds, llms.txt, machine indexes, hreflang alternates, redirect stubs)
   /// derives from `SiteConfig.baseURL`, so swapping it here re-targets the whole
   /// build. Backs the `--base-url` CLI option, which lets a deploy workflow build
   /// the same site for a staging origin while the YAML keeps the production truth.
   ///
   /// Most plugins read the configuration through `BuildContext` at render time and
   /// pick up the replacement automatically. `HreflangEnricher` is the one shipped
   /// plugin that captures the base URL when the blueprint factory composes the
   /// builder, so its registered instances are re-targeted explicitly. Custom
   /// user-registered plugins that captured `config.baseURL` at their own init are
   /// out of reach of this override; reading from `BuildContext` avoids that.
   func baseURL(_ newBaseURL: String) -> SiteBuilder {
      var copy = self
      copy.config = self.config.replacingBaseURL(with: newBaseURL)
      copy.enrichers = self.enrichers.map { enricher in
         (enricher as? HreflangEnricher)?.replacingBaseURL(with: newBaseURL) ?? enricher
      }
      return copy
   }

   /// Returns a copy using `discovery` to find content source files (phase 1)
   /// instead of the default flat-directory `MarkdownContentDiscovery`. Only
   /// single-language builds consult it – multilingual builds route through
   /// `LocalizedContentDiscovery`.
   public func contentDiscovery(_ discovery: any ContentDiscovery) -> SiteBuilder {
      var copy = self
      copy.contentDiscovery = discovery
      return copy
   }

   /// Returns a copy using `loader` to parse section content (articles, episodes,
   /// notes) into `PageModel`s (phase 2). The blueprint factories register a
   /// `MarkdownLoader` here with site-type-specific `requiredFields`.
   public func articleLoader(_ loader: any Loader<MarkdownSource, PageModel>) -> SiteBuilder {
      var copy = self
      copy.articleLoader = loader
      return copy
   }

   /// Returns a copy using `loader` to parse the static `Pages/` directory
   /// (about, privacy, …) into `PageModel`s (phase 2). Defaults to
   /// `StaticPageLoader`, which requires `title` and `slug` frontmatter.
   public func staticPageLoader(_ loader: any Loader<MarkdownSource, PageModel>) -> SiteBuilder {
      var copy = self
      copy.staticPageLoader = loader
      return copy
   }

   /// Returns a copy that registers `provider` to contribute a synthetic content section
   /// (pages generated rather than loaded from files) to the build. The pipeline merges the
   /// provided section into `BuildContext.sections` after file loading, so the machine-index
   /// renderers (sitemap, nav-index, search, llms.txt) enumerate the generated pages. The
   /// OpenAPI blueprint uses this to register its spec-derived pages once and have all four
   /// indexes include them.
   public func contentSectionProvider(_ provider: any ContentSectionProviding) -> SiteBuilder {
      var copy = self
      copy.contentSectionProviders.append(provider)
      return copy
   }

   /// Returns a copy using `teleporter` to copy content and theme assets into
   /// the output directory (phase 0) instead of the default `AssetCopier`.
   /// Replaces the primary teleporter – use `additionalTeleporter(_:)` to add
   /// one without replacing it.
   public func teleporter(_ teleporter: any Teleporter) -> SiteBuilder {
      var copy = self
      copy.teleporter = teleporter
      return copy
   }

   /// Appends an additional teleporter that runs after the primary one.
   /// Useful for DocC-specific asset pipelines that must not replace the standard
   /// `AssetCopier` but need to emit extra assets (e.g. catalog images) into the
   /// same output directory.
   public func additionalTeleporter(_ teleporter: any Teleporter) -> SiteBuilder {
      var copy = self
      copy.additionalTeleporters.append(teleporter)
      return copy
   }

   /// Appends an enricher to the chain (phase 3). Enrichers run in registration
   /// order on every loaded page; the blueprint factories append their built-ins
   /// (`PromotionEnricher`, `HreflangEnricher`) after user-supplied ones.
   public func enricher(_ enricher: any Enricher) -> SiteBuilder {
      var copy = self
      copy.enrichers.append(enricher)
      return copy
   }

   /// Appends a renderer (phases 4–5). HTML `Page` conformers and system
   /// renderers share this one registration surface; the pipeline dispatches
   /// each by its declared `scope`. On a blueprint-composed builder this adds
   /// to the preset renderer list – use `replacing(_:with:)` / `removing(_:)`
   /// to modify the presets instead.
   public func renderer(_ renderer: any Renderer) -> SiteBuilder {
      var copy = self
      copy.renderers.append(renderer)
      return copy
   }

   /// Appends an output processor to the explicitly configured list (phase 6).
   /// Processors run after all renderers, see the final HTML on disk, and can
   /// transform it in-place.
   ///
   /// The first call starts a FRESH list: the pipeline's default chain
   /// (`ImageResizer` → `FontAwesomeInliner` → `CSSBackgroundImageProcessor` →
   /// `AssetMinifier` → `AssetFingerprinter`) applies only while no processor is
   /// configured, so a single `.processor(X)` builds with `[X]` alone – image
   /// variants, minification, and fingerprinting will NOT run. To extend the
   /// defaults instead of replacing them, pass the full chain plus your processor
   /// to `processors(_:)`.
   public func processor(_ processor: any OutputProcessor) -> SiteBuilder {
      var copy = self
      if copy.processors == nil { copy.processors = [] }
      copy.processors?.append(processor)
      return copy
   }

   /// Replaces the entire processors list (phase 6). Pass nil to restore the
   /// pipeline default chain: `ImageResizer` → `FontAwesomeInliner` →
   /// `CSSBackgroundImageProcessor` → `AssetMinifier` → `AssetFingerprinter`.
   public func processors(_ processors: [any OutputProcessor]?) -> SiteBuilder {
      var copy = self
      copy.processors = processors
      return copy
   }

   // MARK: - Renderer Set Operations

   /// Populates the builder with all default blog renderers.
   /// Use with `replacing(_:with:)` or `removing(_:)` to customize.
   ///
   /// ```swift
   /// SiteBuilder(config: config, projectDirectory: dir)
   ///    .defaultBlogRenderers()
   ///    .removing(LlmsTxtRenderer.self)
   ///    .replacing(HomePageRenderer.self, with: MyHomePageRenderer())
   ///    .run()
   /// ```
   public func defaultBlogRenderers() -> SiteBuilder {
      var copy = self
      copy.renderers = Self.blogRenderers
      return copy
   }

   /// Replaces a renderer by type. If the type is not found, appends the replacement.
   public func replacing<T: Renderer>(_ type: T.Type, with replacement: any Renderer) -> SiteBuilder {
      var copy = self
      let typeName = String(describing: type)
      if let index = copy.renderers.firstIndex(where: { String(describing: Swift.type(of: $0)) == typeName }) {
         copy.renderers[index] = replacement
      } else {
         copy.renderers.append(replacement)
      }
      return copy
   }

   /// Removes a renderer by type. No-op if the type is not found.
   public func removing<T: Renderer>(_ type: T.Type) -> SiteBuilder {
      var copy = self
      let typeName = String(describing: type)
      copy.renderers.removeAll { String(describing: Swift.type(of: $0)) == typeName }
      return copy
   }

   // MARK: - Enricher Set Operations

   /// Replaces an enricher by type. If the type is not found, appends the replacement.
   ///
   /// Mirrors `replacing(_:with:)` for renderers – useful for swapping out a
   /// preset-registered enricher (e.g., the default `HreflangEnricher`) for a custom one.
   public func replacingEnricher<T: Enricher>(_ type: T.Type, with replacement: any Enricher) -> SiteBuilder {
      var copy = self
      let typeName = String(describing: type)
      if let index = copy.enrichers.firstIndex(where: { String(describing: Swift.type(of: $0)) == typeName }) {
         copy.enrichers[index] = replacement
      } else {
         copy.enrichers.append(replacement)
      }
      return copy
   }

   /// Removes an enricher by type. No-op if the type is not found.
   ///
   /// Mirrors `removing(_:)` for renderers – useful for opting out of a preset-registered
   /// enricher (e.g., disabling the default `HreflangEnricher` on a multilingual site).
   public func removingEnricher<T: Enricher>(_ type: T.Type) -> SiteBuilder {
      var copy = self
      let typeName = String(describing: type)
      copy.enrichers.removeAll { String(describing: Swift.type(of: $0)) == typeName }
      return copy
   }

   /// The type names of every registered renderer, in registration order. Kept `internal` so
   /// `@testable` builds can assert on pipeline composition (e.g. which DocC feature pages were
   /// registered) without widening the public API.
   var registeredRendererTypeNames: [String] {
      self.renderers.map { String(describing: type(of: $0)) }
   }

   /// The registered renderer instances, in registration order. Internal for the same reason
   /// as `registeredRendererTypeNames`: lets `@testable` builds assert on wiring details
   /// (e.g. which path resolvers a machine-index renderer received).
   var registeredRenderers: [any Renderer] {
      self.renderers
   }

   // MARK: - Build Pipeline

   /// Materializes the composed configuration into an executable `BuildPipeline`.
   /// Unconfigured slots fall back to the pipeline defaults (an empty renderer
   /// list becomes `SiteBuilder.blogRenderers`). Call this directly for
   /// programmatic builds; `run()` goes through it for the CLI commands.
   public func buildPipeline() -> BuildPipeline {
      BuildPipeline(
         config: self.config,
         projectDirectory: self.projectDirectory,
         cleanBeforeBuild: self.cleanBeforeBuild,
         contentDiscovery: self.contentDiscovery,
         articleLoader: self.articleLoader,
         staticPageLoader: self.staticPageLoader,
         teleporter: self.teleporter,
         additionalTeleporters: self.additionalTeleporters,
         enrichers: self.enrichers,
         renderers: self.renderers.isEmpty ? nil : self.renderers,
         processors: self.processors,
         contentSectionProviders: self.contentSectionProviders
      )
   }

   // MARK: - Default Renderer Lists

   /// The standard set of renderers for a blog site.
   public static var blogRenderers: [any Renderer] {
      [
         SectionPageRenderer(),
         SectionListingRenderer(),
         CategoryListingRenderer(),
         TagListingRenderer(),
         StaticPageRenderer(),
         HomePageRenderer(),
         ErrorPageRenderer(),
         RSSFeedRenderer(),
         SitemapRenderer(),
         RobotsTxtRenderer(),
         NavIndexRenderer(),
         TokenCSSOutputRenderer(),
         BaseCSSOutputRenderer(),
         FontsFaceCSSRenderer(),
         CloudflareHeadersRenderer(),
         HTMLRedirectPageRenderer(),
         CloudflareRedirectsRenderer(),
         LanguageRedirectRenderer(),
         FaviconRenderer(),
         LlmsTxtRenderer(),
         ContentIndexRenderer(),
         DraftPreviewRenderer(),
      ]
   }

   /// The standard set of renderers for a podcast site.
   public static var podcastRenderers: [any Renderer] {
      [
         PodcastEpisodeRenderer(),
         PodcastListingRenderer(),
         PodcastHomePageRenderer(),
         PodcastRSSRenderer(),
         TemplateStaticPageRenderer(),
         TagListingRenderer(),
         ErrorPageRenderer(),
         SitemapRenderer(),
         RobotsTxtRenderer(),
         NavIndexRenderer(),
         TokenCSSOutputRenderer(),
         BaseCSSOutputRenderer(),
         FontsFaceCSSRenderer(),
         CloudflareHeadersRenderer(),
         HTMLRedirectPageRenderer(),
         CloudflareRedirectsRenderer(),
         FaviconRenderer(),
         LlmsTxtRenderer(),
         ContentIndexRenderer(),
         DraftPreviewRenderer(),
      ]
   }

   /// Populates the builder with all default podcast renderers.
   public func defaultPodcastRenderers() -> SiteBuilder {
      var copy = self
      copy.renderers = Self.podcastRenderers
      return copy
   }

   /// The standard set of renderers for a newsletter site.
   /// Blog renderers plus email HTML generation via EmailRenderer.
   public static var newsletterRenderers: [any Renderer] {
      blogRenderers + [EmailRenderer()]
   }

   /// Populates the builder with all default newsletter renderers.
   public func defaultNewsletterRenderers() -> SiteBuilder {
      var copy = self
      copy.renderers = Self.newsletterRenderers
      return copy
   }

   // MARK: - Preset Recipes (return SiteBuilder for .run() chaining)

   /// Full blog site with articles, categories, tags, RSS, sitemap, and all standard pages.
   ///
   /// Default enricher chain: user-supplied `enrichers` first, then `PromotionEnricher`
   /// (always – gated at runtime by `config.promotions`), then `HreflangEnricher`
   /// (only when `config.isMultilingual`). The order preserves today's runtime behavior
   /// where user enrichers can mutate page metadata before promotion selection runs.
   public static func blog(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .articleLoader(MarkdownLoader(requiredFields: ["title", "date"], language: config.language))

      for enricher in enrichers {
         builder = builder.enricher(enricher)
      }
      builder = builder.enricher(PromotionEnricher(config: config))
      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      return builder.defaultBlogRenderers()
   }

   /// Portfolio or landing page site: static pages, home page, sitemap, and error page.
   /// No blog, no RSS, no tags.
   public static func portfolio(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .articleLoader(MarkdownLoader(requiredFields: ["title", "date"], language: config.language))

      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      return
         builder
         .renderer(StaticPageRenderer())
         .renderer(HomePageRenderer())
         .renderer(ErrorPageRenderer())
         .renderer(SitemapRenderer())
         .renderer(RobotsTxtRenderer())
         .renderer(TokenCSSOutputRenderer())
         .renderer(BaseCSSOutputRenderer())
         .renderer(FontsFaceCSSRenderer())
         .renderer(CloudflareHeadersRenderer())
         .renderer(FaviconRenderer())
         .renderer(LlmsTxtRenderer())
   }

   /// Podcast site with episodes, iTunes RSS, episode listing, and optional host showcase.
   /// No categories, no blog-style articles – episodes are the primary content.
   ///
   /// Default enricher chain: user-supplied `enrichers` first, then `HreflangEnricher`
   /// (only when `config.isMultilingual`). PromotionEnricher is intentionally not
   /// registered here since podcast renderers don't read `extensions["promotion"]`.
   public static func podcast(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .articleLoader(
            MarkdownLoader(
               requiredFields: ["title", "date", "audioURL", "duration"],
               language: config.language
            )
         )

      for enricher in enrichers {
         builder = builder.enricher(enricher)
      }
      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      return builder.defaultPodcastRenderers()
   }

   /// Newsletter site with issue archive, email HTML rendering, tags, RSS, and all standard pages.
   /// Same blog renderers plus EmailRenderer for generating email-safe HTML at `_Site/email/<slug>.html`.
   ///
   /// Default enricher chain: user-supplied `enrichers` first, then `PromotionEnricher`
   /// (gated at runtime by `config.promotions`), then `HreflangEnricher` (only when
   /// `config.isMultilingual`). Same shape as `blog(...)` because newsletter sites use
   /// the same article renderer that consumes `extensions["promotion"]`.
   public static func newsletter(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .articleLoader(MarkdownLoader(requiredFields: ["title", "date"], language: config.language))

      for enricher in enrichers {
         builder = builder.enricher(enricher)
      }
      builder = builder.enricher(PromotionEnricher(config: config))
      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      return builder.defaultNewsletterRenderers()
   }

   /// Documentation site: static pages with sitemap. No blog, no RSS, no tags.
   /// Same as portfolio for now – future versions may add sidebar navigation.
   public static func docs(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true
   ) -> SiteBuilder {
      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)

      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      return
         builder
         .renderer(StaticPageRenderer())
         .renderer(HomePageRenderer())
         .renderer(ErrorPageRenderer())
         .renderer(SitemapRenderer())
         .renderer(RobotsTxtRenderer())
         .renderer(TokenCSSOutputRenderer())
         .renderer(BaseCSSOutputRenderer())
         .renderer(FontsFaceCSSRenderer())
         .renderer(CloudflareHeadersRenderer())
         .renderer(FaviconRenderer())
         .renderer(LlmsTxtRenderer())
   }

   /// DocC documentation site: renders a `.docc` catalog (DocC Markdown plus
   /// directives) to static HTML. Composes the DocC discovery → loader → page →
   /// cross-reference stack so a catalog of notes becomes AI-fetchable, accessible
   /// static pages – unlike DocC's own client-side SPA, where `curl`/crawlers see
   /// an empty shell. Sitemap, robots, CSS, favicons, and the search/nav index
   /// ship as standard. `<doc:>` cross-references resolve under the first declared
   /// section's URL prefix (default `documentation`).
   public static func docc(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      highlighter: (any CodeHighlighting)? = nil
   ) -> SiteBuilder {
      let urlPrefix = config.effectiveSections.first?.urlPrefix ?? "documentation"

      let contentDirectory = projectDirectory.appendingPathComponent(config.contentDirectory)

      var builder = SiteBuilder(config: config, projectDirectory: projectDirectory)
         .cleanBeforeBuild(cleanBeforeBuild)
         .contentDiscovery(DocCCatalogDiscovery())
         .articleLoader(DocCLoader(language: config.language, defaultCodeLanguage: config.docc?.defaultCodeLanguage, highlighter: highlighter))
         // Emit every *.docc/Images/ asset into output /assets/ so @PageImage icon
         // URLs like /assets/WWDC25.svg resolve to real files in production.
         .additionalTeleporter(DocCCatalogImageTeleporter(contentDirectory: contentDirectory))
         .enricher(DocCCrossReferenceEnricher(urlPrefix: urlPrefix, language: config.language))

      // Central session-frameworks map: when configured, bulk-assign framework keys from a flat
      // JSON file rather than requiring per-note frontmatter. Per-note values still win.
      if let mapPath = config.docc?.sessionFrameworksPath {
         let mapURL = projectDirectory.appendingPathComponent(mapPath)
         if let data = try? Data(contentsOf: mapURL),
            let map = try? JSONDecoder().decode([String: String].self, from: data)
         {
            builder = builder.enricher(DocCFrameworkEnricher(map: map))
         } else {
            // Misconfigured or missing path – skip gracefully rather than crashing the build.
            print("[SiteKit] Warning: docc.sessionFrameworksPath '\(mapPath)' could not be read or decoded – framework enricher skipped.")
         }
      }

      if config.isMultilingual {
         builder = builder.enricher(HreflangEnricher(config: config))
      }

      // DocC feature flags decide which specialized pages and routes ship. A generic Markdown docs
      // site stays clean by default (contributors + missing-sessions off); search is on by default
      // because it is broadly useful. Absent `docc` config ⇒ those same defaults via DocCConfig().
      let features = config.docc ?? DocCConfig()

      // Path truth for the machine indexes: DocCContributorPage consumes the contributor
      // profile notes and re-homes them under /contributors/<handle>/, so sitemap and
      // nav index must ask it for the final paths instead of trusting the router default.
      var pathResolvers: [any PagePathResolving] = []
      if features.contributorsEnabled {
         pathResolvers.append(DocCContributorPage())
      }

      builder =
         builder
         .renderer(DocCHomePage())
         .renderer(DocCYearListingPage())

      // Contributors feature: the /contributors/ overview page + per-contributor profile pages.
      if features.contributorsEnabled {
         builder = builder.renderer(DocCContributorsPage())
      }
      // Missing-sessions feature: the /missingnotes/ coverage page + its show-more script.
      if features.missingSessionsEnabled {
         builder =
            builder
            .renderer(DocCMissingPage())
            .renderer(DocCMissingScriptRenderer())
      }
      if features.contributorsEnabled {
         builder = builder.renderer(DocCContributorPage())
      }
      // Search feature: the dedicated /search/ facet page.
      if features.searchEnabled {
         builder = builder.renderer(DocCSearchPage())
      }

      builder =
         builder
         .renderer(DocCArticlePage())
         .renderer(DocCStylesheetRenderer())
         .renderer(ErrorPageRenderer())
         .renderer(SitemapRenderer(pathResolvers: pathResolvers))
         .renderer(RobotsTxtRenderer())
         .renderer(NavIndexRenderer(pathResolvers: pathResolvers))

      // Search index + client scripts ship only when search is enabled.
      if features.searchEnabled {
         builder =
            builder
            .renderer(DocCSearchIndexRenderer(pathResolvers: pathResolvers))
            .renderer(DocCSearchScriptRenderer())
            .renderer(DocCSearchPageScriptRenderer())
      }

      return
         builder
         .renderer(DocCSidebarScriptRenderer())
         .renderer(DocCSidebarNavRenderer())
         .renderer(DocCFilterScriptRenderer())
         .renderer(DocCTocScriptRenderer())
         .renderer(DocCThemeScriptRenderer())
         .renderer(TokenCSSOutputRenderer())
         .renderer(BaseCSSOutputRenderer())
         .renderer(FontsFaceCSSRenderer())
         .renderer(CloudflareHeadersRenderer())
         // Both honor SiteConfig.redirectsFile and are no-ops without it: the `_redirects`
         // file gives Cloudflare Pages true server-side 301s, the HTML stubs are the
         // platform-independent fallback for every other host.
         .renderer(HTMLRedirectPageRenderer())
         .renderer(CloudflareRedirectsRenderer())
         .renderer(FaviconRenderer())
         .renderer(LlmsTxtRenderer())
   }
}

// MARK: - Convenience factories (load config from path string)
extension SiteBuilder {
   /// Full blog site – loads the configuration file named by `configPath`, resolved
   /// relative to the current directory (the default `"SiteConfig.yaml"` matches the
   /// standard site layout).
   ///
   /// A configuration loading failure is reported as a single error line and exits
   /// the process with code 1; for catchable errors use `SiteConfig.load(contentsOf:)`
   /// with the `blog(config:projectDirectory:)` factory.
   ///
   /// ```swift
   /// // In Sources/Site/Main.swift:
   /// try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()
   /// ```
   public static func blog(
      configPath: String,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) throws -> SiteBuilder {
      let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let config = SiteBuilder.loadConfigOrExit(at: configPath, in: projectDirectory)
      return blog(config: config, projectDirectory: projectDirectory, cleanBeforeBuild: cleanBeforeBuild, enrichers: enrichers)
   }

   /// Portfolio or landing page site – loads the configuration file named by
   /// `configPath`, resolved relative to the current directory.
   ///
   /// A configuration loading failure is reported as a single error line and exits
   /// the process with code 1; for catchable errors use `SiteConfig.load(contentsOf:)`
   /// with the `portfolio(config:projectDirectory:)` factory.
   ///
   /// ```swift
   /// // In Sources/Site/Main.swift:
   /// try SiteBuilder.portfolio(configPath: "SiteConfig.yaml").run()
   /// ```
   public static func portfolio(
      configPath: String,
      cleanBeforeBuild: Bool = true
   ) throws -> SiteBuilder {
      let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let config = SiteBuilder.loadConfigOrExit(at: configPath, in: projectDirectory)
      return portfolio(config: config, projectDirectory: projectDirectory, cleanBeforeBuild: cleanBeforeBuild)
   }

   /// Newsletter site – loads the configuration file named by `configPath`, resolved
   /// relative to the current directory.
   ///
   /// A configuration loading failure is reported as a single error line and exits
   /// the process with code 1; for catchable errors use `SiteConfig.load(contentsOf:)`
   /// with the `newsletter(config:projectDirectory:)` factory.
   ///
   /// ```swift
   /// // In Sources/Site/Main.swift:
   /// try SiteBuilder.newsletter(configPath: "SiteConfig.yaml").run()
   /// ```
   public static func newsletter(
      configPath: String,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) throws -> SiteBuilder {
      let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let config = SiteBuilder.loadConfigOrExit(at: configPath, in: projectDirectory)
      return newsletter(config: config, projectDirectory: projectDirectory, cleanBeforeBuild: cleanBeforeBuild, enrichers: enrichers)
   }

   /// Podcast site – loads the configuration file named by `configPath`, resolved
   /// relative to the current directory.
   ///
   /// A configuration loading failure is reported as a single error line and exits
   /// the process with code 1; for catchable errors use `SiteConfig.load(contentsOf:)`
   /// with the `podcast(config:projectDirectory:)` factory.
   ///
   /// ```swift
   /// // In Sources/Site/Main.swift:
   /// try SiteBuilder.podcast(configPath: "SiteConfig.yaml").run()
   /// ```
   public static func podcast(
      configPath: String,
      cleanBeforeBuild: Bool = true,
      enrichers: [any Enricher] = []
   ) throws -> SiteBuilder {
      let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let config = SiteBuilder.loadConfigOrExit(at: configPath, in: projectDirectory)
      return podcast(config: config, projectDirectory: projectDirectory, cleanBeforeBuild: cleanBeforeBuild, enrichers: enrichers)
   }

   /// DocC documentation site – loads the configuration file named by `configPath`,
   /// resolved relative to the current directory.
   ///
   /// A configuration loading failure is reported as a single error line and exits
   /// the process with code 1; for catchable errors use `SiteConfig.load(contentsOf:)`
   /// with the `docc(config:projectDirectory:)` factory.
   ///
   /// ```swift
   /// // In Sources/Site/Main.swift:
   /// try SiteBuilder.docc(configPath: "SiteConfig.yaml").run()
   /// ```
   public static func docc(
      configPath: String,
      cleanBeforeBuild: Bool = true,
      highlighter: (any CodeHighlighting)? = nil
   ) throws -> SiteBuilder {
      let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      let config = SiteBuilder.loadConfigOrExit(at: configPath, in: projectDirectory)
      return docc(config: config, projectDirectory: projectDirectory, cleanBeforeBuild: cleanBeforeBuild, highlighter: highlighter)
   }

   /// Loads the site configuration for a `configPath:` convenience factory, reporting
   /// any failure as a single CLI error line and exiting with code 1.
   ///
   /// `configPath` resolves relative to `projectDirectory` (the process working
   /// directory); absolute paths are honored as-is. Exiting here instead of rethrowing
   /// keeps a site's `main.swift` one-liner – `try SiteBuilder.blog(configPath:).run()`
   /// – on the same clean failure surface as every other CLI error: a YAML typo would
   /// otherwise escape `main` and hit the Swift runtime's top-level trap (exit 133)
   /// before `run()` is ever entered. Programmatic callers that need the error instead
   /// of an exit use `SiteConfig.load(contentsOf:)` plus the designed
   /// `(config:projectDirectory:)` factories.
   private static func loadConfigOrExit(at configPath: String, in projectDirectory: URL) -> SiteConfig {
      do {
         return try SiteConfig.load(contentsOf: URL(fileURLWithPath: configPath, relativeTo: projectDirectory).absoluteURL)
      } catch {
         SiteBuilder.exitReportingError(error)
      }
   }
}

// MARK: - Run

/// Reasons a `--base-url` CLI option value is unusable.
enum BaseURLOverrideError: Error, Equatable, CustomStringConvertible {
   /// `--base-url` was passed as the last argument, with no value following it.
   case missingValue
   /// The value is not an absolute http(s) URL (e.g. `wwdcnotes.com` without a scheme).
   case notAnAbsoluteHTTPURL(String)

   var description: String {
      switch self {
      case .missingValue:
         return "--base-url requires a value, e.g. --base-url https://staging.example.com"
      case .notAnAbsoluteHTTPURL(let value):
         return "--base-url value '\(value)' must be an absolute http(s) URL, e.g. https://staging.example.com"
      }
   }
}

extension SiteBuilder {
   /// Reads CLI arguments and dispatches to build, serve, or validate.
   ///
   /// Call this from `Sources/Site/Main.swift` to handle all commands:
   /// ```
   /// swift run Site build
   /// swift run Site serve
   /// swift run Site validate
   /// ```
   ///
   /// Any error thrown by the dispatched command is reported as a single error line
   /// and terminates the process with exit code 1 – the same failure surface as
   /// argument errors – so a site's top-level `try ….run()` never reaches the Swift
   /// runtime's "Error raised at top level" trap (SIGTRAP, exit 133).
   public func run() throws {
      let arguments = CommandLine.arguments
      let command = arguments.count > 1 ? arguments[1] : "build"

      do {
         switch command {
         case "build":
            let pipeline = self.applyingBuildArguments(arguments).buildPipeline()
            try pipeline.build()

         case "serve":
            let builder = self.applyingBuildArguments(arguments)
            try builder.buildPipeline().build()
            try SiteBuilder.serveSite(config: builder.config, projectDirectory: self.projectDirectory, arguments: arguments)

         case "validate":
            try SiteBuilder.validateSite(config: self.config, projectDirectory: self.projectDirectory)

         case "help", "--help", "-h":
            SiteBuilder.printSiteKitUsage()

         default:
            let logger = Logger(label: "SiteKit")
            logger.error("Unknown command: \(command)")
            SiteBuilder.printSiteKitUsage()
            exit(1)
         }
      } catch {
         SiteBuilder.exitReportingError(error)
      }
   }

   /// Reports `error` as a single clean line and terminates with exit code 1.
   ///
   /// The shared failure surface for every CLI error path: unknown commands and bad
   /// option values already exit this way, and `run()` plus the `configPath:`
   /// convenience factories route thrown errors (config decode, content loading,
   /// renderer failures) through here so none of them escapes to the Swift runtime's
   /// top-level trap (exit 133).
   private static func exitReportingError(_ error: any Error) -> Never {
      let logger = Logger(label: "SiteKit")
      logger.error("\(self.cliDescription(of: error))")
      exit(1)
   }

   /// A single-line, human-readable rendering of `error` for CLI output.
   ///
   /// Swift-native errors print via `String(describing:)`, which surfaces the
   /// `CustomStringConvertible` conformances of SiteKit's error enums and still gives
   /// a readable case dump for everything else. True `NSError` instances use
   /// `localizedDescription` instead, because their `description` is the noisy
   /// "Error Domain=… UserInfo=…" dump.
   static func cliDescription(of error: any Error) -> String {
      if type(of: error) is NSError.Type {
         return (error as NSError).localizedDescription
      }
      return String(describing: error)
   }

   /// Extracts and normalizes the `--base-url` option value from CLI arguments.
   ///
   /// Returns nil when the option is absent. Trailing slashes are stripped because every
   /// consumer joins absolute URLs as `baseURL + "/path"` and a kept slash would double it.
   /// A value that is not an absolute http(s) URL is rejected: a build whose canonical,
   /// sitemap, and feed URLs silently point at a scheme-less string would only surface
   /// after deployment. The YAML `baseURL` is deliberately not re-validated here – this
   /// guard covers the new CLI surface only, existing configs keep their behavior.
   ///
   /// Kept separate from `run()` so tests can exercise the exact parsing `run()` uses
   /// without mocking `CommandLine.arguments`.
   static func baseURLOverride(from arguments: [String]) throws -> String? {
      guard let flagIndex = arguments.firstIndex(of: "--base-url") else { return nil }
      guard flagIndex + 1 < arguments.count else { throw BaseURLOverrideError.missingValue }

      let value = arguments[flagIndex + 1]
      guard
         let url = URL(string: value),
         let scheme = url.scheme, scheme == "http" || scheme == "https",
         let host = url.host, !host.isEmpty
      else {
         throw BaseURLOverrideError.notAnAbsoluteHTTPURL(value)
      }

      var normalized = value
      while normalized.hasSuffix("/") {
         normalized.removeLast()
      }
      return normalized
   }

   /// Applies the CLI options shared by the `build` and `serve` render passes
   /// (`--no-clean`, `--base-url`) to a copy of this builder. Both commands route through
   /// this one seam so their option handling cannot drift apart (serve historically ignored
   /// `--no-clean` and wiped pre-built output). Kept separate from `run()` so tests can
   /// exercise the exact plumbing without mocking `CommandLine.arguments`.
   func applyingBuildArguments(_ arguments: [String]) -> SiteBuilder {
      self.cleanBeforeBuild(!arguments.contains("--no-clean"))
         .applyingBaseURLOverride(from: arguments)
   }

   /// Applies a `--base-url` CLI override to a copy of this builder when the option is
   /// present. Exits with a clear error message when the value is missing or malformed,
   /// matching how `run()` reports an unknown command.
   private func applyingBaseURLOverride(from arguments: [String]) -> SiteBuilder {
      do {
         guard let overrideBaseURL = try SiteBuilder.baseURLOverride(from: arguments) else { return self }
         return self.baseURL(overrideBaseURL)
      } catch {
         let logger = Logger(label: "SiteKit")
         logger.error("\(error)")
         exit(1)
      }
   }

   private static func serveSite(config: SiteConfig, projectDirectory: URL, arguments: [String]) throws {
      let logger = Logger(label: "SiteKit.serve")
      let outputDir = projectDirectory.appendingPathComponent(config.outputDirectory)

      guard FileManager.default.fileExists(atPath: outputDir.path) else {
         logger.error("Output directory '\(config.outputDirectory)' not found. Build first.")
         exit(1)
      }

      var port = "8080"
      if let portIndex = arguments.firstIndex(of: "--port"), portIndex + 1 < arguments.count {
         port = arguments[portIndex + 1]
      }

      logger.info("Starting development server at http://localhost:\(port)")
      logger.info("Serving files from: \(outputDir.path)")
      logger.info("Press Ctrl+C to stop")

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
      process.arguments = ["-m", "http.server", port, "--directory", outputDir.path]
      try process.run()

      // Forward SIGTERM and SIGINT to the child process so the server shuts down
      // cleanly whether stopped interactively (Ctrl+C) or programmatically (kill/AI tools).
      signal(SIGTERM, SIG_IGN)
      signal(SIGINT, SIG_IGN)
      let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
      sigtermSource.setEventHandler {
         process.terminate()
         exit(0)
      }
      sigtermSource.resume()
      let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
      sigintSource.setEventHandler {
         process.terminate()
         exit(0)
      }
      sigintSource.resume()

      process.waitUntilExit()
   }

   private static func validateSite(config: SiteConfig, projectDirectory: URL) throws {
      let logger = Logger(label: "SiteKit.validate")
      var hasIssues = false

      if let locConfig = config.localization, !locConfig.languages.isEmpty {
         let defaultLang = config.effectiveDefaultLanguage
         let targetLangs = locConfig.languages
         let contentDirectory = projectDirectory.appendingPathComponent(config.contentDirectory)
         let discovery = LocalizedContentDiscovery(defaultLanguage: defaultLang, additionalLanguages: targetLangs)
         let missing = TranslationStatus.check(
            contentDirectory: contentDirectory,
            defaultLanguage: defaultLang,
            targetLanguages: targetLangs,
            localizedDiscovery: discovery,
            sections: config.effectiveSections
         )

         if missing.isEmpty {
            logger.info("Translations: all up to date ✓")
         } else {
            hasIssues = true
            logger.warning("Translations: \(missing.count) missing")
            let grouped = Dictionary(grouping: missing) { $0.locale }
            for locale in targetLangs {
               let items = grouped[locale] ?? []
               for item in items {
                  logger.warning("  [\(locale)] \(item.sourceFile) → \(item.expectedFile)")
               }
            }
         }
      } else {
         logger.info("Translations: single-language site, skipping ✓")
      }

      if hasIssues { exit(1) }
      logger.info("Validation passed.")
   }

   private static func printSiteKitUsage() {
      print(
         """
         SiteKit - Static Site Generator

         USAGE:
            swift run Site <command>

         COMMANDS:
            build       Build the site (default)
            serve       Build then start a local development server
            validate    Check translations and other quality rules
            help        Show this help message

         OPTIONS:
            --no-clean        Skip cleaning output directory before build
            --port <number>   Port for serve command (default: 8080)
            --base-url <url>  Override the SiteConfig.yaml baseURL for this build (build/serve).
                              Absolute http(s) URL, e.g. https://staging.example.com
         """
      )
   }
}
