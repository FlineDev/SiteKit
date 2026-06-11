import Testing
@testable import SiteKit

@Suite("ImageVariantPlanner")
struct ImageVariantPlannerTests {
   private func role(name: String = "test", desktop: Int, mobile: Int) -> ImageRole {
      ImageRole(name: name, selector: "img", desktopWidth: desktop, mobileWidth: mobile)
   }

   @Test("Density strategy when mobile is close to desktop width")
   func densityStrategy() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 720, mobile: 390),
         sourceWidth: 2000,
         sourceHeight: 1125,
         mobileBreakpoint: 768
      )
      // 390 ≥ 720/2 = 360 – mobile not significantly narrower, use density.
      #expect(plan.strategy == .density)
      #expect(plan.displayWidth == 720)
      // Height derived from source aspect ratio 2000:1125.
      let expectedHeight = Int(Double(720) * Double(1125) / Double(2000) + 0.5)
      #expect(plan.displayHeight == expectedHeight)

      let widths = plan.uniqueTargetWidths
      #expect(widths.contains(720))
      #expect(widths.contains(1440))
   }

   @Test("Responsive strategy when mobile is significantly narrower")
   func responsiveStrategy() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 1400, mobile: 390),
         sourceWidth: 4000,
         sourceHeight: 2250,
         mobileBreakpoint: 768
      )
      // 390 × 2 = 780 < 1400 – responsive.
      #expect(plan.strategy == .responsive)
      #expect(plan.displayWidth == 1400)
      let widths = plan.uniqueTargetWidths
      // 390 × 3 = 1170 (mobile retina), 1400 (desktop 1×), 1400 × 2 = 2800 (desktop retina).
      #expect(widths.contains(1170))
      #expect(widths.contains(1400))
      #expect(widths.contains(2800))
   }

   @Test("Targets cap at source width (no upscaling)")
   func capAtSource() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 720, mobile: 390),
         sourceWidth: 512,
         sourceHeight: 512,
         mobileBreakpoint: 768
      )
      // desktop width 720 capped at 512. Retina 1440 also capped.
      // Both targets collapse onto source – plan still produces a valid single-entry srcset.
      #expect(plan.strategy == .density)
      #expect(plan.displayWidth == 512)
      // All targets end up at 512 → uniqueTargetWidths is [512].
      #expect(plan.uniqueTargetWidths == [512])
   }

   @Test("Small logo: both 1x and 2x fit under source")
   func smallLogo() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 32, mobile: 32),
         sourceWidth: 256,
         sourceHeight: 256,
         mobileBreakpoint: 768
      )
      #expect(plan.strategy == .density)
      #expect(plan.displayWidth == 32)
      #expect(plan.uniqueTargetWidths.contains(32))
      #expect(plan.uniqueTargetWidths.contains(64))
   }

   @Test("Zero source width does not crash")
   func zeroSourceWidth() {
      let plan = ImageVariantPlanner.plan(
         role: self.role(desktop: 720, mobile: 390),
         sourceWidth: 0,
         sourceHeight: 0,
         mobileBreakpoint: 768
      )
      #expect(plan.displayHeight >= 1)
   }
}
