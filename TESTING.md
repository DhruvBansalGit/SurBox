# SurBox verification

## Latest update: physical MacBook lid input

**Hardware blocker:** this MacBookAir10,1 (2020 M1 Air) exposes no compatible continuous lid-angle HID sensor. The real IOKit probe and unavailable-state UI were verified. No actual physical lid-motion success is claimed. [Full findings and implementation](LID_TRACKING.md).

The revised release passes **16 deterministic groups** and **53 primary native checks** (54 in the audio-error suite), including the original instrument checks plus actual sensor discovery and six explicitly injected lid-reading integration checks. The latest primary run includes another 60-second eight-voice soak. Software wiring is tested; hand-moved sensor latency, jitter and hardware behavior remain blocked on this machine. Xcode source references now include both lid-input modules.

One combined multi-suite verification command hit its 240-second tool timeout after the primary, fallback, audio-error and relocation suites completed. The remaining missing-resource case and network-denied check were rerun separately and passed. The first standalone missing-resource invocation omitted the test's `--missing-resources` flag, so it correctly failed two expectations for a full sample bank; rerunning with the correct flag passed, without a product-code change. Some stress runs were substantially slower under host load; no new 60 FPS or latency guarantee is made. The linked per-run logs contain the current exact results.

**The remainder documents the original instrument-release milestone.** Its counts and timing numbers are historical; the updated logs and lid report above supersede them. These original audio/UI checks must not be mistaken for physical-screen acceptance.

Date: 2026-10-27. Host: macOS 15.5, Apple Silicon arm64, Apple Swift 6.1 / Command Line Tools. Target minimum: macOS 14. **Full Xcode and XCTest are not installed on this host.**

## Delivered build

- [Native app](artifacts/SurBox.app), [app ZIP](artifacts/SurBox-macOS-arm64.zip), [source ZIP](artifacts/SurBox-source.zip).
- Release SwiftPM build succeeded without warnings in the final build; local ad-hoc codesign strict verification passed. Executable is Mach-O arm64.
- The actual app was launched repeatedly in a logged-in GUI session and started AVAudioEngine on the host output device.
- [Build log](artifacts/testing/build.txt), [deterministic results](artifacts/testing/core-results.txt).
- [Xcode project](SurBox.xcodeproj) plist, shared scheme XML and source/resource references checked. A real Xcode build or XCTest/XCUITest run is **not** claimed.

## Automated results

**12 deterministic test groups passed**, using exactly the included XCTest test bodies under a standalone assertion shim because the XCTest module is missing from Command Line Tools. The normal `swift test` attempt failed with `no such module 'XCTest'`; it was not reported as passing.

Covered groups:

1. Bellows min/max, normalized fraction and non-finite input.
2. Symmetric supply from opening and closing strokes.
3. Resting pressure decay and the minimum-air assist floor.
4. No further pumping when the angle remains clamped at a limit.
5. 3,600 reversal steps: bounded reserve/pressure and smooth intensity.
6. Sensitivity increases supply.
7. Invalid/zero time steps cannot corrupt state.
8. Chords, duplicate source ownership, pointer glissando and panic.
9. Settings Codable round-trip, sanitization, relative scales and drone interval.
10. Eighteen physical keyboard mappings and tonic-relative sargam.
11. DSP silence, envelope attack, polyphony, bounded output, release and mute.
12. Sample loading validation, repeated crossfade loops and fast note retrigger.

Native suites (many assertions intentionally repeat to test different deployment/error contexts):

| Suite | Assertions | Result |
|---|---:|---|
| [Primary native](artifacts/testing/native/native-results.txt) | 45 | Passed |
| [Explicit synthesized fallback](artifacts/testing/fallback/native-results.txt) | 45 | Passed |
| [Simulated audio initialization failure + Retry](artifacts/testing/audio-error/native-results.txt) | 46 | Passed |
| [Relocated standalone app](artifacts/testing/relocated/native-results.txt) | 45 | Passed |
| [Entire resource bundle removed from throwaway copy](artifacts/testing/missing-resources/native-results.txt) | 45 | Passed |
| [OS sandbox denying all network operations](artifacts/testing/network-denied/native-results.txt) | 45 | Passed |

The primary suite used a 60-second eight-note playing/bellows run: 2,978 deliberate state-update cycles, plus 600 rapid note/bellows changes. This is a responsive state/update stress check, **not a measured 60 FPS guarantee**. Other modes used five-second soaks.

### Native interaction and rendering evidence

The harness sends actual `NSEvent` instances through `NSWindow.sendEvent` to the production SceneKit view. It verifies panel/key hit-testing and first-responder behavior, not just direct model calls. It checks:

- Native Metal renderer, 37 key bodies and 24 facets forming twelve pleats.
- Folded launch; pointer-based opening and closing; fixed hinge world coordinates.
- Body transform and key positions remain stationary during pumping.
- Pointer movement replenishes the real model's reserve.
- Open and closed actual renderer snapshots differ.
- Computer C/E/G chord, auto-repeat suppression, pointer ownership, natural and black key hits, drag-glissando and all release paths.
- Octave switches, selectable tonic/fifth drones, mute, Space pumping, Escape, focus loss and app deactivation.
- Accessible children, Western/sargam labels, note press/release and bellows increment/decrement actions.
- Default and compact viewports, including projected maximum-open panel/body corners entirely inside the viewport with margins.

