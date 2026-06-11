import Testing
@testable import SiteKit

@Suite("SelectorMatcher")
struct SelectorMatcherTests {
   private func candidate(
      tag: String = "img",
      classes: Set<String> = [],
      ancestors: [(String, Set<String>)] = []
   ) -> SelectorMatcher.Candidate {
      SelectorMatcher.Candidate(
         tagName: tag,
         classes: classes,
         ancestors: ancestors.map { SelectorMatcher.Candidate.Ancestor(tagName: $0.0, classes: $0.1) }
      )
   }

   @Test("Tag-only selector matches on tag name")
   func tagOnly() {
      #expect(SelectorMatcher.matches(selector: "img", candidate: self.candidate()))
      #expect(!SelectorMatcher.matches(selector: "span", candidate: self.candidate()))
   }

   @Test("Class-only selector requires class to be present")
   func classOnly() {
      let c = self.candidate(classes: ["sk-post-image"])
      #expect(SelectorMatcher.matches(selector: ".sk-post-image", candidate: c))
      #expect(!SelectorMatcher.matches(selector: ".other", candidate: c))
   }

   @Test("tag.class requires both")
   func tagAndClass() {
      let imgWithClass = self.candidate(classes: ["hero"])
      let spanWithClass = self.candidate(tag: "span", classes: ["hero"])
      #expect(SelectorMatcher.matches(selector: "img.hero", candidate: imgWithClass))
      #expect(!SelectorMatcher.matches(selector: "img.hero", candidate: spanWithClass))
      #expect(!SelectorMatcher.matches(selector: "img.hero", candidate: self.candidate()))
   }

   @Test("Multiple class tokens on a single element all required")
   func multipleClasses() {
      let c = self.candidate(classes: ["one", "two", "three"])
      #expect(SelectorMatcher.matches(selector: ".one.two", candidate: c))
      #expect(SelectorMatcher.matches(selector: ".two.three", candidate: c))
      #expect(!SelectorMatcher.matches(selector: ".one.four", candidate: c))
   }

   @Test("Child combinator > matches immediate parent only")
   func childCombinator() {
      let nested = self.candidate(ancestors: [("figure", ["sk-article-hero"]), ("main", [])])
      #expect(SelectorMatcher.matches(selector: "figure.sk-article-hero > img", candidate: nested))

      // Moving sk-article-hero up one level – the immediate parent is now a <div>
      // without that class, so the child combinator fails even though the class is
      // still somewhere in the ancestor chain.
      let indirect = self.candidate(ancestors: [("div", []), ("figure", ["sk-article-hero"])])
      #expect(!SelectorMatcher.matches(selector: "figure.sk-article-hero > img", candidate: indirect))
   }

   @Test("Descendant combinator (space) matches any ancestor")
   func descendantCombinator() {
      // Markdown-rendered article body image: <div class="sk-article-body"><p><img></p></div>
      let articleBodyImage = self.candidate(ancestors: [("p", []), ("div", ["sk-article-body"])])
      #expect(SelectorMatcher.matches(selector: ".sk-article-body img", candidate: articleBodyImage))
   }

   @Test("Mixed combinators: descendant then child")
   func mixedCombinators() {
      let c = self.candidate(
         ancestors: [("span", ["label"]), ("section", ["card"]), ("main", [])]
      )
      // `.card > span.label img` → section.card must be 2nd ancestor, span.label must
      // be immediate parent, img is the target.
      #expect(SelectorMatcher.matches(selector: ".card > span.label img", candidate: c))

      // `.main span.label img` → span.label must be some ancestor, main must be some
      // earlier ancestor (because descendant).
      #expect(SelectorMatcher.matches(selector: "main span.label img", candidate: c))
   }

   @Test("Comma list: any branch succeeding wins")
   func commaList() {
      let c = self.candidate(classes: ["home-avatar"])
      #expect(SelectorMatcher.matches(selector: ".home-avatar, .sk-article-author-image", candidate: c))

      // Both branches fail.
      #expect(!SelectorMatcher.matches(selector: ".foo, .bar", candidate: c))
   }

   @Test("img alone with no ancestors matches `img` selector")
   func rootImg() {
      #expect(SelectorMatcher.matches(selector: "img", candidate: self.candidate()))
   }

   @Test("Descendant selector fails when no ancestors present")
   func descendantWithoutAncestors() {
      #expect(!SelectorMatcher.matches(selector: ".foo img", candidate: self.candidate()))
   }
}
