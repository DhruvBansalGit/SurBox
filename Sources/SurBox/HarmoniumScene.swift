import AppKit
import SceneKit
import SwiftUI
import SurBoxCore

// Visual musical instrument, not fabrication CAD. Scene units use mm-like
// proportions chosen for this interface. Rear bellows has a stationary X-axis
// hinge, a rigid top leaf and twelve individually articulated cloth pleats.
@MainActor final class HarmoniumScene: SCNView {
    weak var model: InstrumentModel?
    let hinge = SCNNode()
    let foldRoot = SCNNode()
    private(set) var keys: [Int: SCNNode] = [:]
    private var labels: [Int: SCNNode] = [:]
    private var foldNodes: [SCNNode] = []
    private var computerHeld = Set<UInt16>()
    private var dragStart: CGPoint?
    private var dragAngle = 0.0
    private var dragSlope = CGPoint.zero
    private var pointerKey = false
    private var tracking: NSTrackingArea?
    private var previousNoteState = ""
    private var previousLabelState = ""
    private var previousActive = Set<Int>()
    private var accessibleElements: [InstrumentAccessibilityElement] = []
    private let ivory = NSColor(red: 0.83, green: 0.80, blue: 0.71, alpha: 1)
    private let ebony = NSColor(red: 0.035, green: 0.039, blue: 0.039, alpha: 1)
    override var acceptsFirstResponder: Bool { true }
    init(model: InstrumentModel) {
        self.model = model
        super.init(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        scene = SCNScene(); backgroundColor = NSColor(red: 0.055, green: 0.060, blue: 0.063, alpha: 1)
        antialiasingMode = .multisampling4X; preferredFramesPerSecond = 60
        allowsCameraControl = false; autoenablesDefaultLighting = false
        isPlaying = true; rendersContinuously = false
        setAccessibilityElement(true); setAccessibilityRole(.group)
        setAccessibilityLabel("Harmonium keyboard and hinged bellows")
        setAccessibilityHelp("Drag the rear wood panel upward to open and downward to close. A through quote play notes. Hold Space to pump. Escape releases all notes.")
        buildScene(); model.scene = self; buildAccessibility(); updateBellows(); updateNotes()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    private func material(_ color: NSColor, roughness: CGFloat = 0.7) -> SCNMaterial {
        let m=SCNMaterial(); m.diffuse.contents=color; m.roughness.contents=roughness; m.metalness.contents=0.0; m.lightingModel = .physicallyBased; return m
    }
    private lazy var wood: SCNMaterial = {
        let image = NSImage(size: NSSize(width: 1024, height: 256))
        image.lockFocus(); NSColor(red: 0.29, green: 0.20, blue: 0.135, alpha: 1).setFill(); NSRect(x:0,y:0,width:1024,height:256).fill()
        // Original restrained grain texture, generated once, no network assets.
        for i in 0..<170 {
            let y=CGFloat(i)*1.52
            NSColor(white: i%3==0 ? 0.75 : 0.06, alpha: i%3==0 ? 0.055 : 0.13).setStroke()
            let path=NSBezierPath(); path.lineWidth = i%4==0 ? 1.2 : 0.5
            path.move(to: NSPoint(x:0,y:y)); path.curve(to: NSPoint(x:1024,y:y+3), controlPoint1:NSPoint(x:330,y:y+CGFloat(i%7)-3), controlPoint2:NSPoint(x:670,y:y-CGFloat(i%5)))
            path.stroke()
        }
        image.unlockFocus()
        let m=material(.brown); m.diffuse.contents=image; m.roughness.contents=0.58; return m
    }()
    @discardableResult private func box(_ size: SCNVector3, _ pos: SCNVector3, _ mat: SCNMaterial, chamfer: CGFloat=1.2, name: String?=nil, parent: SCNNode?=nil) -> SCNNode {
        let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:chamfer)
        g.materials=[mat]; let n=SCNNode(geometry:g); n.position=pos; n.name=name; (parent ?? scene!.rootNode).addChildNode(n); return n
    }
    private func buildScene() {
        let root=scene!.rootNode
        let camera=SCNNode(); camera.camera=SCNCamera(); camera.camera!.fieldOfView=28; camera.camera!.zNear=10; camera.camera!.zFar=4000
        camera.camera!.wantsHDR=false
        camera.position=SCNVector3(180,480,1000); camera.look(at:SCNVector3(0,105,28)); root.addChildNode(camera); pointOfView=camera
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light!.type = .ambient; ambient.light!.color=NSColor(white:0.75,alpha:1); ambient.light!.intensity=460; root.addChildNode(ambient)
        let key=SCNNode(); key.light=SCNLight(); key.light!.type = .directional; key.light!.intensity=1050; key.light!.castsShadow=true; key.light!.shadowMode = .deferred
        key.light!.shadowColor=NSColor(white:0,alpha:0.45); key.light!.shadowRadius=5; key.light!.shadowMapSize=CGSize(width:2048,height:2048)
        key.eulerAngles=SCNVector3(-0.85,-0.6,-0.2); root.addChildNode(key)
        box(SCNVector3(18000,8,18000),SCNVector3(0,-12,0),material(NSColor(white:0.023,alpha:1)),chamfer:0)
        box(SCNVector3(610,78,382),SCNVector3(0,39,32),wood,chamfer:5,name:"body")
        box(SCNVector3(596,8,370),SCNVector3(0,82,32),material(NSColor(white:0.07,alpha:1)),chamfer:2)
        box(SCNVector3(610,12,20),SCNVector3(0,90,218),wood,chamfer:2)
        box(SCNVector3(18,65,370),SCNVector3(-296,104,32),wood,chamfer:2)
        box(SCNVector3(18,65,370),SCNVector3(296,104,32),wood,chamfer:2)
        box(SCNVector3(580,50,218),SCNVector3(0,107,-53),wood,chamfer:2,name:"soundboard")
        box(SCNVector3(577,6,214),SCNVector3(0,135,-53),material(NSColor(white:0.065,alpha:1)),chamfer:1)
        // Front register rail and small, non-interactive traditional stop knobs.
        box(SCNVector3(574,26,25),SCNVector3(0,108,68),wood,chamfer:2)
        for x in [-218,-177,177,218] {
            let g=SCNCylinder(radius:6,height:11); g.materials=[material(NSColor(red:0.48,green:0.43,blue:0.32,alpha:1),roughness:0.4)]
            let n=SCNNode(geometry:g); n.eulerAngles.x = .pi/2; n.position=SCNVector3(x,110,86); root.addChildNode(n)
        }
        addText("SURBOX", at:SCNVector3(-28,110,81), size:7, color:NSColor(white:0.74,alpha:1), flat:false, parent:root)
        hinge.position=SCNVector3(0,140,-150); hinge.name="bellows"; root.addChildNode(hinge)
        foldRoot.position=hinge.position; root.addChildNode(foldRoot)
        box(SCNVector3(577,9,208),SCNVector3(0,0,104),wood,chamfer:2,name:"bellows",parent:hinge)
        box(SCNVector3(531,1.5,155),SCNVector3(0,5,104),material(NSColor(red:0.105,green:0.12,blue:0.115,alpha:1)),chamfer:2,name:"bellows",parent:hinge)
        for x in [-182,0,182] { box(SCNVector3(5,3,155),SCNVector3(x,7,104),wood,chamfer:1,name:"bellows",parent:hinge) }
        box(SCNVector3(115,8,13),SCNVector3(0,10,192),wood,chamfer:3,name:"bellows",parent:hinge)
        for x in [-225,225] { box(SCNVector3(27,5,24),SCNVector3(x,143,-148),material(NSColor(red:0.33,green:0.31,blue:0.25,alpha:1)),chamfer:1) }
        for i in 0..<24 {
            let n=SCNNode(); n.name="bellows"; foldRoot.addChildNode(n); foldNodes.append(n)
            let m=material(NSColor(red:i%2==0 ? 0.235:0.135,green:i%2==0 ? 0.255:0.15,blue:i%2==0 ? 0.23:0.135,alpha:1)); m.isDoubleSided=true
            n.geometry=SCNGeometry(); n.geometry!.materials=[m]
        }
        let naturals=(0..<37).filter { ![1,3,6,8,10].contains($0%12) }
        let width:Float=560/Float(naturals.count)
        for (i,n) in naturals.enumerated() {
            let x = -280+width*(Float(i)+0.5)
            let node=box(SCNVector3(width-1.1,13,130),SCNVector3(x,96,148),material(ivory),chamfer:1.4,name:"key-\(n)")
            keys[n]=node
            let label=addText("",at:SCNVector3(-7,7,48),size:7,color:NSColor(white:0.27,alpha:1),flat:true,parent:node)
            labels[n]=label
        }
        var whiteIndex = 0
        for n in 0..<37 {
            if naturals.contains(n) { whiteIndex += 1; continue }
            let x = -280+width*Float(whiteIndex)
            let node=box(SCNVector3(width*0.61,21,78),SCNVector3(x,111,122),material(ebony,roughness:0.44),chamfer:1.5,name:"key-\(n)")
            keys[n]=node
        }
    }
    @discardableResult private func addText(_ text:String, at:SCNVector3, size:CGFloat, color:NSColor, flat:Bool, parent:SCNNode)->SCNNode {
        let g=SCNText(string:text,extrusionDepth:0.02); g.font=NSFont.systemFont(ofSize:size,weight:.medium); g.flatness=0.4; g.materials=[material(color)]
        let n=SCNNode(geometry:g); n.position=at; if flat { n.eulerAngles.x = -.pi/2 }; parent.addChildNode(n); return n
    }
    func updateBellows() {
        guard let m=model else { return }
        SCNTransaction.begin(); SCNTransaction.animationDuration=0
        hinge.eulerAngles.x = CGFloat(-m.bellows.angle)
        // A fan-like side gusset and a full-width pleated end close the wedge.
        for i in 0..<24 {
            let a=m.bellows.angle*Double(i)/24, b=m.bellows.angle*Double(i+1)/24
            let ra:Double=i%2==0 ? 204:194, rb:Double=(i+1)%2==0 ? 204:194
            func p(_ x:Double,_ r:Double,_ t:Double)->SCNVector3 { SCNVector3(x,r*sin(t)-3,r*cos(t)) }
            let xa:Double=i%2==0 ? 284:277, xb:Double=(i+1)%2==0 ? 284:277
            let vertices=[p(-xa,ra,a),p(xa,ra,a),p(xb,rb,b),p(-xb,rb,b),p(-277,8,a),p(-277,8,b),p(277,8,a),p(277,8,b)]
            let indices:[Int32]=[0,1,2,0,2,3,4,0,3,4,3,5,1,6,7,1,7,2]
            let mat=foldNodes[i].geometry!.materials
            let geo=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)]); geo.materials=mat; foldNodes[i].geometry=geo
        }
        SCNTransaction.commit(); needsDisplay=true
    }
    func updateNotes() {
        guard let m=model else { return }
        let signature="\(m.notes.active.sorted())-\(m.settings.firstNote)-\(m.settings.tonic)-\(m.settings.scale)"
        guard signature != previousNoteState else { return }; previousNoteState=signature
        let labelState="\(m.settings.firstNote)-\(m.settings.tonic)-\(m.settings.scale)"
        let changedLabels=labelState != previousLabelState
        let active=m.notes.active
        SCNTransaction.begin(); SCNTransaction.animationDuration=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.045
        for (offset,node) in keys {
            let midi=m.settings.firstNote+offset
            let black=[1,3,6,8,10].contains(offset%12), pressed=active.contains(midi)
            if changedLabels || previousActive.contains(midi) != pressed {
                node.position.y = CGFloat((black ? 111 : 96) - (pressed ? 3 : 0))
                node.eulerAngles.x = pressed ? 0.014 : 0
                node.geometry?.firstMaterial?.diffuse.contents=pressed ? NSColor(red:0.44,green:0.51,blue:0.46,alpha:1) : (black ? ebony:ivory)
            }
            // Never regenerate text meshes during note events.
            if changedLabels, let label=labels[offset]?.geometry as? SCNText {
                label.string=NoteNames.solfege(midi,tonic:m.settings.tonic)+"\n"+NoteNames.western[midi%12]
                label.firstMaterial?.diffuse.contents=m.settings.isInScale(midi) ? NSColor(white:0.27,alpha:1):NSColor(white:0.57,alpha:1)
            }
        }
        previousActive=active; previousLabelState=labelState
        SCNTransaction.commit(); needsDisplay=true
    }
    func cancelPointer() { dragStart=nil; pointerKey=false; computerHeld.removeAll() }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking=NSTrackingArea(rect:bounds,options:[.activeInKeyWindow,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil); addTrackingArea(tracking!); super.updateTrackingAreas()
    }
    private func hit(_ point:CGPoint)->String? {
        for h in hitTest(point,options:[.searchMode:SCNHitTestSearchMode.all.rawValue]) {
            var n:SCNNode?=h.node
            while let node=n {
                if let name=node.name, name=="bellows" || name.hasPrefix("key-") { return name }; n=node.parent
            }
        }
        return nil
    }
    override func mouseMoved(with event:NSEvent) {
        let target=hit(convert(event.locationInWindow,from:nil))
        if target=="bellows" { NSCursor.openHand.set() } else if target?.hasPrefix("key-")==true { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
    }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self)
        let p=convert(event.locationInWindow,from:nil)
        if hit(p)=="bellows", let m=model {
            dragStart=p; dragAngle=m.bellows.angle; m.pumping=true; NSCursor.closedHand.set()
            let h=hinge.position
            func projected(_ a:Double)->SCNVector3 { projectPoint(SCNVector3(0,Double(h.y)+204*sin(a),Double(h.z)+204*cos(a))) }
            let p0=projected(dragAngle), p1=projected(dragAngle+0.02)
            dragSlope=CGPoint(x:Double(p1.x-p0.x)/0.02,y:Double(p1.y-p0.y)/0.02)
        } else { pointerKey=true; playPointer(p) }
    }
    override func mouseDragged(with event:NSEvent) {
        let p=convert(event.locationInWindow,from:nil)
        if let start=dragStart {
            let denom=max(1000,dragSlope.x*dragSlope.x+dragSlope.y*dragSlope.y)
            let delta=((p.x-start.x)*dragSlope.x+(p.y-start.y)*dragSlope.y)/denom
            model?.setBellows(dragAngle+Double(delta))
            // Do not accumulate overshoot: reversing at either hard stop must
            // move immediately, not traverse an invisible pointer dead zone.
            if model?.bellows.atLimit == true {
                dragStart=p; dragAngle=model!.bellows.angle
            }
        } else if pointerKey { playPointer(p) }
    }
    override func mouseUp(with event:NSEvent) { dragStart=nil; pointerKey=false; model?.pumping=false; model?.release("pointer"); NSCursor.arrow.set() }
    private func playPointer(_ p:CGPoint) {
        if let name=hit(p), name.hasPrefix("key-"), let offset=Int(name.dropFirst(4)), let m=model { m.press(m.settings.firstNote+offset,source:"pointer") } else { model?.release("pointer") }
    }
    override func keyDown(with event:NSEvent) {
        if event.modifierFlags.intersection([.command,.control,.option]).isEmpty == false { super.keyDown(with:event); return }
        if event.isARepeat { return }
        if let offset=ComputerKeys.offsets[event.keyCode], let m=model { computerHeld.insert(event.keyCode); m.press(m.settings.firstNote+offset,source:"key-\(event.keyCode)"); return }
        switch event.keyCode {
        case 49: model?.beginPump()
        case 53: model?.deactivate(); model?.suspended=false
        case 123: model?.shiftOctave(-1)
        case 124: model?.shiftOctave(1)
        default: super.keyDown(with:event)
        }
    }
    override func keyUp(with event:NSEvent) {
        if computerHeld.remove(event.keyCode) != nil { model?.release("key-\(event.keyCode)") }
        if event.keyCode==49 { model?.endPump() }
    }
    override func becomeFirstResponder()->Bool { needsDisplay=true; return super.becomeFirstResponder() }
    override func resignFirstResponder()->Bool { model?.deactivate(); model?.suspended=false; needsDisplay=true; return super.resignFirstResponder() }
    override func accessibilityChildren()->[Any]? { accessibleElements }
    private func buildAccessibility() {
        accessibleElements=(0..<37).map { InstrumentAccessibilityElement(view:self,offset:$0) }
        accessibleElements.append(InstrumentAccessibilityElement(view:self,offset:nil))
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { DispatchQueue.main.async { [weak self] in guard let self else{return}; self.window?.makeFirstResponder(self) } }
    }
    func keyPoint(offset:Int)->CGPoint? {
        guard let n=keys[offset] else{return nil}
        let p=projectPoint(n.convertPosition(SCNVector3(0,8,45),to:nil)); return CGPoint(x:CGFloat(p.x),y:CGFloat(p.y))
    }
    func bellowsPoint()->CGPoint { let p=projectPoint(hinge.convertPosition(SCNVector3(60,10,180),to:nil)); return CGPoint(x:CGFloat(p.x),y:CGFloat(p.y)) }
}

struct HarmoniumViewport: NSViewRepresentable {
    let model: InstrumentModel
    func makeNSView(context:Context)->HarmoniumScene { HarmoniumScene(model:model) }
    func updateNSView(_ view:HarmoniumScene,context:Context) {}
}
