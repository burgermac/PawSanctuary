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

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

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
    /// reimplementation of its logic — at a fixed, permanent synthetic date
    /// (2026-09-12) deep inside the real 90-day calendar
    /// (`Spec_Phase6c_Calendar.md`), rather than today's real wall clock.
    ///
    /// **Found 18 Aug 2026: this test rotted twice.** The original version
    /// guarded on `EventRegistry.activeEvents` (real `Date()`, not
    /// injectable) actually containing a live overlap right now — first
    /// against `founders_circle_aug2026`/`foster_weekend_aug2026`, and it
    /// self-documented exactly how it would fail once Foster Weekend's
    /// window (2026-08-14...18) closed. It closed, and the test failed
    /// exactly as its own comment predicted. Rather than patch it with
    /// another event that will just expire again later, `checkEventLifecycle`
    /// itself gained an injectable `at date:` parameter (defaulting to
    /// `Date()` for its one production call site) — this test now checks
    /// against 2026-09-12, which sits inside both `sanctuary_circle_s1_20260904`
    /// (2026-09-04...10-04) and `playtime_rush_20260911` (2026-09-11...09-15),
    /// real, already-shipped calendar content that will never change.
    func testCheckEventLifecycleRegistersAnIndependentRiderForEachRealActiveEvent() {
        let testDate = date("2026-09-12")
        let activeIDs = Set(EventScheduler().activeEvents(at: testDate))
        XCTAssertGreaterThanOrEqual(activeIDs.count, 2,
                                     "the fixed test date must sit inside a genuine real overlap")

        let before = Set(OrderRewardRegistry.providers.map(ObjectIdentifier.init))
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: testDate)
        let newProviders = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        defer { newProviders.forEach { OrderRewardRegistry.unregister($0) } }

        let registeredIDs = Set(newProviders.compactMap { ($0 as? EventTokenRiderProvider)?.eventID })
        XCTAssertEqual(registeredIDs, activeIDs,
                       "checkEventLifecycle must register exactly one independent rider per real active event")
    }

    /// The other half of "leaves the other unaffected": a no-op check (same
    /// active events as last time) must not unregister-then-reregister a
    /// still-active rider. Same fixed synthetic date as the test above, for
    /// the same permanence reason.
    func testCheckEventLifecycleIsIdempotentWhenActiveEventsUnchanged() {
        let testDate = date("2026-09-12")
        let activeIDs = EventScheduler().activeEvents(at: testDate)
        XCTAssertFalse(activeIDs.isEmpty, "needs at least one real active event for this test to be meaningful")

        let before = Set(OrderRewardRegistry.providers.map(ObjectIdentifier.init))
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: testDate)
        let afterFirst = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        let identitiesAfterFirst = Set(afterFirst.map(ObjectIdentifier.init))

        vm.checkEventLifecycle(at: testDate)   // second call, same synthetic date -- nothing changed
        let afterSecond = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        let identitiesAfterSecond = Set(afterSecond.map(ObjectIdentifier.init))
        defer { afterSecond.forEach { OrderRewardRegistry.unregister($0) } }

        XCTAssertEqual(identitiesAfterFirst, identitiesAfterSecond,
                       "a no-op check must not unregister and re-register the same still-active riders")
    }

    /// The real-ending half of the same acceptance line, now exercisable
    /// against the real shipped `checkEventLifecycle` for the first time —
    /// LiveOpsEngineTests.swift's `testEndingOneOverlappingEventLeavesTheOtherActive`
    /// covered only the data-source half of this before `at date:` existed
    /// to make `checkEventLifecycle` itself steppable across a time skip.
    /// `playtime_rush_20260911` (2026-09-11...09-15) ends while
    /// `sanctuary_circle_s1_20260904` (2026-09-04...10-04) continues — proves
    /// both that the ended event's rider is unregistered AND that the
    /// surviving event's rider is the same object, not torn down and rebuilt.
    func testCheckEventLifecycleUnregistersOnlyTheEndedEventsRiderWhenOneOfTwoOverlappingEventsEnds() {
        let beforeEnd = date("2026-09-14")   // both sanctuary_circle_s1 and playtime_rush active
        let afterEnd  = date("2026-09-15")   // playtime_rush's window has closed

        let before = Set(OrderRewardRegistry.providers.map(ObjectIdentifier.init))
        let vm = MergeBoardViewModel()

        vm.checkEventLifecycle(at: beforeEnd)
        let afterFirstCheck = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        let seasonProvider = afterFirstCheck.first {
            ($0 as? EventTokenRiderProvider)?.eventID == "sanctuary_circle_s1_20260904"
        }
        XCTAssertNotNil(seasonProvider, "the continuous track's rider must be registered while both are active")
        let seasonProviderIdentity = seasonProvider.map(ObjectIdentifier.init)

        vm.checkEventLifecycle(at: afterEnd)
        let afterSecondCheck = OrderRewardRegistry.providers.filter { !before.contains(ObjectIdentifier($0)) }
        defer { afterSecondCheck.forEach { OrderRewardRegistry.unregister($0) } }

        let registeredIDs = Set(afterSecondCheck.compactMap { ($0 as? EventTokenRiderProvider)?.eventID })
        XCTAssertEqual(registeredIDs, ["sanctuary_circle_s1_20260904"],
                       "playtime_rush_20260911's rider must be unregistered once its window ends")
        let survivingSeasonProvider = afterSecondCheck.first {
            ($0 as? EventTokenRiderProvider)?.eventID == "sanctuary_circle_s1_20260904"
        }
        XCTAssertEqual(survivingSeasonProvider.map(ObjectIdentifier.init), seasonProviderIdentity,
                       "the still-active event's rider must be left alone, not unregistered and re-registered")
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

/// Spec_Phase6c_Calendar.md §3.2 — the weekly track's first 4 instances
/// (month 1: Sep 2026). Static authored data, synthetic query dates, same
/// deterministic approach as SanctuaryCircleSeasonsTests above.
@MainActor
final class WeeklyEventsMonth1Tests: XCTestCase {

    private let weeklyIDs = [
        "rescue_relay_20260904",
        "playtime_rush_20260911",
        "rescue_relay_20260918",
        "playtime_rush_20260925",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func weeklyEvent(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing weekly event \(id)")
    }

    func testAllFourExistInTheRegistry() throws {
        for id in weeklyIDs {
            _ = try weeklyEvent(id)
        }
    }

    /// Each is a 4-day event with a 3-day gap to the next (7-day cadence),
    /// per spec §2.1 — checked directly against dates, not the scheduler,
    /// so a scheduler bug can't cancel out against the same bug in the
    /// data it's reading.
    func testEachIsFourDaysLongWithAThreeDayGapToTheNext() throws {
        // UTC throughout, matching how ISO8601DateFormatter parsed these
        // dates -- a local-timezone Calendar bit the Season span test in
        // §3.1 via the 2026-11-01 DST transition; none of this batch's
        // dates cross that boundary, but pinning to UTC here anyway rather
        // than relying on "this particular set of dates happens to be
        // safe."
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for event in events {
            let days = utcCalendar.dateComponents([.day], from: event.startDate, to: event.endDate).day
            XCTAssertEqual(days, 4, "\(event.id) must run exactly 4 days")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            let gap = utcCalendar.dateComponents([.day], from: a.endDate, to: b.startDate).day
            XCTAssertEqual(gap, 3, "gap between \(a.id) and \(b.id) must be exactly 3 days")
        }
    }

    /// No two of the 4 are ever simultaneously active.
    func testNoTwoOfTheFourOverlap() throws {
        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertLessThanOrEqual(a.endDate, b.startDate,
                                     "\(a.id) and \(b.id) must not overlap")
        }
    }

    /// None of this batch's 4 instances straddle a season boundary (that's
    /// month 2's instance 5, per spec §2.1/§3.3) — each should overlap
    /// Season 1 and only Season 1 throughout its run.
    func testEachOverlapsOnlySeasonOneThroughoutItsRun() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let seasonIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                              "sanctuary_circle_s3_20261103"])
        for id in weeklyIDs {
            let event = try weeklyEvent(id)
            // Sample the event's first and last active day, not just the
            // start instant, since a boundary bug is more likely to show up
            // at the edges than the middle.
            for sampleDate in [event.startDate, event.endDate.addingTimeInterval(-3600)] {
                let activeSeasons = Set(scheduler.activeEvents(at: sampleDate)).intersection(seasonIDs)
                XCTAssertEqual(activeSeasons, ["sanctuary_circle_s1_20260904"],
                               "\(id) at \(sampleDate) must overlap exactly Season 1, not zero or a different season")
            }
        }
    }

    func testEachHasAMatchingProgressTrackMatchingAdoptionDrivesTableVerbatim() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id])
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }
}

/// Spec_Phase6c_Calendar.md §3.3 — the weekly track's next 5 instances
/// (month 2: Oct 2026). This batch contains the one weekly event in the
/// whole calendar that straddles a season boundary — instance 5
/// (rescue_relay_20261002) — so most of the coverage here is specifically
/// about that transition, not just repeating month 1's pattern.
@MainActor
final class WeeklyEventsMonth2Tests: XCTestCase {

