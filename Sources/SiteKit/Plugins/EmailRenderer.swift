import Foundation
import Logging

/// Generates email-safe HTML versions of articles at `email/<slug>.html`.
///
/// Produces self-contained HTML files with inline CSS, table-based layout,
/// and relative image URLs (suitable for local preview and web archive).
///
/// **URL handling**: Image URLs are kept relative by default, which works for
/// local preview and web-hosted archives. For actual email sending, the sending
/// system (e.g., Keila campaign) should prepend the site's baseURL to make
/// images resolve correctly in email clients.
///
/// Opt-in: add `.renderer(EmailRenderer())` to your site pipeline.
public struct EmailRenderer: Renderer {
   private let logger = Logger(label: "SiteKit.EmailRenderer")

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let accentColor = "#4f46e5"
      let accentColorLight = "#818cf8"
      let siteName = context.config.name
      let siteDescription = context.config.description
      // Use short tagline: text before " – " or "." in description
      let tagline: String = {
         let desc = siteDescription
         if let dashRange = desc.range(of: " – ") {
            return String(desc[desc.startIndex..<dashRange.lowerBound])
         }
         if let dotRange = desc.range(of: ".") {
            return String(desc[desc.startIndex..<dotRange.lowerBound])
         }
         return desc
      }()
      var outputFiles: [OutputFile] = []

