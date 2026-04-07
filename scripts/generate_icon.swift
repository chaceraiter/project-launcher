#!/usr/bin/env swift

import AppKit
import Foundation

struct Palette {
    static let skyTop = NSColor(red: 0.55, green: 0.82, blue: 0.98, alpha: 1.0)
    static let skyBottom = NSColor(red: 0.90, green: 0.97, blue: 1.0, alpha: 1.0)
    static let sun = NSColor(red: 1.0, green: 0.93, blue: 0.66, alpha: 1.0)
    static let grass = NSColor(red: 0.60, green: 0.84, blue: 0.50, alpha: 1.0)
    static let hill = NSColor(red: 0.48, green: 0.73, blue: 0.43, alpha: 1.0)
    static let wood = NSColor(red: 0.66, green: 0.46, blue: 0.24, alpha: 1.0)
    static let woodDark = NSColor(red: 0.40, green: 0.27, blue: 0.14, alpha: 1.0)
    static let rope = NSColor(red: 0.95, green: 0.84, blue: 0.64, alpha: 1.0)
    static let stone = NSColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1.0)
    static let cloud = NSColor.white.withAlphaComponent(0.78)
    static let white = NSColor.white
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.stroke()
}

func drawCloud(x: CGFloat, y: CGFloat, scale: CGFloat) {
    let puffs = [
        CGRect(x: x, y: y, width: 92 * scale, height: 54 * scale),
        CGRect(x: x + 46 * scale, y: y + 18 * scale, width: 82 * scale, height: 52 * scale),
        CGRect(x: x + 92 * scale, y: y, width: 94 * scale, height: 56 * scale),
    ]

    for puff in puffs {
        fill(NSBezierPath(ovalIn: puff), color: Palette.cloud)
    }

    let base = roundedRect(
        CGRect(x: x + 26 * scale, y: y + 6 * scale, width: 126 * scale, height: 34 * scale),
        radius: 17 * scale
    )
    fill(base, color: Palette.cloud)
}

func drawTrebuchet() {
    let wheelLeft = NSBezierPath(ovalIn: CGRect(x: 290, y: 214, width: 94, height: 94))
    let wheelRight = NSBezierPath(ovalIn: CGRect(x: 460, y: 214, width: 94, height: 94))
    fill(wheelLeft, color: Palette.woodDark)
    fill(wheelRight, color: Palette.woodDark)
    fill(NSBezierPath(ovalIn: CGRect(x: 316, y: 240, width: 42, height: 42)), color: Palette.sun)
    fill(NSBezierPath(ovalIn: CGRect(x: 486, y: 240, width: 42, height: 42)), color: Palette.sun)

    let base = roundedRect(CGRect(x: 246, y: 284, width: 356, height: 36), radius: 18)
    fill(base, color: Palette.woodDark)

    let legLeft = NSBezierPath()
    legLeft.move(to: CGPoint(x: 314, y: 300))
    legLeft.line(to: CGPoint(x: 404, y: 624))
    legLeft.line(to: CGPoint(x: 444, y: 612))
    legLeft.line(to: CGPoint(x: 352, y: 294))
    legLeft.close()
    fill(legLeft, color: Palette.wood)

    let legRight = NSBezierPath()
    legRight.move(to: CGPoint(x: 534, y: 302))
    legRight.line(to: CGPoint(x: 440, y: 624))
    legRight.line(to: CGPoint(x: 482, y: 638))
    legRight.line(to: CGPoint(x: 574, y: 314))
    legRight.close()
    fill(legRight, color: Palette.wood)

    let topBeam = roundedRect(CGRect(x: 372, y: 592, width: 144, height: 32), radius: 16)
    fill(topBeam, color: Palette.woodDark)

    let braceLeft = NSBezierPath()
    braceLeft.move(to: CGPoint(x: 342, y: 310))
    braceLeft.line(to: CGPoint(x: 426, y: 494))
    braceLeft.line(to: CGPoint(x: 452, y: 482))
    braceLeft.line(to: CGPoint(x: 368, y: 302))
    braceLeft.close()
    fill(braceLeft, color: Palette.woodDark)

    let braceRight = NSBezierPath()
    braceRight.move(to: CGPoint(x: 566, y: 314))
    braceRight.line(to: CGPoint(x: 488, y: 496))
    braceRight.line(to: CGPoint(x: 514, y: 508))
    braceRight.line(to: CGPoint(x: 592, y: 326))
    braceRight.close()
    fill(braceRight, color: Palette.woodDark)

    let pivot = NSBezierPath(ovalIn: CGRect(x: 424, y: 572, width: 48, height: 48))
    fill(pivot, color: Palette.sun)
    fill(NSBezierPath(ovalIn: CGRect(x: 438, y: 586, width: 20, height: 20)), color: Palette.woodDark)

    let throwingArm = NSBezierPath()
    throwingArm.move(to: CGPoint(x: 448, y: 594))
    throwingArm.curve(
        to: CGPoint(x: 740, y: 744),
        controlPoint1: CGPoint(x: 560, y: 654),
        controlPoint2: CGPoint(x: 654, y: 708)
    )
    stroke(throwingArm, color: Palette.woodDark, width: 30)

    let counterArm = NSBezierPath()
    counterArm.move(to: CGPoint(x: 446, y: 592))
    counterArm.line(to: CGPoint(x: 310, y: 502))
    stroke(counterArm, color: Palette.woodDark, width: 24)

    let counterWeight = roundedRect(CGRect(x: 236, y: 404, width: 120, height: 120), radius: 28)
    fill(counterWeight, color: Palette.wood)
    stroke(counterWeight, color: Palette.white.withAlphaComponent(0.25), width: 4)

    let weightStrap = roundedRect(CGRect(x: 286, y: 496, width: 22, height: 46), radius: 10)
    fill(weightStrap, color: Palette.woodDark)

    let slingLeft = NSBezierPath()
    slingLeft.move(to: CGPoint(x: 736, y: 742))
    slingLeft.line(to: CGPoint(x: 820, y: 830))
    stroke(slingLeft, color: Palette.rope, width: 8)

    let slingRight = NSBezierPath()
    slingRight.move(to: CGPoint(x: 758, y: 728))
    slingRight.line(to: CGPoint(x: 878, y: 800))
    stroke(slingRight, color: Palette.rope, width: 8)

    let slingCup = roundedRect(CGRect(x: 812, y: 784, width: 84, height: 34), radius: 16)
    fill(slingCup, color: Palette.rope)

    let projectile = NSBezierPath(ovalIn: CGRect(x: 858, y: 852, width: 74, height: 60))
    fill(projectile, color: Palette.stone)
    fill(NSBezierPath(ovalIn: CGRect(x: 882, y: 874, width: 12, height: 10)), color: Palette.white.withAlphaComponent(0.22))

    let motionA = NSBezierPath()
    motionA.move(to: CGPoint(x: 814, y: 886))
    motionA.curve(to: CGPoint(x: 752, y: 832), controlPoint1: CGPoint(x: 790, y: 872), controlPoint2: CGPoint(x: 770, y: 846))
    stroke(motionA, color: Palette.white.withAlphaComponent(0.55), width: 6)

    let motionB = NSBezierPath()
    motionB.move(to: CGPoint(x: 854, y: 920))
    motionB.curve(to: CGPoint(x: 792, y: 868), controlPoint1: CGPoint(x: 832, y: 906), controlPoint2: CGPoint(x: 812, y: 884))
    stroke(motionB, color: Palette.white.withAlphaComponent(0.44), width: 4)
}

