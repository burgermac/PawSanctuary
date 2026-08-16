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

    /// Superseded by Spec_Phase6c_ConcurrentEvents.md §4: the real registry
    /// now has genuine overlap (`foster_weekend_aug2026` inside Founders'
    /// Circle's window), so `activeEvents.first` and `currentEvent` are no
    /// longer guaranteed to agree — sort order and array-declaration order
    /// can differ once more than one event is active. What must still hold
    /// unconditionally, independent of which real events happen to be active
    /// at test-run time: `currentEvent` (`allEvents.first { isActive }`) can
    /// never point at an event `activeEvents` (every active event) doesn't
    /// also contain.
    func testCurrentEventIsAlwaysContainedInActiveEventsWhenNonNil() {
        guard let currentID = EventRegistry.currentEvent?.id else { return }
        XCTAssertTrue(EventRegistry.activeEvents.map(\.id).contains(currentID))
    }
}

/// Spec_Phase6c_ConcurrentEvents.md §5 acceptance: "Both events' order-token
/// riders fire independently" and "ending one of the two overlapping events
/// leaves the other's ... rider unaffected." Nothing exercised
/// `OrderRewardRegistry` with more than one simultaneously-registered
/// `EventTokenRiderProvider` before this — the mechanism (`flatMap` over
/// every registered provider) was tested in isolation per-provider, never
/// together, which is exactly the gap this task closes.
@MainActor
final class ConcurrentEventRiderRegistrationTests: XCTestCase {

    /// Direct, deterministic proof (riderFrequency 1.0, matching the
    /// existing single-provider convention in EventTokenRiderProviderTests)
    /// that two simultaneously-registered providers both fire on the same
    /// call — neither one starves the other by occupying a shared slot,
    /// which is the exact bug this task fixed (previously only one
    /// `activeEventRiderProvider` could ever be registered at a time).
    func testOrderRewardRegistryFiresRidersForMultipleSimultaneouslyRegisteredEvents() {
        let providerA = EventTokenRiderProvider(eventID: "test_event_a", tokensPerRider: 20, riderFrequency: 1.0)
        let providerB = EventTokenRiderProvider(eventID: "test_event_b", tokensPerRider: 15, riderFrequency: 1.0)
        OrderRewardRegistry.register(providerA)
        OrderRewardRegistry.register(providerB)
        defer {
            OrderRewardRegistry.unregister(providerA)
            OrderRewardRegistry.unregister(providerB)
        }

        let riders = OrderRewardRegistry.riders(playerLevel: 1)

        XCTAssertTrue(riders.contains(OrderReward(kind: .eventToken, amount: 20, payloadID: "test_event_a")))
        XCTAssertTrue(riders.contains(OrderReward(kind: .eventToken, amount: 15, payloadID: "test_event_b")))
    }

    /// Exercises the real, shipped `checkEventLifecycle()` — not a
    /// reimplementation of its logic — against today's real calendar, which
    /// genuinely has two overlapping events (`founders_circle_aug2026`,
    /// `foster_weekend_aug2026`, Spec_Phase6c §4). `EventRegistry.activeEvents`
    /// isn't injectable, so this guards on real overlap actually existing
    /// right now rather than silently passing once Foster Weekend's window
    /// (2026-08-14...18) closes -- if this guard fires, the fix is a fresh
    /// overlapping test event, not a change to the assertion.
    func testCheckEventLifecycleRegistersAnIndependentRiderForEachRealActiveEvent() {
        let activeIDs = Set(EventRegistry.activeEvents.map(\.id))
        guard activeIDs.count >= 2 else {
            XCTFail("""
                Needs >= 2 genuinely-overlapping real events to prove anything. \
                Today's EventRegistry.activeEvents: \(activeIDs). Foster \
                Weekend's window (2026-08-14...18) may have closed -- add a \
                fresh overlapping EventDefinition to re-enable this test.
                """)
            return
        }

        let before = Set(OrderRewardRegistry.providers.map(ObjectIdentifier.init))
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle()
        let newProviders = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        defer { newProviders.forEach { OrderRewardRegistry.unregister($0) } }

        let registeredIDs = Set(newProviders.compactMap { ($0 as? EventTokenRiderProvider)?.eventID })
        XCTAssertEqual(registeredIDs, activeIDs,
                       "checkEventLifecycle must register exactly one independent rider per real active event")
    }

