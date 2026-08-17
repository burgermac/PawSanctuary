//
//  LiveOpsEngine.swift
//  PawSanctuary
//
//  Phase 6a — real implementations behind the LiveOpsPrimitives.swift protocol
//  stubs (Phase 1, Task 1.5). Generic and event-agnostic; nothing in the app
//  calls into these yet. See specs/Spec_Phase6a_Primitives.md.
//

import Foundation
import Observation

// ============================================================
// MARK: - 1. Scheduler
// ============================================================

/// Lifecycle, eligibility, and overlap/priority resolution over a list of
/// `EventDefinition`s. Defaults to `EventRegistry.allEvents`; a different list
/// can be injected for testing.
@MainActor
final class EventScheduler: EventScheduling {
    private let events: [EventDefinition]

    init(events: [EventDefinition] = EventRegistry.allEvents) {
        self.events = events
    }

    func activeEvents(at date: Date) -> [String] {
        events.filter { date >= $0.startDate && date < $0.endDate }.map(\.id)
    }

    func isEligible(eventID: String, playerLevel: Int) -> Bool {
        guard let event = events.first(where: { $0.id == eventID }) else { return false }
        return playerLevel >= event.minLevel
    }

    func priority(for eventID: String) -> Int {
        events.first(where: { $0.id == eventID })?.priority ?? 0
    }

    /// The single highest-priority *eligible* active event, or `nil` if none
    /// qualify. Not part of `EventScheduling` — `isEligible` needs a player
    /// level the protocol method doesn't carry, so this takes one directly.
    /// Ties break by earliest `startDate`.
    func contestedSlotWinner(at date: Date, playerLevel: Int) -> String? {
        let eligible = activeEvents(at: date).filter { isEligible(eventID: $0, playerLevel: playerLevel) }
        return eligible
            .compactMap { id in events.first(where: { $0.id == id }).map { (id: id, event: $0) } }
            .max { lhs, rhs in
                if lhs.event.priority != rhs.event.priority { return lhs.event.priority < rhs.event.priority }
                return lhs.event.startDate > rhs.event.startDate   // earlier start wins on a priority tie
            }?.id
    }
}

// ============================================================
// MARK: - 2. Token wallet
// ============================================================

/// Arbitrary named currencies with an end-of-event lifecycle. Owns its state
/// directly and round-trips through `GameState.eventTokenWallets` via
/// restore(from:)/capture(into:) — the same shape `KibbleEngine` uses for
/// kibble/dogTags. Not yet wired into `MergeBoardViewModel` (Phase 6a is
/// machinery only); a future caller instantiates one, calls `restore(from:)`
/// after load and `capture(into:)` before save.
@Observable
@MainActor
final class TokenWallet: TokenWalleting {
    private(set) var wallets: [String: Int] = [:]

    func balance(_ token: String) -> Int { wallets[token] ?? 0 }

    func credit(_ token: String, _ amount: Int) {
        wallets[token, default: 0] += amount
    }

    @discardableResult
    func debit(_ token: String, _ amount: Int) -> Bool {
        guard balance(token) >= amount else { return false }
        wallets[token, default: 0] -= amount
        return true
    }

    /// Removes the token's entry entirely — not just zeroes it, so an expired
    /// event's currency stops existing rather than lingering as a visible `0`.
    func purge(tokensFor eventID: String) {
        wallets.removeValue(forKey: eventID)
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        wallets = s.eventTokenWallets
    }

    func capture(into s: inout GameState) {
        s.eventTokenWallets = wallets
    }
}

// ============================================================
// MARK: - 3. Progress track
// ============================================================

/// Per-track claimed-milestone state. `claimedFree`/`claimedPaid` hold
/// `TrackMilestone.index` values already claimed on that lane.
struct TrackState: Codable, Equatable {
    var progress: Int = 0
    var claimedFree: [Int] = []
    var claimedPaid: [Int] = []
}

