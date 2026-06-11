import Foundation

/// Generates a `lang-redirect.js` script that auto-redirects users to their preferred language.
///
/// Loaded only on default-locale pages of multilingual sites. Behavior:
/// 1. Checks `localStorage` for a user-chosen language preference (set by language picker)
/// 2. Falls back to `navigator.language` browser detection
/// 3. Only redirects on external/direct visits (skips internal navigation)
/// 4. If already on a locale path (e.g. `/de/`), doesn't redirect
///
/// Uses localStorage for the `preferredLang` key only – no cookies, no session storage.
public struct LanguageRedirectRenderer: Renderer {
   /// `.global` – produces a single `assets/js/lang-redirect.js` bundle that the
   /// site-wide `<head>` references; the script knows about all locales internally.
   /// Per-locale invocation would write the same file multiple times. Declared here
   /// so `BuildPipeline`'s scope-based router invokes this renderer exactly once.
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard context.config.isMultilingual else { return [] }

      let js = Self.generateScript(
         languages: context.config.allLanguages,
         defaultLanguage: context.config.effectiveDefaultLanguage
      )

      let outputPath = context.outputDirectory
         .appendingPathComponent("assets")
         .appendingPathComponent("js")
         .appendingPathComponent("lang-redirect.js")

      return [OutputFile(outputPath: outputPath, content: js)]
   }

   /// Generates the language-redirect JavaScript snippet.
   ///
   /// Used both by this renderer (produces `/assets/js/lang-redirect.js`) and by
   /// `OutputFileRenderer.buildHead()`, which inlines the same snippet synchronously
   /// at the top of the `<head>`. Inlining is critical for performance: the redirect
   /// must fire BEFORE CSS/fonts/images start loading, otherwise the browser wastes
   /// time downloading resources on a page it's about to navigate away from.
   public static func generateScript(languages: [String], defaultLanguage: String) -> String {
      let langsJSON = languages.map { "\"\($0)\"" }.joined(separator: ", ")
      return """
      (function() {
         'use strict';

         var LANGS = [\(langsJSON)];
         var DEFAULT = '\(defaultLanguage)';

         // 1. Check user's explicit language preference (set by language picker)
         var stored = null;
         try { stored = localStorage.getItem('preferredLang'); } catch(e) {}

         // User explicitly chose the default language – never redirect
         if (stored === DEFAULT) return;

         // 2. Skip redirect if URL has ?noredirect (e.g. "Read the original" link)
         if (location.search.indexOf('noredirect') !== -1) return;

         // 3. Only redirect on external/direct visits (skip internal navigation)
         if (!stored && document.referrer) {
            try {
               if (new URL(document.referrer).hostname === location.hostname) return;
            } catch(e) {}
         }

         // 4. Don't redirect if already on a locale path
         var pathParts = location.pathname.split('/').filter(Boolean);
         if (pathParts.length > 0 && LANGS.indexOf(pathParts[0]) !== -1 && pathParts[0] !== DEFAULT) {
            return;
         }

         // 5. Determine preferred language
         var preferred = stored;

         if (!preferred) {
            var browserLang = (navigator.language || '').toLowerCase();

            // Exact match (e.g. "de" or "zh-hans")
            for (var i = 0; i < LANGS.length; i++) {
               if (browserLang === LANGS[i].toLowerCase()) {
                  preferred = LANGS[i];
                  break;
               }
            }

            // Prefix match (e.g. "de" from "de-DE")
            if (!preferred) {
               var prefix = browserLang.split('-')[0];
               for (var j = 0; j < LANGS.length; j++) {
                  if (prefix === LANGS[j].toLowerCase().split('-')[0]) {
                     preferred = LANGS[j];
                     break;
                  }
               }
            }
         }

         // 6. Redirect if preferred differs from default
         if (preferred && preferred !== DEFAULT) {
            location.replace('/' + preferred + location.pathname);
         }
      })();
      """
   }
}
