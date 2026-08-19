//
//  ParallelBoardLifecycleTests.swift
//  PawSanctuaryTests
//
//  Design-authority review of Spec_Phase6b_ParallelBoard.md against shipped
//  code (18 Aug 2026), the review pass Milestone track and Pass already had
//  but this event type hadn't. Every other file's own coordinator/registry
//  logic is unit-tested in isolation (ParallelBoardCoordinatorTests,
//  ParallelBoardEventsTests, ParallelBoardEnergyTests) — but the actual
//  integration wiring in MergeBoardViewModel.checkEventLifecycle() (coordinator
//  creation, progressTrack sharing, idempotence, teardown, and the
//  relaunch-restore path through apply(_:)/pendingParallelBoardRestore) had
//  zero coverage anywhere. This file closes that gap, exercising the real,
//  shipped checkEventLifecycle() against the real "Second Chances" calendar
//  window (second_chances_20260911, 2026-09-11...09-14) — a fixed, permanent
//  date, not today's real wall clock, matching the exact precedent
//  EventSystemTests.swift's ConcurrentEventRiderRegistrationTests already set
//  for the identical class of gap on the milestone-lane side.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ParallelBoardLifecycleTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private let insideWindow = "2026-09-12"     // inside second_chances_20260911 (09-11...09-14)
    private let beforeWindow = "2026-09-01"     // before any Second Chances instance
    private let betweenWindows = "2026-09-20"   // after season 1's instance, before season 2's

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    func testCheckEventLifecycleCreatesACoordinatorForTheRealActiveEvent() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))

        let coordinator = vm.activeParallelBoardEvent
        XCTAssertNotNil(coordinator)
        XCTAssertEqual(coordinator?.eventID, "second_chances_20260911")
        XCTAssertEqual(coordinator?.chainID, ContentRegistry.parallelBoardSecondChancesChainID)
    }

    /// The chokepoint fixed alongside D6's spend-goal chokepoint earlier this
    /// session had the same shape of bug: a new piece of state quietly not
    /// wired to the thing it needs to share. Here, a coordinator constructed
    /// with its own private ProgressTrack() (its injectable default) instead
    /// of MergeBoardViewModel's own persisted instance would still pass every
    /// ParallelBoardCoordinatorTests case — sharing is only provable from the
    /// call site that constructs it.
    func testCheckEventLifecycleSharesTheViewModelsOwnPersistedProgressTrack() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))

        XCTAssertTrue(vm.activeParallelBoardEvent?.progressTrack === vm.progressTrack,
                      "the coordinator must advance the same ProgressTrack instance MergeBoardViewModel persists, not a private standalone one")
    }

    func testCheckEventLifecycleIsIdempotentAndDoesNotReplaceTheCoordinator() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let first = vm.activeParallelBoardEvent
        XCTAssertNotNil(first)

        vm.checkEventLifecycle(at: date(insideWindow))   // same date, second call
        let second = vm.activeParallelBoardEvent

        XCTAssertTrue(first === second,
                      "a no-op check must not discard and recreate the coordinator, losing any in-progress board state")
    }

    func testCheckEventLifecycleTearsDownTheCoordinatorWhenNoEventIsActive() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        XCTAssertNotNil(vm.activeParallelBoardEvent)

        vm.checkEventLifecycle(at: date(betweenWindows))
        XCTAssertNil(vm.activeParallelBoardEvent, "the coordinator must be torn down once its event's window ends")
    }

    func testNoCoordinatorIsCreatedBeforeAnyEventStarts() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(beforeWindow))
        XCTAssertNil(vm.activeParallelBoardEvent)
    }

    /// The actual production path: loadGame() -> apply(saved) stages
    /// pendingParallelBoardRestore -> checkEventLifecycle(at:) consumes it.
    /// Proven here via loadGame(at:)'s injectable date (added during this
    /// review) rather than waiting for 2026-09-11 to arrive in real time or
    /// exercising ParallelBoardCoordinator.restore(from:) in isolation, which
    /// ParallelBoardCoordinatorTests already covers but which can't prove the
    /// wiring above it is correct.
    func testBoardPlacementSurvivesForceQuitAndRelaunchWhileTheSameEventIsStillActive() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try XCTUnwrap(vm.activeParallelBoardEvent)

        coordinator.collectFromGenerator()
        let placedCount = coordinator.boardState.board.flatMap { $0 }.filter { $0.item != nil }.count
        XCTAssertEqual(placedCount, 1, "setup: the generator collect must have actually placed an item")
        let energyAfterCollect = coordinator.energy.balance
        XCTAssertEqual(energyAfterCollect, parallelBoardEnergyCap - parallelBoardGeneratorCost)

        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame(at: date(insideWindow))   // same still-active window, simulating a same-day relaunch

        let restored = try XCTUnwrap(relaunched.activeParallelBoardEvent)
        XCTAssertEqual(restored.eventID, "second_chances_20260911")
        let restoredPlacedCount = restored.boardState.board.flatMap { $0 }.filter { $0.item != nil }.count
        XCTAssertEqual(restoredPlacedCount, 1,
                       "the generator-collected item must survive a force-quit/relaunch mid-event")
        XCTAssertEqual(restored.energy.balance, energyAfterCollect,
                       "energy spent before the force-quit must not be refunded on relaunch")
    }

    /// The negative case for the same path: a save carrying parallelBoardState
    /// from an event that has since ENDED must not leak that stale board into
    /// a coordinator for a later, different event.
    func testAStaleSaveStateFromAnEndedEventIsNeverAppliedToADifferentEvent() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.collectFromGenerator()
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        // Season 2's window (second_chances_20261011) — a different eventID
        // than the persisted save's "second_chances_20260911".
        relaunched.loadGame(at: date("2026-10-12"))

        let seasonTwo = try XCTUnwrap(relaunched.activeParallelBoardEvent)
        XCTAssertEqual(seasonTwo.eventID, "second_chances_20261011")
        let placedCount = seasonTwo.boardState.board.flatMap { $0 }.filter { $0.item != nil }.count
        XCTAssertEqual(placedCount, 0,
                       "a stale save from a since-ended event must never seed a different event's fresh board")
    }
}
