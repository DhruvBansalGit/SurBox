import Foundation

// User request: the PHYSICAL MacBook screen drives the virtual bellows.
// A gentle +/-20 degree stroke around a comfortable calibrated position spans
// the bellows. No need to close the laptop or force its hinge to a hard stop.
public struct LidMotion {
    public private(set) var baseline: Double?
    public private(set) var angle = BellowsController.closed
    private var anchor = BellowsController.closed
    private var lastDegrees: Double?
    private var lastTime: Double?
    public init() {}
    public mutating func reset() { self = Self() }
    @discardableResult public mutating func calibrate(degrees: Double, angle: Double, time: Double) -> Bool {
        guard degrees.isFinite, (30...160).contains(degrees), time.isFinite else { return false }
        baseline=degrees; lastDegrees=degrees; lastTime=time
        self.angle=min(BellowsController.open,max(BellowsController.closed,angle)); anchor=self.angle
        return true
    }
    // Device feature report 1: report ID, little-endian unsigned degree value.
    // Neither binary clamshell state nor bogus 0/65535 values become motion.
    public static func decode(_ bytes:[UInt8]) -> Double? {
        guard bytes.count>=3, bytes[0]==1 else { return nil }
        let degrees=Int(bytes[1]) | (Int(bytes[2])<<8)
        return (0...180).contains(degrees) ? Double(degrees):nil
    }
    public mutating func ingest(degrees:Double,time:Double) -> Double? {
        guard let baseline,let previous=lastDegrees,let previousTime=lastTime,
              degrees.isFinite,time.isFinite,(30...160).contains(degrees),time>previousTime else { return nil }
        let dt=time-previousTime
        // Reconnection / wake gets a fresh reference, not a burst of fake air.
        guard dt<0.6 else { self.baseline=nil; return nil }
        guard abs(degrees-previous)/dt<500 else { return nil }
        lastTime=time
        guard abs(degrees-previous)>=0.65 else { return angle }
        lastDegrees=degrees
        let gain=(BellowsController.open-BellowsController.closed)/40
        angle=min(BellowsController.open,max(BellowsController.closed,anchor+(degrees-baseline)*gain))
        // Re-anchor a saturated endpoint: reversing immediately moves the panel.
        if angle==BellowsController.closed || angle==BellowsController.open {
            self.baseline=degrees; anchor=angle
        }
        return angle
    }
}
