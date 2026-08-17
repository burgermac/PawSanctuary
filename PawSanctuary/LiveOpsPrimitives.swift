//
//  LiveOpsPrimitives.swift
//  PawSanctuary
//
//  Phase 1, Task 1.5 — protocols and value types only, no implementations.
//  Nothing conforms to these yet. They exist so Phase 6 has a target and so
//  nothing is built against a shape that will change.
//
//  All protocols are @MainActor: every implementation in the codebase follows
//  the domain-coordinator pattern (see KibbleEngine, InventoryStore) of a
//  @MainActor @Observable class, and Swift 6 strict concurrency requires the
//  isolation to be declared on the protocol for that conformance to compile.
//

import Foundation

// 1. Scheduler — lifecycle, eligibility, and overlap/priority resolution.
@MainActor
protocol EventScheduling {
    func activeEvents(at date: Date) -> [String]        // event IDs
    func isEligible(eventID: String, playerLevel: Int) -> Bool
    /// Which event owns a contested UI slot when several are active.
    func priority(for eventID: String) -> Int
}

// 2. Token wallet — arbitrary named currencies with an end-of-event lifecycle.
@MainActor
protocol TokenWalleting {
    func balance(_ token: String) -> Int
    func credit(_ token: String, _ amount: Int)
    func debit(_ token: String, _ amount: Int) -> Bool
    func purge(tokensFor eventID: String)
}

// 3. Progress track — ordered milestones, supporting parallel free/paid lanes.
struct TrackMilestone: Codable, Equatable {
    var index: Int
    var threshold: Int
    var freeRewards: [OrderReward]
    var paidRewards: [OrderReward]
}

@MainActor
protocol ProgressTracking {
    func progress(trackID: String) -> Int
    func advance(trackID: String, by amount: Int)
    func claimable(trackID: String, paidLaneUnlocked: Bool) -> [TrackMilestone]
    func claim(trackID: String, milestone: Int, paidLane: Bool) -> [OrderReward]
}

// 4. Reward table — weighted random payloads. Every variable-ratio reward routes here.
struct WeightedReward: Codable, Equatable {
    var weight: Int
    var rewards: [OrderReward]
}

@MainActor
protocol RewardTabling {
    func roll(tableID: String) -> [OrderReward]
    func table(_ id: String) -> [WeightedReward]
}

// 5. Timer service — countdowns, deadlines, expiry, and attached notifications.
@MainActor
protocol EventTiming {
    func remaining(eventID: String) -> TimeInterval
    func isUrgent(eventID: String) -> Bool
    func scheduleExpiryNotification(eventID: String, at date: Date)
}

// 6. Offer hook — lets an active event register its own offers.
@MainActor
protocol OfferHooking {
    func registerOffer(eventID: String, offerID: String)
    func activeOffers() -> [String]
}

// 7. Rider injection — see OrderRewardRegistry.swift (Task 1.2).
