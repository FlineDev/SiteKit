import Foundation
import Testing

@testable import SiteKit

@Suite("Redirect renderers")
struct HTMLRedirectPageRendererTests {
   // MARK: - Helpers

   /// Builds a context rooted in a fresh temp directory. When `redirectsYAML` is given it is
   /// written as `Redirects.yaml` into the project directory and referenced from the config;
   /// nil leaves `redirectsFile` unset (the default for most sites).
   private func makeContext(redirectsYAML: String?) throws -> BuildContext {
      let projectDirectory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-redirect-tests-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

      var redirectsFile: String?
      if let redirectsYAML {
         redirectsFile = "Redirects.yaml"
         try redirectsYAML.write(
            to: projectDirectory.appendingPathComponent("Redirects.yaml"),
            atomically: true,
            encoding: .utf8
         )
      }

      let config = SiteConfig(name: "Test", baseURL: "https://example.com", redirectsFile: redirectsFile)
      return BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: projectDirectory.appendingPathComponent("_Site"),
         projectDirectory: projectDirectory
      )
   }

   /// A mix of static rules and Cloudflare placeholder rules (`*` splat and `:placeholder`),
   /// mirroring a real migration config where one splat covers the masses and a handful of
   /// renamed pages get explicit static rules.
   private static let mixedRulesYAML = """
   redirects:
     - from: /old-page
       to: /new-page/
       status: 301
     - from: /documentation/wwdcnotes/jeehut
       to: /documentation/contributors/jeehut/
       status: 301
     - from: /documentation/wwdcnotes/*
       to: /documentation/:splat
       status: 301
     - from: /legacy/:slug
       to: /blog/:slug
       status: 302
   """

   // MARK: - No-op property (registration safety)

   @Test("Both redirect renderers are no-ops when no redirectsFile is configured")
   func noOpWithoutRedirectsFile() throws {
      let context = try self.makeContext(redirectsYAML: nil)
      #expect(try HTMLRedirectPageRenderer().render(context: context).isEmpty)
      #expect(try CloudflareRedirectsRenderer().render(context: context).isEmpty)
   }

   @Test("Both redirect renderers are no-ops when the configured file does not exist")
   func noOpWithMissingFile() throws {
      var context = try self.makeContext(redirectsYAML: nil)
      let config = SiteConfig(name: "Test", baseURL: "https://example.com", redirectsFile: "Missing.yaml")
      context = BuildContext(
         config: config,
         themeConfig: nil,
         sections: [],
         staticPages: [],
         tags: [:],
         homeContent: nil,
         outputDirectory: context.outputDirectory,
         projectDirectory: context.projectDirectory
      )
      #expect(try HTMLRedirectPageRenderer().render(context: context).isEmpty)
      #expect(try CloudflareRedirectsRenderer().render(context: context).isEmpty)
   }

   // MARK: - Splat safety

   /// Placeholder rules (`*`/`:`) are Cloudflare Pages syntax that only the `_redirects`
   /// processor can evaluate – a meta-refresh stub for them would create a literal `*`
   /// directory in the output. Only static rules may produce stub pages.
   @Test("HTML stubs are written for static rules only, placeholder rules are skipped")
   func skipsPlaceholderRulesForStubs() throws {
      let context = try self.makeContext(redirectsYAML: Self.mixedRulesYAML)
      let files = try HTMLRedirectPageRenderer().render(context: context)

      let paths = files.map { $0.outputPath.path.replacingOccurrences(of: context.outputDirectory.path, with: "") }
      #expect(paths.sorted() == [
         "/documentation/wwdcnotes/jeehut/index.html",
         "/old-page/index.html",
      ])
      #expect(!paths.contains { $0.contains("*") || $0.contains(":") })
   }

   @Test("Static stub pages carry meta refresh, canonical, and fallback link")
   func staticStubContent() throws {
      let context = try self.makeContext(redirectsYAML: Self.mixedRulesYAML)
      let files = try HTMLRedirectPageRenderer().render(context: context)

      let stub = try #require(files.first { $0.outputPath.path.contains("/old-page/") })
      #expect(stub.content.contains("<meta http-equiv=\"refresh\" content=\"0; url=/new-page/\">"))
      #expect(stub.content.contains("<link rel=\"canonical\" href=\"https://example.com/new-page/\">"))
      #expect(stub.content.contains("<a href=\"/new-page/\">"))
   }

   /// The `_redirects` file is processed by Cloudflare Pages itself, which understands the
   /// placeholder syntax – every rule must pass through verbatim, splats included.
   @Test("The _redirects file keeps all rules verbatim, including placeholder rules")
   func cloudflareRedirectsKeepAllRules() throws {
      let context = try self.makeContext(redirectsYAML: Self.mixedRulesYAML)
      let files = try CloudflareRedirectsRenderer().render(context: context)

      let redirects = try #require(files.first)
      #expect(redirects.outputPath.lastPathComponent == "_redirects")
      #expect(redirects.content.contains("/old-page  /new-page/  301"))
      #expect(redirects.content.contains("/documentation/wwdcnotes/jeehut  /documentation/contributors/jeehut/  301"))
      #expect(redirects.content.contains("/documentation/wwdcnotes/*  /documentation/:splat  301"))
      #expect(redirects.content.contains("/legacy/:slug  /blog/:slug  302"))
   }
}
