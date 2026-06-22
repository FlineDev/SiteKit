import Foundation
import Logging

/// Failures a `BuildPipeline.build()` run can abort with.
public enum BuildPipelineError: Error {
   /// The configured `contentDirectory` does not exist on disk.
   case contentDirectoryNotFound(URL)
   /// An output subdirectory could not be created; carries the path and the
   /// underlying filesystem error.
   case outputDirectoryCreationFailed(URL, Error)
   /// An `OutputFile` could not be written; carries the path and the
   /// underlying filesystem error.
   case fileWriteFailed(URL, Error)
   /// One or more renderers failed during the render phase. Each entry carries the
   /// renderer's type name and the error it threw, so the aggregate never hides its
   /// causes – a top-level catch printing this error still shows every failure.
   case renderersFailed([(renderer: String, error: any Error)])
}

extension BuildPipelineError: CustomStringConvertible {
   public var description: String {
      switch self {
      case .contentDirectoryNotFound(let url):
         return "Content directory not found at \(url.path)."
      case .outputDirectoryCreationFailed(let url, let error):
         return "Could not create output directory \(url.path): \(error)"
      case .fileWriteFailed(let url, let error):
         return "Could not write output file \(url.path): \(error)"
      case .renderersFailed(let failures):
         let details =
            failures
            .map { "\($0.renderer): \($0.error)" }
            .joined(separator: "; ")
         return "\(failures.count) renderer(s) failed – \(details)"
      }
   }
}

/// The executor behind `SiteBuilder`: walks the build phases in order –
/// asset teleporting, content discovery, loading, enrichment, per-locale and
/// global rendering, output processing – and writes the result to the output
/// directory.
///
/// Compose one via `SiteBuilder.buildPipeline()` rather than constructing it
/// directly; the direct initializer exists for tests and advanced programmatic
/// use.
public struct BuildPipeline {
   private let config: SiteConfig
   private let projectDirectory: URL
   private let contentDirectory: URL
   private let outputDirectory: URL
   private let contentDiscovery: any ContentDiscovery
   private let loader: any Loader<MarkdownSource, PageModel>
   private let staticPageLoader: any Loader<MarkdownSource, PageModel>
   private let assetCopier: any Teleporter
   private let additionalTeleporters: [any Teleporter]
   private let enrichers: [any Enricher]
   private let renderers: [any Renderer]
   private let processors: [any OutputProcessor]
   private let contentSectionProviders: [any ContentSectionProviding]
   private let logger: Logger
   private let cleanBeforeBuild: Bool
   private let themeConfig: ThemeConfig?

