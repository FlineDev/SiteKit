import Foundation

/// One file a `Renderer` wants written to disk.
///
/// Renderers do not touch the filesystem directly: they return `OutputFile`
/// values and the pipeline writes them. `OutputFile` carries either text
/// (`content`) or raw bytes (`binaryContent`); favicons, generated PNGs, and
/// other non-textual outputs use the binary initializer. The `outputPath` is
/// always an absolute file URL inside `BuildContext.outputDirectory`.
public struct OutputFile {
   /// Absolute destination file URL inside `BuildContext.outputDirectory`;
   /// intermediate directories are created on write.
   public let outputPath: URL

   /// Text payload written as UTF-8; empty for binary files.
   public let content: String

   /// Raw byte payload; when set it wins over `content`.
   public let binaryContent: Data?

   /// Creates a text output file (HTML, XML, CSS, JSON, …).
   public init(outputPath: URL, content: String) {
      self.outputPath = outputPath
      self.content = content
      self.binaryContent = nil
   }

   /// Creates a binary output file (favicon, PNG, font, …).
   public init(outputPath: URL, binaryContent: Data) {
      self.outputPath = outputPath
      self.content = ""
      self.binaryContent = binaryContent
   }
}
