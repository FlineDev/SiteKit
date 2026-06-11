import Testing

@testable import SiteKit

@Suite("DocCVariantSwitcher")
struct DocCVariantSwitcherTests {
   @Test("Renders both variants in the DOM with a default-Community toggle")
   func rendersBothVariants() {
      let html = DocCVariantSwitcher().render(
         community: "<p>Community body</p>",
         ai: "<p>AI body</p>",
         slug: "wwdc24-1-x"
      )
      // Both bodies are present in the DOM (so both stay AI-fetchable).
      #expect(html.contains("<p>Community body</p>"))
      #expect(html.contains("<p>AI body</p>"))
      // Radio + label toggle, Community checked by default.
      #expect(html.contains("sk-docc-variant-radio-community") && html.contains("checked"))
      #expect(html.contains("sk-docc-variant-radio-ai"))
      // Mode-switch cards carry the faithful prototype labels (each a <label> driving its radio).
      #expect(html.contains("sk-docc-modeswitch"))
      // Community card uses the full "Community Notes" label from UIStrings.
      #expect(html.contains("<b>Community Notes</b>"))
      // AI card: "AI Notes beta" (the "BETA" tag is lowercase "beta" per the prototype).
      #expect(html.contains("<b>AI Notes <span class=\"sk-docc-beta\">beta</span></b>"))
      #expect(html.contains("for=\"sk-variant-wwdc24-1-x-community\""))
      #expect(html.contains("sk-docc-mode--ai"))
      // The AI disclaimer banner is present (CSS reveals it only when AI is active).
      #expect(html.contains("sk-docc-ai-banner"))
      // Namespaced so it never collides with in-content @TabNavigator.
      #expect(html.contains("sk-docc-variants"))
   }

   @Test("Returns the community body unchanged when there is no AI variant")
   func noAIVariant() {
      let body = "<p>Just community</p>"
      #expect(DocCVariantSwitcher().render(community: body, ai: nil, slug: "x") == body)
      #expect(DocCVariantSwitcher().render(community: body, ai: "", slug: "x") == body)
   }
}
