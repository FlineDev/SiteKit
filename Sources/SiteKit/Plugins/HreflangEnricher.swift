import Foundation

/// Enricher that populates `page.extensions["hreflang"]` (locale → full URL)
/// so renderers can emit `<link rel="alternate" hreflang="…" href="…">` tags
/// on multilingual sites.
///
/// Input is `page.extensions["translationMap"]: [String: Set<String>]`
/// (base slug → set of available locales), which the pipeline injects on
/// every page during multilingual builds before the enricher chain runs.
/// When the input is missing the page passes through unchanged – exactly the
/// single-language case.
///
/// One of the two enrichers blueprint factory methods append last (alongside
/// `PromotionEnricher`); part of the SEO/i18n cross-cutting concern.
public struct HreflangEnricher: Enricher {
   private var baseURL: String
   private let defaultLanguage: String
   private let allLanguages: [String]
   private let config: SiteConfig

   /// Creates a HreflangEnricher.
   ///
   /// - Parameter config: Site configuration. The translation map (slug → available
   ///   locales) is read from `page.extensions["translationMap"]` during `enrich(_:)`,
   ///   so it does not need to be supplied here.
   public init(config: SiteConfig) {
      self.config = config
      self.baseURL = config.baseURL
      self.defaultLanguage = config.effectiveDefaultLanguage
      self.allLanguages = config.allLanguages
   }

   /// Returns a copy of this enricher whose alternate URLs are prefixed with the given
   /// base URL instead of the one captured at initialization. Routing, languages, and
   /// section resolution keep the originally captured configuration: those only produce
   /// relative paths, so the deploy-target origin is the single thing that may differ.
   ///
   /// This enricher is constructed by the blueprint factory methods while the builder is
   /// composed, long before CLI arguments are parsed – a base URL override applied at
   /// `run()` time therefore has to swap the captured value explicitly.
   func replacingBaseURL(with newBaseURL: String) -> HreflangEnricher {
      var copy = self
      copy.baseURL = newBaseURL
      return copy
   }

   public func enrich(_ page: PageModel) throws -> PageModel {
      // Without a translationMap on the page we cannot compute cross-locale URLs.
      // Multilingual builds populate this in BuildPipeline; single-language builds
      // do not – and have no use for hreflang either, so a no-op is the right default.
      guard let translationMap: [String: Set<String>] = page.extensionValue("translationMap") else {
         return page
      }

      let availableLocales = translationMap[page.slug] ?? [page.locale]

      let baseRouter = DefaultURLRouter(config: self.config)
      var hreflangMap: [String: String] = [:]

      // Resolve the section this page belongs to (stored by BuildPipeline before enriching)
      let sectionSlug: String? = page.extensionValue("sectionSlug")
      let section = sectionSlug.flatMap { slug in
         self.config.effectiveSections.first(where: { $0.slug == slug })
      }

      for locale in availableLocales.sorted() {
         let router = LocaleAwareURLRouter(wrapping: baseRouter, locale: locale, defaultLanguage: self.defaultLanguage)
         let path: String
         if page.pageType == .staticPage {
            path = router.staticPagePath(for: page)
         } else if let section {
            path = router.pagePath(for: page, in: section)
         } else {
            path = router.articlePath(for: page)
         }
         hreflangMap[locale] = "\(self.baseURL)\(path)"
      }

      // Add x-default pointing to the default language version
      if let defaultURL = hreflangMap[self.defaultLanguage] {
         hreflangMap["x-default"] = defaultURL
      }

      var extensions = page.extensions
      extensions["hreflang"] = hreflangMap

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
         extensions: extensions
      )
   }
}
