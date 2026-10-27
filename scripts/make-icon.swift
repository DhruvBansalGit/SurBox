import AppKit
import Foundation

let root=URL(fileURLWithPath:CommandLine.arguments[1])
let set=root.appendingPathComponent("Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at:set,withIntermediateDirectories:true)
for (size,name) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
    let image=NSImage(size:NSSize(width:size,height:size)); image.lockFocus()
    let scale=CGFloat(size)/1024
    let transform=NSAffineTransform(); transform.scale(by:scale); transform.concat()
    NSColor(red:0.08,green:0.09,blue:0.09,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:28,y:28,width:968,height:968),xRadius:218,yRadius:218).fill()
    NSColor(red:0.35,green:0.25,blue:0.17,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:172,y:217,width:680,height:440),xRadius:24,yRadius:24).fill()
    for i in 0..<7 {
        NSColor(red:0.42,green:0.49,blue:0.44,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:203,y:508+CGFloat(i)*31,width:618,height:13),xRadius:5,yRadius:5).fill()
    }
    for i in 0..<10 {
        NSColor(red:0.84,green:0.81,blue:0.73,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:200+CGFloat(i)*63,y:251,width:59,height:196),xRadius:5,yRadius:5).fill()
    }
    for i in [0,1,3,4,5,7,8] {
        NSColor(red:0.055,green:0.06,blue:0.06,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:242+CGFloat(i)*63,y:339,width:35,height:116),xRadius:4,yRadius:4).fill()
    }
    image.unlockFocus()
    let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
    try rep.representation(using:.png,properties:[:])!.write(to:set.appendingPathComponent("icon_\(name).png"))
}