func renderIcon(to outputURL: URL) throws {
    let size = CGSize(width: 1024, height: 1024)
    let image = NSImage(size: size)

    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "IconRender", code: 1)
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    let canvas = CGRect(origin: .zero, size: size)
    let inset = canvas.insetBy(dx: 60, dy: 60)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
    shadow.shadowBlurRadius = 38
    shadow.shadowOffset = CGSize(width: 0, height: -18)
    shadow.set()

    let base = roundedRect(inset, radius: 220)
    let skyGradient = NSGradient(colors: [Palette.skyBottom, Palette.skyTop])!
    skyGradient.draw(in: base, angle: 90)

    stroke(base, color: Palette.white.withAlphaComponent(0.33), width: 5)

    let sun = NSBezierPath(ovalIn: CGRect(x: 706, y: 722, width: 154, height: 154))
    fill(sun, color: Palette.sun.withAlphaComponent(0.95))

    drawCloud(x: 176, y: 724, scale: 1.0)
    drawCloud(x: 550, y: 640, scale: 0.78)

    let hillBack = NSBezierPath()
    hillBack.move(to: CGPoint(x: 124, y: 370))
    hillBack.curve(
        to: CGPoint(x: 900, y: 404),
        controlPoint1: CGPoint(x: 346, y: 330),
        controlPoint2: CGPoint(x: 684, y: 452)
    )
    hillBack.line(to: CGPoint(x: 900, y: 120))
    hillBack.line(to: CGPoint(x: 124, y: 120))
    hillBack.close()
    fill(hillBack, color: Palette.hill)

    let hillFront = NSBezierPath()
    hillFront.move(to: CGPoint(x: 124, y: 280))
    hillFront.curve(
        to: CGPoint(x: 900, y: 308),
        controlPoint1: CGPoint(x: 280, y: 254),
        controlPoint2: CGPoint(x: 716, y: 360)
    )
    hillFront.line(to: CGPoint(x: 900, y: 120))
    hillFront.line(to: CGPoint(x: 124, y: 120))
    hillFront.close()
    fill(hillFront, color: Palette.grass)

    drawTrebuchet()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconRender", code: 2)
    }

    try png.write(to: outputURL)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate_icon.swift <output-png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try renderIcon(to: outputURL)
