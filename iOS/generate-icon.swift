#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText

let size: CGFloat = 1024
let cx: CGFloat = 512, cy: CGFloat = 512
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
) else { fatalError() }

// ============================================================
//  SQUIRCLE CLIP
// ============================================================
let cr: CGFloat = 228
let bgPath = CGMutablePath()
bgPath.addRoundedRect(in: rect, cornerWidth: cr, cornerHeight: cr)
ctx.addPath(bgPath)
ctx.clip()

// ============================================================
//  BACKGROUND — deep cosmic gradient (indigo → midnight → dark teal)
// ============================================================
let bg: [CGFloat] = [
    0.08, 0.04, 0.20, 1,   // rich indigo
    0.04, 0.03, 0.16, 1,   // deep purple
    0.03, 0.06, 0.14, 1,   // midnight blue-teal
    0.02, 0.02, 0.08, 1,   // near-black
]
let bgG = CGGradient(colorSpace: cs, colorComponents: bg, locations: [0, 0.3, 0.65, 1], count: 4)!
ctx.drawLinearGradient(bgG, start: CGPoint(x: 100, y: size), end: CGPoint(x: size - 100, y: 0), options: [])

// Radial warmth — subtle amber center
let warm: [CGFloat] = [0.25, 0.15, 0.05, 0.12, 0.0, 0.0, 0.0, 0.0]
let warmG = CGGradient(colorSpace: cs, colorComponents: warm, locations: [0, 1], count: 2)!
ctx.drawRadialGradient(warmG, startCenter: CGPoint(x: cx - 20, y: cy + 40), startRadius: 0,
                       endCenter: CGPoint(x: cx - 20, y: cy + 40), endRadius: 380, options: [])

// Subtle star field (tiny dots)
func drawStar(at p: CGPoint, r: CGFloat, alpha: CGFloat) {
    ctx.setFillColor(red: 0.9, green: 0.95, blue: 1, alpha: alpha)
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (120, 900, 1.5, 0.3), (280, 950, 1, 0.2), (850, 920, 1.2, 0.25),
    (900, 780, 1, 0.2), (80, 680, 1.3, 0.2), (950, 500, 1, 0.15),
    (70, 350, 1.2, 0.2), (920, 200, 1, 0.2), (180, 150, 1.5, 0.25),
    (750, 120, 1, 0.15), (400, 960, 1, 0.2), (650, 80, 1.2, 0.2),
]
for (x, y, r, a) in stars { drawStar(at: CGPoint(x: x, y: y), r: r, alpha: a) }

// ============================================================
//  ENERGY RINGS — concentric halos
// ============================================================
// Outer ring — faint teal
let ring1: [CGFloat] = [0.1, 0.5, 0.6, 0.0, 0.15, 0.6, 0.5, 0.06, 0.1, 0.4, 0.5, 0.0]
let ring1G = CGGradient(colorSpace: cs, colorComponents: ring1, locations: [0, 0.5, 1], count: 3)!
ctx.drawRadialGradient(ring1G, startCenter: CGPoint(x: cx, y: cy + 20), startRadius: 280,
                       endCenter: CGPoint(x: cx, y: cy + 20), endRadius: 440, options: [])

// Inner ring — warm golden
let ring2: [CGFloat] = [1.0, 0.7, 0.2, 0.0, 1.0, 0.8, 0.3, 0.15, 0.8, 0.5, 0.1, 0.0]
let ring2G = CGGradient(colorSpace: cs, colorComponents: ring2, locations: [0, 0.5, 1], count: 3)!
ctx.drawRadialGradient(ring2G, startCenter: CGPoint(x: cx - 10, y: cy + 30), startRadius: 120,
                       endCenter: CGPoint(x: cx - 10, y: cy + 30), endRadius: 320, options: [])