      for section in context.sections {
         let nonDraftPages = section.pages.filter { !$0.draft }

         for page in nonDraftPages {
            var htmlBody = page.htmlContent
            htmlBody = self.stripAdBlockquotes(in: htmlBody)
            htmlBody = self.injectInlineStyles(in: htmlBody, accentColor: accentColor)
            let dateString = page.date.map { self.formatDate($0) } ?? ""

            let heroImageHTML: String
            if let imagePath = page.image {
               heroImageHTML = """
                              <tr>
                                 <td style="padding: 0;">
                                    <img src="\(imagePath)" alt="\(self.escapeHTML(page.imageAlt ?? page.title))" style="width: 100%; height: auto; display: block;" />
                                 </td>
                              </tr>
                  """
            } else {
               heroImageHTML = ""
            }

            let emailHTML = """
               <!DOCTYPE html>
               <html lang="\(page.locale)">
               <head>
                  <meta charset="utf-8" />
                  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                  <meta name="color-scheme" content="light dark" />
                  <meta name="supported-color-schemes" content="light dark" />
                  <title>\(self.escapeHTML(page.title))</title>
                  <style>
                     /* Dark mode support */
                     @media (prefers-color-scheme: dark) {
                        .email-bg { background-color: #1a1a1a !important; }
                        .email-card { background-color: #242424 !important; }
                        .email-title { color: #f0f0f0 !important; }
                        .email-date { color: #999999 !important; }
                        .email-text { color: #d4d4d4 !important; }
                        .email-heading { color: #f0f0f0 !important; }
                        .email-link { color: \(accentColorLight) !important; border-bottom-color: \(accentColorLight)40 !important; }
                        .email-code-inline { background-color: #333333 !important; color: #f472b6 !important; }
                        .email-code-block { background-color: #1e1e2e !important; color: #e0e0e0 !important; }
                        .email-strong { color: #f0f0f0 !important; }
                        .email-quote-border { border-left-color: #555555 !important; }
                        .email-quote-text { color: #aaaaaa !important; }
                        .email-quote-mark { color: #555555 !important; }
                        .email-callout { background-color: #2a2a3a !important; border-left-color: \(accentColorLight) !important; }
                        .email-callout-text { color: #d4d4d4 !important; }
                        .email-hr { border-top-color: #333333 !important; }
                        .email-header-accent { color: \(accentColorLight) !important; }
                        .email-header-tagline { color: #999999 !important; }
                        .email-h2-border { border-bottom-color: \(accentColorLight)20 !important; }
                     }
                     /* Outlook dark mode */
                     [data-ogsc] .email-bg { background-color: #1a1a1a !important; }
                     [data-ogsc] .email-card { background-color: #242424 !important; }
                     [data-ogsc] .email-title { color: #f0f0f0 !important; }
                     [data-ogsc] .email-text { color: #d4d4d4 !important; }
                     [data-ogsc] .email-heading { color: #f0f0f0 !important; }
                     [data-ogsc] .email-link { color: \(accentColorLight) !important; }
                     [data-ogsc] .email-code-inline { background-color: #333333 !important; color: #f472b6 !important; }
                     [data-ogsc] .email-code-block { background-color: #1e1e2e !important; color: #e0e0e0 !important; }
                     [data-ogsc] .email-strong { color: #f0f0f0 !important; }
                     [data-ogsc] .email-header-accent { color: \(accentColorLight) !important; }
                     <!--[if mso]>
                     table { border-collapse: collapse; }
                     .content-cell { font-family: Arial, sans-serif; }
                     <![endif]-->
                  </style>
               </head>
               <body style="margin: 0; padding: 0; background-color: #f0f0ef; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; hyphens: auto; -webkit-hyphens: auto; -ms-hyphens: auto;">
                  <!-- Preview-only: dark mode toggle (JS, ignored by email clients) -->
                  <script>
                     document.addEventListener('DOMContentLoaded', function() {
                        var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                        var forceStyle = document.createElement('style');
                        forceStyle.id = 'dark-mode-override';
                        document.head.appendChild(forceStyle);
                        var btn = document.createElement('button');
                        btn.title = 'Toggle dark/light mode preview';
                        btn.style.cssText = 'position:fixed;top:12px;right:12px;z-index:9999;width:36px;height:36px;border-radius:50%;border:none;font-size:18px;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;transition:background 0.2s;';
                        function updateBtn() {
                           btn.textContent = isDark ? '☀️' : '🌙';
                           btn.style.background = isDark ? '#333' : '#fff';
                        }
                        updateBtn();
                        btn.onclick = function() {
                           isDark = !isDark;
                           updateBtn();
                           if (isDark) {
                              forceStyle.textContent = '.email-bg{background-color:#1a1a1a!important}.email-card{background-color:#242424!important}.email-title{color:#f0f0f0!important}.email-date{color:#999!important}.email-text,.content-cell{color:#d4d4d4!important}.email-heading{color:#f0f0f0!important}.email-link{color:\(accentColorLight)!important;border-bottom-color:\(accentColorLight)40!important}.email-code-inline{background-color:#333!important;color:#f472b6!important}.email-strong{color:#f0f0f0!important}.email-header-accent{color:\(accentColorLight)!important}.email-header-tagline{color:#999!important}.email-callout{background-color:#2a2a3a!important;border-left-color:\(accentColorLight)!important}.email-callout-text{color:#d4d4d4!important}.email-hr{border-top-color:#333!important}.email-h2-border{border-bottom-color:\(accentColorLight)20!important}.email-quote-border{border-left-color:#555!important}.email-quote-text{color:#aaa!important}.email-quote-mark{color:#555!important}';
                           } else {
                              forceStyle.textContent = '.email-bg{background-color:#f0f0ef!important}.email-card{background-color:#fff!important}.email-title{color:#111!important}.email-date{color:#888!important}.email-text,.content-cell{color:#333!important}.email-heading{color:#111!important}.email-link{color:\(accentColor)!important;border-bottom-color:\(accentColor)40!important}.email-code-inline{background-color:#f0f0f0!important;color:#d63384!important}.email-strong{color:#111!important}.email-header-accent{color:\(accentColor)!important}.email-header-tagline{color:#888!important}.email-callout{background-color:\(accentColor)08!important;border-left-color:\(accentColor)!important}.email-callout-text{color:#333!important}.email-hr{border-top-color:#e5e7eb!important}.email-h2-border{border-bottom-color:\(accentColor)20!important}.email-quote-border{border-left-color:#d1d5db!important}.email-quote-text{color:#555!important}.email-quote-mark{color:#d1d5db!important}';
                           }
                        };
                        document.body.appendChild(btn);
                     });
                  </script>
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="email-bg" style="background-color: #f0f0ef;">
                     <tr>
                        <td align="center" style="padding: 32px 16px;">

                           <!-- Header -->
                           <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">
                              <tr>
                                 <td align="center" style="padding: 0 0 20px 0;">
                                    <span class="email-header-accent" style="font-size: 18px; font-weight: 700; color: \(accentColor); letter-spacing: -0.3px;">\(self.escapeHTML(siteName))</span>\(tagline.isEmpty ? "" : "<span class=\"email-header-tagline\" style=\"font-size: 18px; font-weight: 400; color: #888888;\"> – \(self.escapeHTML(tagline))</span>")
                                 </td>
                              </tr>
                           </table>

                           <!-- Main Content Card -->
                           <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="email-card" style="max-width: 600px; width: 100%; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08);">
                              <tr>
                                 <td style="padding: 24px 32px 12px 32px;">
                                    <h1 class="email-title" style="margin: 0 0 8px 0; font-size: 26px; line-height: 1.3; color: #111111; font-weight: 700; letter-spacing: -0.3px;">\(self.escapeHTML(page.title))</h1>
                                    \(dateString.isEmpty ? "" : "<p class=\"email-date\" style=\"margin: 0 0 0 0; font-size: 14px; color: #888888; letter-spacing: 0.2px;\">\(dateString)</p>")
                                 </td>
                              </tr>
                              \(heroImageHTML)
                              <tr>
                                 <td style="padding: 20px 32px 24px 32px; font-size: 16px; line-height: 1.7; color: #333333; hyphens: auto; -webkit-hyphens: auto; -ms-hyphens: auto;" class="content-cell">
                                    \(htmlBody)
                                 </td>
                              </tr>
                           </table>

                           <!-- Footer -->
                           <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">
                              <tr>
                                 <td style="padding: 24px 32px 0 32px; text-align: center;">
                                    <p style="margin: 0 0 8px 0; font-size: 13px; line-height: 1.5; color: #999999;">
                                       You received this email because you subscribed to \(self.escapeHTML(siteName)).
                                    </p>
                                    <p style="margin: 0; font-size: 13px; line-height: 1.5; color: #999999;">
                                       <a href="{{unsubscribe_url}}" style="color: #999999; text-decoration: underline;">Unsubscribe</a>
                                    </p>
                                 </td>
                              </tr>
                           </table>

                        </td>
                     </tr>
                  </table>
               </body>
               </html>
               """

            let outputPath = context.outputDirectory
               .appendingPathComponent("email")
               .appendingPathComponent("\(page.slug).html")

            outputFiles.append(OutputFile(outputPath: outputPath, content: emailHTML))
         }
      }