   /// Creates a pipeline with explicit plugins; every nil slot falls back to
   /// the built-in default (`MarkdownContentDiscovery`, `MarkdownLoader`,
   /// `StaticPageLoader`, `AssetCopier`, `SiteBuilder.blogRenderers`, the
   /// five-element processor chain). Also loads `Theme/theme.yaml` here, so a
   /// malformed theme surfaces as a warning at construction time.
   public init(
      config: SiteConfig,
      projectDirectory: URL,
      cleanBeforeBuild: Bool = true,
      contentDiscovery: (any ContentDiscovery)? = nil,
      articleLoader: (any Loader<MarkdownSource, PageModel>)? = nil,
      staticPageLoader: (any Loader<MarkdownSource, PageModel>)? = nil,
      teleporter: (any Teleporter)? = nil,
      additionalTeleporters: [any Teleporter] = [],
      enrichers: [any Enricher] = [],
      renderers: [any Renderer]? = nil,
      processors: [any OutputProcessor]? = nil,
      contentSectionProviders: [any ContentSectionProviding] = []
   ) {
      self.config = config
      self.projectDirectory = projectDirectory
      self.contentDirectory = projectDirectory.appendingPathComponent(config.contentDirectory)
      self.outputDirectory = projectDirectory.appendingPathComponent(config.outputDirectory)
      self.contentDiscovery = contentDiscovery ?? MarkdownContentDiscovery()
      self.loader = articleLoader ?? MarkdownLoader(language: config.language)
      self.staticPageLoader = staticPageLoader ?? StaticPageLoader()
      self.assetCopier = teleporter ?? AssetCopier()
      self.additionalTeleporters = additionalTeleporters
      self.enrichers = enrichers
      self.contentSectionProviders = contentSectionProviders
      self.logger = Logger(label: "SiteKit.build")
      self.cleanBeforeBuild = cleanBeforeBuild

      // Load theme config if theme directory exists
      let themeDir = config.theme?.directory ?? "Theme"
      let themePath = projectDirectory.appendingPathComponent(themeDir)
      do {
         self.themeConfig = try ThemeConfig.load(from: themePath)
      } catch {
         self.themeConfig = nil
         self.logger.warning("Failed to load theme config from \(themePath.path): \(error)")
      }

      // Default post-build processors if none provided.
      // Order matters:
      // - ImageResizer must run before FontAwesomeInliner because the FA inliner
      //   produces inline <svg> elements (no <img>), and running image resize after
      //   it would still be correct but a no-op on the inlined SVGs.
      // - AssetMinifier runs before AssetFingerprinter – the fingerprint hash must be
      //   taken over the FINAL bytes a visitor downloads, so minification has to be
      //   done first or the hash would not reflect what actually ships.
      // - AssetFingerprinter runs LAST – it renames referenced theme CSS/JS to
      //   content-hashed filenames and rewrites every reference, so it needs the
      //   fully-minified, fully-written output to hash and the final HTML to rewrite.
      // CSSBackgroundImageProcessor must run BEFORE AssetMinifier, because the
      // minifier rewrites the CSS file (stripping whitespace) which would make
      // our regex-based declaration scanner harder to match reliably.
      self.processors =
         processors ?? [
            ImageResizer(),
            FontAwesomeInliner(),
            CSSBackgroundImageProcessor(),
            AssetMinifier(),
            AssetFingerprinter(),
         ]

      // Default generators if none provided. The canonical list lives on
      // SiteBuilder.blogRenderers so SiteBuilder.blog(...) and a direct
      // BuildPipeline(...) construction stay in sync – the previous inline
      // list silently omitted five renderers (BaseCSSOutputRenderer,
      // FontsFaceCSSRenderer, CloudflareHeadersRenderer, ContentIndexRenderer,
      // DraftPreviewRenderer) and was a known drift hazard.
      self.renderers = renderers ?? SiteBuilder.blogRenderers
   }

   /// Runs the full build: cleans the output directory (when configured),
   /// teleports assets, then builds the content – single-language or once per
   /// locale plus the global pass – and finishes with the output processors.
   /// Throws `BuildPipelineError` on the first hard failure; processor errors
   /// are logged as warnings instead and do not abort the build.
   public func build() throws {
      self.logger.info("Starting build process...")

      // 1. Clean output directory
      if self.cleanBeforeBuild {
         let fileManager = FileManager.default
         if fileManager.fileExists(atPath: self.outputDirectory.path) {
            try fileManager.removeItem(at: self.outputDirectory)
            self.logger.info("Cleaned output directory")
         }
      }

      // 2. Copy content assets
      let assetsDirectory = self.projectDirectory.appendingPathComponent(self.config.assetsDirectory)
      try self.assetCopier.copy(from: assetsDirectory, to: self.outputDirectory)

      // 3. Copy theme assets
      let themeDir = self.config.theme?.directory ?? "Theme"
      let themeDirectory = self.projectDirectory.appendingPathComponent(themeDir)
      let themeOutputDirectory = self.outputDirectory.appendingPathComponent("assets").appendingPathComponent("theme")
      try self.assetCopier.copy(from: themeDirectory, into: themeOutputDirectory)

      // 3b. Run additional teleporters (e.g. DocCCatalogImageTeleporter for *.docc/Images/).
      for teleporter in self.additionalTeleporters {
         try teleporter.copy(from: assetsDirectory, to: self.outputDirectory)
      }

      if self.config.isMultilingual {
         try self.buildMultilingual()
      } else {
         try self.buildSingleLanguage()
      }

      // Run post-build output processors (e.g. FontAwesomeInliner). These see the final
      // HTML on disk and can transform it in-place. Runs once per build (not per locale).
      for processor in self.processors {
         do {
            try processor.process(
               outputDirectory: self.outputDirectory,
               projectDirectory: self.projectDirectory,
               themeConfig: self.themeConfig
            )
         } catch {
            self.logger.warning("Output processor \(type(of: processor)) failed: \(error)")
         }
      }
   }

