import Foundation

/// A person referenced across SiteKit: blog author, podcast host/guest, site owner.
///
/// Decodes from both a plain string and a dictionary in YAML/JSON:
/// - `author: "Jane Doe"` → `Person(name: "Jane Doe")`
/// - `author: {name: "Jane Doe", url: "https://jane.dev"}` → full Person
public struct Person: Sendable, Equatable {
   /// Display name – the only required field.
   public let name: String

   /// Homepage or profile URL the person's name links to.
   public let url: String?

   /// Avatar image path or URL (frontmatter accepts `imageURL` or `image`).
   public let imageURL: String?

   /// Contact email; podcast feeds emit it as `<itunes:email>`.
   public let email: String?

   /// Memberwise initializer; everything beyond `name` is optional.
   public init(
      name: String,
      url: String? = nil,
      imageURL: String? = nil,
      email: String? = nil
   ) {
      self.name = name
      self.url = url
      self.imageURL = imageURL
      self.email = email
   }

   /// Parse from YAML frontmatter value (untyped dictionary).
   public static func from(frontmatterValue: Any) -> Person? {
      if let name = frontmatterValue as? String {
         return Person(name: name)
      }
      if let dict = frontmatterValue as? [String: Any], let name = dict["name"] as? String {
         return Person(
            name: name,
            url: dict["url"] as? String,
            imageURL: dict["imageURL"] as? String ?? dict["image"] as? String,
            email: dict["email"] as? String
         )
      }
      return nil
   }
}

extension Person: Codable {
   private enum CodingKeys: String, CodingKey {
      case name, url, imageURL, email
   }

   public init(from decoder: Decoder) throws {
      // Try decoding as a plain string first
      if let container = try? decoder.singleValueContainer(),
         let name = try? container.decode(String.self)
      {
         self.name = name
         self.url = nil
         self.imageURL = nil
         self.email = nil
         return
      }

      // Otherwise decode as a keyed container
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.url = try container.decodeIfPresent(String.self, forKey: .url)
      self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
      self.email = try container.decodeIfPresent(String.self, forKey: .email)
   }
}
