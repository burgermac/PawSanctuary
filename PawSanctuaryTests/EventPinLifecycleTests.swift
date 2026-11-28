//
//  EventPinLifecycleTests.swift
//  PawSanctuaryTests
//
//  Remote event data, task 7.2.4 (specs/Spec_RemoteEventData.md §5.5): pins,
//  and the rule that saved state under an unknown id is never destroyed.
//  Dates are fixed ones from the compiled calendar.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EventPinLifecycleTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private let insideDrive = "2026-09-12"     // kibble_drive_20260911, second_chances_20260911
    private let nothingRunning = "2026-09-20"  // no Drive, no Parallel Board

    override func setUp() async throws {
        GameStore.clear()
    }

    override func tearDown() async throws {
        GameStore.clear()
    }

    /// What `vm` would write now. Cleared first so the write-order guard
    /// cannot leave an older file behind to be read back.
    private func savedState(of vm: MergeBoardViewModel) throws -> GameState {
        GameStore.clear()
        vm.persistNow()
        return try XCTUnwrap(GameStore.load())
    }

    /// A view model loaded from a fresh save edited by `edit`.
    private func relaunch(at day: String,
                          editing edit: (inout GameState) -> Void) throws -> MergeBoardViewModel {
        var state = try savedState(of: MergeBoardViewModel())
        edit(&state)
        GameStore.clear()
        GameStore.saveNow(state, sequence: 1)
        let vm = MergeBoardViewModel()
        vm.loadGame(at: date(day))
        return vm
    }

    private func boughtDrive(_ id: String) -> KibbleDriveState {
        KibbleDriveState(eventID: id, points: 300, claimedRungs: [0], purchased: true)
    }

    private func pin(_ id: String, _ kind: RemoteEventKind,
                     from start: String, to end: String) -> EventPin {
        EventPin(id: id, kind: kind, start: date(start), end: date(end), track: nil)
    }

    // MARK: Recording and pruning

    func testRunningEventsArePinnedAndSaved() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideDrive))

        let saved = try savedState(of: vm).eventPins
        let drive = try XCTUnwrap(saved["kibble_drive_20260911"])
        XCTAssertEqual(drive.kind, .kibbleDrive)
        XCTAssertEqual(drive.start, date("2026-09-11"))
        XCTAssertEqual(drive.end, date("2026-09-14"))
        XCTAssertNil(drive.track, "the Drive ladder stays code")
        let board = try XCTUnwrap(saved["second_chances_20260911"])
        XCTAssertEqual(board.kind, .parallelBoard)
        XCTAssertEqual(board.track, ProgressTrackRegistry.tracks["second_chances_20260911"])
    }

    func testAnExistingPinIsNeverOverwritten() throws {
        let original = pin("kibble_drive_20260911", .kibbleDrive, from: "2026-09-10", to: "2026-09-13")
        let vm = try relaunch(at: insideDrive) { $0.eventPins = [original.id: original] }

        XCTAssertEqual(vm.eventPins[original.id], original)
    }

    func testPinsArePrunedSevenDaysAfterTheirEnd() throws {
        let old = pin("remote_old", .milestoneTrack, from: "2026-09-10", to: "2026-09-13")
        let vm = try relaunch(at: "2026-09-19") { $0.eventPins = [old.id: old] }
        XCTAssertNotNil(vm.eventPins[old.id], "six days after the end it is still kept")

        vm.checkEventLifecycle(at: date("2026-09-20"))
        XCTAssertNil(vm.eventPins[old.id], "seven days after the end it goes")
    }

    // MARK: Unknown ids never destroy state

    func testABoughtDriveWithAnUnknownIDKeepsItsState() throws {
        let state = boughtDrive("remote_drive_gone")
        let vm = try relaunch(at: nothingRunning) { $0.kibbleDrive = state }

        XCTAssertNil(vm.kibbleDrive, "a held Drive is not a running one")
        vm.awardCarePoints(50)
        XCTAssertEqual(try savedState(of: vm).kibbleDrive, state,
                       "still in the save, untouched: it earns nothing while held")
    }

    func testAHeldDriveSurvivesASecondCheckAndResumesWhenItsIDIsRunningAgain() throws {
        let state = boughtDrive("kibble_drive_20260911")
        let notEndedYet = pin(state.eventID, .kibbleDrive, from: "2026-09-11", to: "2026-09-14")
        // Before the window, as after a clock change: known and not over.
        let vm = try relaunch(at: "2026-09-01") {
            $0.kibbleDrive = state
            $0.eventPins = [notEndedYet.id: notEndedYet]
        }
        vm.checkEventLifecycle(at: date("2026-09-02"))
        XCTAssertNil(vm.kibbleDrive)

        vm.checkEventLifecycle(at: date(insideDrive))
        XCTAssertEqual(vm.kibbleDrive, state)
    }

    func testAPinnedDriveIsForfeitedOnceItsPinnedEndPasses() throws {
        let state = boughtDrive("remote_drive_gone")
        let ended = pin(state.eventID, .kibbleDrive, from: "2026-09-15", to: "2026-09-18")
        let vm = try relaunch(at: nothingRunning) {
            $0.kibbleDrive = state
            $0.eventPins = [ended.id: ended]
        }

        XCTAssertNil(try savedState(of: vm).kibbleDrive)
    }

    func testAPinPrunedOnTheSameLaunchStillForfeitsItsDrive() throws {
        let state = boughtDrive("remote_drive_gone")
        let longEnded = pin(state.eventID, .kibbleDrive, from: "2026-09-01", to: "2026-09-04")
        let vm = try relaunch(at: nothingRunning) {
            $0.kibbleDrive = state
            $0.eventPins = [longEnded.id: longEnded]
        }

        XCTAssertNil(try savedState(of: vm).kibbleDrive)
        XCTAssertTrue(vm.eventPins.isEmpty)
    }

    func testAPinnedDriveStillRunningByItsPinIsKept() throws {
        let state = boughtDrive("remote_drive_gone")
        let running = pin(state.eventID, .kibbleDrive, from: "2026-09-19", to: "2026-09-22")
        let vm = try relaunch(at: nothingRunning) {
            $0.kibbleDrive = state
            $0.eventPins = [running.id: running]
        }

        XCTAssertEqual(try savedState(of: vm).kibbleDrive, state)
    }

    func testAParallelBoardWithAnUnknownIDSurvives() throws {
        let first = MergeBoardViewModel()
        first.checkEventLifecycle(at: date(insideDrive))
        let coordinator = try XCTUnwrap(first.activeParallelBoardEvent)
        coordinator.collectFromGenerator()
        var board = try XCTUnwrap(try savedState(of: first).parallelBoardState)
        board.eventID = "remote_board_gone"

        let vm = try relaunch(at: nothingRunning) { $0.parallelBoardState = board }
        XCTAssertNil(vm.activeParallelBoardEvent)
        vm.checkEventLifecycle(at: date(nothingRunning))

        let kept = try XCTUnwrap(try savedState(of: vm).parallelBoardState)
        XCTAssertEqual(kept.eventID, "remote_board_gone")
        XCTAssertEqual(kept.energyBalance, board.energyBalance)
        XCTAssertEqual(kept.board.flatMap { $0 }.filter { $0.item != nil }.count, 1)
    }

    func testAKnownFinishedParallelBoardIsStillDropped() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideDrive))
        XCTAssertNotNil(vm.activeParallelBoardEvent)
        vm.checkEventLifecycle(at: date(nothingRunning))

        XCTAssertNil(try savedState(of: vm).parallelBoardState)
    }
}
