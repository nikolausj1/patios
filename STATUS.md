---
title: "STATUS - Patio Finder"
created: 2026-07-24
modified: 2026-08-19
version: 2.9
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Patio Finder - Status

## Project

PatioFinder is an iPhone app with a Find-My-style compass arrow that rotates to point at the nearest outdoor restaurant patio, showing live distance, walking ETA, star rating, open-now status, and beer/wine/cocktail markers, with swipe-to-cycle, an Adult Drinks filter, and tap-to-directions via Apple Maps.

## Stage

Live. Version 1.1 (the Text Search patio engine) was approved and released to the App Store on 2026-07-28 and is the current public version. No version is in review; the next work ships as 1.2.

## Health

🟢 On-track. 1.1 shipped without a review bounce. No open blockers. The Google Maps Platform deprecation notice received 2026-08-19 was triaged and requires no action from this project (see below).

## Waiting on Me

Nothing. In particular, the Google deprecation email needs **no Google Cloud Console change** — it concerns the Places SDK for iOS, which this app does not link.

## Next Up

1. Make Google-provider failure loud rather than silent (see Biggest Risk). Currently a Places outage, billing lapse, or key restriction silently degrades the app to MapKit results with no user-visible signal.
2. Fix the stale success footer in `deploy.sh` (line 112): it prints "It starts in demo mode (sample SF patios). Add your Google Places key..." unconditionally on every run, including runs where the key is present and the live provider is active. Gate it on the key actually being set. Pairs naturally with item 1 — both are misleading-signal bugs pointing in opposite directions.
3. Pick the 1.2 feature from the Ideas Shelf. Cuisine filter and favorites are the small ones; the App Store name/subtitle change is now unblocked since nothing is in review.

## Biggest Risk

The silent-fallback failure mode is still present in `PatioViewModel.load`. Any throw from the Google provider is caught and answered with MapKit data, and the load is reported as `.loaded`; a Google-side failure therefore surfaces as "the app got noticeably worse at finding patios," not as an error. This is exactly how the `API_KEY_IOS_APP_BLOCKED` bug hid in production. The `X-Ios-Bundle-Identifier` fix itself is intact (`GooglePlacesProvider.execute`), so the known trigger is closed, but the concealment path is not.

---

## Ideas Shelf

- **Cuisine filter** (S): filter the arrow target and list by cuisine, on top of Google Places data already fetched.
- **Favorites** (S-M): star a patio to jump straight to it, reusing existing list and selection plumbing.
- **Weather glance 2.0** (M): re-add WeatherKit with the " Weather" attribution and a pre-made physical-device recording for review.
- **Optional iPad (universal) support** (M): mostly layout work; would let it run on the household iPads too.
- **App Store name + subtitle** (S): consider renaming to "Patio Finder: <short tagline>". Text-only App Store change, no build needed, but the name field caps at 30 chars (about 16 left after "Patio Finder: "), must be unique on the store, and rides a version review. Decide name-with-colon vs. using the separate 30-char Subtitle field. No longer blocked by an in-review release; the home-screen icon label (CFBundleDisplayName) is separate and would need a build if changed too.

## App Store Readiness

Shipped. 1.1 is live and carries the Text Search engine (patio-relevance ranking, up to 60 results) with a 500 m distance-ranked safety net and rural widening; validated live from Capitol Hill (8 → 55 confirmed patios, nearest 0.38 → 0.02 mi) and 3101 W Government Way (7 → 59, nearest 0.73 → 0.47 mi).

- 2026-07-16: build 1 reviewed; Guideline 5.2.5 information request (WeatherKit attribution proof).
- 2026-07-24: weather feature and WeatherKit entitlement removed entirely (verified via codesign on the store binary); listing metadata, review notes, and the hosted privacy policy scrubbed of weather mentions; build 3 uploaded, swapped into the submission; reply sent confirming the app does not support WeatherKit; resubmitted — Waiting for Review.
- 2026-07-27: 1.0 approved and Ready for Sale. Same day, 1.1 (build 4, Text Search engine) was uploaded, its version record created via the ASC API with release notes, build attached, and submitted.
- 2026-07-28: **1.1 approved and released** (confirmed 2026-08-19 via the public iTunes Lookup API, `currentVersionReleaseDate` 2026-07-28T16:45:10Z). Store page: https://apps.apple.com/us/app/patiofinder/id6789832868
- The 1.0 binary also carries the Google Places key fix (X-Ios-Bundle-Identifier header), adaptive city/rural patio search, drink markers, the Adult Drinks filter, and stale-data refresh.