    private let weeklyIDs = [
        "rescue_relay_20261002",
        "playtime_rush_20261009",
        "rescue_relay_20261016",
        "playtime_rush_20261023",
        "rescue_relay_20261030",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func weeklyEvent(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing weekly event \(id)")
    }

    func testAllFiveExistInTheRegistry() throws {
        for id in weeklyIDs {
            _ = try weeklyEvent(id)
        }
    }

    func testEachIsFourDaysLongWithAThreeDayGapToTheNext() throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for event in events {
            let days = utcCalendar.dateComponents([.day], from: event.startDate, to: event.endDate).day
            XCTAssertEqual(days, 4, "\(event.id) must run exactly 4 days")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            let gap = utcCalendar.dateComponents([.day], from: a.endDate, to: b.startDate).day
            XCTAssertEqual(gap, 3, "gap between \(a.id) and \(b.id) must be exactly 3 days")
        }
    }

    /// The month 1/month 2 boundary isn't covered by either batch's own
    /// test in isolation — this closes that gap rather than leaving it to
    /// §3.5's full-calendar pass.
    func testGapFromMonthOnesLastInstanceIsAlsoThreeDays() throws {
        let lastOfMonth1 = try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == "playtime_rush_20260925" }))
        let firstOfMonth2 = try weeklyEvent("rescue_relay_20261002")
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let gap = utcCalendar.dateComponents([.day], from: lastOfMonth1.endDate, to: firstOfMonth2.startDate).day
        XCTAssertEqual(gap, 3)
    }

    func testNoTwoOfTheFiveOverlap() throws {
        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertLessThanOrEqual(a.endDate, b.startDate, "\(a.id) and \(b.id) must not overlap")
        }
    }

    /// The straddle itself: rescue_relay_20261002 runs under Season 1 at
    /// its start and Season 2 at its end, per spec §2.1 -- proving the
    /// event ID stays the same while its season partner changes mid-run,
    /// never both seasons at once and never neither.
    func testInstanceFiveStraddlesFromSeasonOneToSeasonTwo() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let seasonIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                              "sanctuary_circle_s3_20261103"])

        let atStart = Set(scheduler.activeEvents(at: date("2026-10-02"))).intersection(seasonIDs)
        XCTAssertEqual(atStart, ["sanctuary_circle_s1_20260904"],
                       "at the straddling event's start, only Season 1 should be active")

        // One hour before its endDate (2026-10-06), safely inside Season 2
        // (which began 2026-10-04).
        let nearEnd = date("2026-10-06").addingTimeInterval(-3600)
        let atEnd = Set(scheduler.activeEvents(at: nearEnd)).intersection(seasonIDs)
        XCTAssertEqual(atEnd, ["sanctuary_circle_s2_20261004"],
                       "near the straddling event's end, only Season 2 should be active")
    }

    /// At the exact instant Season 1 ends and Season 2 begins (2026-10-04),
    /// the straddling event is still active -- total simultaneously-active
    /// count from the seasons+this batch must be exactly 2 (the straddler +
    /// whichever season), never 3, confirming the transition is a clean
    /// handoff rather than a moment of triple overlap.
    func testAtTheSeasonBoundaryInstantOnlyTwoEventsAreActive() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let relevantIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                                "rescue_relay_20261002"])
        let active = Set(scheduler.activeEvents(at: date("2026-10-04"))).intersection(relevantIDs)
        XCTAssertEqual(active, ["sanctuary_circle_s2_20261004", "rescue_relay_20261002"])
    }

    /// Instances 6-8 don't straddle -- ordinary month-1-style containment
    /// within Season 2 throughout.
    func testInstancesSixThroughEightOverlapOnlySeasonTwoThroughoutTheirRun() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let seasonIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                              "sanctuary_circle_s3_20261103"])
        for id in ["playtime_rush_20261009", "rescue_relay_20261016", "playtime_rush_20261023"] {
            let event = try weeklyEvent(id)
            for sampleDate in [event.startDate, event.endDate.addingTimeInterval(-3600)] {
                let activeSeasons = Set(scheduler.activeEvents(at: sampleDate)).intersection(seasonIDs)
                XCTAssertEqual(activeSeasons, ["sanctuary_circle_s2_20261004"],
                               "\(id) at \(sampleDate) must overlap exactly Season 2")
            }
        }
    }

    /// Instance 9 ends exactly as Season 2 ends (2026-11-03) -- contained
    /// cleanly within Season 2, not a second straddle into Season 3.
    func testInstanceNineEndsExactlyWithSeasonTwoNotStraddlingIntoSeasonThree() throws {
        let event = try weeklyEvent("rescue_relay_20261030")
        let season2 = try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == "sanctuary_circle_s2_20261004" }))
        XCTAssertEqual(event.endDate, season2.endDate,
                       "instance 9 should end at exactly the same instant Season 2 ends")

        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let seasonIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                              "sanctuary_circle_s3_20261103"])
        for sampleDate in [event.startDate, event.endDate.addingTimeInterval(-3600)] {
            let activeSeasons = Set(scheduler.activeEvents(at: sampleDate)).intersection(seasonIDs)
            XCTAssertEqual(activeSeasons, ["sanctuary_circle_s2_20261004"],
                           "instance 9 at \(sampleDate) must overlap exactly Season 2, never Season 3")
        }
    }

    func testEachHasAMatchingProgressTrackMatchingAdoptionDrivesTableVerbatim() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id])
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }
}

/// Spec_Phase6c_Calendar.md §3.4 — the weekly track's final 4 instances
/// (month 3: Nov 2026), completing the 13-event weekly track. All 4 sit
/// entirely inside Season 3 — no straddle, same posture as month 1.
@MainActor
final class WeeklyEventsMonth3Tests: XCTestCase {

    private let weeklyIDs = [
        "playtime_rush_20261106",
        "rescue_relay_20261113",
        "playtime_rush_20261120",
        "rescue_relay_20261127",
    ]

    private func weeklyEvent(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing weekly event \(id)")
    }

    func testAllFourExistInTheRegistry() throws {
        for id in weeklyIDs {
            _ = try weeklyEvent(id)
        }
    }

    func testEachIsFourDaysLongWithAThreeDayGapToTheNext() throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for event in events {
            let days = utcCalendar.dateComponents([.day], from: event.startDate, to: event.endDate).day
            XCTAssertEqual(days, 4, "\(event.id) must run exactly 4 days")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            let gap = utcCalendar.dateComponents([.day], from: a.endDate, to: b.startDate).day
            XCTAssertEqual(gap, 3, "gap between \(a.id) and \(b.id) must be exactly 3 days")
        }
    }

    /// The month 2/month 3 boundary isn't covered by either batch's own
    /// test in isolation.
    func testGapFromMonthTwosLastInstanceIsAlsoThreeDays() throws {
        let lastOfMonth2 = try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == "rescue_relay_20261030" }))
        let firstOfMonth3 = try weeklyEvent("playtime_rush_20261106")
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let gap = utcCalendar.dateComponents([.day], from: lastOfMonth2.endDate, to: firstOfMonth3.startDate).day
        XCTAssertEqual(gap, 3)
    }

    func testNoTwoOfTheFourOverlap() throws {
        let events = try weeklyIDs.map { try weeklyEvent($0) }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertLessThanOrEqual(a.endDate, b.startDate, "\(a.id) and \(b.id) must not overlap")
        }
    }

    func testEachOverlapsOnlySeasonThreeThroughoutItsRun() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let seasonIDs = Set(["sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004",
                              "sanctuary_circle_s3_20261103"])
        for id in weeklyIDs {
            let event = try weeklyEvent(id)
            for sampleDate in [event.startDate, event.endDate.addingTimeInterval(-3600)] {
                let activeSeasons = Set(scheduler.activeEvents(at: sampleDate)).intersection(seasonIDs)
                XCTAssertEqual(activeSeasons, ["sanctuary_circle_s3_20261103"],
                               "\(id) at \(sampleDate) must overlap exactly Season 3")
            }
        }
    }

    func testEachHasAMatchingProgressTrackMatchingAdoptionDrivesTableVerbatim() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id])
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }

    /// Capstone for the weekly track as a whole, landing exactly when the
    /// 13th instance does — the full-calendar cross-cutting invariants
    /// (max-2-concurrent day-by-day across all 90 days, etc.) are §3.5's
    /// job, but "all 13 instances actually exist" is cheap to confirm right
    /// here at the moment the set becomes complete.
    func testAllThirteenWeeklyInstancesExistInTheRegistry() {
        let expectedIDs: Set<String> = [
            "rescue_relay_20260904", "playtime_rush_20260911", "rescue_relay_20260918", "playtime_rush_20260925",
            "rescue_relay_20261002", "playtime_rush_20261009", "rescue_relay_20261016",
            "playtime_rush_20261023", "rescue_relay_20261030",
            "playtime_rush_20261106", "rescue_relay_20261113", "playtime_rush_20261120", "rescue_relay_20261127",
        ]
        XCTAssertEqual(expectedIDs.count, 13)
        let actualIDs = Set(EventRegistry.allEvents.map(\.id))
        XCTAssertTrue(expectedIDs.isSubset(of: actualIDs),
                      "missing weekly instances: \(expectedIDs.subtracting(actualIDs))")
    }
}

