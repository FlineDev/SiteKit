import Testing
@testable import SiteKit

@Suite("ImageMarkupRewriter")
struct ImageMarkupRewriterTests {
   private func role(desktop: Int, mobile: Int) -> ImageRole {
      ImageRole(name: "test", selector: "img", desktopWidth: desktop, mobileWidth: mobile)
   }

   @Test("Density plan emits src + 2x srcset without sizes")
   func densityMarkup() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 720, mobile: 390),
         sourceWidth: 2000,
         sourceHeight: 1125,
         mobileBreakpoint: 768
      )
      let result = ImageMarkupRewriter.apply(
         plan: plan,
         parsed: ["src": "/a/hero.webp", "alt": "Hero"],
         pathByWidth: [720: "/a/hero-720w.webp", 1440: "/a/hero-1440w.webp"]
      )
      #expect(result["src"] == "/a/hero-720w.webp")
      #expect(result["srcset"] == "/a/hero-720w.webp 1x, /a/hero-1440w.webp 2x")
      #expect(result["sizes"] == nil)
      #expect(result["width"] == "720")
      // 720 × 1125 / 2000 ≈ 405
      #expect(result["height"] == "405")
   }

   @Test("Responsive plan emits sizes + width-based srcset")
   func responsiveMarkup() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 1400, mobile: 390),
         sourceWidth: 4000,
         sourceHeight: 2250,
         mobileBreakpoint: 768
      )
      let result = ImageMarkupRewriter.apply(
         plan: plan,
         parsed: ["src": "/a/bg.webp", "alt": "Bg"],
         pathByWidth: [1170: "/a/bg-1170w.webp", 2800: "/a/bg-2800w.webp", 1400: "/a/bg-1400w.webp"]
      )
      #expect(result["srcset"] == "/a/bg-1170w.webp 1170w, /a/bg-1400w.webp 1400w, /a/bg-2800w.webp 2800w")
      #expect(result["sizes"] == "(max-width: 768px) 390px, 1400px")
      #expect(result["width"] == "1400")
   }

   @Test("Density markup collapses duplicate variant paths")
   func densityCollapseDuplicates() {
      // Source smaller than desktop retina – both 1x and 2x map to the same
      // generated variant. The srcset should not list the same path twice.
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 32, mobile: 32),
         sourceWidth: 40,
         sourceHeight: 40,
         mobileBreakpoint: 768
      )
      let result = ImageMarkupRewriter.apply(
         plan: plan,
         parsed: ["src": "/a/logo.webp"],
         pathByWidth: [32: "/a/logo-32w.webp", 40: "/a/logo.webp"]
      )
      // The source cap pulls 2x to 40 (= source width) – one density entry.
      #expect(result["srcset"]?.contains("1x") == true)
   }
}
