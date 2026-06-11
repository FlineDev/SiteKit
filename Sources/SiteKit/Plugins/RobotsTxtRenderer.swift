import Foundation

/// Generates `/robots.txt` at the site root with `User-agent: *` allow, AI
/// crawler allow-list (ClaudeBot, GPTBot, PerplexityBot, etc.), and a
/// `Sitemap:` pointer.
///
/// Always `.global` scope: one robots.txt at the root, even on multilingual
/// sites (search engines and AI crawlers expect exactly one). To opt a site
/// out of AI training crawling, replace this renderer with a custom one;
/// SiteKit's default leans permissive because the AI-friendliness invariant
/// is the design default.
public struct RobotsTxtRenderer: Renderer {
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      let baseURL = context.config.baseURL

      var lines: [String] = [
         "User-agent: *",
         "Allow: /",
         "",
      ]

      // AI crawler directives – explicitly allow with rate limiting
      let aiBots = [
         "ClaudeBot",
         "Claude-SearchBot",
         "GPTBot",
         "OAI-SearchBot",
         "Google-Extended",
         "PerplexityBot",
         "CCBot",
      ]

      for bot in aiBots {
         lines.append("User-agent: \(bot)")
         lines.append("Crawl-delay: 1")
         lines.append("Allow: /")
         lines.append("")
      }

      if context.config.isMultilingual {
         lines.append("Sitemap: \(baseURL)/sitemap_index.xml")
      } else {
         lines.append("Sitemap: \(baseURL)/sitemap.xml")
      }
      lines.append("")

      let content = lines.joined(separator: "\n")
      let path = context.outputDirectory.appendingPathComponent("robots.txt")
      return [OutputFile(outputPath: path, content: content)]
   }
}
