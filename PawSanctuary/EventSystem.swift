//
//  EventSystem.swift
//  PawSanctuary
//
//  Time-limited event models and static event registry.
//

import SwiftUI
import Foundation

// ============================================================
// MARK: - PERSISTED STATE
// ============================================================

struct EventProgress: Codable, Equatable {
    var eventId: String = ""
    var coinsEarned: Int = 0
    var claimedMilestones: [Int] = []

    func hasClaimed(_ tier: Int) -> Bool { claimedMilestones.contains(tier) }

    func canClaim(_ milestone: EventMilestone) -> Bool {
        coinsEarned >= milestone.coinsRequired && !hasClaimed(milestone.id)
    }
}

// ============================================================
// MARK: - STATIC DEFINITIONS
// ============================================================

struct EventMilestone: Identifiable {
    let id: Int             // tier number (1, 2, 3)
    let coinsRequired: Int
    let kibbleReward: Int
    let dogTagsReward: Int
}

struct EventDefinition: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let startDate: Date
    let endDate: Date
    let milestones: [EventMilestone]
    let icon: String
    let accentColor: Color
    let gradientColors: [Color]
    /// Minimum player level to see/participate in this event. Phase 6a — EventScheduler.
    let minLevel: Int
    /// Which event wins a contested UI slot when several are active simultaneously.
    /// Higher wins; ties break by earliest startDate. Phase 6a — EventScheduler.
    let priority: Int

    init(id: String, name: String, tagline: String, startDate: Date, endDate: Date,
         milestones: [EventMilestone], icon: String, accentColor: Color, gradientColors: [Color],
         minLevel: Int = 0, priority: Int = 0) {
        self.id = id; self.name = name; self.tagline = tagline
        self.startDate = startDate; self.endDate = endDate
        self.milestones = milestones
        self.icon = icon; self.accentColor = accentColor; self.gradientColors = gradientColors
        self.minLevel = minLevel; self.priority = priority
    }

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

// ============================================================
// MARK: - REGISTRY
// ============================================================

