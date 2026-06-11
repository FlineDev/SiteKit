---
id: c3d4e5f6
title: "Deploying to the edge"
date: 2026-02-18
tags: [deploy, cloudflare]
summary: "From a local build folder to a global CDN in a single command."
---

Shipping a static site is mostly a packaging problem: produce the right files, put them in the right places, and let the CDN do the rest.

SiteKit's deploy posture is intentionally boring – the output of `swift run Site build` is a flat folder of HTML, CSS, JS, and images that any host can serve. The interesting work happens at build time, not at deploy time.