   /// Returns `context` with the synthetic sections from every registered
   /// `ContentSectionProviding` plugin merged in, so the machine-index renderers enumerate
   /// generated pages (e.g. the OpenAPI blueprint's spec-derived pages) alongside file-backed
   /// ones. A no-op when no providers are registered. Providers see the file-backed context.
   private func mergingProvidedSections(into context: BuildContext) -> BuildContext {
      guard !self.contentSectionProviders.isEmpty else { return context }
      let provided = self.contentSectionProviders.compactMap { $0.contentSection(in: context) }
      return context.appendingSections(provided)
   }

   /// Standard single-language build (backward compatible).
   private func buildSingleLanguage() throws {
      // 4. Load content sections
      var contentSections: [ContentSection] = []
      var allSectionPages: [PageModel] = []
      var allDraftPages: [PageModel] = []

      for sectionConfig in self.config.effectiveSections {
         let sectionDir = self.contentDirectory.appendingPathComponent(sectionConfig.contentDirectory)
         guard FileManager.default.fileExists(atPath: sectionDir.path) else {
            self.logger.info("Section directory '\(sectionConfig.contentDirectory)' not found, skipping")
            continue
         }

         let sources = try self.contentDiscovery.discover(in: sectionDir)
         self.logger.info("Found \(sources.count) \(sectionConfig.name) files")
         var pages = try self.loadPages(from: sources, using: self.loader)

         // Tag pages with their section slug so enrichers can generate section-correct URLs
         pages = pages.map { page in
            var ext = page.extensions
            ext["sectionSlug"] = sectionConfig.slug
            return PageModel(
               id: page.id,
               title: page.title,
               date: page.date,
               slug: page.slug,
               htmlContent: page.htmlContent,
               sourcePath: page.sourcePath,
               category: page.category,
               tags: page.tags,
               summary: page.summary,
               description: page.description,
               author: page.author,
               image: page.image,
               imageAlt: page.imageAlt,
               draft: page.draft,
               pageType: page.pageType,
               locale: page.locale,
               originalLanguage: page.originalLanguage,
               legalDocument: page.legalDocument,
               extensions: ext
            )
         }

         // Run enrichers
         var enrichedPages = pages
         for enricher in self.enrichers {
            enrichedPages = try enrichedPages.map { try enricher.enrich($0) }
         }

         // Warn about pages missing an id
         for page in enrichedPages where page.id == nil {
            self.logger.warning("Page '\(page.title)' (\(page.sourcePath.lastPathComponent)) has no id in frontmatter")
         }

         // Separate drafts from published pages
         let draftPages = enrichedPages.filter { $0.draft }
         let publishedPages = enrichedPages.filter { !$0.draft }
         if !draftPages.isEmpty {
            self.logger.info("Found \(draftPages.count) draft(s) in \(sectionConfig.name)")
         }

         let sortedPublished = publishedPages.sortedByDate()
         contentSections.append(ContentSection(config: sectionConfig, pages: sortedPublished))
         allSectionPages.append(contentsOf: sortedPublished)
         allDraftPages.append(contentsOf: draftPages)
      }

      // 5. Load static pages
      let pagesDirectory = self.contentDirectory.appendingPathComponent("Pages")
      let staticSources = try self.contentDiscovery.discover(in: pagesDirectory)
         .filter { $0.filePath.lastPathComponent != "home.md" }
      self.logger.info("Found \(staticSources.count) static page files")
      var staticPages = try self.loadPages(from: staticSources, using: self.staticPageLoader)
      // Run enrichers on static pages so the chain reaches them too.
      for enricher in self.enrichers {
         staticPages = try staticPages.map { try enricher.enrich($0) }
      }
      let publishedStaticPages = staticPages.filter { !$0.draft }

      // 6. Load home page content
      let homeContent = self.loadHomeContent(from: pagesDirectory, localeSuffix: nil)

      // 7. Build context and run all generators
      let allTags = self.collectTags(from: allSectionPages)
      let uiStrings = UIStrings(locale: self.config.language, projectDirectory: self.projectDirectory)
      let context = BuildContext(
         config: self.config,
         themeConfig: self.themeConfig,
         sections: contentSections,
         staticPages: publishedStaticPages,
         tags: allTags,
         homeContent: homeContent,
         uiStrings: uiStrings,
         outputDirectory: self.outputDirectory,
         projectDirectory: self.projectDirectory,
         draftPages: allDraftPages
      )

      // Merge in any synthetic sections (e.g. the OpenAPI blueprint's spec-derived pages)
      // so the machine-index renderers enumerate them like file-backed pages.
      try self.runRenderers(context: self.mergingProvidedSections(into: context))
   }