enum EventRegistry {

    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? .distantPast
    }

    static let allEvents: [EventDefinition] = [
        EventDefinition(
            id: "rescue_rush_jun2026",
            name: "Rescue Rush",
            tagline: "Merge animals and complete orders to earn event coins!",
            startDate: date("2026-06-01"),
            endDate:   date("2026-06-15"),
            milestones: [
                EventMilestone(id: 1, coinsRequired: 200, kibbleReward: 50,  dogTagsReward: 0),
                EventMilestone(id: 2, coinsRequired: 450, kibbleReward: 75,  dogTagsReward: 3),
                EventMilestone(id: 3, coinsRequired: 700, kibbleReward: 150, dogTagsReward: 8),
            ],
            icon: "hare.fill",
            accentColor: Color(red: 0.85, green: 0.45, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.93, blue: 0.80),
                Color(red: 0.99, green: 0.87, blue: 0.68),
            ]
        ),
        // Phase 6b screen-verification content — a short-lived (3-4 day, per
        // D5) milestone track proving the primitive-backed flow end to end.
        // NOT the real 6c rolling calendar. `milestones: []` is correct and
        // intentional: this event's real milestone data lives in
        // ProgressTrackRegistry.tracks (LiveOpsEngine.swift), not here — the
        // old EventMilestone-keyed field is vestigial for any event defined
        // after Phase 6b (specs/Spec_Phase6b_MilestoneTrack.md §3.6).
        EventDefinition(
            id: "adoption_drive_aug2026",
            name: "Adoption Drive",
            tagline: "Fulfil orders to earn drive tokens!",
            startDate: date("2026-08-01"),
            endDate:   date("2026-08-05"),
            milestones: [],
            icon: "pawprint.circle.fill",
            accentColor: Color(red: 0.10, green: 0.55, blue: 0.60),
            gradientColors: [
                Color(red: 0.85, green: 0.96, blue: 0.95),
                Color(red: 0.70, green: 0.90, blue: 0.88),
            ]
        ),
        // Phase 6b, Pass screen-verification content — a continuous 30-day
        // track (per D5's second cadence clause) proving the two-lane,
        // paid-unlock flow end to end. Starts the instant Adoption Drive goes
        // inactive (endDate above is exclusive) so the two never overlap
        // under the current single-active-event model — see
        // specs/Spec_Phase6b_Pass.md §0. Real milestone data (both lanes)
        // lives in ProgressTrackRegistry.tracks, not here — `milestones: []`
        // is correct and intentional, same posture as Adoption Drive above.
        // NOT the real 6c rolling calendar.
        EventDefinition(
            id: "founders_circle_aug2026",
            name: "Founders' Circle",
            tagline: "A season of rewards for the sanctuary's founding rescuers.",
            startDate: date("2026-08-05"),
            endDate:   date("2026-09-04"),
            milestones: [],
            icon: "trophy.fill",
            accentColor: Color(red: 0.72, green: 0.50, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.96, blue: 0.85),
                Color(red: 0.96, green: 0.85, blue: 0.60),
            ]
        ),
        // Phase 6c screen-verification content — the first EventDefinition
        // whose sole purpose is proving two *real* events can be
        // simultaneously active (Spec_Phase6c_ConcurrentEvents.md §4), not a
        // new event type. Scheduled entirely inside Founders' Circle's
        // still-open window so the two genuinely overlap rather than sit
        // adjacent, matching D5's "short weekly event running concurrently
        // with the continuous Pass" cadence. Dates chosen to bracket the
        // date this task was implemented (16 Aug 2026) rather than the
        // spec's original 20-24 Aug proposal, so the overlap is verifiable
        // on screen against the real registry immediately, per the spec's
        // own note to re-verify dates at implementation time. Free-lane-only
        // milestone table lives in ProgressTrackRegistry.tracks, same
        // posture as Adoption Drive above — `milestones: []` here is
        // correct and intentional. NOT the real 6c rolling calendar.
        EventDefinition(
            id: "foster_weekend_aug2026",
            name: "Foster Weekend",
            tagline: "Take in extra fosters this weekend to earn bonus rewards!",
            startDate: date("2026-08-14"),
            endDate:   date("2026-08-18"),
            milestones: [],
            icon: "gift.fill",
            accentColor: Color(red: 0.45, green: 0.30, blue: 0.65),
            gradientColors: [
                Color(red: 0.93, green: 0.90, blue: 0.98),
                Color(red: 0.82, green: 0.74, blue: 0.93),
            ]
        ),
        // Phase 6c real calendar (Spec_Phase6c_Calendar.md §3.1) — the
        // continuous track, 3 sequential 30-day Passes covering the
        // calendar's full 2026-09-04...2026-12-03 span, contiguous with
        // zero gap (same convention as Adoption Drive -> Founders' Circle),
        // starting the instant Founders' Circle above ends. Milestone table
        // is a verbatim reuse of Founders' Circle's own 10-tier curve
        // (ProgressTrackRegistry.tracks), re-keyed per season since token
        // wallets/progress are ID-keyed — see spec §2.2 for why a shared ID
        // across seasons would be wrong (Season 2 would open already-maxed).
        EventDefinition(
            id: "sanctuary_circle_s1_20260904",
            name: "Sanctuary Circle",
            tagline: "A season of rewards for the sanctuary's circle of supporters.",
            startDate: date("2026-09-04"),
            endDate:   date("2026-10-04"),
            milestones: [],
            icon: "trophy.fill",
            accentColor: Color(red: 0.72, green: 0.50, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.96, blue: 0.85),
                Color(red: 0.96, green: 0.85, blue: 0.60),
            ]
        ),
        EventDefinition(
            id: "sanctuary_circle_s2_20261004",
            name: "Sanctuary Circle",
            tagline: "A season of rewards for the sanctuary's circle of supporters.",
            startDate: date("2026-10-04"),
            endDate:   date("2026-11-03"),
            milestones: [],
            icon: "trophy.fill",
            accentColor: Color(red: 0.72, green: 0.50, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.96, blue: 0.85),
                Color(red: 0.96, green: 0.85, blue: 0.60),
            ]
        ),
        EventDefinition(
            id: "sanctuary_circle_s3_20261103",
            name: "Sanctuary Circle",
            tagline: "A season of rewards for the sanctuary's circle of supporters.",
            startDate: date("2026-11-03"),
            endDate:   date("2026-12-03"),
            milestones: [],
            icon: "trophy.fill",
            accentColor: Color(red: 0.72, green: 0.50, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.96, blue: 0.85),
                Color(red: 0.96, green: 0.85, blue: 0.60),
            ]
        ),
        // Phase 6c real calendar (Spec_Phase6c_Calendar.md §3.2) — the
        // weekly track, month 1 (instances 1-4 of 13). Alternates between
        // two flavors, "Rescue Relay" and "Playtime Rush", both sharing the
        // exact same free-lane-only milestone table (Adoption Drive's,
        // verbatim — see spec §2.2) and differing only in name/tagline/
        // icon/color. 7-day cadence, 4-day duration, 3-day gap between
        // instances — genuinely non-overlapping with each other, always
        // overlapping Season 1 underneath (see spec §2.1 for the one
        // later instance, not in this batch, that straddles a season
        // boundary).
        EventDefinition(
            id: "rescue_relay_20260904",
            name: "Rescue Relay",
            tagline: "Team up to rescue as many animals as you can this week!",
            startDate: date("2026-09-04"),
            endDate:   date("2026-09-08"),
            milestones: [],
            icon: "figure.run",
            accentColor: Color(red: 0.80, green: 0.35, blue: 0.20),
            gradientColors: [
                Color(red: 1.00, green: 0.92, blue: 0.85),
                Color(red: 0.97, green: 0.78, blue: 0.65),
            ]
        ),
        EventDefinition(
            id: "playtime_rush_20260911",
            name: "Playtime Rush",
            tagline: "Play it up — fulfil orders for bonus rewards this week!",
            startDate: date("2026-09-11"),
            endDate:   date("2026-09-15"),
            milestones: [],
            icon: "star.circle.fill",
            accentColor: Color(red: 0.15, green: 0.55, blue: 0.45),
            gradientColors: [
                Color(red: 0.85, green: 0.97, blue: 0.93),
                Color(red: 0.68, green: 0.90, blue: 0.82),
            ]
        ),
        EventDefinition(
            id: "rescue_relay_20260918",
            name: "Rescue Relay",
            tagline: "Team up to rescue as many animals as you can this week!",
            startDate: date("2026-09-18"),
            endDate:   date("2026-09-22"),
            milestones: [],
            icon: "figure.run",
            accentColor: Color(red: 0.80, green: 0.35, blue: 0.20),
            gradientColors: [
                Color(red: 1.00, green: 0.92, blue: 0.85),
                Color(red: 0.97, green: 0.78, blue: 0.65),
            ]
        ),
        EventDefinition(
            id: "playtime_rush_20260925",
            name: "Playtime Rush",
            tagline: "Play it up — fulfil orders for bonus rewards this week!",
            startDate: date("2026-09-25"),
            endDate:   date("2026-09-29"),
            milestones: [],
            icon: "star.circle.fill",
            accentColor: Color(red: 0.15, green: 0.55, blue: 0.45),
            gradientColors: [
                Color(red: 0.85, green: 0.97, blue: 0.93),
                Color(red: 0.68, green: 0.90, blue: 0.82),
            ]
        ),
    ]

    static var currentEvent: EventDefinition? {
        allEvents.first { $0.isActive }
    }

    /// Every currently-active event — Phase 6c prerequisite, see
    /// specs/Spec_Phase6c_ConcurrentEvents.md §3.1. Routes through
    /// `EventScheduler` (Phase 6a) rather than duplicating its `isActive`
    /// filter inline; this is that scheduler's first real caller. Sorted by
    /// `priority` desc, then `startDate` asc, for stable display order when
    /// rendering more than one at a time (§3.4 — every UI/ViewModel consumer
    /// now reads this instead of `currentEvent` below). `currentEvent`
    /// itself is untouched and can now genuinely diverge from
    /// `activeEvents.first` once real overlap exists (§4's
    /// `foster_weekend_aug2026`, inside Founders' Circle's window) — the two
    /// are no longer guaranteed to agree, only that `currentEvent`, when
    /// non-nil, is always contained somewhere in `activeEvents` (see
    /// `EventSystemTests.testCurrentEventIsAlwaysContainedInActiveEventsWhenNonNil`).
    @MainActor
    static var activeEvents: [EventDefinition] {
        let scheduler = EventScheduler()
        let activeIDs = Set(scheduler.activeEvents(at: Date()))
        return allEvents
            .filter { activeIDs.contains($0.id) }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.startDate < $1.startDate
            }
    }
}

