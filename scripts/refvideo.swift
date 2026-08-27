#!/usr/bin/env swift
//
//  refvideo.swift — reference-video analysis toolkit
//
//  Extracts frames from reference-game screen recordings for design analysis.
//  Written because this machine has no ffmpeg; uses AVFoundation directly.
//
//  Two audiences:
//    • Triage (e.g. the cowork scanning process) — `info` and `sheet` give a
//      cheap, glanceable summary of a recording without decoding it repeatedly.
//    • Deep dives — `frames` and `crop` pull dense frame sequences at a chosen
//      interval and region, for reading animation choreography frame by frame.
//
//  Run `swift scripts/refvideo.swift` with no arguments for usage.
//
//  Note on coordinates: `crop` takes x,y,w,h in SOURCE pixels with the origin
//  at the TOP-LEFT of the upright frame (i.e. what you'd measure off a
//  screenshot). Track orientation is applied before cropping.
//

import AVFoundation
import AppKit
import Foundation

// ============================================================
// MARK: - Usage
// ============================================================

let usageText = """
refvideo — reference-video analysis toolkit

USAGE
  swift scripts/refvideo.swift <command> [options]

COMMANDS
  info   <video>
        Print duration, dimensions, frame rate and file size as key=value lines.

  sheet  <video> <out.jpg> [--step S] [--cols N] [--width W] [--quality Q]
        Build one tiled contact sheet of the whole recording, each thumbnail
        labelled with its timestamp. The cheap first look at a new recording.
        Defaults: --step 1.0  --cols 6  --width 220  --quality 0.8

  frames <video> <outDir> [--start T] [--end T] [--step S] [--width W] [--quality Q]
        Write one JPEG per sampled instant, scaled to fit --width.
        Defaults: --start 0  --end <duration>  --step 0.5  --width 430  --quality 0.7

  crop   <video> <outDir> --rect X,Y,W,H [--start T] [--end T] [--step S] [--quality Q]
        Same as `frames`, but writes a cropped region at FULL source resolution —
        use this to zoom into one tile or UI element. --rect is in source pixels,
        origin top-left. Not scaled: the crop is written at native detail.
        Defaults: --start 0  --end <duration>  --step 0.5  --quality 0.85

EXAMPLES
  swift scripts/refvideo.swift info "Screen Recordings/clip.MP4"
  swift scripts/refvideo.swift sheet "Screen Recordings/clip.MP4" /tmp/clip.jpg --step 1
  swift scripts/refvideo.swift frames "Screen Recordings/clip.MP4" /tmp/f --step 0.5
  swift scripts/refvideo.swift crop "Screen Recordings/clip.MP4" /tmp/z \\
        --rect 850,1250,356,500 --start 3.4 --end 4.4 --step 0.05

NOTES
  • Output filenames embed the timestamp (frame_03.90.jpg), so they sort in
    playback order and the name alone tells you where in the clip you are.
  • Sampling is exact (zero tolerance), so --step 0.03 on 60fps footage gives
    roughly every other real frame — dense enough to read a 0.06s animation phase.
  • Extracting hundreds of frames is slow and produces a lot of images. Start
    coarse (--step 0.5), find the moment, then re-run tight on a narrow window.
"""

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

// ============================================================
// MARK: - Argument parsing
// ============================================================

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    print(usageText)
    exit(0)
}
args.removeFirst()

if ["-h", "--help", "help"].contains(command) {
    print(usageText)
    exit(0)
}

/// Pulls `--name value` out of `args`, returning the value if present.
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: "--" + name) else { return nil }
    guard i + 1 < args.count else { die("--\(name) needs a value") }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}

func doubleOption(_ name: String, default fallback: Double) -> Double {
    guard let raw = option(name) else { return fallback }
    guard let value = Double(raw) else { die("--\(name) expects a number, got '\(raw)'") }
    return value
}

func intOption(_ name: String, default fallback: Int) -> Int {
    guard let raw = option(name) else { return fallback }
    guard let value = Int(raw) else { die("--\(name) expects an integer, got '\(raw)'") }
    return value
}

/// Consumes the next positional argument (one not starting with `--`).
func positional(_ label: String) -> String {
    guard let i = args.firstIndex(where: { !$0.hasPrefix("--") }) else {
        die("missing <\(label)>")
    }
    return args.remove(at: i)
}

// ============================================================
// MARK: - AVFoundation helpers
// ============================================================

/// Runs async work to completion from this synchronous script.
func runBlocking(_ body: @escaping () async -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await body()
        semaphore.signal()
    }
    semaphore.wait()
}