## Since 1.1

- Repo moved out of Dropbox to `~/_Developer/Patio Finder` via a fresh clone (the old repo's git was corrupt; everything committed was safe on GitHub). The Dropbox copy is a leftover with a `MOVED.md` and is not to be read or written.
- `deploy.sh` now builds into `/tmp/patiofinder-build` rather than an in-repo `build/`, so build output never enters a synced folder again. Merged as `23cb49f`. **Verified on device 2026-08-19**: full `./deploy.sh` run built, signed, installed, and launched on the iPhone (`JustinN`, iPhone 16 Pro Max); no `build/` directory was recreated in the repo and 89 MB of DerivedData landed in `/tmp`. Note `/tmp` is cleared periodically by macOS, so the first build after a reboot is cold.
- Confirmed during that run that the Google key reaches the binary: the built `PatioFinder.app/Info.plist` carries a 39-character `GooglePlacesAPIKey`, so the live provider is active. The `deploy.sh` "demo mode" footer that suggests otherwise is unconditional output, not a real signal (see Next Up item 2).
- Google Maps Platform deprecation notice (2026-08-19, project `boreal-physics-172622`) triaged: **not applicable**. It deprecates `GMSPlacesClient` / `PlacesClient` search methods in the Places SDK for iOS, removed in SDK 12.0.0 in Q3 2027. This app links no SDK — `GooglePlacesProvider` POSTs directly to the `places.googleapis.com/v1` REST endpoints over `URLSession`. Google's official deprecations page lists nothing against those web-service endpoints. No code change, no console change.

## Lessons

- Google Maps/Places API keys restricted to an iOS bundle id reject raw `URLSession` calls with 403 `API_KEY_IOS_APP_BLOCKED` unless every request sends an `X-Ios-Bundle-Identifier` header matching the restriction; the Google SDK adds it silently, hand-rolled clients must add it themselves. Bit this project in production: the app silently fell back to a worse data source. (promoted to Build Guide v2.8, 2026-07-27)
- The App Store Connect API cannot create app records (web UI only), and `xcodebuild -exportArchive` with ASC API-key auth 403s on cloud-managed distribution certificates unless the key has cert privileges; running the same export with no auth flags uses the Mac's signed-in Xcode account and succeeds. Relevant to every iOS app shipped from this machine. (promoted to Build Guide v2.8, 2026-07-27)
- Google Maps Platform deprecation emails are scoped to one *surface*, and the surfaces share method names. A notice titled for the Places SDK for iOS lists only Objective-C/Swift method signatures (`GMSPlacesClient`, `PlacesClient`) and does not touch apps that call the Places API (New) REST endpoints `places:searchText` / `places:searchNearby` directly — despite the identical names. Before planning any migration, check whether the project actually links the SDK (a dependency-free project calling `places.googleapis.com/v1` over `URLSession` does not), and confirm against https://developers.google.com/maps/deprecations, which is the authority and lists the web-service endpoints nowhere. These emails go to every Cloud project with the API enabled, not only to projects Google detected using the deprecated calls, so "your affected projects" is not evidence of exposure.
- An app's live App Store version and release date can be read without App Store Connect credentials from the public iTunes Lookup API: `https://itunes.apple.com/lookup?bundleId=<bundle id>` returns `version`, `currentVersionReleaseDate`, and the release notes as JSON. Fastest way to reconcile a stale "Waiting for Review" status in a status file against reality.
- Verify configuration reaches the *built binary*, not the build script's own output. A deploy script's closing message can be an unconditional `echo` that has drifted from reality — here it announced "demo mode, add your API key" on every run, including runs where the key was correctly injected. The check that actually settles it is reading the value out of the built product (`PlistBuddy -c "Print :SomeKey" .../YourApp.app/Info.plist`) and asserting on its length or prefix shape rather than printing it, which keeps secrets out of the transcript.
- Never let Xcode DerivedData live inside a cloud-synced folder (Dropbox, iCloud Drive). A single in-repo `build/` directory wedged Dropbox with 2,529 files here and coincided with git corruption that cost the local history. Point `-derivedDataPath` at `/tmp` or `~/Library/Developer/Xcode/DerivedData`; a `.gitignore` entry keeps it out of git but does nothing about the sync client.
