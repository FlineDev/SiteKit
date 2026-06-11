import Foundation

extension OutputFileRenderer {
   /// Minifies a CSS string – strips `/* */` comments, collapses whitespace around
   /// structural punctuation, drops trailing semicolons before closing braces.
   ///
   /// Safe for standard CSS. Applied to `<style>` blocks inlined in `<head>` (tokens.css,
   /// base.css) where every saved byte ships on every page – on a 1000-page site, shaving
   /// ~1.5 KB per page via minification saves ~1.5 MB of total transfer.
   fileprivate static func minifiedCSS(_ css: String) -> String {
      css
         // Strip /* … */ block comments (CSS has no nested comments).
         .replacing(#/\/\*[\s\S]*?\*\//#, with: "")
         // Collapse whitespace around structural punctuation EXCEPT `+` and `-`
         // which MUST keep surrounding spaces inside calc()/min()/max()/clamp().
         .replacing(#/\s*([{};:,>~])\s*/#) { String($0.output.1) }
         // Drop trailing semicolons before closing braces: `display:block;}` -> `display:block}`.
         .replacing(";}", with: "}")
         // Collapse any remaining whitespace runs to a single space.
         .replacing(#/\s+/#, with: " ")
         .trimmingCharacters(in: .whitespacesAndNewlines)
   }

   /// Minifies an inline JS snippet – strips comments and collapses whitespace.
   /// Conservative: meant for SiteKit-generated inline scripts (language-redirect,
   /// theme-detect) only. External theme JS is not touched.
   fileprivate static func minifiedInlineJS(_ js: String) -> String {
      js
         .replacing(#/\/\*[\s\S]*?\*\//#, with: "")
         // Strip `//` line comments – but only when preceded by whitespace or start-of-string
         // so we don't devour things like `http://…` inside strings.
         .replacing(#/(^|\s)\/\/[^\n]*/#) { String($0.output.1) }
         .replacing(#/\s*\n\s*/#, with: " ")
         .replacing(#/\s+/#, with: " ")
         .trimmingCharacters(in: .whitespacesAndNewlines)
   }

   /// Returns a `<link rel="stylesheet">` tag for a stylesheet URL.
   ///
   /// For stylesheets known to be non-critical (Font Awesome, syntax highlighter themes),
   /// uses the media-swap pattern (`media="print" onload="this.media='all'"`) so the browser
   /// does not block First Paint on the stylesheet download. A `<noscript>` fallback ensures
   /// correct rendering without JS.
   /// Returns `true` when a stylesheet URL matches one of the known "non-critical"
   /// bundles that SiteKit loads with the media-swap pattern. Shared between
   /// `stylesheetLink(for:)` (which decides the loading pattern) and the preload
   /// list at the top of `<head>` (which must skip these, because preloading
   /// non-critical CSS would pull it onto the critical render path).
   ///
   /// - Font Awesome (~90 KB of icon styles – mostly decorative / below-fold)
   /// - Highlight.js / Prism / syntax.css (only matters inside `<pre><code>`)
   fileprivate static func isNonCriticalStylesheet(named url: String) -> Bool {
      let lower = url.lowercased()
      return lower.contains("font-awesome")
         || lower.contains("fontawesome")
         || lower.contains("highlight.js")
         || lower.contains("highlightjs")
         || lower.contains("/prism")
         || lower.contains("prism.css")
         || lower.contains("prismjs")
         || lower.hasSuffix("/syntax.css")
         || lower.hasSuffix("syntax.css")
   }

   fileprivate static func stylesheetLink(for url: String) -> String {
      if Self.isNonCriticalStylesheet(named: url) {
         return "<link rel=\"stylesheet\" href=\"\(url)\" media=\"print\" onload=\"this.media='all'\"/><noscript><link rel=\"stylesheet\" href=\"\(url)\"/></noscript>"
      }
      return "<link rel=\"stylesheet\" href=\"\(url)\"/>"
   }

   /// Renders a complete HTML page with the shared site chrome (navigation, footer, skip link).
   ///
   /// Custom `Renderer` implementations can use this to produce pages with consistent
   /// navigation, footer, and theme styling while providing their own main content.
   ///
   /// ```swift
   /// let shell = OutputFileRenderer(context: context)
   /// let head = shell.buildHead(title: "My Page", description: "...")
   /// let content = "<main class=\"sk-main\"><!-- custom content --></main>"
   /// let html = shell.renderPageShell(head: head, bodyClass: "my-page", content: content)
   /// ```
   public func renderPageShell(
      head: String,
      bodyClass: String,
      dataAttributes: [String: String] = [:],
      content: String,
      chrome: PageChrome = .standard
   ) -> String {
      var bodyParts: [String] = [
         "<a class=\"sk-skip-link\" href=\"#main-content\">\(self.uiStrings.string(for: .skipToContent).htmlEscaped)</a>"
      ]

      // `.appShell` pages render their own header + footer inside `content`, so the
      // generic site nav/footer are suppressed to avoid doubling up. `.standard`
      // (the default) keeps the full chrome – every existing page is unaffected.
      if chrome == .standard {
         bodyParts.append(self.renderNavigation())
      }
      bodyParts.append("<div id=\"main-content\">")
      bodyParts.append(content)
      bodyParts.append("</div>")
      if chrome == .standard {
         bodyParts.append(self.renderFooter())
      }

      var bodyAttrs = " class=\"\(bodyClass)\""
      // Sorted so the rendered body-attribute order is deterministic across builds.
      for (key, value) in dataAttributes.sorted(by: { $0.key < $1.key }) {
         bodyAttrs += " \(key)=\"\(value.htmlEscaped)\""
      }

      return "<!DOCTYPE html><html lang=\"\(self.languageCode)\"><head>\(head)</head><body\(bodyAttrs)>\(bodyParts.joined())</body></html>"
   }

   /// Builds the `<head>` section with meta tags, Open Graph, Twitter Card, theme CSS/JS,
   /// hreflang alternates, RSS discovery, JSON-LD structured data, and favicon links.
   ///
   /// Custom generators can use this to get all standard head content without reimplementing
   /// SEO, social sharing, and theme integration.
   public func buildHead(
      title: String,
      description: String? = nil,
      canonicalURL: String? = nil,
      ogType: String = "website",
      image: String? = nil,
      imageAlt: String? = nil,
      rssFeedURL: String? = nil,
      rssFeedTitle: String? = nil,
      articleDate: Date? = nil,
      articleAuthor: Person? = nil,
      articleCategory: String? = nil,
      jsonLD: String? = nil,
      hreflang: [String: String]? = nil,
      noindex: Bool = false,
      preloadImageURL: String? = nil
   ) -> String {
      var parts: [String] = [
         "<meta charset=\"UTF-8\"/>",
         "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, viewport-fit=cover\"/>",
         "<title>\(title.htmlEscaped)</title>",
      ]

      if noindex {
         parts.append("<meta name=\"robots\" content=\"noindex, nofollow\"/>")
      }

      // Language redirect – inlined synchronously at the top of <head> (before any CSS,
      // fonts, images, or other scripts) so it fires BEFORE resources are fetched. If
      // the user is about to be redirected to a localized page, we don't want to waste
      // bandwidth loading resources on a page they'll navigate away from.
      // Only emitted on default-locale pages of multilingual sites.
      if self.config.isMultilingual && self.uiStrings.locale == self.config.effectiveDefaultLanguage {
         let script = LanguageRedirectRenderer.generateScript(
            languages: self.config.allLanguages,
            defaultLanguage: self.config.effectiveDefaultLanguage
         )
         parts.append("<script>\(Self.minifiedInlineJS(script))</script>")
      }

      // Preload LCP image (e.g. article hero) so the browser discovers and fetches it
      // before it parses the <body>, reducing Largest Contentful Paint.
      if let preloadImageURL {
         parts.append("<link rel=\"preload\" as=\"image\" href=\"\(preloadImageURL)\" fetchpriority=\"high\"/>")
      }

      // Preload render-critical theme stylesheets at the top of <head>. The browser's
      // preload scanner picks these up before anything else in <head> parses, so the
      // stylesheet fetch runs in parallel with HTML streaming. Render still blocks on
      // the actual <link rel="stylesheet"> later (preventing FOUC), but the fetch is
      // already in flight – typically cuts 100–300 ms off the "critical request chain"
      // that Lighthouse flags as high-latency on mobile networks.
      //
      // We preload ONLY stylesheets that will load render-blocking. Non-critical ones
      // (Font Awesome, Highlight.js, syntax.css) are already media-swap loaded below
      // – preloading them here would pull them onto the critical path unnecessarily.
      if let themeConfig = self.themeConfig {
         for css in themeConfig.css where !Self.isNonCriticalStylesheet(named: css) {
            parts.append("<link rel=\"preload\" as=\"style\" href=\"/assets/theme/\(css)\"/>")
         }
      }

      // Theme CSS/JS
      if let themeConfig = self.themeConfig {
         // Preconnect to external CDN hosts for faster resource loading
         var preconnectedHosts = Set<String>()
         for url in themeConfig.externalCSS + themeConfig.externalJS {
            if let host = URL(string: url)?.host, preconnectedHosts.insert(host).inserted {
               parts.append("<link rel=\"preconnect\" href=\"https://\(host)\" crossorigin>")
            }
         }

         // Fonts – two modes:
         //   1) Self-hosted (selfHostedFonts: true): emit `<link rel="preload" as="style">`
         //      for `/assets/theme/fonts.css` (produced by `FontsFaceCSSRenderer`) with
         //      onload-swap-to-stylesheet. `@font-face` rules are in that file. Loading async
         //      means the browser doesn't start fetching woff2 files until after FCP, so they
         //      don't compete with HTML/critical CSS on slow mobile connections. Combined with
         //      `font-display: swap`, text paints with fallback first and upgrades silently.
         //   2) Google Fonts CDN (default): same async pattern, but pointing at Google's
         //      CSS URL instead of our own.
         if themeConfig.selfHostedFonts == true {
            let url = "/assets/theme/fonts.css"
            parts.append("<link rel=\"preload\" as=\"style\" href=\"\(url)\" onload=\"this.onload=null;this.rel='stylesheet'\"/><noscript><link rel=\"stylesheet\" href=\"\(url)\"/></noscript>")
         } else if let fontsURL = TokenCSSGenerator.fontsLinkURL(themeConfig: themeConfig) {
            // fonts.googleapis.com serves regular CSS (no crossorigin needed)
            if preconnectedHosts.insert("fonts.googleapis.com").inserted {
               parts.append("<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">")
            }
            // fonts.gstatic.com serves font files via CORS (crossorigin required)
            if preconnectedHosts.insert("fonts.gstatic.com").inserted {
               parts.append("<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>")
            }
            // Non-blocking load: <link rel="preload" as="style" onload> swaps to stylesheet after load.
            // <noscript> fallback makes fonts work without JS.
            parts.append("<link rel=\"preload\" as=\"style\" href=\"\(fontsURL)\" onload=\"this.onload=null;this.rel='stylesheet'\"/><noscript><link rel=\"stylesheet\" href=\"\(fontsURL)\"/></noscript>")
         }

         for css in themeConfig.externalCSS {
            parts.append(Self.stylesheetLink(for: css))
         }
         for js in themeConfig.externalJS {
            parts.append("<script src=\"\(js)\" defer></script>")
         }
         // Font Awesome CDN (opt-in: only when explicitly enabled via includesFontAwesome: true)
         let alreadyHasFA = themeConfig.externalCSS.contains(where: { $0.contains("font-awesome") })
         if themeConfig.includesFontAwesome == true && !alreadyHasFA {
            if !preconnectedHosts.contains("cdnjs.cloudflare.com") {
               parts.append("<link rel=\"preconnect\" href=\"https://cdnjs.cloudflare.com\" crossorigin>")
            }
            parts.append(Self.stylesheetLink(for: "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"))
         }
         // Inline tokens.css + base.css directly in <head> (no external requests).
         // These are small (~2KB tokens, ~1KB base) and universally needed for correct
         // first paint – inlining eliminates two render-blocking round-trips that can
         // dominate FCP on slow networks. Files at /assets/theme/css/tokens.css and
         // /assets/css/base.css are still produced for themes that want to reference them.
         if themeConfig.hasTokens {
            if let tokensCSS = TokenCSSGenerator.generate(themeConfig: themeConfig) {
               parts.append("<style>\(Self.minifiedCSS(tokensCSS))</style>")
            }
            // `try?` does not re-silence a missing base.css: BaseCSSOutputRenderer runs in every default chain behind
            // the same hasTokens gate and throws on the missing resource, so the same build run fails with a nonzero
            // exit before its output can be deployed. buildHead itself stays non-throwing for its many call sites.
            if let baseCSS = try? BaseCSSOutputRenderer.loadBaseCSS() {
               parts.append("<style>\(Self.minifiedCSS(baseCSS))</style>")
            }
         }
         for css in themeConfig.css {
            parts.append(Self.stylesheetLink(for: "/assets/theme/\(css)"))
         }
         for js in themeConfig.js {
            parts.append("<script src=\"/assets/theme/\(js)\" defer></script>")
         }
         // Theme-level favicons from theme.yaml (e.g. SVG icon in Theme/images/)
         for favicon in themeConfig.favicons {
            if favicon.hasSuffix(".svg") {
               parts.append("<link rel=\"icon\" type=\"image/svg+xml\" href=\"/assets/theme/\(favicon)\"/>")
            } else {
               parts.append("<link rel=\"icon\" href=\"/assets/theme/\(favicon)\"/>")
            }
         }
         // Pre-generated PNG favicons from Content/Assets/Favicons/ (copied by FaviconRenderer)
         parts.append(contentsOf: self.buildFaviconLinks())
         if let inlineScript = themeConfig.headInlineScript {
            parts.append("<script>\(inlineScript)</script>")
         }
         // Note: language redirect is emitted inline at the TOP of <head> above
         // (not here) so it runs before any resources are fetched.
      } else {
         parts.append("<link rel=\"stylesheet\" href=\"/assets/css/syntax.css\"/>")
      }

      if let description {
         parts.append("<meta name=\"description\" content=\"\(description.htmlEscaped)\"/>")
      }

      if let canonicalURL {
         parts.append("<link rel=\"canonical\" href=\"\(canonicalURL)\"/>")
      }

      // Resolve the effective image: use provided image, or fall back to theme default image.
      // Image URLs are kept as-is (relative paths work across staging/production environments).
      let effectiveImage = image ?? self.themeConfig?.defaultImage
      let effectiveImageAlt = image != nil ? imageAlt : nil

      // Open Graph
      parts.append("<meta property=\"og:title\" content=\"\(title.htmlEscaped)\"/>")
      parts.append("<meta property=\"og:type\" content=\"\(ogType)\"/>")
      parts.append("<meta property=\"og:site_name\" content=\"\(self.config.name.htmlEscaped)\"/>")

      // Locale (helps platforms understand the page language)
      let ogLocale = self.uiStrings.locale.replacing("-", with: "_")
      parts.append("<meta property=\"og:locale\" content=\"\(ogLocale)\"/>")

      if let canonicalURL {
         parts.append("<meta property=\"og:url\" content=\"\(canonicalURL)\"/>")
      }

      if let description {
         parts.append("<meta property=\"og:description\" content=\"\(description.htmlEscaped)\"/>")
      }

      if let effectiveImage {
         parts.append("<meta property=\"og:image\" content=\"\(effectiveImage)\"/>")
         if let effectiveImageAlt {
            parts.append("<meta property=\"og:image:alt\" content=\"\(effectiveImageAlt.htmlEscaped)\"/>")
         }
      }

      // Article-specific OG tags
      if ogType == "article" {
         if let articleDate {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withFullDate]
            parts.append("<meta property=\"article:published_time\" content=\"\(isoFormatter.string(from: articleDate))\"/>")
         }
         if let authorName = articleAuthor?.name {
            parts.append("<meta property=\"article:author\" content=\"\(authorName.htmlEscaped)\"/>")
         }
         if let articleCategory, !articleCategory.isEmpty {
            parts.append("<meta property=\"article:section\" content=\"\(articleCategory.htmlEscaped)\"/>")
         }
      }

      // Twitter Card
      let twitterCardType = (effectiveImage != nil) ? "summary_large_image" : "summary"
      parts.append("<meta name=\"twitter:card\" content=\"\(twitterCardType)\"/>")
      parts.append("<meta name=\"twitter:title\" content=\"\(title.htmlEscaped)\"/>")

      if let description {
         parts.append("<meta name=\"twitter:description\" content=\"\(description.htmlEscaped)\"/>")
      }

      if let effectiveImage {
         parts.append("<meta name=\"twitter:image\" content=\"\(effectiveImage)\"/>")
         if let effectiveImageAlt {
            parts.append("<meta name=\"twitter:image:alt\" content=\"\(effectiveImageAlt.htmlEscaped)\"/>")
         }
      }

      // Hreflang alternate language links
      if let hreflang {
         for (locale, url) in hreflang.sorted(by: { $0.key < $1.key }) {
            parts.append("<link rel=\"alternate\" hreflang=\"\(locale)\" href=\"\(url)\"/>")
         }
      }

      // RSS feed
      if let rssFeedURL, let rssFeedTitle {
         parts.append("<link rel=\"alternate\" type=\"application/rss+xml\" title=\"\(rssFeedTitle.htmlEscaped)\" href=\"\(rssFeedURL)\"/>")
      }

      // JSON-LD structured data
      if let jsonLD {
         parts.append("<script type=\"application/ld+json\">\(jsonLD)</script>")
      }

      // Search index discovery link
      let localeBase = self.uiStrings.locale == self.config.effectiveDefaultLanguage
         ? "" : "/\(self.uiStrings.locale)"
      parts.append("<link rel=\"search\" type=\"application/json\" title=\"Content Index\" href=\"\(localeBase)/assets/nav-index.json\">")

      // AI navigation comment – helps AI agents discover machine-readable resources
      let feedPath = rssFeedURL ?? "\(localeBase)/feed.xml"
      parts.append("<!-- AI: Machine-readable resources available. RSS (full text): \(feedPath) | Search index (JSON): \(localeBase)/assets/nav-index.json | Full-text index: \(localeBase)/assets/search-index.json | Site directory: /llms.txt -->")

      return parts.joined()
   }

   func buildArticleJSONLD(page: PageModel, canonicalURL: String) -> String {
      let isoFormatter = ISO8601DateFormatter()
      isoFormatter.formatOptions = [.withFullDate]

      var json: [String: Any] = [
         "@context": "https://schema.org",
         "@type": "BlogPosting",
         "headline": page.title,
         "url": canonicalURL,
         "wordCount": self.wordCount(html: page.htmlContent),
      ]

      if let date = page.date {
         json["datePublished"] = isoFormatter.string(from: date)
      }

      if let description = page.summary ?? page.description {
         json["description"] = description
      }

      if let image = page.image {
         json["image"] = image
      }

      if let author = page.author ?? self.config.author {
         var authorObj: [String: String] = [
            "@type": "Person",
            "name": author.name,
         ]
         if let url = author.url {
            authorObj["url"] = url
         }
         json["author"] = authorObj
      }

      json["publisher"] = [
         "@type": "Organization",
         "name": self.config.name,
         "url": self.config.baseURL,
      ] as [String: String]

      // Serialize to JSON
      if let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
         let string = String(data: data, encoding: .utf8)
      {
         return string
      }
      return "{}"
   }

   func buildWebPageJSONLD(page: PageModel, canonicalURL: String) -> String {
      var json: [String: Any] = [
         "@context": "https://schema.org",
         "@type": "WebPage",
         "name": page.title,
         "url": canonicalURL,
      ]

      if let description = page.summary ?? page.description {
         json["description"] = description
      }

      if let image = page.image {
         json["image"] = image
      }

      json["isPartOf"] = [
         "@type": "WebSite",
         "name": self.config.name,
         "url": self.config.baseURL,
      ] as [String: String]

      if let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
         let string = String(data: data, encoding: .utf8)
      {
         return string
      }
      return "{}"
   }

   func buildWebSiteJSONLD() -> String {
      let json: [String: Any] = [
         "@context": "https://schema.org",
         "@type": "WebSite",
         "name": self.config.name,
         "url": self.config.baseURL,
         "description": self.config.description,
         "potentialAction": [
            "@type": "SearchAction",
            "target": "\(self.config.baseURL)/?q={search_term_string}",
            "query-input": "required name=search_term_string",
         ] as [String: String],
      ]

      if let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
         let string = String(data: data, encoding: .utf8)
      {
         return string
      }
      return "{}"
   }

   /// Builds an hreflang map for a page that exists in all configured languages.
   public func buildHreflangForAllLanguages(_ pathForRouter: (any URLRouter) -> String) -> [String: String]? {
      guard self.config.isMultilingual else { return nil }
      let baseRouter = DefaultURLRouter(config: self.config)
      let defaultLang = self.config.effectiveDefaultLanguage
      var map: [String: String] = [:]
      for locale in self.config.allLanguages {
         let router = LocaleAwareURLRouter(wrapping: baseRouter, locale: locale, defaultLanguage: defaultLang)
         map[locale] = "\(self.config.baseURL)\(pathForRouter(router))"
      }
      if let defaultURL = map[defaultLang] { map["x-default"] = defaultURL }
      return map
   }

   private func wordCount(html: String) -> Int {
      let stripped = html.replacing(#/<[^>]+>/#, with: " ")
      return stripped.split(whereSeparator: { $0.isWhitespace }).count
   }

   /// Builds `<link>` tags for favicons based on files in `Content/Assets/Favicons/`.
   ///
   /// Scans the Favicons directory and emits appropriate HTML link elements for each file found.
   /// Recognizes standard favicon filenames and emits the correct `rel`, `type`, and `sizes`
   /// attributes. Falls back to a generic `<link rel="icon">` for unrecognized PNG files.
   private func buildFaviconLinks() -> [String] {
      let faviconsDir = self.projectDirectory
         .appendingPathComponent(self.config.contentDirectory)
         .appendingPathComponent("Assets")
         .appendingPathComponent("Favicons")

      let fileManager = FileManager.default
      guard fileManager.fileExists(atPath: faviconsDir.path) else { return [] }

      let filenames: [String]
      do {
         filenames = try fileManager.contentsOfDirectory(atPath: faviconsDir.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
      } catch {
         return []
      }

      var links: [String] = []
      for filename in filenames {
         let lower = filename.lowercased()

         if lower == "apple-touch-icon.png" {
            links.append("<link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/apple-touch-icon.png\">")
         } else if lower == "favicon-32x32.png" {
            links.append("<link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/favicon-32x32.png\">")
         } else if lower == "favicon-16x16.png" {
            links.append("<link rel=\"icon\" type=\"image/png\" sizes=\"16x16\" href=\"/favicon-16x16.png\">")
         } else if lower == "favicon.ico" {
            links.append("<link rel=\"icon\" type=\"image/x-icon\" href=\"/favicon.ico\">")
         } else if lower.hasSuffix(".svg") {
            links.append("<link rel=\"icon\" type=\"image/svg+xml\" href=\"/\(filename)\">")
         } else if lower == "site.webmanifest" {
            links.append("<link rel=\"manifest\" href=\"/site.webmanifest\">")
         } else if lower.hasSuffix(".png") {
            links.append("<link rel=\"icon\" type=\"image/png\" href=\"/\(filename)\">")
         }
      }

      return links
   }

   private func renderNavigation() -> String {
      // Use locale override if available, otherwise default navigation
      let localeOverride = self.config.localization?.localeOverrides?[self.uiStrings.locale]
      let nav = localeOverride?.navigation ?? self.config.navigation
      guard let nav else { return "" }

      let homePath = self.router.homePath()

      var navParts: [String] = []

      // Logo (use override logo if available, otherwise default)
      let logo = nav.logo ?? self.config.navigation?.logo
      if let logo {
         let dimAttrs: String
         if let w = logo.imageWidth, let h = logo.imageHeight {
            dimAttrs = " width=\"\(w)\" height=\"\(h)\""
         } else {
            dimAttrs = ""
         }
         if let image = logo.image, let text = logo.text {
            navParts.append("<a class=\"sk-site-logo\" href=\"\(homePath)\"><img src=\"\(image)\" alt=\"\(self.config.name.htmlEscaped)\"\(dimAttrs)/><span class=\"sk-site-logo-text\">\(text.htmlEscaped)</span></a>")
         } else if let text = logo.text {
            navParts.append("<a class=\"sk-site-logo\" href=\"\(homePath)\">\(text.htmlEscaped)</a>")
         } else if let image = logo.image {
            navParts.append("<a class=\"sk-site-logo\" href=\"\(homePath)\"><img src=\"\(image)\" alt=\"\(self.config.name.htmlEscaped)\"\(dimAttrs)/></a>")
         }
      }

      if !nav.items.isEmpty {
         let navLinks = nav.items.map { item -> String in
            let localizedURL = self.localizeURL(item.url)
            if let icon = item.icon {
               return "<li class=\"sk-nav-item\"><a href=\"\(localizedURL)\"><span class=\"sk-nav-icon\"><i class=\"\(icon)\"></i></span> \(item.title.htmlEscaped)</a></li>"
            } else {
               return "<li class=\"sk-nav-item\"><a href=\"\(localizedURL)\">\(item.title.htmlEscaped)</a></li>"
            }
         }.joined()
         navParts.append("<ul class=\"sk-nav-list\">\(navLinks)</ul>")
      }

      // Search button – inline SVG icon (no Font Awesome dependency)
      if nav.showSearch ?? true {
         let searchIcon = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"11\" cy=\"11\" r=\"8\"/><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/></svg>"
         navParts.append("<button class=\"sk-search-btn\" aria-label=\"Search\">\(searchIcon)</button>")
      }

      // Language picker shell (menu populated by theme JS for custom styling)
      if self.config.isMultilingual {
         let langUpper = self.uiStrings.locale.uppercased()
         let globeIcon = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><line x1=\"2\" y1=\"12\" x2=\"22\" y2=\"12\"/><path d=\"M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z\"/></svg>"
         navParts.append("<div class=\"sk-lang-picker\"><button class=\"sk-lang-btn\" aria-label=\"\(self.uiStrings.string(for: .switchLanguage).htmlEscaped)\">\(globeIcon)<span class=\"sk-lang-current\">\(langUpper)</span></button><div class=\"sk-lang-menu\" role=\"menu\"></div></div>")
      }

      // Theme toggle – inline SVG icon (no Font Awesome dependency)
      if nav.showThemeToggle ?? true {
         let themeIcon = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 18V4a8 8 0 1 1 0 16z\"/></svg>"
         navParts.append("<button class=\"sk-theme-toggle\" aria-label=\"Theme\">\(themeIcon)</button>")
      }

      return "<header class=\"sk-site-header\" role=\"banner\"><nav class=\"sk-site-nav\" aria-label=\"\(self.uiStrings.string(for: .mainNavigation).htmlEscaped)\">\(navParts.joined())</nav></header>"
   }

   private func renderFooter() -> String {
      // Use locale override if available, otherwise default footer
      let localeOverride = self.config.localization?.localeOverrides?[self.uiStrings.locale]
      let footerConfig = localeOverride?.footer ?? self.config.footer
      guard let footerConfig else { return "" }

      var leftParts: [String] = []
      var centerParts: [String] = []
      var rightParts: [String] = []

      // Social links go on the left
      let footerSocial = footerConfig.social ?? []
      let socialConfig = footerSocial.isEmpty ? (self.config.footer?.social ?? []) : footerSocial
      if !socialConfig.isEmpty {
         let socialLinks = socialConfig.map { social -> String in
            let relAttr: String
            if let rel = social.rel {
               relAttr = "\(rel) noopener"
            } else {
               relAttr = "noopener"
            }
            let icon = self.socialIcon(for: social.platform)
            let knownAcronyms: Set<String> = ["rss", "api"]
            let displayName = knownAcronyms.contains(social.platform.lowercased())
               ? social.platform.uppercased()
               : social.platform.prefix(1).uppercased() + social.platform.dropFirst()
            return "<li><a href=\"\(social.url)\" target=\"_blank\" rel=\"\(relAttr)\">\(icon) \(displayName.htmlEscaped)</a></li>"
         }.joined()
         leftParts.append("<ul class=\"sk-social-links\">\(socialLinks)</ul>")
      }

      let showAttribution = footerConfig.showAttribution != false
      let attributionLinkHTML = "<a href=\"https://github.com/FlineDev/SiteKit\" target=\"_blank\" rel=\"nofollow\" class=\"sk-attribution-link\">SiteKit</a>"

      let copyrightText: String?
      if let raw = footerConfig.copyright {
         copyrightText = raw
      } else if let name = footerConfig.copyrightName {
         let currentYear = Calendar.current.component(.year, from: Date())
         let yearString: String
         if let start = footerConfig.startYear, start < currentYear {
            yearString = "\(start)–\(currentYear)"
         } else {
            yearString = "\(currentYear)"
         }
         copyrightText = "© \(yearString) \(name)"
      } else {
         copyrightText = nil
      }

      if showAttribution {
         let builtWithFormat = self.uiStrings.string(for: .builtWith)
         let parts = builtWithFormat.components(separatedBy: "%@")
         let before = parts.first ?? ""
         let after = parts.count > 1 ? parts[1] : ""
         let attributionHTML = "\(before.htmlEscaped)\(attributionLinkHTML)\(after.htmlEscaped)"
         if let copyright = copyrightText {
            centerParts.append("<p class=\"sk-copyright\">\(attributionHTML) · \(copyright.htmlEscaped)</p>")
         } else {
            centerParts.append("<p class=\"sk-copyright\">\(attributionHTML)</p>")
         }
      } else if let copyright = copyrightText {
         centerParts.append("<p class=\"sk-copyright\">\(copyright)</p>")
      }

      // Navigation links go on the right
      let footerLinks = footerConfig.links ?? []
      if !footerLinks.isEmpty {
         let links = footerLinks.map { link in
            "<li><a href=\"\(self.localizeURL(link.url))\">\(link.title.htmlEscaped)</a></li>"
         }.joined()
         rightParts.append("<nav class=\"sk-footer-nav\"><ul class=\"sk-footer-links\">\(links)</ul></nav>")
      }

      return "<footer class=\"sk-site-footer\" role=\"contentinfo\"><div class=\"sk-footer-inner\"><div class=\"sk-footer-left\">\(leftParts.joined())</div><div class=\"sk-footer-center\">\(centerParts.joined())</div><div class=\"sk-footer-right\">\(rightParts.joined())</div></div></footer>"
   }

   /// Prefixes internal URLs with the locale path for non-default locales.
   /// External URLs (starting with http) are returned unchanged.
   private func localizeURL(_ url: String) -> String {
      guard url.hasPrefix("/") else { return url }
      let homePath = self.router.homePath()
      guard homePath != "/" else { return url }
      return "\(homePath.hasSuffix("/") ? String(homePath.dropLast()) : homePath)\(url)"
   }

   private func socialIcon(for platform: String) -> String {
      switch platform.lowercased() {
      case "mastodon":
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M23.268 5.313c-.35-2.578-2.617-4.61-5.304-5.004C17.51.242 15.792 0 11.813 0h-.03c-3.98 0-4.835.242-5.288.309C3.882.692 1.496 2.518.917 5.127.64 6.412.61 7.837.661 9.143c.074 1.874.088 3.745.26 5.611.118 1.24.325 2.47.62 3.68.55 2.237 2.777 4.098 4.96 4.857 2.336.792 4.849.923 7.256.38.265-.061.527-.132.786-.213.585-.184 1.27-.39 1.774-.753a.057.057 0 0 0 .023-.043v-1.809a.052.052 0 0 0-.02-.041.053.053 0 0 0-.046-.01 20.282 20.282 0 0 1-4.709.547c-2.73 0-3.463-1.284-3.674-1.818a5.593 5.593 0 0 1-.319-1.433.053.053 0 0 1 .066-.054 19.685 19.685 0 0 0 4.636.536h.338c1.578-.007 3.156-.088 4.72-.3 .051-.007.098-.015.144-.024 2.369-.413 4.63-1.699 4.863-5.344.009-.168.03-1.725.03-1.9 0-.58.196-4.101-.027-6.26Z\"/></svg>"
      case "github":
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12\"/></svg>"
      case "twitter", "x":
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z\"/></svg>"
      case "bluesky":
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M12 10.8c-1.087-2.114-4.046-6.053-6.798-7.995C2.566.944 1.561 1.266.902 1.565.139 1.908 0 3.08 0 3.768c0 .69.378 5.65.624 6.479.785 2.627 3.597 3.503 6.204 3.26-3.77.583-6.319 2.028-3.94 7.058 2.634 4.97 4.612 3.27 5.75 2.106C10.025 21.283 11.58 17.77 12 16.59c.42 1.18 1.975 4.694 3.362 6.08 1.138 1.165 3.116 2.865 5.75-2.105 2.38-5.03-.17-6.475-3.94-7.058 2.607.243 5.42-.633 6.204-3.26.246-.829.624-5.789.624-6.479 0-.688-.139-1.86-.902-2.203-.659-.3-1.664-.621-4.3 1.24C16.046 4.748 13.087 8.687 12 10.8Z\"/></svg>"
      case "rss":
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M6.503 20.752c0 1.794-1.456 3.248-3.251 3.248-1.796 0-3.252-1.454-3.252-3.248 0-1.794 1.456-3.248 3.252-3.248 1.795 0 3.251 1.454 3.251 3.248zm-6.503-12.572v4.811c6.05.062 10.96 4.966 11.022 11.009h4.817c-.062-8.742-7.115-15.793-15.839-15.82zm0-8.18v4.819c12.282.051 22.238 10.005 22.289 22.201h4.711c-.038-14.867-12.105-26.938-27-27.02z\"/></svg>"
      default:
         return "<svg class=\"sk-social-icon\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\"><path fill=\"currentColor\" d=\"M10 6V8H5V19H16V14H18V20C18 20.5523 17.5523 21 17 21H4C3.44772 21 3 20.5523 3 20V7C3 6.44772 3.44772 6 4 6H10ZM21 3V11H19V6.413L11.2071 14.2071L9.79289 12.7929L17.585 5H13V3H21Z\"/></svg>"
      }
   }
}
