import Foundation

// Pure deterministic instrument logic. Opening AND closing supply a virtual
// reservoir, per the product brief; this is a player-friendly air abstraction,
// not a claim that every real harmonium has double-acting inlet valves.
public struct BellowsController {
    public static let closed = 0.07
    public static let open = 0.92
    public private(set) var angle: Double = closed
    public init() {}
    @discardableResult public mutating func setAngle(_ value: Double) -> Double {
        guard value.isFinite else { return angle }
        angle = min(Self.open, max(Self.closed, value)); return angle
    }
    public var fraction: Double { (angle - Self.closed) / (Self.open - Self.closed) }
    public var atLimit: Bool { angle <= Self.closed + 0.002 || angle >= Self.open - 0.002 }
}

public struct AirflowModel {
    public private(set) var reserve = 0.28
    public private(set) var pressure = 0.22
    public private(set) var velocity = 0.0
    public private(set) var direction = 0
    private var previousAngle = BellowsController.closed
    public init() {}
    public mutating func reset(angle: Double = BellowsController.closed) {
        self = Self(); previousAngle = angle
    }
    public mutating func step(angle: Double, dt: Double, notes: Int, sensitivity: Double, minimum: Double) {
        guard dt.isFinite, dt > 0, angle.isFinite else { return }
        let t = min(dt, 0.1)
        let boundedAngle = min(BellowsController.open, max(BellowsController.closed, angle))
        let delta = boundedAngle - previousAngle
        previousAngle = boundedAngle
        let speed = min(abs(delta) / t, 5)
        direction = abs(delta) < 0.00001 ? 0 : (delta > 0 ? 1 : -1)
        velocity += (speed - velocity) * (1 - exp(-t / 0.065))
        let pump = min(3, speed * min(3, max(0.2, sensitivity)) * 0.85)
        let consumption = 0.20 + Double(min(max(notes, 0), 16)) * 0.025
        reserve = min(1, max(0, reserve + (pump - consumption * (0.25 + reserve)) * t))
        let floor = min(0.5, max(0, minimum))
        let target = floor + (1 - floor) * min(1, reserve * 0.9 + velocity * 0.09)
        pressure += (target - pressure) * (1 - exp(-t / (target > pressure ? 0.06 : 0.30)))
        pressure = min(1, max(0, pressure))
    }
}

public enum PracticeScale: String, CaseIterable, Codable {
    case free = "Free play", bilawal = "Bilawal", kafi = "Kafi", bhairav = "Bhairav"
    public var intervals: Set<Int> {
        switch self {
        case .free: return Set(0..<12)
        case .bilawal: return [0,2,4,5,7,9,11]
        case .kafi: return [0,2,3,5,7,9,10]
        case .bhairav: return [0,1,4,5,7,8,11]
        }
    }
}

public struct InstrumentSettings: Codable {
    public var volume = 0.48
    public var octave = 3
    public var sensitivity = 1.25
    public var minimumAir = 0.20
    public var keyVelocity = 0.78
    public var tonic = 0
    public var scale = PracticeScale.free
    public var droneTonic = false
    public var droneFifth = false
    public var muted = false
    public init() {}
    public mutating func sanitize() {
        volume = volume.isFinite ? min(1, max(0, volume)) : 0.48
        octave = min(5, max(2, octave))
        sensitivity = sensitivity.isFinite ? min(3, max(0.2, sensitivity)) : 1.25
        minimumAir = minimumAir.isFinite ? min(0.5, max(0, minimumAir)) : 0.20
        keyVelocity = keyVelocity.isFinite ? min(1, max(0.2, keyVelocity)) : 0.78
        tonic = ((tonic % 12) + 12) % 12
    }
    public var firstNote: Int { (octave + 1) * 12 }
    public func isInScale(_ note: Int) -> Bool { scale.intervals.contains((note - tonic + 120) % 12) }
    public func droneNote(fifth: Bool) -> Int { firstNote + tonic + (fifth ? 7 : 0) }
}

// Sources own notes rather than booleans: releasing a pointer cannot silence
// the same pitch still held by a hardware key or a drone.
public struct NoteLedger {
    public private(set) var sources: [String: Int] = [:]
    public init() {}
    public var active: Set<Int> { Set(sources.values) }
    public mutating func press(source: String, note: Int) { if (0...127).contains(note) { sources[source] = note } }
    public mutating func release(source: String) { sources.removeValue(forKey: source) }
    public mutating func releaseAll() { sources.removeAll() }
}

public enum NoteNames {
    public static let western = ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"]
    public static let sargam = ["Sa","re","Re","ga","Ga","Ma","Ma♯","Pa","dha","Dha","ni","Ni"]
    public static func name(_ midi: Int) -> String { western[(midi + 120) % 12] + String(midi / 12 - 1) }
    public static func solfege(_ midi: Int, tonic: Int) -> String { sargam[(midi - tonic + 120) % 12] }
}

public enum ComputerKeys {
    // ANSI physical key positions, independent of keyboard layout / shift.
    public static let offsets: [UInt16:Int] = [0:0,13:1,1:2,14:3,2:4,3:5,17:6,5:7,16:8,4:9,32:10,38:11,40:12,31:13,37:14,35:15,41:16,39:17]
    public static let legend = ["A","W","S","E","D","F","T","G","Y","H","U","J","K","O","L","P",";","'"]
}