/// Ordered milestone lists, keyed by track ID.
enum ProgressTrackRegistry {
    static let tracks: [String: [TrackMilestone]] = [
        // "Adoption Drive" (EventSystem.swift) — Phase 6b screen-verification
        // content. Thresholds/rewards are a first cut (roughly matching
        // rescue_rush_jun2026's 200/450/700 spacing, scaled down since fewer
        // orders carry a rider than earned coins generally), not derived from
        // a model — see specs/Spec_Phase6b_MilestoneTrack.md §4.
        "adoption_drive_aug2026": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        // "Founders' Circle" (EventSystem.swift) — Phase 6b, Pass
        // screen-verification content. First cut, not derived from a model —
        // see specs/Spec_Phase6b_Pass.md §4: 10 milestones at linear steps of
        // 60 tokens (same rider mechanism/frequency as Adoption Drive above,
        // reused via EventTokenRiderProvider), free-lane dog tags gated to
        // the back half, paid-lane roughly 2.2x the free kibble amount plus
        // dog tags throughout, one .cardPack as the final milestone's hero
        // reward.
        "founders_circle_aug2026": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 25)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 55),
                                         OrderReward(kind: .dogTags, amount: 2)]),
            TrackMilestone(index: 1, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 3)]),
            TrackMilestone(index: 2, threshold: 180,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 110),
                                         OrderReward(kind: .dogTags, amount: 4)]),
            TrackMilestone(index: 3, threshold: 240,
                           freeRewards: [OrderReward(kind: .kibble, amount: 60),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 130),
                                         OrderReward(kind: .dogTags, amount: 5)]),
            TrackMilestone(index: 4, threshold: 300,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 165),
                                         OrderReward(kind: .dogTags, amount: 6)]),
            TrackMilestone(index: 5, threshold: 360,
                           freeRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 5)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 200),
                                         OrderReward(kind: .dogTags, amount: 8)]),
            TrackMilestone(index: 6, threshold: 420,
                           freeRewards: [OrderReward(kind: .kibble, amount: 100),
                                         OrderReward(kind: .dogTags, amount: 6)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 220),
                                         OrderReward(kind: .dogTags, amount: 10)]),
            TrackMilestone(index: 7, threshold: 480,
                           freeRewards: [OrderReward(kind: .kibble, amount: 120),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 260),
                                         OrderReward(kind: .dogTags, amount: 12)]),
            TrackMilestone(index: 8, threshold: 540,
                           freeRewards: [OrderReward(kind: .kibble, amount: 140),
                                         OrderReward(kind: .dogTags, amount: 10)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 300),
                                         OrderReward(kind: .dogTags, amount: 15)]),
            TrackMilestone(index: 9, threshold: 600,
                           freeRewards: [OrderReward(kind: .kibble, amount: 160),
                                         OrderReward(kind: .dogTags, amount: 15)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 350),
                                         OrderReward(kind: .dogTags, amount: 20),
                                         OrderReward(kind: .cardPack, amount: 1,
                                                      payloadID: CardPackType.star4.rawValue)]),
        ],
        // "Foster Weekend" (EventSystem.swift) — Phase 6c §4 screen-verification
        // content proving two real events can run concurrently. Free-lane-only,
        // same posture as Adoption Drive above: a short event has no business
        // offering a paid Pass-style unlock of its own. Thresholds scaled down
        // from Adoption Drive's 60/140/220 to fit the shorter 4-day window.
        "foster_weekend_aug2026": [
            TrackMilestone(index: 0, threshold: 40,
                           freeRewards: [OrderReward(kind: .kibble, amount: 30)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 90,
                           freeRewards: [OrderReward(kind: .kibble, amount: 45),
                                         OrderReward(kind: .dogTags, amount: 2)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 150,
                           freeRewards: [OrderReward(kind: .kibble, amount: 70),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: []),
        ],
        // "Second Chances" (ParallelBoardEvents.swift) — Phase 6b, Task 3.7/§5
        // screen-verification content for the Parallel Board event type.
        // Reuses Founders' Circle's own linear-step shape (§4: "reuses §4's
        // Founders' Circle shape as a template") — free-lane-only, 8
        // milestones instead of 10, steps of 20 rather than 60, scaled down
        // for a 3-day board fed by merge-completion tokens
        // (parallelBoardTokensPerCompletion = 10, §3.5) rather than an
        // order-fulfillment rider — 16 top-tier completions clears the whole
        // table, comfortably achievable in 3 days without an economy model
        // run for it (same first-cut posture as every other number in this
        // event type — see Spec_Phase6b_ParallelBoard.md §4).
        "second_chances_20260911": [
            TrackMilestone(index: 0, threshold: 20,
                           freeRewards: [OrderReward(kind: .kibble, amount: 30)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 40,
                           freeRewards: [OrderReward(kind: .kibble, amount: 35)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40),
                                         OrderReward(kind: .dogTags, amount: 2)],
                           paidRewards: []),
            TrackMilestone(index: 3, threshold: 80,
                           freeRewards: [OrderReward(kind: .kibble, amount: 45),
                                         OrderReward(kind: .dogTags, amount: 2)],
                           paidRewards: []),
            TrackMilestone(index: 4, threshold: 100,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 5, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 55),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 6, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 60),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: []),
            TrackMilestone(index: 7, threshold: 160,
                           freeRewards: [OrderReward(kind: .kibble, amount: 80),
                                         OrderReward(kind: .dogTags, amount: 6)],
                           paidRewards: []),
        ],
        // "Sanctuary Circle" seasons 1-3 (EventSystem.swift) — Phase 6c real
        // calendar (Spec_Phase6c_Calendar.md §2.2/§3.1). Verbatim reuse of
        // Founders' Circle's 10-milestone table above, re-keyed per season
        // since progress is ID-keyed (a shared ID across seasons would make
        // a later season open already-maxed from an earlier one's
        // progress). Deliberately not re-derived or varied season to
        // season — see the spec's own §0/§2.2 on avoiding new unmodelled
        // numbers where an already-reviewed curve can be reused instead.
        "sanctuary_circle_s1_20260904": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 25)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 55),
                                         OrderReward(kind: .dogTags, amount: 2)]),
            TrackMilestone(index: 1, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 3)]),
            TrackMilestone(index: 2, threshold: 180,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 110),
                                         OrderReward(kind: .dogTags, amount: 4)]),
            TrackMilestone(index: 3, threshold: 240,
                           freeRewards: [OrderReward(kind: .kibble, amount: 60),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 130),
                                         OrderReward(kind: .dogTags, amount: 5)]),
            TrackMilestone(index: 4, threshold: 300,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 165),
                                         OrderReward(kind: .dogTags, amount: 6)]),
            TrackMilestone(index: 5, threshold: 360,
                           freeRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 5)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 200),
                                         OrderReward(kind: .dogTags, amount: 8)]),
            TrackMilestone(index: 6, threshold: 420,
                           freeRewards: [OrderReward(kind: .kibble, amount: 100),
                                         OrderReward(kind: .dogTags, amount: 6)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 220),
                                         OrderReward(kind: .dogTags, amount: 10)]),
            TrackMilestone(index: 7, threshold: 480,
                           freeRewards: [OrderReward(kind: .kibble, amount: 120),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 260),
                                         OrderReward(kind: .dogTags, amount: 12)]),
            TrackMilestone(index: 8, threshold: 540,
                           freeRewards: [OrderReward(kind: .kibble, amount: 140),
                                         OrderReward(kind: .dogTags, amount: 10)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 300),
                                         OrderReward(kind: .dogTags, amount: 15)]),
            TrackMilestone(index: 9, threshold: 600,
                           freeRewards: [OrderReward(kind: .kibble, amount: 160),
                                         OrderReward(kind: .dogTags, amount: 15)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 350),
                                         OrderReward(kind: .dogTags, amount: 20),
                                         OrderReward(kind: .cardPack, amount: 1,
                                                      payloadID: CardPackType.star4.rawValue)]),
        ],
        "sanctuary_circle_s2_20261004": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 25)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 55),
                                         OrderReward(kind: .dogTags, amount: 2)]),
            TrackMilestone(index: 1, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 3)]),
            TrackMilestone(index: 2, threshold: 180,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 110),
                                         OrderReward(kind: .dogTags, amount: 4)]),
            TrackMilestone(index: 3, threshold: 240,
                           freeRewards: [OrderReward(kind: .kibble, amount: 60),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 130),
                                         OrderReward(kind: .dogTags, amount: 5)]),
            TrackMilestone(index: 4, threshold: 300,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 165),
                                         OrderReward(kind: .dogTags, amount: 6)]),
            TrackMilestone(index: 5, threshold: 360,
                           freeRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 5)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 200),
                                         OrderReward(kind: .dogTags, amount: 8)]),
            TrackMilestone(index: 6, threshold: 420,
                           freeRewards: [OrderReward(kind: .kibble, amount: 100),
                                         OrderReward(kind: .dogTags, amount: 6)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 220),
                                         OrderReward(kind: .dogTags, amount: 10)]),
            TrackMilestone(index: 7, threshold: 480,
                           freeRewards: [OrderReward(kind: .kibble, amount: 120),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 260),
                                         OrderReward(kind: .dogTags, amount: 12)]),
            TrackMilestone(index: 8, threshold: 540,
                           freeRewards: [OrderReward(kind: .kibble, amount: 140),
                                         OrderReward(kind: .dogTags, amount: 10)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 300),
                                         OrderReward(kind: .dogTags, amount: 15)]),
            TrackMilestone(index: 9, threshold: 600,
                           freeRewards: [OrderReward(kind: .kibble, amount: 160),
                                         OrderReward(kind: .dogTags, amount: 15)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 350),
                                         OrderReward(kind: .dogTags, amount: 20),
                                         OrderReward(kind: .cardPack, amount: 1,
                                                      payloadID: CardPackType.star4.rawValue)]),
        ],
        "sanctuary_circle_s3_20261103": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 25)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 55),
                                         OrderReward(kind: .dogTags, amount: 2)]),
            TrackMilestone(index: 1, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 3)]),
            TrackMilestone(index: 2, threshold: 180,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 110),
                                         OrderReward(kind: .dogTags, amount: 4)]),
            TrackMilestone(index: 3, threshold: 240,
                           freeRewards: [OrderReward(kind: .kibble, amount: 60),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 130),
                                         OrderReward(kind: .dogTags, amount: 5)]),
            TrackMilestone(index: 4, threshold: 300,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 4)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 165),
                                         OrderReward(kind: .dogTags, amount: 6)]),
            TrackMilestone(index: 5, threshold: 360,
                           freeRewards: [OrderReward(kind: .kibble, amount: 90),
                                         OrderReward(kind: .dogTags, amount: 5)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 200),
                                         OrderReward(kind: .dogTags, amount: 8)]),
            TrackMilestone(index: 6, threshold: 420,
                           freeRewards: [OrderReward(kind: .kibble, amount: 100),
                                         OrderReward(kind: .dogTags, amount: 6)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 220),
                                         OrderReward(kind: .dogTags, amount: 10)]),
            TrackMilestone(index: 7, threshold: 480,
                           freeRewards: [OrderReward(kind: .kibble, amount: 120),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 260),
                                         OrderReward(kind: .dogTags, amount: 12)]),
            TrackMilestone(index: 8, threshold: 540,
                           freeRewards: [OrderReward(kind: .kibble, amount: 140),
                                         OrderReward(kind: .dogTags, amount: 10)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 300),
                                         OrderReward(kind: .dogTags, amount: 15)]),
            TrackMilestone(index: 9, threshold: 600,
                           freeRewards: [OrderReward(kind: .kibble, amount: 160),
                                         OrderReward(kind: .dogTags, amount: 15)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 350),
                                         OrderReward(kind: .dogTags, amount: 20),
                                         OrderReward(kind: .cardPack, amount: 1,
                                                      payloadID: CardPackType.star4.rawValue)]),
        ],
        // "Rescue Relay" / "Playtime Rush" (EventSystem.swift) — Phase 6c
        // real calendar, weekly track month 1 (Spec_Phase6c_Calendar.md
        // §2.2/§3.2). Verbatim reuse of Adoption Drive's 3-milestone table
        // above, re-keyed per instance since progress is ID-keyed. Both
        // flavors share this exact table — deliberate, not an oversight,
        // see the spec's own §6 on why no new number was invented here.
        "rescue_relay_20260904": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "playtime_rush_20260911": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "rescue_relay_20260918": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "playtime_rush_20260925": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        // Weekly track, month 2 (Spec_Phase6c_Calendar.md §3.3). Same
        // verbatim Adoption Drive table as month 1 above.
        "rescue_relay_20261002": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "playtime_rush_20261009": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "rescue_relay_20261016": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "playtime_rush_20261023": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "rescue_relay_20261030": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        // Weekly track, month 3 (Spec_Phase6c_Calendar.md §3.4) — completes
        // the 13-event weekly track. Same verbatim Adoption Drive table as
        // months 1 and 2 above.
        "playtime_rush_20261106": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "rescue_relay_20261113": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "playtime_rush_20261120": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
        "rescue_relay_20261127": [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 50)],
                           paidRewards: []),
            TrackMilestone(index: 1, threshold: 140,
                           freeRewards: [OrderReward(kind: .kibble, amount: 75),
                                         OrderReward(kind: .dogTags, amount: 3)],
                           paidRewards: []),
            TrackMilestone(index: 2, threshold: 220,
                           freeRewards: [OrderReward(kind: .kibble, amount: 150),
                                         OrderReward(kind: .dogTags, amount: 8)],
                           paidRewards: []),
        ],
    ]
}

