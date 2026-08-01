//
//  LiveOpsEngineTests.swift
//  PawSanctuaryTests
//
//  Phase 6a — coverage for the real primitive implementations behind
//  LiveOpsPrimitives.swift. Each primitive is tested standalone, with no
//  dependency on MergeBoardViewModel (nothing wires these in yet).
//

import XCTest
import SwiftUI
@testable import PawSanctuary

@MainActor
final class EventSchedulerTests: XCTestCase {

    private func day(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func makeEvent(id: String, start: String, end: String,
                            minLevel: Int = 0, priority: Int = 0) -> EventDefinition {
        EventDefinition(
            id: id, name: id, tagline: "", startDate: day(start), endDate: day(end),
            milestones: [], icon: "star.fill", accentColor: .blue, gradientColors: [.blue, .white],
            minLevel: minLevel, priority: priority
        )
    }

    func testActiveEventsReturnsEveryOverlappingEvent() {
        let events = [
            makeEvent(id: "weekly", start: "2026-08-01", end: "2026-08-05"),
            makeEvent(id: "pass",   start: "2026-07-15", end: "2026-08-14"),
            makeEvent(id: "past",   start: "2026-01-01", end: "2026-01-02"),
        ]
        let scheduler = EventScheduler(events: events)
        let active = Set(scheduler.activeEvents(at: day("2026-08-02")))
        XCTAssertEqual(active, ["weekly", "pass"])
    }

    func testIsEligibleGatesOnMinLevel() {
        let events = [makeEvent(id: "highLevel", start: "2026-08-01", end: "2026-08-05", minLevel: 20)]
        let scheduler = EventScheduler(events: events)
        XCTAssertFalse(scheduler.isEligible(eventID: "highLevel", playerLevel: 5))
        XCTAssertTrue(scheduler.isEligible(eventID: "highLevel", playerLevel: 20))
        XCTAssertFalse(scheduler.isEligible(eventID: "unknown", playerLevel: 999))
    }

    func testPriorityLooksUpTheDeclaredValue() {
        let events = [makeEvent(id: "a", start: "2026-08-01", end: "2026-08-05", priority: 7)]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.priority(for: "a"), 7)
        XCTAssertEqual(scheduler.priority(for: "unknown"), 0)
    }

    func testContestedSlotWinnerPicksHighestPriority() {
        let events = [
            makeEvent(id: "low",  start: "2026-08-01", end: "2026-08-05", priority: 1),
            makeEvent(id: "high", start: "2026-08-01", end: "2026-08-05", priority: 5),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 99), "high")
    }

    func testContestedSlotWinnerExcludesIneligibleEvents() {
        let events = [
            makeEvent(id: "highPriorityLocked", start: "2026-08-01", end: "2026-08-05", minLevel: 50, priority: 10),
            makeEvent(id: "openLowPriority",    start: "2026-08-01", end: "2026-08-05", minLevel: 0,  priority: 1),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 5), "openLowPriority")
    }

    func testContestedSlotWinnerBreaksTiesByEarliestStart() {
        let events = [
            makeEvent(id: "later",   start: "2026-08-03", end: "2026-08-10", priority: 3),
            makeEvent(id: "earlier", start: "2026-08-01", end: "2026-08-10", priority: 3),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-04"), playerLevel: 99), "earlier")
    }

    func testContestedSlotWinnerIsNilWhenNothingQualifies() {
        let scheduler = EventScheduler(events: [])
        XCTAssertNil(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 99))
    }
}
