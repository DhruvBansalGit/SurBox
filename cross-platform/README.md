# SurBox for Android and Windows

These are **native platform implementations**, not Electron/WebView wrappers or a website repackaged as an app. They reuse the 39 licensed acoustic recordings and the same instrument-state rules as the original macOS edition. The original macOS source/app remains available.

- Android: Java, native Canvas perspective bellows, multitouch and `AudioTrack` streaming.
- Windows: C++17, Win32/GDI perspective bellows, mouse/keyboard and `waveOut` native PCM output. The same preallocated C++ DSP used by macOS is compiled into Windows.
- All editions: independent note-source ownership, 12 pleats, constrained hinge, both-direction pumping, air reserve/assist, polyphony, 60 ms loop overlap, envelopes, volume, tonic, scales, drones and release on focus loss.
- **Physical screen/lid motion is NOT implemented on Android or Windows.** Use touch/mouse or Space. macOS's hardware-dependent lid feature remains separate.

## Public downloads

Choose a system at https://surbox.vercel.app/#downloads

- [Android 8+ universal APK](https://surbox.vercel.app/downloads/SurBox-Android.apk)
- [Windows 10/11 x64 portable ZIP](https://surbox.vercel.app/downloads/SurBox-Windows-x64.zip)
- [Apple Silicon macOS ZIP](https://surbox.vercel.app/downloads/SurBox-macOS-arm64.zip)
- [Source archive](https://surbox.vercel.app/downloads/SurBox-source.zip)

These remain engineering previews. Android is not a Play Store listing; Windows is not Authenticode-signed; macOS is not notarized. Use the normal installation controls only if you trust the source. Never disable OS security globally.

### Android

Download the APK, open it with the Android package installer, and allow that browser/file manager to install from this source only if you trust it. Revoke that permission afterward. Rotate to landscape. **Android 1.0.1 replaces the thin perspective keyboard with 13 large, tall keys.** Use the minus/plus octave controls to reach C2-C8; only one octave is visible at a time. Touch the exposed lower cream faces for naturals and the dark upper faces for sharps/flats. Separate fingers can hold keys and drag the bellows above; Stop releases everything. Settings contain tonic/scale, drones, air controls, mute/reset/retry. A connected keyboard supports the desktop mapping. VersionCode 2 is signed with the original key and installs as an update over 1.0.0.

Android 8.0/API 26 or newer is declared. The APK contains Java/Dex rather than native ABI libraries, so it does not require a separate arm64/x86 APK. It was installed and tested on an Android 15/API 35 arm64 emulator in normal and compact landscape sizes, not every Android version or physical phone. Landscape-first, one-octave layout; unusual forced portrait/multiwindow modes are not covered by touch-size guarantees. The emulator is not evidence of physical-device latency, speaker quality or touch ergonomics.

The APK requests **no permissions**, including no Internet, microphone or storage access. Settings stay in app-local preferences; samples are bundled. Test instrumentation is a separate APK and is NOT publicly distributed.

Build with JDK 11+, Android SDK platform 35 and build-tools 35.0.1:

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk"
# Set SURBOX_ANDROID_KEYSTORE and SURBOX_ANDROID_STOREPASS securely for this process.
bash cross-platform/android/build.sh
bash cross-platform/android/test.sh  # requires an authorized test emulator
```

A dedicated RSA release key was created for this personal APK and kept under the operator's private `$HOME/.local/share/surbox-signing/` directory, outside Git, the source ZIP and Vercel. Back it up securely: future in-place updates must use the same signing key. Its **public certificate SHA-256** is:

`bb65366453d67d593645895f7d5c71f24a9b0b8b1633fe7dfaf09b45b78b28ab`

No signing password or private key is included in the repository. An independent source builder should supply their own key rather than trying to use the publisher's identity.

### Windows

Extract the **entire ZIP**, keep its samples folder next to SurBox.exe, then run SurBox.exe. No .NET/Java/Electron installation is required; the published runner build statically links the MSVC runtime. Settings are stored under the current user's LocalAppData/SurBox directory. It is an x64 build for Windows 10/11, not a native Windows ARM or 32-bit build.

Click the instrument to focus it. Play `A W S E D F T G Y H U J K O L P ; '`; hold Space to pump; Escape stops notes; Left/Right shift octaves. Mouse click/drag glissando and keyboard chords coexist. Use the compact toolbar for volume, air, tonic, scale and drones.

The downloadable Windows binary is the **MSVC build produced and tested on the actual Windows GitHub Actions runner**, not the initial macOS cross-compiled binary. The isolated workflow is [windows-native.yml](../.github/workflows/windows-native.yml); it has read-only repository permissions, no deployment/signing secrets and a 15-minute job timeout. The public repository's standard runner was used without billing changes.

A local cross-build is also supported with Zig 0.14.1:

```sh
ZIG=/path/to/zig bash cross-platform/windows/build.sh
```

`SurBox.exe --self-test` runs sample loading and DSP checks in a real Windows process; `--ui-test` exercises Win32 messages/rendering and writes a native screenshot. Neither is a physical speaker listening test.

## Verification and differences

See [PLATFORM_TESTING.md](../PLATFORM_TESTING.md) for exact test counts, screenshots, runner URL and remaining gates. The Windows/Android visuals are perspective 2.5D native polygons with individually animated folds, not the macOS SceneKit renderer. Physical sensors, rich key-level assistive-technology parity and OS-specific device interruption paths differ. Human listening, real hardware input/audio, accessibility and long-run thermal/battery acceptance remain outstanding.
