---
id: d4e5f6a7
title: "Working with async sequences in Swift"
date: 2026-05-18
tags: [swift, concurrency]
summary: "Iterate over time-varying values with the same vocabulary you already use for arrays."
image: "/assets/async-sequence-pipeline.svg"
imageAlt: "Diagram of a producer-consumer pipeline with backpressure"
---

An `AsyncSequence` is the natural extension of `Sequence` into the world of `await`. Once you internalise that single sentence the rest of the API surface falls into place: every operator you know from arrays – `map`, `filter`, `prefix`, `reduce` – has a sibling that suspends instead of blocking. You write loops; the runtime arranges the awaiting.

## The mental model

A regular `for` loop pulls one element at a time from a `Sequence`. A `for await` loop does the same thing, but each pull is allowed to suspend until the next element is ready. Producers push values whenever they have one; the consumer's task is parked between elements without spending a thread. That is the whole compromise.

### What suspension actually buys you

Three properties, none of which are obvious from the syntax:

1. **Backpressure for free.** A slow consumer naturally throttles a fast producer, because the producer cannot deliver the next element until the consumer is ready to receive it.
2. **Cancellation reaches the loop.** When the enclosing `Task` is cancelled, the next `await` inside the `for await` body unwinds – no manual flag-checking required.
3. **No buffer to size.** Pull-based delivery means you never have to pick "how many events to keep around" up front; the sequence holds at most one.

## A worked example

Suppose you want to read lines from a file handle as they arrive, run them through a parser, and stop on the first malformed entry. With `AsyncSequence` the shape is unsurprising:

```swift
func validate(_ url: URL) async throws -> Int {
   var count = 0
   for try await line in url.lines {
      guard let event = LogEvent(line) else {
         throw ValidationError.malformedLine(count)
      }
      count += 1
      print("parsed", event.identifier)
   }
   return count
}
```

The loop reads exactly as if `url.lines` were an array; the only difference is the `try await`. Compose that with `prefix(100)` or `filter { $0.isError }` and the result is still an `AsyncSequence` – the operators chain without forcing materialisation.

> Async sequences are the rare API where the type system pulls its weight: once a value is an `AsyncSequence`, you cannot accidentally treat it as synchronous, and the compiler points at the missing `await` for you.

### Things to watch for

Three sharp edges that bite even experienced users:

- **`AsyncSequence` is single-pass.** Iterating consumes it. If two consumers need the same stream, multicast it first.
- **Cancellation only fires at suspension points.** A tight CPU-bound loop inside `for await` ignores cancellation until it `await`s again.
- **Error propagation needs `try await`.** A throwing `next()` will silently terminate the loop if you forget – the compiler now warns, but old code may not.

#### A small typed-throws note

Swift 6 introduced typed throws for `AsyncSequence` via the associated `Failure` type. In practice this means a `for try await` loop can declare exactly which error it expects, and the compiler enforces the contract end-to-end – useful when wrapping a third-party producer whose error space you would rather not leak into your code.

## When not to reach for it

Async sequences shine for *streams of events over time*. They are overkill for one-off async values – `async` functions already give you those. They are also a poor fit for *random-access* needs: there is no `subscript(_:)` on an async sequence, and there is no good reason to fake one.

A short checklist:

- The producer emits more than one element. ✓
- The consumer wants to react incrementally, not after the whole stream completes. ✓
- The values are produced over time, not all at once. ✓

If two of the three are missing, an `async` function returning an `Array` is probably the simpler answer.

## Further reading

For a deeper dive into the wider Swift Concurrency model, the [Apple docs on Concurrency](https://developer.apple.com/documentation/swift/concurrency) cover task groups, actors, and the structured-concurrency rules that govern when and how a `for await` loop is allowed to suspend.

@LinkCard(url: "https://github.com/apple/swift-async-algorithms", title: "apple/swift-async-algorithms") {
Operators for async sequences – `merge`, `zip`, `debounce`, `chunked` and more – maintained by the Swift team.
}
