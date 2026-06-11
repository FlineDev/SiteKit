import Foundation
import Yams

/// Generic `Loader` that decodes any `Decodable & Sendable` type from a
/// `YAMLSource`.
///
/// Used throughout SiteKit to load structured data (`SiteConfig`,
/// `ThemeConfig`, podcast metadata, blueprint manifests) through the
/// pipeline rather than bypassing it with ad-hoc `Yams` calls – keeps every
/// YAML decode subject to the same error-reporting and validation surface.
/// `Output` carries its own decoding behaviour, including `init(from:)`
/// overrides for legacy-name fallbacks (see `SiteConfig`'s lenient decoder).
public struct YAMLLoader<Output: Decodable & Sendable>: Loader {
   public typealias Source = YAMLSource

   public init() {}

   public func load(source: YAMLSource) throws -> Output {
      let decoder = YAMLDecoder()
      return try decoder.decode(Output.self, from: source.content)
   }
}
