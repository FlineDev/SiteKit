import Foundation
import Testing

@testable import SiteKitOpenAPI

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
      let url = try #require(
         Bundle.module.url(forResource: fixture.name, withExtension: fixture.fileExtension, subdirectory: "Fixtures"),
         "Missing fixture \(fixture)"
      )
      return try OpenAPISpecLoader().load(source: url)
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

   @Test("Rejects an unsupported OpenAPI major version")
   func unsupportedVersion() throws {
      let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      let url = directory.appendingPathComponent("unsupported-\(UUID().uuidString).yaml")
      let swagger2 = """
         swagger: '2.0'
         openapi: '2.0'
         info:
           title: Legacy
           version: 1.0.0
         paths: {}
         """
      try swagger2.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }

      #expect(throws: OpenAPISpecLoader.LoadError.self) {
         try OpenAPISpecLoader().load(source: url)
      }
   }
}
