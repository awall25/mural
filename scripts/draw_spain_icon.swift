// Reproducible, original geometric app icon for this personal fork.
import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 1, green: 0.975, blue: 0.933, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor(calibratedRed: 1, green: 0.54, blue: 0.30, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 582, y: 646, width: 190, height: 190)).fill()
let bubble = NSBezierPath(roundedRect: NSRect(x: 190, y: 248, width: 644, height: 472), xRadius: 150, yRadius: 150)
NSColor(calibratedRed: 0.212, green: 0.165, blue: 0.133, alpha: 1).setFill()
bubble.fill()
let tail = NSBezierPath()
tail.move(to: NSPoint(x: 316, y: 292)); tail.line(to: NSPoint(x: 300, y: 162)); tail.line(to: NSPoint(x: 456, y: 276)); tail.close(); tail.fill()
NSColor(calibratedRed: 1, green: 0.944, blue: 0.78, alpha: 1).setStroke()
let arch = NSBezierPath()
arch.move(to: NSPoint(x: 407, y: 354)); arch.line(to: NSPoint(x: 407, y: 494))
arch.curve(to: NSPoint(x: 617, y: 494), controlPoint1: NSPoint(x: 407, y: 635), controlPoint2: NSPoint(x: 617, y: 635))
arch.line(to: NSPoint(x: 617, y: 354)); arch.lineWidth = 48; arch.lineCapStyle = .round; arch.stroke()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