   /// Multi-language build: discovers content per locale, builds per locale, then global assets.
   private func buildMultilingual() throws {
      let defaultLang = self.config.effectiveDefaultLanguage
      let additionalLangs = self.config.localization?.languages ?? []
      let allLangs = self.config.allLanguages

      self.logger.info("Multi-language build: \(allLangs.joined(separator: ", "))")

      let localizedDiscovery = LocalizedContentDiscovery(
         defaultLanguage: defaultLang,
         additionalLanguages: additionalLangs
      )

      // Discover content for all sections grouped by locale
      var allSectionContent: [String: [String: [MarkdownSource]]] = [:]  // [sectionSlug: [locale: [sources]]]
      for sectionConfig in self.config.effectiveSections {
         let sectionDir = self.contentDirectory.appendingPathComponent(sectionConfig.contentDirectory)
         if FileManager.default.fileExists(atPath: sectionDir.path) {
            allSectionContent[sectionConfig.slug] = try localizedDiscovery.discoverLocalized(in: sectionDir)
         } else {
            allSectionContent[sectionConfig.slug] = [:]
         }
      }

      let pagesDirectory = self.contentDirectory.appendingPathComponent("Pages")
      let allStaticContent = try localizedDiscovery.discoverLocalized(in: pagesDirectory)

      let baseRouter = DefaultURLRouter(config: self.config)

      // Partition renderers by their declared scope. `.perLocale` renderers run inside
      // the per-locale loop below; `.global` renderers run exactly once after the loop.
      // Each `Renderer` declares its scope via `var scope: RenderScope` (default `.perLocale`).
      let perLocaleRenderers = self.renderers.filter { $0.scope == .perLocale }
      let globalRenderers = self.renderers.filter { $0.scope == .global }

      // Check translation status
      let translationStatus = TranslationStatus.check(
         contentDirectory: self.contentDirectory,
         defaultLanguage: defaultLang,
         targetLanguages: additionalLangs,
         localizedDiscovery: localizedDiscovery,
         sections: self.config.effectiveSections
      )

      if !translationStatus.isEmpty {
         let mode = self.config.localization?.translationMode ?? "manual"
         let threshold = translationStatus.count > 20
         if threshold {
            self.logger.warning("\(translationStatus.count) translations missing across all languages")
         } else {
            for missing in translationStatus {
               if mode == "auto" {
                  self.logger.error("Missing translation: \(missing.expectedFile) (\(missing.locale))")
               } else {
                  self.logger.warning("Missing translation: \(missing.expectedFile) (\(missing.locale))")
               }
            }
         }
      }

      // Build translation map for hreflang enricher
      var translationMap: [String: Set<String>] = [:]
      let slugPattern = /^\d{4}-\d{2}-\d{2}-(.+)$/
      for (_, localeContent) in allSectionContent {
         for (locale, sources) in localeContent {
            for source in sources {
               let base = localizedDiscovery.baseFilename(for: source.filePath)
               let slug = (base.wholeMatch(of: slugPattern).map { String($0.1) } ?? base).lowercased()
               translationMap[slug, default: []].insert(locale)
            }
         }
      }
      for (locale, sources) in allStaticContent {
         for source in sources {
            let base = localizedDiscovery.baseFilename(for: source.filePath)
            let slug = (base.wholeMatch(of: slugPattern).map { String($0.1) } ?? base).lowercased()
            translationMap[slug, default: []].insert(locale)
         }
      }

      // Build per locale
      for locale in allLangs {
         self.logger.info("Building locale: \(locale)")

         // Load all sections for this locale
         var contentSections: [ContentSection] = []
         var allSectionPages: [PageModel] = []
         var allDraftPages: [PageModel] = []

         for sectionConfig in self.config.effectiveSections {
            let localeContent = allSectionContent[sectionConfig.slug] ?? [:]
            let localeSources = localeContent[locale] ?? []
            let defaultSources = localeContent[defaultLang] ?? []

            let effectiveSources: [MarkdownSource]
            if locale == defaultLang {
               effectiveSources = localeSources
            } else {
               let translatedBases = Set(localeSources.map { localizedDiscovery.baseFilename(for: $0.filePath) })
               let fallbackSources = defaultSources.filter {
                  !translatedBases.contains(localizedDiscovery.baseFilename(for: $0.filePath))
               }
               effectiveSources = localeSources + fallbackSources
            }

            var pages = try self.loadPages(from: effectiveSources, using: self.loader, locale: locale)

            // Tag pages with their section slug + translationMap so chain enrichers
            // (notably HreflangEnricher) have everything they need without an extra
            // constructor parameter.
            pages = pages.map { page in
               var ext = page.extensions
               ext["sectionSlug"] = sectionConfig.slug
               ext["translationMap"] = translationMap
               return PageModel(
                  id: page.id,
                  title: page.title,
                  date: page.date,
                  slug: page.slug,
                  htmlContent: page.htmlContent,
                  sourcePath: page.sourcePath,
                  category: page.category,
                  tags: page.tags,
                  summary: page.summary,
                  description: page.description,
                  author: page.author,
                  image: page.image,
                  imageAlt: page.imageAlt,
                  draft: page.draft,
                  pageType: page.pageType,
                  locale: page.locale,
                  originalLanguage: page.originalLanguage,
                  legalDocument: page.legalDocument,
                  extensions: ext
               )
            }

            // Run enrichers
            for enricher in self.enrichers {
               pages = try pages.map { try enricher.enrich($0) }
            }

            // Warn about pages missing an id (only for default language to avoid duplicate warnings)
            if locale == defaultLang {
               for page in pages where page.id == nil {
                  self.logger.warning("Page '\(page.title)' (\(page.sourcePath.lastPathComponent)) has no id in frontmatter")
               }
            }

            // Separate drafts from published pages
            let draftPages = pages.filter { $0.draft }
            let publishedPages = pages.filter { !$0.draft }
            if !draftPages.isEmpty {
               self.logger.info("Found \(draftPages.count) draft(s) in \(sectionConfig.name) (\(locale))")
            }
            let sortedPublished = publishedPages.sortedByDate()
            contentSections.append(ContentSection(config: sectionConfig, pages: sortedPublished))
            allSectionPages.append(contentsOf: sortedPublished)
            allDraftPages.append(contentsOf: draftPages)
         }

         // Static pages for this locale
         let staticSources = (allStaticContent[locale] ?? [])
            .filter { !$0.filePath.lastPathComponent.hasPrefix("home") || $0.filePath.lastPathComponent != "home.md" }
            .filter { !$0.filePath.lastPathComponent.hasPrefix("home.") }
         let defaultStaticSources =
            locale == defaultLang
            ? []
            : ((allStaticContent[defaultLang] ?? [])
               .filter { !$0.filePath.lastPathComponent.hasPrefix("home") })
         let translatedStaticBases = Set(staticSources.map { localizedDiscovery.baseFilename(for: $0.filePath) })
         let fallbackStaticSources = defaultStaticSources.filter {
            !translatedStaticBases.contains(localizedDiscovery.baseFilename(for: $0.filePath))
         }
         let effectiveStaticSources = staticSources + fallbackStaticSources
         var staticPages = try self.loadPages(from: effectiveStaticSources, using: self.staticPageLoader, locale: locale)
         // Static pages don't carry a sectionSlug, but they do need translationMap
         // so HreflangEnricher (and any future chain enricher) can act on them.
         staticPages = staticPages.map { page in
            var ext = page.extensions
            ext["translationMap"] = translationMap
            return PageModel(
               id: page.id,
               title: page.title,
               date: page.date,
               slug: page.slug,
               htmlContent: page.htmlContent,
               sourcePath: page.sourcePath,
               category: page.category,
               tags: page.tags,
               summary: page.summary,
               description: page.description,
               author: page.author,
               image: page.image,
               imageAlt: page.imageAlt,
               draft: page.draft,
               pageType: page.pageType,
               locale: page.locale,
               originalLanguage: page.originalLanguage,
               legalDocument: page.legalDocument,
               extensions: ext
            )
         }
         for enricher in self.enrichers {
            staticPages = try staticPages.map { try enricher.enrich($0) }
         }
         let publishedStaticPages = staticPages.filter { !$0.draft }

         // Home page content for this locale
         let homeContent = self.loadHomeContent(from: pagesDirectory, localeSuffix: locale == defaultLang ? nil : locale)

         // Create locale-aware context
         let router = LocaleAwareURLRouter(wrapping: baseRouter, locale: locale, defaultLanguage: defaultLang)
         let uiStrings = UIStrings(locale: locale, projectDirectory: self.projectDirectory)
         let allTags = self.collectTags(from: allSectionPages)

         let context = BuildContext(
            config: self.config,
            themeConfig: self.themeConfig,
            sections: contentSections,
            staticPages: publishedStaticPages,
            tags: allTags,
            homeContent: homeContent,
            router: router,
            uiStrings: uiStrings,
            outputDirectory: self.outputDirectory,
            projectDirectory: self.projectDirectory,
            draftPages: allDraftPages
         )

         try self.runRenderers(context: context, renderers: perLocaleRenderers)
      }

      // Run global generators once (with default locale context)
      var defaultSections: [ContentSection] = []
      var defaultAllPages: [PageModel] = []
      for sectionConfig in self.config.effectiveSections {
         let localeContent = allSectionContent[sectionConfig.slug] ?? [:]
         let defaultSources = localeContent[defaultLang] ?? []
         let pages = try self.loadPages(from: defaultSources, using: self.loader)
            .filter { !$0.draft }
            .sortedByDate()
         defaultSections.append(ContentSection(config: sectionConfig, pages: pages))
         defaultAllPages.append(contentsOf: pages)
      }

      let defaultStaticSourcesFinal = (allStaticContent[defaultLang] ?? []).filter { !$0.filePath.lastPathComponent.hasPrefix("home") }
      let defaultStaticPages = try self.loadPages(from: defaultStaticSourcesFinal, using: self.staticPageLoader).filter { !$0.draft }
      let defaultHomeContent = self.loadHomeContent(from: self.contentDirectory.appendingPathComponent("Pages"), localeSuffix: nil)

      let globalContext = BuildContext(
         config: self.config,
         themeConfig: self.themeConfig,
         sections: defaultSections,
         staticPages: defaultStaticPages,
         tags: self.collectTags(from: defaultAllPages),
         homeContent: defaultHomeContent,
         uiStrings: UIStrings(locale: defaultLang, projectDirectory: self.projectDirectory),
         outputDirectory: self.outputDirectory,
         projectDirectory: self.projectDirectory
      )

      // Synthetic provider sections live in the global pass (where the site-wide machine
      // indexes run), not duplicated per-locale – their pages are not localized.
      try self.runRenderers(context: self.mergingProvidedSections(into: globalContext), renderers: globalRenderers)

      // Generate translation status JSON for AI agents
      let translationStatusGenerator = TranslationStatusRenderer(
         missingTranslations: translationStatus,
         translationMode: self.config.localization?.translationMode ?? "manual",
         styleGuidePath: self.config.localization?.styleGuidePath
      )
      let statusFiles = try translationStatusGenerator.render(context: globalContext)
      for file in statusFiles {
         try self.writeOutputFile(file)
      }
      self.logger.info("Generated translation status (\(translationStatus.count) missing)")
   }

