//
//  MemoryLogTests.swift
//  PawSanctuaryTests
//
//  The DEBUG memory sampler's pure parts (MemoryLog.swift). The sampling
//  itself reads the live process and is not tested.
//

#if DEBUG
import XCTest
@testable import PawSanctuary

@MainActor
final class MemoryLogTests: XCTestCase {

    func testCsvRowHasOneFieldPerHeaderColumn() {
        let row = MemoryLog.csvRow(
            time: Date(timeIntervalSince1970: 0), elapsed: 61, event: "sample",
            headroomMB: 1234.56, usedMB: 7.04,
            context: MemoryLog.Context(spawnersOnBoard: 4, spawnersAffordable: 3, occupiedCells: 30))
        XCTAssertEqual(row.split(separator: ",").count,
                       MemoryLog.header.split(separator: ",").count)
        XCTAssertEqual(row, "1970-01-01T00:00:00Z,61,sample,1234.6,7.0,4,3,30")
    }

    func testTrimKeepsHeaderAndNewestLines() {
        let lines = ["header"] + (1...10).map { "row\($0)" }
        XCTAssertEqual(MemoryLog.trimmed(lines, max: 4), ["header", "row8", "row9", "row10"])
    }

    func testTrimLeavesAShortLogAlone() {
        let lines = ["header", "a", "b"]
        XCTAssertEqual(MemoryLog.trimmed(lines, max: 10), lines)
    }
}
#endif
