import AppKit
import SceneKit
import AVFoundation
import SurBoxCore
import SurBoxDSP

// Opt-in in-process acceptance harness. Dispatches NSEvents to the real view,
// inspects actual Metal renders and writes PCM from the production DSP. Does
// not pretend to be a human listening test or an external XCUITest driver.
@MainActor enum NativeChecks {
    static var log=[String]()
    static var failures=0
    static var folder:URL {
        let argument=CommandLine.arguments.first{$0.hasPrefix("--report-dir=")}
        return URL(fileURLWithPath:argument.map{String($0.dropFirst(13))} ?? "/tmp/surbox-native")
    }
    static func check(_ ok:Bool,_ label:String) { let s="\(ok ? "PASS":"FAIL") \(label)"; log.append(s); print(s); if !ok { failures += 1 } }
    static func pause(_ seconds:Double=0.15) async { try? await Task.sleep(nanoseconds:UInt64(seconds*1e9)) }
    static func run(model:InstrumentModel) { Task { await exercise(model) } }
    static func savePNG(_ image:NSImage,_ name:String) {
        if let tiff=image.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let data=rep.representation(using:.png,properties:[:]) { try? data.write(to:folder.appendingPathComponent(name)) }
    }
    static func capture(_ view:HarmoniumScene,_ name:String) {
        guard let content=view.window?.contentView else{return}
        let sceneImage=view.snapshot()
        savePNG(sceneImage,name+"-scene.png")
        // Native SwiftUI bitmap plus actual SceneKit snapshot: Metal-backed
        // views do not consistently appear in cacheDisplay by themselves.
        if let rep=content.bitmapImageRepForCachingDisplay(in:content.bounds) {
            content.cacheDisplay(in:content.bounds,to:rep)
            let image=NSImage(size:content.bounds.size); image.lockFocus()
            rep.draw(in:content.bounds)
            var rect=view.convert(view.bounds,to:content)
            if content.isFlipped { rect.origin.y=content.bounds.height-rect.maxY }
            sceneImage.draw(in:rect)
            image.unlockFocus(); savePNG(image,name+".png")
        }
    }
    static func mouse(_ view:HarmoniumScene,_ type:NSEvent.EventType,_ p:CGPoint) {
        guard let win=view.window else{return}
        let location=view.convert(p,to:nil)
        let e=NSEvent.mouseEvent(with:type,location:location,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:win.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:type == .leftMouseUp ? 0:1)!
        // Full NSWindow routing, including hit-test and first responder.
        win.sendEvent(e)
    }
    static func key(_ view:HarmoniumScene,_ type:NSEvent.EventType,_ code:UInt16,repeatKey:Bool=false) {
        let e=NSEvent.keyEvent(with:type,location:.zero,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:view.window!.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:repeatKey,keyCode:code)!
        view.window?.sendEvent(e)
    }
    static func exercise(_ model:InstrumentModel) async {
        try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        guard let view=model.scene,let window=view.window else { check(false,"Native scene/window present"); finish(); return }
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view)
        check(view.renderingAPI == .metal,"SceneKit uses native Metal")
        check(view.keys.count==37,"37 individually modeled keys")
        log.append("INFO Actual lid sensor: available=\(model.lidAvailable), degrees=\(model.lidDegrees.map{String($0)} ?? "none"), status=\(model.lidStatus)")
        check(!model.lidStatus.hasPrefix("Checking"),"Real lid sensor probe resolves without blocking the UI")
        if !model.lidAvailable { check(model.lidDegrees==nil && !model.lidTrackingActive,"Absent physical sensor does not fabricate lid motion") }
        let fallback=CommandLine.arguments.contains("--fallback") || CommandLine.arguments.contains("--missing-resources")
        let audioFailure=CommandLine.arguments.contains("--audio-failure")
        if audioFailure {
            check(model.audioFailed,"Audio initialization error surfaced")
            model.audio.start(); await pause(1)
            check(!model.audioFailed,"Retry recovers audio after simulated failure")
        } else {
            check(!model.audioFailed,"AVAudioEngine starts on actual output device")
        }
        check(fallback ? model.audioStatus.contains("fallback"):model.audio.sampleCount==39, fallback ? "Missing samples select explicit synthesized fallback":"All 39 bundled recordings decode")
        check(model.bellows.fraction==0,"Starts folded")
        await pause(0.4); capture(view,"01-folded")
        let pivot=view.hinge.worldPosition
        let body=view.scene!.rootNode.childNode(withName:"body",recursively:true)!.worldTransform
        let front=view.keys[0]!.worldPosition
        let start=view.bellowsPoint()
        mouse(view,.leftMouseDown,start)
        check(model.pumping,"Real hit-tested panel starts drag")
        for i in 1...24 { mouse(view,.leftMouseDragged,CGPoint(x:start.x,y:start.y+CGFloat(i)*5)); await pause(0.012) }
        mouse(view,.leftMouseUp,CGPoint(x:start.x,y:start.y+120))
        check(model.bellows.angle>0.5,"Dragging visibly opens rotating panel")
        check(abs(view.hinge.worldPosition.x-pivot.x)<0.0001 && abs(view.hinge.worldPosition.y-pivot.y)<0.0001 && abs(view.hinge.worldPosition.z-pivot.z)<0.0001,"Hinge world pivot remains fixed")
        check(SCNMatrix4EqualToMatrix4(body,view.scene!.rootNode.childNode(withName:"body",recursively:true)!.worldTransform),"Main body is stationary during pumping")
        check(view.keys[0]!.worldPosition.x==front.x && view.keys[0]!.worldPosition.y==front.y,"Keyboard stays stationary during pumping")
        check(model.airflow.reserve>0.3,"Pointer movement replenishes actual airflow reserve")
        check(view.foldRoot.childNodes.count==24,"Twelve accordion pleats expand as 24 facets")
        await pause(); capture(view,"02-open")
        let openImage=view.snapshot().tiffRepresentation
        let closeStart=view.bellowsPoint(); mouse(view,.leftMouseDown,closeStart)
        for i in 1...40 { mouse(view,.leftMouseDragged,CGPoint(x:closeStart.x,y:closeStart.y-CGFloat(i)*6)); await pause(0.005) }
        mouse(view,.leftMouseUp,closeStart)
        check(model.bellows.angle==BellowsController.closed,"Reverse drag closes and clamps panel")
        await pause(); check(openImage != view.snapshot().tiffRepresentation,"Open and closed Metal renders differ")
        // Computer chords, repeat suppression, pointer ownership and glissando.
        key(view,.keyDown,0); key(view,.keyDown,2); key(view,.keyDown,5)
        check(model.notes.active==[48,52,55],"Computer keyboard chord C/E/G")
        key(view,.keyDown,0,repeatKey:true)
        check(model.notes.sources.count==3,"Auto-repeat does not duplicate notes")
        if let point=view.keyPoint(offset:0) {
            mouse(view,.leftMouseDown,point)
            check(model.notes.sources["pointer"]==48,"Mouse click hits cream key")
            mouse(view,.leftMouseUp,point)
            check(model.notes.active.contains(48),"Mouse release preserves computer-held pitch")
        }
        key(view,.keyUp,0); key(view,.keyUp,2); key(view,.keyUp,5)
        check(model.notes.active.isEmpty,"Key releases clear chord")
        if let c=view.keyPoint(offset:0),let d=view.keyPoint(offset:2),let e=view.keyPoint(offset:4) {
            mouse(view,.leftMouseDown,c); mouse(view,.leftMouseDragged,d); mouse(view,.leftMouseDragged,e)
            check(model.notes.active==[52],"Pointer glissando changes pitch without stuck notes")
            mouse(view,.leftMouseUp,e); check(model.notes.active.isEmpty,"Glissando release clears note")
        }
        let black=view.projectPoint(view.keys[1]!.convertPosition(SCNVector3(0,12,15),to:nil))
        mouse(view,.leftMouseDown,CGPoint(x:black.x,y:black.y)); check(model.notes.active==[49],"Raised black key hit-test wins")
        mouse(view,.leftMouseUp,CGPoint(x:black.x,y:black.y))
        key(view,.keyDown,0); model.shiftOctave(1)
        check(model.notes.active.isEmpty && model.settings.firstNote==60,"Octave change releases old pitches")
        model.settings.tonic=2; model.settings.droneTonic=true; model.settings.droneFifth=true
        check(model.notes.active==[62,69],"Selectable Sa and fifth drones")
        model.settings.muted=true; check(model.notes.active.isEmpty,"Mute releases sounding notes")
        model.reset(); window.makeFirstResponder(view)
        key(view,.keyDown,49); await pause(0.7); key(view,.keyUp,49)
        check(model.bellows.fraction>0.25 && !model.pumping,"Space pump works and stops on release")
        key(view,.keyDown,0); NotificationCenter.default.post(name:NSApplication.didResignActiveNotification,object:NSApp)
        check(model.notes.active.isEmpty && !model.pumping,"App deactivation prevents stuck keys and pumping")
        model.suspended=false; model.reset()
        key(view,.keyDown,0); key(view,.keyDown,53)
        check(model.notes.active.isEmpty,"Escape is immediate panic")
        let elements=view.accessibilityChildren() as? [InstrumentAccessibilityElement] ?? []
        check(elements.count==38,"Accessibility exposes 37 keys and hinged bellows")
        if let first=elements.first,let pump=elements.last {
            check(first.accessibilityLabel()?.contains("Sa")==true,"Accessible key includes Western and relative Indian note")
            _ = first.accessibilityPerformPress(); check(model.notes.active==[48],"Accessibility press holds a note")
            _ = first.accessibilityPerformPress(); check(model.notes.active.isEmpty,"Accessibility second press releases note")
            let before=model.bellows.angle
            _ = pump.accessibilityPerformIncrement(); check(model.bellows.angle>before,"Accessible bellows opens")
            _ = pump.accessibilityPerformDecrement(); check(model.bellows.angle==before,"Accessible bellows closes")
        }
        key(view,.keyDown,0); window.makeFirstResponder(nil)
        check(model.notes.active.isEmpty,"Keyboard focus loss releases notes")
        window.makeFirstResponder(view)
        // Capture the coherent final playing state, not an independent animation.
        model.setBellows(0.62)
        model.press(48,source:"test-a"); model.press(52,source:"test-b"); model.press(55,source:"test-c")
        await pause(0.4); capture(view,"03-playing")
        model.releaseAll()
        checkFraming(view,model,"default")
        window.setContentSize(NSSize(width:850,height:620)); await pause(0.4)
        check(view.bounds.width>=800 && view.bounds.height>350,"Compact window retains playable scene")
        capture(view,"04-compact")
        checkFraming(view,model,"compact")
        window.setContentSize(NSSize(width:1180,height:800)); await pause()
        let begin=ProcessInfo.processInfo.systemUptime
        for i in 0..<600 {
            let angle=0.495+0.425*sin(Double(i)/15)
            model.setBellows(angle); model.press(48+i%24,source:"stress"); model.release("stress")
            if i%10==0 { await pause(0.001) }
        }
        let elapsed=ProcessInfo.processInfo.systemUptime-begin
        check(model.notes.active.isEmpty && model.bellows.angle.isFinite,"600 rapid notes and bellows reversals leave valid state")
        log.append(String(format:"INFO 600 scene/state updates: %.3f s (includes deliberate yields; not hardware latency)",elapsed))
        let soakArg=CommandLine.arguments.first{$0.hasPrefix("--soak-seconds=")}
        let soakSeconds=Double(soakArg.map{String($0.dropFirst(15))} ?? "5") ?? 5
        let soakStart=ProcessInfo.processInfo.systemUptime
        var frames=0
        while ProcessInfo.processInfo.systemUptime-soakStart<soakSeconds {
            for n in 0..<8 { model.press(48+(frames/6+n*3)%25,source:"soak-\(n)") }
            model.setBellows(0.495+0.425*sin(Double(frames)/40))
            frames += 1; await pause(1/60)
        }
        model.releaseAll()
        check(model.notes.active.isEmpty && !model.audioFailed,"Sustained 8-voice playing with bellows: \(Int(soakSeconds)) seconds / \(frames) updates")
        model.settings.minimumAir=0.4
        model.press(48,source:"live-a"); model.press(52,source:"live-b"); model.press(55,source:"live-c")
        let liveURL=folder.appendingPathComponent("actual-engine-output.wav")
        let captured=await withCheckedContinuation { continuation in
            model.audio.diagnosticCapture(to:liveURL,seconds:0.8) { continuation.resume(returning:$0) }
        }
        model.releaseAll()
        if captured,let file=try? AVAudioFile(forReading:liveURL),let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length)),(try? file.read(into:buffer)) != nil,let samples=buffer.floatChannelData?[0] {
            let peak=(0..<Int(buffer.frameLength)).reduce(Float(0)){max($0,abs(samples[$1]))}
            check(peak>0.01 && peak<1,"Actual running AVAudioEngine mixer produces nonzero unclipped chord")
            log.append("INFO live mixer sample rate=\(file.processingFormat.sampleRate), frames=\(buffer.frameLength), peak=\(peak)")
        } else { check(false,"Actual AVAudioEngine mixer capture") }
        renderAudio(root:HarmoniumAudioEngine.resourceRoot, fallback:fallback)
        await checkLidIntegration(model,view)
        model.reset(); finish()
    }
    static func checkLidIntegration(_ model:InstrumentModel,_ view:HarmoniumScene) async {
        let actualAvailable=model.lidAvailable, actualStatus=model.lidStatus
        model.lidPanel=true; await pause(0.4)
        for w in NSApp.windows where w.isVisible && w.frame.width>300 && w.frame.width<600 {
            if let content=w.contentView,let rep=content.bitmapImageRepForCachingDisplay(in:content.bounds) {
                content.cacheDisplay(in:content.bounds,to:rep)
                if let data=rep.representation(using:.png,properties:[:]) { try? data.write(to:folder.appendingPathComponent("06-physical-lid-status.png")) }
            }
        }
        model.lidPanel=false; model.stopLid(); await pause(0.2)
        // Injected values exercise the actual app integration, NOT a claim that
        // this M1 Air has a working physical sensor. No production demo mode.
        model.reset(); model.suspended=false; model.lidEnabled=true
        model.setBellows(BellowsController.closed); await pause(0.4)
        let initial=model.bellows.angle
        model.receiveLid(.angle(90)); await pause(0.03)
        check(model.bellows.angle==initial,"Injected lid: first reading calibrates without a jump")
        model.press(48,source:"lid-test")
        let reserve=model.airflow.reserve
        for i in 1...20 { model.receiveLid(.angle(90+Double(i))); await pause(0.03) }
        check(model.bellows.angle>initial+0.3 && model.airflow.reserve>reserve,"Injected lid: opening rotates actual bellows and pumps air")
        let opened=model.bellows.angle
        for i in 1...20 { model.receiveLid(.angle(110-Double(i))); await pause(0.03) }
        check(model.bellows.angle<opened-0.3 && model.notes.active.contains(48),"Injected lid: closing reverses bellows while held note continues")
        model.receiveLid(.unavailable("Injected read failure"))
        check(!model.lidTrackingActive,"Injected lid: read failure disables tracking without a fake stroke")
        model.lidEnabled=false; let stationary=model.bellows.angle
        model.receiveLid(.angle(110)); await pause(0.03); model.receiveLid(.angle(112))
        check(model.bellows.angle==stationary,"Injected lid: disabled tracking ignores screen movement")
        model.lidEnabled=true; model.calibrateLid(); await pause(0.03)
        model.receiveLid(.angle(20))
        check(model.notes.active.isEmpty && !model.lidTrackingActive,"Injected lid: near-close state releases notes and pauses")
        model.suspended=false; model.releaseAll()
        model.receiveLid(.unavailable(actualAvailable ? "Hardware probe stopped after isolated test":actualStatus))
        log.append("INFO Physical movement acceptance remains unverified; integration tests above used injected angle readings.")
    }
    static func checkFraming(_ view:HarmoniumScene,_ model:InstrumentModel,_ label:String) {
        let before=model.bellows.angle
        model.setBellows(BellowsController.open)
        var points=[SCNVector3]()
        for x in [-305.0,305.0] { for y in [0.0,137.0] { for z in [-162.0,228.0] { points.append(SCNVector3(x,y,z)) } } }
        for x in [-288.5,288.5] { for z in [0.0,208.0] { points.append(view.hinge.convertPosition(SCNVector3(x,8,z),to:nil)) } }
        let projected=points.map{view.projectPoint($0)}
        check(projected.allSatisfy{$0.x>12 && $0.x<view.bounds.width-12 && $0.y>12 && $0.y<view.bounds.height-12},"Full body and maximum-open panel fit \(label) viewport without cropping")
        log.append("INFO \(label) projected bounds x=\(projected.map{$0.x}.min()!)..\(projected.map{$0.x}.max()!) y=\(projected.map{$0.y}.min()!)..\(projected.map{$0.y}.max()!), viewport=\(view.bounds.size)")
        model.setBellows(before)
    }
    static func renderAudio(root:URL, fallback:Bool) {
        let dsp=sb_create(48000)!; defer{sb_destroy(dsp)}
        if !fallback,let data=try? Data(contentsOf:root.appendingPathComponent("samples.json")),let list=try? JSONDecoder().decode([SampleRecord].self,from:data) {
            for record in list {
                if let f=try? AVAudioFile(forReading:root.appendingPathComponent(record.file)),let b=AVAudioPCMBuffer(pcmFormat:f.processingFormat,frameCapacity:AVAudioFrameCount(f.length)),(try? f.read(into:b)) != nil,let p=b.floatChannelData?[0] { sb_load_sample(dsp,Int32(record.midi),p,Int32(b.frameLength),f.processingFormat.sampleRate,Int32(record.loopStart),Int32(record.loopEnd)) }
            }
        }
        check(sb_sample_count(dsp)==(fallback ? 0:39),fallback ? "Offline renderer exercises synthesized fallback":"Offline renderer loads complete sample manifest")
        let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:1)!
        let file=try? AVAudioFile(forWriting:folder.appendingPathComponent("surbox-audio-check.wav"),settings:format.settings)
        let block=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:256)!; block.frameLength=256
        var peak:Float=0, energy=0.0, jump:Float=0,last:Float=0, tail:Float=0
        var maxSeconds=0.0
        sb_controls(dsp,0.75,0.48,0)
        for n:Int32 in [48,52,55] { sb_note(dsp,n,0.8) }
        for i in 0..<2400 {
            if i==1850 { sb_panic(dsp) }
            let begin=ProcessInfo.processInfo.systemUptime
            sb_render(dsp,block.floatChannelData![0],256)
            maxSeconds=max(maxSeconds,ProcessInfo.processInfo.systemUptime-begin)
            for j in 0..<256 {
                let v=block.floatChannelData![0][j]; peak=max(peak,abs(v)); jump=max(jump,abs(v-last)); energy+=Double(v*v); last=v
                if i>2300 { tail=max(tail,abs(v)) }
            }
            try? file?.write(from:block)
        }
        check(peak>0.03 && energy>1,"Production sampled DSP produces nonzero audible-range PCM")
        check(peak<0.95 && jump<0.15,"Chord with multiple loop wraps remains bounded without abrupt sample jumps")
        check(tail<0.00001,"Released sample chord decays to silence")
        log.append(String(format:"INFO sampled PCM peak=%.5f max adjacent jump=%.5f tail=%.8f; max 256-frame render %.3f ms",peak,jump,tail,maxSeconds*1000))
    }
    static func finish() {
        log.append("RESULT native checks=\(log.filter{$0.hasPrefix("PASS") || $0.hasPrefix("FAIL")}.count) failures=\(failures)")
        try? (log.joined(separator:"\n")+"\n").write(to:folder.appendingPathComponent("native-results.txt"),atomically:true,encoding:.utf8)
        print(log.last!); NSApp.terminate(nil)
    }
}
