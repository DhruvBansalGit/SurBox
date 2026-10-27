import SwiftUI
import AppKit
import SurBoxCore

@MainActor final class InstrumentModel: ObservableObject {
    @Published var settings: InstrumentSettings { didSet { settingsChanged(old: oldValue) } }
    @Published private(set) var bellows = BellowsController()
    @Published private(set) var airflow = AirflowModel()
    @Published private(set) var notes = NoteLedger()
    @Published var audioStatus = "Preparing acoustic recordings…"
    @Published var audioFailed = false
    @Published var help = false
    @Published var airControls = false
    @Published var musicControls = false
    @Published var pumping = false
    @Published var lidPanel = false
    @Published private(set) var lidAvailable = false
    @Published private(set) var lidDegrees: Double?
    @Published private(set) var lidStatus = "Checking for a continuous lid-angle sensor…"
    @Published var lidEnabled = true {
        didSet { defaults.set(lidEnabled,forKey:"SurBox.lidEnabled"); calibrateLid() }
    }
    private var lidMotion = LidMotion()
    private var lidReadTime = -Double.infinity
    private var lidMoveTime = -Double.infinity
    private var manualBellowsTime = -Double.infinity
    private var lidSensor: LidAngleSensor?
    let audio = HarmoniumAudioEngine()
    private var timer: Timer?
    private var saveWork: DispatchWorkItem?
    private let defaults: UserDefaults
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var observers: [NSObjectProtocol] = []
    private var heldPump = false
    private var pumpDirection = 1.0
    var scene: HarmoniumScene?
    var suspended = false
    init(testing: Bool = false) {
        defaults = testing ? UserDefaults(suiteName: "SurBox.EphemeralTesting")! : .standard
        if !testing, let d = defaults.data(forKey: "SurBox.settings"), let saved = try? JSONDecoder().decode(InstrumentSettings.self, from: d) { settings = saved } else { settings = InstrumentSettings() }
        settings.sanitize()
        // Never restore active drones or mute unexpectedly across launches.
        settings.droneTonic = false; settings.droneFifth = false; settings.muted = false
        lidEnabled = defaults.object(forKey:"SurBox.lidEnabled") as? Bool ?? true
        lidSensor = LidAngleSensor { [weak self] reading in
            MainActor.assumeIsolated { self?.receiveLid(reading) }
        }
        lidSensor?.start()
        audio.statusChanged = { [weak self] status, failed in
            self?.audioStatus = status; self?.audioFailed = failed
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.deactivate() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspended = false }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.deactivate() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didMiniaturizeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.deactivate() }
        })
        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        audio.start(forceFallback: CommandLine.arguments.contains("--fallback"), simulateFailure: CommandLine.arguments.contains("--audio-failure"))
    }
    private func settingsChanged(old: InstrumentSettings) {
        if old.octave != settings.octave || old.tonic != settings.tonic {
            releaseAll(); syncDrones()
        } else if old.droneTonic != settings.droneTonic || old.droneFifth != settings.droneFifth { syncDrones() }
        if old.muted != settings.muted {
            if settings.muted { releaseAll() } else { syncDrones() }
        }
        saveWork?.cancel()
        let data = try? JSONEncoder().encode(settings)
        let defaults = defaults
        let work = DispatchWorkItem { defaults.set(data, forKey: "SurBox.settings") }
        saveWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        scene?.updateNotes(); updateAudio()
    }
    var lidTrackingActive: Bool {
        let now=ProcessInfo.processInfo.systemUptime
        return lidEnabled && lidAvailable && !suspended && lidMotion.baseline != nil && now-lidReadTime<0.6 && now-manualBellowsTime>0.35
    }
    func receiveLid(_ reading:LidAngleSensor.Reading) {
        switch reading {
        case .unavailable(let message):
            if lidMotion.baseline != nil { pumping=false }
            lidAvailable=false; lidDegrees=nil; lidStatus=message; lidMotion.reset(); lidMoveTime = -.infinity
        case .angle(let degrees):
            let now=ProcessInfo.processInfo.systemUptime
            lidAvailable=true; lidDegrees=degrees; lidReadTime=now
            guard (30...160).contains(degrees) else {
                lidStatus="Tracking paused near the lid limit. Keep the screen comfortably open; normal lid-close sleep is unchanged."
                if lidMotion.baseline != nil { deactivate() }; lidMotion.reset(); return
            }
            lidStatus="Live sensor: \(Int(degrees))°. Gently open and close the screen while holding notes."
            guard lidEnabled,!suspended,now-manualBellowsTime>0.35 else { lidMotion.reset(); return }
            if lidMotion.baseline==nil { lidMotion.calibrate(degrees:degrees,angle:bellows.angle,time:now); return }
            if let angle=lidMotion.ingest(degrees:degrees,time:now) {
                if abs(angle-bellows.angle)>0.001 { lidMoveTime=now }
                setBellows(angle,fromLid:true)
            }
        }
    }
    func calibrateLid() {
        if lidMotion.baseline != nil { pumping=false }
        lidMotion.reset(); lidMoveTime = -.infinity
        if let degrees=lidDegrees,ProcessInfo.processInfo.systemUptime-lidReadTime<0.6 {
            lidMotion.calibrate(degrees:degrees,angle:bellows.angle,time:ProcessInfo.processInfo.systemUptime)
        }
    }
    func retryLid() { lidStatus="Checking for a continuous lid-angle sensor…"; lidSensor?.retry() }
    func stopLid() { lidSensor?.stop() }
    func setBellows(_ angle: Double, fromLid:Bool = false) {
        if !fromLid { manualBellowsTime=ProcessInfo.processInfo.systemUptime; lidMotion.reset() }
        let old=bellows.angle
        bellows.setAngle(angle)
        if abs(old-bellows.angle)>0.000001 { scene?.updateBellows() }
    }
    func beginPump() { suspended = false; heldPump = true; pumping = true }
    func endPump() { heldPump = false; pumping = false }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, max(0.0001, now - lastTime)); lastTime = now
        if lidTrackingActive { pumping=now-lidMoveTime<0.16 }
        else if lidMotion.baseline != nil && now-lidReadTime>=0.6 { lidMotion.reset(); pumping=false; lidStatus="Lid readings paused. Mouse and Space remain available." }
        if heldPump && !suspended {
            if bellows.angle >= BellowsController.open { pumpDirection = -1 }
            if bellows.angle <= BellowsController.closed { pumpDirection = 1 }
            setBellows(bellows.angle + dt * 0.65 * pumpDirection)
        }
        airflow.step(angle: bellows.angle, dt: dt, notes: notes.active.count, sensitivity: settings.sensitivity, minimum: settings.minimumAir)
        updateAudio()
    }
    func press(_ note: Int, source: String) {
        suspended = false
        let before = notes.active
        notes.press(source: source, note: note)
        applyDiff(before)
    }
    func release(_ source: String) { let before = notes.active; notes.release(source: source); applyDiff(before) }
    private func applyDiff(_ before: Set<Int>) {
        for n in before.subtracting(notes.active) { audio.note(n, velocity: 0) }
        for n in notes.active.subtracting(before) { audio.note(n, velocity: settings.keyVelocity) }
        scene?.updateNotes()
    }
    func releaseAll() { notes.releaseAll(); audio.panic(); endPump(); scene?.cancelPointer(); scene?.updateNotes() }
    func deactivate() {
        suspended = true; releaseAll(); lidMotion.reset(); lidMoveTime = -.infinity
        var inactive=settings; inactive.droneTonic=false; inactive.droneFifth=false
        settings=inactive
    }
    private func syncDrones() {
        release("drone-tonic"); release("drone-fifth")
        if settings.droneTonic { press(settings.droneNote(fifth: false), source: "drone-tonic") }
        if settings.droneFifth { press(settings.droneNote(fifth: true), source: "drone-fifth") }
    }
    func updateAudio() { audio.update(pressure: airflow.pressure, volume: settings.volume, muted: settings.muted || suspended) }
    func reset() { releaseAll(); settings = InstrumentSettings(); bellows = BellowsController(); airflow.reset(); scene?.updateBellows() }
    func shiftOctave(_ delta: Int) { settings.octave = min(5, max(2, settings.octave + delta)) }
}