/// Ordered milestones with parallel free/paid lanes. Owns its state directly
/// and round-trips through `GameState.progressTracks` via
/// restore(from:)/capture(into:), same shape as `TokenWallet`. Not yet wired
/// into `MergeBoardViewModel`.
@Observable
@MainActor
final class ProgressTrack: ProgressTracking {
    private var states: [String: TrackState] = [:]
    private let registry: [String: [TrackMilestone]]

    init(registry: [String: [TrackMilestone]] = ProgressTrackRegistry.tracks) {
        self.registry = registry
    }

    func progress(trackID: String) -> Int {
        states[trackID]?.progress ?? 0
    }

    func advance(trackID: String, by amount: Int) {
        states[trackID, default: TrackState()].progress += amount
    }

    /// Every milestone reached whose relevant lane still has an unclaimed
    /// reward. The free lane counts regardless of `paidLaneUnlocked`; the paid
    /// lane only counts when it's `true` — so a milestone whose free reward is
    /// already claimed and whose paid lane isn't unlocked drops out entirely,
    /// even past threshold.
    func claimable(trackID: String, paidLaneUnlocked: Bool) -> [TrackMilestone] {
        let milestones = registry[trackID] ?? []
        let state = states[trackID] ?? TrackState()
        return milestones.filter { milestone in
            guard milestone.threshold <= state.progress else { return false }
            let freeAvailable = !state.claimedFree.contains(milestone.index)
            let paidAvailable = paidLaneUnlocked && !state.claimedPaid.contains(milestone.index)
            return freeAvailable || paidAvailable
        }
    }

