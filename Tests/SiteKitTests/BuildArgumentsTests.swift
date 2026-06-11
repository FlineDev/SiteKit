import Foundation
import Testing

@testable import SiteKit

/// `run()` itself reads `CommandLine.arguments` and starts processes, so these tests pin the
/// extracted seam both the `build` and the `serve` case route through. Serve historically
/// ignored `--no-clean` (it always built with the default clean), which wiped pre-built
/// output – the shared seam plus these assertions keep the two commands from drifting again.
@Suite("Build argument parsing")
struct BuildArgumentsTests {
   /// Reflects on a SiteBuilder's private `cleanBeforeBuild` flag, mirroring the
   /// reflection idiom in `BaseURLOverrideTests`.
   private func cleanBeforeBuild(of builder: SiteBuilder) -> Bool? {
      let mirror = Mirror(reflecting: builder)
      for child in mirror.children where child.label == "cleanBeforeBuild" {
         return child.value as? Bool
      }
      return nil
   }

   /// Reflects on a SiteBuilder's private `config`, same idiom as `cleanBeforeBuild(of:)` –
   /// `SiteConfig.baseURL` itself is public once the config is extracted.
   private func siteConfig(of builder: SiteBuilder) -> SiteConfig? {
      let mirror = Mirror(reflecting: builder)
      for child in mirror.children where child.label == "config" {
         return child.value as? SiteConfig
      }
      return nil
   }

   private func makeBuilder() -> SiteBuilder {
      SiteBuilder.blog(
         config: SiteConfig(name: "Fixture", baseURL: "https://example.org"),
         projectDirectory: URL(fileURLWithPath: "/tmp/sitekit-build-arguments-test")
      )
   }

   @Test("build without --no-clean keeps the default clean")
   func buildDefaultCleans() {
      let builder = self.makeBuilder().applyingBuildArguments(["Site", "build"])
      #expect(self.cleanBeforeBuild(of: builder) == true)
   }

   @Test("build with --no-clean skips the clean")
   func buildNoCleanHonored() {
      let builder = self.makeBuilder().applyingBuildArguments(["Site", "build", "--no-clean"])
      #expect(self.cleanBeforeBuild(of: builder) == false)
   }

   @Test("serve with --no-clean skips the clean exactly like build")
   func serveNoCleanHonored() {
      let builder = self.makeBuilder().applyingBuildArguments(["Site", "serve", "--no-clean"])
      #expect(self.cleanBeforeBuild(of: builder) == false)
   }

   @Test("serve without --no-clean keeps the default clean")
   func serveDefaultCleans() {
      let builder = self.makeBuilder().applyingBuildArguments(["Site", "serve"])
      #expect(self.cleanBeforeBuild(of: builder) == true)
   }

   @Test("--no-clean and --base-url combine through the same seam")
   func noCleanCombinesWithBaseURL() {
      let builder = self.makeBuilder()
         .applyingBuildArguments(["Site", "serve", "--no-clean", "--base-url", "https://staging.example.org"])
      #expect(self.cleanBeforeBuild(of: builder) == false)
      #expect(self.siteConfig(of: builder)?.baseURL == "https://staging.example.org")
   }
}
