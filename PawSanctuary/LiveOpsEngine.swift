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

/// Ordered milestone lists, keyed by track ID. Empty — no track is authored
/// until Phase 6b (e.g. the Pass event type) defines one.
enum ProgressTrackRegistry {
    static let tracks: [String: [TrackMilestone]] = [:]
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

    // MARK: Persistence

    func restore(from s: GameState) {
        states = s.progressTracks
    }

    func capture(into s: inout GameState) {
        s.progressTracks = states
    }
}
