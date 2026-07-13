import AppKit

guard CommandLine.arguments.count == 2 else { exit(2) }
let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: 36, dy: 36), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.03, green: 0.34, blue: 0.48, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.68, blue: 0.62, alpha: 1)
])!
gradient.draw(in: outer, angle: -35)

NSColor.white.withAlphaComponent(0.22).setStroke()
for radius in [145.0, 270.0, 395.0] {
    let ring = NSBezierPath(ovalIn: NSRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 18
    ring.stroke()
}

let sweep = NSBezierPath()
sweep.move(to: NSPoint(x: 512, y: 512))
sweep.line(to: NSPoint(x: 850, y: 690))
sweep.lineWidth = 22
sweep.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.48).setStroke()
sweep.stroke()

let plane = NSBezierPath()
plane.move(to: NSPoint(x: 512, y: 815))
plane.line(to: NSPoint(x: 565, y: 590))
plane.line(to: NSPoint(x: 795, y: 455))
plane.line(to: NSPoint(x: 775, y: 385))
plane.line(to: NSPoint(x: 558, y: 470))
plane.line(to: NSPoint(x: 535, y: 300))
plane.line(to: NSPoint(x: 620, y: 220))
plane.line(to: NSPoint(x: 597, y: 180))
plane.line(to: NSPoint(x: 512, y: 215))
plane.line(to: NSPoint(x: 427, y: 180))
plane.line(to: NSPoint(x: 404, y: 220))
plane.line(to: NSPoint(x: 489, y: 300))
plane.line(to: NSPoint(x: 466, y: 470))
plane.line(to: NSPoint(x: 249, y: 385))
plane.line(to: NSPoint(x: 229, y: 455))
plane.line(to: NSPoint(x: 459, y: 590))
plane.close()
NSColor.white.setFill()
plane.fill()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: output))
