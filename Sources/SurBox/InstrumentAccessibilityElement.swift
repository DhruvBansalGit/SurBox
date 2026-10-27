import AppKit
import SurBoxCore

// Virtual children make the Metal keyboard inspectable and operable by AX.
// Press toggles an accessible held note; a second press, panic or focus loss
// releases it. Bellows exposes increment/decrement rather than a fake slider.
@MainActor final class InstrumentAccessibilityElement: NSAccessibilityElement {
    weak var view: HarmoniumScene?
    let offset: Int?
    init(view:HarmoniumScene,offset:Int?) {
        self.view=view; self.offset=offset; super.init()
        setAccessibilityParent(view)
        setAccessibilityRole(offset == nil ? .incrementor:.button)
    }
    override func accessibilityLabel()->String? {
        guard let model=view?.model else{return nil}
        if let offset {
            let note=model.settings.firstNote+offset
            return "\(NoteNames.name(note)), \(NoteNames.solfege(note,tonic:model.settings.tonic))"
        }
        return "Hinged bellows"
    }
    override func accessibilityHelp()->String? {
        offset == nil ? "Increment opens, decrement closes; both replenish air." : "Press to hold this note; press again to release. Escape releases all notes."
    }
    override func accessibilityValue()->Any? {
        guard let model=view?.model else{return nil}
        if let offset { return model.notes.active.contains(model.settings.firstNote+offset) ? "Pressed":"Released" }
        return "\(Int(model.bellows.angle*180 / .pi)) degrees"
    }
    override func accessibilityFrame()->NSRect {
        guard let view,let window=view.window else{return .zero}
        let p=offset.flatMap{view.keyPoint(offset:$0)} ?? view.bellowsPoint()
        let point=window.convertPoint(toScreen:view.convert(p,to:nil))
        return NSRect(x:point.x-10,y:point.y-12,width:20,height:24)
    }
    override func accessibilityPerformPress()->Bool {
        guard let model=view?.model,let offset else{return false}
        let source="ax-\(offset)"
        if model.notes.sources[source] != nil { model.release(source) }
        else { model.press(model.settings.firstNote+offset,source:source) }
        return true
    }
    override func accessibilityPerformIncrement()->Bool {
        guard offset == nil,let model=view?.model else{return false}
        model.setBellows(model.bellows.angle+0.12); return true
    }
    override func accessibilityPerformDecrement()->Bool {
        guard offset == nil,let model=view?.model else{return false}
        model.setBellows(model.bellows.angle-0.12); return true
    }
}
