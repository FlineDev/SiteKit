import Foundation

/// Keys for all translatable UI strings used by SiteKit renderers.
/// Arrows and other decorative symbols are added by renderers, not stored in translations.
public enum UIStringKey: String, CaseIterable, Sendable {
   /// Read-time indicator on article meta rows. Template `%d min read`.
   case minRead
   /// Label of the previous-article pagination link ("Previous").
   case previousArticle
   /// Label of the next-article pagination link ("Next").
   case nextArticle
   /// Back-link label from an article to its listing ("Back to Blog").
   case backToBlog
   /// Empty-state text on a listing without posts ("No posts yet.").
   case noPostsYet
   /// Default blog section title ("Blog").
   case blog
   /// Heading of the full article listing ("All Posts").
   case allPosts
   /// Heading of a tag listing page. Template `Posts tagged with %@`.
   case postsTaggedWith
   /// Post-count badge on tag/category listings. Template `%d post(s)`.
   case postCount
   /// Heading of the all-tags index page ("All Tags").
   case allTags
   /// Tags label used on the tags index and article meta ("Tags").
   case tags
   /// Heading of the recent-posts block on the home page ("Recent Posts").
   case recentPosts
   /// Link label from the home page to the full listing ("View all posts").
   case viewAllPosts
   /// 404 page title ("Page Not Found").
   case pageNotFound
   /// 404 page explanation text.
   case pageNotFoundMessage
   /// The large error-code display on the 404 page ("404").
   case errorCode404
   /// 404 page link label back to the home page ("Go to Home Page").
   case goToHomePage
   /// Accessible skip-navigation link target label ("Skip to content").
   case skipToContent
   /// Accessible label of the `<nav>` landmark ("Main navigation").
   case mainNavigation
   /// Accessible label of the language switcher ("Switch language").
   case switchLanguage
   /// Machine-translation notice on translated articles. Template
   /// `This article was AI-translated from %@.` (the original language name).
   case translationNotice
   /// Link label from the translation notice to the original article.
   case translationNoticeLink
   /// Notice on translated legal documents. Template
   /// `This is a translation. Only the %@ version is legally binding.`
   case legalNotice
   /// Link label from the legal notice to the binding language version.
   case legalNoticeLink
   /// Default snippets section title ("Snippets").
   case snippets
   /// Heading of the full snippets listing ("All Snippets").
   case allSnippets
   /// Follow-me promotion line below articles. Template with `%@` for the
   /// linked platform name(s).
   case followMeArticle
   /// Shorter follow-me promotion variant for snippets. Template with `%@`.
   case followMeShort
   /// The word joining two platform links in follow-me lines ("and").
   case connectorAnd
   /// Footer credit line. Template `Built with %@` (linked generator name).
   case builtWith

   // Podcast
   /// Heading of an episode's chapter list ("Chapters").
   case podcastChapters
   /// Heading of an episode's show-notes section ("Show Notes").
   case podcastShowNotes
   /// Download link label on episode pages ("Download (MP3)").
   case podcastDownloadMP3
   /// Pagination link to the previous episode ("Previous Episode").
   case podcastPreviousEpisode
   /// Pagination link to the next episode ("Next Episode").
   case podcastNextEpisode
   /// Back-link label from an episode to the episode listing ("All Episodes").
   case podcastAllEpisodes
   /// Episodes listing heading ("Episodes").
   case podcastEpisodes
   /// Heading of the latest-episodes block on the podcast home ("Latest Episodes").
   case podcastLatestEpisodes
   /// Link label from the podcast home to the full listing ("View All Episodes").
   case podcastViewAllEpisodes
   /// RSS subscribe link label ("Subscribe to Podcast Feed").
   case podcastSubscribeFeed
   /// Label preceding the podcast-platform links ("Listen on").
   case podcastSubscribeLabel

