---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-07-24
version: 2.0
author: Claude Opus 4.8 (claude-opus-4-8)
tags:
---

# Patio Finder - Status

## Project

PatioFinder is an iPhone app with a Find-My-style compass arrow that rotates to point at the nearest outdoor restaurant patio, showing live distance, walking ETA, star rating, open-now status, current weather, and small beer/wine/cocktail markers, with swipe-to-cycle, a filterable nearby list, and tap-to-directions via Apple Maps.

## Stage

Beta (feature-complete and running on the iPhone; version 1.0 has been submitted to the App Store and is Waiting for Review).

## Health

🟡 At-risk. The app works and is submitted, but the exact binary now sitting in App Review was built before today's fixes, so if it is approved as-is it will ship a degraded experience (see Biggest Risk). Today's improved build runs on the phone but is not yet the one under review.

## Waiting on Me

- [ ] **Decide whether to replace the in-review build** with today's build (Google key header fix, wider patio coverage, drink markers, Adult Drinks filter, live refresh) before it is approved, versus letting 1.0 ship and following up with an update (~5 min decision)
      - unblocks: shipping a correct first version instead of the regressed one
- [ ] **Upload the current build and swap it into the pending submission** once the above is decided (bump `CURRENT_PROJECT_VERSION`, export with distribution signing, upload, attach) (~30 min)
      - unblocks: App Review evaluating the build you actually want live
- [ ] **Confirm the generated app icon is final** (the amber arrow in the dark ticked bezel, already wired into the asset catalog) (~2 min)
      - unblocks: peace of mind before approval; it is the icon currently attached to the submission

## Next Up

1. Commit and push today's work so it is version-controlled, not only Dropbox-synced (in progress this session).
2. Decide on and, if chosen, upload the corrected build to replace the one in review.
3. Wait on Apple review (up to about 48 hours); version 1.0 is set to release automatically on approval.

## Biggest Risk

The build currently in App Review was produced before the Google Places API key was locked to the iOS bundle id AND before the app was taught to send the matching `X-Ios-Bundle-Identifier` header, so that binary will get 403s from Google and silently fall back to the sparse keyless MapKit search; approved as-is, it would ship a noticeably worse "missing patios" experience.

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing the existing list and selection plumbing.
- **Text Search paging** (S-M): swap searchNearby (20-result cap) for Text Search with page tokens (up to 60) for even denser city coverage.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.

## App Store Readiness

Version 1.0 is submitted and Waiting for Review. Completed via the App Store Connect API and browser this cycle:

- Done: app record created (Apple ID 6789832868), free pricing in all territories, screenshots (6.9" class), listing metadata, Food & Drink / Travel categories, 4+ age rating, App Privacy (Precise Location, App Functionality, not linked, no tracking), privacy policy and support URL hosted on the GitHub repo, distribution build uploaded, submitted for review with reviewer notes.
- Remaining: the build-swap decision above, then Apple's review outcome. Nothing else is blocked on manual steps.
