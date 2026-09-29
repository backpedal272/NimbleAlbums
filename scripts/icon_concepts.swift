// Throwaway concept sketches for the Nimble Albums app icon.
// Renders each concept as a 1024 master plus a review sheet (style guide v2, §5).
// Usage: swift scripts/icon_concepts.swift <output-dir>

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let nimbleBlue = CGColor(srgbRed: 0x00 / 255.0, green: 0x9A / 255.0, blue: 0xD6 / 255.0, alpha: 1)
let deepBlue = CGColor(srgbRed: 0x00 / 255.0, green: 0x6C / 255.0, blue: 0xA5 / 255.0, alpha: 1)
let cream = CGColor(srgbRed: 0xFA / 255.0, green: 0xF8 / 255.0, blue: 0xF4 / 255.0, alpha: 1)

// MARK: - Shape helpers (512 grid, top-left origin)

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2), transform: nil)
}

func fill(_ ctx: CGContext, _ color: CGColor, _ paths: [CGPath]) {
    ctx.setFillColor(color)
    for p in paths { ctx.addPath(p); ctx.fillPath() }
}

/// Filled polygon with its corners softened by a round-joined stroke of the same color.
func softPolygon(_ ctx: CGContext, _ color: CGColor, _ pts: [CGPoint], soften: CGFloat) {
    let path = CGMutablePath()
    path.addLines(between: pts)
    path.closeSubpath()
    ctx.setFillColor(color)
    ctx.addPath(path); ctx.fillPath()
    ctx.setStrokeColor(color)
    ctx.setLineWidth(soften)
    ctx.setLineJoin(.round)
    ctx.addPath(path); ctx.strokePath()
}

func stroke(_ ctx: CGContext, _ color: CGColor, width: CGFloat, _ pts: [CGPoint]) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addLines(between: pts)
    ctx.strokePath()
}

/// A cloud built from a pill-shaped base and three bumps. `x, y` = top-left of the bounding box, `w` = width.
func cloud(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> [CGPath] {
    let s = w / 240 // designed at 240 wide, 150 tall
    return [
        roundedRect(x, y + 70 * s, 240 * s, 80 * s, 40 * s),
        circle(x + 70 * s, y + 80 * s, 48 * s),
        circle(x + 138 * s, y + 62 * s, 62 * s),
        circle(x + 188 * s, y + 104 * s, 40 * s),
    ]
}

/// Mountain range + sun, the family's photo glyph (as in the existing tag icon).
func mountains(_ ctx: CGContext, _ color: CGColor, x: CGFloat, y: CGFloat, w: CGFloat, sun: Bool = true) {
    let s = w / 200 // designed at 200 wide, 120 tall, bottom at y + 120
    softPolygon(ctx, color, [
        CGPoint(x: x + 12 * s, y: y + 108 * s),
        CGPoint(x: x + 66 * s, y: y + 46 * s),
        CGPoint(x: x + 100 * s, y: y + 80 * s),
        CGPoint(x: x + 136 * s, y: y + 22 * s),
        CGPoint(x: x + 188 * s, y: y + 108 * s),
    ], soften: 24 * s)
    if sun { fill(ctx, color, [circle(x + 40 * s, y + 6 * s, 20 * s)]) }
}

/// A chunkier two-bump cloud, closer to the Nimble Bot bubble's proportions. Designed at 240 wide, 160 tall.
func roundCloud(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> [CGPath] {
    let s = w / 240
    return [
        roundedRect(x, y + 64 * s, 240 * s, 96 * s, 48 * s),
        circle(x + 82 * s, y + 88 * s, 60 * s),
        circle(x + 160 * s, y + 72 * s, 72 * s),
    ]
}

/// Fill `paths` with the background gradient, i.e. a true cut-out through the mark.
func knockout(_ ctx: CGContext, _ paths: [CGPath]) {
    ctx.saveGState()
    for p in paths { ctx.addPath(p) }
    ctx.clip()
    let gradient = CGGradient(colorsSpace: srgb, colors: [nimbleBlue, deepBlue] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 512, y: 512), options: [])
    ctx.restoreGState()
}

func polygonPath(_ pts: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: pts)
    path.closeSubpath()
    return path
}

// MARK: - Concepts

struct Concept {
    let id: String
    let caption: String
    let draw: (CGContext) -> Void
}