func makeAsset(_ path: String) -> AVURLAsset {
    guard FileManager.default.fileExists(atPath: path) else { die("no such file: \(path)") }
    return AVURLAsset(url: URL(fileURLWithPath: path))
}

/// Duration in seconds, plus natural size and nominal frame rate of the first video track.
func describe(_ asset: AVURLAsset) async throws -> (duration: Double, size: CGSize, fps: Float) {
    let duration = CMTimeGetSeconds(try await asset.load(.duration))
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        return (duration, .zero, 0)
    }
    let size = try await track.load(.naturalSize)
    let fps = try await track.load(.nominalFrameRate)
    return (duration, size, fps)
}

func makeGenerator(_ asset: AVURLAsset, maxWidth: CGFloat?) -> AVAssetImageGenerator {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    // Exact sampling: without this AVFoundation snaps to nearby sync frames,
    // which collapses a dense sweep into a handful of duplicated stills.
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    if let maxWidth {
        // Generous height cap — these are portrait phone recordings, so width binds.
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth * 4)
    }
    return generator
}

/// Non-deprecated single-frame fetch (the sync `copyCGImage` is deprecated on macOS 15+).
func image(at seconds: Double, from generator: AVAssetImageGenerator) async throws -> CGImage {
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    return try await withCheckedThrowingContinuation { continuation in
        generator.generateCGImageAsynchronously(for: time) { image, _, error in
            if let image {
                continuation.resume(returning: image)
            } else {
                continuation.resume(throwing: error ?? NSError(
                    domain: "refvideo", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "no image returned"]))
            }
        }
    }
}

func sampleTimes(start: Double, end: Double, step: Double) -> [Double] {
    guard step > 0 else { die("--step must be greater than zero") }
    guard end >= start else { die("--end must be at or after --start") }
    var times: [Double] = []
    var index = 0
    while true {
        let t = start + Double(index) * step
        if t > end { break }
        times.append(t)
        index += 1
        if times.count > 20_000 { die("refusing to extract more than 20000 frames — widen --step") }
    }
    return times
}

func writeJPEG(_ image: CGImage, to path: String, quality: Double) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .jpeg,
                                        properties: [.compressionFactor: quality]) else {
        throw NSError(domain: "refvideo", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"])
    }
    try data.write(to: URL(fileURLWithPath: path))
}

func makeDirectory(_ path: String) {
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
}

// ============================================================
// MARK: - Commands
// ============================================================

