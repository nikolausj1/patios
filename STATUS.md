---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-07-24
version: 2.2
author: Claude Opus 4.8 (claude-opus-4-8)
tags:
---

# Patio Finder - Status

## Project

PatioFinder is an iPhone app with a Find-My-style compass arrow that rotates to point at the nearest outdoor restaurant patio, showing live distance, walking ETA, star rating, open-now status, and beer/wine/cocktail markers, with swipe-to-cycle, an Adult Drinks filter, and tap-to-directions via Apple Maps.

## Stage

Beta (feature-complete; version 1.0 build 3 resubmitted to App Review on 2026-07-24 and Waiting for Review).

## Health

🟢 On-track. The 5.2.5 review issue was resolved by removing the weather feature entirely (code, UI, and entitlement); the reply was sent to App Review, build 3 swapped in, and the submission is back in the queue with no open blockers.

## Waiting on Me

Nothing.

## Next Up

1. Await the re-review (typically up to 48 hours); 1.0 releases automatically on approval.
2. On approval, sanity-check the live App Store listing (weather-free description, icon, screenshots).
3. Pick a 1.1 candidate from the Ideas Shelf; if weather returns, prepare the WeatherKit attribution screen recording before submitting.

## Biggest Risk

A second review bounce on some new issue would restart the queue again; mitigations are already in place for the two known ones (WeatherKit removed; the reviewed binary now contains the Google key bundle-id header fix).

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing existing list and selection plumbing.
- **Text Search paging** (S-M): swap searchNearby (20-result cap) for Text Search with page tokens (up to 60) for denser city coverage.
- **Weather glance 2.0** (M): re-add WeatherKit with the " Weather" attribution and a pre-made physical-device recording for review.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.

## App Store Readiness

- 2026-07-16: build 1 reviewed; Guideline 5.2.5 information request (WeatherKit attribution proof).
- 2026-07-24: weather feature and WeatherKit entitlement removed entirely (verified via codesign on the store binary); listing metadata, review notes, and the hosted privacy policy scrubbed of weather mentions; build 3 uploaded, swapped into the submission; reply sent confirming the app does not support WeatherKit; resubmitted — Waiting for Review.
- The reviewed binary also carries the Google Places key fix (X-Ios-Bundle-Identifier header), adaptive city/rural patio search, drink markers, the Adult Drinks filter, and stale-data refresh.
