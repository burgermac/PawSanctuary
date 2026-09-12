//
//  KibbleDrivePurchaseTests.swift
//  PawSanctuaryTests
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) §6 step 3, purchase half —
//  the purchase flip, the time-of-check/time-of-use guard, and the
//  late-purchase catch-up grant (§7 open question 5).
//
//  Dates are fixed and taken from KibbleDriveRegistry, never from Date(), for
//  the reason KibbleDriveLifecycleTests' header gives.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleDrivePurchaseTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    /// `kibble_drive_20260911` opens 2026-09-11 and closes 2026-09-14.
    private let windowStart = "2026-09-11"
    private let dayTwo = "2026-09-12"
    private let dayThree = "2026-09-13"
    private let afterWindow = "2026-09-20"
    private let insideSecondWindow = "2026-10-10"

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func runningDrive(points: Int, at iso: String) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(iso))
        vm.kibbleDrive?.points = points
        return vm
    }

    // MARK: The purchase flip

    func testPurchaseFlipsTheRunningDrive() throws {
        let vm = runningDrive(points: 100, at: dayTwo)
        vm.applyKibbleDrivePurchase(at: date(dayTwo))
        XCTAssertEqual(vm.kibbleDrive?.purchased, true)
    }

    /// StoreKit can replay a transaction through `listenForTransactions()`
    /// after a relaunch, so applying the same purchase twice must not grant
    /// twice.
    func testASecondApplicationOfTheSamePurchaseGrantsNothingFurther() throws {
        let vm = runningDrive(points: 100, at: dayThree)
        vm.applyKibbleDrivePurchase(at: date(dayThree))
        let afterFirst = try XCTUnwrap(vm.kibbleDrive?.points)

        vm.applyKibbleDrivePurchase(at: date(dayThree))
        XCTAssertEqual(vm.kibbleDrive?.points, afterFirst,
                       "a redelivered transaction must not re-run the catch-up grant")
    }

    func testPurchaseWithNoDriveRunningIsASafeNoOp() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(afterWindow))
        vm.applyKibbleDrivePurchase(at: date(afterWindow))
        XCTAssertNil(vm.kibbleDrive)
    }

    // MARK: TOCTOU (§5, the pendingEventPassEventID pattern)

    /// The purchase sheet is an unbounded wait. If the window closes and a
    /// *different* Drive is running by the time the transaction resolves, the
    /// captured ID must stop it unlocking the wrong event.
    func testAPurchaseResolvingAgainstADifferentDriveIsRefused() throws {
        let vm = runningDrive(points: 100, at: dayTwo)
        vm.pendingKibbleDriveEventID = "kibble_drive_20260911"

        // The first window closed and the next one opened while the sheet was up.
        vm.checkEventLifecycle(at: date(insideSecondWindow))
        XCTAssertEqual(vm.kibbleDrive?.eventID, "kibble_drive_20261009", "setup")

        vm.applyKibbleDrivePurchase(at: date(insideSecondWindow))

        XCTAssertEqual(vm.kibbleDrive?.purchased, false,
                       "the player bought the September Drive — unlocking October's instead is unrecoverable")
        XCTAssertEqual(vm.kibbleDrive?.points, 0, "and no catch-up grant may land on it either")
    }

    func testACapturedIDMatchingTheRunningDriveIsAccepted() throws {
        let vm = runningDrive(points: 100, at: dayTwo)
        vm.pendingKibbleDriveEventID = "kibble_drive_20260911"
        vm.applyKibbleDrivePurchase(at: date(dayTwo))
        XCTAssertEqual(vm.kibbleDrive?.purchased, true)
    }

    func testTheCapturedIDIsClearedAfterEveryAttempt() {
        let vm = runningDrive(points: 100, at: dayTwo)
        vm.pendingKibbleDriveEventID = "kibble_drive_20260911"
        vm.applyKibbleDrivePurchase(at: date(dayTwo))
        XCTAssertNil(vm.pendingKibbleDriveEventID, "a stale capture must not leak into the next purchase flow")
    }

    // MARK: The catch-up grant (§7 open question 5)

    /// The exploit the cap exists to prevent: a flat top-up to par would hand
    /// someone who never played the entire ladder for $4.99.
    func testAPlayerWhoNeverPlayedIsGrantedNothing() {
        let vm = runningDrive(points: 0, at: dayThree)
        XCTAssertEqual(vm.kibbleDriveCatchUpGrant(at: date(dayThree)), 0,
                       "nothing was lost, so nothing is owed — and a flat top-up here would be the whole ladder for no play")

        vm.applyKibbleDrivePurchase(at: date(dayThree))
        XCTAssertEqual(vm.kibbleDrive?.points, 0)
        XCTAssertEqual(vm.kibbleDrive?.purchased, true, "they still bought it — the purchase stands, the grant does not")
    }

    func testABuyerAtOrAboveParIsGrantedNothing() {
        // Two days elapsed at 105/day = 210 par; this player is ahead of it.
        let vm = runningDrive(points: 260, at: dayThree)
        XCTAssertEqual(vm.kibbleDriveCatchUpGrant(at: date(dayThree)), 0,
                       "there is no shortfall to close")
    }

    func testABuyerOnTheOpeningDayIsGrantedNothing() {
        let vm = runningDrive(points: 20, at: windowStart)
        XCTAssertEqual(vm.kibbleDriveCatchUpGrant(at: date(windowStart)), 0,
                       "no window has elapsed yet, so there is nothing to catch up on")
    }

    func testAMidWindowBuyerIsToppedUpTowardPar() throws {
        // Two days elapsed -> par 210. Banked 80, so shortfall 130, capped at
        // half of 80 = 40.
        let vm = runningDrive(points: 80, at: dayThree)
        XCTAssertEqual(vm.kibbleDriveCatchUpGrant(at: date(dayThree)), 40)

        vm.applyKibbleDrivePurchase(at: date(dayThree))
        XCTAssertEqual(vm.kibbleDrive?.points, 120)
    }

    /// The property that keeps §3.5 intact, stated directly rather than left
    /// to follow from the arithmetic above.
    func testTheGrantNeverExceedsWhatTheBuyerBankedThemselves() {
        for banked in [1, 10, 40, 80, 150, 209, 210, 300] {
            for day in [windowStart, dayTwo, dayThree] {
                let vm = runningDrive(points: banked, at: day)
                let grant = vm.kibbleDriveCatchUpGrant(at: date(day))
                XCTAssertLessThanOrEqual(Double(grant), Double(banked) * kibbleDriveCatchUpCap,
                                         "banked \\(banked) on \\(day): the grant must stay keyed to the player's own work")
            }
        }
    }

    /// §3.5's margin of safety, re-derived against the grant rather than
    /// assumed to survive it. A granted point costs the buyer no kibble but
    /// pays `1.80` back, so the worst case is a buyer who converts P banked
    /// points into `P * (1 + cap)`. The Drive must still not be a net kibble
    /// source — if a retune of `kibbleDriveCatchUpCap` ever breaks that, this
    /// fails rather than the faucet quietly opening.
    func testTheWorstCaseGrantLeavesTheDriveANetKibbleSink() {
        let kibbleSpentPerPointEarned = 7.1      // §3.5, from EconomySimulation
        let kibblePaidPerPoint = 1.80            // §3.3: 540 kibble over a 300-point ladder

        let banked = 100.0
        let total = banked * (1 + kibbleDriveCatchUpCap)
        let spent = banked * kibbleSpentPerPointEarned
        let paid = total * kibblePaidPerPoint
        let margin = spent / paid

        XCTAssertGreaterThan(margin, 1.0,
                             "the Drive must never pay out more kibble than it takes to play for — it would be loopable")
        XCTAssertGreaterThan(margin, 2.0,
                             "§3.5 measured ~3.9x before the grant; the cap is sized to keep this comfortably above 2x")
    }

    func testTheGrantIsRefusedOnceTheWindowHasClosed() {
        let vm = runningDrive(points: 80, at: dayThree)
        XCTAssertEqual(vm.kibbleDriveCatchUpGrant(at: date(afterWindow)), 0,
                       "forfeit on close means there is no Drive left to top up")
    }
}