switch command {

// ── info ────────────────────────────────────────────────────
case "info":
    let path = positional("video")
    let asset = makeAsset(path)
    runBlocking {
        do {
            let (duration, size, fps) = try await describe(asset)
            let bytes = (try? FileManager.default
                .attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
            print("path=\(path)")
            print(String(format: "duration_sec=%.3f", duration))
            print("width=\(Int(size.width))")
            print("height=\(Int(size.height))")
            print(String(format: "fps=%.3f", fps))
            print(String(format: "size_mb=%.1f", Double(bytes) / 1_048_576))
        } catch {
            die("could not read asset: \(error.localizedDescription)")
        }
    }

// ── sheet ───────────────────────────────────────────────────
case "sheet":
    let path = positional("video")
    let outPath = positional("out.jpg")
    let step = doubleOption("step", default: 1.0)
    let columns = max(1, intOption("cols", default: 6))
    let thumbWidth = max(60, intOption("width", default: 220))
    let quality = doubleOption("quality", default: 0.8)

    let asset = makeAsset(path)
    runBlocking {
        do {
            let (duration, _, _) = try await describe(asset)
            let times = sampleTimes(start: 0, end: max(0, duration - 0.05), step: step)
            let generator = makeGenerator(asset, maxWidth: CGFloat(thumbWidth))

            var thumbnails: [(Double, CGImage)] = []
            for t in times {
                if let image = try? await image(at: t, from: generator) {
                    thumbnails.append((t, image))
                }
            }
            guard let first = thumbnails.first?.1 else { die("no frames could be read") }

            let thumbHeight = Int((CGFloat(thumbWidth) * CGFloat(first.height)
                                   / CGFloat(first.width)).rounded())
            let labelHeight = 22
            let cellWidth = thumbWidth
            let cellHeight = thumbHeight + labelHeight
            let rows = Int((Double(thumbnails.count) / Double(columns)).rounded(.up))
            let sheetWidth = columns * cellWidth
            let sheetHeight = rows * cellHeight

            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: sheetWidth, pixelsHigh: sheetHeight,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            else { die("could not allocate contact sheet bitmap") }

            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            guard let nsContext = NSGraphicsContext(bitmapImageRep: rep) else {
                die("could not create drawing context")
            }
            NSGraphicsContext.current = nsContext
            let context = nsContext.cgContext

            context.setFillColor(CGColor(gray: 0.11, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white,
            ]

            for (index, entry) in thumbnails.enumerated() {
                let row = index / columns
                let column = index % columns
                let x = column * cellWidth
                // CGContext origin is bottom-left; rows are laid out top-down.
                let cellBottom = sheetHeight - (row + 1) * cellHeight
                context.draw(entry.1, in: CGRect(x: x, y: cellBottom + labelHeight,
                                                 width: thumbWidth, height: thumbHeight))
                let label = String(format: "%.2fs", entry.0) as NSString
                label.draw(at: NSPoint(x: x + 6, y: cellBottom + 4), withAttributes: attributes)
            }

            guard let data = rep.representation(using: .jpeg,
                                                properties: [.compressionFactor: quality]) else {
                die("could not encode contact sheet")
            }
            try data.write(to: URL(fileURLWithPath: outPath))
            print("wrote \(outPath)  (\(thumbnails.count) thumbs, \(columns)x\(rows), \(sheetWidth)x\(sheetHeight))")
        } catch {
            die("sheet failed: \(error.localizedDescription)")
        }
    }

// ── frames ──────────────────────────────────────────────────
case "frames":
    let path = positional("video")
    let outDir = positional("outDir")
    let start = doubleOption("start", default: 0)
    let endOption = option("end").flatMap(Double.init)
    let step = doubleOption("step", default: 0.5)
    let width = doubleOption("width", default: 430)
    let quality = doubleOption("quality", default: 0.7)

    let asset = makeAsset(path)
    makeDirectory(outDir)
    runBlocking {
        do {
            let (duration, _, _) = try await describe(asset)
            let end = endOption ?? max(0, duration - 0.05)
            let generator = makeGenerator(asset, maxWidth: CGFloat(width))
            var written = 0
            for t in sampleTimes(start: start, end: end, step: step) {
                do {
                    let frame = try await image(at: t, from: generator)
                    let name = String(format: "%@/frame_%06.2f.jpg", outDir, t)
                    try writeJPEG(frame, to: name, quality: quality)
                    written += 1
                } catch {
                    print(String(format: "skip %.2f: %@", t, error.localizedDescription))
                }
            }
            print("wrote \(written) frames to \(outDir)")
        } catch {
            die("frames failed: \(error.localizedDescription)")
        }
    }

// ── crop ────────────────────────────────────────────────────
case "crop":
    let path = positional("video")
    let outDir = positional("outDir")
    guard let rectRaw = option("rect") else { die("crop needs --rect X,Y,W,H") }
    let parts = rectRaw.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard parts.count == 4, !parts.contains(where: { $0 == nil }) else {
        die("--rect expects four integers, e.g. --rect 850,1250,356,500")
    }
    let (rx, ry, rw, rh) = (parts[0]!, parts[1]!, parts[2]!, parts[3]!)
    guard rw > 0, rh > 0 else { die("--rect width and height must be positive") }

    let start = doubleOption("start", default: 0)
    let endOption = option("end").flatMap(Double.init)
    let step = doubleOption("step", default: 0.5)
    let quality = doubleOption("quality", default: 0.85)

    let asset = makeAsset(path)
    makeDirectory(outDir)
    runBlocking {
        do {
            let (duration, _, _) = try await describe(asset)
            let end = endOption ?? max(0, duration - 0.05)
            // No maximumSize: crops are written at native resolution, which is
            // the entire point of this command.
            let generator = makeGenerator(asset, maxWidth: nil)
            var written = 0
            var warnedBounds = false
            for t in sampleTimes(start: start, end: end, step: step) {
                do {
                    let frame = try await image(at: t, from: generator)
                    let rect = CGRect(x: rx, y: ry, width: rw, height: rh)
                    guard let cropped = frame.cropping(to: rect) else {
                        if !warnedBounds {
                            print("crop rect \(rx),\(ry),\(rw),\(rh) falls outside the "
                                  + "\(frame.width)x\(frame.height) frame")
                            warnedBounds = true
                        }
                        continue
                    }
                    let name = String(format: "%@/crop_%06.2f.jpg", outDir, t)
                    try writeJPEG(cropped, to: name, quality: quality)
                    written += 1
                } catch {
                    print(String(format: "skip %.2f: %@", t, error.localizedDescription))
                }
            }
            print("wrote \(written) crops to \(outDir)")
        } catch {
            die("crop failed: \(error.localizedDescription)")
        }
    }

default:
    die("unknown command '\(command)' — run with --help for usage")
}
