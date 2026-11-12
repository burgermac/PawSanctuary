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

    /// "Second Chances" — Parallel Board's own layer of the real 90-day
    /// calendar (`specs/Spec_Phase6c_Calendar.md`, whose §7 originally
    /// listed this as explicitly out of scope: "Parallel Board itself isn't
    /// implemented... revisit this calendar once it ships"). Cadence
    /// decided by the design authority 17 Aug 2026: **monthly, one per
    /// Sanctuary Circle season** (3 total across the 90 days) rather than
    /// the weekly track's cadence — matches the Alignment Plan's own framing
    /// of Parallel Board as "highest revenue, most expensive," read as a
    /// premium/occasional event, not a fourth routine weekly beat.
    ///
    /// All three instances **reuse the same name, chain, and progress-track
    /// shape verbatim** — the identical "reward-curve reuse, not new
    /// numbers" discipline `Spec_Phase6c_Calendar.md` §2.2 already applied
    /// to Rescue Relay/Playtime Rush/Sanctuary Circle, and the identical
    /// "reuse one name across seasons" precedent §6 of that spec explicitly
    /// reviewed and accepted for Sanctuary Circle. Only the event ID and
    /// dates change per season — token wallets/progress are ID-keyed, so
    /// each season needs its own key (a shared ID would open season 2
    /// already-maxed from season 1's leftover progress, the same reasoning
    /// `Spec_Phase6c_Calendar.md` §2.1 gives for `sanctuary_circle_s1/s2/s3`
    /// each getting a distinct ID).
    ///
    /// Each instance runs 3 days, starting 7 days into its paired season —
    /// the same offset the original test instance below used relative to
    /// Season 1's 2026-09-04 start, applied consistently to Seasons 2/3:
    ///
    /// | Season | Event ID | Start | End |
    /// |---|---|---|---|
    /// | 1 | `second_chances_20260911` | 2026-09-11 | 2026-09-14 |
    /// | 2 | `second_chances_20261011` | 2026-10-11 | 2026-10-14 |
    /// | 3 | `second_chances_20261110` | 2026-11-10 | 2026-11-13 |
    /// | 4 | `second_chances_20261210` | 2026-12-10 | 2026-12-13 |
    /// | 5 | `second_chances_20270109` | 2027-01-09 | 2027-01-12 |
    /// | 6 | `second_chances_20270208` | 2027-02-08 | 2027-02-11 |
    /// | 7 | `second_chances_20270310` | 2027-03-10 | 2027-03-13 |
    /// | 8 | `second_chances_20270409` | 2027-04-09 | 2027-04-12 |
    /// | 9 | `second_chances_20270509` | 2027-05-09 | 2027-05-12 |
    ///
    /// Seasons 4-6 are the Phase 7 second calendar
    /// (`specs/Spec_Phase7_Calendar2.md` §2.4): same rule, 7 days into
    /// S4/S5/S6. The 2026-11-13 → 2026-12-10 dark period is by design (one
    /// instance per season) and matches the existing 27-day gaps.
    /// Seasons 7-9 are the Phase 7 third calendar
    /// (`specs/Spec_Phase7_Calendar3.md` §2.5): same rule, 7 days into
    /// S7/S8/S9. The 2027-02-11 → 2027-03-10 dark period is likewise 27 days
    /// and by design.
    ///
    /// The Season 1 instance is the same one §5 of `Spec_Phase6b_ParallelBoard.md`
    /// authored as the type's screen-verification test event — its dates
    /// were already chosen to deliberately overlap `playtime_rush_20260911`
    /// as a three-way concurrency proof (continuous Pass + weekly event +
    /// parallel-board event, all genuinely active at once); it simply now
    /// does double duty as Season 1's real calendar content too, rather
    /// than being a separate, redundant entry. Seasons 2/3 don't repeat
    /// that specific triple-overlap by construction — proving it once was
    /// enough — but each still overlaps its own season throughout, which is
    /// the one pairing D5 actually requires of this track.
    static let allEvents: [ParallelBoardEventDefinition] = [
        ParallelBoardEventDefinition(
            id: "second_chances_20260911",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2026-09-11"),
            endDate:   date("2026-09-14")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20261011",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2026-10-11"),
            endDate:   date("2026-10-14")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20261110",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2026-11-10"),
            endDate:   date("2026-11-13")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20261210",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2026-12-10"),
            endDate:   date("2026-12-13")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20270109",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2027-01-09"),
            endDate:   date("2027-01-12")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20270208",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2027-02-08"),
            endDate:   date("2027-02-11")
        ),
        // Phase 7 third calendar (Spec_Phase7_Calendar3.md §2.5/§3.5) —
        // Seasons 7-9, same rule: 7 days into S7/S8/S9, 3 days each.
        ParallelBoardEventDefinition(
            id: "second_chances_20270310",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2027-03-10"),
            endDate:   date("2027-03-13")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20270409",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2027-04-09"),
            endDate:   date("2027-04-12")
        ),
        ParallelBoardEventDefinition(
            id: "second_chances_20270509",
            name: "Second Chances",
            icon: "arrow.triangle.2.circlepath",
            chainID: ContentRegistry.parallelBoardSecondChancesChainID,
            startDate: date("2027-05-09"),
            endDate:   date("2027-05-12")
        ),
    ]

    /// `at` defaults to `Date()` for production call sites — injectable so
    /// tests can check lifecycle behavior against a fixed, permanent date
    /// instead of real wall-clock time, which rots the moment whatever
    /// event window it depended on closes (found 18 Aug 2026, fixed
    /// alongside the identical issue in `checkEventLifecycle` itself).
    static func activeEvent(at date: Date = Date()) -> ParallelBoardEventDefinition? {
        allEvents.first { date >= $0.startDate && date < $0.endDate }
    }
}
