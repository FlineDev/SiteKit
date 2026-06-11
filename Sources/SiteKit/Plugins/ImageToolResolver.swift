import Foundation
import Logging
import Crypto

/// Shared tooling for image variant generation – used by both `ImageResizer`
/// (rewrites `<img>` tags) and `CSSBackgroundImageProcessor` (rewrites CSS
/// `background-image` declarations).
///
/// Encapsulates ImageMagick discovery, dimension probing, and variant generation
/// with a disk-backed cache keyed by `(src path, target width)`. Pulled out of
/// `ImageResizer` so both processors use identical logic and the same cache
/// directory – no duplicate variants, no inconsistent sizing.
enum ImageToolResolver {
   enum Tool {
      case magick7(path: String)
      case convert6(path: String)

      var path: String {
         switch self {
         case .magick7(let p), .convert6(let p): return p
         }
      }
   }

   enum VariantResult {
      case generated(String)
      case cacheHit(String)
      case failed
   }

   // MARK: - Discovery

   /// Locates `magick` (v7+) or `convert` (v6) on PATH. Returns nil when neither is available.
   static func find() -> Tool? {
      if let path = Self.which("magick") { return .magick7(path: path) }
      if let path = Self.which("convert") { return .convert6(path: path) }
      return nil
   }

   private static func which(_ name: String) -> String? {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["which", name]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = Pipe()
      do {
         try process.run()
         process.waitUntilExit()
         guard process.terminationStatus == 0 else { return nil }
         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
         return path.isEmpty ? nil : path
      } catch {
         return nil
      }
   }

   // MARK: - Identify

   /// Probes `(width, height)` of an image using ImageMagick's `identify`.
   /// Returns nil on read failure. Callers should cache results – each call
   /// spawns a subprocess.
   static func identifyDimensions(of file: URL, tool: Tool) -> (Int, Int)? {
      let process = Process()
      let path = tool.path
      if path.hasSuffix("magick") {
         process.executableURL = URL(fileURLWithPath: path)
         process.arguments = ["identify", "-format", "%w %h", file.path]
      } else {
         let identifyPath = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent("identify").path
         if FileManager.default.isExecutableFile(atPath: identifyPath) {
            process.executableURL = URL(fileURLWithPath: identifyPath)
            process.arguments = ["-format", "%w %h", file.path]
         } else {
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["identify", "-format", "%w %h", file.path]
         }
      }
      let outPipe = Pipe()
      process.standardOutput = outPipe
      process.standardError = Pipe()
      do {
         try process.run()
         process.waitUntilExit()
         guard process.terminationStatus == 0 else { return nil }
         let data = outPipe.fileHandleForReading.readDataToEndOfFile()
         guard let text = String(data: data, encoding: .utf8) else { return nil }
         let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
         guard parts.count >= 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }
         return (w, h)
      } catch {
         return nil
      }
   }

   // MARK: - Variant generation

   /// Ensures a resized variant of `originalSrc` exists at `targetWidth` inside the output
   /// directory. Caches generated variants under `.sitekit-cache/images/<sha8>-<w>w.<ext>`
   /// so subsequent builds (and sibling processors referencing the same image) reuse them.
   ///
   /// Returns the rooted URL path (e.g. `"/assets/hero-bg-720w.webp"`) suitable for
   /// direct use in HTML `src` / CSS `url()`.
   static func ensureVariant(
      originalSrc: String,
      outputDirectory: URL,
      cacheDir: URL,
      targetWidth: Int,
      fileExtension: String,
      tool: Tool,
      logger: Logger
   ) -> VariantResult {
      let srcPath = outputDirectory.appendingPathComponent(String(originalSrc.dropFirst()))
      let hash = Self.sha8(of: originalSrc)
      let variantName = "\(srcPath.deletingPathExtension().lastPathComponent)-\(targetWidth)w.\(fileExtension)"
      let cacheFile = cacheDir.appendingPathComponent("\(hash)-\(targetWidth)w.\(fileExtension)")
      let outputFile = srcPath.deletingLastPathComponent().appendingPathComponent(variantName)

      let variantRelative = "/" + outputFile.path.dropFirst(outputDirectory.path.count + 1)

      if FileManager.default.fileExists(atPath: cacheFile.path) {
         try? FileManager.default.removeItem(at: outputFile)
         if (try? FileManager.default.copyItem(at: cacheFile, to: outputFile)) != nil {
            return .cacheHit(variantRelative)
         }
         return .failed
      }
      if Self.resize(input: srcPath, output: cacheFile, targetWidth: targetWidth, tool: tool) {
         try? FileManager.default.removeItem(at: outputFile)
         if (try? FileManager.default.copyItem(at: cacheFile, to: outputFile)) != nil {
            return .generated(variantRelative)
         }
      }
      logger.warning("Failed to resize \(originalSrc) to \(targetWidth)w")
      return .failed
   }

   /// Runs ImageMagick to downscale `input` to at-most `targetWidth` pixels wide,
   /// writing to `output`. Uses `-resize WIDTHxWIDTH>` so source images smaller
   /// than the target are copied as-is – never upscaled.
   @discardableResult
   static func resize(input: URL, output: URL, targetWidth: Int, tool: Tool) -> Bool {
      try? FileManager.default.createDirectory(
         at: output.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
      let process = Process()
      process.executableURL = URL(fileURLWithPath: tool.path)
      process.arguments = [
         input.path,
         "-resize", "\(targetWidth)x\(targetWidth)>",
         "-quality", "85",
         "-strip",
         output.path,
      ]
      process.standardOutput = Pipe()
      process.standardError = Pipe()
      do {
         try process.run()
         process.waitUntilExit()
         return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: output.path)
      } catch {
         return false
      }
   }

   static func sha8(of string: String) -> String {
      let data = Data(string.utf8)
      let digest = SHA256.hash(data: data)
      return digest.map { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
   }
}
