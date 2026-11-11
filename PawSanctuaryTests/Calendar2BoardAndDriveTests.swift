//
//  Calendar2BoardAndDriveTests.swift
//  PawSanctuaryTests
//
//  Phase 7 second calendar (specs/Spec_Phase7_Calendar2.md §3.5) — the
//  Parallel Board ("Second Chances") and Kibble Drive windows for
//  2026-12-03 → 2027-03-03.
//
//  Every date here is injected and fixed. Nothing reads Date(): lifecycle
//  tests that depend on wall-clock time rot the moment the window they relied
//  on closes (TODO.md's resolved test-rot entry). Day arithmetic uses a UTC
//  calendar, matching how the registries parse their ISO dates.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class Calendar2BoardAndDriveTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func days(from a: Date, to b: Date) -> Int? {
        utc.dateComponents([.day], from: a, to: b).day
    }

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Parallel Board

    /// §2.4: each new instance starts exactly 7 days into its paired season.
    func testEachNewSecondChancesStartsSevenDaysIntoItsSeason() throws {
        let pairs = [
            "second_chances_20261210": "sanctuary_circle_s4_20261203",
            "second_chances_20270109": "sanctuary_circle_s5_20270102",
            "second_chances_20270208": "sanctuary_circle_s6_20270201",
        ]
        for (eventID, seasonID) in pairs {
            let event = try XCTUnwrap(ParallelBoardEventRegistry.allEvents.first { $0.id == eventID },
                                      "missing \(eventID)")
            let season = try XCTUnwrap(EventRegistry.allEvents.first { $0.id == seasonID },
                                       "missing \(seasonID)")
            XCTAssertEqual(days(from: season.startDate, to: event.startDate), 7,
                           "\(eventID) must start 7 days into \(seasonID)")
            XCTAssertEqual(days(from: event.startDate, to: event.endDate), 3, "\(eventID) runs 3 days")
        }
    }

    /// §2.7: reward-curve reuse, not new numbers — each new table is the
    /// Season 1 table verbatim (rewards included, not just thresholds).
    func testEachNewSecondChancesTableEqualsTheSeasonOneTable() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["second_chances_20260911"])
        for id in ["second_chances_20261210", "second_chances_20270109", "second_chances_20270208"] {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its progress track")
            XCTAssertEqual(table, reference, "\(id) must copy the 8-milestone table verbatim")
        }
    }

    /// §2.4: the 11-13 → 12-10 dark period is by design (one instance per
    /// season) and gets no window.
    func testTheGapBeforeTheFirstNewSecondChancesHasNoWindow() {
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2026-11-20")))
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2026-12-05")))
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2026-12-09")),
                     "the day before the S4 instance opens")
        XCTAssertEqual(ParallelBoardEventRegistry.activeEvent(at: date("2026-12-10"))?.id,
                       "second_chances_20261210", "opens on its start day")
    }

    // MARK: Kibble Drive

    /// §2.5: 28-day spacing kept unchanged (owner decision), counted from the
    /// last shipped Drive.
    func testEachNewDriveStartsExactlyTwentyEightDaysAfterThePreviousOne() throws {
        let chain = [
            "kibble_drive_20261106",
            "kibble_drive_20261204",
            "kibble_drive_20270101",
            "kibble_drive_20270129",
            "kibble_drive_20270226",
        ]
        let events = try chain.map { id in
            try XCTUnwrap(KibbleDriveRegistry.allEvents.first { $0.id == id }, "missing \(id)")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertEqual(days(from: a.startDate, to: b.startDate), 28,
                           "\(b.id) must start 28 days after \(a.id)")
            XCTAssertEqual(days(from: b.startDate, to: b.endDate), 3, "\(b.id) runs 3 days")
        }
    }

    /// No extra Drive before 1 Dec (owner kept the 28-day spacing): nothing
    /// opens between the end of `kibble_drive_20261106` and 2026-12-04.
    func testNoDriveWindowOpensBetweenNovemberNinthAndDecemberFourth() {
        let gapStart = date("2026-11-09")
        let gapEnd = date("2026-12-04")
        let opening = KibbleDriveRegistry.allEvents.filter { $0.startDate >= gapStart && $0.startDate < gapEnd }
        XCTAssertEqual(opening.map(\.id), [], "no Drive may open inside the 11-09 → 12-04 gap")

        var day = gapStart
        while day < gapEnd {
            XCTAssertNil(KibbleDriveRegistry.activeEvent(at: day), "no Drive should be active on \(day)")
            day = utc.date(byAdding: .day, value: 1, to: day)!
        }
        XCTAssertEqual(KibbleDriveRegistry.activeEvent(at: gapEnd)?.id, "kibble_drive_20261204")
    }

    // MARK: Lifecycle at injected dates

    /// 2026-12-05: inside `kibble_drive_20261204`, before the S4 Second Chances.
    func testLifecycleOnDecemberFifthCreatesTheDriveAndNoParallelBoard() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2026-12-05"))

        let drive = try XCTUnwrap(vm.kibbleDrive, "a Drive window is open")
        XCTAssertEqual(drive.eventID, "kibble_drive_20261204")
        XCTAssertEqual(drive.points, 0, "a new Drive starts empty")
        XCTAssertNil(vm.activeParallelBoardEvent, "no Second Chances window is open on 12-05")
    }

    /// 2026-12-11: inside `second_chances_20261210`; the 12-04 Drive ended 12-07.
    func testLifecycleOnDecemberEleventhCreatesTheParallelBoardAndNoDrive() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2026-12-11"))

        let coordinator = try XCTUnwrap(vm.activeParallelBoardEvent, "a Second Chances window is open")
        XCTAssertEqual(coordinator.eventID, "second_chances_20261210")
        XCTAssertNil(vm.kibbleDrive, "no Drive window is open on 12-11")
    }
}