// Core bloom — bright gold
let bloom: [CGFloat] = [
    1.0, 0.90, 0.50, 0.35,
    1.0, 0.75, 0.30, 0.15,
    0.8, 0.50, 0.15, 0.04,
    0.0, 0.0,  0.0,  0.0,
]
let bloomG = CGGradient(colorSpace: cs, colorComponents: bloom, locations: [0, 0.15, 0.4, 1], count: 4)!
ctx.drawRadialGradient(bloomG, startCenter: CGPoint(x: cx - 15, y: cy + 30), startRadius: 0,
                       endCenter: CGPoint(x: cx - 15, y: cy + 30), endRadius: 280, options: [])

// ============================================================
//  SPARKLES — 4-pointed stars with golden glow
// ============================================================
func drawSparkle(at pos: CGPoint, size s: CGFloat, alpha: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: pos.x, y: pos.y + s))
    path.addLine(to: CGPoint(x: pos.x + s * 0.12, y: pos.y + s * 0.12))
    path.addLine(to: CGPoint(x: pos.x + s, y: pos.y))
    path.addLine(to: CGPoint(x: pos.x + s * 0.12, y: pos.y - s * 0.12))
    path.addLine(to: CGPoint(x: pos.x, y: pos.y - s))
    path.addLine(to: CGPoint(x: pos.x - s * 0.12, y: pos.y + s * 0.12).applying(.init(translationX: 0, y: -2 * s * 0.12)))
    // Simplified: use symmetric 4-point
    let p2 = CGMutablePath()
    p2.move(to: CGPoint(x: pos.x, y: pos.y + s))
    p2.addLine(to: CGPoint(x: pos.x + s * 0.13, y: pos.y + s * 0.13))
    p2.addLine(to: CGPoint(x: pos.x + s, y: pos.y))
    p2.addLine(to: CGPoint(x: pos.x + s * 0.13, y: pos.y - s * 0.13))
    p2.addLine(to: CGPoint(x: pos.x, y: pos.y - s))
    p2.addLine(to: CGPoint(x: pos.x - s * 0.13, y: pos.y - s * 0.13))
    p2.addLine(to: CGPoint(x: pos.x - s, y: pos.y))
    p2.addLine(to: CGPoint(x: pos.x - s * 0.13, y: pos.y + s * 0.13))
    p2.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.6, color: CGColor(red: r, green: g, blue: b, alpha: alpha * 0.8))
    ctx.setFillColor(red: min(1, r + 0.3), green: min(1, g + 0.2), blue: min(1, b + 0.1), alpha: alpha)
    ctx.addPath(p2)
    ctx.fillPath()
    ctx.restoreGState()
}

// Gold sparkles
drawSparkle(at: CGPoint(x: 190, y: 790), size: 20, alpha: 0.7, r: 1, g: 0.85, b: 0.3)
drawSparkle(at: CGPoint(x: 830, y: 730), size: 15, alpha: 0.5, r: 1, g: 0.8, b: 0.2)
drawSparkle(at: CGPoint(x: 760, y: 860), size: 11, alpha: 0.4, r: 0.9, g: 0.7, b: 0.3)
drawSparkle(at: CGPoint(x: 250, y: 280), size: 13, alpha: 0.5, r: 1, g: 0.9, b: 0.4)
drawSparkle(at: CGPoint(x: 810, y: 340), size: 17, alpha: 0.6, r: 1, g: 0.85, b: 0.3)
// Teal sparkles
drawSparkle(at: CGPoint(x: 140, y: 530), size: 9, alpha: 0.35, r: 0.3, g: 0.9, b: 0.8)
drawSparkle(at: CGPoint(x: 880, y: 560), size: 12, alpha: 0.4, r: 0.4, g: 0.85, b: 0.7)
drawSparkle(at: CGPoint(x: 340, y: 880), size: 10, alpha: 0.3, r: 0.3, g: 0.8, b: 0.7)

