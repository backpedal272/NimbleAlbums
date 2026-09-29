// Generates the Nimble Albums app icon: a cream cloud with a Nimble Blue photo
// (mountains and sun) cut into it — "a photo in the cloud".
// Follows the Nimble Icons style guide v2. All colors are sRGB.
// Usage: swift scripts/generate_icon.swift <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let nimbleBlue = CGColor(srgbRed: 0x00 / 255.0, green: 0x9A / 255.0, blue: 0xD6 / 255.0, alpha: 1)
let deepBlue = CGColor(srgbRed: 0x00 / 255.0, green: 0x6C / 255.0, blue: 0xA5 / 255.0, alpha: 1)
let cream = CGColor(srgbRed: 0xFA / 255.0, green: 0xF8 / 255.0, blue: 0xF4 / 255.0, alpha: 1)

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Background: diagonal gradient, Nimble Blue top-left → Deep Blue bottom-right (CG origin is bottom-left).
let gradient = CGGradient(colorsSpace: srgb, colors: [nimbleBlue, deepBlue] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Work on a 512 grid with a top-left origin.
ctx.translateBy(x: 0, y: 1024)
ctx.scaleBy(x: 2, y: -2)

// Cloud: 320 × 200 at (96, 156) — a pill-shaped base plus three bumps, all Cream.
ctx.setFillColor(cream)
ctx.addPath(CGPath(roundedRect: CGRect(x: 96, y: 249.33, width: 320, height: 106.67),
                   cornerWidth: 53.33, cornerHeight: 53.33, transform: nil))
for (cx, cy, r) in [(189.33, 262.67, 64.0), (280.0, 238.67, 82.67), (346.67, 294.67, 53.33)] {
    ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}
ctx.fillPath()

// Photo cut into the cloud, Nimble Blue: two peaks softened with round joins, plus a sun.
let mountains = CGMutablePath()
mountains.addLines(between: [
    CGPoint(x: 181.04, y: 333.36),
    CGPoint(x: 230.72, y: 276.32),
    CGPoint(x: 262.00, y: 307.60),
    CGPoint(x: 295.12, y: 254.24),
    CGPoint(x: 342.96, y: 333.36),
])
mountains.closeSubpath()
ctx.setFillColor(nimbleBlue)
ctx.addPath(mountains)
ctx.fillPath()
ctx.setStrokeColor(nimbleBlue)
ctx.setLineWidth(22.08)
ctx.setLineJoin(.round)
ctx.addPath(mountains)
ctx.strokePath()

ctx.addEllipse(in: CGRect(x: 188.4, y: 221.12, width: 36.8, height: 36.8)) // sun: center (206.8, 239.52), r 18.4
ctx.fillPath()

let url = URL(fileURLWithPath: output)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(output)") }
print("Wrote \(output)")