/// Spec_Phase6c_Calendar.md §3.5 — full-calendar regression tests, the
/// last task in the spec. Distinct from §3.1-§3.4's per-batch spot-checks
/// because these need the whole 90-day calendar assembled to be
/// meaningful — see the spec's own §4: "at no point across the full 90
/// days are more than 2 events simultaneously active" can't be asserted
/// from a partial calendar. All against static authored data with
/// synthetic query dates, per the spec's §4 rationale for why this is
/// stronger verification than the concurrent-events prerequisite's own
/// necessarily wall-clock-guarded tests could offer.
@MainActor
final class FullCalendarRegressionTests: XCTestCase {

    private let seasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
    ]

    private let weeklyIDs: [String] = [
        "rescue_relay_20260904", "playtime_rush_20260911", "rescue_relay_20260918", "playtime_rush_20260925",
        "rescue_relay_20261002", "playtime_rush_20261009", "rescue_relay_20261016",
        "playtime_rush_20261023", "rescue_relay_20261030",
        "playtime_rush_20261106", "rescue_relay_20261113", "playtime_rush_20261120", "rescue_relay_20261127",
    ]

    private var newBatchIDs: Set<String> { seasonIDs.union(weeklyIDs) }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    /// The real invariant this task exists to prove: sampled once per day,
    /// midnight UTC (matching how every date in this calendar was
    /// authored — all transitions land exactly on a day boundary, so a
    /// daily sample can't miss a mid-day change), across the *entire*
    /// 2026-09-04...2026-12-03 span, the simultaneously-active count from
    /// just this new batch never exceeds 2 -- weekly + continuous, never a
    /// 3-way pileup, even through rescue_relay_20261002's straddle.
    func testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        var day = date("2026-09-04")
        let end = date("2026-12-03")
        var maxCount = 0
        var maxDay: Date?
        var sampledDays = 0

        while day < end {
            let active = Set(scheduler.activeEvents(at: day)).intersection(newBatchIDs)
            if active.count > maxCount {
                maxCount = active.count
                maxDay = day
            }
            XCTAssertLessThanOrEqual(active.count, 2,
                                     "more than 2 new-batch events active on \(day): \(active)")
            day = day.addingTimeInterval(86_400)
            sampledDays += 1
        }

        XCTAssertEqual(sampledDays, 90, "must actually sample all 90 days, not silently fewer")
        XCTAssertEqual(maxCount, 2, "expected at least one day to genuinely hit 2 -- if this is < 2, " +
                       "the calendar isn't exercising real overlap and the test below is checking nothing")
        _ = maxDay   // available for debugging a failure; not asserted on directly
    }

    /// Complementary to the above: at every sampled day, *at least* one
    /// season is active (seasons are contiguous with zero gap per §3.1) —
    /// the weekly+continuous pairing never drops to zero either.
    func testAtLeastOneSeasonIsActiveOnEveryDayOfTheNinetyDaySpan() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        var day = date("2026-09-04")
        let end = date("2026-12-03")
        while day < end {
            let activeSeasons = Set(scheduler.activeEvents(at: day)).intersection(seasonIDs)
            XCTAssertEqual(activeSeasons.count, 1, "expected exactly one season active on \(day), got \(activeSeasons)")
            day = day.addingTimeInterval(86_400)
        }
    }

    /// Spec §4's literal "for every pair" — explicit full pairwise check
    /// across all 13, not just adjacent ones or adjacent batches, even
    /// though transitivity from the adjacent-pair checks in §3.2-§3.4
    /// already implies this.
    func testNoTwoOfAllThirteenWeeklyEventsEverOverlapFullPairwise() throws {
        let events = try weeklyIDs.map { id in
            try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing \(id)")
        }
        for i in 0..<events.count {
            for j in (i + 1)..<events.count {
                let a = events[i], b = events[j]
                let noOverlap = a.endDate <= b.startDate || b.endDate <= a.startDate
                XCTAssertTrue(noOverlap, "\(a.id) and \(b.id) overlap")
            }
        }
    }

    /// A gap day — no weekly event active, only the season underneath.
    /// Batch-level tests sampled event start/end edges; none specifically
    /// sampled a quiet day in between.
    func testAGapDayHasOnlyTheSeasonActiveNoWeeklyEvent() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        // 2026-09-09: after instance 1 ends (09-08) and before instance 2
        // starts (09-11) -- squarely inside the 3-day gap.
        let active = Set(scheduler.activeEvents(at: date("2026-09-09"))).intersection(newBatchIDs)
        XCTAssertEqual(active, ["sanctuary_circle_s1_20260904"])
    }

    /// Every one of the 16 new EventDefinition IDs has a matching
    /// ProgressTrackRegistry entry -- an event silently missing its table
    /// would show a card with a permanently-0 maxTokens denominator, a
    /// real and easy-to-miss authoring mistake at this volume (per spec §4).
    func testAllSixteenNewEventsHaveAMatchingProgressTrack() {
        for id in newBatchIDs.sorted() {
            XCTAssertNotNil(ProgressTrackRegistry.tracks[id], "\(id) is missing a ProgressTrackRegistry entry")
        }
        XCTAssertEqual(newBatchIDs.count, 16)
    }

    /// The 4 pre-existing events must be untouched by this whole spec —
    /// still present, same IDs, same shape.
    func testExistingFourLegacyEventsAreUntouched() {
        let expectedLegacyIDs: Set<String> = [
            "rescue_rush_jun2026", "adoption_drive_aug2026", "founders_circle_aug2026", "foster_weekend_aug2026",
        ]
        let actualIDs = Set(EventRegistry.allEvents.map(\.id))
        XCTAssertTrue(expectedLegacyIDs.isSubset(of: actualIDs),
                      "missing legacy events: \(expectedLegacyIDs.subtracting(actualIDs))")
    }

    /// Sanity on the registry's total shape, no accidental duplicate IDs
    /// anywhere (a copy-paste mistake across this many literal entries is
    /// exactly the kind of error this volume invites). A running total, not
    /// a fixed "twenty": 4 legacy + 16 first-calendar entries = 20, plus the
    /// second calendar's additions as they land (Spec_Phase7_Calendar2.md
    /// §3.1: +3 seasons = 23; §3.2: +4 December weekly events = 27;
    /// §3.3: +5 January weekly events = 32; §3.4: +4 February weekly events
    /// = 36, the batch's final EventRegistry total). Third calendar
    /// (Spec_Phase7_Calendar3.md §3.1: +3 seasons = 39; §3.2: +4 March weekly
    /// events = 43). Bump this in the same commit that adds entries.
    func testRegistryHasExpectedRunningTotalOfUniqueEventIDsNoDuplicates() {
        let allIDs = EventRegistry.allEvents.map(\.id)
        XCTAssertEqual(allIDs.count, 43)
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "duplicate event ID(s) found in EventRegistry.allEvents")
    }
}

/// Spec_Phase7_Calendar2.md §3.1 — the second calendar's continuous track:
/// Sanctuary Circle seasons 4-6 (2026-12-03...2027-03-03). Static authored
/// data queried at synthetic, injected dates only — never the wall clock —
/// with every day-count Calendar pinned to UTC (the first calendar's §3.1
/// DST lesson).
@MainActor
final class SanctuaryCircleSeasons2Tests: XCTestCase {

    private let seasonIDs = [
        "sanctuary_circle_s4_20261203",
        "sanctuary_circle_s5_20270102",
        "sanctuary_circle_s6_20270201",
    ]

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func season(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing season \(id)")
    }

    func testAllThreeNewSeasonsExistWithTheSpecifiedDates() throws {
        let expected: [(String, String, String)] = [
            ("sanctuary_circle_s4_20261203", "2026-12-03", "2027-01-02"),
            ("sanctuary_circle_s5_20270102", "2027-01-02", "2027-02-01"),
            ("sanctuary_circle_s6_20270201", "2027-02-01", "2027-03-03"),
        ]
        for (id, start, end) in expected {
            let s = try season(id)
            XCTAssertEqual(s.startDate, date(start), "\(id) start")
            XCTAssertEqual(s.endDate, date(end), "\(id) end")
            XCTAssertEqual(s.name, "Sanctuary Circle")
        }
    }

    /// The batch seam: Season 4 opens the exact instant Season 3 closes.
    func testSeasonThreeEndEqualsSeasonFourStart() throws {
        let s3 = try season("sanctuary_circle_s3_20261103")
        let s4 = try season(seasonIDs[0])
        XCTAssertEqual(s3.endDate, s4.startDate, "Season 3 -> 4 must hand off with zero gap and zero overlap")
    }

    func testSeasonsFourToSixAreContiguousWithZeroGapAndZeroOverlap() throws {
        let s4 = try season(seasonIDs[0])
        let s5 = try season(seasonIDs[1])
        let s6 = try season(seasonIDs[2])
        XCTAssertEqual(s4.endDate, s5.startDate, "Season 4 -> 5 must be contiguous, zero gap")
        XCTAssertEqual(s5.endDate, s6.startDate, "Season 5 -> 6 must be contiguous, zero gap")
    }

