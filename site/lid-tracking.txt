# Physical MacBook screen -> harmonium bellows

## Important hardware finding

The development machine is **MacBookAir10,1 (2020 M1 MacBook Air)**. A direct IOKit HID probe returned **no compatible continuous lid-angle sensor**, and IORegistry exposed only binary `AppleClamshellState` for the lid. Binary open/closed state cannot measure the opening angle or the speed of a stroke.

**Moving this machine's physical screen therefore cannot drive SurBox through the built-in sensor.** Software cannot manufacture the missing measurement. This update adds a real sensor path for compatible MacBooks, not a fake flapping animation, and it does not claim that physical tracking was tested successfully on this hardware.

- [Actual sensor result and integration tests](artifacts/testing/native/native-results.txt)
- [Actual unavailable-state UI](artifacts/testing/native/06-physical-lid-status.png)
- [Updated app](artifacts/SurBox.app)

## What changed

The top bar now has a **MacBook lid / Lid tracking / Lid unavailable** control. It shows the actual detected angle when available, a tracking toggle, calibration, and sensor retry. With a valid compatible sensor, tracking is enabled by default unless previously disabled.

The native IOKit reader searches only for Apple's continuous lid-angle HID device:

- Vendor: `0x05AC`
- Product: `0x8104`
- Usage page: `0x0020`
- Usage: `0x008A`
- Feature report ID: `1`, angle as a little-endian 16-bit degree value

The public IOKit APIs access an **undocumented, hardware-dependent Apple report contract**. There is no universal supported macOS lid-angle API. Hardware exposure and OS behavior can vary; the app probes capability rather than assuming all Apple Silicon models work. It does not request root privileges, change security settings, capture keyboard HID input, or use a webcam.

Sensor reads run on a dedicated queue at up to 50 Hz, not on the UI/audio callback. Initial readings calibrate to the current virtual panel position without creating a stroke. Approximately 40 degrees of gentle physical screen travel spans the virtual bellows range; this is a relative musical control, not a one-to-one angle display.

Valid opening/closing changes drive the existing real virtual-panel rotation and stateful airflow model. There is no independent decorative animation. Noise and implausible reports are filtered; stale/disconnected readings pause tracking rather than making up data. Endpoint overshoot is discarded so a reversal responds immediately. Manual mouse/Space pumping takes priority and re-anchors the sensor afterward.

Normal lid-close sleep remains intact. Tracking pauses below 30 degrees or above 160 degrees; near-close movement releases notes. The app does not keep a closed laptop awake or encourage forcing a hinge.

## Use on a compatible MacBook

1. Place the laptop on a stable surface and keep the screen comfortably open.
2. Open the laptop control in SurBox and confirm a **live physical angle** is shown.
3. Enable tracking, and use **Calibrate here** at a comfortable viewing position.
4. Hold musical keys or enable a Sa/Pa drone, then gently move the actual screen up and down. The virtual bellows and air reserve follow the measured motion.
5. Do not slam the screen or push it against its stops. Full closure can sleep the Mac.

On an unsupported machine, the toggle and calibration are disabled, and an explicit message explains why. Mouse/Space playback remains supported, but is not represented as physical screen tracking. A compatible Mac or an additional external angle-sensing approach would be required for this M1 Air; external hardware is not included in this update.

## Verification

- Release build and strict local codesign verification pass.
- **16 deterministic test groups** pass: the original 12 plus report decoding/calibration, both-direction air supply, limits/noise/reversal and invalid/stale readings.
- Updated primary native suite: **53 checks passed** on this host. Audio-error suite has one additional check.
- Actual device discovery and unavailable-state UI were exercised on the physical M1 Air.
- Six native integration checks use **explicitly injected angle values** to verify initial alignment, opening and pumping, closing while a note remains held, sensor failure, disabled mode and near-close note release. These use the production model and renderer but are **not physical sensor acceptance**.
- Existing keyboard, mouse, audio, resource-failure and relocation tests were rerun.
- **Unverified:** an actual hand-moved lid on a compatible MacBook, real sensor latency/jitter/hot-plug/wake behavior, and cross-model report compatibility. The requested physical interaction cannot be signed off on this host.

## References

- [Lid Angle: HID identifiers, report method and compatibility caveat](https://github.com/andrewcharlesmoss/lid-angle)
- [Sensor reader implementation reference](https://github.com/andrewcharlesmoss/lid-angle/blob/main/Sources/LidAngleApp/main.swift)
- [M1 compatibility report](https://github.com/samhenrigold/LidAngleSensor/issues/13)
- [Model compatibility discussion](https://github.com/samhenrigold/LidAngleSensor/issues/36)
- [M1 Air lid-switch hardware discussion](https://www.ifixit.com/Answers/View/940917/MacBook+doesn't+sleep+when+lid+closed+after+screen+replaced)

The local direct probe, not the web model list alone, determines the UI's capability state.
