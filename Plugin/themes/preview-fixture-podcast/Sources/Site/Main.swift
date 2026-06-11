import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.podcast(configPath: "SiteConfig.yaml").run()
   }
}
