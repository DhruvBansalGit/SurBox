#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
: "${ZIG:?Set ZIG to a Zig 0.14.1 executable for cross-compilation}"
OUT="$ROOT/artifacts/windows/SurBox-Windows-x64"
mkdir -p "$OUT/samples"
"$ZIG" c++ -target x86_64-windows-gnu -std=c++17 -O2 -municode -Wl,--subsystem,windows \
  -I "$ROOT/Sources/SurBoxDSP/include" \
  "$ROOT/cross-platform/windows/SurBox.cpp" "$ROOT/Sources/SurBoxDSP/SurBoxDSP.cpp" \
  -lwinmm -lcomctl32 -lgdi32 -luser32 -lshell32 -static -o "$OUT/SurBox.exe"
cp "$ROOT/Sources/SurBox/Resources/Samples/"*.wav "$OUT/samples/"
cp "$ROOT/Sources/SurBox/Resources/Audio-LICENSE.txt" "$OUT/Audio-LICENSE.txt"
python3 - "$ROOT" "$OUT" <<'PY'
import json,pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:]);records=json.loads((root/'Sources/SurBox/Resources/samples.json').read_text())
(out/'samples/manifest.txt').write_text(''.join(f'{r["midi"]} {r["loopStart"]} {r["loopEnd"]} {r["file"]}\n' for r in records))
PY
cp "$ROOT/cross-platform/windows/README.txt" "$OUT/README.txt"
(cd "$ROOT/artifacts/windows" && zip -qr SurBox-Windows-x64.zip SurBox-Windows-x64)
file "$OUT/SurBox.exe"
printf '\nBuilt %s\n' "$ROOT/artifacts/windows/SurBox-Windows-x64.zip"
