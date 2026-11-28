//
//  EventCatalogMergeTests.swift
//  PawSanctuaryTests
//
//  Remote event data, task 7.2.4 (specs/Spec_RemoteEventData.md §5.3, §5.5):
//  the merge, tombstones, and pins overriding a later file. Pure.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EventCatalogMergeTests: XCTestCase {

    private func day(_ n: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(n) * 86_400)
    }

    private func drive(_ id: String, _ start: Int, _ end: Int) -> KibbleDriveEventDefinition {
        KibbleDriveEventDefinition(id: id, name: id, icon: "shippingbox.fill",
                                   startDate: day(start), endDate: day(end))
    }

    private func pass(_ id: String, _ start: Int, _ end: Int, name: String = "Pass") -> EventDefinition {
        EventDefinition(id: id, name: name, tagline: "", startDate: day(start), endDate: day(end),
                        milestones: [], icon: "trophy.fill", accentColor: .orange, gradientColors: [])
    }

    private func track(_ threshold: Int) -> [TrackMilestone] {
        [TrackMilestone(index: 0, threshold: threshold, freeRewards: [],
                        paidRewards: [OrderReward(kind: .kibble, amount: 10)])]
    }

    private var base: EventCatalog {
        EventCatalog(events: [pass("season", 10, 40)],
                     tracks: ["season": track(100), "ladder": track(1)],
                     parallelBoardEvents: [],
                     kibbleDriveEvents: [drive("drive_a", 20, 23), drive("drive_b", 50, 53)])
    }

    private func content(events: [EventDefinition] = [], tracks: [String: [TrackMilestone]] = [:],
                         drives: [KibbleDriveEventDefinition] = [],
                         cancelled: [String] = []) -> RemoteEventContent {
        RemoteEventContent(events: events, tracks: tracks, parallelBoardEvents: [],
                           kibbleDriveEvents: drives, cancelledIDs: cancelled)
    }

    private func merge(_ content: RemoteEventContent?, pins: [EventPin] = [],
                       now: Int) -> EventCatalogMerge {
        EventCatalog.merging(base: base, content: content,
                             pins: Dictionary(uniqueKeysWithValues: pins.map { ($0.id, $0) }),
                             now: day(now))
    }

    func testAFileAddsAndReplacesByIDAndKeepsTheRest() {
        let result = merge(content(drives: [drive("drive_b", 60, 63), drive("drive_c", 70, 73)]), now: 1)

        XCTAssertNil(result.fileRejection)
        XCTAssertEqual(result.catalog.kibbleDriveEvents.map(\.id), ["drive_a", "drive_b", "drive_c"])
        XCTAssertEqual(result.catalog.kibbleDriveEvents[1].startDate, day(60))
        XCTAssertEqual(result.catalog.events.map(\.id), ["season"])
    }

    func testATombstoneRemovesAnUnstartedEventAndIsIgnoredForAStartedOne() {
        let result = merge(content(cancelled: ["drive_a", "drive_b"]), now: 21)

        XCTAssertEqual(result.catalog.kibbleDriveEvents.map(\.id), ["drive_a"])
    }

    func testATombstoneIsIgnoredForAPinnedEvent() {
        let pinned = EventPin(id: "drive_b", kind: .kibbleDrive, start: day(50), end: day(53), track: nil)
        let result = merge(content(cancelled: ["drive_b"]), pins: [pinned], now: 30)

        XCTAssertTrue(result.catalog.kibbleDriveEvents.contains { $0.id == "drive_b" })
    }

    func testARunningPassKeepsItsPinnedDatesAndTableButTakesTheNewName() throws {
        let pinned = EventPin(id: "season", kind: .pass, start: day(10), end: day(40), track: track(100))
        let result = merge(content(events: [pass("season", 12, 35, name: "Renamed")],
                                   tracks: ["season": track(999)]),
                           pins: [pinned], now: 20)

        XCTAssertNil(result.fileRejection)
        let season = try XCTUnwrap(result.catalog.events.first)
        XCTAssertEqual(season.startDate, day(10))
        XCTAssertEqual(season.endDate, day(40))
        XCTAssertEqual(season.name, "Renamed")
        XCTAssertEqual(result.catalog.tracks["season"], track(100))
    }

    func testAnEndedPinStillStopsAFileReopeningTheEvent() {
        let pinned = EventPin(id: "drive_a", kind: .kibbleDrive, start: day(20), end: day(23), track: nil)
        let result = merge(content(drives: [drive("drive_a", 24, 27)]), pins: [pinned], now: 25)

        XCTAssertEqual(result.catalog.kibbleDriveEvents.first?.endDate, day(23))
    }

    func testAPinnedFileOnlyPassComesBackWhenItsFileIsGone() throws {
        let pinned = EventPin(id: "remote_pass", kind: .pass, start: day(60), end: day(80), track: track(7))
        let result = merge(nil, pins: [pinned], now: 65)

        let event = try XCTUnwrap(result.catalog.events.first { $0.id == "remote_pass" })
        XCTAssertEqual(event.endDate, day(80))
        XCTAssertEqual(event.name, "Season Pass")
        XCTAssertEqual(result.catalog.tracks["remote_pass"], track(7))
        XCTAssertEqual(result.catalog.windows.first { $0.id == "remote_pass" }?.kind, .pass)
    }

    func testWithoutAFileALivePinDisplacesAnOverlappingCompiledEvent() {
        let pinned = EventPin(id: "remote_drive", kind: .kibbleDrive, start: day(49), end: day(52), track: nil)
        let result = merge(nil, pins: [pinned], now: 50)

        XCTAssertEqual(result.catalog.kibbleDriveEvents.map(\.id), ["drive_a", "remote_drive"])
    }

    func testAMergedClashDropsTheWholeFileAndKeepsThePins() {
        let pinned = EventPin(id: "season", kind: .pass, start: day(10), end: day(40), track: track(100))
        // The file shortens the season and books a second pass in the gap. The
        // pin keeps the season's end, so the two would run at once.
        let file = content(events: [pass("season", 10, 25), pass("season_2", 30, 45)],
                           tracks: ["season_2": track(5)],
                           drives: [drive("drive_c", 70, 73)])
        let result = merge(file, pins: [pinned], now: 20)

        XCTAssertEqual(result.fileRejection?.rule, .v8)
        XCTAssertEqual(result.catalog.events.map(\.id), ["season"])
        XCTAssertFalse(result.catalog.kibbleDriveEvents.contains { $0.id == "drive_c" })
        XCTAssertEqual(result.catalog.events.first?.endDate, day(40))
    }

    func testRemovingAnEventNeverRemovesATrackThatHasNoEvent() {
        let result = merge(content(cancelled: ["ladder"]), now: 1)

        XCTAssertEqual(result.catalog.tracks["ladder"], track(1))
    }

    func testNoFileAndNoPinsIsTheBaseCatalog() {
        let result = merge(nil, now: 1)

        XCTAssertNil(result.fileRejection)
        XCTAssertEqual(result.catalog.windows, base.windows)
        XCTAssertEqual(result.catalog.tracks, base.tracks)
    }
}
