import Foundation
import Yams

/// Generates platform-independent HTML redirect pages.
///
/// Instead of relying on hosting-specific features like Cloudflare's `_redirects` file,
/// this generator creates small HTML files at each source path containing:
/// - `<meta http-equiv="refresh">` for instant redirect
/// - `<link rel="canonical">` for SEO
/// - A visible fallback link for accessibility
///
/// This approach works on any static hosting platform.
public struct HTMLRedirectPageRenderer: Renderer {
   /// `.global` – redirect stubs are rooted at site-wide paths (one HTML file per
   /// `from` rule), not under any locale prefix. Per-locale invocation would write
   /// the same files multiple times. Declared here so `BuildPipeline`'s scope-based
   /// router invokes this renderer exactly once per build.
   public var scope: RenderScope { .global }

   public init() {}

   public func render(context: BuildContext) throws -> [OutputFile] {
      guard let redirectsFile = context.config.redirectsFile else { return [] }

      let filePath = context.projectDirectory.appendingPathComponent(redirectsFile)
      guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }

      let yamlString = try String(contentsOf: filePath, encoding: .utf8)
      let decoder = YAMLDecoder()
      let config = try decoder.decode(RedirectsFileConfig.self, from: yamlString)

      let baseURL = context.config.baseURL

      // Placeholder rules (`*` splats, `:param` segments) are Cloudflare Pages syntax that
      // only the server-side `_redirects` processor can evaluate. A meta-refresh stub for
      // them would write a literal `*`/`:param` directory into the output, so only static
      // rules get stub pages; `CloudflareRedirectsRenderer` still passes every rule through.
      return config.redirects
         .filter { !$0.from.contains("*") && !$0.from.contains(":") }
         .map { rule in
            let canonicalURL = "\(baseURL)\(rule.to)"
            let html = """
            <!DOCTYPE html>\
            <html><head>\
            <meta charset="utf-8">\
            <meta http-equiv="refresh" content="0; url=\(rule.to)">\
            <link rel="canonical" href="\(canonicalURL)">\
            <title>Redirecting\u{2026}</title>\
            </head><body>\
            <p>Redirecting to <a href="\(rule.to)">\(rule.to)</a>\u{2026}</p>\
            </body></html>
            """

            let fromPath = rule.from.hasPrefix("/") ? String(rule.from.dropFirst()) : rule.from
            let outputPath = context.outputDirectory
               .appendingPathComponent(fromPath)
               .appendingPathComponent("index.html")

            return OutputFile(outputPath: outputPath, content: html)
         }
   }
}