      self.logger.info("Generated \(outputFiles.count) email HTML files")
      return outputFiles
   }

   /// Strips ad/promotional blockquotes from the HTML content.
   private func stripAdBlockquotes(in html: String) -> String {
      // `(?s:…)` makes `.` match newlines just for the enclosed group.
      let blockquoteRegex = #/(?:<hr />\s*)?<blockquote>(?s:(.*?))</blockquote>(?:\s*<hr />)?/#

      return html.replacing(blockquoteRegex) { match in
         let innerContent = String(match.output.1)
         let isAdContent =
            innerContent.contains("Want to see your ad") ||
            innerContent.contains("Enjoyed this article? Check out")
         return isAdContent ? "" : String(match.output.0)
      }
   }

   /// Injects inline styles into HTML elements for email client compatibility.
   private func injectInlineStyles(in html: String, accentColor: String) -> String {
      // Code blocks: <pre><code>...</code></pre> – must come before inline <code>.
      let codeBlockOpen = #"<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 16px 0;"><tr><td class="email-code-block" style="background-color: #1e1e2e; border-radius: 8px; padding: 16px 20px; overflow-x: auto;"><code class="email-code-block" style="font-family: 'SF Mono', 'Fira Code', Menlo, Monaco, Consolas, monospace; font-size: 13px; line-height: 1.6; color: #e0e0e0; white-space: pre-wrap; word-break: break-all;">"#

      var result = html
         // <pre><code class="language-XXX"> and <pre><code> – both map to codeBlockOpen.
         .replacing(#/<pre><code class="language-\w+">/#, with: codeBlockOpen)
         .replacing("<pre><code>", with: codeBlockOpen)
         .replacing("</code></pre>", with: "</code></td></tr></table>")
         // Inline <code> (any remaining after pre/code handling above).
         .replacing(
            "<code>",
            with: #"<code class="email-code-inline" style="font-family: 'SF Mono', Menlo, Monaco, Consolas, monospace; font-size: 14px; background-color: #f0f0f0; color: #d63384; padding: 2px 6px; border-radius: 4px;">"#
         )

      // Blockquotes – detect callout boxes (start with emoji) vs actual quotes.
      result = self.styleBlockquotes(in: result, accentColor: accentColor)

      return result
         // Links
         .replacing(#/<a href="([^"]*)">/#) { match in
            let href = match.output.1
            return #"<a class="email-link" href="\#(href)" style="color: \#(accentColor); text-decoration: none; border-bottom: 1px solid \#(accentColor)40;">"#
         }
         // Headings h2/h3/h4 (preserve any existing attributes on the opening tag).
         .replacing(#/<h2([^>]*)>/#) { match in
            #"<h2\#(match.output.1) class="email-heading email-h2-border" style="margin: 36px 0 16px 0; font-size: 22px; line-height: 1.3; color: #111111; font-weight: 700; letter-spacing: -0.3px; border-bottom: 2px solid \#(accentColor)20; padding-bottom: 8px;">"#
         }
         .replacing(#/<h3([^>]*)>/#) { match in
            #"<h3\#(match.output.1) class="email-heading" style="margin: 32px 0 12px 0; font-size: 20px; line-height: 1.3; color: #111111; font-weight: 700; letter-spacing: -0.2px;">"#
         }
         .replacing(#/<h4([^>]*)>/#) { match in
            #"<h4\#(match.output.1) class="email-heading" style="margin: 28px 0 8px 0; font-size: 17px; line-height: 1.3; color: #222222; font-weight: 600;">"#
         }
         // Paragraphs
         .replacing(#/<p([^>]*)>/#) { match in
            #"<p\#(match.output.1) class="email-text" style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.7; color: #333333;">"#
         }
         // Horizontal rules
         .replacing(
            "<hr />",
            with: #"<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 28px 0;"><tr><td class="email-hr" style="border-top: 1px solid #e5e7eb;"></td></tr></table>"#
         )
         // Strong/bold
         .replacing(#/<strong([^>]*)>/#) { match in
            #"<strong\#(match.output.1) class="email-strong" style="font-weight: 600; color: #111111;">"#
         }
         // Lists
         .replacing("<ul>", with: #"<ul style="margin: 0 0 16px 0; padding-left: 24px;">"#)
         .replacing("<ol>", with: #"<ol style="margin: 0 0 16px 0; padding-left: 24px;">"#)
         .replacing("<li>", with: #"<li style="margin: 0 0 8px 0; font-size: 16px; line-height: 1.7; color: #333333;">"#)
   }

   /// Styles blockquotes differently based on content type.
   /// - Callout boxes (starting with emoji): accent border + background
   /// - Actual quotes: gray border, italic, no background
   private func styleBlockquotes(in html: String, accentColor: String) -> String {
      // `(?s:…)` makes `.` match newlines inside the capture group so blockquotes
      // spanning multiple lines are matched whole.
      let blockquoteRegex = #/<blockquote>(?s:(.*?))</blockquote>/#

      return html.replacing(blockquoteRegex) { match in
         let innerContent = String(match.output.1)

         // Check if content starts with emoji (callout/info box). We look past any leading
         // `<p>` or `<p style=…>` wrapper the markdown renderer adds.
         let strippedContent = innerContent
            .replacing("<p>", with: "")
            .replacing(#/<p style[^>]*>/#, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
         let firstChar = strippedContent.unicodeScalars.first
         // U+2100 covers most callout-style emoji; U+2026 "…" is excluded to keep prose safe.
         let isCalloutBox = firstChar.map { $0.value > 0x2100 && $0.value != 0x2026 } ?? false

         // Strip paragraph bottom margins inside blockquotes.
         let trimmedContent = innerContent.replacing(
            "<p>",
            with: #"<p class="email-callout-text" style="margin: 0; font-size: 15px; line-height: 1.5;">"#
         )

         if isCalloutBox {
            return #"<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 16px 0;"><tr><td class="email-callout" style="border-left: 4px solid \#(accentColor); background-color: \#(accentColor)08; padding: 12px 16px; border-radius: 0 8px 8px 0;">\#(trimmedContent)</td></tr></table>"#
         } else {
            return #"<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 8px 0;"><tr><td class="email-quote-border email-quote-text" style="border-left: 3px solid #d1d5db; padding: 2px 16px; font-style: italic; color: #555555; font-size: 15px; line-height: 1.5;">\#(trimmedContent)</td><td class="email-quote-mark" style="vertical-align: top; padding: 0 0 0 8px; font-size: 36px; color: #d1d5db; font-family: Georgia, serif; line-height: 1; width: 28px;">&rdquo;</td></tr></table>"#
         }
      }
   }

   /// Converts relative image `src` attributes to absolute URLs using the site's baseURL.
   private func makeImageURLsAbsolute(in html: String, baseURL: String) -> String {
      html.replacing(#/src="(?!https?://)([^"]+)"/#) { match in
         let relativePath = String(match.output.1)
         let absolutePath = relativePath.hasPrefix("/")
            ? "\(baseURL)\(relativePath)"
            : "\(baseURL)/\(relativePath)"
         return #"src="\#(absolutePath)""#
      }
   }

   private func formatDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .long
      formatter.timeStyle = .none
      formatter.locale = Locale(identifier: "en_US")
      return formatter.string(from: date)
   }

   private func escapeHTML(_ string: String) -> String {
      string
         .replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
   }
}

private extension String {
   var removingLeadingSlash: String {
      self.hasPrefix("/") ? String(self.dropFirst()) : self
   }
}
