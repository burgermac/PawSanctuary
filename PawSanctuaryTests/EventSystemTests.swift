//
//  EventSystemTests.swift
//  PawSanctuaryTests
//
//  Phase 6b — coverage for concrete event-type logic (as opposed to the
//  generic Phase 6a primitives, covered in LiveOpsEngineTests.swift).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EventTokenRiderProviderTests: XCTestCase {

    func testRidersCarryTheDeclaredEventTokenAndAmount() {
        let provider = EventTokenRiderProvider(eventID: "test_event", tokensPerRider: 20,
                                                riderFrequency: 1.0)   // always fires
        let riders = provider.riders(playerLevel: 1)
        XCTAssertEqual(riders, [OrderReward(kind: .eventToken, amount: 20, payloadID: "test_event")])
    }

    func testNeverFiresWhenFrequencyIsZero() {
        let provider = EventTokenRiderProvider(eventID: "test_event", riderFrequency: 0)
        for _ in 0..<100 {
            XCTAssertEqual(provider.riders(playerLevel: 1), [])
        }
    }

    /// Statistical: matches the tolerance style used for RewardTableRegistry's
    /// distribution test (LiveOpsEngineTests.swift) -- same no-injected-RNG
    /// convention, so this is inherently probabilistic.
    func testRiderFrequencyMatchesTheDeclaredRate() {
        let provider = EventTokenRiderProvider(eventID: "test_event", riderFrequency: 0.33)
        let trials = 20_000
        var fired = 0
        for _ in 0..<trials {
            if !provider.riders(playerLevel: 1).isEmpty { fired += 1 }
        }
        let observed = Double(fired) / Double(trials)
        XCTAssertEqual(observed, 0.33, accuracy: 0.03,
                       "expected ~33% of orders to carry a rider, observed \(observed * 100)%")
    }
}

/// Regression coverage for the time-of-check/time-of-use gap found reviewing
/// the shipped Pass feature: applyPurchase used to read activeEvent?.id only
/// after the async StoreKit purchase resolved, which can silently drop the
/// unlock if the active event's window closes mid-purchase (a real, if
/// narrow, "charged, nothing granted" bug — the purchase-sheet confirmation
/// is a genuinely unbounded wait). Fixed by capturing the event at button-tap
/// time into pendingEventPassEventID, which applyPurchase now prefers.
///
/// activeEvent (EventRegistry.currentEvent) isn't injectable — it's driven by
/// the real wall clock against a hardcoded event list — so these tests only
/// exercise what's reliably assertable regardless of today's date: that the
/// captured pending ID wins over whatever activeEvent says, and that it's
/// consumed rather than leaking into an unrelated later purchase.
@MainActor
final class EventPassPurchaseTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testPurchaseUnlocksThePendingCapturedEventRegardlessOfWhateverIsCurrentlyActive() {
        let vm = makeViewModel()
        vm.pendingEventPassEventID = "some_far_future_test_event"

        vm.applyPurchase(.eventPass, priceUSD: 4.99)

        XCTAssertTrue(vm.passUnlockedEventIDs.contains("some_far_future_test_event"),
                       "must unlock the event captured at purchase time, not whatever activeEvent resolves to now")
    }

    func testPendingEventIDIsClearedAfterBeingConsumed() {
        let vm = makeViewModel()
        vm.pendingEventPassEventID = "some_test_event"

        vm.applyPurchase(.eventPass, priceUSD: 4.99)

        XCTAssertNil(vm.pendingEventPassEventID,
                     "must not leak into a later, unrelated purchase")
    }

    func testNonEventPassPurchaseDoesNotTouchThePendingEventID() {
        let vm = makeViewModel()
        vm.pendingEventPassEventID = "an_in_flight_event_pass_purchase"

        vm.applyPurchase(.kibbleSmall, priceUSD: 0.99)

        XCTAssertEqual(vm.pendingEventPassEventID, "an_in_flight_event_pass_purchase",
                       "an unrelated purchase completing mid-flight must not clear or consume it")
    }
}

/// Phase 6c prerequisite (specs/Spec_Phase6c_ConcurrentEvents.md §3.1) —
/// EventRegistry.activeEvents isn't injectable either, same constraint noted
/// above for currentEvent: real wall clock, hardcoded event list. These
/// assert invariants that hold regardless of today's date, rather than which
/// specific event is active right now.
@MainActor
final class EventRegistryActiveEventsTests: XCTestCase {

    func testActiveEventsIsASubsetOfAllEvents() {
        let allIDs = Set(EventRegistry.allEvents.map(\.id))
        for event in EventRegistry.activeEvents {
            XCTAssertTrue(allIDs.contains(event.id))
        }
    }

    func testActiveEventsMatchesIndependentlyReimplementedIsActiveFilter() {
        // Deliberately re-derives the filter here rather than calling
        // EventDefinition.isActive, so a bug in activeEvents' EventScheduler
        // wiring can't cancel out against the same bug in the property under
        // test.
        let now = Date()
        let expectedIDs = Set(EventRegistry.allEvents
            .filter { now >= $0.startDate && now < $0.endDate }
            .map(\.id))
        let actualIDs = Set(EventRegistry.activeEvents.map(\.id))
        XCTAssertEqual(actualIDs, expectedIDs)
    }

    func testActiveEventsIsSortedByPriorityThenStartDate() {
        let events = EventRegistry.activeEvents
        for (a, b) in zip(events, events.dropFirst()) {
            if a.priority != b.priority {
                XCTAssertGreaterThan(a.priority, b.priority)
            } else {
                XCTAssertLessThanOrEqual(a.startDate, b.startDate)
            }
        }
    }

    /// Today's real event list never has two events overlap, so the new
    /// list-returning property and the old single-winner property must
    /// always agree while that holds — a regression guard for this task's
    /// "no behavior change yet" claim, not a test of the production calendar.
    func testActiveEventsAgreesWithCurrentEventWhileNoneOverlap() {
        XCTAssertEqual(EventRegistry.activeEvents.first?.id, EventRegistry.currentEvent?.id)
    }
}
