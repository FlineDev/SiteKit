import SiteKit

@main
struct Site {
   static func main() throws {
      try SiteBuilder.docc(configPath: "SiteConfig.yaml").run()
   }
}
