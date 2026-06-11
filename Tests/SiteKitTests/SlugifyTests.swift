import Testing
@testable import SiteKit

@Suite("String.slugified()")
struct SlugifyTests {
   @Test("Converts simple title to slug")
   func simpleTitle() {
      #expect("Hello World".slugified() == "hello-world")
   }

   @Test("Handles already-lowercase text")
   func alreadyLowercase() {
      #expect("hello world".slugified() == "hello-world")
   }

   @Test("Strips special characters")
   func specialCharacters() {
      #expect("Hello, World! How's it going?".slugified() == "hello-world-how-s-it-going")
   }

   @Test("Handles multiple spaces and hyphens")
   func multipleSpaces() {
      #expect("Hello   World---Test".slugified() == "hello-world-test")
   }

   @Test("Preserves unicode alphanumeric characters")
   func unicodeCharacters() {
      #expect("Über Cool Café".slugified() == "über-cool-café")
   }

   @Test("Handles numbers")
   func withNumbers() {
      #expect("Swift 6 Typed Throws".slugified() == "swift-6-typed-throws")
   }

   @Test("Handles empty string")
   func emptyString() {
      #expect("".slugified() == "")
   }

   @Test("Handles string with only special characters")
   func onlySpecialChars() {
      #expect("---!!!---".slugified() == "")
   }

   @Test("Preserves hyphens between words")
   func existingHyphens() {
      #expect("multi-platform-app".slugified() == "multi-platform-app")
   }

   @Test("Handles parentheses and brackets")
   func bracketsAndParens() {
      #expect("The Composable Architecture (TCA)".slugified() == "the-composable-architecture-tca")
   }

   @Test("German language replaces umlauts and ß")
   func germanUmlauts() {
      #expect("Über uns".slugified(language: "de") == "ueber-uns")
      #expect("Größe".slugified(language: "de") == "groesse")
      #expect("Straße".slugified(language: "de") == "strasse")
      #expect("Ärger".slugified(language: "de") == "aerger")
   }

   @Test("Non-German language preserves umlauts")
   func nonGermanPreservesUmlauts() {
      #expect("Über Cool".slugified() == "über-cool")
      #expect("Über Cool".slugified(language: "en") == "über-cool")
   }
}