    func testSeasonsFourToSixSpanExactlyNinetyDaysThirtyEach() throws {
        let s4 = try season(seasonIDs[0])
        let s6 = try season(seasonIDs[2])
        XCTAssertEqual(utcCalendar.dateComponents([.day], from: s4.startDate, to: s6.endDate).day, 90)
        for id in seasonIDs {
            let s = try season(id)
            XCTAssertEqual(utcCalendar.dateComponents([.day], from: s.startDate, to: s.endDate).day, 30,
                           "\(id) must be 30 days")
        }
    }

    func testEachNewSeasonsMilestoneTableIsAVerbatimCopyOfFoundersCircles() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["founders_circle_aug2026"])
        XCTAssertEqual(reference.count, 10)
        for id in seasonIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Founders' Circle's")
        }
    }

    /// The spec's three sample dates: exactly the matching season is active
    /// among all six seasons.
    func testExactlyTheMatchingSeasonIsActiveAtMidSeasonSampleDates() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let samples: [(String, String)] = [
            ("2026-12-15", "sanctuary_circle_s4_20261203"),
            ("2027-01-15", "sanctuary_circle_s5_20270102"),
            ("2027-02-15", "sanctuary_circle_s6_20270201"),
        ]
        for (iso, expectedID) in samples {
            let active = Set(scheduler.activeEvents(at: date(iso))).intersection(allSeasonIDs)
            XCTAssertEqual(active, [expectedID], "at \(iso), exactly \(expectedID) should be active")
        }
    }

    /// The boundary instants themselves (start inclusive, end exclusive):
    /// exactly one season, never two and never zero.
    func testExactlyOneSeasonIsActiveAtEachSeasonBoundaryInstant() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let boundaries: [(String, String)] = [
            ("2026-12-03", "sanctuary_circle_s4_20261203"),
            ("2027-01-02", "sanctuary_circle_s5_20270102"),
            ("2027-02-01", "sanctuary_circle_s6_20270201"),
        ]
        for (iso, expectedID) in boundaries {
            let active = Set(scheduler.activeEvents(at: date(iso))).intersection(allSeasonIDs)
            XCTAssertEqual(active, [expectedID], "at boundary \(iso)")
        }
    }
}

/// Spec_Phase7_Calendar3.md §3.1 — the third calendar's continuous track:
/// Sanctuary Circle seasons 7-9 (2027-03-03...2027-06-01). Static authored
/// data queried at synthetic, injected dates only — never the wall clock —
/// with every day-count Calendar pinned to UTC (S7 spans both the US 03-14
/// and EU 03-28 spring DST changes).
@MainActor
final class SanctuaryCircleSeasons3Tests: XCTestCase {

    private let seasonIDs = [
        "sanctuary_circle_s7_20270303",
        "sanctuary_circle_s8_20270402",
        "sanctuary_circle_s9_20270502",
    ]

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
        "sanctuary_circle_s7_20270303", "sanctuary_circle_s8_20270402", "sanctuary_circle_s9_20270502",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func season(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing season \(id)")
    }

    func testAllThreeNewSeasonsExistWithTheSpecifiedDates() throws {
        let expected: [(String, String, String)] = [
            ("sanctuary_circle_s7_20270303", "2027-03-03", "2027-04-02"),
            ("sanctuary_circle_s8_20270402", "2027-04-02", "2027-05-02"),
            ("sanctuary_circle_s9_20270502", "2027-05-02", "2027-06-01"),
        ]
        for (id, start, end) in expected {
            let s = try season(id)
            XCTAssertEqual(s.startDate, date(start), "\(id) start")
            XCTAssertEqual(s.endDate, date(end), "\(id) end")
            XCTAssertEqual(s.name, "Sanctuary Circle")
        }
    }

    /// The batch seam: Season 7 opens the exact instant Season 6 closes.
    func testSeasonSixEndEqualsSeasonSevenStart() throws {
        let s6 = try season("sanctuary_circle_s6_20270201")
        let s7 = try season(seasonIDs[0])
        XCTAssertEqual(s6.endDate, s7.startDate, "Season 6 -> 7 must hand off with zero gap and zero overlap")
    }

    func testSeasonsSevenToNineAreContiguousWithZeroGapAndZeroOverlap() throws {
        let s7 = try season(seasonIDs[0])
        let s8 = try season(seasonIDs[1])
        let s9 = try season(seasonIDs[2])
        XCTAssertEqual(s7.endDate, s8.startDate, "Season 7 -> 8 must be contiguous, zero gap")
        XCTAssertEqual(s8.endDate, s9.startDate, "Season 8 -> 9 must be contiguous, zero gap")
    }

    func testSeasonsSevenToNineSpanExactlyNinetyDaysThirtyEach() throws {
        let s7 = try season(seasonIDs[0])
        let s9 = try season(seasonIDs[2])
        XCTAssertEqual(utcCalendar.dateComponents([.day], from: s7.startDate, to: s9.endDate).day, 90)
        for id in seasonIDs {
            let s = try season(id)
            XCTAssertEqual(utcCalendar.dateComponents([.day], from: s.startDate, to: s.endDate).day, 30,
                           "\(id) must be 30 days")
        }
    }

    func testEachNewSeasonsMilestoneTableIsAVerbatimCopyOfFoundersCircles() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["founders_circle_aug2026"])
        XCTAssertEqual(reference.count, 10)
        for id in seasonIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Founders' Circle's")
        }
    }

    func testExactlyTheMatchingSeasonIsActiveAtMidSeasonSampleDates() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let samples: [(String, String)] = [
            ("2027-03-15", "sanctuary_circle_s7_20270303"),
            ("2027-04-15", "sanctuary_circle_s8_20270402"),
            ("2027-05-15", "sanctuary_circle_s9_20270502"),
        ]
        for (iso, expectedID) in samples {
            let active = Set(scheduler.activeEvents(at: date(iso))).intersection(allSeasonIDs)
            XCTAssertEqual(active, [expectedID], "at \(iso), exactly \(expectedID) should be active")
        }
    }

    func testExactlyOneSeasonIsActiveAtEachSeasonBoundaryInstant() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let boundaries: [(String, String)] = [
            ("2027-03-03", "sanctuary_circle_s7_20270303"),
            ("2027-04-02", "sanctuary_circle_s8_20270402"),
            ("2027-05-02", "sanctuary_circle_s9_20270502"),
        ]
        for (iso, expectedID) in boundaries {
            let active = Set(scheduler.activeEvents(at: date(iso))).intersection(allSeasonIDs)
            XCTAssertEqual(active, [expectedID], "at boundary \(iso)")
        }
    }
}

/// Spec_Phase7_Calendar3.md §3.2 — the third calendar's weekly track, month
/// 1 (March, instances 1-4). Static authored data queried at synthetic,
/// injected dates only — never the wall clock — with every day-count
/// Calendar pinned to UTC.
@MainActor
final class WeeklyEvents3Month1Tests: XCTestCase {

    /// In calendar order: Rescue Relay, Playtime Rush, Rescue Relay, Playtime Rush.
    private let weeklyIDs = [
        "rescue_relay_20270305",
        "playtime_rush_20270312",
        "rescue_relay_20270319",
        "playtime_rush_20270326",
    ]

    private let seasonSevenID = "sanctuary_circle_s7_20270303"

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s6_20270201",
        "sanctuary_circle_s7_20270303", "sanctuary_circle_s8_20270402", "sanctuary_circle_s9_20270502",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func event(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing event \(id)")
    }

    private func days(from a: Date, to b: Date) -> Int? {
        utcCalendar.dateComponents([.day], from: a, to: b).day
    }

    func testAllFourExistWithTheSpecifiedDatesAndNames() throws {
        let expected: [(String, String, String, String)] = [
            ("rescue_relay_20270305",  "Rescue Relay",  "2027-03-05", "2027-03-09"),
            ("playtime_rush_20270312", "Playtime Rush", "2027-03-12", "2027-03-16"),
            ("rescue_relay_20270319",  "Rescue Relay",  "2027-03-19", "2027-03-23"),
            ("playtime_rush_20270326", "Playtime Rush", "2027-03-26", "2027-03-30"),
        ]
        for (id, name, start, end) in expected {
            let e = try event(id)
            XCTAssertEqual(e.name, name, "\(id) name")
            XCTAssertEqual(e.startDate, date(start), "\(id) start")
            XCTAssertEqual(e.endDate, date(end), "\(id) end")
        }
    }