The first visual iteration left too much empty space. Enlarging it then exposed body cropping; both camera framing issues were corrected, and explicit geometry-projection checks were added. Final default projected instrument bounds: x 199.6–935.0, y 32.7–489.9 within a 1180 × 529 scene view. Compact bounds: x 154.2–664.4, y 22.7–339.9 within 850 × 367. Units here are UI points, not physical instrument dimensions.

Inspected final captures:

- [Folded](artifacts/testing/native/01-folded.png)
- [Opened by actual drag events](artifacts/testing/native/02-open.png)
- [Playing a chord](artifacts/testing/native/03-playing.png)
- [Compact window](artifacts/testing/native/04-compact.png)

Screenshots combine the actual SwiftUI/AppKit view bitmap with the actual SceneKit Metal snapshot in its exact viewport rectangle, because Metal-backed layers do not reliably appear in `cacheDisplay`. They are **native renderer captures, not concept art or browser mockups**. They do not capture the system title-bar traffic lights or an external screen-recording stream. Visual inspection confirmed the keyboard layout, wood body, expanded/compressed folds, pressed keys, labels, compact control area and unclipped final framing.

### Audio evidence

- All 39 bundled note recordings decoded through AVAudioFile.
- The **running app's actual AVAudioEngine main mixer** was tapped during an intentionally played chord, only under the opt-in self-test flag. [Actual engine capture](artifacts/testing/native/actual-engine-output.wav): 44,100 Hz, 35,280 frames, peak 0.1417127. This verifies the real engine graph emits nonzero unclipped audio; it is not an independent substitute synth.
- The [production DSP looping chord capture](artifacts/testing/native/surbox-audio-check.wav) runs 12.8 seconds at 48 kHz, including multiple sample loop boundaries and release.
- DSP capture: peak 0.19006; maximum adjacent-sample jump 0.04580; final tail 0.00000000. These establish bounded PCM and silence after release, not subjective proof that every loop is inaudible.
- Maximum observed 256-frame three-voice offline render time in the final primary run: 0.018 ms. This excludes OS/device buffering and is **not input-to-speaker or round-trip latency**.
- Prepared sample onset threshold (>0.03 amplitude) measured at approximately 0.79–14.17 ms into the files, median 4.51 ms. Hardware latency was not measured.
- Synthetic fallback is explicitly identified in the UI. The missing-resource test actually deletes the complete audio bundle in a relocated, re-signed throwaway copy; it does not merely set a fake error status.
- The initialization error is deliberately injected; Retry successfully initializes the real AVAudioEngine afterward. This is not a real hardware-disconnect test.

### Offline and privacy

A full native suite passed with the application launched using macOS `sandbox-exec` and `(deny network*)`, including sample loading and actual output-engine capture. The app also passed from a freshly copied path outside the workspace. Samples are resolved inside the app bundle; no absolute developer audio path is required. The application requests no account, microphone, cloud, paid API or sample download. Only explicit help attribution links may open a browser. Network denial was scoped to the test process, not a global OS/firewall change.

## Manual acceptance still required

The implementation is delivered and functional, but the user's entire acceptance list is **not** marked human-verified.

- Listen through speakers/headphones to bass, middle and high notes, fast passages and sustained chords; judge recognizability, beating, loop artifacts, clicks and natural release.
- Use a physical mouse and trackpad, especially long panel drags, overshoot/reversal at stops, drag releases outside the window, keyboard rollover and long playing sessions. Event routing is verified; subjective hardware feel is not.
- Verify real audio-device switches (wired/Bluetooth/USB), unplug/replug, sleep/wake and system audio interruptions. The recovery path exists, but those physical scenarios were not exercised.
- Measure end-to-end latency on intended audio devices. Bluetooth devices may add latency outside app control.
- Perform end-to-end VoiceOver and Full Keyboard Access navigation. Virtual AX elements and actions pass in-process tests, but a human assistive-technology audit was not performed.
- Check older macOS 14 machines, Intel builds, low-power/thermal operation, unusual window aspect ratios and additional localized keyboards.
- Verify Xcode GUI building and XCTest on a Mac with full Xcode.
- For outside distribution, sign with Developer ID, notarize and validate Gatekeeper installation. Only ad-hoc local signing was performed here.

## Reproduce

From the SurBox folder:

```sh
SOAK_SECONDS=60 bash scripts/verify.sh
```

For the separate offline restriction check:

```sh
sandbox-exec -p '(version 1) (allow default) (deny network*)' \
  artifacts/SurBox.app/Contents/MacOS/SurBox --self-test \
  --report-dir="$PWD/artifacts/testing/network-denied"
```

This uses a logged-in graphical/audio session. The self-test process deliberately plays short, conservatively leveled chords and exits after writing results. It uses an isolated settings suite and does not overwrite normal player preferences. Normal app launches neither run the harness nor record output.

## Scope

All application changes are isolated under SurBox, plus a root README entry. Existing application sources were not edited. No CAD model, BOM, web wrapper or deployment was substituted for the native app.