    /// Idempotent — claiming an already-claimed lane returns `[]`, not the
    /// same rewards again.
    func claim(trackID: String, milestone: Int, paidLane: Bool) -> [OrderReward] {
        guard let def = registry[trackID]?.first(where: { $0.index == milestone }) else { return [] }
        var state = states[trackID] ?? TrackState()
        guard def.threshold <= state.progress else { return [] }

        if paidLane {
            guard !state.claimedPaid.contains(milestone) else { return [] }
            state.claimedPaid.append(milestone)
            states[trackID] = state
            return def.paidRewards
        } else {
            guard !state.claimedFree.contains(milestone) else { return [] }
            state.claimedFree.append(milestone)
            states[trackID] = state
            return def.freeRewards
        }
    }

    /// Whether `milestone`'s reward on `lane` has already been claimed. Not
    /// part of `ProgressTracking` — `claimable`'s OR-combined design (the free
    /// lane counts regardless of paid-lane state) can answer "is *something*
    /// claimable here" but can't disentangle which lane once both a UI needs
    /// to render simultaneously (Phase 6b, Pass — two lanes on screen at
    /// once, specs/Spec_Phase6b_Pass.md §3.5), since OR isn't invertible: if
    /// the free lane is still available, `claimable(paidLaneUnlocked: true)`
    /// reads `true` whether or not the paid lane specifically is claimed.
    func isClaimed(trackID: String, milestone: Int, paidLane: Bool) -> Bool {
        let state = states[trackID] ?? TrackState()
        return paidLane ? state.claimedPaid.contains(milestone) : state.claimedFree.contains(milestone)
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        states = s.progressTracks
    }

