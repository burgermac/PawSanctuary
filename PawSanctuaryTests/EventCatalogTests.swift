//
//  EventCatalogTests.swift
//  PawSanctuaryTests
//
//  Remote event data, task 7.2.1 (specs/Spec_RemoteEventData.md §10): the
//  catalog seam must change nothing. With no downloaded file present (the
//  only state that exists at this step), the effective catalog is the
//  compiled one, item by item, and every registry accessor returns exactly
//  its compiled literal.
//

import XCTest
@testable import PawSanctuary

final class EventCatalogTests: XCTestCase {

    // MARK: - Item-by-item comparison helpers

    private func assertSameEvents(_ actual: [EventDefinition], _ expected: [EventDefinition],
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "EventRegistry event count", file: file, line: line)
        XCTAssertEqual(actual.map(\.id), expected.map(\.id), "EventRegistry ids or order", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.id, e.id, file: file, line: line)
            XCTAssertEqual(a.name, e.name, "\(e.id) name", file: file, line: line)
            XCTAssertEqual(a.tagline, e.tagline, "\(e.id) tagline", file: file, line: line)
            XCTAssertEqual(a.startDate, e.startDate, "\(e.id) startDate", file: file, line: line)
            XCTAssertEqual(a.endDate, e.endDate, "\(e.id) endDate", file: file, line: line)
            XCTAssertEqual(a.icon, e.icon, "\(e.id) icon", file: file, line: line)
            XCTAssertEqual(a.accentColor, e.accentColor, "\(e.id) accentColor", file: file, line: line)
            XCTAssertEqual(a.gradientColors, e.gradientColors, "\(e.id) gradientColors", file: file, line: line)
            XCTAssertEqual(a.minLevel, e.minLevel, "\(e.id) minLevel", file: file, line: line)
            XCTAssertEqual(a.priority, e.priority, "\(e.id) priority", file: file, line: line)
            XCTAssertEqual(a.milestones.map(\.id), e.milestones.map(\.id), "\(e.id) legacy milestones", file: file, line: line)
            XCTAssertEqual(a.milestones.map(\.coinsRequired), e.milestones.map(\.coinsRequired),
                           "\(e.id) legacy thresholds", file: file, line: line)
        }
    }

    private func assertSameParallelBoardEvents(_ actual: [ParallelBoardEventDefinition],
                                               _ expected: [ParallelBoardEventDefinition],
                                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.map(\.id), expected.map(\.id), "Parallel Board ids or order", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.name, e.name, "\(e.id) name", file: file, line: line)
            XCTAssertEqual(a.icon, e.icon, "\(e.id) icon", file: file, line: line)
            XCTAssertEqual(a.chainID, e.chainID, "\(e.id) chainID", file: file, line: line)
            XCTAssertEqual(a.startDate, e.startDate, "\(e.id) startDate", file: file, line: line)
            XCTAssertEqual(a.endDate, e.endDate, "\(e.id) endDate", file: file, line: line)
        }
    }

    private func assertSameKibbleDriveEvents(_ actual: [KibbleDriveEventDefinition],
                                             _ expected: [KibbleDriveEventDefinition],
                                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.map(\.id), expected.map(\.id), "Kibble Drive ids or order", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.name, e.name, "\(e.id) name", file: file, line: line)
            XCTAssertEqual(a.icon, e.icon, "\(e.id) icon", file: file, line: line)
            XCTAssertEqual(a.startDate, e.startDate, "\(e.id) startDate", file: file, line: line)
            XCTAssertEqual(a.endDate, e.endDate, "\(e.id) endDate", file: file, line: line)
        }
    }

    private func assertSameTracks(_ actual: [String: [TrackMilestone]], _ expected: [String: [TrackMilestone]],
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(actual.keys), Set(expected.keys), "track keys", file: file, line: line)
        for (key, table) in expected {
            XCTAssertEqual(actual[key], table, "track \(key) milestones", file: file, line: line)
        }
    }

    // MARK: - Tests

    /// No downloaded file exists at this step, so the effective catalog must
    /// be the compiled one: every event, track, Parallel Board event and
    /// Kibble Drive compared item by item, ids and dates included.
    func testEffectiveCatalogEqualsCompiledWhenNoFileIsPresent() {
        let effective = EventCatalog.effective

        assertSameEvents(effective.events, EventRegistry.compiledEvents)
        assertSameTracks(effective.tracks, ProgressTrackRegistry.compiledTracks)
        assertSameParallelBoardEvents(effective.parallelBoardEvents, ParallelBoardEventRegistry.compiledEvents)
        assertSameKibbleDriveEvents(effective.kibbleDriveEvents, KibbleDriveRegistry.compiledEvents)
    }

    /// `EventCatalog.compiled` is built from the registries' compiled
    /// literals and nothing else.
    func testCompiledCatalogIsBuiltFromTheCompiledLiterals() {
        let compiled = EventCatalog.compiled

        assertSameEvents(compiled.events, EventRegistry.compiledEvents)
        assertSameTracks(compiled.tracks, ProgressTrackRegistry.compiledTracks)
        assertSameParallelBoardEvents(compiled.parallelBoardEvents, ParallelBoardEventRegistry.compiledEvents)
        assertSameKibbleDriveEvents(compiled.kibbleDriveEvents, KibbleDriveRegistry.compiledEvents)
    }

    /// The accessors every caller already uses return exactly the compiled
    /// values, so no consumer can see a difference.
    func testRegistryAccessorsReturnExactlyTheCompiledValues() {
        assertSameEvents(EventRegistry.allEvents, EventRegistry.compiledEvents)
        assertSameTracks(ProgressTrackRegistry.tracks, ProgressTrackRegistry.compiledTracks)
        assertSameParallelBoardEvents(ParallelBoardEventRegistry.allEvents, ParallelBoardEventRegistry.compiledEvents)
        assertSameKibbleDriveEvents(KibbleDriveRegistry.allEvents, KibbleDriveRegistry.compiledEvents)
    }

    /// The default-argument consumers that capture a registry at init
    /// (`EventScheduler`, `ProgressTrack`) see the compiled content.
    @MainActor
    func testDefaultInitialisedConsumersSeeTheCompiledCatalog() {
        let scheduler = EventScheduler()
        let explicit = EventScheduler(events: EventRegistry.compiledEvents)
        for event in EventRegistry.compiledEvents {
            let mid = event.startDate.addingTimeInterval(event.endDate.timeIntervalSince(event.startDate) / 2)
            XCTAssertEqual(Set(scheduler.activeEvents(at: mid)), Set(explicit.activeEvents(at: mid)),
                           "active set differs inside \(event.id)")
        }

        // With progress past every threshold and nothing claimed, claimable
        // returns the whole table the track captured at init, in order.
        let track = ProgressTrack()
        for (key, table) in ProgressTrackRegistry.compiledTracks {
            track.advance(trackID: key, by: Int.max / 2)
            XCTAssertEqual(track.claimable(trackID: key, paidLaneUnlocked: true), table,
                           "ProgressTrack table for \(key)")
        }
    }
}
