#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product SurBox -j 4
BIN="$(swift build -c release --show-bin-path)"
APP="$PWD/artifacts/SurBox.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SurBox" "$APP/Contents/MacOS/SurBox"
cp -R "$BIN/SurBox_SurBox.bundle" "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
# Ad-hoc signing is local only; not Developer ID distribution/notarization.
codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
printf '\nBuilt %s\n' "$APP"