// ============================================================
//  BOLT — golden-amber metallic with 3D depth
// ============================================================
let bolt: [CGPoint] = [
    CGPoint(x: 430, y: 840),
    CGPoint(x: 625, y: 840),
    CGPoint(x: 548, y: 590),
    CGPoint(x: 700, y: 590),
    CGPoint(x: 400, y: 175),
    CGPoint(x: 490, y: 475),
    CGPoint(x: 340, y: 475),
]
let boltPath = CGMutablePath()
boltPath.addLines(between: bolt)
boltPath.closeSubpath()

// Deep warm shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 55,
              color: CGColor(red: 0.8, green: 0.4, blue: 0, alpha: 0.6))
ctx.setFillColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
ctx.addPath(boltPath)
ctx.fillPath()
ctx.restoreGState()

// Outer glow
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 35, color: CGColor(red: 1, green: 0.75, blue: 0.2, alpha: 0.5))
ctx.setFillColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
ctx.addPath(boltPath)
ctx.fillPath()
ctx.restoreGState()

// Main fill — rich gold gradient
ctx.saveGState()
ctx.addPath(boltPath)
ctx.clip()
let boltC: [CGFloat] = [
    1.0, 0.98, 0.85, 1,    // pale white-gold (tip)
    1.0, 0.92, 0.55, 1,    // bright gold
    1.0, 0.78, 0.20, 1,    // deep amber
    0.95, 0.70, 0.15, 1,   // rich amber
    1.0, 0.85, 0.40, 1,    // warm gold (base)
]
let boltG = CGGradient(colorSpace: cs, colorComponents: boltC, locations: [0, 0.2, 0.5, 0.75, 1], count: 5)!
ctx.drawLinearGradient(boltG, start: CGPoint(x: 400, y: 175), end: CGPoint(x: 580, y: 840), options: [])
ctx.restoreGState()

ctx.addPath(bgPath); ctx.clip()

// Specular highlight — upper face
ctx.saveGState()
let specPath = CGMutablePath()
specPath.move(to: CGPoint(x: 435, y: 835))
specPath.addLine(to: CGPoint(x: 620, y: 835))
specPath.addLine(to: CGPoint(x: 550, y: 595))
specPath.addLine(to: CGPoint(x: 340, y: 475))
specPath.closeSubpath()
ctx.addPath(specPath); ctx.clip()
let specC: [CGFloat] = [1, 1, 1, 0.45, 1, 1, 1, 0.0]
let specG = CGGradient(colorSpace: cs, colorComponents: specC, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(specG, start: CGPoint(x: 430, y: 840), end: CGPoint(x: 500, y: 520), options: [])
ctx.restoreGState()

ctx.addPath(bgPath); ctx.clip()

// Lower face shade
ctx.saveGState()
let shadePath = CGMutablePath()
shadePath.move(to: CGPoint(x: 548, y: 590))
shadePath.addLine(to: CGPoint(x: 700, y: 590))
shadePath.addLine(to: CGPoint(x: 400, y: 175))
shadePath.addLine(to: CGPoint(x: 490, y: 475))
shadePath.closeSubpath()
ctx.addPath(shadePath); ctx.clip()
let shadeC: [CGFloat] = [0, 0, 0, 0.0, 0.2, 0.05, 0, 0.25]
let shadeG = CGGradient(colorSpace: cs, colorComponents: shadeC, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(shadeG, start: CGPoint(x: 700, y: 590), end: CGPoint(x: 420, y: 200), options: [])
ctx.restoreGState()

ctx.addPath(bgPath); ctx.clip()

// Edge glow stroke
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 5, color: CGColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.5))
ctx.setStrokeColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.3)
ctx.setLineWidth(2.5)
ctx.setLineJoin(.round)
ctx.addPath(boltPath)
ctx.strokePath()
ctx.restoreGState()

