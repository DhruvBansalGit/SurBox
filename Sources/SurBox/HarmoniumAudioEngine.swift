import AVFoundation
import SurBoxDSP
import Foundation

struct SampleRecord: Codable {
    let midi: Int
    let file: String
    let loopStart: Int
    let loopEnd: Int
}

// Native callback performs only preallocated C++ mixing and atomic reads.
// Samples are decoded once, off the UI thread, before starting the engine.
final class HarmoniumAudioEngine {
    private let queue = DispatchQueue(label: "SurBox.audio-control", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var observer: NSObjectProtocol?
    let dsp: OpaquePointer
    private(set) var sampleCount = 0
    var statusChanged: ((String, Bool) -> Void)?
    private var started = false
    init() { dsp = sb_create(48000)! }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) }; engine?.stop(); sb_destroy(dsp) }

    static var resourceRoot: URL {
        // Do not call Bundle.module's fatal accessor when the bundle is absent.
        // App distribution, relocated app and SwiftPM CLI are all supported.
        let roots=[Bundle.main.resourceURL, Bundle.main.bundleURL, Bundle.main.executableURL?.deletingLastPathComponent()].compactMap{$0}
        for root in roots {
            if let b=Bundle(url:root.appendingPathComponent("SurBox_SurBox.bundle")),let resources=b.resourceURL { return resources }
        }
        return Bundle.main.resourceURL ?? Bundle.main.bundleURL
    }
    func start(forceFallback: Bool = false, simulateFailure: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            self.engine?.stop()
            if let observer = self.observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
            if !self.started {
                self.loadSamples(forceFallback: forceFallback)
                self.started = true
            }
            do {
                if simulateFailure { throw NSError(domain: "SurBox", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated audio-start failure"]) }
                let engine = AVAudioEngine()
                let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
                let dsp = self.dsp
                let node = AVAudioSourceNode(format: format) { _, _, frames, list -> OSStatus in
                    let buffers = UnsafeMutableAudioBufferListPointer(list)
                    if let data = buffers[0].mData { sb_render(dsp, data.assumingMemoryBound(to: Float.self), Int32(frames)) }
                    return noErr
                }
                engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
                engine.prepare(); try engine.start()
                self.engine = engine; self.source = node
                self.observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
                    self?.panic(); self?.start()
                }
                let count = self.sampleCount
                self.report(count > 0 ? "Acoustic harmonium · \(count) sampled notes" : "Synthesized reed fallback · recordings unavailable", failed: false)
            } catch {
                self.engine = nil; self.source = nil
                self.report("Audio unavailable: \(error.localizedDescription). Choose Retry Audio.", failed: true)
            }
        }
    }
    private func report(_ text: String, failed: Bool) {
        DispatchQueue.main.async { [weak self] in self?.statusChanged?(text, failed) }
    }
    private func loadSamples(forceFallback: Bool) {
        guard !forceFallback else { return }
        let root = Self.resourceRoot
        guard let data = try? Data(contentsOf: root.appendingPathComponent("samples.json")),
              let records = try? JSONDecoder().decode([SampleRecord].self, from: data) else { return }
        for record in records {
            let url = root.appendingPathComponent(record.file)
            guard let file = try? AVAudioFile(forReading: url), file.length < 1_000_000,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil, let channel = buffer.floatChannelData?[0] else { continue }
            _ = sb_load_sample(dsp, Int32(record.midi), channel, Int32(buffer.frameLength), file.processingFormat.sampleRate, Int32(record.loopStart), Int32(record.loopEnd))
        }
        sampleCount = Int(sb_sample_count(dsp))
    }
    func note(_ midi: Int, velocity: Double) { sb_note(dsp, Int32(midi), Float(velocity)) }
    func update(pressure: Double, volume: Double, muted: Bool) { sb_controls(dsp, Float(pressure), Float(volume), muted ? 1 : 0) }
    func panic() { sb_panic(dsp) }
    // Opt-in test instrumentation only: observe the actual AVAudioEngine mixer,
    // not another DSP instance. No tap or file I/O exists in normal playback.
    func diagnosticCapture(to url:URL, seconds:Double, completion:@escaping (Bool)->Void) {
        guard CommandLine.arguments.contains("--self-test") else { completion(false); return }
        queue.async { [weak self] in
            guard let engine=self?.engine,engine.isRunning else { DispatchQueue.main.async { completion(false) }; return }
            let mixer=engine.mainMixerNode
            let format=mixer.outputFormat(forBus:0)
            guard let file=try? AVAudioFile(forWriting:url,settings:format.settings) else { DispatchQueue.main.async { completion(false) }; return }
            mixer.installTap(onBus:0,bufferSize:512,format:format) { buffer,_ in try? file.write(from:buffer) }
            self?.queue.asyncAfter(deadline:.now()+seconds) {
                mixer.removeTap(onBus:0)
                DispatchQueue.main.async { completion(true) }
            }
        }
    }
    func stop() { panic(); queue.async { [weak self] in self?.engine?.stop() } }
}