   // DocC
   /// Label of the appbar search trigger ("Search").
   case doccSearch
   /// Placeholder text for the pinned sidebar tree-filter input.
   case doccFilter
   /// Label for the collapsible Contributors group in the sidebar tree.
   case doccContributors
   /// Tooltip shown on stub session rows ("No notes yet").
   case doccStubTitle
   /// Label for the Light option in the sidebar theme switch.
   case doccThemeLight
   /// Label for the Dark option in the sidebar theme switch.
   case doccThemeDark
   /// Label for the Auto (system) option in the sidebar theme switch.
   case doccThemeAuto
   /// Accessible label for the single appbar theme toggle button (light ↔ dark).
   case doccThemeToggle
   /// Section heading for the Overview block on the DocC home page.
   case doccHomeOverview
   /// Section heading for the Contributing block on the DocC home page.
   case doccHomeContributing
   /// Section heading for the Topics card grid on the DocC home page.
   case doccHomeTopics
   /// Call-to-action link label on each per-year card in the Topics grid.
   case doccHomeYearCardLink
   /// Call-to-action link label on the Contributors mosaic card.
   case doccHomeContributorsLink

   // DocC year page
   /// Inline status badge label on stub session rows ("Needs notes").
   case doccStubPillLabel
   /// Small-caps eyebrow on the year overview page title block ("Year overview").
   case doccYearEyebrow
   /// Stat label for non-stub session notes on the year stats row ("notes").
   case doccYearStatsNotes
   /// Stat label for all sessions on the year stats row ("sessions").
   case doccYearStatsSessions
   /// Stat label for topic groups on the year stats row ("topics").
   case doccYearStatsTopics
   /// Fallback group title for sessions not covered by any topic group ("More Sessions").
   case doccMoreSessions

   // DocC article page
   /// Label for the Watch Video call-to-action button on the article meta row.
   case doccWatchVideo
   /// Suffix for the read-time indicator on the article meta row (e.g. "min read").
   case doccReadTime
   /// Pill label that replaces the raw "Quick Read" prefix inside the TLDR card.
   case doccQuickReadTag
   /// Section heading for the Written By block below the article body.
   case doccWrittenBy
   /// Section heading for the Related Sessions list at the bottom of the article.
   case doccRelatedSessions
   /// Link label to a contributor's contributed-notes listing page.
   case doccContributedNotes
   /// Label for the Community mode card in the variant switcher.
   case doccCommunityLabel
   /// Sub-label for the Community mode card ("Written & reviewed by people").
   case doccCommunitySubtitle
   /// Label for the AI mode card in the variant switcher.
   case doccAILabel
   /// Sub-label for the AI mode card ("AI-generated summary of the session").
   case doccAISubtitle
   /// Full disclaimer text shown in the AI-mode banner below the switcher.
   case doccAIBannerText
   /// Badge label for Tip callouts.
   case doccCalloutTip
   /// Badge label for Note callouts.
   case doccCalloutNote
   /// Badge label for Important callouts.
   case doccCalloutImportant
   /// Badge label for Warning callouts.
   case doccCalloutWarning
   /// Badge label for Experiment callouts.
   case doccCalloutExperiment
   /// Heading shown in the stub empty-state ("No notes available yet").
   case doccStubEmptyTitle
   /// Body text shown in the stub empty-state (contribute nudge).
   case doccStubEmptyBody
   /// CTA button label in the stub empty-state ("Learn how to contribute").
   case doccStubEmptyCTA
   /// Stat label for a contributor's note count ("notes contributed") – plural form (N ≠ 1).
   case doccNotesContributed
   /// Stat label for a contributor's note count when count == 1 ("note contributed") – singular form.
   case doccNoteContributed
   /// Word "Session" used in the article eyebrow: "WWDC25 · Session 361".
   case doccSessionLabel
   /// Subtle hint line appended at the bottom of every Quick Read / TLDR card.
   /// Informs readers that the quick summary was machine-generated, not hand-written.
   case doccQuickReadAiHint
   /// One-line corrections nudge at the end of a session note's body, linking to the
   /// contributing guide ("Missing anything? Corrections? Contributions are welcome!").
   case doccCorrectionsCTA