    func testEachIsFourDaysLong() throws {
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertEqual(days(from: e.startDate, to: e.endDate), 4, "\(id) must be 4 days")
        }
    }

    func testEachIsFollowedByAThreeDayGapToTheNext() throws {
        for (a, b) in zip(weeklyIDs, weeklyIDs.dropFirst()) {
            let first = try event(a)
            let next = try event(b)
            XCTAssertEqual(days(from: first.endDate, to: next.startDate), 3, "\(a) -> \(b) gap must be 3 days")
        }
    }

    /// The cross-batch seam: the second calendar's last weekly event to the
    /// third calendar's first is the ordinary 3-day off-period.
    func testCrossBatchSeamFromPlaytimeRush20270226IsExactlyThreeDays() throws {
        let lastOfBatchTwo = try event("playtime_rush_20270226")
        let firstOfBatchThree = try event(weeklyIDs[0])
        XCTAssertEqual(days(from: lastOfBatchTwo.endDate, to: firstOfBatchThree.startDate), 3)
    }

    /// Batch 2 ends on Playtime Rush, so batch 3 starts on Rescue Relay and
    /// alternates from there.
    func testFlavorAlternationContinuesAcrossTheBatchSeam() throws {
        let lastOfBatchTwo = try event("playtime_rush_20270226")
        var names = [lastOfBatchTwo.name]
        for id in weeklyIDs { names.append(try event(id).name) }
        XCTAssertEqual(names, ["Playtime Rush", "Rescue Relay", "Playtime Rush", "Rescue Relay", "Playtime Rush"])
        for (a, b) in zip(names, names.dropFirst()) {
            XCTAssertNotEqual(a, b, "consecutive weekly events must alternate flavor")
        }
    }

    func testNoTwoOfTheFourOverlap() throws {
        let events = try weeklyIDs.map { try event($0) }
        for i in events.indices {
            for j in events.indices where j > i {
                let a = events[i], b = events[j]
                XCTAssertFalse(a.startDate < b.endDate && b.startDate < a.endDate,
                               "\(a.id) overlaps \(b.id)")
            }
        }
    }

    /// Each lies wholly inside Season 7, and on every day it runs exactly
    /// Season 7 (no other season) is active underneath.
    func testEachOverlapsExactlySeasonSevenThroughout() throws {
        let s7 = try event(seasonSevenID)
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertGreaterThanOrEqual(e.startDate, s7.startDate, "\(id) starts before Season 7")
            XCTAssertLessThanOrEqual(e.endDate, s7.endDate, "\(id) ends after Season 7")
            var day = e.startDate
            var sampled = 0
            while day < e.endDate {
                let active = Set(scheduler.activeEvents(at: day))
                XCTAssertTrue(active.contains(id), "\(id) should be active at \(day)")
                XCTAssertEqual(active.intersection(allSeasonIDs), [seasonSevenID], "\(id) at \(day)")
                sampled += 1
                day = try XCTUnwrap(utcCalendar.date(byAdding: .day, value: 1, to: day))
            }
            XCTAssertEqual(sampled, 4, "\(id) sampled days")
        }
    }

    func testEachMilestoneTableIsAVerbatimCopyOfAdoptionDrives() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        XCTAssertEqual(reference.count, 3)
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }
}

/// Spec_Phase7_Calendar2.md §3.2 — the second calendar's weekly track, month
/// 1 (December, instances 1-4). Static authored data queried at synthetic,
/// injected dates only — never the wall clock — with every day-count
/// Calendar pinned to UTC.
@MainActor
final class WeeklyEvents2Month1Tests: XCTestCase {

    /// In calendar order: Playtime Rush, Rescue Relay, Playtime Rush, Rescue Relay.
    private let weeklyIDs = [
        "playtime_rush_20261204",
        "rescue_relay_20261211",
        "playtime_rush_20261218",
        "rescue_relay_20261225",
    ]

    private let seasonFourID = "sanctuary_circle_s4_20261203"

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func event(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing event \(id)")
    }

    private func days(from a: Date, to b: Date) -> Int? {
        utcCalendar.dateComponents([.day], from: a, to: b).day
    }

    func testAllFourExistWithTheSpecifiedDatesAndNames() throws {
        let expected: [(String, String, String, String)] = [
            ("playtime_rush_20261204", "Playtime Rush", "2026-12-04", "2026-12-08"),
            ("rescue_relay_20261211",  "Rescue Relay",  "2026-12-11", "2026-12-15"),
            ("playtime_rush_20261218", "Playtime Rush", "2026-12-18", "2026-12-22"),
            ("rescue_relay_20261225",  "Rescue Relay",  "2026-12-25", "2026-12-29"),
        ]
        for (id, name, start, end) in expected {
            let e = try event(id)
            XCTAssertEqual(e.name, name, "\(id) name")
            XCTAssertEqual(e.startDate, date(start), "\(id) start")
            XCTAssertEqual(e.endDate, date(end), "\(id) end")
        }
    }

    func testEachIsFourDaysLong() throws {
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertEqual(days(from: e.startDate, to: e.endDate), 4, "\(id) must be 4 days")
        }
    }

    func testEachIsFollowedByAThreeDayGapToTheNext() throws {
        for (a, b) in zip(weeklyIDs, weeklyIDs.dropFirst()) {
            let first = try event(a)
            let next = try event(b)
            XCTAssertEqual(days(from: first.endDate, to: next.startDate), 3, "\(a) -> \(b) gap must be 3 days")
        }
    }

    /// The cross-batch seam: the first calendar's last weekly event to the
    /// second calendar's first is the ordinary 3-day off-period.
    func testCrossBatchSeamFromRescueRelay20261127IsExactlyThreeDays() throws {
        let lastOfBatchOne = try event("rescue_relay_20261127")
        let firstOfBatchTwo = try event(weeklyIDs[0])
        XCTAssertEqual(days(from: lastOfBatchOne.endDate, to: firstOfBatchTwo.startDate), 3)
    }

    /// Batch 1 ends on Rescue Relay, so batch 2 starts on Playtime Rush and
    /// alternates from there.
    func testFlavorAlternationContinuesAcrossTheBatchSeam() throws {
        let lastOfBatchOne = try event("rescue_relay_20261127")
        var names = [lastOfBatchOne.name]
        for id in weeklyIDs { names.append(try event(id).name) }
        XCTAssertEqual(names, ["Rescue Relay", "Playtime Rush", "Rescue Relay", "Playtime Rush", "Rescue Relay"])
        for (a, b) in zip(names, names.dropFirst()) {
            XCTAssertNotEqual(a, b, "consecutive weekly events must alternate flavor")
        }
    }

    func testNoTwoOfTheFourOverlap() throws {
        let events = try weeklyIDs.map { try event($0) }
        for i in events.indices {
            for j in events.indices where j > i {
                let a = events[i], b = events[j]
                XCTAssertFalse(a.startDate < b.endDate && b.startDate < a.endDate,
                               "\(a.id) overlaps \(b.id)")
            }
        }
    }

    /// Each lies wholly inside Season 4, and on every day it runs exactly
    /// Season 4 (no other season) is active underneath.
    func testEachOverlapsExactlySeasonFourThroughout() throws {
        let s4 = try event(seasonFourID)
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertGreaterThanOrEqual(e.startDate, s4.startDate, "\(id) starts before Season 4")
            XCTAssertLessThanOrEqual(e.endDate, s4.endDate, "\(id) ends after Season 4")
            var day = e.startDate
            var sampled = 0
            while day < e.endDate {
                let active = Set(scheduler.activeEvents(at: day))
                XCTAssertTrue(active.contains(id), "\(id) should be active at \(day)")
                XCTAssertEqual(active.intersection(allSeasonIDs), [seasonFourID], "\(id) at \(day)")
                sampled += 1
                day = try XCTUnwrap(utcCalendar.date(byAdding: .day, value: 1, to: day))
            }
            XCTAssertEqual(sampled, 4, "\(id) sampled days")
        }
    }

    func testEachMilestoneTableIsAVerbatimCopyOfAdoptionDrives() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        XCTAssertEqual(reference.count, 3)
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }
}

/// Spec_Phase7_Calendar2.md §3.3 — the second calendar's weekly track, month
/// 2 (January, instances 5-9). This batch holds both season straddles:
/// instance 5 spans S4 -> S5 (2027-01-02) and instance 9 spans S5 -> S6
/// (2027-02-01). Static authored data queried at synthetic, injected dates
/// only — never the wall clock — with every day-count Calendar pinned to UTC.
@MainActor
final class WeeklyEvents2Month2Tests: XCTestCase {

    /// In calendar order: Playtime Rush, Rescue Relay, Playtime Rush,
    /// Rescue Relay, Playtime Rush.
    private let weeklyIDs = [
        "playtime_rush_20270101",
        "rescue_relay_20270108",
        "playtime_rush_20270115",
        "rescue_relay_20270122",
        "playtime_rush_20270129",
    ]

    private let seasonFourID = "sanctuary_circle_s4_20261203"
    private let seasonFiveID = "sanctuary_circle_s5_20270102"
    private let seasonSixID = "sanctuary_circle_s6_20270201"

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func event(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing event \(id)")
    }

    private func days(from a: Date, to b: Date) -> Int? {
        utcCalendar.dateComponents([.day], from: a, to: b).day
    }

    private func activeSeasons(at iso: String, _ scheduler: EventScheduler) -> Set<String> {
        Set(scheduler.activeEvents(at: date(iso))).intersection(allSeasonIDs)
    }

    func testAllFiveExistWithTheSpecifiedDatesAndNames() throws {
        let expected: [(String, String, String, String)] = [
            ("playtime_rush_20270101", "Playtime Rush", "2027-01-01", "2027-01-05"),
            ("rescue_relay_20270108",  "Rescue Relay",  "2027-01-08", "2027-01-12"),
            ("playtime_rush_20270115", "Playtime Rush", "2027-01-15", "2027-01-19"),
            ("rescue_relay_20270122",  "Rescue Relay",  "2027-01-22", "2027-01-26"),
            ("playtime_rush_20270129", "Playtime Rush", "2027-01-29", "2027-02-02"),
        ]
        for (id, name, start, end) in expected {
            let e = try event(id)
            XCTAssertEqual(e.name, name, "\(id) name")
            XCTAssertEqual(e.startDate, date(start), "\(id) start")
            XCTAssertEqual(e.endDate, date(end), "\(id) end")
        }
    }