let allConcepts: [Concept] = [
    Concept(id: "A", caption: "A · a cloud in a photo (cream card, blue cloud)") { ctx in
        fill(ctx, cream, [roundedRect(96, 116, 320, 280, 80)])
        fill(ctx, nimbleBlue, cloud(156, 180, 200))
    },
    Concept(id: "B", caption: "B · a cloud in a picture frame (cream frame + cloud)") { ctx in
        fill(ctx, cream, [roundedRect(96, 116, 320, 280, 80)])
        fill(ctx, nimbleBlue, [roundedRect(144, 164, 224, 184, 36)])
        fill(ctx, cream, cloud(176, 200, 160))
    },
    Concept(id: "C", caption: "C · a photo that lives in the cloud (cloud with a photo)") { ctx in
        fill(ctx, cream, cloud(96, 156, 320))
        mountains(ctx, nimbleBlue, x: 182, y: 244, w: 160)
    },
    Concept(id: "C1", caption: "C1 · refined: larger photo, optically centered") { ctx in
        fill(ctx, cream, cloud(96, 156, 320))
        mountains(ctx, nimbleBlue, x: 170, y: 234, w: 184)
    },
    Concept(id: "C2", caption: "C2 · horizon: mountains cut out of the cloud's base") { ctx in
        let c = cloud(96, 156, 320)
        fill(ctx, cream, c)
        ctx.saveGState()
        for p in c { ctx.addPath(p) }
        ctx.clip()
        // peaks rise from below the cloud's bottom edge, so the landscape opens onto the background
        let peaks = polygonPath([
            CGPoint(x: 164, y: 390), CGPoint(x: 232, y: 296), CGPoint(x: 264, y: 326),
            CGPoint(x: 310, y: 262), CGPoint(x: 388, y: 390),
        ])
        knockout(ctx, [peaks.union(peaks.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 10))])
        ctx.restoreGState()
        knockout(ctx, [circle(198, 252, 22)])
    },
    Concept(id: "C3", caption: "C3 · bold: two big peaks, no sun (best at 16 px)") { ctx in
        fill(ctx, cream, cloud(96, 156, 320))
        mountains(ctx, nimbleBlue, x: 162, y: 226, w: 200, sun: false)
    },
    Concept(id: "C4", caption: "C4 · rounder, chunkier cloud (Nimble Bot proportions)") { ctx in
        fill(ctx, cream, roundCloud(96, 150, 320))
        mountains(ctx, nimbleBlue, x: 172, y: 250, w: 176)
    },
    Concept(id: "C5", caption: "C5 · minimal: one peak and a sun") { ctx in
        fill(ctx, cream, cloud(96, 156, 320))
        softPolygon(ctx, nimbleBlue, [
            CGPoint(x: 190, y: 322), CGPoint(x: 272, y: 232), CGPoint(x: 354, y: 322),
        ], soften: 28)
        fill(ctx, nimbleBlue, [circle(202, 250, 24)])
    },
    Concept(id: "D", caption: "D · a photo coming down from the cloud") { ctx in
        fill(ctx, cream, [roundedRect(96, 116, 320, 280, 80)])
        fill(ctx, nimbleBlue, cloud(146, 170, 220))
        stroke(ctx, cream, width: 32, [CGPoint(x: 272, y: 232), CGPoint(x: 272, y: 282)])
        stroke(ctx, cream, width: 32, [CGPoint(x: 246, y: 262), CGPoint(x: 272, y: 288), CGPoint(x: 298, y: 262)])
    },
    Concept(id: "E", caption: "E · your photos as a folder") { ctx in
        // folder: tab + body
        fill(ctx, cream, [
            roundedRect(96, 128, 150, 100, 36),
            roundedRect(96, 160, 320, 236, 72),
            roundedRect(96, 160, 80, 120, 0),
        ])
        mountains(ctx, nimbleBlue, x: 156, y: 222, w: 200)
    },
]

// MARK: - Rendering

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

func renderMaster(_ concept: Concept) -> CGImage {
    let ctx = makeContext(1024, 1024)
    let gradient = CGGradient(colorsSpace: srgb, colors: [nimbleBlue, deepBlue] as CFArray, locations: [0, 1])!
    // CG origin is bottom-left: top-left is (0, 1024)
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 2, y: -2)
    concept.draw(ctx)
    return ctx.makeImage()!
}

func downscale(_ image: CGImage, to size: Int) -> CGImage {
    let ctx = makeContext(size, size)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

/// Draw an icon at `rect` with an approximate macOS squircle mask (preview only).
func drawMasked(_ ctx: CGContext, _ image: CGImage, _ rect: CGRect, nearest: Bool = false) {
    ctx.saveGState()
    let r = rect.width * 0.225
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = nearest ? .none : .high
    ctx.draw(image, in: rect)
    ctx.restoreGState()
}

func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat) {
    let font = CTFontCreateWithName("Helvetica Neue" as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0.2, green: 0.2, blue: 0.22, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let only = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let concepts = allConcepts.filter { only.isEmpty || ($0.id.hasPrefix(only) && $0.id.count > only.count) }
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// Review sheet: one row per concept — 320 preview, 128, 32, 16, and 16 blown up ×4 (nearest) to judge it.
let rowH = 400, sheetW = 1100
let sheet = makeContext(sheetW, rowH * concepts.count + 40)
sheet.setFillColor(CGColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheet.height))

for (i, concept) in concepts.enumerated() {
    let master = renderMaster(concept)
    writePNG(master, outDir.appendingPathComponent("concept-\(concept.id).png"))

    let top = CGFloat(sheet.height - 20 - rowH * i) // CG y of the row's top edge
    let base = top - 360
    drawMasked(sheet, master, CGRect(x: 40, y: base, width: 320, height: 320))
    drawMasked(sheet, downscale(master, to: 128), CGRect(x: 400, y: base + 96, width: 128, height: 128))
    drawMasked(sheet, downscale(master, to: 32), CGRect(x: 568, y: base + 144, width: 32, height: 32))
    let tiny = downscale(master, to: 16)
    drawMasked(sheet, tiny, CGRect(x: 640, y: base + 152, width: 16, height: 16))
    drawMasked(sheet, tiny, CGRect(x: 700, y: base + 96, width: 128, height: 128), nearest: true)
    drawText(sheet, concept.caption, x: 400, y: base + 290, size: 22)
    drawText(sheet, "128        32     16           16 px enlarged", x: 400, y: base + 60, size: 14)
}

writePNG(sheet.makeImage()!, outDir.appendingPathComponent(only.isEmpty ? "review-sheet.png" : "review-sheet-\(only).png"))
print("Wrote \(concepts.count) concepts + review sheet to \(outDir.path)")