    /// The other half of "leaves the other unaffected": a no-op check (same
    /// active events as last time) must not unregister-then-reregister a
    /// still-active rider. Doesn't exercise a real event actually ending
    /// (EventRegistry.activeEvents isn't injectable, and waiting for Foster
    /// Weekend's real 2026-08-18 end date isn't practical here) but does
    /// prove checkEventLifecycle's "leave unchanged ones alone" branch holds
    /// against the real registry, using the real shipped method.
    func testCheckEventLifecycleIsIdempotentWhenActiveEventsUnchanged() {
        let activeIDs = EventRegistry.activeEvents.map(\.id)
        guard !activeIDs.isEmpty else {
            XCTFail("needs at least one real active event for this test to be meaningful")
            return
        }

        let before = Set(OrderRewardRegistry.providers.map(ObjectIdentifier.init))
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle()
        let afterFirst = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        let identitiesAfterFirst = Set(afterFirst.map(ObjectIdentifier.init))

        vm.checkEventLifecycle()   // second call, nothing changed in EventRegistry.activeEvents
        let afterSecond = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        let identitiesAfterSecond = Set(afterSecond.map(ObjectIdentifier.init))
        defer { afterSecond.forEach { OrderRewardRegistry.unregister($0) } }

        XCTAssertEqual(identitiesAfterFirst, identitiesAfterSecond,
                       "a no-op check must not unregister and re-register the same still-active riders")
    }
}

/// Spec_Phase6c_Calendar.md §3.1 — the continuous track's 3 sequential
/// Sanctuary Circle seasons. Unlike the concurrent-events prerequisite's
/// tests, this is static authored data with real, fixed dates, so these
/// checks are fully deterministic against synthetic query dates rather than
/// the real wall clock — the calendar spec's own §4 flags this as stronger
/// verification than the prerequisite could offer for its own tests.
@MainActor
final class SanctuaryCircleSeasonsTests: XCTestCase {

    private let seasonIDs = [
        "sanctuary_circle_s1_20260904",
        "sanctuary_circle_s2_20261004",
        "sanctuary_circle_s3_20261103",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func season(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing season \(id)")
    }

    func testAllThreeSeasonsExistInTheRegistry() throws {
        for id in seasonIDs {
            _ = try season(id)
        }
    }

    func testSeasonsAreContiguousWithZeroGapAndZeroOverlap() throws {
        let s1 = try season(seasonIDs[0])
        let s2 = try season(seasonIDs[1])
        let s3 = try season(seasonIDs[2])

        XCTAssertEqual(s1.endDate, s2.startDate, "Season 1 -> 2 must be contiguous, zero gap")
        XCTAssertEqual(s2.endDate, s3.startDate, "Season 2 -> 3 must be contiguous, zero gap")
    }

    func testSeasonsSpanExactlyNinetyDays() throws {
        let s1 = try season(seasonIDs[0])
        let s3 = try season(seasonIDs[2])
        // Dates are parsed by ISO8601DateFormatter, which defaults to UTC --
        // the day-count Calendar must match that timezone, not the device's
        // local one, or a DST transition between the two dates (the US
        // clocks fall back 2026-11-01, squarely inside this span) silently
        // shifts the wall-clock delta by an hour and rounds the day count
        // down by one.
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let days = utcCalendar.dateComponents([.day], from: s1.startDate, to: s3.endDate).day
        XCTAssertEqual(days, 90)
    }

    func testEachSeasonHasAMatchingProgressTrackOfTenMilestones() {
        for id in seasonIDs {
            XCTAssertEqual(ProgressTrackRegistry.tracks[id]?.count, 10,
                           "\(id) must have a 10-milestone table (Founders' Circle's shape)")
        }
    }

    /// Spec §2.2: every season's table is a *verbatim* reuse of Founders'
    /// Circle's, not independently re-derived numbers that happen to look
    /// similar.
    func testEachSeasonsMilestoneTableIsAVerbatimCopyOfFoundersCircles() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["founders_circle_aug2026"])
        for id in seasonIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id])
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Founders' Circle's")
        }
    }

    /// Confirms the scheduler-level data source agrees with the raw dates
    /// checked above — at a representative date inside each season, that
    /// season (and only that season, among the 3) is reported active.
    func testExactlyOneSeasonActiveAtASampleDateWithinEachSeason() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let sampleDates = [
            seasonIDs[0]: date("2026-09-15"),
            seasonIDs[1]: date("2026-10-15"),
            seasonIDs[2]: date("2026-11-15"),
        ]
        for (expectedID, sampleDate) in sampleDates {
            let activeSeasons = Set(scheduler.activeEvents(at: sampleDate)).intersection(seasonIDs)
            XCTAssertEqual(activeSeasons, [expectedID],
                           "at \(sampleDate), exactly \(expectedID) among the 3 seasons should be active")
        }
    }
}
