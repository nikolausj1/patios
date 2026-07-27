---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-07-24
version: 2.4
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

- [ ] **Field-test the new Text Search patio engine** already running on the iPhone: walk a couple of Seattle blocks and confirm the nearest-patio results feel right (~15 min)
      - unblocks: the green light to publish it as 1.1 the moment 1.0 is approved

## Next Up

1. Await the re-review (typically up to 48 hours); 1.0 releases automatically on approval.
2. STANDING PLAN: once 1.0 is approved AND Justin's field test confirms the new engine is good, publish it as 1.1 (bump version, upload, submit) without further prompting.
3. Sanity-check the live App Store listing after approval (weather-free description, icon, screenshots).

## Biggest Risk

A second review bounce on some new issue would restart the queue again; mitigations are already in place for the two known ones (WeatherKit removed; the reviewed binary now contains the Google key bundle-id header fix).

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing existing list and selection plumbing.
- **Weather glance 2.0** (M): re-add WeatherKit with the " Weather" attribution and a pre-made physical-device recording for review.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.

## App Store Readiness

Post-submission (local, destined for 1.1): the Google provider was rewritten around Text Search paging (patio-relevance ranking, up to 60 results) with a 500 m distance-ranked safety net and rural widening; validated live from Capitol Hill (8 → 55 confirmed patios, nearest 0.38 → 0.02 mi) and 3101 W Government Way (7 → 59, nearest 0.73 → 0.47 mi).

- 2026-07-16: build 1 reviewed; Guideline 5.2.5 information request (WeatherKit attribution proof).
- 2026-07-24: weather feature and WeatherKit entitlement removed entirely (verified via codesign on the store binary); listing metadata, review notes, and the hosted privacy policy scrubbed of weather mentions; build 3 uploaded, swapped into the submission; reply sent confirming the app does not support WeatherKit; resubmitted — Waiting for Review.
- The reviewed binary also carries the Google Places key fix (X-Ios-Bundle-Identifier header), adaptive city/rural patio search, drink markers, the Adult Drinks filter, and stale-data refresh.

## Lessons

- Google Maps/Places API keys restricted to an iOS bundle id reject raw `URLSession` calls with 403 `API_KEY_IOS_APP_BLOCKED` unless every request sends an `X-Ios-Bundle-Identifier` header matching the restriction; the Google SDK adds it silently, hand-rolled clients must add it themselves. Bit this project in production: the app silently fell back to a worse data source.
- The App Store Connect API cannot create app records (web UI only), and `xcodebuild -exportArchive` with ASC API-key auth 403s on cloud-managed distribution certificates unless the key has cert privileges; running the same export with no auth flags uses the Mac's signed-in Xcode account and succeeds. Relevant to every iOS app shipped from this machine.
