# SurBox

## Now available for macOS, Windows and Android

Choose your platform at **[surbox.vercel.app/#downloads](https://surbox.vercel.app/#downloads)**. Native Android (Java/Canvas/AudioTrack) and Windows (Win32/C++/native PCM) previews now accompany the original macOS app; these are not web wrappers. All include the acoustic recordings and offline bellows/key playback.

- [Android 8+ universal APK](https://surbox.vercel.app/downloads/SurBox-Android.apk) — signed direct-install package, landscape multitouch; Android 15 emulator tested, not Play Store distributed.
- [Windows 10/11 x64 ZIP](https://surbox.vercel.app/downloads/SurBox-Windows-x64.zip) — extract all files and run SurBox.exe; built and tested on a Windows runner, unsigned and still a hardware-validation preview.
- [Apple Silicon macOS ZIP](https://surbox.vercel.app/downloads/SurBox-macOS-arm64.zip) — original app retained.
- [Platform build/setup](cross-platform/README.md) and [platform test report](PLATFORM_TESTING.md).

Windows and Android use mouse/touch or Space pumping, **not physical screen-flapping input**. Physical listening, input/audio latency, device switching and full accessibility acceptance remain unverified. The platform hint on the website is advisory; every download stays visible. iOS, Linux, Windows ARM-native and macOS Intel binaries are not supplied.

## Original macOS edition

A native, offline macOS harmonium with a genuinely hinged 3D bellows, a responsive 37-key keyboard, stateful airflow and bundled acoustic reed recordings. SwiftUI / AppKit, SceneKit / Metal, AVAudioEngine, and a small allocation-free C++ DSP mixer. macOS 14 or later. No third-party runtime packages, account, API key, microphone permission or network service.

## Physical screen control — hardware-dependent

SurBox now includes a real MacBook lid-angle input: on compatible hardware, gently moving the physical screen drives the bellows and airflow while you hold notes. The laptop button shows sensor status, calibration and enable/disable controls.

**The development Mac is a 2020 M1 MacBook Air and exposes no compatible continuous lid-angle sensor. Physical-screen flapping cannot work through its built-in lid switch.** The app displays `Lid unavailable` instead of inventing motion. Sensor-driven integration is tested with labeled injected readings; actual hand-moved screen tracking on a supported Mac remains unverified. [Hardware findings, usage and test details](LID_TRACKING.md).

## Run

- **Website:** [surbox.vercel.app](https://surbox.vercel.app) — a download/information page, not a browser instrument.
- **Ready-to-run Apple Silicon app:** [Download ZIP](https://surbox.vercel.app/downloads/SurBox-macOS-arm64.zip)
- **Portable source archive:** [Download source](https://surbox.vercel.app/downloads/SurBox-source.zip)
- **GitHub:** [DhruvBansalGit/SurBox](https://github.com/DhruvBansalGit/SurBox) — source published on `main`.
- **Publishing status:** [PUBLISHING.md](PUBLISHING.md) — GitHub and Vercel are live; Vercel deployments currently use the CLI, not automatic Git pushes.
- **Source:** [Swift package](Package.swift) or [Xcode project](SurBox.xcodeproj)
- **Finished interface:** [Playing](artifacts/testing/native/03-playing.png), [Folded](artifacts/testing/native/01-folded.png), [Compact window](artifacts/testing/native/04-compact.png)
- **Evidence and remaining acceptance gates:** [TESTING.md](TESTING.md)

Double-click the app or copy it to Applications. The supplied executable is arm64 and ad-hoc signed for local use, **not notarized or Developer ID signed**. A copy downloaded from another machine may be blocked by Gatekeeper; use the normal macOS approval flow only if you trust its source. Do not disable Gatekeeper globally. No installer or additional download is required. Intel users must build from source; an Intel runtime was not tested here.

## Build from source

With Apple Swift 5.9+ and the macOS SDK (Xcode or Command Line Tools):

```sh
cd surbox
sh scripts/build-app.sh
```

The script creates the app bundle, copies all audio and licensing resources, and applies local ad-hoc signing. `SIGN_IDENTITY` can name a valid signing identity for a distribution build; notarization is a separate operator step. `swift run SurBox` also works during development. Dependencies are Apple frameworks and the C++ standard library only; samples are already in the project.

The included Xcode project has an app, static Swift core, static C++ DSP, unit tests and shared scheme. Its plist, scheme XML and all source/resource references were checked. **Full Xcode is not installed on the build host, so the Xcode GUI build and XCTest execution are not claimed.** The delivered app was built and launched with SwiftPM / Command Line Tools on macOS 15.5.

## Play

1. Click the instrument. It becomes the computer-keyboard input surface.
2. Grab the rear wood panel or its folds. Drag up to open and down to close. The panel rotates about a fixed rear horizontal pivot; the body and keyboard do not move.
3. Reverse at either limit. Both strokes charge an internal reserve; resting slowly drains it. Minimum air is 20% by default, so you can play immediately without pumping. Set **Air → Minimum airflow** to zero for manual air.
4. Click/hold keys and drag across them for glissando. Use the computer keyboard for chords while the pointer pumps the bellows. A single pointer itself supplies only one key at a time.

Computer mapping, chromatically from the first displayed C:

`A W S E D F T G Y H U J K O L P ; '`

- **Space held:** accessible repeating pump. Releasing Space stops it. This is explicitly assisted input; ordinary pointer dragging never runs an unrelated animation.
- **Left / Right arrows** or toolbar minus/plus: shift the three-octave range. Default C3–C6; range starts can be C2–C5.
- **Escape** or **Command-period:** release all notes and drones.
- **Sa:** tonic, free/Bilawal/Kafi/Bhairav scale guides, Sa and Pa drones. Guides dim out-of-scale labels but never block playing.
- **Air:** pumping sensitivity, minimum airflow, key strength, and accessible open/close steps.
- **Mute / volume / reset:** compact toolbar controls.
- **Help:** controls and recording credit. After interacting with a control, click the instrument to return computer-key input there.

Natural keys show relative sargam and Western pitch class. The held-note readout and accessible key labels include the octave. Lowercase re/ga/dha/ni are komal; Ma-sharp is tivra. Tonic is not fixed to C. Drones use the same recording bank, not special reed-stop recordings.

App deactivation, focus loss, minimization, sleep, octave changes, reset and panic release notes safely. Note ownership is per input source: releasing a mouse note does not release a matching computer-held pitch. Computer key positions use ANSI physical key codes. Localized hardware layouts may have different printed letters.

## Audio: recordings, not a disguised synth

39 acoustic note recordings (MIDI 36–74, C2–D5 using the lower reed as pitch reference) are derived from Donya Quick's **Harmonium Samples – All Keys and Drones**, recorded at Yale University's Euterpea Studio and released under **CC0 1.0**:

- [Original recording and license](https://freesound.org/people/donyaquick/sounds/330410/)
- [Bundled attribution/license](Sources/SurBox/Resources/Audio-LICENSE.txt)
- [Extraction provenance](AudioSource/extraction.json)
- [Reproducible preparation script](scripts/prepare-samples.py)

The input is the publicly available **HQ MP3 preview, not the original lossless WAV**. The notes were converted to mono PCM, trimmed, high-pass filtered at 35 Hz, gain-normalized, slightly pitch-corrected, and provided with looping metadata. Original paired/octave reed beating remains; this is not a sterile single-sine instrument. Frequencies outside the sampled range use nearest-sample transposition; extreme upper ranges will sound thinner. There are no separate velocity layers or independently recorded stops. Rendered stop knobs are decorative and are not presented as functioning audio controls.

Playback uses 60 ms loop crossfades, 10 ms attack and 55 ms release smoothing, a 22 ms output-control slew, polyphonic normalization, and bounded soft saturation. 48 kHz internal mono DSP is converted to the actual device format by AVAudioEngine. The current device was 44.1 kHz. Up to 128 MIDI pitch slots are preallocated; eight-voice real-time and three-voice looping checks were run. The audio callback does not decode files, allocate voice storage, lock a mutex or touch SwiftUI. Samples are decoded on a serial audio-control queue before starting.

If some notes are missing, remaining recordings supply nearest-note playback. If the manifest, every sample, or the whole resource bundle is missing, the app runs an explicitly labeled **Synthesized reed fallback**. It never calls that a real recording. Audio initialization failures show a Retry Audio action. Configuration-change notifications schedule an engine rebuild and release audio gates; real device hot-plug remains a manual acceptance check.

## Bellows construction and modeling choices

Research references:

- [Bina instrument instructions](https://www.binaswar.com/manual-instruction/)
- [Design and Development of an Indian Harmonium with Automatic Bellow Mechanism](https://iopscience.iop.org/article/10.1088/1742-6596/1950/1/012021/pdf)
- [Structural Development of Harmonium in India](https://swarsindhu.pratibha-spandan.org/wp-content/uploads/v12i03a61.pdf)

The rear wood leaf, accordion gussets and internal reserve follow recognizable harmonium construction. The requested laptop-like **horizontal** hinge and double-direction supply are deliberate player-friendly choices, not a claim that all real harmoniums have this orientation or double-acting valves. The app is a musical visualization, not fabrication CAD.

The angle is clamped to 0.07–0.92 radians (about 4–53 degrees). Twenty-four cloth facets form twelve pleats around the fixed hinge; side gussets form the wedge and the front gusset spans the instrument. Pointer displacement drives angle continuously. At hard stops, overshoot is discarded so reversing starts moving immediately. A physically based material/light setup and shadowed stationary body supply depth. Geometry proportions use a roughly 610 mm-wide visual model; they are design choices, not dimensions copied from a particular product.

Airflow integrates actual bounded angle changes, speed, signed direction, configurable sensitivity, note-dependent consumption and stored reserve. Pressure is independently smoothed, not directly mapped to panel angle. At rest the reserve drains. A stationary panel cannot keep supplying air at an end stop.

## Architecture

- [InstrumentCore.swift](Sources/SurBoxCore/InstrumentCore.swift): deterministic bellows constraints, airflow, source-owned notes, settings, sargam and scale logic.
- [InstrumentModel.swift](Sources/SurBox/InstrumentModel.swift): main-actor state, frame ticks, input arbitration, defaults and lifecycle safety.
- [HarmoniumScene.swift](Sources/SurBox/HarmoniumScene.swift): SceneKit body/keys/pleats, fixed-pivot drag and actual NSWindow input.
- [HarmoniumAudioEngine.swift](Sources/SurBox/HarmoniumAudioEngine.swift): asynchronous sample loading and native engine recovery.
- [SurBoxDSP.cpp](Sources/SurBoxDSP/SurBoxDSP.cpp): preallocated atomic-gate sample mixer and separately identifiable synthesis fallback.
- [SurBoxApp.swift](Sources/SurBox/SurBoxApp.swift): compact SwiftUI interface, toolbar and help.
- [InstrumentAccessibilityElement.swift](Sources/SurBox/InstrumentAccessibilityElement.swift): accessible key children and bellows actions. Press toggles an accessible held key; second press releases it.
- [NativeChecks.swift](Sources/SurBox/NativeChecks.swift): opt-in native acceptance harness and real renderer/mixer captures; normal launches do not run tests or write audio.

Preferences are local UserDefaults under the app identifier `local.surbox.instrument`. Volume, octave, tonic, scale and air/touch settings persist. Drones and mute do not restore as active on a fresh launch. No analytics, media uploads or microphone access. Help links open the browser only when explicitly clicked.

## Tests and limitations

```sh
bash scripts/verify.sh
SOAK_SECONDS=60 bash scripts/verify.sh
```

The checks require a logged-in macOS graphical/audio session. XCTest source is included; the same 16 deterministic test bodies run using a small assertion shim on a Command-Line-Tools-only host. Native suites exercise event dispatch, Metal snapshots, AX actions, real audio output, error recovery, relocated resources and the genuinely missing-bundle case. See [the full report](TESTING.md) for exact results, metrics, offline proof and manual gates.

This is a working local instrument build, **not a claim that every human acceptance criterion has been signed off**. Human listening for musical timbre/loop quality, physical mouse/trackpad feel, VoiceOver navigation, real output-device switching/sleep recovery, hardware round-trip latency, older macOS/Intel hardware and Developer ID/notarized distribution remain unverified. MIDI controllers, microphone input, audio recording/export in the user UI and per-stop reed banks are not included.
