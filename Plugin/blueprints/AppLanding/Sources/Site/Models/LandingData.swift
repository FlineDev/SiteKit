import Foundation

struct LandingData: Decodable, Sendable {
   let appStoreURL: String
   let hero: HeroSection
   let features: [Feature]?
   let featureBanner: FeatureBannerSection?
   let testimonials: [Testimonial]?
   let pricing: PricingSection?
   let appStoreReviews: [AppStoreReview]?
   let trustedBy: [TrustedByApp]?
   let faq: [FAQItem]?
   let cta: CTASection?
   let techSpecs: TechSpecsSection?
}

struct HeroSection: Decodable, Sendable {
   let title: String
   let subtitle: String
}

struct FeatureBannerSection: Decodable, Sendable {
   let title: String
   let subtitle: String
   let ctaText: String
   let videoPath: String
}

struct Feature: Decodable, Sendable {
   let title: String
   let description: String
   let imagePath: String
}

struct Testimonial: Decodable, Sendable {
   let name: String
   let handle: String
   let avatarPath: String
   let quote: String
   let row: Int?
}

struct PricingSection: Decodable, Sendable {
   let title: String
   let subtitle: String
   let ctaText: String
   let tiers: [PricingTier]
}

struct PricingTier: Decodable, Sendable {
   let name: String
   let badge: String?
   let monthlyPrice: String
   let features: [String]
   let highlighted: Bool?
}

struct TechSpecsSection: Decodable, Sendable {
   let columns: [TechSpecColumn]
}

struct TechSpecColumn: Decodable, Sendable {
   let title: String
   let items: [String]
}

struct AppStoreReview: Decodable, Sendable {
   let quote: String
   let author: String
   let location: String
   let avatarPath: String?
}

struct TrustedByApp: Decodable, Sendable {
   let name: String
   let url: String
   let iconPath: String?
}

struct FAQItem: Decodable, Sendable {
   let question: String
   let answer: String
}

struct CTASection: Decodable, Sendable {
   let title: String
   let buttonText: String
}
