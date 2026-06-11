import Foundation
import Testing

@testable import PreviewGeneratorKit

@Suite("PreviewVariants")
struct VariantTests {
   @Test("Catalog declares exactly nine variants")
   func catalogShapeIsNine() {
      #expect(previewVariants.count == 9)
   }

   @Test("Every layout template appears with three variants")
   func eachLayoutTemplateHasThreeVariants() {
      var counts: [String: Int] = [:]
      for variant in previewVariants {
         counts[variant.layoutTemplate, default: 0] += 1
      }
      #expect(counts == ["Classic": 3, "Sidebar": 3, "Minimal": 3])
   }

   @Test("Filename ids match the committed ThemePreview.html iframe references")
   func filenameIDsAreStable() {
      let expected = [
         "Classic-indigo-editorial-light",
         "Classic-slate-system-dark",
         "Classic-amber-modern-light",
         "Sidebar-slate-system-light",
         "Sidebar-indigo-modern-dark",
         "Sidebar-amber-editorial-light",
         "Minimal-amber-editorial-light",
         "Minimal-indigo-system-dark",
         "Minimal-slate-modern-light",
      ]
      #expect(previewVariants.map(\.id) == expected)
   }

   @Test("themeYAML wires every variant axis into the file content")
   func themeYAMLIncludesAxes() {
      let variant = PreviewVariant(
         layoutTemplate: "Sidebar",
         colorScheme: "slate",
         fontPairing: "system",
         mode: .dark
      )
      let yaml = variant.themeYAML()
      #expect(yaml.contains(#"name: "Sidebar""#))
      #expect(yaml.contains(#"colorScheme: "slate""#))
      #expect(yaml.contains(#"fontPairing: "system""#))
      #expect(yaml.contains(#""css/theme.css""#))
      #expect(yaml.contains(#""js/theme.js""#))
      #expect(yaml.contains(#"document.documentElement.setAttribute('data-theme','dark')"#))
   }

   @Test("Light variants force light mode in the head inline script")
   func themeYAMLForcesLightModeWhenLight() {
      let variant = PreviewVariant(
         layoutTemplate: "Classic",
         colorScheme: "amber",
         fontPairing: "modern",
         mode: .light
      )
      #expect(variant.themeYAML().contains("'data-theme','light'"))
      #expect(!variant.themeYAML().contains("'data-theme','dark'"))
   }
}
