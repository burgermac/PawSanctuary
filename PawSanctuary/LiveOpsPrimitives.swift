//
//  LiveOpsPrimitives.swift
//  PawSanctuary
//
//  Phase 1, Task 1.5 — protocols and value types only, no implementations.
//  Nothing conforms to these yet. They exist so Phase 6 has a target and so
//  nothing is built against a shape that will change.
//

import Foundation

// 1. Scheduler — lifecycle, eligibility, and overlap/priority resolution.
protocol EventScheduling {
    func activeEvents(at date: Date) -> [String]        // event IDs
    func isEligible(eventID: String, playerLevel: Int) -> Bool
    /// Which event owns a contested UI slot when several are active.
    func priority(for eventID: String) -> Int
}

// 2. Token wallet — arbitrary named currencies with an end-of-event lifecycle.
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

protocol RewardTabling {
    func roll(tableID: String) -> [OrderReward]
    func table(_ id: String) -> [WeightedReward]
}

// 5. Timer service — countdowns, deadlines, expiry, and attached notifications.
protocol EventTiming {
    func remaining(eventID: String) -> TimeInterval
    func isUrgent(eventID: String) -> Bool
    func scheduleExpiryNotification(eventID: String, at date: Date)
}

// 6. Offer hook — lets an active event register its own offers.
protocol OfferHooking {
    func registerOffer(eventID: String, offerID: String)
    func activeOffers() -> [String]
}

// 7. Parallel board instance — a second board with its own chains, energy and offers.
protocol ParallelBoardHosting {
    func makeBoard(eventID: String) -> UUID
    func teardownBoard(eventID: String)
    func energyBalance(eventID: String) -> Int
}

// 8. Rider injection — see OrderRewardRegistry.swift (Task 1.2).
