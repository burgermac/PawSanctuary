//
//  ParallelBoardEventsTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Task 3.7 — coverage for ParallelBoardEventDefinition's date-window
//  logic, tested against synthetic instances rather than the registry (which
//  is empty until §5's real test event is authored, a separate later task).
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

    func testActiveEventIsNilWhenTheRegistryIsEmpty() {
        // ParallelBoardEventRegistry.allEvents is empty until §5's real test
        // event lands — this documents that current, real behavior rather
        // than asserting against a synthetic registry.
        XCTAssertNil(ParallelBoardEventRegistry.activeEvent)
    }
}
