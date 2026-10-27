#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
TOOLS="$SDK/build-tools/35.0.1"
BUILD="$ROOT/cross-platform/android/build"
RES="$ROOT/Sources/SurBox/Resources"
mkdir -p "$BUILD/classes" "$BUILD/dex" "$BUILD/assets" "$ROOT/artifacts/android"
cp "$RES"/Samples/*.wav "$BUILD/assets/"
cp "$RES/samples.json" "$RES/Audio-LICENSE.txt" "$BUILD/assets/"
# Native Java/Canvas + AudioTrack; no Gradle/network dependency resolution.
cd "$ROOT/cross-platform/android"
find src -name '*.java' > "$BUILD/sources.txt"
javac -source 8 -target 8 -Xlint:-options -encoding UTF-8 -classpath "$SDK/platforms/android-35/android.jar" -d "$BUILD/classes" @"$BUILD/sources.txt"
cd "$BUILD/classes"
find . -name '*.class' > "$BUILD/classes.txt"
"$TOOLS/d8" --lib "$SDK/platforms/android-35/android.jar" --min-api 26 --output "$BUILD/dex" @"$BUILD/classes.txt"
"$TOOLS/aapt2" link -o "$BUILD/unsigned.apk" --manifest "$ROOT/cross-platform/android/AndroidManifest.xml" -I "$SDK/platforms/android-35/android.jar" -A "$BUILD/assets" --min-sdk-version 26 --target-sdk-version 35
(cd "$BUILD/dex" && zip -q "$BUILD/unsigned.apk" classes.dex)
"$TOOLS/zipalign" -f -p 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
# Signing material must stay outside Git. APK signing is mandatory even for
# direct installs. Supply these variables from your secure local key store.
: "${SURBOX_ANDROID_KEYSTORE:?Set SURBOX_ANDROID_KEYSTORE to your private release keystore}"
: "${SURBOX_ANDROID_STOREPASS:?Set SURBOX_ANDROID_STOREPASS for this process only}"
"$TOOLS/apksigner" sign --ks "$SURBOX_ANDROID_KEYSTORE" --ks-key-alias surbox --ks-pass env:SURBOX_ANDROID_STOREPASS --out "$ROOT/artifacts/android/SurBox-Android.apk" "$BUILD/aligned.apk"
"$TOOLS/apksigner" verify --verbose --print-certs "$ROOT/artifacts/android/SurBox-Android.apk"
printf '\nBuilt %s\n' "$ROOT/artifacts/android/SurBox-Android.apk"
