import Foundation

/// Centralised relative-path generation for every kind of page on a SiteKit
/// site.
///
/// `URLRouter` is the single source of truth for "where does *X* live on the
/// site?". Every renderer that links to another page, every sitemap entry,
/// every hreflang `href`, every internal `<a>` goes through the router so
/// that path schemes can change in one place. Returned values are *relative*
/// paths (always starting with `/`, ending with `/`); full URLs are built by
/// prepending `SiteConfig.baseURL`.
///
/// SiteKit ships `DefaultURLRouter`, which produces the canonical scheme
/// (articles under `/<blogPrefix>/<slug>/` or `/<category>/<slug>/`, sections
/// under `/<section.urlPrefix>/`, tags under `/tags/<slug>/`). Swap in a
/// custom conformer when a site needs a different path convention without
/// rewriting every renderer.
///
/// ## How to implement
///
/// ```swift
/// public struct YearPrefixedRouter: URLRouter {
///    public func articlePath(for page: PageModel) -> String {
///       let year = Calendar(identifier: .iso8601).component(.year, from: page.date ?? .distantPast)
///       return "/\(year)/\(page.slug)/"
///    }
///    // ...all other methods...
/// }
/// ```
///
/// Pass to `BuildContext` via the builder; renderers receive it as
/// `context.router`.
///
/// ## What this should NOT do
///
/// - Return absolute URLs – prepend `SiteConfig.baseURL` at the call site.
/// - Encode locale prefixes – locale-aware routing is layered on top
///   (`LocaleAwareURLRouter`).
/// - Read from disk or do work beyond pure path composition – routers are
///   invoked many times per build and must stay cheap.
/// - Return paths without trailing slashes – every SiteKit URL terminates
///   with `/` so canonical URLs and links match.
public protocol URLRouter {
   /// Relative path of one article page, e.g. `/blog/<slug>/`. Prefer
   /// `pagePath(for:in:)` when the section is known – this section-less variant
   /// derives the prefix from configuration and category alone.
   func articlePath(for page: PageModel) -> String

   /// Relative path of a category listing page, e.g. `/<category-slug>/`.
   func categoryPath(for category: CategoryConfig) -> String

   /// Relative path of one tag's listing page, e.g. `/tags/<tag-slug>/` –
   /// global, never section-scoped.
   func tagPath(for tag: String) -> String

   /// Relative path of the all-tags index page, e.g. `/tags/`.
   func tagsIndexPath() -> String

   /// Relative path of a top-level static page, e.g. `/<slug>/`; `/` for an
   /// empty slug.
   func staticPagePath(for page: PageModel) -> String

   /// Relative path of the blog listing page, e.g. `/blog/`. Prefer
   /// `sectionListingPath(for:)` when the section is known.
   func blogListingPath() -> String

   /// Relative path of the home page – `/`, locale-prefixed on non-default
   /// locales.
   func homePath() -> String

   // Section-aware routing

   /// Relative path of a content page within its section, e.g.
   /// `/<section.urlPrefix>/<slug>/`. The canonical path API for section
   /// content – the section-less `articlePath(for:)` exists for callers that
   /// only have the page.
   func pagePath(for page: PageModel, in section: SectionConfig) -> String

   /// Relative path of a section's listing page, e.g. `/<section.urlPrefix>/`.
   func sectionListingPath(for section: SectionConfig) -> String
}

/// Default URL router that produces SiteKit's standard URL patterns.
///
/// - With `blogURLPrefix`: all articles at `/<prefix>/<slug>/`
/// - Without: articles at `/<category-slug>/<slug>/`
public struct DefaultURLRouter: URLRouter {
   private let config: SiteConfig

   /// Creates a router producing the standard scheme for `config` (reads
   /// `blogURLPrefix`, `language`, and the declared sections).
   public init(config: SiteConfig) {
      self.config = config
   }

   /// `/<blogURLPrefix>/<slug>/` when configured; otherwise the slugified
   /// category (or `blog` for category-less pages) as prefix.
   public func articlePath(for page: PageModel) -> String {
      let prefix = self.config.blogURLPrefix ?? (page.category.isEmpty ? "blog" : page.category.slugified(language: self.config.language))
      return "/\(prefix)/\(page.slug)/"
   }

   /// `/<category.slug>/`.
   public func categoryPath(for category: CategoryConfig) -> String {
      "/\(category.slug)/"
   }