    func testEachIsFourDaysLong() throws {
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertEqual(days(from: e.startDate, to: e.endDate), 4, "\(id) must be 4 days")
        }
    }

    func testEachIsFollowedByAThreeDayGapToTheNext() throws {
        for (a, b) in zip(weeklyIDs, weeklyIDs.dropFirst()) {
            let first = try event(a)
            let next = try event(b)
            XCTAssertEqual(days(from: first.endDate, to: next.startDate), 3, "\(a) -> \(b) gap must be 3 days")
        }
    }

    /// Month 1 -> month 2 seam: rescue_relay_20261225 to playtime_rush_20270101
    /// is the ordinary 3-day off-period, and the flavor keeps alternating.
    func testMonthOneToMonthTwoSeamIsExactlyThreeDaysAndAlternates() throws {
        let lastOfMonthOne = try event("rescue_relay_20261225")
        let firstOfMonthTwo = try event(weeklyIDs[0])
        XCTAssertEqual(days(from: lastOfMonthOne.endDate, to: firstOfMonthTwo.startDate), 3)
        var names = [lastOfMonthOne.name]
        for id in weeklyIDs { names.append(try event(id).name) }
        XCTAssertEqual(names, ["Rescue Relay", "Playtime Rush", "Rescue Relay", "Playtime Rush",
                               "Rescue Relay", "Playtime Rush"])
    }

    func testNoTwoOfTheFiveOverlap() throws {
        let events = try weeklyIDs.map { try event($0) }
        for i in events.indices {
            for j in events.indices where j > i {
                let a = events[i], b = events[j]
                XCTAssertFalse(a.startDate < b.endDate && b.startDate < a.endDate,
                               "\(a.id) overlaps \(b.id)")
            }
        }
    }

    /// Straddle 1: instance 5 has exactly S4 underneath on 01-01, and exactly
    /// S5 on 01-02 (the handoff day), 01-03 and 01-04.
    func testInstanceFiveStraddlesSeasonFourToFiveWithExactlyTheRightSeasonUnderneath() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let id = weeklyIDs[0]
        let samples: [(String, String)] = [
            ("2027-01-01", seasonFourID),
            ("2027-01-02", seasonFiveID),
            ("2027-01-03", seasonFiveID),
            ("2027-01-04", seasonFiveID),
        ]
        for (iso, expectedSeason) in samples {
            XCTAssertTrue(scheduler.activeEvents(at: date(iso)).contains(id), "\(id) should be active at \(iso)")
            XCTAssertEqual(activeSeasons(at: iso, scheduler), [expectedSeason], "\(id) at \(iso)")
        }
        XCTAssertFalse(scheduler.activeEvents(at: date("2027-01-05")).contains(id), "\(id) ends 01-05, exclusive")
    }

    /// Straddle 2: instance 9 has exactly S5 underneath on 01-29, 01-30 and
    /// 01-31, and exactly S6 on 02-01 (the handoff day).
    func testInstanceNineStraddlesSeasonFiveToSixWithExactlyTheRightSeasonUnderneath() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let id = weeklyIDs[4]
        let samples: [(String, String)] = [
            ("2027-01-29", seasonFiveID),
            ("2027-01-30", seasonFiveID),
            ("2027-01-31", seasonFiveID),
            ("2027-02-01", seasonSixID),
        ]
        for (iso, expectedSeason) in samples {
            XCTAssertTrue(scheduler.activeEvents(at: date(iso)).contains(id), "\(id) should be active at \(iso)")
            XCTAssertEqual(activeSeasons(at: iso, scheduler), [expectedSeason], "\(id) at \(iso)")
        }
        XCTAssertFalse(scheduler.activeEvents(at: date("2027-02-02")).contains(id), "\(id) ends 02-02, exclusive")
    }

    /// At the exact changeover instants, and one second either side, exactly
    /// 2 EventRegistry events are active (the straddler + one season) —
    /// never 3 (outgoing and incoming season together) and never 1.
    func testExactlyTwoRegistryEventsAreActiveAtEachSeasonChangeoverInstant() throws {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let changeovers: [(String, String, String, String)] = [
            // (boundary, straddler, season before, season from the boundary on)
            ("2027-01-02", weeklyIDs[0], seasonFourID, seasonFiveID),
            ("2027-02-01", weeklyIDs[4], seasonFiveID, seasonSixID),
        ]
        for (iso, straddler, before, after) in changeovers {
            let boundary = date(iso)
            XCTAssertEqual(Set(scheduler.activeEvents(at: boundary)), [straddler, after],
                           "at the \(iso) boundary instant")
            XCTAssertEqual(Set(scheduler.activeEvents(at: boundary.addingTimeInterval(-1))), [straddler, before],
                           "one second before the \(iso) boundary")
            XCTAssertEqual(Set(scheduler.activeEvents(at: boundary.addingTimeInterval(1))), [straddler, after],
                           "one second after the \(iso) boundary")
        }
    }

    /// Instances 6-8 lie wholly inside Season 5, and on every day each runs,
    /// exactly Season 5 is active underneath.
    func testInstancesSixToEightOverlapOnlySeasonFive() throws {
        let s5 = try event(seasonFiveID)
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        for id in weeklyIDs[1...3] {
            let e = try event(id)
            XCTAssertGreaterThanOrEqual(e.startDate, s5.startDate, "\(id) starts before Season 5")
            XCTAssertLessThanOrEqual(e.endDate, s5.endDate, "\(id) ends after Season 5")
            var day = e.startDate
            var sampled = 0
            while day < e.endDate {
                let active = Set(scheduler.activeEvents(at: day))
                XCTAssertTrue(active.contains(id), "\(id) should be active at \(day)")
                XCTAssertEqual(active.intersection(allSeasonIDs), [seasonFiveID], "\(id) at \(day)")
                sampled += 1
                day = try XCTUnwrap(utcCalendar.date(byAdding: .day, value: 1, to: day))
            }
            XCTAssertEqual(sampled, 4, "\(id) sampled days")
        }
    }

    func testEachMilestoneTableIsAVerbatimCopyOfAdoptionDrives() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        XCTAssertEqual(reference.count, 3)
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }
}

/// Spec_Phase7_Calendar2.md §3.4 — the second calendar's weekly track, month
/// 3 (February, instances 10-13). All four lie wholly inside Season 6; no
/// straddle. Instance 13 ends 2027-03-02, one day before Season 6 ends.
/// Static authored data queried at synthetic, injected dates only — never
/// the wall clock — with every day-count Calendar pinned to UTC.
@MainActor
final class WeeklyEvents2Month3Tests: XCTestCase {

    /// In calendar order: Rescue Relay, Playtime Rush, Rescue Relay,
    /// Playtime Rush.
    private let weeklyIDs = [
        "rescue_relay_20270205",
        "playtime_rush_20270212",
        "rescue_relay_20270219",
        "playtime_rush_20270226",
    ]

    /// All 13 weekly events of the second calendar, instances 1-13 in order.
    private let allThirteenWeeklyIDs = [
        "playtime_rush_20261204", "rescue_relay_20261211", "playtime_rush_20261218", "rescue_relay_20261225",
        "playtime_rush_20270101", "rescue_relay_20270108", "playtime_rush_20270115", "rescue_relay_20270122",
        "playtime_rush_20270129",
        "rescue_relay_20270205", "playtime_rush_20270212", "rescue_relay_20270219", "playtime_rush_20270226",
    ]

    private let seasonSixID = "sanctuary_circle_s6_20270201"

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func event(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing event \(id)")
    }

    private func days(from a: Date, to b: Date) -> Int? {
        utcCalendar.dateComponents([.day], from: a, to: b).day
    }

    func testAllFourExistWithTheSpecifiedDatesAndNames() throws {
        let expected: [(String, String, String, String)] = [
            ("rescue_relay_20270205",  "Rescue Relay",  "2027-02-05", "2027-02-09"),
            ("playtime_rush_20270212", "Playtime Rush", "2027-02-12", "2027-02-16"),
            ("rescue_relay_20270219",  "Rescue Relay",  "2027-02-19", "2027-02-23"),
            ("playtime_rush_20270226", "Playtime Rush", "2027-02-26", "2027-03-02"),
        ]
        for (id, name, start, end) in expected {
            let e = try event(id)
            XCTAssertEqual(e.name, name, "\(id) name")
            XCTAssertEqual(e.startDate, date(start), "\(id) start")
            XCTAssertEqual(e.endDate, date(end), "\(id) end")
        }
    }

