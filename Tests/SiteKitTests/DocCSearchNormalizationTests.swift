import Foundation
import Testing

@testable import SiteKit

/// The sidebar filter, the ⌘K overlay, and the dedicated search page must all fold
/// typographic apostrophes/quotes to ASCII, strip apostrophes entirely, and lowercase –
/// applied to the query AND the searched fields – so "whats new", "what's new", and
/// "What’s New" hit the same titles. These assertions pin the shared normalization
/// function and its application points in each shipped script.
@Suite("DocC search normalization")
struct DocCSearchNormalizationTests {
   private func script(_ load: () throws -> String) throws -> String {
      try load()
   }

   /// The normalization core every script must carry: quote folding, apostrophe
   /// stripping, lowercasing, and the normalized→original index map for highlighting.
   private func expectNormalizationCore(in js: String) {
      #expect(js.contains("function normalizeWithMap(text)"))
      #expect(js.contains("function normalizeForSearch(text)"))
      #expect(js.contains(#"if (ch === "‘" || ch === "’") ch = "'";"#))
      #expect(js.contains(#"else if (ch === "“" || ch === "”") ch = "\"";"#))
      #expect(js.contains(#"if (ch === "'") continue;"#))
      #expect(js.contains("ch.toLowerCase()"))
      #expect(js.contains("map.push(i)"))
   }

   @Test("docc-filter.js normalizes query and every haystack")
   func filterScript() throws {
      let js = try script(DocCFilterScriptRenderer.loadScript)
      expectNormalizationCore(in: js)
      // Query side: the typed value is normalized once in applyFilter.
      #expect(js.contains("var query = normalizeForSearch(q.trim());"))
      // Haystack side: in-DOM rows, cross-year JSON titles, and year/branch labels.
      #expect(js.contains("normalizeForSearch(plainText).indexOf(query)"))
      #expect(js.contains("normalizeForSearch(title).indexOf(query)"))
      #expect(js.contains("normalizeForSearch(yearText).indexOf(query)"))
      #expect(js.contains("normalizeForSearch(labelEl.textContent).indexOf(query)"))
      // Highlighting maps the normalized hit back onto the original string.
      #expect(js.contains("var nm = normalizeWithMap(text);"))
      #expect(js.contains("var start = nm.map[idx];"))
      // The pre-normalization matching must be gone everywhere.
      #expect(!js.contains(".toLowerCase().indexOf(query)"))
   }

   @Test("docc-search.js normalizes terms and record fields, highlight maps back")
   func searchScript() throws {
      let js = try script(DocCSearchScriptRenderer.loadScript)
      expectNormalizationCore(in: js)
      // Record fields are folded once at index load, not per keystroke.
      #expect(js.contains("records[i].normTitle = normalizeForSearch(records[i].title || \"\");"))
      #expect(js.contains("records[i].normText = normalizeForSearch(records[i].text || \"\");"))
      // Scoring compares against the folded fields.
      #expect(js.contains("record.normTitle.indexOf(term)"))
      #expect(js.contains("record.normText.indexOf(term)"))
      // The query is normalized before splitting into terms.
      #expect(js.contains("var normalized = normalizeForSearch(query.trim());"))
      // Highlighting finds hits on the normalized text and maps ranges back.
      #expect(js.contains("nm.map[idx], nm.map[idx + term.length - 1] + 1"))
      #expect(!js.contains("record.title.toLowerCase()"))
   }

   @Test("docc-search-page.js normalizes terms and record fields, highlight maps back")
   func searchPageScript() throws {
      let js = try script(DocCSearchPageScriptRenderer.loadScript)
      expectNormalizationCore(in: js)
      #expect(js.contains("records[i].normTitle = normalizeForSearch(records[i].title || \"\");"))
      #expect(js.contains("records[i].normText = normalizeForSearch(records[i].text || \"\");"))
      #expect(js.contains("record.normTitle.indexOf(term)"))
      #expect(js.contains("record.normText.indexOf(term)"))
      #expect(js.contains("var normalized = normalizeForSearch(query.trim());"))
      #expect(js.contains("nm.map[idx], nm.map[idx + term.length - 1] + 1"))
      #expect(!js.contains("(record.title || \"\").toLowerCase()"))
   }

   @Test("Normalization function is identical across all three scripts")
   func normalizationKeptInSync() throws {
      func core(of js: String) throws -> String {
         let start = try #require(js.range(of: "function normalizeWithMap(text)"))
         let end = try #require(js.range(of: "return { norm: norm, map: map };", range: start.upperBound..<js.endIndex))
         let body = js[start.lowerBound..<end.upperBound]
         // Comment style differs per script (// vs /* */); compare the code itself.
         return body
            .replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"//[^\n]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      }
      let filter = try core(of: script(DocCFilterScriptRenderer.loadScript))
      let search = try core(of: script(DocCSearchScriptRenderer.loadScript))
      let page = try core(of: script(DocCSearchPageScriptRenderer.loadScript))
      #expect(filter == search)
      #expect(search == page)
   }
}