// ============================================================
//  "2x" BADGE — amber-gold pill with glass effect
// ============================================================
let badgeW: CGFloat = 270
let badgeH: CGFloat = 125
let badgeX: CGFloat = 585
let badgeY: CGFloat = 108
let badgeRect2 = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
let badgeRadius: CGFloat = 40
let badgePath2 = CGPath(roundedRect: badgeRect2, cornerWidth: badgeRadius, cornerHeight: badgeRadius, transform: nil)

// Badge glow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 28,
              color: CGColor(red: 0.9, green: 0.5, blue: 0, alpha: 0.6))
ctx.setFillColor(red: 0.85, green: 0.55, blue: 0.1, alpha: 1)
ctx.addPath(badgePath2)
ctx.fillPath()
ctx.restoreGState()

// Badge fill
ctx.saveGState()
ctx.addPath(badgePath2); ctx.clip()
let badgeC: [CGFloat] = [
    1.0, 0.75, 0.20, 1,    // bright amber top
    0.85, 0.55, 0.10, 1,   // deep amber bottom
]
let badgeG = CGGradient(colorSpace: cs, colorComponents: badgeC, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(badgeG, start: CGPoint(x: badgeX, y: badgeY + badgeH),
                       end: CGPoint(x: badgeX + badgeW, y: badgeY), options: [])
// Glass highlight
let glassC: [CGFloat] = [1, 1, 1, 0.30, 1, 1, 1, 0.0]
let glassG = CGGradient(colorSpace: cs, colorComponents: glassC, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(glassG, start: CGPoint(x: badgeX, y: badgeY + badgeH),
                       end: CGPoint(x: badgeX, y: badgeY + badgeH * 0.4), options: [])
ctx.restoreGState()

ctx.addPath(bgPath); ctx.clip()

// Badge border
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 3, color: CGColor(red: 1, green: 0.8, blue: 0.3, alpha: 0.4))
ctx.setStrokeColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.4)
ctx.setLineWidth(1.5)
ctx.addPath(badgePath2)
ctx.strokePath()
ctx.restoreGState()

// Badge text "2x"
let badgeAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 82, weight: .black),
    .foregroundColor: NSColor.white,
    .kern: -2 as NSNumber,
]
let badgeStr = NSAttributedString(string: "2x", attributes: badgeAttrs)
let badgeLine = CTLineCreateWithAttributedString(badgeStr)
let badgeBounds = CTLineGetBoundsWithOptions(badgeLine, .useOpticalBounds)
let badgeTextX = badgeX + (badgeW - badgeBounds.width) / 2 - badgeBounds.origin.x
let badgeTextY = badgeY + (badgeH - badgeBounds.height) / 2 - badgeBounds.origin.y

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 5,
              color: CGColor(red: 0.5, green: 0.2, blue: 0, alpha: 0.5))
ctx.textPosition = CGPoint(x: badgeTextX, y: badgeTextY)
CTLineDraw(badgeLine, ctx)
ctx.restoreGState()

// ============================================================
//  FINISH — top glass + vignette
// ============================================================
ctx.addPath(bgPath); ctx.clip()

let topC: [CGFloat] = [1, 1, 1, 0.06, 1, 1, 1, 0.0]
let topG = CGGradient(colorSpace: cs, colorComponents: topC, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(topG, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: size - 70),
                       options: [.drawsAfterEndLocation])

let vigC: [CGFloat] = [0, 0, 0, 0.0, 0, 0, 0, 0.25]
let vigG = CGGradient(colorSpace: cs, colorComponents: vigC, locations: [0, 1], count: 2)!
ctx.drawRadialGradient(vigG, startCenter: CGPoint(x: cx, y: cy), startRadius: 320,
                       endCenter: CGPoint(x: cx, y: cy), endRadius: 700, options: [])

// ============================================================
//  OUTPUT
// ============================================================
guard let image = ctx.makeImage() else { fatalError() }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError() }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("Generated: \(out) (1024x1024)")