    /// Includes instance 13 (02-26 -> 03-02), which crosses February 2027's
    /// 28-day month end.
    func testEachIsFourDaysLong() throws {
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertEqual(days(from: e.startDate, to: e.endDate), 4, "\(id) must be 4 days")
        }
    }

    func testEachIsFollowedByAThreeDayGapToTheNext() throws {
        for (a, b) in zip(weeklyIDs, weeklyIDs.dropFirst()) {
            let first = try event(a)
            let next = try event(b)
            XCTAssertEqual(days(from: first.endDate, to: next.startDate), 3, "\(a) -> \(b) gap must be 3 days")
        }
    }

    /// Month 2 -> month 3 seam: playtime_rush_20270129 (ends 02-02) to
    /// rescue_relay_20270205 is the ordinary 3-day off-period, and the flavor
    /// keeps alternating.
    func testMonthTwoToMonthThreeSeamIsExactlyThreeDaysAndAlternates() throws {
        let lastOfMonthTwo = try event("playtime_rush_20270129")
        let firstOfMonthThree = try event(weeklyIDs[0])
        XCTAssertEqual(days(from: lastOfMonthTwo.endDate, to: firstOfMonthThree.startDate), 3)
        var names = [lastOfMonthTwo.name]
        for id in weeklyIDs { names.append(try event(id).name) }
        XCTAssertEqual(names, ["Playtime Rush", "Rescue Relay", "Playtime Rush", "Rescue Relay", "Playtime Rush"])
    }

    func testNoTwoOfTheFourOverlap() throws {
        let events = try weeklyIDs.map { try event($0) }
        for i in events.indices {
            for j in events.indices where j > i {
                let a = events[i], b = events[j]
                XCTAssertFalse(a.startDate < b.endDate && b.startDate < a.endDate,
                               "\(a.id) overlaps \(b.id)")
            }
        }
    }

    /// Each lies wholly inside Season 6, and on every day each runs, exactly
    /// Season 6 is active underneath.
    func testEachLiesInsideSeasonSixWithOnlySeasonSixUnderneath() throws {
        let s6 = try event(seasonSixID)
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        for id in weeklyIDs {
            let e = try event(id)
            XCTAssertGreaterThanOrEqual(e.startDate, s6.startDate, "\(id) starts before Season 6")
            XCTAssertLessThanOrEqual(e.endDate, s6.endDate, "\(id) ends after Season 6")
            var day = e.startDate
            var sampled = 0
            while day < e.endDate {
                let active = Set(scheduler.activeEvents(at: day))
                XCTAssertTrue(active.contains(id), "\(id) should be active at \(day)")
                XCTAssertEqual(active.intersection(allSeasonIDs), [seasonSixID], "\(id) at \(day)")
                sampled += 1
                day = try XCTUnwrap(utcCalendar.date(byAdding: .day, value: 1, to: day))
            }
            XCTAssertEqual(sampled, 4, "\(id) sampled days")
        }
    }

    /// Instance 13 ends 2027-03-02 (exclusive), one day before Season 6
    /// ends: on 03-02 Season 6 alone is active, and the weekly event is not.
    func testInstanceThirteenEndsOneDayBeforeSeasonSix() throws {
        let last = try event(weeklyIDs[3])
        let s6 = try event(seasonSixID)
        XCTAssertEqual(days(from: last.endDate, to: s6.endDate), 1)
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        XCTAssertEqual(Set(scheduler.activeEvents(at: date("2027-03-02"))), [seasonSixID])
    }

    func testEachMilestoneTableIsAVerbatimCopyOfAdoptionDrives() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        XCTAssertEqual(reference.count, 3)
        for id in weeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, reference, "\(id)'s table must exactly match Adoption Drive's")
        }
    }

    /// Capstone for §3.2-§3.4: all 13 of the second calendar's weekly IDs
    /// exist exactly once, with a table, in calendar order with alternating
    /// flavors, each 4 days long and 3 days after the previous one.
    func testCapstoneAllThirteenNewWeeklyIDsExist() throws {
        XCTAssertEqual(allThirteenWeeklyIDs.count, 13)
        XCTAssertEqual(Set(allThirteenWeeklyIDs).count, 13)
        let registryIDs = EventRegistry.allEvents.map(\.id)
        for id in allThirteenWeeklyIDs {
            XCTAssertEqual(registryIDs.filter { $0 == id }.count, 1, "\(id) must appear exactly once")
            XCTAssertNotNil(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
        }
        let events = try allThirteenWeeklyIDs.map { try event($0) }
        for (i, e) in events.enumerated() {
            XCTAssertEqual(e.name, i % 2 == 0 ? "Playtime Rush" : "Rescue Relay", "\(e.id) flavor")
            XCTAssertEqual(days(from: e.startDate, to: e.endDate), 4, "\(e.id) must be 4 days")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertEqual(days(from: a.endDate, to: b.startDate), 3, "\(a.id) -> \(b.id) gap must be 3 days")
        }
    }
}

/// Spec_Phase7_Calendar2.md §3.6 / §4 — full-calendar regression tests for
/// the second 90-day calendar (2026-12-03...2027-03-03). Cross-cutting
/// invariants that only mean something once §3.1-§3.5 are all in: all four
/// event surfaces (EventRegistry, ParallelBoardEventRegistry,
/// KibbleDriveRegistry, ProgressTrackRegistry) queried together. Static
/// authored data at synthetic, injected dates only — never `Date()`,
/// `EventRegistry.activeEvents`, `currentEvent`, `isActive` or
/// `timeRemaining` — and every day-stepping Calendar pinned to UTC. All
/// transitions land on midnight-UTC day boundaries, so a daily sample at
/// midnight UTC cannot miss one. Test-only; no production code.
@MainActor
final class FullCalendar2RegressionTests: XCTestCase {

    private let newSeasonIDs: [String] = [
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private let allSeasonIDs: Set<String> = [
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "sanctuary_circle_s4_20261203", "sanctuary_circle_s5_20270102", "sanctuary_circle_s6_20270201",
    ]

    private let newWeeklyIDs: [String] = [
        "playtime_rush_20261204", "rescue_relay_20261211", "playtime_rush_20261218", "rescue_relay_20261225",
        "playtime_rush_20270101", "rescue_relay_20270108", "playtime_rush_20270115", "rescue_relay_20270122",
        "playtime_rush_20270129",
        "rescue_relay_20270205", "playtime_rush_20270212", "rescue_relay_20270219", "playtime_rush_20270226",
    ]

    /// Last weekly event of the first calendar — the batch seam.
    private let lastFirstCalendarWeeklyID = "rescue_relay_20261127"

    private let newSecondChancesIDs: [String] = [
        "second_chances_20261210", "second_chances_20270109", "second_chances_20270208",
    ]

    private let newKibbleDriveIDs: [String] = [
        "kibble_drive_20261204", "kibble_drive_20270101", "kibble_drive_20270129", "kibble_drive_20270226",
    ]

    /// The 20 EventRegistry entries that existed before this calendar.
    private let existingEventIDs: Set<String> = [
        "rescue_rush_jun2026", "adoption_drive_aug2026", "founders_circle_aug2026", "foster_weekend_aug2026",
        "sanctuary_circle_s1_20260904", "sanctuary_circle_s2_20261004", "sanctuary_circle_s3_20261103",
        "rescue_relay_20260904", "playtime_rush_20260911", "rescue_relay_20260918", "playtime_rush_20260925",
        "rescue_relay_20261002", "playtime_rush_20261009", "rescue_relay_20261016",
        "playtime_rush_20261023", "rescue_relay_20261030",
        "playtime_rush_20261106", "rescue_relay_20261113", "playtime_rush_20261120", "rescue_relay_20261127",
    ]

    private let existingSecondChancesIDs: Set<String> = [
        "second_chances_20260911", "second_chances_20261011", "second_chances_20261110",
    ]

    private let existingKibbleDriveIDs: Set<String> = [
        "kibble_drive_20260911", "kibble_drive_20261009", "kibble_drive_20261106",
    ]

    private var newBatchEventIDs: Set<String> { Set(newSeasonIDs).union(newWeeklyIDs) }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Every midnight-UTC day in [from, to), stepped with a UTC-pinned Calendar.
    private func days(from: String, to: String) -> [Date] {
        var result: [Date] = []
        var day = date(from)
        let end = date(to)
        while day < end {
            result.append(day)
            day = utcCalendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    private func event(_ id: String) throws -> EventDefinition {
        try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == id }), "missing \(id)")
    }

    /// Every active ID across all four surfaces at `day`: EventRegistry via
    /// the injected-date scheduler, plus every Parallel Board and Drive
    /// window counted with `filter` (not `activeEvent(at:)`, which returns
    /// `.first` and would hide an overlap).
    private func allSurfaceActiveIDs(at day: Date) -> (events: Set<String>, parallel: [String], drive: [String]) {
        let events = Set(EventScheduler(events: EventRegistry.allEvents).activeEvents(at: day))
        let parallel = ParallelBoardEventRegistry.allEvents
            .filter { day >= $0.startDate && day < $0.endDate }.map(\.id)
        let drive = KibbleDriveRegistry.allEvents
            .filter { day >= $0.startDate && day < $0.endDate }.map(\.id)
        return (events, parallel, drive)
    }

    // MARK: §4.1

