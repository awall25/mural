// Inspect the icon actually packaged in the app, including color data.
import Foundation
import ImageIO
import CoreGraphics
let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
precondition(image.width >= 120 && image.height >= 120, "App icon is too small")
let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
let data = UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4)
precondition(Set(data).count > 16, "Packaged app icon is blank")
print("Verified visible app icon artwork at \(image.width) × \(image.height)")
