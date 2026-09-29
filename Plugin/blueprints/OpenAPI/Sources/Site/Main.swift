import SiteKit
import SiteKitOpenAPI

@main
struct Site {
   static func main() throws {
      try SiteBuilder.openAPI(configPath: "SiteConfig.yaml").run()
   }
}
