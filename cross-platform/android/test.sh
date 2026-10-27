#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD";SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}";TOOLS="$SDK/build-tools/35.0.1"
BUILD="$ROOT/cross-platform/android/build";mkdir -p "$BUILD/test-classes" "$BUILD/test-dex" artifacts/testing/android
javac -source 8 -target 8 -Xlint:-options -encoding UTF-8 -cp "$SDK/platforms/android-35/android.jar:$BUILD/classes" -d "$BUILD/test-classes" cross-platform/android/tests/SurBoxInstrumentation.java
(cd "$BUILD/test-classes" && find . -name '*.class' > "$BUILD/test-class-list.txt" && "$TOOLS/d8" --lib "$SDK/platforms/android-35/android.jar" --classpath "$BUILD/classes" --min-api 26 --output "$BUILD/test-dex" @"$BUILD/test-class-list.txt")
"$TOOLS/aapt2" link -o "$BUILD/test-unsigned.apk" --manifest cross-platform/android/tests/AndroidManifest.xml -I "$SDK/platforms/android-35/android.jar"
(cd "$BUILD/test-dex" && zip -q "$BUILD/test-unsigned.apk" classes.dex)
"$TOOLS/zipalign" -f -p 4 "$BUILD/test-unsigned.apk" "$BUILD/test-aligned.apk"
"$TOOLS/apksigner" sign --ks "$SURBOX_ANDROID_KEYSTORE" --ks-key-alias surbox --ks-pass env:SURBOX_ANDROID_STOREPASS --out "$BUILD/test.apk" "$BUILD/test-aligned.apk"
ADB="$SDK/platform-tools/adb";DEVICE="${SURBOX_ANDROID_DEVICE:-emulator-5554}"
"$ADB" -s "$DEVICE" install -r artifacts/android/SurBox-Android.apk
"$ADB" -s "$DEVICE" install -r "$BUILD/test.apk"
"$ADB" -s "$DEVICE" shell am instrument -w ai.surbox.tests/ai.surbox.SurBoxInstrumentation | tee artifacts/testing/android/instrumentation.txt
"$ADB" -s "$DEVICE" pull /sdcard/Android/data/ai.surbox/files/verification/. artifacts/testing/android/
grep -q 'failures=0' artifacts/testing/android/android-results.txt
