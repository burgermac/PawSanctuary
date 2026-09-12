//
//  KibbleDriveTests.swift
//  PawSanctuaryTests
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) — the paid, activity-gated
//  ladder. These cover §6 step 2: the `awardCarePoints` broadcast, and the
//  weekly-reset independence §1 names as the most likely error in the feature.
//
//  Deliberately a separate file from `CarePointsTests`. §6 step 2 asks that the
//  existing Care Points suite stay green *untouched* — that is the proof the
//  weekly bar's behaviour is unchanged — so nothing here edits it.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleDriveTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func makeViewModel(drive: KibbleDriveState? = nil) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.carePointsThisWeek = 0
        vm.kibbleDrive = drive
        return vm
    }

    private func drive(points: Int = 0, purchased: Bool = false) -> KibbleDriveState {
        KibbleDriveState(eventID: "kibble_drive_test", points: points, purchased: purchased)
    }

    // MARK: The broadcast — points are copied, not moved

    func testAwardCreditsTheWeeklyBarAndTheDriveWithTheSameAmount() {
        let vm = makeViewModel(drive: drive())
        vm.awardCarePoints(8)
        vm.awardCarePoints(15)

        XCTAssertEqual(vm.carePointsThisWeek, 23)
        XCTAssertEqual(vm.kibbleDrive?.points, 23,
                       "the Drive subscribes to the same activity stream — it must receive the full amount, not a share of it")
    }

    /// The non-rivalrous property stated as its own assertion rather than left
    /// implicit in the equality above: adding a subscriber must not reduce what
    /// any existing subscriber receives.
    func testAddingTheDriveDoesNotReduceWhatTheWeeklyBarReceives() {
        let withoutDrive = makeViewModel()
        let withDrive = makeViewModel(drive: drive())
        for amount in [8, 15, 30, 1, 1, 25] {
            withoutDrive.awardCarePoints(amount)
            withDrive.awardCarePoints(amount)
        }
        XCTAssertEqual(withDrive.carePointsThisWeek, withoutDrive.carePointsThisWeek,
                       "the weekly bar must be untouched by whether a Drive happens to be running")
    }

    // MARK: Accrual is not gated on purchase (§7 open question 3, decided 12 Sep 2026)

    func testAnUnpurchasedDriveStillAccrues() {
        let vm = makeViewModel(drive: drive(purchased: false))
        vm.awardCarePoints(30)
        XCTAssertEqual(vm.kibbleDrive?.points, 30,
                       "an unpurchased player watches the ladder fill with every rung locked — that visible-but-locked accumulation is the offer")
        XCTAssertEqual(vm.kibbleDrive?.purchased, false, "accruing must not flip the purchase flag")
    }

    func testAPurchasedDriveAccruesIdentically() {
        let unpurchased = makeViewModel(drive: drive(purchased: false))
        let purchased = makeViewModel(drive: drive(purchased: true))
        unpurchased.awardCarePoints(30)
        purchased.awardCarePoints(30)
        XCTAssertEqual(purchased.kibbleDrive?.points, unpurchased.kibbleDrive?.points,
                       "purchase releases rungs; it does not change the rate points arrive at")
    }

    // MARK: No Drive running

    func testAwardIsSafeAndStillCreditsTheWeeklyBarWithNoDriveRunning() {
        let vm = makeViewModel(drive: nil)
        vm.awardCarePoints(15)
        XCTAssertEqual(vm.carePointsThisWeek, 15)
        XCTAssertNil(vm.kibbleDrive, "no Drive scheduled must stay no Drive — the broadcast must not conjure one")
    }

    func testTheExistingNonPositiveGuardCoversTheDriveToo() {
        let vm = makeViewModel(drive: drive(points: 40))
        vm.awardCarePoints(0)
        vm.awardCarePoints(-10)
        XCTAssertEqual(vm.carePointsThisWeek, 0)
        XCTAssertEqual(vm.kibbleDrive?.points, 40, "a rejected award must reach neither subscriber")
    }

    // MARK: The weekly-reset trap (§1) — now behavioural, not just structural

    /// `Spec_KibbleDrive_Draft.md` §1's "single most likely implementation
    /// error in the whole feature." The Drive is fed by the same chokepoint as
    /// `carePointsThisWeek`, so the Drive's accumulator looks like it belongs in
    /// `checkWeeklyGoalReset`'s list. It does not: a Drive window can straddle
    /// the weekly boundary, and zeroing the ladder there would destroy a
    /// purchase outright.
    func testAWeeklyResetZeroesTheCareBarButLeavesTheDriveLadderStanding() {
        let vm = makeViewModel(drive: drive())
        vm.awardCarePoints(260)
        XCTAssertEqual(vm.carePointsThisWeek, 260)
        XCTAssertEqual(vm.kibbleDrive?.points, 260)

        // Put the last reset in a previous week so the real boundary check fires.
        vm.lastWeeklyGoalReset = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        vm.checkWeeklyGoalReset()

        XCTAssertEqual(vm.carePointsThisWeek, 0, "the weekly bar resets — that is its whole rhythm")
        XCTAssertEqual(vm.kibbleDrive?.points, 260,
                       "the Drive's ladder is scoped to its event, not to the week — a window straddling the boundary must survive it")
        XCTAssertEqual(vm.kibbleDrive?.eventID, "kibble_drive_test", "the reset must not re-scope the Drive either")
    }

    func testTheDriveKeepsAccruingNormallyAfterAWeeklyReset() {
        let vm = makeViewModel(drive: drive())
        vm.awardCarePoints(100)
        vm.lastWeeklyGoalReset = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        vm.checkWeeklyGoalReset()
        vm.awardCarePoints(50)

        XCTAssertEqual(vm.carePointsThisWeek, 50, "the bar restarts from the reset, not from its old total")
        XCTAssertEqual(vm.kibbleDrive?.points, 150, "the ladder accumulates straight through the boundary")
    }

    // MARK: Persistence of the new view-model wiring

    /// Through the real save path — `persistNow()` on one view model,
    /// `loadGame()` on a fresh other — rather than the capture/apply pair,
    /// which is private. Step 1's `PersistenceTests` already prove
    /// `GameState.kibbleDrive` encodes and migrates; what this proves is the
    /// view-model wiring added in step 2, which those cannot see.
    func testDrivePointsSurviveAForceQuitAndRelaunch() throws {
        let vm = makeViewModel(drive: drive(purchased: true))
        vm.awardCarePoints(147)
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertEqual(relaunched.kibbleDrive?.points, 147,
                       "points banked before a force-quit must not be lost — they are what a purchase releases")
        XCTAssertEqual(relaunched.kibbleDrive?.purchased, true)
        XCTAssertEqual(relaunched.kibbleDrive?.eventID, "kibble_drive_test")
    }

    func testNoDriveRoundTripsAsNoDrive() throws {
        let vm = makeViewModel(drive: nil)
        vm.awardCarePoints(20)
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertNil(relaunched.kibbleDrive,
                     "a save written with no Drive scheduled must come back with none")
    }
}
