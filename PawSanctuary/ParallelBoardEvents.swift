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
    /// Empty until §5's real, screen-verifiable test event is authored — a
    /// separate task from §3.7, same as Milestone track's own lifecycle-wiring
    /// task (6b.2) landing with no real event content yet.
    static let allEvents: [ParallelBoardEventDefinition] = []

    static var activeEvent: ParallelBoardEventDefinition? {
        let now = Date()
        return allEvents.first { now >= $0.startDate && now < $0.endDate }
    }
}
