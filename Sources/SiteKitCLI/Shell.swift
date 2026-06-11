import Foundation

/// The result of running an external process.
struct ShellResult {
   let exitCode: Int32
   let standardOutput: String
   let standardError: String

   var combinedOutput: String {
      (self.standardOutput + "\n" + self.standardError).trimmingCharacters(in: .whitespacesAndNewlines)
   }
}

/// Thin wrapper around `Process` for the handful of external commands the CLI shells out to
/// (`git`, `swift`, `gh`, `swift package update`, `swift build`).
enum Shell {
   /// Runs `command` with `arguments`, optionally in `directory`. Returns `nil` when the
   /// executable cannot be launched at all (e.g. the tool is not installed).
   @discardableResult
   static func run(_ command: String, _ arguments: [String] = [], in directory: URL? = nil) -> ShellResult? {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [command] + arguments
      if let directory { process.currentDirectoryURL = directory }

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      do {
         try process.run()
      } catch {
         return nil
      }

      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

      return ShellResult(
         exitCode: process.terminationStatus,
         standardOutput: String(decoding: outputData, as: UTF8.self),
         standardError: String(decoding: errorData, as: UTF8.self)
      )
   }
}
