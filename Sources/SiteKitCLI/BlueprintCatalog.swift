import Foundation

/// One blueprint entry: a PascalCase name and a one-line description.
struct Blueprint: Equatable {
   let name: String
   let description: String
}

enum BlueprintCatalogError: Error, CustomStringConvertible {
   case directoryNotFound(URL)
   case blueprintNotFound(name: String, available: [String])

   var description: String {
      switch self {
      case .directoryNotFound(let url):
         return "Blueprint catalog not found at \(url.path)."
      case .blueprintNotFound(let name, let available):
         return "Unknown blueprint '\(name)'. Available: \(available.joined(separator: ", "))."
      }
   }
}

/// Discovers and parses the on-disk blueprint catalog under `Plugin/blueprints/`.
///
/// Each blueprint is a `<Name>/` directory paired with a `<Name>.md` instruction file whose
/// third line is a bold one-line description (`**…**`). The catalog is the pairing of those two.
enum BlueprintCatalog {
   /// All blueprints found in `directory`, sorted by name.
   ///
   /// A blueprint counts only when both the `<Name>/` directory and a sibling `<Name>.md`
   /// exist. The description is the bold text on line 3 of `<Name>.md`, with the surrounding
   /// `**` stripped; when that line is absent the description is an empty string.
   static func all(in directory: URL) throws -> [Blueprint] {
      let manager = FileManager.default
      var isDirectory: ObjCBool = false
      guard manager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
         throw BlueprintCatalogError.directoryNotFound(directory)
      }

      let entries = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
      var blueprints: [Blueprint] = []
      for entry in entries {
         let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
         guard values.isDirectory == true else { continue }
         let name = entry.lastPathComponent
         let markdownURL = directory.appendingPathComponent("\(name).md")
         guard manager.fileExists(atPath: markdownURL.path) else { continue }
         let description = Self.description(fromMarkdownAt: markdownURL)
         blueprints.append(Blueprint(name: name, description: description))
      }
      return blueprints.sorted { $0.name < $1.name }
   }

   /// The blueprint with `name`, or a `blueprintNotFound` error listing what is available.
   static func blueprint(named name: String, in directory: URL) throws -> Blueprint {
      let all = try self.all(in: directory)
      guard let match = all.first(where: { $0.name == name }) else {
         throw BlueprintCatalogError.blueprintNotFound(name: name, available: all.map(\.name))
      }
      return match
   }

   /// Extracts the bold one-line description from line 3 of a blueprint `<Name>.md` file.
   static func description(fromMarkdownAt url: URL) -> String {
      guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return "" }
      let lines = contents.components(separatedBy: .newlines)
      guard lines.count >= 3 else { return "" }
      var line = lines[2].trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("**") && line.hasSuffix("**") && line.count >= 4 {
         line = String(line.dropFirst(2).dropLast(2))
      }
      return line
   }
}
