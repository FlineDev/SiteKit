import Foundation
import Testing

@testable import SiteKitOpenAPI

/// Loads a fixture from the test bundle's `Fixtures` directory and runs it through the loader.
private func loadFixture(_ name: String, _ fileExtension: String = "yaml") throws -> OpenAPISpec {
   let url = try #require(
      Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures"),
      "Missing fixture \(name).\(fileExtension)"
   )
   return try OpenAPISpecLoader().load(source: url)
}

@Suite("OpenAPISpecLoader")
struct OpenAPISpecLoaderTests {
   /// One fixture in the 2×2 decode matrix: an OpenAPI major version crossed with a serialization format.
   struct Fixture: Sendable, CustomStringConvertible {
      let name: String
      let fileExtension: String
      var description: String { "\(self.name).\(self.fileExtension)" }
   }

   /// The full matrix: OpenAPI 3.0 and 3.1, each as YAML and JSON. Every fixture is the same logical
   /// Petstore, so all four must decode into an identical model – which is itself the proof that the
   /// 3.0 (via OpenAPIKitCompat conversion) and 3.1 (direct) paths normalize to one 3.1 shape.
   static let fixtures: [Fixture] = [
      Fixture(name: "petstore-3.0", fileExtension: "yaml"),
      Fixture(name: "petstore-3.0", fileExtension: "json"),
      Fixture(name: "petstore-3.1", fileExtension: "yaml"),
      Fixture(name: "petstore-3.1", fileExtension: "json"),
   ]

   private func loadSpec(_ fixture: Fixture) throws -> OpenAPISpec {
      try loadFixture(fixture.name, fixture.fileExtension)
   }

   @Test("Decodes the info block", arguments: fixtures)
   func info(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      #expect(spec.info.title == "Swagger Petstore")
      #expect(spec.info.version == "1.0.0")
      #expect(spec.info.description?.contains("sample API") == true)
   }

   @Test("Decodes the server list", arguments: fixtures)
   func servers(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      #expect(spec.servers.count == 1)
      let server = try #require(spec.servers.first)
      #expect(server.url == "https://petstore.swagger.io/v1")
      #expect(server.description == "Production server")
   }

   @Test("Decodes the tag list", arguments: fixtures)
   func tags(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      #expect(spec.tags.count == 1)
      let tag = try #require(spec.tags.first)
      #expect(tag.name == "pets")
      #expect(tag.description == "Everything about your Pets")
   }

   @Test("Flattens every path/method into one operation list", arguments: fixtures)
   func operationCount(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      // GET /pets, POST /pets, GET /pets/{petId}
      #expect(spec.operations.count == 3)
   }

   @Test("Maps a known operation's method, path, tags, parameters, and responses", arguments: fixtures)
   func knownOperation(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      let operation = try #require(
         spec.operations.first { $0.method == "GET" && $0.path == "/pets/{petId}" },
         "Missing GET /pets/{petId}"
      )
      #expect(operation.operationId == "showPetById")
      #expect(operation.summary == "Info for a specific pet")
      #expect(operation.tags == ["pets"])
      #expect(operation.deprecated == false)

      let parameter = try #require(operation.parameters.first { $0.name == "petId" })
      #expect(parameter.location == .path)
      #expect(parameter.required == true)
      #expect(parameter.schema?.type == "string")

      let statusCodes = operation.responses.map(\.statusCode)
      #expect(statusCodes.contains("200"))
      #expect(statusCodes.contains("default"))
      let okResponse = try #require(operation.responses.first { $0.statusCode == "200" })
      #expect(okResponse.content.first?.contentType == "application/json")
      #expect(okResponse.content.first?.schema?.referenceName == "Pet")
   }

   @Test("Maps an operation's request body", arguments: fixtures)
   func requestBody(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      let operation = try #require(spec.operations.first { $0.method == "POST" && $0.path == "/pets" })
      let body = try #require(operation.requestBody)
      #expect(body.required == true)
      #expect(body.content.first?.contentType == "application/json")
      #expect(body.content.first?.schema?.referenceName == "Pet")
   }

   @Test("Maps component schemas with properties and required fields", arguments: fixtures)
   func schemas(_ fixture: Fixture) throws {
      let spec = try self.loadSpec(fixture)
      let names = spec.schemas.map(\.name)
      #expect(names.contains("Pet"))
      #expect(names.contains("Pets"))
      #expect(names.contains("Error"))

      let pet = try #require(spec.schemas.first { $0.name == "Pet" })
      #expect(pet.schema.type == "object")
      #expect(pet.schema.required.contains("id"))
      #expect(pet.schema.required.contains("name"))
      let nameProperty = try #require(pet.schema.properties.first { $0.name == "name" })
      #expect(nameProperty.schema.type == "string")
      #expect(nameProperty.required == true)
      let idProperty = try #require(pet.schema.properties.first { $0.name == "id" })
      #expect(idProperty.schema.format == "int64")

      let pets = try #require(spec.schemas.first { $0.name == "Pets" })
      #expect(pets.schema.type == "array")
      #expect(pets.schema.items.first?.referenceName == "Pet")
   }
}

