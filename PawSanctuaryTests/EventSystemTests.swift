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

    /// Sanity on the registry's total shape: 4 legacy + 16 new = 20, no
    /// accidental duplicate IDs anywhere (a copy-paste mistake across 20
    /// literal entries is exactly the kind of error this volume invites).
    func testRegistryHasExactlyTwentyUniqueEventIDsNoDuplicates() {
        let allIDs = EventRegistry.allEvents.map(\.id)
        XCTAssertEqual(allIDs.count, 20)
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "duplicate event ID(s) found in EventRegistry.allEvents")
    }
}
