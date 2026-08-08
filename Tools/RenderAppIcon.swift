import AppKit
import CoreGraphics
import Foundation

// Icon concept: a lightning bolt standing on a row of price-coded bars,
// matching the app's price bands (blue / green / orange / red).

enum Variant { case light, dark, tinted }

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

/// Apple-style squircle (superellipse) inscribed in `rect`.
func squirclePath(in rect: CGRect, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// Lightning bolt in a unit box, y-down; returns a path mapped into `rect`.
func boltPath(in rect: CGRect) -> CGPath {
    let pts: [(CGFloat, CGFloat)] = [
        (0.62, 0.00),
        (0.14, 0.56),
        (0.42, 0.56),
        (0.34, 1.00),
        (0.86, 0.42),
        (0.56, 0.42),
    ]
    let path = CGMutablePath()
    for (i, p) in pts.enumerated() {
        let pt = CGPoint(x: rect.minX + p.0 * rect.width,
                         y: rect.maxY - p.1 * rect.height) // flip to y-up
        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
    }
    path.closeSubpath()
    return path
}

func roundedBar(_ r: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(ctx: CGContext, size: CGFloat, variant: Variant, inset: CGFloat) {
    let full = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.clear(full)

    let plate = full.insetBy(dx: size * inset, dy: size * inset)
    let shape = inset > 0 ? squirclePath(in: plate) : CGPath(rect: full, transform: nil)

    // Background plate. The iOS "dark" variant leaves it transparent so the
    // system's own dark backdrop shows through.
    if variant != .dark {
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        let colors: [CGColor]
        switch variant {
        case .light:  colors = [rgb(0x1D3A63), rgb(0x0A1428)]
        case .tinted: colors = [rgb(0x000000), rgb(0x000000)]
        case .dark:   colors = []
        }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: plate.midX, y: plate.maxY),
                               end: CGPoint(x: plate.midX, y: plate.minY),
                               options: [])
        ctx.restoreGState()
    }

    // Everything lives inside a safe content box so the iOS corner mask
    // never clips the artwork.
    let content = plate.insetBy(dx: plate.width * 0.155, dy: plate.height * 0.155)

    // Price bars along the bottom, left→right cheap→expensive.
    let barColors: [CGColor]
    switch variant {
    case .light, .dark:
        barColors = [rgb(0x4C9AFF), rgb(0x35C759), rgb(0x35C759), rgb(0xFF9F0A), rgb(0xFF453A)]
    case .tinted:
        barColors = (0..<5).map { rgb(0xFFFFFF, 0.55 + 0.09 * CGFloat($0)) }
    }
    let heights: [CGFloat] = [0.11, 0.19, 0.15, 0.25, 0.33]
    let slot = content.width / 5
    let barWidth = slot * 0.60
    for i in 0..<5 {
        let h = content.height * heights[i]
        let r = CGRect(x: content.minX + slot * CGFloat(i) + (slot - barWidth) / 2,
                       y: content.minY, width: barWidth, height: h)
        ctx.addPath(roundedBar(r, radius: barWidth * 0.34))
        ctx.setFillColor(barColors[i])
        ctx.fillPath()
    }

    // Bolt sits above the bars, clear of them.
    let boltHeight = content.height * 0.62
    let boltWidth = boltHeight * 0.78
    let boltRect = CGRect(x: content.midX - boltWidth / 2,
                          y: content.maxY - boltHeight,
                          width: boltWidth,
                          height: boltHeight)
    let bolt = boltPath(in: boltRect)

    ctx.addPath(bolt)
    switch variant {
    case .light, .dark:
        ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [rgb(0xFFE45C), rgb(0xFFAE1A)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g,
                               start: CGPoint(x: boltRect.midX, y: boltRect.maxY),
                               end: CGPoint(x: boltRect.midX, y: boltRect.minY),
                               options: [])
    case .tinted:
        ctx.setFillColor(rgb(0xFFFFFF))
        ctx.fillPath()
    }
}

func render(size: Int, variant: Variant, inset: CGFloat, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.setAllowsAntialiasing(true)
    drawIcon(ctx: ctx, size: CGFloat(size), variant: variant, inset: inset)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Output
//
// Run from the repo root:  swift Tools/RenderAppIcon.swift
// Writes straight into the two AppIcon sets; Contents.json already names these files.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iosSet = root.appendingPathComponent("octopus-menubar/OctopusIOS/Assets.xcassets/AppIcon.appiconset")
let macSet = root.appendingPathComponent("octopus-menubar/octopus-menubar/Assets.xcassets/AppIcon.appiconset")

// iOS: full-bleed square, the system applies the corner mask. The dark variant
// is transparent so iOS composites it over its own dark backdrop.
render(size: 1024, variant: .light, inset: 0, to: iosSet.appendingPathComponent("AppIcon-1024.png"))
render(size: 1024, variant: .dark, inset: 0, to: iosSet.appendingPathComponent("AppIcon-1024-dark.png"))
render(size: 1024, variant: .tinted, inset: 0, to: iosSet.appendingPathComponent("AppIcon-1024-tinted.png"))

// macOS: squircle drawn with the standard ~10% margin.
for (px, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                   (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                   (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                   (1024, "icon_512x512@2x")] {
    render(size: px, variant: .light, inset: 0.098, to: macSet.appendingPathComponent("\(name).png"))
}

print("Rendered app icons.")
