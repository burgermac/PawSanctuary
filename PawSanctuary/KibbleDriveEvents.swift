//
//  KibbleDriveEvents.swift
//  PawSanctuary
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) §6 step 3a — the schedule
//  and lookup the Drive's lifecycle runs off.
//
//  Its own registry rather than an EventRegistry.allEvents entry, mirroring
//  ParallelBoardEvents.swift's reasoning: a Drive never participates in the
//  milestone-lane bookkeeping checkEventLifecycle does for ordinary events,
//  so folding it into that registry would mean teaching every consumer of
//  activeEvents to skip it. Deliberately smaller than EventDefinition — no
//  milestones (that is ProgressTrackRegistry's job once §6 step 4 lands the
//  ladder), no priority, since only one Drive is ever scheduled at a time by
//  construction of this being its own registry.
//

import Foundation

struct KibbleDriveEventDefinition: Identifiable {
    let id: String
    let name: String
    let icon: String
    let startDate: Date
    let endDate: Date

    var timeRemaining: TimeInterval { max(0, endDate.timeIntervalSinceNow) }

    /// Deliberately coarser than the reference's countdown. §3.3 sets a
    /// 3-day window, so hours are the unit that matters to a player deciding
    /// whether they can still finish; seconds would be noise.
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

enum KibbleDriveRegistry {
    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? .distantPast
    }

    /// **The schedule only — the ladder content is §6 step 4.** A Drive needs
    /// a window before its lifecycle can be written or watched, so the dates
    /// land here in 3a and the rung table joins them in step 4.
    ///
    /// Cadence is §4's: **3-day windows about four weeks apart**, not weekly.
    /// §4 is explicit that rarity is doing real work — at a weekly cadence the
    /// Drive stops being an occasion and becomes the kibble economy, and
    /// §3.5's ~3.9× safety margin stops being a margin. The 28-day spacing is
    /// what keeps §3.5's amortised supply impact at +2.6% rather than the
    /// +24% it runs at inside a window.
    ///
    /// **These windows overlap `ParallelBoardEventRegistry`'s own instances**,
    /// and that is allowed rather than overlooked: §4 explicitly expects the
    /// Drive to run concurrently with whatever else is live, and
    /// `Spec_ParallelBoardReview_Draft.md` §2.5 records the reference running
    /// 3+ event surfaces at once. An earlier draft of this file asserted the
    /// opposite — that two premium offers should never share days because they
    /// compete for one purchase — which is a plausible commercial instinct but
    /// is **not** in the spec and contradicts §4. It was removed rather than
    /// left as an unsourced rule masquerading as a requirement. If that
    /// instinct turns out to be right, it belongs in the spec first.
    ///
    /// | Instance | Start | End |
    /// |---|---|---|
    /// | `kibble_drive_20260911` | 2026-09-11 | 2026-09-14 |
    /// | `kibble_drive_20261009` | 2026-10-09 | 2026-10-12 |
    /// | `kibble_drive_20261106` | 2026-11-06 | 2026-11-09 |
    ///
    /// **The first window is deliberately live on the day 3a was written**, so
    /// the lifecycle could be verified on screen rather than only against an
    /// injected date — the same choice, for the same reason, that
    /// `Spec_Phase6b_ParallelBoard.md` §5 made for `second_chances_20260911`,
    /// which ParallelBoardEvents.swift records doing double duty as both the
    /// screen-verification event and Season 1's real content. It does overlap
    /// that Second Chances window exactly. Per the note above that is
    /// permitted, but it is worth a deliberate look when §6 step 4 lands the
    /// ladder: this is the one date here chosen for testability rather than
    /// for the calendar. Moving it is a one-line change — the cadence, not the
    /// phase, is what §4 argues for.
    ///
    /// Each instance takes its own ID because `KibbleDriveState` is scoped by
    /// `eventID`: a shared ID would let a finished Drive's points open the
    /// next one part-filled, the same reasoning `Spec_Phase6c_Calendar.md`
    /// §2.1 gives for `sanctuary_circle_s1/s2/s3`.
    static let allEvents: [KibbleDriveEventDefinition] = [
        KibbleDriveEventDefinition(
            id: "kibble_drive_20260911",
            name: "Kibble Drive",
            icon: "shippingbox.fill",
            startDate: date("2026-09-11"),
            endDate:   date("2026-09-14")
        ),
        KibbleDriveEventDefinition(
            id: "kibble_drive_20261009",
            name: "Kibble Drive",
            icon: "shippingbox.fill",
            startDate: date("2026-10-09"),
            endDate:   date("2026-10-12")
        ),
        KibbleDriveEventDefinition(
            id: "kibble_drive_20261106",
            name: "Kibble Drive",
            icon: "shippingbox.fill",
            startDate: date("2026-11-06"),
            endDate:   date("2026-11-09")
        ),
    ]

    /// `at` defaults to `Date()` for production call sites — injectable so
    /// tests can pin lifecycle behaviour to fixed, permanent dates rather than
    /// real wall-clock time, which rots the moment the window it depended on
    /// closes. `ParallelBoardEventRegistry.activeEvent` learned this the hard
    /// way; see `TODO.md`'s resolved test-rot entry.
    static func activeEvent(at date: Date = Date()) -> KibbleDriveEventDefinition? {
        allEvents.first { date >= $0.startDate && date < $0.endDate }
    }
}