/// Coverage for the schema-mapping branches the Petstore happy path never touches:
/// `nullable` convergence across 3.0/3.1, `enum`, schema-level `deprecated`, and
/// `oneOf` + discriminator. The `features-3.0`/`features-3.1` fixtures carry the
/// same logical schemas in each dialect, so a shared assertion run over both also
/// proves the 3.0-via-Compat path preserves these facets.
@Suite("OpenAPISpecLoader feature mapping")
struct OpenAPISpecLoaderFeatureTests {
   /// The same feature schemas expressed in 3.0 and in 3.1 (both YAML).
   static let dialects = ["features-3.0", "features-3.1"]

   @Test("Normalizes nullable identically: 3.0 `nullable: true` and 3.1 `[\"T\",\"null\"]`")
   func nullableConverges() throws {
      let spec30 = try loadFixture("features-3.0")
      let spec31 = try loadFixture("features-3.1")
      let nickname30 = try #require(self.nicknameProperty(in: spec30))
      let nickname31 = try #require(self.nicknameProperty(in: spec31))

      #expect(nickname30.schema.nullable == true)
      #expect(nickname31.schema.nullable == true)
      #expect(nickname30.schema.type == "string")
      #expect(nickname31.schema.type == "string")
      // The whole node converges, not just the two facets above – the core correctness claim.
      #expect(nickname30.schema == nickname31.schema)
   }

   @Test("Maps enum values", arguments: dialects)
   func enumValues(_ fixture: String) throws {
      let spec = try loadFixture(fixture)
      let widget = try #require(spec.schemas.first { $0.name == "Widget" })
      let status = try #require(widget.schema.properties.first { $0.name == "status" })
      #expect(status.schema.enumValues == ["available", "pending", "sold"])
   }

   @Test("Maps schema-level deprecated", arguments: dialects)
   func deprecatedField(_ fixture: String) throws {
      let spec = try loadFixture(fixture)
      let widget = try #require(spec.schemas.first { $0.name == "Widget" })
      let legacyId = try #require(widget.schema.properties.first { $0.name == "legacyId" })
      #expect(legacyId.schema.deprecated == true)
   }

   @Test("Maps oneOf composition with its discriminator", arguments: dialects)
   func oneOfDiscriminator(_ fixture: String) throws {
      let spec = try loadFixture(fixture)
      let animal = try #require(spec.schemas.first { $0.name == "Animal" })
      let composition = try #require(animal.schema.composition)
      #expect(composition.kind == .oneOf)
      #expect(Set(composition.subschemas.compactMap(\.referenceName)) == ["Cat", "Dog"])
      let discriminator = try #require(composition.discriminator)
      #expect(discriminator.propertyName == "petType")
      // The mapping value is captured faithfully (the raw spec value – here a `$ref`
      // string); S2 resolves it to a schema page when rendering.
      #expect(discriminator.mapping["cat"] == "#/components/schemas/Cat")
   }

   private func nicknameProperty(in spec: OpenAPISpec) -> OpenAPISpec.SchemaProperty? {
      spec.schemas.first { $0.name == "Widget" }?.schema.properties.first { $0.name == "nickname" }
   }
}

/// Coverage for the loader's error paths: an unsupported version (a real Swagger
/// 2.0 document with no `openapi` field), an empty file, malformed YAML, and a
/// missing file.
@Suite("OpenAPISpecLoader errors")
struct OpenAPISpecLoaderErrorTests {
   @Test("A Swagger 2.0 document (no openapi field) throws unsupportedVersion, not a DecodingError")
   func swagger2IsRejected() throws {
      let url = try #require(Bundle.module.url(forResource: "swagger-2.0", withExtension: "yaml", subdirectory: "Fixtures"))
      #expect(throws: OpenAPISpecLoader.LoadError.unsupportedVersion("<missing>")) {
         try OpenAPISpecLoader().load(source: url)
      }
   }

   @Test("An empty spec throws")
   func emptySpecThrows() throws {
      let url = try Self.writeTemporary("", fileExtension: "yaml")
      defer { try? FileManager.default.removeItem(at: url) }
      #expect(throws: (any Error).self) {
         try OpenAPISpecLoader().load(source: url)
      }
   }

   @Test("A malformed YAML spec throws")
   func malformedSpecThrows() throws {
      let url = try Self.writeTemporary("openapi: '3.1.0'\npaths: { : : :", fileExtension: "yaml")
      defer { try? FileManager.default.removeItem(at: url) }
      #expect(throws: (any Error).self) {
         try OpenAPISpecLoader().load(source: url)
      }
   }

   @Test("A missing file throws")
   func missingFileThrows() throws {
      let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
         .appendingPathComponent("does-not-exist-\(UUID().uuidString).yaml")
      #expect(throws: (any Error).self) {
         try OpenAPISpecLoader().load(source: url)
      }
   }

   private static func writeTemporary(_ contents: String, fileExtension: String) throws -> URL {
      let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
         .appendingPathComponent("openapi-loader-\(UUID().uuidString).\(fileExtension)")
      try contents.write(to: url, atomically: true, encoding: .utf8)
      return url
   }
}