    func capture(into s: inout GameState) {
        s.progressTracks = states
    }

    #if DEBUG
    /// Dev-only full reset — see `MergeBoardViewModel.resetToFreshGame()`.
    func reset() {
        states = [:]
    }
    #endif
}

// ============================================================
// MARK: - 4. Reward table
// ============================================================

/// Weighted-random reward payloads, keyed by table ID. No persisted state —
/// a roll is consumed immediately by the caller, same as
/// `SubObjectSystem.weightedRarityRoll`, whose weight-bucket pattern this
/// mirrors. `tables` defaults to an empty static registry — no table is
/// authored until content needs one (Phase 6b, or migrating the existing
/// hardcoded chest payout — see specs/Spec_Phase6a_Primitives.md §5).
///
/// An instantiable type rather than the enum-of-statics shape
/// `OrderRewardRegistry` uses: `RewardTabling`'s requirements are instance
/// methods, and an enum can't satisfy those with `static func`s.
@MainActor
final class RewardTableRegistry: RewardTabling {
    static let defaultTables: [String: [WeightedReward]] = [:]

    private let tables: [String: [WeightedReward]]

    init(tables: [String: [WeightedReward]] = RewardTableRegistry.defaultTables) {
        self.tables = tables
    }

    func table(_ id: String) -> [WeightedReward] {
        tables[id] ?? []
    }

