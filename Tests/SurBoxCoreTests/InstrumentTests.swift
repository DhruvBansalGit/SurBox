import Foundation
#if canImport(XCTest)
import XCTest
#else
// The exact same test bodies run on Command Line Tools, without XCTest.
class XCTestCase {}
private var failures = 0
func check(_ ok: Bool, _ line: UInt = #line) { if !ok { failures += 1; print("FAIL line \(line)") } }
func XCTAssertTrue(_ x: Bool, line: UInt = #line) { check(x,line) }
func XCTAssertFalse(_ x: Bool, line: UInt = #line) { check(!x,line) }
func XCTAssertEqual<T: Equatable>(_ a:T,_ b:T,line:UInt = #line) { check(a==b,line) }
func XCTAssertEqual(_ a:Double,_ b:Double,accuracy:Double,line:UInt = #line) { check(abs(a-b)<=accuracy,line) }
func XCTAssertLessThan<T:Comparable>(_ a:T,_ b:T,line:UInt = #line) { check(a<b,line) }
func XCTAssertGreaterThan<T:Comparable>(_ a:T,_ b:T,line:UInt = #line) { check(a>b,line) }
@main enum CoreValidation {
    static func main() throws {
        let t=InstrumentTests()
        t.testBellowsLimitsAndInvalidInput(); t.testBothDirectionsPumpSymmetrically()
        t.testPressureDecayAndBeginnerAssist(); t.testClampedPanelCannotPumpAtLimit()
        t.testReversalRemainsSmooth(); t.testSensitivityIncreasesReserve()
        t.testInvalidTimeDoesNotCorruptState(); t.testNoteOwnershipChordsGlissandoAndPanic()
        try t.testSettingsPersistenceSanitizationAndScale(); t.testKeyboardMappingAndSargam()
        t.testDSPSilenceAttackPolyphonyReleaseMute(); t.testDSPLoopingAndFastRetrigger()
        t.testLidReportAndCalibration(); t.testLidMotionDrivesBothAirStrokes()
        t.testLidLimitsAndNoise(); t.testLidInvalidAndStaleSamples()
        print("RESULT: 16 deterministic test groups, failures=\(failures)")
        exit(failures==0 ? 0:1)
    }
}
#endif
import SurBoxCore
import SurBoxDSP

final class InstrumentTests: XCTestCase {
    func testLidReportAndCalibration() {
        XCTAssertEqual(LidMotion.decode([1,100,0]),100)
        XCTAssertEqual(LidMotion.decode([1,180,0,0]),180)
        XCTAssertEqual(LidMotion.decode([1,255,255]),nil)
        XCTAssertEqual(LidMotion.decode([1,60]),nil)
        XCTAssertEqual(LidMotion.decode([2,100,0]),nil)
        var lid=LidMotion()
        XCTAssertTrue(lid.calibrate(degrees:100,angle:0.4,time:0))
        XCTAssertEqual(lid.ingest(degrees:100,time:0.02),0.4)
        XCTAssertFalse(lid.calibrate(degrees:15,angle:0.4,time:1))
    }
    func testLidMotionDrivesBothAirStrokes() {
        var lid=LidMotion(),air=AirflowModel()
        lid.calibrate(degrees:90,angle:BellowsController.closed,time:0)
        for i in 1...20 {
            let angle=lid.ingest(degrees:90+Double(i),time:Double(i)*0.04)!
            air.step(angle:angle,dt:0.04,notes:3,sensitivity:1.25,minimum:0)
        }
        XCTAssertGreaterThan(lid.angle,0.45); let openReserve=air.reserve
        XCTAssertGreaterThan(openReserve,0.4)
        for i in 21...40 {
            let angle=lid.ingest(degrees:130-Double(i),time:Double(i)*0.04)!
            air.step(angle:angle,dt:0.04,notes:3,sensitivity:1.25,minimum:0)
        }
        XCTAssertEqual(lid.angle,BellowsController.closed,accuracy:0.00001)
        XCTAssertGreaterThan(air.reserve,openReserve); XCTAssertEqual(air.direction,-1)
    }
    func testLidLimitsAndNoise() {
        var lid=LidMotion(); lid.calibrate(degrees:80,angle:0.495,time:0)
        XCTAssertEqual(lid.ingest(degrees:80.2,time:0.02),0.495)
        for i in 1...35 { _=lid.ingest(degrees:80+Double(i),time:Double(i)*0.04) }
        XCTAssertEqual(lid.angle,BellowsController.open)
        let reversed=lid.ingest(degrees:114,time:1.44)!
        XCTAssertLessThan(reversed,BellowsController.open)
        for i in 1...60 { _=lid.ingest(degrees:114-Double(i),time:1.44+Double(i)*0.04) }
        XCTAssertEqual(lid.angle,BellowsController.closed)
    }
    func testLidInvalidAndStaleSamples() {
        var lid=LidMotion(); lid.calibrate(degrees:90,angle:0.3,time:0)
        XCTAssertEqual(lid.ingest(degrees:.nan,time:0.02),nil)
        XCTAssertEqual(lid.ingest(degrees:150,time:0.001),nil)
        XCTAssertEqual(lid.ingest(degrees:10,time:0.02),nil)
        XCTAssertEqual(lid.ingest(degrees:95,time:1),nil)
        XCTAssertEqual(lid.baseline,nil)
        XCTAssertEqual(lid.angle,0.3)
        XCTAssertTrue(lid.calibrate(degrees:110,angle:0.3,time:2))
        XCTAssertEqual(lid.ingest(degrees:110,time:2.02),0.3)
    }
    func testBellowsLimitsAndInvalidInput() {
        var b=BellowsController()
        XCTAssertEqual(b.angle,BellowsController.closed)
        b.setAngle(-200); XCTAssertEqual(b.fraction,0)
        b.setAngle(200); XCTAssertEqual(b.fraction,1)
        b.setAngle(.nan); XCTAssertEqual(b.fraction,1)
        b.setAngle(.infinity); XCTAssertEqual(b.fraction,1)
        b.setAngle(0.5); XCTAssertFalse(b.atLimit)
    }
    func testBothDirectionsPumpSymmetrically() {
        var up=AirflowModel(), down=AirflowModel()
        up.reset(angle:0.1); down.reset(angle:0.9)
        for i in 1...60 {
            up.step(angle:0.1+Double(i)*0.012,dt:1/60,notes:3,sensitivity:1.5,minimum:0)
            down.step(angle:0.9-Double(i)*0.012,dt:1/60,notes:3,sensitivity:1.5,minimum:0)
        }
        XCTAssertEqual(up.reserve,down.reserve,accuracy:0.0001)
        XCTAssertGreaterThan(up.reserve,0.4)
        XCTAssertEqual(up.direction,1); XCTAssertEqual(down.direction,-1)
    }
    func testPressureDecayAndBeginnerAssist() {
        var manual=AirflowModel(), assisted=AirflowModel()
        for _ in 0..<3600 {
            manual.step(angle:0.07,dt:1/60,notes:4,sensitivity:1,minimum:0)
            assisted.step(angle:0.07,dt:1/60,notes:4,sensitivity:1,minimum:0.2)
        }
        XCTAssertLessThan(manual.pressure,0.0001)
        XCTAssertEqual(assisted.pressure,0.2,accuracy:0.001)
    }
    func testClampedPanelCannotPumpAtLimit() {
        var air=AirflowModel(); air.reset(angle:BellowsController.open)
        for _ in 0..<1200 { air.step(angle:99,dt:1/60,notes:1,sensitivity:3,minimum:0) }
        XCTAssertEqual(air.reserve,0); XCTAssertEqual(air.velocity,0)
    }
    func testReversalRemainsSmooth() {
        var air=AirflowModel(); var b=BellowsController(); var last=air.pressure
        for i in 0..<3600 {
            b.setAngle(0.495+0.425*sin(Double(i)/24))
            air.step(angle:b.angle,dt:1/60,notes:8,sensitivity:1.3,minimum:0.2)
            XCTAssertLessThan(abs(air.pressure-last),0.09)
            XCTAssertTrue((0...1).contains(air.pressure)); XCTAssertTrue((0...1).contains(air.reserve))
            last=air.pressure
        }
    }
    func testSensitivityIncreasesReserve() {
        var low=AirflowModel(),high=AirflowModel()
        for i in 0..<60 {
            let a=0.07+Double(i)*0.008
            low.step(angle:a,dt:1/60,notes:4,sensitivity:0.3,minimum:0)
            high.step(angle:a,dt:1/60,notes:4,sensitivity:2,minimum:0)
        }
        XCTAssertGreaterThan(high.reserve,low.reserve)
    }
    func testInvalidTimeDoesNotCorruptState() {
        var a=AirflowModel(); let before=a.pressure
        a.step(angle:0.5,dt:0,notes:0,sensitivity:1,minimum:0)
        a.step(angle:.nan,dt:0.01,notes:0,sensitivity:1,minimum:0)
        a.step(angle:0.5,dt:.nan,notes:0,sensitivity:1,minimum:0)
        XCTAssertEqual(before,a.pressure)
    }
    func testNoteOwnershipChordsGlissandoAndPanic() {
        var n=NoteLedger()
        n.press(source:"key",note:60); n.press(source:"pointer",note:60)
        n.release(source:"pointer"); XCTAssertEqual(n.active,[60])
        n.press(source:"pointer",note:64); n.press(source:"second",note:67)
        XCTAssertEqual(n.active,[60,64,67])
        n.press(source:"pointer",note:65); XCTAssertEqual(n.active,[60,65,67])
        n.press(source:"key",note:60); XCTAssertEqual(n.sources.count,3)
        n.press(source:"invalid",note:500); XCTAssertEqual(n.sources.count,3)
        n.releaseAll(); XCTAssertTrue(n.active.isEmpty)
    }
    func testSettingsPersistenceSanitizationAndScale() throws {
        var s=InstrumentSettings(); s.tonic=2; s.scale = .bhairav; s.volume=0.61
        let decoded=try JSONDecoder().decode(InstrumentSettings.self,from:JSONEncoder().encode(s))
        XCTAssertEqual(decoded.tonic,2); XCTAssertEqual(decoded.volume,0.61)
        XCTAssertTrue(s.isInScale(62)); XCTAssertFalse(s.isInScale(64))
        XCTAssertEqual(s.droneNote(fifth:true)-s.droneNote(fifth:false),7)
        s.octave=99; s.volume = .infinity; s.tonic = -1; s.minimumAir = -4; s.sanitize()
        XCTAssertEqual(s.octave,5); XCTAssertEqual(s.volume,0.48); XCTAssertEqual(s.tonic,11); XCTAssertEqual(s.minimumAir,0)
    }
    func testKeyboardMappingAndSargam() {
        XCTAssertEqual(ComputerKeys.offsets.count,18)
        XCTAssertEqual(Set(ComputerKeys.offsets.values),Set(0..<18))
        XCTAssertEqual(NoteNames.solfege(62,tonic:2),"Sa")
        XCTAssertEqual(NoteNames.solfege(69,tonic:2),"Pa")
        XCTAssertEqual(NoteNames.name(60),"C4")
    }
    func testDSPSilenceAttackPolyphonyReleaseMute() {
        let e=sb_create(48000)!; defer{sb_destroy(e)}
        var data=[Float](repeating:0,count:48000)
        sb_render(e,&data,48000); XCTAssertEqual(data.max(),0)
        sb_controls(e,0.8,0.5,0)
        for n:Int32 in [48,52,55] { sb_note(e,n,0.8) }
        sb_render(e,&data,48000)
        XCTAssertGreaterThan(data.map{abs($0)}.max()!,0.05)
        XCTAssertLessThan(data.map{abs($0)}.max()!,0.9)
        XCTAssertLessThan(zip(data,data.dropFirst()).map{abs($1-$0)}.max()!,0.1)
        sb_panic(e); sb_render(e,&data,48000)
        XCTAssertLessThan(abs(data.last!),0.00001)
        sb_note(e,60,1); sb_controls(e,1,1,1); sb_render(e,&data,48000)
        XCTAssertLessThan(abs(data.last!),0.00001)
    }
    func testDSPLoopingAndFastRetrigger() {
        let e=sb_create(48000)!; defer{sb_destroy(e)}
        var pcm=(0..<96000).map{Float(sin(Double($0)*2 * .pi * 261.625/48000)*0.4)}
        XCTAssertEqual(sb_load_sample(e,60,&pcm,96000,48000,12000,90000),1)
        XCTAssertEqual(sb_sample_count(e),1)
        XCTAssertEqual(sb_load_sample(e,61,&pcm,96000,48000,92000,90000),0)
        var out=[Float](repeating:0,count:256)
        sb_controls(e,0.8,0.5,0); sb_note(e,60,0.9)
        var maxJump:Float=0,last:Float=0
        for i in 0..<1200 {
            if i>600 { sb_note(e,60,i%4<2 ? 0.9:0) }
            sb_render(e,&out,256)
            for value in out { maxJump=max(maxJump,abs(value-last)); last=value; XCTAssertTrue(value.isFinite) }
        }
        XCTAssertLessThan(maxJump,0.09)
    }
}