    /// Direct mirror of the first calendar's
    /// `testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive`.
    func testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoBatchTwoEventsActive() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        var maxCount = 0
        var sampledDays = 0
        for day in days(from: "2026-12-03", to: "2027-03-03") {
            let active = Set(scheduler.activeEvents(at: day)).intersection(newBatchEventIDs)
            maxCount = max(maxCount, active.count)
            XCTAssertLessThanOrEqual(active.count, 2, "more than 2 batch-2 events active on \(day): \(active)")
            sampledDays += 1
        }
        XCTAssertEqual(sampledDays, 90, "must actually sample all 90 days, not silently fewer")
        XCTAssertEqual(maxCount, 2, "expected at least one day to genuinely hit 2, or this checks nothing")
    }

    // MARK: §4.2

    func testExactlyOneOfSeasonsFourToSixIsActiveOnEveryDayOfTheNinetyDays() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let sampled = days(from: "2026-12-03", to: "2027-03-03")
        XCTAssertEqual(sampled.count, 90)
        for day in sampled {
            let active = Set(scheduler.activeEvents(at: day)).intersection(newSeasonIDs)
            XCTAssertEqual(active.count, 1, "expected exactly one of S4-S6 on \(day), got \(active)")
        }
    }

    // MARK: §4.3

    /// Across the batch seam: S3's 30 days plus the whole new batch —
    /// proves S3 -> S4 hands off at 2026-12-03 with nothing missing.
    func testExactlyOneSeasonIsActiveOnEveryDayAcrossTheBatchSeam() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let sampled = days(from: "2026-11-03", to: "2027-03-03")
        XCTAssertEqual(sampled.count, 120)
        for day in sampled {
            let active = Set(scheduler.activeEvents(at: day)).intersection(allSeasonIDs)
            XCTAssertEqual(active.count, 1, "expected exactly one season on \(day), got \(active)")
        }
    }

    // MARK: §4.4

    /// Asserted `== 3`, not `<= 3`, so the test checks real gaps — including
    /// the 12-01 -> 12-04 seam between the two calendars.
    func testWeeklyTrackIsNeverDarkLongerThanItsOwnThreeDayCadence() {
        let scheduler = EventScheduler(events: EventRegistry.allEvents)
        let weeklyIDs = Set(newWeeklyIDs).union([lastFirstCalendarWeeklyID])
        var longestDarkRun = 0
        var currentRun = 0
        for day in days(from: "2026-11-27", to: "2027-03-02") {
            let anyWeekly = !Set(scheduler.activeEvents(at: day)).isDisjoint(with: weeklyIDs)
            currentRun = anyWeekly ? 0 : currentRun + 1
            longestDarkRun = max(longestDarkRun, currentRun)
        }
        XCTAssertEqual(longestDarkRun, 3, "weekly track must never be dark longer than its 3-day off-period")
    }

    // MARK: §4.5

    func testNoTwoOfTheThirteenNewWeeklyEventsOverlapAndNoneOverlapsTheBatchOneTail() throws {
        let events = try newWeeklyIDs.map { try event($0) }
        XCTAssertEqual(events.count, 13)
        for i in 0..<events.count {
            for j in (i + 1)..<events.count {
                let a = events[i], b = events[j]
                XCTAssertTrue(a.endDate <= b.startDate || b.endDate <= a.startDate, "\(a.id) and \(b.id) overlap")
            }
        }
        let tail = try event(lastFirstCalendarWeeklyID)
        for e in events {
            XCTAssertTrue(e.endDate <= tail.startDate || tail.endDate <= e.startDate,
                          "\(e.id) overlaps \(tail.id)")
        }
    }

    // MARK: §4.6

    /// Rules 2-3 of spec §2.6 asserted day by day; the all-surface total is
    /// recorded against the construction ceiling of 4 and pinned at this
    /// calendar's observed peak of 3. The `== 3` is a pin on this calendar's
    /// shape, not a product rule (§2.6: no all-surface cap exists) — if a
    /// later calendar intends a 4-way overlap, change the pin.
    func testPerRegistryConcurrencyAndAllSurfaceTotalAcrossTheNinetyDays() {
        var maxAllSurface = 0
        var sampledDays = 0
        for day in days(from: "2026-12-03", to: "2027-03-03") {
            let (events, parallel, drive) = allSurfaceActiveIDs(at: day)
            XCTAssertLessThanOrEqual(parallel.count, 1, "more than 1 Parallel Board active on \(day): \(parallel)")
            XCTAssertLessThanOrEqual(drive.count, 1, "more than 1 Kibble Drive active on \(day): \(drive)")
            let total = events.intersection(newBatchEventIDs).count + parallel.count + drive.count
            XCTAssertLessThanOrEqual(total, 4, "all-surface total above the construction ceiling on \(day)")
            maxAllSurface = max(maxAllSurface, total)
            sampledDays += 1
        }
        XCTAssertEqual(sampledDays, 90)
        XCTAssertEqual(maxAllSurface, 3, "this calendar's all-surface peak is 3 (spec §2.6); a different " +
                       "value means a window was re-dated")
    }

    // MARK: §4.7

    func testEveryNewIDHasItsCorrectReferenceTable() throws {
        let founders = try XCTUnwrap(ProgressTrackRegistry.tracks["founders_circle_aug2026"])
        let adoption = try XCTUnwrap(ProgressTrackRegistry.tracks["adoption_drive_aug2026"])
        let secondChances = try XCTUnwrap(ProgressTrackRegistry.tracks["second_chances_20260911"])
        for id in newSeasonIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, founders, "\(id) must use Founders' Circle's table")
        }
        for id in newWeeklyIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, adoption, "\(id) must use Adoption Drive's table")
        }
        for id in newSecondChancesIDs {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its table")
            XCTAssertEqual(table, secondChances, "\(id) must use second_chances_20260911's table")
        }
        XCTAssertEqual(newSeasonIDs.count + newWeeklyIDs.count, 16)
        XCTAssertEqual(newSecondChancesIDs.count, 3)
    }

    // MARK: §4.8

    func testRegistrySizesHaveNoDuplicatesAndKeepEveryExistingID() {
        let eventIDs = EventRegistry.allEvents.map(\.id)
        let parallelIDs = ParallelBoardEventRegistry.allEvents.map(\.id)
        let driveIDs = KibbleDriveRegistry.allEvents.map(\.id)

        // Subset, not exact: later calendars append to EventRegistry. The exact
        // running total lives in FullCalendarRegressionTests (Calendar 3 §3.1).
        XCTAssertGreaterThanOrEqual(eventIDs.count, 36)
        XCTAssertEqual(parallelIDs.count, 6)
        XCTAssertEqual(driveIDs.count, 7)
        XCTAssertEqual(Set(eventIDs).count, eventIDs.count, "duplicate ID in EventRegistry.allEvents")
        XCTAssertEqual(Set(parallelIDs).count, parallelIDs.count, "duplicate ID in ParallelBoardEventRegistry")
        XCTAssertEqual(Set(driveIDs).count, driveIDs.count, "duplicate ID in KibbleDriveRegistry")

        XCTAssertEqual(existingEventIDs.count, 20)
        XCTAssertTrue(existingEventIDs.isSubset(of: Set(eventIDs)),
                      "missing existing events: \(existingEventIDs.subtracting(eventIDs))")
        XCTAssertTrue(existingSecondChancesIDs.isSubset(of: Set(parallelIDs)),
                      "missing existing Parallel Board windows: \(existingSecondChancesIDs.subtracting(parallelIDs))")
        XCTAssertTrue(existingKibbleDriveIDs.isSubset(of: Set(driveIDs)),
                      "missing existing Drive windows: \(existingKibbleDriveIDs.subtracting(driveIDs))")

        XCTAssertTrue(existingEventIDs.union(newBatchEventIDs).isSubset(of: Set(eventIDs)),
                      "missing Calendar 2 events: \(existingEventIDs.union(newBatchEventIDs).subtracting(eventIDs))")
        XCTAssertEqual(Set(parallelIDs), existingSecondChancesIDs.union(newSecondChancesIDs))
        XCTAssertEqual(Set(driveIDs), existingKibbleDriveIDs.union(newKibbleDriveIDs))
    }

    // MARK: §4.9

    /// Exact active set across all four registries on the spec's five
    /// representative days. Whole EventRegistry, not just batch 2, so a
    /// stray legacy window would also show up.
    func testRepresentativeSpotChecksReturnTheExactActiveSetAcrossAllSurfaces() {
        let expected: [(String, Set<String>)] = [
            // S4 + weekly #1 + Drive
            ("2026-12-04", ["sanctuary_circle_s4_20261203", "playtime_rush_20261204", "kibble_drive_20261204"]),
            // a quiet day: S4 only
            ("2026-12-09", ["sanctuary_circle_s4_20261203"]),
            // S4 + weekly #2 + Second Chances
            ("2026-12-11", ["sanctuary_circle_s4_20261203", "rescue_relay_20261211", "second_chances_20261210"]),
            // straddle boundary: S5 + weekly #5; Drive still active
            ("2027-01-02", ["sanctuary_circle_s5_20270102", "playtime_rush_20270101", "kibble_drive_20270101"]),
            // S6 + weekly #9; Drive just ended (kibble_drive_20270129 ends 02-01, exclusive)
            ("2027-02-01", ["sanctuary_circle_s6_20270201", "playtime_rush_20270129"]),
        ]
        for (iso, want) in expected {
            let (events, parallel, drive) = allSurfaceActiveIDs(at: date(iso))
            XCTAssertEqual(events.union(parallel).union(drive), want, "active set on \(iso)")
            XCTAssertEqual(events.count + parallel.count + drive.count, want.count,
                           "no surface reported a duplicate on \(iso)")
        }
    }
}
