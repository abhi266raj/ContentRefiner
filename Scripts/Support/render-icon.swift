import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
func image(_ size: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size)/1024, y: CGFloat(size)/1024)
    let tile = NSBezierPath(roundedRect: NSRect(x:64,y:64,width:896,height:896),xRadius:200,yRadius:200)
    NSGradient(starting:NSColor(srgbRed:0.20,green:0.27,blue:0.67,alpha:1),ending:NSColor(srgbRed:0.08,green:0.13,blue:0.31,alpha:1))!.draw(in:tile,angle:-45)
    let page = NSBezierPath(); page.move(to:.init(x:300,y:260));page.line(to:.init(x:724,y:260));page.line(to:.init(x:724,y:640));page.line(to:.init(x:600,y:764));page.line(to:.init(x:300,y:764));page.close();NSColor.white.setFill();page.fill()
    let fold = NSBezierPath();fold.move(to:.init(x:600,y:764));fold.line(to:.init(x:600,y:640));fold.line(to:.init(x:724,y:640));fold.close();NSColor(srgbRed:0.72,green:0.78,blue:0.98,alpha:1).setFill();fold.fill()
    NSColor(srgbRed:0.20,green:0.27,blue:0.67,alpha:1).setStroke()
    for (y,end) in [(562,642),(482,598),(402,536)] {let line=NSBezierPath();line.move(to:.init(x:380,y:y));line.line(to:.init(x:end,y:y));line.lineWidth=32;line.lineCapStyle = .round;line.stroke()}
    let star=NSBezierPath();for (i,p) in [(720,486),(744,410),(820,386),(744,362),(720,286),(696,362),(620,386),(696,410)].enumerated(){if i==0{star.move(to:.init(x:p.0,y:p.1))}else{star.line(to:.init(x:p.0,y:p.1))}};star.close();NSColor(srgbRed:0.40,green:0.89,blue:0.82,alpha:1).setFill();star.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let name="icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try image(size*scale).representation(using:.png,properties:[:])!.write(to:destination.appendingPathComponent(name))
    }
}