    func roll(tableID: String) -> [OrderReward] {
        let entries = table(tableID)
        let total = entries.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }

        var roll = Double.random(in: 0..<Double(total))
        for entry in entries {
            roll -= Double(entry.weight)
            if roll < 0 { return entry.rewards }
        }
        return entries.last?.rewards ?? []
    }
}

// ============================================================
// MARK: - 5. Timer service
// ============================================================

/// Countdowns, deadlines, and expiry notifications for events. `remaining`/
/// `isUrgent` delegate to `EventDefinition`'s existing computed properties;
/// an unrecognised ID reads as "not remaining, not urgent" rather than
/// trapping — a stale notification firing after an event left the registry
/// is a real scenario, not a bug. Notification scheduling is a thin wrapper
/// over `NotificationManager.scheduleEventExpiry`, resolving the summary
/// from the event's own name/tagline since the protocol method carries no
/// summary parameter.
@MainActor
final class EventTimer: EventTiming {
    private let events: [EventDefinition]

    init(events: [EventDefinition] = EventRegistry.allEvents) {
        self.events = events
    }

    func remaining(eventID: String) -> TimeInterval {
        events.first(where: { $0.id == eventID })?.timeRemaining ?? 0
    }

    func isUrgent(eventID: String) -> Bool {
        events.first(where: { $0.id == eventID })?.isUrgent ?? false
    }

    func scheduleExpiryNotification(eventID: String, at date: Date) {
        guard let event = events.first(where: { $0.id == eventID }) else { return }
        NotificationManager.shared.scheduleEventExpiry(
            eventID: eventID, at: date, summary: "\(event.name) — \(event.tagline)")
    }
}

// ============================================================
// MARK: - 6. Offer hook
// ============================================================

/// Lets an active event register its own offers. In-memory only, same
/// registration-list shape as `OrderRewardRegistry` (Phase 1.2) — nothing
/// here needs to survive a save: an active event re-registers its offers on
/// every launch while it's live.
@MainActor
final class OfferHookRegistry: OfferHooking {
    private var offersByEvent: [String: [String]] = [:]

    func registerOffer(eventID: String, offerID: String) {
        guard !(offersByEvent[eventID] ?? []).contains(offerID) else { return }
        offersByEvent[eventID, default: []].append(offerID)
    }

    func activeOffers() -> [String] {
        offersByEvent.values.flatMap { $0 }
    }

    /// Not part of `OfferHooking` — internal cleanup on event expiry, the
    /// same asymmetry `TokenWalleting.purge` has over `credit`/`debit`.
    func unregister(offersFor eventID: String) {
        offersByEvent.removeValue(forKey: eventID)
    }
}
