#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts/testing
sh scripts/build-app.sh 2>&1 | tee artifacts/testing/build.txt
BIN="$(swift build -c release --show-bin-path)"
# XCTest isn't shipped by Command Line Tools. These are the SAME test bodies
# with a minimal assertion shim when XCTest cannot be imported.
swiftc -O -parse-as-library -I "$BIN/Modules" -I "$BIN/SurBoxDSP.build" \
  Tests/SurBoxCoreTests/InstrumentTests.swift \
  "$BIN/SurBoxCore.build/InstrumentCore.swift.o" "$BIN/SurBoxCore.build/LidMotion.swift.o" "$BIN/SurBoxDSP.build/SurBoxDSP.cpp.o" \
  -lc++ -o artifacts/testing/CoreChecks
artifacts/testing/CoreChecks | tee artifacts/testing/core-results.txt
APP="$PWD/artifacts/SurBox.app"
run_native() {
  local mode="$1"; shift
  "$APP/Contents/MacOS/SurBox" --self-test --report-dir="$PWD/artifacts/testing/$mode" "$@" > "artifacts/testing/$mode-process.txt" 2>&1
  cat "artifacts/testing/$mode/native-results.txt"
  grep -q 'failures=0' "artifacts/testing/$mode/native-results.txt"
}
run_native native --soak-seconds="${SOAK_SECONDS:-5}"
run_native fallback --fallback
run_native audio-error --audio-failure
# Relocate into a fresh directory, remove the WHOLE resource bundle, re-sign
# this throwaway copy only, and prove graceful fallback without developer paths.
TMP="$(mktemp -d /tmp/surbox-offline.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$APP" "$TMP/SurBox.app"
APP="$TMP/SurBox.app"
run_native relocated
rm -rf "$APP/Contents/Resources/SurBox_SurBox.bundle"
codesign --force --sign - "$APP"
run_native missing-resources --missing-resources
printf '\nAll standalone and native suites passed. Human listening, hardware input and hot-plug review remain separate.\n'
