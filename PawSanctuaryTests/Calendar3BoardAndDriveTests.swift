//
//  Calendar3BoardAndDriveTests.swift
//  PawSanctuaryTests
//
//  Phase 7 third calendar (specs/Spec_Phase7_Calendar3.md §3.5) — the
//  Parallel Board ("Second Chances") and Kibble Drive windows for
//  2027-03-03 → 2027-06-01.
//
//  Every date here is injected and fixed. Nothing reads Date(): lifecycle
//  tests that depend on wall-clock time rot the moment the window they relied
//  on closes (TODO.md's resolved test-rot entry). Day arithmetic uses a UTC
//  calendar, matching how the registries parse their ISO dates — S7 contains
//  both spring DST changes (US 03-14, EU 03-28), so a local calendar would
//  miscount.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class Calendar3BoardAndDriveTests: XCTestCase {

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

    /// §2.5: each new instance starts exactly 7 days into its paired season.
    func testEachNewSecondChancesStartsSevenDaysIntoItsSeason() throws {
        let pairs = [
            "second_chances_20270310": "sanctuary_circle_s7_20270303",
            "second_chances_20270409": "sanctuary_circle_s8_20270402",
            "second_chances_20270509": "sanctuary_circle_s9_20270502",
        ]
        for (eventID, seasonID) in pairs {
            let event = try XCTUnwrap(ParallelBoardEventRegistry.allEvents.first { $0.id == eventID },
                                      "missing \(eventID)")
            let season = try XCTUnwrap(EventRegistry.allEvents.first { $0.id == seasonID },
                                       "missing \(seasonID)")
            XCTAssertEqual(days(from: season.startDate, to: event.startDate), 7,
                           "\(eventID) must start 7 days into \(seasonID)")
            XCTAssertEqual(days(from: event.startDate, to: event.endDate), 3, "\(eventID) runs 3 days")
            XCTAssertEqual(event.name, "Second Chances")
            XCTAssertEqual(event.icon, "arrow.triangle.2.circlepath")
            XCTAssertEqual(event.chainID, ContentRegistry.parallelBoardSecondChancesChainID)
        }
    }

    /// §2.5: exact dates, so a re-dating shows up.
    func testNewSecondChancesHaveTheSpecifiedDates() throws {
        let expected = [
            ("second_chances_20270310", "2027-03-10", "2027-03-13"),
            ("second_chances_20270409", "2027-04-09", "2027-04-12"),
            ("second_chances_20270509", "2027-05-09", "2027-05-12"),
        ]
        for (id, start, end) in expected {
            let event = try XCTUnwrap(ParallelBoardEventRegistry.allEvents.first { $0.id == id }, "missing \(id)")
            XCTAssertEqual(event.startDate, date(start), "\(id) start")
            XCTAssertEqual(event.endDate, date(end), "\(id) end")
        }
    }

    /// §2.8: reward-curve reuse, not new numbers — each new table is the
    /// Season 1 table verbatim (rewards included, not just thresholds).
    func testEachNewSecondChancesTableEqualsTheSeasonOneTable() throws {
        let reference = try XCTUnwrap(ProgressTrackRegistry.tracks["second_chances_20260911"])
        for id in ["second_chances_20270310", "second_chances_20270409", "second_chances_20270509"] {
            let table = try XCTUnwrap(ProgressTrackRegistry.tracks[id], "\(id) is missing its progress track")
            XCTAssertEqual(table, reference, "\(id) must copy the 8-milestone table verbatim")
        }
    }

    /// §2.5: the 02-11 → 03-10 dark period is by design (one instance per
    /// season) and gets no window.
    func testTheGapBeforeTheFirstNewSecondChancesHasNoWindow() {
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2027-02-20")))
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2027-03-03")),
                     "S7's first day — the Parallel Board opens 7 days in")
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent(at: date("2027-03-09")),
                     "the day before the S7 instance opens")
        XCTAssertEqual(ParallelBoardEventRegistry.activeEvent(at: date("2027-03-10"))?.id,
                       "second_chances_20270310", "opens on its start day")
    }

    // MARK: Kibble Drive

    /// §2.6: 28-day spacing kept unchanged (owner decision Q9), counted from
    /// the last Calendar 2 Drive.
    func testEachNewDriveStartsExactlyTwentyEightDaysAfterThePreviousOne() throws {
        let chain = [
            "kibble_drive_20270226",
            "kibble_drive_20270326",
            "kibble_drive_20270423",
            "kibble_drive_20270521",
        ]
        let events = try chain.map { id in
            try XCTUnwrap(KibbleDriveRegistry.allEvents.first { $0.id == id }, "missing \(id)")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertEqual(days(from: a.startDate, to: b.startDate), 28,
                           "\(b.id) must start 28 days after \(a.id)")
            XCTAssertEqual(days(from: b.startDate, to: b.endDate), 3, "\(b.id) runs 3 days")
            XCTAssertEqual(b.name, "Kibble Drive")
            XCTAssertEqual(b.icon, "shippingbox.fill")
        }
        XCTAssertEqual(events[1].startDate, date("2027-03-26"))
        XCTAssertEqual(events[2].startDate, date("2027-04-23"))
        XCTAssertEqual(events[3].startDate, date("2027-05-21"))
        XCTAssertEqual(events[3].endDate, date("2027-05-24"))
    }

    /// The 03-01 → 03-26 dark period (25 days, 28 − 3) gets no Drive.
    func testNoDriveWindowOpensBetweenMarchFirstAndMarchTwentySixth() {
        let gapStart = date("2027-03-01")
        let gapEnd = date("2027-03-26")
        let opening = KibbleDriveRegistry.allEvents.filter { $0.startDate >= gapStart && $0.startDate < gapEnd }
        XCTAssertEqual(opening.map(\.id), [], "no Drive may open inside the 03-01 → 03-26 gap")

        var day = gapStart
        var sampled = 0
        while day < gapEnd {
            XCTAssertNil(KibbleDriveRegistry.activeEvent(at: day), "no Drive should be active on \(day)")
            sampled += 1
            day = utc.date(byAdding: .day, value: 1, to: day)!
        }
        XCTAssertEqual(sampled, 25)
        XCTAssertEqual(KibbleDriveRegistry.activeEvent(at: gapEnd)?.id, "kibble_drive_20270326")
    }

    // MARK: Lifecycle at injected dates

    /// 2027-03-11: inside `second_chances_20270310`; the 02-26 Drive ended
    /// 03-01 and the next opens 03-26.
    func testLifecycleOnMarchEleventhCreatesTheParallelBoardAndNoDrive() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2027-03-11"))

        let coordinator = try XCTUnwrap(vm.activeParallelBoardEvent, "a Second Chances window is open")
        XCTAssertEqual(coordinator.eventID, "second_chances_20270310")
        XCTAssertNil(vm.kibbleDrive, "no Drive window is open on 03-11")
    }

    /// 2027-03-27: inside `kibble_drive_20270326`; the S7 Second Chances ended
    /// 03-13.
    func testLifecycleOnMarchTwentySeventhCreatesTheDriveAndNoParallelBoard() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2027-03-27"))

        let drive = try XCTUnwrap(vm.kibbleDrive, "a Drive window is open")
        XCTAssertEqual(drive.eventID, "kibble_drive_20270326")
        XCTAssertEqual(drive.points, 0, "a new Drive starts empty")
        XCTAssertNil(vm.activeParallelBoardEvent, "no Second Chances window is open on 03-27")
    }
}
