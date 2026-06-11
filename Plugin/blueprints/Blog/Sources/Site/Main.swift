import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.blog(configPath: "SiteConfig.yaml").run()
   }
}
