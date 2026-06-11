import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.newsletter(configPath: "SiteConfig.yaml")
         .run()
   }
}
