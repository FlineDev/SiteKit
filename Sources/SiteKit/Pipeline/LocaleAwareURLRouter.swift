import Foundation

/// `URLRouter` decorator that prefixes every returned path with `/<locale>/`
/// when the active locale is not the default language.
///
/// Wraps any other `URLRouter` (typically `DefaultURLRouter`) so per-locale
/// routing composes with site-specific path conventions. The default locale
/// passes through unchanged so existing URLs stay stable on single-language
/// sites and on the canonical locale of multilingual sites.
public struct LocaleAwareURLRouter: URLRouter {
   private let wrapped: any URLRouter
   private let locale: String
   private let defaultLanguage: String

   /// Wraps `router` for one locale. Paths pass through unchanged when
   /// `locale == defaultLanguage`; otherwise every path gains a `/<locale>`
   /// prefix.
   public init(wrapping router: any URLRouter, locale: String, defaultLanguage: String) {
      self.wrapped = router
      self.locale = locale
      self.defaultLanguage = defaultLanguage
   }

   private var isDefaultLanguage: Bool {
      self.locale == self.defaultLanguage
   }

   private func prefixed(_ path: String) -> String {
      if self.isDefaultLanguage { return path }
      return "/\(self.locale)\(path)"
   }

   /// The wrapped router's article path, locale-prefixed on non-default locales.
   public func articlePath(for page: PageModel) -> String {
      self.prefixed(self.wrapped.articlePath(for: page))
   }

   /// The wrapped router's category path, locale-prefixed on non-default locales.
   public func categoryPath(for category: CategoryConfig) -> String {
      self.prefixed(self.wrapped.categoryPath(for: category))
   }

   /// The wrapped router's tag path, locale-prefixed on non-default locales.
   public func tagPath(for tag: String) -> String {
      self.prefixed(self.wrapped.tagPath(for: tag))
   }

   /// The wrapped router's tags index path, locale-prefixed on non-default locales.
   public func tagsIndexPath() -> String {
      self.prefixed(self.wrapped.tagsIndexPath())
   }

   /// The wrapped router's section page path, locale-prefixed on non-default locales.
   public func pagePath(for page: PageModel, in section: SectionConfig) -> String {
      self.prefixed(self.wrapped.pagePath(for: page, in: section))
   }

   /// The wrapped router's section listing path, locale-prefixed on non-default locales.
   public func sectionListingPath(for section: SectionConfig) -> String {
      self.prefixed(self.wrapped.sectionListingPath(for: section))
   }

   /// The wrapped router's snippet path, locale-prefixed on non-default locales.
   @available(*, deprecated, message: "Use pagePath(for:in:) / sectionListingPath(for:) with a SectionConfig instead")
   public func snippetPath(for page: PageModel) -> String {
      if let defaultRouter = self.wrapped as? DefaultURLRouter {
         return self.prefixed(defaultRouter.snippetPath(for: page))
      }
      return self.prefixed("/snippets/\(page.slug)/")
   }

   /// The wrapped router's snippets listing path, locale-prefixed on non-default locales.
   @available(*, deprecated, message: "Use pagePath(for:in:) / sectionListingPath(for:) with a SectionConfig instead")
   public func snippetsListingPath() -> String {
      if let defaultRouter = self.wrapped as? DefaultURLRouter {
         return self.prefixed(defaultRouter.snippetsListingPath())
      }
      return self.prefixed("/snippets/")
   }

   /// The wrapped router's static page path, locale-prefixed on non-default locales.
   public func staticPagePath(for page: PageModel) -> String {
      self.prefixed(self.wrapped.staticPagePath(for: page))
   }

   /// The wrapped router's blog listing path, locale-prefixed on non-default locales.
   public func blogListingPath() -> String {
      self.prefixed(self.wrapped.blogListingPath())
   }

   /// `/` on the default locale, `/<locale>/` otherwise – bypasses the wrapped
   /// router because the locale root IS the localized home.
   public func homePath() -> String {
      if self.isDefaultLanguage { return "/" }
      return "/\(self.locale)/"
   }
}
