---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-07-24
version: 2.1
author: Claude Opus 4.8 (claude-opus-4-8)
tags:
---

# Patio Finder - Status

## Project

PatioFinder is an iPhone app with a Find-My-style compass arrow that rotates to point at the nearest outdoor restaurant patio, showing live distance, walking ETA, star rating, open-now status, current weather, and beer/wine/cocktail markers, with swipe-to-cycle, an Adult Drinks filter, and tap-to-directions via Apple Maps.

## Stage

Beta (feature-complete; version 1.0 was submitted to the App Store and came back with an App Review information request).

## Health

🔴 Blocked. App Review returned the submission under Guideline 5.2.5 asking for proof of WeatherKit attribution; the app is compliant, but the reply requires a screen recording from a physical iPhone that only Justin can make. Everything else is staged and ready.

## Waiting on Me

- [ ] **Record a ~30-second screen recording on the iPhone** showing the weather line and tapping its " Weather" attribution link, then drop it in `_inbox/` (~2 min)
      - unblocks: the reply to Apple's 5.2.5 message, which is the only thing standing before resubmission
- [ ] **Approve hosting the recording** (suggested: the public `patios` GitHub repo) so the reply can link to it (~1 min)
      - unblocks: same as above; App Store Connect replies are text-only, so the video needs a URL

## Next Up

1. Justin records and drops the video; Claude hosts it, replies to Apple's message with the attribution explanation and link, and resubmits.
2. Await the re-review; version 1.0 (build 2) releases automatically on approval.
3. After approval, consider the Ideas Shelf items for a 1.1.

## Biggest Risk

The 5.2.5 reply sits unanswered until the physical-device recording exists; every day it waits is a day of review-queue time lost, and reviewers may eventually close stale submissions.

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing existing list and selection plumbing.
- **Text Search paging** (S-M): swap searchNearby (20-result cap) for Text Search with page tokens (up to 60) for denser city coverage.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.

## App Store Readiness

- Reviewed: version 1.0 build 1 on 2026-07-16; result was a Guideline 5.2.5 information request (WeatherKit attribution proof), not a content rejection.
- Since then: build 2 (adds the Google key bundle-id header fix, wider patio coverage, drink markers, Adult Drinks filter, live refresh on movement/foreground) was uploaded, swapped into the 1.0 submission, and the App Review notes now explain the WeatherKit attribution and where it appears.
- Remaining: Justin's screen recording → reply to the review message → resubmit. The app's attribution (" Weather" trademark linking to Apple's legal page, shown wherever weather data appears) already satisfies the guideline; the reply just has to demonstrate it.
