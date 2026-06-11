import SiteKit

@main struct Site {
   static func main() throws {
      try SiteBuilder.portfolio(configPath: "SiteConfig.yaml")
         .replacing(HomePageRenderer.self, with: LandingPageRenderer())
         .run()
   }
}
