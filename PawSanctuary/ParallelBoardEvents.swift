//
//  ParallelBoardEvents.swift
//  PawSanctuary
//
//  Phase 6b, Task 3.7 — the "separate registry" §0.5 decided on (16 Aug
//  2026, design authority): a parallel-board event never participates in
//  `EventRegistry.allEvents`/`activeEvents`, so it needs its own small
//  schedule + lookup, mirroring EventSystem.swift's EventDefinition/
//  EventRegistry shape but deliberately smaller — no milestones (that's
//  ProgressTrackRegistry's job), no priority (only one of these is ever
//  scheduled active at a time, by construction of this being its own
//  registry).
//

import SwiftUI
import Foundation

struct ParallelBoardEventDefinition: Identifiable {
    let id: String
    let name: String
    let icon: String
    let chainID: ChainID
    let startDate: Date
    let endDate: Date

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    var timeRemaining: TimeInterval { max(0, endDate.timeIntervalSinceNow) }
    var isUrgent: Bool { timeRemaining < 3600 }

    var timerLabel: String {
        let secs = Int(timeRemaining)
        let days  = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins  = (secs % 3600) / 60
        if days  > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h \(mins)m left" }
        return "\(mins)m left"
    }
}

enum ParallelBoardEventRegistry {
    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? .distantPast
    }

    /// "Second Chances" (§5) — test-only content to prove the second-board
    /// flow end to end, not 6c's real rolling calendar, matching the
    /// identical framing Milestone track's and Pass's own §5 used.
    ///
    /// **2026-09-11 to 2026-09-14** (3 days, D5-cadence-compliant) —
    /// deliberately inside `sanctuary_circle_s1_20260904`'s window
    /// (2026-09-04→10-04) *and* fully overlapping `playtime_rush_20260911`
    /// (2026-09-11→09-15): a three-way concurrency case (continuous Pass +
    /// weekly event + parallel-board event, all genuinely active at once)
    /// proving a *third* kind of event layers onto the existing two without
    /// incident — see `ParallelBoardEventsTests`.
    static let allEvents: [ParallelBoardEventDefinition] = [
        ParallelBoardEventDefinition(
            id: "second_chances_20260911",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2026-09-11"),
            endDate:   date("2026-09-14")
        ),
    ]

    static var activeEvent: ParallelBoardEventDefinition? {
        let now = Date()
        return allEvents.first { now >= $0.startDate && now < $0.endDate }
    }
}
