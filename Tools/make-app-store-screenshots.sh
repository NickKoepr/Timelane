#!/bin/zsh
# Builds an unsandboxed, ad-hoc signed Debug copy of Timelane (build/ScreenshotData), lets it capture every
# screenshot scene with sample data (see Timelane/Debug/Screenshots), then composes the App Store images.
# Usage: Tools/make-app-store-screenshots.sh [scene ...]     (default: all scenes)
# Output: build/AppStoreScreenshots/raw/*.png (captures) and build/AppStoreScreenshots/*.png (2880 x 1800).
# The copy has its own bundle id (…timelane.screenshots). The app comes to the front for a few seconds per scene; your own app and database are not touched.
set -euo pipefail
cd "$(dirname "$0")/.."

if (( $# )); then scenes=("$@"); else scenes=(timeline entryForm menuBar projects overview trackedApps settings); fi
raw="$PWD/build/AppStoreScreenshots/raw"
app="build/ScreenshotData/Build/Products/Debug/Timelane.app"
mkdir -p "$raw"

xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' \
    -derivedDataPath build/ScreenshotData -configuration Debug \
    ENABLE_APP_SANDBOX=NO CODE_SIGN_ENTITLEMENTS= CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    PRODUCT_BUNDLE_IDENTIFIER=nl.nickkoepr.timelane.screenshots build -quiet

for scene in $scenes; do
    echo "Capturing $scene"
    rm -f "$raw/$scene.png"
    # Fixed zoom levels via the argument domain (nothing is written to defaults).
    open -n -W "$app" --args -screenshotScene "$scene" -screenshotOutput "$raw" \
        -ApplePersistenceIgnoreState YES -timelineZoomLevel 0 -menuBarTimelineZoomLevel 0
    [[ -f "$raw/$scene.png" ]] || { echo "No capture for $scene" >&2; exit 1; }
done

# The own bundle id keeps the screenshot copy's preferences apart from the real app's.
defaults delete nl.nickkoepr.timelane.screenshots 2>/dev/null || true

swift Tools/compose-app-store-screenshots.swift "$raw" "$PWD/build/AppStoreScreenshots"
