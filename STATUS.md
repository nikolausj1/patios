---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-07-27
version: 2.7
author: Claude Opus 4.8 (claude-opus-4-8)
tags:
---

# Patio Finder - Status

## Project

PatioFinder is an iPhone app with a Find-My-style compass arrow that rotates to point at the nearest outdoor restaurant patio, showing live distance, walking ETA, star rating, open-now status, and beer/wine/cocktail markers, with swipe-to-cycle, an Adult Drinks filter, and tap-to-directions via Apple Maps.

## Stage

Live (version 1.0 is on the App Store; version 1.1 with the Text Search patio engine was submitted 2026-07-27 and is Waiting for Review).

## Health

🟢 On-track. 1.0 was approved and is Ready for Sale; 1.1 (build 4, the Text Search engine that finds up to 60 nearby patios) is submitted and Waiting for Review with release notes set. No open blockers.

## Waiting on Me

Nothing.

## Next Up

1. Await the 1.1 review; it releases automatically on approval.
2. Sanity-check the live App Store product page (listing, icon, screenshots) now that the app is public.
3. Pick the next feature from the Ideas Shelf (cuisine filter and favorites are the small ones).

## Biggest Risk

A 1.1 review bounce would delay the much-better patio engine reaching users; low likelihood, since 1.1 changes only the data-fetch strategy relative to the approved 1.0 binary.

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing existing list and selection plumbing.
- **Weather glance 2.0** (M): re-add WeatherKit with the " Weather" attribution and a pre-made physical-device recording for review.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.
- **App Store name + subtitle** (S): consider renaming to "Patio Finder: <short tagline>". Text-only App Store change, no build needed, but the name field caps at 30 chars (about 16 left after "Patio Finder: "), must be unique on the store, and rides a version review. Decide name-with-colon vs. using the separate 30-char Subtitle field. Do it on a future version so the in-review release is not disturbed; the home-screen icon label (CFBundleDisplayName) is separate and would need a build if changed too.

## App Store Readiness

Post-submission (local, destined for 1.1): the Google provider was rewritten around Text Search paging (patio-relevance ranking, up to 60 results) with a 500 m distance-ranked safety net and rural widening; validated live from Capitol Hill (8 → 55 confirmed patios, nearest 0.38 → 0.02 mi) and 3101 W Government Way (7 → 59, nearest 0.73 → 0.47 mi).

- 2026-07-16: build 1 reviewed; Guideline 5.2.5 information request (WeatherKit attribution proof).
- 2026-07-24: weather feature and WeatherKit entitlement removed entirely (verified via codesign on the store binary); listing metadata, review notes, and the hosted privacy policy scrubbed of weather mentions; build 3 uploaded, swapped into the submission; reply sent confirming the app does not support WeatherKit; resubmitted — Waiting for Review.
- 2026-07-27: 1.0 approved and Ready for Sale. Same day, 1.1 (build 4, Text Search engine) was uploaded, its version record created via the ASC API with release notes, build attached, and submitted — Waiting for Review.
- The 1.0 binary also carries the Google Places key fix (X-Ios-Bundle-Identifier header), adaptive city/rural patio search, drink markers, the Adult Drinks filter, and stale-data refresh.

## Lessons

- Google Maps/Places API keys restricted to an iOS bundle id reject raw `URLSession` calls with 403 `API_KEY_IOS_APP_BLOCKED` unless every request sends an `X-Ios-Bundle-Identifier` header matching the restriction; the Google SDK adds it silently, hand-rolled clients must add it themselves. Bit this project in production: the app silently fell back to a worse data source. (promoted to Build Guide v2.8, 2026-07-27)
- The App Store Connect API cannot create app records (web UI only), and `xcodebuild -exportArchive` with ASC API-key auth 403s on cloud-managed distribution certificates unless the key has cert privileges; running the same export with no auth flags uses the Mac's signed-in Xcode account and succeeds. Relevant to every iOS app shipped from this machine. (promoted to Build Guide v2.8, 2026-07-27)
