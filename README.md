# PatioFinder 🍹➡️

An iPhone app that points you to the nearest outdoor restaurant **patio** — a big
Find‑My‑style arrow that rotates as you turn, with the live distance underneath.
Swipe to cycle through other nearby patios, tap the list to jump to one, or open
the map to see it in context.

> Built with SwiftUI + CoreLocation + MapKit. No third‑party dependencies.

## Features

- **Directional arrow** that rotates using the device compass to point at the patio.
- **Live distance** in locale‑appropriate units (miles/feet in the US, km/m elsewhere).
- **Swipe left/right** on the arrow to cycle to the next‑nearest patio; a **list**
  button opens all nearby patios sorted by distance; a **map** button shows the
  selected patio with a walking‑directions handoff to Apple Maps.
- **Haptic + amber glow** when you're pointed straight at the patio.
- **Google Places** data (restaurants flagged with outdoor seating), with a bundled
  **sample list** so the app runs even before you add a key.
- Full light/dark support, warm terracotta design.

## Requirements

- Xcode 15 or newer
- iOS 17+ target
- **A physical iPhone** — the compass/heading does not work in the Simulator.

## Getting started

The fastest path is `./deploy.sh` (below), which generates the project, builds,
and installs to a connected iPhone in one command. To open it in Xcode manually:

1. Generate the project first: `xcodegen generate` (the `.xcodeproj` is not
   committed — `project.yml` is the source of truth). Then open `PatioFinder.xcodeproj`.
2. Select the **PatioFinder** target ▸ **Signing & Capabilities** and choose your
   development **Team** (needed to run on a device).
3. Build & run on your iPhone.
4. Grant **location** access when prompted.

That's it — with no API key the app runs in **demo mode** using the sample patios
in `PatioFinder/Resources/Patios.json` (centered on San Francisco). The arrow,
swiping, list, and map all work against that data.

### Using live Google Places data

1. Create a Google Cloud project and enable the **Places API (New)**.
2. Create an API key.
3. Open `Config.xcconfig` and replace the placeholder:
   ```
   GOOGLE_PLACES_API_KEY = your_real_key_here
   ```
4. (Optional) Keep your key out of git:
   ```
   git update-index --skip-worktree Config.xcconfig
   ```
5. Re‑run. The app now queries `places:searchNearby` for restaurants within ~15 miles
   (ranked nearest‑first, max 20 results) and keeps those flagged with `outdoorSeating`.
   If the call returns nothing (or fails), it falls back to the bundled sample list.

## How it works

| Concern | Where |
| --- | --- |
| Location + compass heading | `PatioFinder/Services/LocationService.swift` |
| Places fetching (Google + seed) | `PatioFinder/Services/*Provider.swift` |
| Sorting, selection, geometry | `PatioFinder/ViewModels/PatioViewModel.swift` |
| Bearing / arrow math | `PatioFinder/Utils/Geo.swift` |
| Distance formatting | `PatioFinder/Utils/DistanceFormatter.swift` |
| Arrow, main screen, list, map | `PatioFinder/Views/*` |

The arrow rotation is `bearingToPatio − deviceHeading`, so when you face the patio
the arrow points straight up.

## Manual test checklist

Run on a device and confirm:

- [ ] On launch it asks for location, then shows the nearest patio's name + arrow.
- [ ] Rotating your body rotates the arrow; facing the patio makes it point up,
      glow amber, and buzz once.
- [ ] The distance below the arrow matches your locale's units and updates as you move.
- [ ] Swiping the arrow left/right switches to the next/previous patio; the page
      dots and "Patio N of M" label update; **Back to nearest** returns to #1.
- [ ] The list button shows nearby patios sorted by distance; tapping one aims the arrow at it.
- [ ] The map button shows your location + the patio pin, with a Directions handoff.
- [ ] With a valid API key, real nearby patios appear; without one, the sample set loads.

## Regenerating the project (optional)

The committed `PatioFinder.xcodeproj` is ready to open. If you'd rather regenerate
it, a `project.yml` is included for [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
brew install xcodegen
xcodegen generate
```
