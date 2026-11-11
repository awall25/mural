// Original geometric Spain Trip icon, rendered directly into an opaque sRGB bitmap.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, 1])! }
context.setFillColor(color(1, 0.975, 0.933))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(color(1, 0.54, 0.30))
context.fillEllipse(in: CGRect(x: 580, y: 646, width: 202, height: 202))
context.setFillColor(color(0.212, 0.165, 0.133))
context.addPath(CGPath(roundedRect: CGRect(x: 170, y: 240, width: 684, height: 480), cornerWidth: 150, cornerHeight: 150, transform: nil))
context.fillPath()
context.move(to: CGPoint(x: 306, y: 286)); context.addLine(to: CGPoint(x: 294, y: 150)); context.addLine(to: CGPoint(x: 460, y: 270)); context.closePath(); context.fillPath()
context.setStrokeColor(color(1, 0.944, 0.78)); context.setLineWidth(50); context.setLineCap(.round)
context.move(to: CGPoint(x: 403, y: 350)); context.addLine(to: CGPoint(x: 403, y: 488))
context.addCurve(to: CGPoint(x: 621, y: 488), control1: CGPoint(x: 403, y: 636), control2: CGPoint(x: 621, y: 636))
context.addLine(to: CGPoint(x: 621, y: 350)); context.strokePath()
// Catch the blank bitmap failure that caused earlier builds to show a black square.
let pixels = UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: size * size * 4)
precondition(Set(pixels).count > 16, "App icon render is blank")
let image = context.makeImage()!
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination), "Could not write app icon")
print("Rendered opaque 1024 × 1024 Spain Trip icon")
