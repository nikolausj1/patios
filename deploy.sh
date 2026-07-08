#!/usr/bin/env bash
#
# One-command deploy of PatioFinder to a connected iPhone.
#
# Run this ON YOUR MAC (not in a remote environment) from the repo root:
#
#     ./deploy.sh
#
# It will: find your connected iPhone, build & sign the app with your Apple
# Developer team, install it, and launch it. Requires Xcode installed and the
# iPhone plugged in & trusted.
#
# Optional overrides (env vars or flags):
#     TEAM=XXXXXXXXXX          your 10-char Apple Developer Team ID
#     BUNDLE_ID=com.you.patio  app bundle identifier (must be unique to you)
#     DEVICE_UDID=...          target device UDID (auto-detected if omitted)
#     CONFIG=Debug|Release     build configuration (default: Debug)
#
set -euo pipefail

PROJECT="PatioFinder.xcodeproj"
SCHEME="PatioFinder"
CONFIG="${CONFIG:-Debug}"
DERIVED="build"
BUNDLE_ID="${BUNDLE_ID:-com.patiofinder.app}"

# --- flag parsing (flags override env) ---------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) TEAM="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --device) DEVICE_UDID="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;33m▸ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------
command -v xcodebuild >/dev/null || die "Xcode not found. Install Xcode from the App Store, then run: sudo xcode-select -s /Applications/Xcode.app"
[[ -d "$PROJECT" ]] || die "Run this from the repo root (couldn't find $PROJECT)."

# --- resolve the connected device --------------------------------------------
step "Looking for a connected iPhone…"
if [[ -z "${DEVICE_UDID:-}" ]]; then
  # Parse physical devices from xctrace (everything above the Simulators section).
  DEVICE_LINE="$(xcrun xctrace list devices 2>/dev/null \
    | awk '/== Simulators ==/{exit} /\([0-9A-Fa-f-]+\)[[:space:]]*$/{print}' \
    | grep -iv 'mac' \
    | head -n 1 || true)"
  [[ -n "$DEVICE_LINE" ]] || die "No iPhone detected. Plug it in, unlock it, tap Trust, and make sure Developer Mode is on (Settings ▸ Privacy & Security ▸ Developer Mode)."
  DEVICE_UDID="$(sed -E 's/.*\(([0-9A-Fa-f-]+)\)[[:space:]]*$/\1/' <<< "$DEVICE_LINE")"
  DEVICE_NAME="$(sed -E 's/[[:space:]]*\([^)]*\)[[:space:]]*$//; s/[[:space:]]*\([^)]*\)[[:space:]]*$//' <<< "$DEVICE_LINE")"
  echo "  Found: ${DEVICE_NAME:-iPhone}  ($DEVICE_UDID)"
else
  echo "  Using device: $DEVICE_UDID"
fi

# --- resolve the signing team ------------------------------------------------
if [[ -z "${TEAM:-}" ]]; then
  step "Detecting your Apple Developer Team ID…"
  TEAMS="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -oE '\(([0-9A-Z]{10})\)' | tr -d '()' | sort -u || true)"
  COUNT="$(grep -c . <<< "$TEAMS" || true)"
  if [[ "$COUNT" == "1" ]]; then
    TEAM="$TEAMS"
    echo "  Using team: $TEAM"
  elif [[ "$COUNT" -gt 1 ]]; then
    echo "  Multiple teams found:"; echo "$TEAMS" | sed 's/^/    /'
    die "Re-run with the one you want, e.g.:  ./deploy.sh --team ${TEAMS%%$'\n'*}"
  else
    die "No signing identity found. Open Xcode ▸ Settings ▸ Accounts, add your Apple ID once, then re-run. Or pass it explicitly: ./deploy.sh --team XXXXXXXXXX"
  fi
fi

# --- build & sign ------------------------------------------------------------
step "Building & signing ($CONFIG) for $BUNDLE_ID…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE_UDID" \
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
if xcrun devicectl --version >/dev/null 2>&1; then
  xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"
  step "Launching…"
  xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" || \
    echo "  Installed. Tap the app on your phone to open it."
elif command -v ios-deploy >/dev/null 2>&1; then
  ios-deploy --id "$DEVICE_UDID" --bundle "$APP_PATH" --justlaunch
else
  die "Installed nothing: need Xcode 15+ (devicectl) or 'brew install ios-deploy'. The .app is at $APP_PATH."
fi

printf '\n\033[1;32m✓ PatioFinder is on your iPhone.\033[0m\n'
echo "  First launch only: if it says 'Untrusted Developer', go to"
echo "  Settings ▸ General ▸ VPN & Device Management ▸ [your account] ▸ Trust,"
echo "  then grant Location when the app asks."
