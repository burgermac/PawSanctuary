//
//  LiveOpsEngine.swift
//  PawSanctuary
//
//  Phase 6a — real implementations behind the LiveOpsPrimitives.swift protocol
//  stubs (Phase 1, Task 1.5). Generic and event-agnostic; nothing in the app
//  calls into these yet. See specs/Spec_Phase6a_Primitives.md.
//

import Foundation

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
