import Foundation
import Testing

@testable import SiteKit

/// Shared fixture for the configPath tests: a directory holding two distinguishable
/// configurations so a test can prove WHICH file was loaded, not just THAT one was.
private enum ConfigPathFixture {
   static let defaultName = "Default Config"
   static let stagingName = "Staging Config"
   static let nestedName = "Nested Config"

   /// Writes a minimal valid site configuration with the given site name.
   static func writeConfig(named siteName: String, to fileURL: URL) throws {
      try """
      name: "\(siteName)"
      baseURL: "https://example.org"
      contentDirectory: "Content"
      outputDirectory: "_Site"
      """.write(to: fileURL, atomically: true, encoding: .utf8)
   }

   /// Creates a temp directory with `SiteConfig.yaml`, a sibling `Staging.yaml`,
   /// and a nested `Config/Nested.yaml` – each carrying a unique site name.
   static func makeDirectory() throws -> URL {
      let directory = FileManager.default.temporaryDirectory
         .appendingPathComponent("sitekit-configpath-fixture-\(UUID().uuidString)")
      let nestedDirectory = directory.appendingPathComponent("Config")
      try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
      try self.writeConfig(named: self.defaultName, to: directory.appendingPathComponent("SiteConfig.yaml"))
      try self.writeConfig(named: self.stagingName, to: directory.appendingPathComponent("Staging.yaml"))
      try self.writeConfig(named: self.nestedName, to: nestedDirectory.appendingPathComponent("Nested.yaml"))
      return directory
   }
}

@Suite("SiteConfigLoading")
struct SiteConfigLoadingTests {
   @Test("load(contentsOf:) loads a config file under any name")
   func loadContentsOfCustomFile() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let config = try SiteConfig.load(contentsOf: directory.appendingPathComponent("Staging.yaml"))
      #expect(config.name == ConfigPathFixture.stagingName)
   }

   @Test("load(contentsOf:) throws fileNotFound for a missing file")
   func loadContentsOfMissingFile() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      #expect(throws: SiteConfigError.self) {
         try SiteConfig.load(contentsOf: directory.appendingPathComponent("Missing.yaml"))
      }
   }

   @Test("load(from:) keeps loading <directory>/SiteConfig.yaml")
   func loadFromDirectoryUnchanged() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let config = try SiteConfig.load(from: directory)
      #expect(config.name == ConfigPathFixture.defaultName)
   }
}

/// Serialized because the `configPath:` factories resolve against the process working
/// directory, which these tests must temporarily switch – a process-global state no
/// parallel test may observe mid-switch.
@Suite("ConfigPathFactories", .serialized)
struct ConfigPathFactoryTests {
   private struct WorkingDirectorySwitchFailed: Error {}

   /// Reflects on a SiteBuilder's private `config`, mirroring the idiom in
   /// `BuildArgumentsTests` – there is no public read path by design.
   private func siteConfig(of builder: SiteBuilder) -> SiteConfig? {
      let mirror = Mirror(reflecting: builder)
      for child in mirror.children where child.label == "config" {
         return child.value as? SiteConfig
      }
      return nil
   }

   /// Runs `body` with the process working directory switched to `directory`,
   /// restoring the previous working directory afterwards.
   private func inWorkingDirectory<T>(_ directory: URL, _ body: () throws -> T) throws -> T {
      let fileManager = FileManager.default
      let previousPath = fileManager.currentDirectoryPath
      guard fileManager.changeCurrentDirectoryPath(directory.path) else {
         throw WorkingDirectorySwitchFailed()
      }
      defer { _ = fileManager.changeCurrentDirectoryPath(previousPath) }
      return try body()
   }

   @Test("All five configPath factories load the file the caller names")
   func factoriesHonorConfigPath() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let factories: [(name: String, make: (String) throws -> SiteBuilder)] = [
         ("blog", { try SiteBuilder.blog(configPath: $0) }),
         ("portfolio", { try SiteBuilder.portfolio(configPath: $0) }),
         ("newsletter", { try SiteBuilder.newsletter(configPath: $0) }),
         ("podcast", { try SiteBuilder.podcast(configPath: $0) }),
         ("docc", { try SiteBuilder.docc(configPath: $0) }),
      ]

      try self.inWorkingDirectory(directory) {
         for factory in factories {
            let builder = try factory.make("Staging.yaml")
            #expect(
               self.siteConfig(of: builder)?.name == ConfigPathFixture.stagingName,
               "factory \(factory.name) must load the config file named by configPath"
            )
         }
      }
   }

   @Test("A configPath in a subdirectory resolves relative to the working directory")
   func nestedConfigPathResolves() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let builder = try self.inWorkingDirectory(directory) {
         try SiteBuilder.blog(configPath: "Config/Nested.yaml")
      }
      #expect(self.siteConfig(of: builder)?.name == ConfigPathFixture.nestedName)
   }

   @Test("An absolute configPath is honored as-is")
   func absoluteConfigPathResolves() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let builder = try self.inWorkingDirectory(directory) {
         try SiteBuilder.blog(configPath: directory.appendingPathComponent("Staging.yaml").path)
      }
      #expect(self.siteConfig(of: builder)?.name == ConfigPathFixture.stagingName)
   }

   @Test("The default SiteConfig.yaml path keeps loading exactly today's file")
   func defaultPathUnchanged() throws {
      let directory = try ConfigPathFixture.makeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let builder = try self.inWorkingDirectory(directory) {
         try SiteBuilder.blog(configPath: "SiteConfig.yaml")
      }
      #expect(self.siteConfig(of: builder)?.name == ConfigPathFixture.defaultName)
   }
}