   private func loadHomeContent(from pagesDirectory: URL, localeSuffix: String?) -> String? {
      let homeFilename = localeSuffix.map { "home.\($0).md" } ?? "home.md"
      let homePath = pagesDirectory.appendingPathComponent(homeFilename)

      // Fall back to default home.md if locale-specific doesn't exist
      let fallbackPath = pagesDirectory.appendingPathComponent("home.md")
      let effectivePath = FileManager.default.fileExists(atPath: homePath.path) ? homePath : fallbackPath

      guard FileManager.default.fileExists(atPath: effectivePath.path),
         let content = try? String(contentsOf: effectivePath, encoding: .utf8)
      else { return nil }

      let source = MarkdownSource(filePath: effectivePath, content: content)
      guard let homePage = try? self.staticPageLoader.load(source: source) else { return nil }
      return homePage.htmlContent
   }

   private func runRenderers(context: BuildContext, renderers: [any Renderer]? = nil) throws {
      let activeRenderers = renderers ?? self.renderers
      var failures: [(renderer: String, error: any Error)] = []
      for renderer in activeRenderers {
         do {
            let files = try renderer.render(context: context)
            for file in files {
               try self.writeOutputFile(file)
            }
            self.logger.info("Renderer \(type(of: renderer)) produced \(files.count) file(s)")
         } catch {
            self.logger.error("Renderer \(type(of: renderer)) failed: \(error)")
            failures.append((renderer: String(describing: type(of: renderer)), error: error))
         }
      }

      if !failures.isEmpty {
         self.logger.error("Build completed with \(failures.count) error(s)")
         throw BuildPipelineError.renderersFailed(failures)
      } else {
         self.logger.info("Build completed successfully!")
      }
   }

