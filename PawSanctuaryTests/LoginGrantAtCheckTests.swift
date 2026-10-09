//
//  LoginGrantAtCheckTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_LoginGrantAtCheck.md: the Good Morning reward is paid when the day
//  is registered, so quitting before tapping the popup can no longer lose it.
//  The failure these guard against: the visit date was saved by the next
//  ordinary save, but the reward was only paid on the Claim tap.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class LoginGrantAtCheckTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// Yesterday's visit, so the next check is a new day.
    private func vmVisitedYesterday() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.quests.lastLoginDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        vm.quests.loginDayIndex = 0
        return vm
    }

    func testQuittingBeforeTheTapKeepsTheReward() {
        let vm = vmVisitedYesterday()
        vm.kibbleEngine.kibble = 10
        vm.checkDailyLogin()
        let paid = vm.kibbleEngine.kibble
        XCTAssertGreaterThan(paid, 10, "the day's reward is paid at the check")

        // An ordinary save, then a force-quit with the popup never touched.
        vm.persistNow()

        // A real relaunch: a new view model loading what was saved.
        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()
        XCTAssertGreaterThanOrEqual(relaunched.kibbleEngine.kibble, paid,
                                    "the reward must survive the quit")
        XCTAssertLessThanOrEqual(relaunched.kibbleEngine.kibble, paid + 2,
                                 "and must not be paid a second time on relaunch")
    }

    func testRelaunchingTheSameDayShowsNoSecondPopup() {
        let vm = vmVisitedYesterday()
        vm.checkDailyLogin()
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()
        XCTAssertFalse(relaunched.showLoginReward, "today was already registered")
    }
}
