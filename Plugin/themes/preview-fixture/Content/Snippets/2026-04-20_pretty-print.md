---
id: f6a7b8c9
title: "Pretty-print Codable structs"
date: 2026-04-20
tags: [swift, debugging]
summary: "A debug-only `dump` replacement that respects `Codable` and is safe to leave in shipping code."
---

Use a single `JSONEncoder` with sorted keys to get diff-friendly output for any `Encodable`:

```swift
extension Encodable {
   var prettyJSON: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return (try? String(decoding: encoder.encode(self), as: UTF8.self)) ?? "<\(Self.self)>"
   }
}
```

Drop `print(value.prettyJSON)` in any breakpoint to skim state without spinning up the debugger view.
