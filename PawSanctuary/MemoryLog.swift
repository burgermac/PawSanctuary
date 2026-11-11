//
//  MemoryLog.swift
//  PawSanctuary
//
//  DEBUG-only memory sampler for the real-device out-of-memory crash recorded
//  in TODO.md (30 Aug 2026, "Terminated due to memory issue" after ~35
//  minutes). Reading the code found no unbounded growth, so the cause has to
//  be measured: this answers whether memory climbs steadily (a leak) or in
//  steps as the player reaches new tiers (the art working set).
//
//  Once a minute it writes one CSV row to Documents/memory_log.csv and to the
//  Xcode console (subsystem com.pawsanctuary, category memory). The file
//  survives a jetsam kill, so after a crash it shows the last minutes before
//  it. A memory warning is logged as its own row.
//
//  `headroom_mb` is os_proc_available_memory(): how much more this process may
//  allocate before iOS terminates it. It falls as footprint grows, and it is
//  the number that matters for a jetsam kill. `used_mb` is the drop from the
//  first sample of this launch. A Simulator reports a headroom that is not a
//  real limit, so read the numbers on a device.
//
//  Compiled out of Release builds entirely.
//

#if DEBUG
import Foundation
import UIKit
import os

@MainActor
enum MemoryLog {

    /// What the view model contributes to each row.
    struct Context {
        var spawnersOnBoard: Int
        var spawnersAffordable: Int
        var occupiedCells: Int
    }

    static let intervalSeconds = 60
    static let maxLines = 2000
    static let header = "time,elapsed_s,event,headroom_mb,used_mb,spawners,affordable,occupied"

    private static let logger = Logger(subsystem: "com.pawsanctuary", category: "memory")
    private static var seconds = 0
    private static var startHeadroomMB: Double?
    private static var startedAt = Date()
    private static var lineCount = 0
    private static var observing = false

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("memory_log.csv")
    }

    /// Call once per second from the view model's tick. Samples every
    /// `intervalSeconds`; `context` is only evaluated when a sample is due.
    static func tick(context: () -> Context) {
        if !observing { startObserving() }
        seconds += 1
        guard seconds % intervalSeconds == 1 || seconds == 1 else { return }
        record(event: "sample", context: context())
    }

    // MARK: Row building (pure, tested)

    static func headroomMB() -> Double {
        Double(os_proc_available_memory()) / 1_048_576
    }

    static func csvRow(time: Date, elapsed: Int, event: String, headroomMB: Double,
                       usedMB: Double, context: Context) -> String {
        let stamp = ISO8601DateFormatter().string(from: time)
        return String(format: "%@,%d,%@,%.1f,%.1f,%d,%d,%d",
                      stamp, elapsed, event, headroomMB, usedMB,
                      context.spawnersOnBoard, context.spawnersAffordable, context.occupiedCells)
    }

    /// Keeps the newest `max` lines, header first.
    static func trimmed(_ lines: [String], max: Int) -> [String] {
        guard lines.count > max else { return lines }
        let body = lines.dropFirst().suffix(max - 1)
        return [lines[0]] + body
    }

    // MARK: Recording

    private static func record(event: String, context: Context) {
        let headroom = headroomMB()
        if startHeadroomMB == nil { startHeadroomMB = headroom }
        let used = (startHeadroomMB ?? headroom) - headroom
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let row = csvRow(time: Date(), elapsed: elapsed, event: event,
                         headroomMB: headroom, usedMB: used, context: context)
        logger.log("\(row, privacy: .public)")
        append(row)
    }

    private static func append(_ row: String) {
        guard let url = fileURL else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? (header + "\n").write(to: url, atomically: true, encoding: .utf8)
            lineCount = 1
        } else if lineCount == 0 {
            lineCount = ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true).count
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((row + "\n").utf8))
        lineCount += 1

        if lineCount > maxLines,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let kept = trimmed(text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init),
                               max: maxLines / 2)
            try? (kept.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            lineCount = kept.count
        }
    }

    private static func startObserving() {
        observing = true
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                record(event: "MEMORY_WARNING",
                       context: Context(spawnersOnBoard: -1, spawnersAffordable: -1, occupiedCells: -1))
            }
        }
    }
}
#endif
