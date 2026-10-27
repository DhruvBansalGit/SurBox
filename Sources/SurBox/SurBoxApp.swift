import SwiftUI
import AppKit
import SurBoxCore

@main struct SurBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("SurBox", id: "instrument") {
            ContentView(model: delegate.model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 840, minHeight: 610)
        }
        .defaultSize(width: 1180, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Instrument") {
                Button("Release All Notes") { delegate.model.deactivate(); delegate.model.suspended=false }.keyboardShortcut(".",modifiers:.command)
                Button("Reset Instrument") { delegate.model.reset() }
                Button("Retry Audio") { delegate.model.audio.start() }
                Divider()
                Button("Controls & Credits") { delegate.model.help=true }.keyboardShortcut("?",modifiers:.command)
            }
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = InstrumentModel(testing: CommandLine.arguments.contains("--self-test"))
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps:true)
        if CommandLine.arguments.contains("--self-test") {
            DispatchQueue.main.asyncAfter(deadline:.now()+2) { NativeChecks.run(model:self.model) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationWillTerminate(_ notification:Notification) { model.audio.stop(); model.stopLid() }
}

struct ContentView: View {
    @ObservedObject var model: InstrumentModel
    private let surface=Color(red:0.072,green:0.078,blue:0.081)
    private let subtle=Color.white.opacity(0.10)
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:18) {
                Text("SURBOX").font(.system(size:13,weight:.semibold,design:.monospaced)).tracking(3)
                Rectangle().fill(subtle).frame(width:1,height:19)
                Text(model.audioStatus.contains("fallback") ? "SYNTHESIZED REED":"ACOUSTIC HARMONIUM").font(.system(size:10,weight:.medium)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Button { model.lidPanel.toggle() } label: {
                    Label(model.lidAvailable ? (model.lidTrackingActive ? "Lid tracking":"MacBook lid") : "Lid unavailable",systemImage:"laptopcomputer")
                }.font(.system(size:11)).foregroundStyle(.secondary)
                    .accessibilityLabel("Physical MacBook lid tracking")
                    .popover(isPresented:$model.lidPanel) { lidPanel.padding(24).frame(width:360) }
                Button { model.help=true } label: { Image(systemName:"questionmark.circle") }.help("Controls, sound source and credits")
            }.buttonStyle(.plain).padding(.leading,82).padding(.trailing,24).frame(height:49)
            Divider().overlay(subtle)
            HStack(spacing:15) {
                Image(systemName:model.settings.muted ? "speaker.slash":"speaker.wave.1").foregroundStyle(.secondary)
                Slider(value:$model.settings.volume,in:0...1).frame(width:94).accessibilityLabel("Master volume")
                Text("\(Int(model.settings.volume*100))").monospacedDigit().foregroundStyle(.secondary).frame(width:24)
                Button(model.settings.muted ? "Unmute":"Mute") { model.settings.muted.toggle() }.help("Mute the instrument")
                Divider().frame(height:18)
                Button { model.shiftOctave(-1) } label: { Image(systemName:"minus") }.accessibilityLabel("Lower octave")
                Text("\(NoteNames.name(model.settings.firstNote)) – \(NoteNames.name(model.settings.firstNote+36))").monospaced().frame(width:75).accessibilityLabel("Keyboard range")
                Button { model.shiftOctave(1) } label: { Image(systemName:"plus") }.accessibilityLabel("Higher octave")
                Spacer(minLength:2)
                Button { model.musicControls.toggle() } label: { Label("Sa · \(NoteNames.western[model.settings.tonic])",systemImage:"music.note") }
                    .popover(isPresented:$model.musicControls) { musicPanel.padding(24).frame(width:350) }
                Button { model.airControls.toggle() } label: { Label("Air",systemImage:"wind") }
                    .popover(isPresented:$model.airControls) { airPanel.padding(24).frame(width:340) }
                Button { model.reset() } label: { Image(systemName:"arrow.counterclockwise") }.help("Reset to defaults").accessibilityLabel("Reset instrument")
            }.font(.system(size:12)).buttonStyle(.borderless).controlSize(.small).padding(.horizontal,24).frame(height:54)
            Divider().overlay(subtle)
            HStack {
                Text(model.lidTrackingActive ? "Gently move your MacBook screen to pump the bellows." : "Drag the rear panel to breathe into the reeds.")
                Spacer()
                Text("\(model.settings.scale.rawValue) · Sa = \(NoteNames.western[model.settings.tonic])")
            }.font(.system(size:11)).foregroundStyle(.secondary).padding(.horizontal,25).frame(height:36)
            HarmoniumViewport(model:model)
            HStack {
                Label(model.pumping ? "PUMPING" : (model.bellows.atLimit ? (model.bellows.fraction < 0.5 ? "FOLDED · DRAG TO OPEN":"OPEN LIMIT · REVERSE TO PUMP") : "BELLOWS"),systemImage:"hand.draw")
                Text("\(Int(model.bellows.angle*180 / .pi))°").monospacedDigit()
                Spacer()
                if !model.notes.active.isEmpty {
                    Text(model.notes.active.sorted().map { NoteNames.name($0) }.joined(separator:"  "))
                } else { Text("Click the instrument to play · ESC releases all") }
            }.font(.system(size:10,weight:.medium,design:.monospaced)).foregroundStyle(.secondary).padding(.horizontal,25).frame(height:27)
            Divider().overlay(subtle)
            HStack(spacing:14) {
                Text("AIR RESERVE").font(.system(size:9,weight:.medium)).tracking(1.3).foregroundStyle(.secondary)
                GeometryReader { g in
                    ZStack(alignment:.leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule().fill(Color(red:0.48,green:0.57,blue:0.51)).frame(width:max(2,g.size.width*model.airflow.reserve))
                    }
                }.frame(width:90,height:4).accessibilityLabel("Air reserve \(Int(model.airflow.reserve*100)) percent")
                Text("\(Int(model.airflow.pressure*100))%").font(.system(size:10,design:.monospaced)).monospacedDigit().foregroundStyle(.secondary).frame(width:34)
                Spacer()
                Text("A W S E D F T G Y H U J K O L P ; '").font(.system(size:10,design:.monospaced)).foregroundStyle(Color.white.opacity(0.65))
                Text("·").foregroundStyle(.tertiary)
                Text("SPACE  pump").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
            }.padding(.horizontal,25).frame(height:43)
            HStack(spacing:12) {
                Circle().fill(model.audioFailed ? Color.orange.opacity(0.75):Color(red:0.48,green:0.57,blue:0.51)).frame(width:5,height:5)
                Text(model.audioStatus).lineLimit(1)
                if model.audioFailed { Button("Retry Audio") { model.audio.start() }.buttonStyle(.link) }
                Spacer()
                Text("\(model.settings.scale.rawValue)  ·  \(model.settings.minimumAir > 0 ? "Air assist on":"Manual air")")
                Button("Controls & credits") { model.help=true }.buttonStyle(.plain)
            }.font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal,25).frame(height:31).background(Color.black.opacity(0.17))
        }.background(surface).tint(Color(red:0.59,green:0.66,blue:0.60))
        .sheet(isPresented:$model.help) { helpPanel }
    }
    private var airPanel: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Bellows & touch").font(.headline)
            labeledSlider("Pumping sensitivity", value:$model.settings.sensitivity,range:0.2...3)
            labeledSlider("Minimum airflow",value:$model.settings.minimumAir,range:0...0.5)
            labeledSlider("Key strength",value:$model.settings.keyVelocity,range:0.2...1)
            Text("Each stroke fills a reserve. At either limit, reverse direction. Set minimum airflow to zero for manual air, or leave a little assist for relaxed playing.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open one step") { model.setBellows(model.bellows.angle+0.1) }
                Button("Close one step") { model.setBellows(model.bellows.angle-0.1) }
            }.controlSize(.small)
        }
    }
    private var lidPanel: some View {
        VStack(alignment:.leading,spacing:15) {
            Text("Play with your MacBook screen").font(.headline)
            Text(model.lidStatus).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
            Toggle("Screen movement drives bellows",isOn:Binding(get:{model.lidAvailable && model.lidEnabled},set:{model.lidEnabled=$0})).disabled(!model.lidAvailable)
            if let degrees=model.lidDegrees {
                Text("Physical screen angle: \(Int(degrees))°").monospacedDigit().font(.caption)
            }
            HStack {
                Button("Calibrate here") { model.calibrateLid() }.disabled(!model.lidAvailable)
                Button("Check sensor again") { model.retryLid() }
            }.controlSize(.small)
            Text("Keep the laptop on a stable surface and use gentle, small movements around a comfortable viewing angle. Hold keyboard notes or enable a drone. Do not force or slam the hinge. Closing the lid can still sleep your Mac.").font(.caption).foregroundStyle(.secondary)
            Text("Requires an exposed continuous lid-angle sensor. The 2020 M1 MacBook Air does not provide one; the open/closed switch cannot measure flapping. Mouse and Space remain available.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func labeledSlider(_ title:String,value:Binding<Double>,range:ClosedRange<Double>)->some View {
        VStack(alignment:.leading,spacing:6) {
            HStack { Text(title); Spacer(); Text(String(format:"%.2f",value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary) }.font(.caption)
            Slider(value:value,in:range).accessibilityLabel(title)
        }
    }
    private var musicPanel: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Practice & drones").font(.headline)
            Picker("Sa / tonic",selection:$model.settings.tonic) { ForEach(0..<12,id:\.self) { Text(NoteNames.western[$0]).tag($0) } }
            Picker("Scale guide",selection:$model.settings.scale) { ForEach(PracticeScale.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
            Toggle("Sa drone",isOn:$model.settings.droneTonic)
            Toggle("Pa drone (fifth)",isOn:$model.settings.droneFifth)
            Text("Scale guides dim out-of-scale labels, never block notes. Lowercase re, ga, dha and ni indicate komal notes; Ma♯ is tivra. Drones use the same recorded voice, not separate reed stops.").font(.caption).foregroundStyle(.secondary)
        }.font(.system(size:12))
    }
    private var helpPanel: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("Meet your harmonium").font(.title2); Spacer(); Button("Done") { model.help=false }.keyboardShortcut(.defaultAction) }
            Text("BREATHE").font(.caption).tracking(2).foregroundStyle(.secondary)
            Text("On a supported MacBook, the lid sensor can drive the bellows directly: gently move your physical screen while holding notes. Use the laptop button for sensor status and calibration. Unsupported hardware is labeled unavailable; no synthetic screen motion is substituted.")
            Text("Grab the rear wood panel. Pull upward to open; push downward to close. The hinge stays fixed while the cloth folds spread. Both strokes replenish a slowly draining air reserve. Hold Space for an accessible continuous pump.")
            Text("PLAY").font(.caption).tracking(2).foregroundStyle(.secondary)
            Text("Click and hold a key, or drag across the keyboard. Play chords with computer keys while dragging the bellows. A W S E D F T G Y H U J K O L P ; ' map chromatically from the first C. Left / Right arrows change octave. Escape or ⌘. releases everything. Click the instrument after using a toolbar control to resume computer-key playing.")
            Text("SOUND & CREDITS").font(.caption).tracking(2).foregroundStyle(.secondary)
            Text("Acoustic recordings: Donya Quick, ‘Harmonium Samples – All Keys and Drones’, recorded at Yale’s Euterpea Studio. Freesound #330410, CC0 1.0. Bundled notes are trimmed, tuned and looped derivatives of the HQ MP3 preview, not the original lossless WAV. Missing notes are pitch-shifted from the nearest available sample; if none load, a clearly labeled synthesized reed fallback is used.")
            Link("Recording & license",destination:URL(string:"https://freesound.org/people/donyaquick/sounds/330410/")!)
            Text("No accounts, microphone access, telemetry or runtime downloads. Stop knobs on the rendered body are visual details only; no unsupported reed-stop claims. Volume starts conservatively. Headphones recommended.").foregroundStyle(.secondary)
        }.font(.system(size:12)).lineSpacing(4).padding(30).frame(width:590)
    }
}