// ============================================================
// MARK: - EVENT TOKEN RIDER (Phase 6b)
// ============================================================

/// Attaches an `.eventToken` reward to a fraction of newly-generated orders
/// while `eventID`'s event is active — the faucet for any track-based event
/// type (Milestone track, Pass). Generic: nothing about this class is
/// milestone-specific, only its original name was (renamed from
/// `MilestoneTrackRiderProvider` in specs/Spec_Phase6b_Pass.md §3.1 so the
/// Pass event type could reuse it instead of a near-duplicate class).
/// Registered/unregistered by `MergeBoardViewModel.checkEventLifecycle()` as
/// the active event changes; never constructed directly by UI code.
///
/// Numbers are a first cut (specs/Spec_Phase6b_MilestoneTrack.md §4), not
/// derived from a model — `riderFrequency` mirrors Phase 2's `.boardItem`
/// recirculation rider, the closest existing precedent.
@MainActor
final class EventTokenRiderProvider: OrderRewardProvider {
    let eventID: String
    let tokensPerRider: Int
    let riderFrequency: Double

    init(eventID: String, tokensPerRider: Int = 20, riderFrequency: Double = 0.33) {
        self.eventID = eventID
        self.tokensPerRider = tokensPerRider
        self.riderFrequency = riderFrequency
    }

    func riders(playerLevel: Int) -> [OrderReward] {
        guard Double.random(in: 0..<1) < riderFrequency else { return [] }
        return [OrderReward(kind: .eventToken, amount: tokensPerRider, payloadID: eventID)]
    }
}