   private func loadPages(from sources: [MarkdownSource], using loader: any Loader<MarkdownSource, PageModel>, locale: String? = nil) throws
      -> [PageModel]
   {
      var pages: [PageModel] = []
      for source in sources {
         do {
            var page = try loader.load(source: source)
            if let locale {
               // Strip locale suffix from slug (e.g., "article-name.de" → "article-name")
               var slug = page.slug
               if slug.hasSuffix(".\(locale)") {
                  slug = String(slug.dropLast(locale.count + 1))
               }
               page = PageModel(
                  id: page.id,
                  title: page.title,
                  date: page.date,
                  slug: slug,
                  htmlContent: page.htmlContent,
                  sourcePath: page.sourcePath,
                  category: page.category,
                  tags: page.tags,
                  summary: page.summary,
                  description: page.description,
                  author: page.author,
                  image: page.image,
                  imageAlt: page.imageAlt,
                  draft: page.draft,
                  pageType: page.pageType,
                  locale: locale,
                  originalLanguage: page.originalLanguage,
                  legalDocument: page.legalDocument,
                  extensions: page.extensions
               )
            }
            pages.append(page)
            self.logger.info("Loaded: \(source.filePath.lastPathComponent) -> \(page.slug)")
         } catch {
            self.logger.error("Failed to load \(source.filePath.lastPathComponent): \(error)")
         }
      }
      return pages
   }

   private func collectTags(from pages: [PageModel]) -> [String: [PageModel]] {
      var tagMap: [String: [PageModel]] = [:]
      for page in pages {
         for tag in page.tags {
            tagMap[tag, default: []].append(page)
         }
      }
      return tagMap
   }

   private func writeOutputFile(_ file: OutputFile) throws {
      let outputPath = file.outputPath
      let directory = outputPath.deletingLastPathComponent()

      do {
         try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
         )
      } catch {
         throw BuildPipelineError.outputDirectoryCreationFailed(directory, error)
      }

      do {
         if let binary = file.binaryContent {
            try binary.write(to: outputPath)
         } else {
            try file.content.write(to: outputPath, atomically: true, encoding: .utf8)
         }
      } catch {
         throw BuildPipelineError.fileWriteFailed(outputPath, error)
      }
   }
}
