#!/usr/bin/env swift
import CoreGraphics
import CoreText
import ImageIO
import Foundation

let W = 600
let H = 500
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Flip to top-left origin
ctx.translateBy(x: 0, y: CGFloat(H))
ctx.scaleBy(x: 1, y: -1)

let darkGreen = CGColor(red: 0.07, green: 0.28, blue: 0.16, alpha: 1)
let accent    = CGColor(red: 0.91, green: 0.66, blue: 0.44, alpha: 1)
let dimGreen  = CGColor(red: 0.07, green: 0.28, blue: 0.16, alpha: 0.55)

// ── Large paw print centred in upper portion ────────────────────────────────
let cx: CGFloat = CGFloat(W) / 2
let cy: CGFloat = 200
let scale: CGFloat = 2.0

ctx.setFillColor(darkGreen)

// Main central pad — large oval
ctx.fillEllipse(in: CGRect(x: cx - 54*scale*0.5, y: cy - 22*scale*0.5,
                            width: 54*scale*0.5*2, height: 40*scale*0.5*2))

// 4 toe beans
let toeData: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (-52, -62, 26, 22),
    (-20, -76, 26, 22),
    ( 20, -76, 26, 22),
    ( 52, -62, 26, 22)
]
for (dx, dy, tw, th) in toeData {
    ctx.fillEllipse(in: CGRect(x: cx + dx*scale*0.5 - tw*scale*0.5*0.5,
                                y: cy + dy*scale*0.5 - th*scale*0.5*0.5,
                                width: tw*scale*0.5, height: th*scale*0.5))
}

// ── "Paw Sanctuary" in large geometric letters via CoreText ─────────────────
func drawLine(_ text: String, x: CGFloat, y: CGFloat, fontSize: CGFloat, color: CGColor) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let attrStr = CFAttributedStringCreateMutable(nil, 0)!
    CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), text as CFString)
    let range = CFRange(location: 0, length: CFStringGetLength(text as CFString))
    CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
    CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, color)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    let tx = x - bounds.width / 2 - bounds.origin.x
    ctx.saveGState()
    ctx.translateBy(x: tx, y: CGFloat(H) - y)
    ctx.scaleBy(x: 1, y: -1)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

drawLine("Paw Sanctuary", x: cx, y: 360, fontSize: 72, color: darkGreen)
drawLine("RESCUE · MERGE · PROTECT", x: cx, y: 440, fontSize: 22, color: dimGreen)

// ── Save ─────────────────────────────────────────────────────────────────────
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let img = ctx.makeImage() else { print("makeImage failed"); exit(1) }
let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { print("finalize failed"); exit(1) }
print("Done")