   /// `/tags/<tag-slug>/`, slugified with the site language's rules.
   public func tagPath(for tag: String) -> String {
      "/tags/\(tag.slugified(language: self.config.language))/"
   }

   /// `/tags/`.
   public func tagsIndexPath() -> String {
      "/tags/"
   }

   // MARK: - Section-aware routing

   /// `/<section.urlPrefix>/<slug>/`.
   public func pagePath(for page: PageModel, in section: SectionConfig) -> String {
      "/\(section.urlPrefix)/\(page.slug)/"
   }

   /// `/<section.urlPrefix>/`.
   public func sectionListingPath(for section: SectionConfig) -> String {
      "/\(section.urlPrefix)/"
   }

   // MARK: - Deprecated wrappers

   /// Pre-sections path of one snippet page; routes through the declared
   /// `snippets` section when one exists.
   @available(*, deprecated, message: "Use pagePath(for:in:) / sectionListingPath(for:) with a SectionConfig instead")
   public func snippetPath(for page: PageModel) -> String {
      if let section = self.config.effectiveSections.first(where: { $0.slug == "snippets" }) {
         return self.pagePath(for: page, in: section)
      }
      let prefix = self.config.snippetsURLPrefix ?? "snippets"
      return "/\(prefix)/\(page.slug)/"
   }

   /// Pre-sections path of the snippets listing; routes through the declared
   /// `snippets` section when one exists.
   @available(*, deprecated, message: "Use pagePath(for:in:) / sectionListingPath(for:) with a SectionConfig instead")
   public func snippetsListingPath() -> String {
      if let section = self.config.effectiveSections.first(where: { $0.slug == "snippets" }) {
         return self.sectionListingPath(for: section)
      }
      let prefix = self.config.snippetsURLPrefix ?? "snippets"
      return "/\(prefix)/"
   }

   /// `/<slug>/`; `/` for an empty slug.
   public func staticPagePath(for page: PageModel) -> String {
      guard !page.slug.isEmpty else { return "/" }
      return "/\(page.slug)/"
   }

   /// `/<blogURLPrefix>/`, defaulting to `/blog/`.
   public func blogListingPath() -> String {
      let prefix = self.config.blogURLPrefix ?? "blog"
      return "/\(prefix)/"
   }

   /// `/`.
   public func homePath() -> String {
      "/"
   }
}

// MARK: - Page path resolution

/// How a content page's final site path relates to the router-derived default.
public enum PagePathResolution: Equatable {
   /// The page lives at the router-derived path – the norm for almost every page.
   case routerDefault
   /// The page is written to this site-absolute path instead (leading and trailing `/`).
   case path(String)
   /// The page's content is consumed by another page and has no URL of its own;
   /// machine indexes must omit it entirely.
   case unpublished
}

/// A page plugin that writes some content pages to site paths the URL router cannot
/// derive – or consumes them without a URL of their own.
///
/// The router computes paths from a page's slug and section alone; a `Page` plugin that
/// overrides `outputURL(for:context:)` is the only place that knows the path it actually
/// writes. Machine-index renderers (`SitemapRenderer`, `NavIndexRenderer`) consult these
/// resolvers so they list the URLs that really exist instead of router defaults nothing
/// serves. Conform in the `Page` plugin that owns the override and keep the returned path
/// in lockstep with what `outputURL` writes; blueprints hand the conforming plugins to the
/// index renderers at composition time (see `SiteBuilder.docc`).
public protocol PagePathResolving {
   /// Resolves the final site path for one content page. Return `.routerDefault` for
   /// every page this plugin does not claim.
   func pathResolution(for page: PageModel, context: BuildContext) -> PagePathResolution
}

extension [any PagePathResolving] {
   /// The first non-default resolution across the resolvers, in order;
   /// `.routerDefault` when no resolver claims the page. Public so blueprint-side index
   /// renderers (e.g. SiteKitOpenAPI's search index) consult the same resolver chain the
   /// built-in sitemap and nav-index do.
   public func pathResolution(for page: PageModel, context: BuildContext) -> PagePathResolution {
      for resolver in self {
         let resolution = resolver.pathResolution(for: page, context: context)
         if resolution != .routerDefault {
            return resolution
         }
      }
      return .routerDefault
   }
}
