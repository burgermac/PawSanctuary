//
//  ParallelBoardEventsTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Task 3.7 — coverage for ParallelBoardEventDefinition's date-window
//  logic, tested against synthetic instances. §5 adds coverage for the real
//  registered "Second Chances" test event further down.
//

import XCTest
@testable import PawSanctuary

final class ParallelBoardEventsTests: XCTestCase {

    private func makeEvent(startOffset: TimeInterval, endOffset: TimeInterval) -> ParallelBoardEventDefinition {
        ParallelBoardEventDefinition(
            id: "test_event", name: "Test Event", icon: "star.fill", chainID: "parallelboard.test",
            startDate: Date().addingTimeInterval(startOffset),
            endDate: Date().addingTimeInterval(endOffset))
    }

    func testIsActiveWhenNowIsInsideTheWindow() {
        let event = makeEvent(startOffset: -3600, endOffset: 3600)
        XCTAssertTrue(event.isActive)
    }

    func testIsNotActiveBeforeStartDate() {
        let event = makeEvent(startOffset: 3600, endOffset: 7200)
        XCTAssertFalse(event.isActive)
    }

    func testIsNotActiveAtOrAfterEndDate() {
        let event = makeEvent(startOffset: -7200, endOffset: -3600)
        XCTAssertFalse(event.isActive)
    }

    func testTimeRemainingNeverGoesNegativeAfterEndDate() {
        let event = makeEvent(startOffset: -7200, endOffset: -3600)
        XCTAssertEqual(event.timeRemaining, 0)
    }

    func testIsUrgentWhenLessThanAnHourRemains() {
        let event = makeEvent(startOffset: -3600, endOffset: 1800)
        XCTAssertTrue(event.isUrgent)
    }

    func testIsNotUrgentWithMoreThanAnHourRemaining() {
        let event = makeEvent(startOffset: -3600, endOffset: 7200)
        XCTAssertFalse(event.isUrgent)
    }

}

// MARK: - §5 "Second Chances" test event

final class ParallelBoardSecondChancesEventTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func secondChances() throws -> ParallelBoardEventDefinition {
        try XCTUnwrap(ParallelBoardEventRegistry.allEvents.first(where: { $0.id == "second_chances_20260911" }))
    }

    func testExistsInTheRegistry() throws {
        _ = try secondChances()
    }

    func testRunsExactlyThreeDays() throws {
        let event = try secondChances()
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let days = utcCalendar.dateComponents([.day], from: event.startDate, to: event.endDate).day
        XCTAssertEqual(days, 3, "D5-cadence-compliant per §5's own recommendation")
    }

    func testDatesMatchTheSpecRecommendedWindow() throws {
        let event = try secondChances()
        XCTAssertEqual(event.startDate, date("2026-09-11"))
        XCTAssertEqual(event.endDate, date("2026-09-14"))
    }

    /// The deliberate three-way concurrency case §5 called for: this event
    /// sits fully inside Sanctuary Circle Season 1's window and fully
    /// overlaps Playtime Rush's second weekly instance.
    func testFullyOverlapsSanctuaryCircleSeason1() throws {
        let event = try secondChances()
        let season1 = try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == "sanctuary_circle_s1_20260904" }))
        XCTAssertGreaterThanOrEqual(event.startDate, season1.startDate)
        XCTAssertLessThanOrEqual(event.endDate, season1.endDate)
    }

    func testFullyOverlapsPlaytimeRushsSecondWeeklyInstance() throws {
        let event = try secondChances()
        let playtimeRush = try XCTUnwrap(EventRegistry.allEvents.first(where: { $0.id == "playtime_rush_20260911" }))
        XCTAssertLessThanOrEqual(event.startDate, playtimeRush.endDate)
        XCTAssertGreaterThanOrEqual(event.endDate, playtimeRush.startDate)
        // Genuinely overlapping, not just adjacent — both windows share a
        // real span of time, matching §5's "all genuinely active at once."
        let overlapStart = max(event.startDate, playtimeRush.startDate)
        let overlapEnd = min(event.endDate, playtimeRush.endDate)
        XCTAssertLessThan(overlapStart, overlapEnd)
    }

    func testChainIsRegisteredWithFiveTiers() throws {
        let event = try secondChances()
        let chain = try XCTUnwrap(ContentRegistry.shared.chain(event.chainID))
        XCTAssertEqual(chain.tiers.count, 5)
        XCTAssertEqual(chain.id, ContentRegistry.parallelBoardSecondChancesChainID)
    }

    func testProgressTrackHasEightFreeLaneOnlyMilestonesWithLinearThresholds() throws {
        let milestones = try XCTUnwrap(ProgressTrackRegistry.tracks["second_chances_20260911"])
        XCTAssertEqual(milestones.count, 8)
        for milestone in milestones {
            XCTAssertTrue(milestone.paidRewards.isEmpty, "free-lane-only, per §5")
        }
        let thresholds = milestones.sorted(by: { $0.index < $1.index }).map(\.threshold)
        XCTAssertEqual(thresholds, [20, 40, 60, 80, 100, 120, 140, 160])
    }

    /// §5's whole point: 16 top-tier completions (the table's max threshold
    /// divided by parallelBoardTokensPerCompletion) must be achievable —
    /// this is the arithmetic tie between §3.5's earning rate and this
    /// table's top milestone, not just an isolated fact about either.
    func testTopMilestoneIsReachableInARoundNumberOfCompletions() throws {
        let milestones = try XCTUnwrap(ProgressTrackRegistry.tracks["second_chances_20260911"])
        let topThreshold = try XCTUnwrap(milestones.map(\.threshold).max())
        XCTAssertEqual(topThreshold % parallelBoardTokensPerCompletion, 0)
        XCTAssertEqual(topThreshold / parallelBoardTokensPerCompletion, 16)
    }
}
