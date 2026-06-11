# Meet the Foundation Models framework

Tap into the on-device large language model behind Apple Intelligence to add private, offline-capable generation to your app.

@Metadata {
   @TitleHeading("WWDC24 · Session 101")
   @PageKind(sampleCode)
   @CallToAction(url: "https://developer.apple.com/videos/", purpose: link, label: "Watch Video (18 min)")
   @Contributors {
      @GitHubUser(Jeehut)
   }
}

## Overview

The framework exposes a guided-generation API with type-safe outputs, tool calling, and streaming. This sample note shows how a SiteKit DocC catalog renders a real session note with a **Written By** block and related sessions.

## Tool calling

Register Swift functions the model may call, and the framework handles the round-trip for you.

@Small {
   WWDC content is owned by Apple Inc.; these are community notes and are not affiliated with or endorsed by Apple.
}
