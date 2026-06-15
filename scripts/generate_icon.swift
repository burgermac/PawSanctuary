#!/usr/bin/env swift
import CoreGraphics
import ImageIO
import Foundation

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()

func makeContext() -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
              bytesPerRow: 0, space: cs,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

// Colours
let darkGreen   = CGColor(red: 0.07, green: 0.28, blue: 0.16, alpha: 1)
let midGreen    = CGColor(red: 0.10, green: 0.36, blue: 0.19, alpha: 1)
let accent      = CGColor(red: 0.91, green: 0.66, blue: 0.44, alpha: 1)  // warm tan/peach
let cream       = CGColor(red: 0.96, green: 0.90, blue: 0.78, alpha: 1)
let groundGreen = CGColor(red: 0.16, green: 0.48, blue: 0.26, alpha: 0.55)

// Scale helper
func s(_ v: CGFloat) -> CGFloat { v / 600 * CGFloat(size) }
func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> CGRect {
    CGRect(x: s(x), y: s(y), width: s(w), height: s(h))
}

func roundedRect(_ ctx: CGContext, _ rect: CGRect, _ radius: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: s(radius), cornerHeight: s(radius), transform: nil)
    ctx.addPath(path)
}

func savePNG(_ ctx: CGContext, to url: URL) {
    guard let img = ctx.makeImage() else { return }
    let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// ── Standard icon ───────────────────────────────────────────────────────────
func drawIcon(ctx: CGContext, darkMode: Bool) {
    ctx.saveGState()
    // CoreGraphics origin is bottom-left; flip to top-left for convenience
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)

    let full = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))

    // ── Background gradient ─────────────────────────────────────────────────
    // Clip to rounded-square
    let bgPath = CGPath(roundedRect: full.insetBy(dx: s(40), dy: s(40)),
                        cornerWidth: s(130), cornerHeight: s(130), transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors: [CGColor]
    if darkMode {
        bgColors = [CGColor(red:0.10, green:0.22, blue:0.12, alpha:1),
                    CGColor(red:0.18, green:0.14, blue:0.08, alpha:1)]
    } else {
        bgColors = [CGColor(red:0.78, green:0.91, blue:0.78, alpha:1),
                    CGColor(red:0.83, green:0.77, blue:0.60, alpha:1)]
    }
    let grad = CGGradient(colorsSpace: cs,
                          colors: bgColors as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(grad,
        startCenter: CGPoint(x: CGFloat(size)*0.5, y: CGFloat(size)*0.28), startRadius: 0,
        endCenter:   CGPoint(x: CGFloat(size)*0.5, y: CGFloat(size)*0.5),  endRadius: CGFloat(size)*0.72,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    ctx.resetClip()

    // Helper to draw a filled rounded rect
    func fillRRect(_ rect: CGRect, r: CGFloat, color: CGColor) {
        ctx.setFillColor(color)
        let p = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
    }

    // ── House body ──────────────────────────────────────────────────────────
    let bodyRect = CGRect(x: s(218), y: s(355), width: s(244), height: s(195))
    fillRRect(bodyRect, r: s(10), color: darkMode ? midGreen : darkGreen)

    // ── Roof ────────────────────────────────────────────────────────────────
    ctx.setFillColor(darkMode ? darkGreen : CGColor(red:0.07, green:0.22, blue:0.12, alpha:1))
    let roofPath = CGMutablePath()
    roofPath.move(to: CGPoint(x: s(194), y: s(358)))
    roofPath.addLine(to: CGPoint(x: s(340), y: s(210)))
    roofPath.addLine(to: CGPoint(x: s(486), y: s(358)))
    roofPath.closeSubpath()
    ctx.addPath(roofPath)
    ctx.fillPath()

    // ── Chimney ─────────────────────────────────────────────────────────────
    fillRRect(CGRect(x: s(400), y: s(240), width: s(34), height: s(65)), r: s(4),
              color: darkMode ? darkGreen : CGColor(red:0.07, green:0.22, blue:0.12, alpha:1))

    // ── Door ────────────────────────────────────────────────────────────────
    fillRRect(CGRect(x: s(300), y: s(440), width: s(80), height: s(110)), r: s(14), color: cream)

    // Door knob
    ctx.setFillColor(darkMode ? midGreen : darkGreen)
    ctx.fillEllipse(in: CGRect(x: s(364), y: s(492), width: s(12), height: s(12)))

    // ── Windows ─────────────────────────────────────────────────────────────
    func drawWindow(_ rect: CGRect) {
        fillRRect(rect, r: s(8), color: CGColor(red:0.96, green:0.90, blue:0.78, alpha:0.92))
        // cross
        let midX = rect.midX
        let midY = rect.midY
        ctx.setStrokeColor(darkMode ? midGreen : darkGreen)
        ctx.setLineWidth(s(3))
        ctx.move(to: CGPoint(x: midX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: midX, y: rect.maxY))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: rect.minX, y: midY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: midY))
        ctx.strokePath()
    }
    drawWindow(CGRect(x: s(230), y: s(382), width: s(62), height: s(58)))
    drawWindow(CGRect(x: s(388), y: s(382), width: s(62), height: s(58)))

    // ── Paw print on door ───────────────────────────────────────────────────
    ctx.setFillColor(accent)
    // Main pad
    ctx.fillEllipse(in: CGRect(x: s(318), y: s(465), width: s(44), height: s(34)))
    // Toe beans
    let toes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (s(310), s(447), s(20), s(18)),
        (s(330), s(440), s(20), s(18)),
        (s(350), s(447), s(20), s(18))
    ].map { ($0.0, $0.1, $0.2, $0.3) }
    for (tx, ty, tw, th) in toes {
        ctx.fillEllipse(in: CGRect(x: tx, y: ty, width: tw, height: th))
    }

    // ── Heart above roof peak ───────────────────────────────────────────────
    ctx.setFillColor(CGColor(red:0.91, green:0.66, blue:0.44, alpha:0.88))
    let hx = s(340), hy = s(192)
    let hr = s(16)
    let heartPath = CGMutablePath()
    heartPath.move(to: CGPoint(x: hx, y: hy + hr * 0.9))
    heartPath.addCurve(to: CGPoint(x: hx - hr * 1.2, y: hy - hr * 0.3),
        control1: CGPoint(x: hx - hr * 1.5, y: hy + hr * 0.5),
        control2: CGPoint(x: hx - hr * 2.0, y: hy - hr * 0.5))
    heartPath.addCurve(to: CGPoint(x: hx, y: hy - hr * 0.3),
        control1: CGPoint(x: hx - hr * 0.5, y: hy - hr * 1.2),
        control2: CGPoint(x: hx, y: hy - hr * 0.5))
    heartPath.addCurve(to: CGPoint(x: hx + hr * 1.2, y: hy - hr * 0.3),
        control1: CGPoint(x: hx, y: hy - hr * 0.5),
        control2: CGPoint(x: hx + hr * 0.5, y: hy - hr * 1.2))
    heartPath.addCurve(to: CGPoint(x: hx, y: hy + hr * 0.9),
        control1: CGPoint(x: hx + hr * 2.0, y: hy - hr * 0.5),
        control2: CGPoint(x: hx + hr * 1.5, y: hy + hr * 0.5))
    heartPath.closeSubpath()
    ctx.addPath(heartPath)
    ctx.fillPath()

    // ── Ground strip ────────────────────────────────────────────────────────
    fillRRect(CGRect(x: s(175), y: s(542), width: s(330), height: s(20)), r: s(10), color: groundGreen)

    // ── Tiny flowers ────────────────────────────────────────────────────────
    func flower(cx: CGFloat, cy: CGFloat) {
        ctx.setFillColor(CGColor(red:0.96, green:0.90, blue:0.78, alpha:0.75))
        ctx.fillEllipse(in: CGRect(x: cx - s(10), y: cy - s(10), width: s(20), height: s(20)))
        ctx.setFillColor(accent)
        ctx.fillEllipse(in: CGRect(x: cx - s(5), y: cy - s(5), width: s(10), height: s(10)))
    }
    flower(cx: s(210), cy: s(537))
    flower(cx: s(470), cy: s(537))

    // ── Border ring ─────────────────────────────────────────────────────────
    ctx.setStrokeColor(CGColor(red:0.07, green:0.28, blue:0.16, alpha:0.12))
    ctx.setLineWidth(s(6))
    ctx.addPath(bgPath)
    ctx.strokePath()

    ctx.restoreGState()
}

