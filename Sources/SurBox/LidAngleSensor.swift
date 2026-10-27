import Foundation
import IOKit.hid
import SurBoxCore

// IOKit is public, but this Apple sensor/report contract is undocumented and
// hardware-dependent. Probe ONLY the angle sensor, never keyboards/trackpads.
// Hardware protocol references and limitations: LID_TRACKING.md.
final class LidAngleSensor {
    enum Reading {
        case angle(Double)
        case unavailable(String)
    }
    private let queue=DispatchQueue(label:"SurBox.lid-sensor",qos:.userInteractive)
    private var timer:DispatchSourceTimer?
    private var device:IOHIDDevice?
    private var manager:IOHIDManager?
    private var report=[UInt8](repeating:0,count:8)
    private var nextProbe=0.0
    private var lastMessage=""
    private let deliver:(Reading)->Void
    init(deliver:@escaping(Reading)->Void) { self.deliver=deliver }
    func start() {
        queue.async { [weak self] in
            guard let self,self.timer==nil else{return}
            let timer=DispatchSource.makeTimerSource(queue:self.queue)
            timer.schedule(deadline:.now(),repeating:.milliseconds(20),leeway:.milliseconds(2))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer=timer; timer.resume()
        }
    }
    func retry() { queue.async { [weak self] in self?.close(); self?.nextProbe=0; self?.lastMessage=""; self?.poll() } }
    func stop() { queue.async { [weak self] in self?.timer?.cancel(); self?.timer=nil; self?.close() } }
    private func close() {
        if let device { IOHIDDeviceClose(device,IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager,IOOptionBits(kIOHIDOptionsTypeNone)) }
        device=nil; manager=nil
    }
    private func unavailable(_ message:String) {
        close(); nextProbe=ProcessInfo.processInfo.systemUptime+5
        guard message != lastMessage else{return}; lastMessage=message
        DispatchQueue.main.async { [deliver] in deliver(.unavailable(message)) }
    }
    private func poll() {
        let now=ProcessInfo.processInfo.systemUptime
        guard now>=nextProbe else{return}
        if device==nil {
            let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager=manager
            let match:[String:Any]=[kIOHIDVendorIDKey:0x05AC,kIOHIDProductIDKey:0x8104,kIOHIDDeviceUsagePageKey:0x0020,kIOHIDDeviceUsageKey:0x008A]
            IOHIDManagerSetDeviceMatching(manager,match as CFDictionary)
            let result=IOHIDManagerOpen(manager,IOOptionBits(kIOHIDOptionsTypeNone))
            guard result==kIOReturnSuccess else { unavailable("macOS denied access to the lid-angle sensor (\(result)). Mouse and Space still work."); return }
            guard let devices=IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,let candidate=devices.first else {
                unavailable("No compatible continuous lid-angle sensor is exposed by this Mac. A binary lid-open switch cannot track flapping."); return
            }
            let opened=IOHIDDeviceOpen(candidate,IOOptionBits(kIOHIDOptionsTypeNone))
            guard opened==kIOReturnSuccess else { unavailable("Lid-angle sensor found, but it could not be opened (\(opened))."); return }
            device=candidate
        }
        guard let device else{return}
        var length=report.count
        let result=IOHIDDeviceGetReport(device,kIOHIDReportTypeFeature,CFIndex(1),&report,&length)
        guard result==kIOReturnSuccess,length>=3,let degrees=LidMotion.decode(Array(report.prefix(length))) else {
            unavailable("The lid-angle sensor stopped returning valid readings. Tracking paused; mouse and Space still work."); return
        }
        lastMessage=""
        DispatchQueue.main.async { [deliver] in deliver(.angle(degrees)) }
    }
}
