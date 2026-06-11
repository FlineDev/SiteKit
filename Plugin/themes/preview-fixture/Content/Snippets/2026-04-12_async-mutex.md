---
id: e5f6a7b8
title: "AsyncMutex one-liner"
slug: async-mutex-one-liner
date: 2026-04-12
tags: [swift, concurrency]
summary: "A bounded async-safe critical section in three lines, no extra dependency."
---

`AsyncMutex` keeps the producer-consumer dance honest when an `actor` is too heavy:

```swift
let mutex = AsyncMutex<State>(.idle)
await mutex.withLock { state in state = .running }
```

It serialises access without isolating the value's lifetime, so you can keep the surrounding code synchronous.