   // DocC contributors list page
   /// Small-caps eyebrow above the contributors hero title ("Community").
   case doccContributorsEyebrow
   /// Subtitle line below the contributors hero title.
   case doccContributorsSubtitle
   /// Heading for the "All contributors" section below the stats row.
   case doccContributorsAllHeading
   /// Short lead sentence below the "All contributors" heading.
   case doccContributorsAllLead
   /// Label for the "Become a contributor" CTA button (shown only when `contributorsBecomeHref` is set).
   case doccContributorsBecomeCTA
   /// Stat label for the total-notes stat in the contributors stats row ("notes written").
   case doccContributorsStatNotes
   /// Stat label for the years-covered stat in the contributors stats row ("years covered").
   case doccContributorsStatYears

   // DocC contributor detail page
   /// Section heading for the Contributions block on the contributor detail page.
   case doccContributorContributionsHeading
   /// Lead sentence in the Contributions section: "Contributed N notes in total. Most active year: YYYY."
   /// Rendered with dynamic numbers from the renderer; only the static frame is a UIString.
   case doccContributorContributionsLead
   /// Link label pointing to the contributor's GitHub profile.
   case doccContributorViewGitHub

   // DocC missing-sessions / coverage page
   /// Small-caps eyebrow above the missing-sessions hero title ("Help wanted").
   case doccMissingEyebrow
   /// Section heading for the per-year coverage bars section.
   case doccMissingCoverageHeading
   /// Short lead sentence below the coverage heading.
   case doccMissingCoverageLead
   /// Label for the "Learn how to contribute" CTA link (shown only when `missingContributeHref` is set).
   case doccMissingLearnCTA
   /// Per-year coverage count chip on the missing-sessions page. Positional template
   /// `%1$lld of %2$lld missing` (missing-of-total) so readers see the year's coverage
   /// at a glance; translators may reorder the two numbers.
   case doccMissingCountFormat
   /// Show-more toggle label on the missing-sessions page when collapsed. Template
   /// `Show %lld more` – the count is the number of stub cards hidden behind the fold.
   case doccMissingShowMore
   /// Show-more toggle label on the missing-sessions page when expanded ("Show less").
   case doccMissingShowLess

   // DocC search overlay (referenced by the search script by these exact names)
   /// Placeholder text inside the search overlay input field.
   case doccSearchPlaceholder
   /// Template string for the result count line. The literal substring `%lld` is replaced
   /// by the search script with the integer result count at runtime.
   case doccSearchResultCount
   /// Heading shown when the search returns zero results.
   case doccSearchNoMatches
   /// Body text below the no-matches heading.
   case doccSearchNoMatchesBody
   /// Label preceding the suggestion chips ("Try:").
   case doccSearchTry
   /// Accessible label for the search overlay's close button ("Close search").
   case doccSearchClose
   /// Link label in the ⌘K overlay's preview panel that opens the focused note ("View more").
   case doccSearchViewNote
   /// Title shown in the on-this-page TOC rail ("On this page").
   case doccTocTitle
   /// Stat label for the contributors count when count == 1 ("contributor") – singular form.
   case doccContributorsStatContributor
   /// Stat label for the contributors count when count != 1 ("contributors") – plural form.
   case doccContributorsStatContributors
   /// Hero subtitle on the missing-sessions page when all sessions are documented.
   case doccMissingHeroComplete
   /// Hero subtitle format template on the missing-sessions page when sessions are missing.
   /// %1$lld = missing count, %2$lld = years-with-missing count.
   case doccMissingHeroSub

