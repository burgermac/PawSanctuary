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
//
// TrackState is declared here (backing GameState.progressTracks, added in the
// same v30 migration as the token wallet above); ProgressTrack itself — the
// ProgressTracking conformance — lands in the next commit.

/// Per-track claimed-milestone state. `claimedFree`/`claimedPaid` hold
/// `TrackMilestone.index` values already claimed on that lane.
struct TrackState: Codable, Equatable {
    var progress: Int = 0
    var claimedFree: [Int] = []
    var claimedPaid: [Int] = []
}
