# Android and Windows verification

2026-10-27. This report is separate from the original [macOS verification](TESTING.md). The new ports are downloadable **engineering previews**, not a claim of identical polish, accessibility or hardware coverage on every system.

## Android native app

- Java + Canvas + AudioTrack; no browser wrapper, cloud audio, account or runtime download.
- Built using the installed Android 35 SDK, build-tools 35.0.1 and JDK 11. Release APK verified with APK Signature Schemes v2/v3, RSA 3072. Declared minimum Android 8.0/API 26, target API 35. No native-ABI library dependency.
- Dedicated private release signing material is kept outside the workspace/repository/archives. Public signing fingerprint and update-key guidance are in [cross-platform setup](cross-platform/README.md).
- Installed on an isolated **read-only Android 15/API 35 arm64 emulator**. Existing virtual-device data was not rewritten. The emulator's debugging prompt was accepted only for this test instance. No physical phone was connected.
- **16 host-side deterministic Java checks passed**: bellows bounds, invalid input, source-owned notes, chord/panic, pumping in both directions, reserve decay/assist, tonic/fifth drones, octave release, fallback synthesis, sample loops and release.
- **19 actual Android instrumentation checks passed**, including:
  - All 39 APK-bundled recordings decoded.
  - Real AudioTrack output started and continued accepting rendered PCM frames.
  - Foreground activity and Android audio focus.
  - Actual Activity keyboard events for a chord and releases.
  - Actual View touch events for opening/closing the hinged bellows and air reserve.
  - Key touch/cancel and two-pointer chord ownership.
  - Space pumping, focus-loss release, relative drones.
  - Native Android screenshot.
  - Production Java mixer generates bounded nonzero PCM and decays to silence.
  - Package manager confirms no Internet permission.

[Android results](artifacts/testing/android/android-results.txt), [Java core results](artifacts/testing/portable/java-results.txt), [actual Android screenshot](artifacts/testing/android/android-playing.png).

A rerun initially checked AudioTrack too soon: the last sample finished loading before output initialization. That test failed honestly; it was corrected to wait for the actual output-started state, and the complete final suite passed. No exception was hidden or accepted as success. Emulator ADB authorization initially blocked automated installation; the test instance's displayed authorization prompt was accepted, then installation and instrumentation succeeded.

The landscape UI was visually inspected and widened for usable touch-key spacing; an overlapping instruction line was removed. Source supports reduced visible range in forced portrait/multiwindow, but the normal phone activity requests sensor-landscape. Physical-device touch ergonomics remain unverified.

**Limitations:** The emulator was run without host speaker playback, so AudioTrack progress is not human listening evidence. No physical Android phone/tablet, Bluetooth/wired route switching, Android 8-14 runtime, foldable hinge, thermal/battery endurance or full TalkBack audit was verified. Standard controls are labeled, but individually navigable virtual-key accessibility is not at macOS parity. Physical screen-angle control is not implemented.

## Windows native app

- Win32/GDI + native waveOut PCM + the original C++ sample DSP; no Electron, .NET runtime or remote sound dependency.
- A preliminary PE x64 binary was cross-compiled with Zig on macOS. Its initial missing nonstandard M_PI macro was replaced by the equivalent explicit pi constant in the shared DSP; host C++ tests passed.
- **The published ZIP uses the later MSVC /MT build from a real Windows runner.** It is not the preliminary cross-build.
- [Successful Windows runner](https://github.com/DhruvBansalGit/SurBox/actions/runs/40484162528), source revision `b3ba72a` for the Windows implementation. Subsequent changes in this update do not modify that Windows implementation.
- **13 C++ core/DSP assertions passed on the macOS host and again as an actual Windows process**: constrained angles, note ownership/chords, panic, bidirectional air, decay/assist, relative drones, octave clearing, polyphonic DSP output and release.
- **A real Windows sample/DSP process check passed** with all 39 recordings, a three-note chord, bounded peak 0.2068 and released silence.
- **13 native Windows UI checks passed** on the runner: rendering 37 key polygons, native keyboard chords/repeat/release, panel hit-testing and drag rotation, reserve supply, volume slider, tonic and drone controls, Escape, deactivation release and actual Windows screenshot capture.
- Workflow uses pinned checkout/upload actions, read-only contents permission, no application secrets and a 15-minute timeout. No service plan/billing changes were made.
- Downloaded the runner-produced artifact, checked ZIP integrity, and used that exact Windows ZIP for public distribution.

[Windows UI results](artifacts/testing/windows/windows-ui-test.txt), [Windows sample/DSP results](artifacts/testing/windows/windows-self-test.txt), [Windows core results](artifacts/testing/windows/logic-results.txt), [actual Windows screenshot](artifacts/testing/windows/windows-ui.png), [workflow](.github/workflows/windows-native.yml).

The native screenshot was inspected: bellows/keys/held notes and all controls are present. Windows uses standard system controls, not the exact macOS dark toolbar styling. The viewport is drawn in native GDI perspective; the bellows pivot is fixed and facets follow the angle.

**Limitations:** The runner does not verify a person's physical mouse/keyboard feel, real speaker/audio-device behavior, Bluetooth latency, Windows 10 hardware, screen-reader completeness or laptop lid sensors. No Authenticode certificate was available; the app is unsigned and SmartScreen may warn. Windows ARM-native and 32-bit builds are not supplied. Physical screen-angle control is not implemented. Audio buffer sizing targets responsive playback but end-to-end hardware latency is not measured.

## macOS preserved

The existing native macOS app/download is retained, including its explicit M1 Air lid-sensor limitation. Its delivered executable was not replaced by either port. The shared DSP source changed only from the nonportable M_PI macro to the numerically equivalent pi literal for Windows compatibility. The existing macOS test milestone remains in [TESTING.md](TESTING.md); this update's testing must not be read as fresh physical-lid verification.

## Website and distribution

The public page presents separate **macOS Apple Silicon**, **Windows x64 ZIP** and **Android universal APK** choices. A small local-only browser-platform hint highlights a likely choice but does not auto-download, hide other platforms or claim exact processor detection. It detects iPad/iPhone separately and explicitly states that APKs do not work on iOS.

The site remains a download page, not a browser instrument. Installation cautions, signing status, supported versions, checksums and incomplete hardware gates are visible. The source archive includes all platform source/build/test scripts and excludes credentials, signing keys, toolchains and generated build caches.

No Play Store, Microsoft Store or Apple App Store listing was created. No paid signing service, account or billing change was made. Direct installation is the distribution path.