   // DocC dedicated search page (the facet-filtered /search/ page, distinct from the ⌘K overlay)
   /// Heading above the facet groups in the search page's filter aside ("Filter").
   case doccSearchFilterHeading
   /// Label for the Year facet group.
   case doccSearchFacetYear
   /// Label for the Note-type facet group.
   case doccSearchFacetType
   /// Label for the Topic facet group ("Topic"). The key keeps its historical name because the
   /// facet's data dimension is the per-note framework field – the visible label says Topic since
   /// the values mix real frameworks with topic buckets (design, media, …).
   case doccSearchFacetFramework
   /// The "All" chip that clears a single facet group's selection.
   case doccSearchFacetAll
   /// Short note-type chip label for AI-authored notes ("AI").
   case doccSearchTypeAI
   /// Short note-type chip label for community-authored notes ("Community").
   case doccSearchTypeCommunity
   /// Short note-type chip label for placeholder/stub notes ("Stub").
   case doccSearchTypeStub
   /// Label for the button that clears every active facet and the query.
   case doccSearchClearFilters
   /// Footer link in the ⌘K overlay that deep-links into the full search page ("See all results").
   case doccSearchSeeAll
   /// Body text for the search page's zero-state when a query/facets exclude everything.
   case doccSearchNoMatchesFilters
   /// Prompt shown in the search page's results area before the reader has typed anything.
   case doccSearchPrompt
   /// Status text shown while the search shards are still loading ("Loading…").
   case doccSearchLoading
}

/// Provides localized UI strings for SiteKit renderers.
///
/// Strings are loaded from a built-in `Localizable.json` resource bundled with SiteKit,
/// then optionally merged with project-level overrides from `{projectDir}/Strings/Localizable.json`.
public struct UIStrings: Sendable {
   /// The locale these strings were resolved for (e.g. "en", "de").
   public let locale: String
   private let strings: [String: String]

   /// Creates a UIStrings instance for the given locale.
   ///
   /// - Parameters:
   ///   - locale: The locale identifier (e.g. "en", "de", "ja")
   ///   - projectDirectory: Optional project directory to load override strings from
   public init(locale: String, projectDirectory: URL? = nil) {
      self.locale = locale

      // Load built-in strings
      var resolved: [String: String] = [:]
      if let builtIn = Self.loadLocalizableJSON(from: Bundle.module) {
         resolved = Self.extractStrings(from: builtIn, locale: locale)
      }

      // Merge project-level overrides
      if let projectDir = projectDirectory {
         let overridePath = projectDir.appendingPathComponent("Strings").appendingPathComponent("Localizable.json")
         if let overrideData = try? Data(contentsOf: overridePath),
            let overrides = try? JSONSerialization.jsonObject(with: overrideData) as? [String: Any]
         {
            let overrideStrings = Self.extractStrings(from: overrides, locale: locale)
            for (key, value) in overrideStrings {
               resolved[key] = value
            }
         }
      }

      self.strings = resolved
   }

   /// Returns the localized string for the given key.
   /// Falls back to the raw key name if no translation is found.
   public func string(for key: UIStringKey) -> String {
      self.strings[key.rawValue] ?? key.rawValue
   }

   /// Returns the localized string for the given key with format arguments.
   /// Supports `%d` (integer) and `%@` (string) format specifiers.
   public func string(for key: UIStringKey, args: any CVarArg...) -> String {
      let format = self.strings[key.rawValue] ?? key.rawValue
      return String(format: format, arguments: args)
   }

   /// Returns the localized string for a raw key not in the UIStringKey enum.
   /// Useful for dynamic keys like language names (e.g., "langNameEn").
   public func string(forRawKey key: String) -> String? {
      self.strings[key]
   }

   // MARK: - Private

   private static func loadLocalizableJSON(from bundle: Bundle) -> [String: Any]? {
      guard let url = bundle.url(forResource: "Localizable", withExtension: "json") else {
         return nil
      }
      guard let data = try? Data(contentsOf: url) else { return nil }
      return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
   }

   /// Extracts localized strings for a specific locale from the Localizable.json structure.
   /// Falls back to English ("en") when the requested locale is not available.
   private static func extractStrings(from json: [String: Any], locale: String) -> [String: String] {
      var result: [String: String] = [:]
      for (key, value) in json {
         guard let entry = value as? [String: Any],
               let localizations = entry["localizations"] as? [String: String]
         else { continue }

         if let localized = localizations[locale] {
            result[key] = localized
         } else if let english = localizations["en"] {
            result[key] = english
         }
      }
      return result
   }
}