// ── Tinted icon (grayscale silhouette for iOS tinted variant) ──────────────
func drawTintedIcon(ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)

    let full = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))

    // White background
    let bgPath = CGPath(roundedRect: full.insetBy(dx: s(40), dy: s(40)),
                        cornerWidth: s(130), cornerHeight: s(130), transform: nil)
    ctx.setFillColor(CGColor(red:1, green:1, blue:1, alpha:1))
    ctx.addPath(bgPath)
    ctx.fillPath()
    ctx.addPath(bgPath)
    ctx.clip()

    func fillR(_ rect: CGRect, r: CGFloat, a: CGFloat = 1) {
        ctx.setFillColor(CGColor(red:0.2, green:0.2, blue:0.2, alpha:a))
        let p = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
    }

    let bodyRect = CGRect(x: s(218), y: s(355), width: s(244), height: s(195))
    fillR(bodyRect, r: s(10))

    ctx.setFillColor(CGColor(red:0.1, green:0.1, blue:0.1, alpha:1))
    let roofPath = CGMutablePath()
    roofPath.move(to: CGPoint(x: s(194), y: s(358)))
    roofPath.addLine(to: CGPoint(x: s(340), y: s(210)))
    roofPath.addLine(to: CGPoint(x: s(486), y: s(358)))
    roofPath.closeSubpath()
    ctx.addPath(roofPath)
    ctx.fillPath()

    fillR(CGRect(x: s(400), y: s(240), width: s(34), height: s(65)), r: s(4))
    fillR(CGRect(x: s(300), y: s(440), width: s(80), height: s(110)), r: s(14), a: 0.08)

    func tintWindow(_ rect: CGRect) {
        fillR(rect, r: s(8), a: 0.07)
    }
    tintWindow(CGRect(x: s(230), y: s(382), width: s(62), height: s(58)))
    tintWindow(CGRect(x: s(388), y: s(382), width: s(62), height: s(58)))

    ctx.setFillColor(CGColor(red:0.2, green:0.2, blue:0.2, alpha:1))
    ctx.fillEllipse(in: CGRect(x: s(318), y: s(465), width: s(44), height: s(34)))
    let toes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (s(310), s(447), s(20), s(18)),
        (s(330), s(440), s(20), s(18)),
        (s(350), s(447), s(20), s(18))
    ]
    for (tx, ty, tw, th) in toes {
        ctx.fillEllipse(in: CGRect(x: tx, y: ty, width: tw, height: th))
    }

    ctx.restoreGState()
}

// ── Write PNGs ──────────────────────────────────────────────────────────────
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

let ctxLight = makeContext()
drawIcon(ctx: ctxLight, darkMode: false)
savePNG(ctxLight, to: outDir.appendingPathComponent("AppIcon.png"))

let ctxDark = makeContext()
drawIcon(ctx: ctxDark, darkMode: true)
savePNG(ctxDark, to: outDir.appendingPathComponent("AppIcon-Dark.png"))

let ctxTinted = makeContext()
drawTintedIcon(ctx: ctxTinted)
savePNG(ctxTinted, to: outDir.appendingPathComponent("AppIcon-Tinted.png"))

print("Done")
