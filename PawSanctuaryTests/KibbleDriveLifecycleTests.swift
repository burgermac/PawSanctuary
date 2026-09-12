//
//  KibbleDriveLifecycleTests.swift
//  PawSanctuaryTests
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) §6 step 3a — creation,
//  teardown, mid-window relaunch, and forfeit on close.
//
//  Every date here is fixed and permanent, taken from KibbleDriveRegistry's
//  own schedule rather than from wall-clock time. Lifecycle tests that read
//  Date() rot the moment the window they depended on closes — this suite had
//  that failure mode demonstrated for it by the Parallel Board's equivalent
//  (see TODO.md's resolved test-rot entry) and is written to avoid it.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleDriveLifecycleTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    /// Inside `kibble_drive_20260911` (2026-09-11 → 2026-09-14).
    private let insideFirstWindow = "2026-09-12"
    /// After the first window, before the second (2026-10-09).
    private let betweenWindows = "2026-09-20"
    /// Inside `kibble_drive_20261009` (2026-10-09 → 2026-10-12).
    private let insideSecondWindow = "2026-10-10"

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: The registry itself

    func testWindowsAreThreeDaysLongAndNoneOverlap() {
        let events = KibbleDriveRegistry.allEvents
        XCTAssertFalse(events.isEmpty)
        for e in events {
            let days = e.endDate.timeIntervalSince(e.startDate) / 86400
            XCTAssertEqual(days, 3, accuracy: 0.01, "\(e.id): §3.3 sets a 3-day window")
        }
        for (a, b) in zip(events, events.dropFirst()) {
            XCTAssertLessThanOrEqual(a.endDate, b.startDate, "\(a.id) and \(b.id) must not overlap")
        }
    }

    /// §4's cadence argument, as an assertion. At a weekly cadence §3.5's
    /// ~3.9× safety margin stops being a margin and the Drive becomes the
    /// kibble economy, so a later retune that tightens the spacing should
    /// fail here rather than quietly opening the faucet.
    func testInstancesAreAboutFourWeeksApartNotWeekly() {
        let starts = KibbleDriveRegistry.allEvents.map(\.startDate)
        for (a, b) in zip(starts, starts.dropFirst()) {
            let gap = b.timeIntervalSince(a) / 86400
            XCTAssertGreaterThanOrEqual(gap, 21, "§4: rarity is load-bearing — this is not a weekly beat")
        }
    }

    func testEveryInstanceHasItsOwnID() {
        let ids = KibbleDriveRegistry.allEvents.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count,
                       "state is scoped by eventID — a shared ID would open the next Drive part-filled from the last one")
    }

    /// Concurrency with other event surfaces is **expected**, not a defect:
    /// §4 says so outright and `Spec_ParallelBoardReview_Draft.md` §2.5 records
    /// the reference running 3+ at once. This asserts the permission rather
    /// than a prohibition, because the first draft of this suite asserted the
    /// prohibition — an unsourced commercial instinct, not a spec requirement —
    /// and failed against a schedule written to the spec.
    func testOverlapWithOtherEventSurfacesIsAllowed() {
        let drive = KibbleDriveRegistry.allEvents[0]
        let concurrent = ParallelBoardEventRegistry.allEvents.contains {
            drive.startDate < $0.endDate && $0.startDate < drive.endDate
        }
        XCTAssertTrue(concurrent,
                      "the first Drive is scheduled alongside a Parallel Board event on purpose — if that stops being true, §4's concurrency claim has gone untested")
    }

    // MARK: Creation and teardown

    func testADriveIsCreatedWhenItsWindowIsOpen() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))

        let drive = try XCTUnwrap(vm.kibbleDrive, "a Drive window is open — state must exist for points to land in")
        XCTAssertEqual(drive.eventID, "kibble_drive_20260911")
        XCTAssertEqual(drive.points, 0, "a new Drive starts empty")
        XCTAssertFalse(drive.purchased)
        XCTAssertEqual(drive.claimedRungs, [])
    }

    func testNoDriveExistsOutsideEveryWindow() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(betweenWindows))
        XCTAssertNil(vm.kibbleDrive, "no window open means no ladder to fill")
    }

    /// Forfeit on close (§7 open question 4, decided 12 Sep 2026): points do
    /// not roll over and unclaimed rungs are lost.
    func testAFinishedDriveIsForfeitedRatherThanCarriedForward() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(260)
        XCTAssertEqual(vm.kibbleDrive?.points, 260, "setup: points must actually have banked")

        // checkEventLifecycle carries no once-per-launch guard of its own —
        // that lives in loadGame — so it can be driven directly at a later date.
        vm.checkEventLifecycle(at: date(betweenWindows))

        XCTAssertNil(vm.kibbleDrive,
                     "the window closed — unclaimed rungs are forfeit and points do not roll over")
    }

    func testPointsFromAFinishedDriveNeverReachTheNextOne() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(300)

        vm.checkEventLifecycle(at: date(insideSecondWindow))

        let drive = try XCTUnwrap(vm.kibbleDrive)
        XCTAssertEqual(drive.eventID, "kibble_drive_20261009")
        XCTAssertEqual(drive.points, 0,
                       "the second Drive must start from zero — inheriting the first's points would open it near its top rung")
    }

    // MARK: Relaunch

    /// The production path: `loadGame(at:)` runs `apply(saved)` first, then
    /// `checkEventLifecycle`, so the ID comparison is made against genuinely
    /// restored state. This is what stops a mid-window relaunch wiping the
    /// ladder a player has been filling.
    func testPointsSurviveARelaunchInsideTheSameWindow() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(147)
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame(at: date(insideFirstWindow))

        let drive = try XCTUnwrap(relaunched.kibbleDrive)
        XCTAssertEqual(drive.eventID, "kibble_drive_20260911")
        XCTAssertEqual(drive.points, 147,
                       "a relaunch inside the running window must not reset the ladder")
    }

    func testASaveFromAFinishedDriveIsDroppedOnRelaunch() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(300)
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame(at: date(betweenWindows))

        XCTAssertNil(relaunched.kibbleDrive,
                     "a save carrying a finished Drive must not resurrect it after the window closed")
    }

    func testASaveFromAFinishedDriveIsNotAppliedToADifferentDrive() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(300)
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame(at: date(insideSecondWindow))

        let drive = try XCTUnwrap(relaunched.kibbleDrive)
        XCTAssertEqual(drive.eventID, "kibble_drive_20261009")
        XCTAssertEqual(drive.points, 0, "stale points must not leak across the gap between two Drives")
    }

    // MARK: Interaction with the weekly reset, end to end

    /// §1's trap at the level step 2 could not reach it: `loadGame` runs
    /// `checkWeeklyGoalReset()` *before* `checkEventLifecycle`, so a relaunch
    /// that crosses the weekly boundary mid-Drive exercises both in their real
    /// production order.
    func testARelaunchAcrossTheWeeklyBoundaryMidDriveKeepsTheLadder() throws {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideFirstWindow))
        vm.awardCarePoints(260)
        vm.lastWeeklyGoalReset = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame(at: date(insideFirstWindow))

        XCTAssertEqual(relaunched.carePointsThisWeek, 0, "the weekly bar reset, as it should have")
        let drive = try XCTUnwrap(relaunched.kibbleDrive)
        XCTAssertEqual(drive.points, 260,
                       "the ladder must survive a weekly reset landing mid-window — this is what would destroy a purchase")
    }
}
