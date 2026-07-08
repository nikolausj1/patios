#!/usr/bin/env bash
#
# One-command deploy of PatioFinder to Justin's iPhone.
#
# Run this ON YOUR MAC from the repo root:
#
#     ./deploy.sh
#
# Defaults are baked in from the household deployment playbook (adult device →
# plain development build, Recipe A). It regenerates the project with XcodeGen if
# available, clears Dropbox xattrs, builds & signs, then installs and launches.
#
# Optional overrides (env vars or flags):
#     TEAM=6A4J2GTB6F              Apple Developer Team ID
#     BUNDLE_ID=com.levelup.patiofinder
#     DEVICE=<devicectl id/UDID>  target device (default: Justin's iPhone)
#     CONFIG=Debug|Release        build configuration (default: Debug)
#
set -euo pipefail

PROJECT="PatioFinder.xcodeproj"
SCHEME="PatioFinder"
CONFIG="${CONFIG:-Debug}"
DERIVED="build"
TEAM="${TEAM:-6A4J2GTB6F}"                                    # Justin Nikolaus (paid)
BUNDLE_ID="${BUNDLE_ID:-com.levelup.patiofinder}"             # com.levelup.<shortname>
DEVICE="${DEVICE:-DA1CF583-BC81-54E3-AFA8-11C8388367A6}"      # iPhone 16 Pro Max (adult)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) TEAM="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;33m▸ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

command -v xcodebuild >/dev/null || die "Xcode not found. Install it, then: sudo xcode-select -s /Applications/Xcode.app"
[[ -d "PatioFinder" ]] || die "Run this from the repo root (couldn't find the PatioFinder/ sources)."

# --- confirm the target device is connected ----------------------------------
step "Checking for the target iPhone…"
DEVJSON="$(mktemp)"; trap 'rm -f "$DEVJSON"' EXIT
xcrun devicectl list devices --json-output "$DEVJSON" >/dev/null 2>&1 || \
  die "Couldn't query devices. Need Xcode 15+ (devicectl). Is the iPhone plugged in and unlocked?"

if ! grep -q "$DEVICE" "$DEVJSON"; then
  step "Default iPhone not found — auto-detecting a connected iPhone…"
  DEVICE="$(python3 - "$DEVJSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for d in data.get("result", {}).get("devices", []):
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {}).get("tunnelState", "")
    is_iphone = "iphone" in (hw.get("deviceType","") + hw.get("productType","")).lower()
    if is_iphone:
        print(d.get("identifier","")); break
PY
)"
  [[ -n "$DEVICE" ]] || die "No iPhone detected. Plug it in, unlock, tap Trust, and enable Developer Mode (Settings ▸ Privacy & Security ▸ Developer Mode)."
  echo "  Using detected iPhone: $DEVICE"
else
  echo "  Target connected: $DEVICE"
fi

# --- regenerate project from project.yml (household source of truth) ---------
if command -v xcodegen >/dev/null 2>&1; then
  step "Regenerating $PROJECT from project.yml…"
  xcodegen generate
fi

# --- Dropbox codesigning guard -----------------------------------------------
xattr -cr . 2>/dev/null || true

# --- build & sign (Recipe A: generic device, automatic provisioning) ---------
step "Building & signing ($CONFIG) as $BUNDLE_ID…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build \
  | { command -v xcbeautify >/dev/null && xcbeautify || cat; }

APP_PATH="$DERIVED/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
[[ -d "$APP_PATH" ]] || die "Build succeeded but couldn't find $APP_PATH"

# --- install & launch --------------------------------------------------------
step "Installing onto the iPhone…"
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"

step "Launching…"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" || \
  echo "  Installed. Tap the app on your phone if it didn't auto-open."

printf '\n\033[1;32m✓ PatioFinder is on your iPhone.\033[0m\n'
echo "  It starts in demo mode (sample SF patios). Add your Google Places key to"
echo "  Config.xcconfig and re-run for live nearby patios."
