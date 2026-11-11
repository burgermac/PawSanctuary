//
//  TotalDaysTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_TotalDaysTrack.md: a lifetime day counter under the 7-day login
//  cycle, with milestones at 8 / 15 / 22 / 30 of a repeating 30-day cycle. A
//  gap never resets it.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class TotalDaysTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Pure cycle maths

    func testTheCycleDayWrapsAfterThirty() {
        XCTAssertEqual(loginCycleDay(forTotalDays: 0), 1)
        XCTAssertEqual(loginCycleDay(forTotalDays: 1), 1)
        XCTAssertEqual(loginCycleDay(forTotalDays: 30), 30)
        XCTAssertEqual(loginCycleDay(forTotalDays: 31), 1)
        XCTAssertEqual(loginCycleDay(forTotalDays: 68), 8)
    }

    func testMilestonesLandOnExactlyTheMeasuredDaysOfEachCycle() {
        XCTAssertEqual(loginTotalDaysMilestones.map(\.day), [8, 15, 22, 30])
        for total in 1...90 {
            let expected = [8, 15, 22, 30].contains(loginCycleDay(forTotalDays: total))
            XCTAssertEqual(loginMilestone(forTotalDays: total) != nil, expected, "day \(total)")
        }
        XCTAssertNil(loginMilestone(forTotalDays: 0))
        XCTAssertEqual(loginMilestone(forTotalDays: 38)?.day, 8, "a second cycle repeats them")
    }

    // MARK: The counter

    func testOpeningTheGameOnANewDayCountsOnceAndASecondOpenDoesNot() {
        let q = QuestCoordinator()
        XCTAssertTrue(q.checkDailyLogin())
        XCTAssertEqual(q.loginTotalDays, 1)
        XCTAssertFalse(q.checkDailyLogin(), "same day, no popup")
        XCTAssertEqual(q.loginTotalDays, 1)
    }

    func testAGapNeverResetsTheCounterWhileItDoesResetTheStreak() {
        let q = QuestCoordinator()
        q.loginTotalDays = 12
        q.loginStreak = 6
        q.loginDayIndex = 5
        q.lastLoginDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        XCTAssertTrue(q.checkDailyLogin())
        XCTAssertEqual(q.loginTotalDays, 13, "a missed stretch costs nothing")
        XCTAssertEqual(q.loginStreak, 1, "the consecutive streak still resets, as before")
    }

    // MARK: Paying (specs/Spec_LoginGrantAtCheck.md: paid at the check, not on a tap)

    /// A view model whose last visit was `daysAgo` days ago, with the counter
    /// at `totalDays` and a known balance, ready for `checkDailyLogin()`.
    private func vm(totalDays: Int, daysAgo: Int = 1, kibble: Int = 0, tags: Int = 0) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.quests.loginTotalDays = totalDays
        vm.quests.loginDayIndex = 0
        vm.quests.loginStreak = 1
        vm.quests.lastLoginDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())
        vm.kibbleEngine.kibble = kibble
        vm.kibbleEngine.dogTags = tags
        return vm
    }

    func testAnOrdinaryDayPaysOnlyTheDayRewardAtTheCheck() {
        let vm = vm(totalDays: 2)            // today becomes day 3: no milestone
        vm.checkDailyLogin()
        XCTAssertTrue(vm.showLoginReward)
        // Yesterday's streak day index was 0, so today is streak day 2.
        let reward = loginDailyRewards[vm.loginStreakDay - 1]
        XCTAssertEqual(vm.kibbleEngine.kibble, reward.kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, reward.dogTags)
    }

    func testAMilestoneDayPaysTheDayRewardPlusTheBonusAtTheCheck() {
        let vm = vm(totalDays: 14)           // today becomes day 15
        let packsBefore = vm.pendingCardPacks.count
        vm.checkDailyLogin()
        let bonus = try! XCTUnwrap(loginMilestone(forTotalDays: 15))
        let reward = loginDailyRewards[vm.loginStreakDay - 1]
        XCTAssertEqual(vm.kibbleEngine.kibble, reward.kibble + bonus.kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, reward.dogTags + bonus.dogTags)
        XCTAssertEqual(vm.pendingCardPacks.count, packsBefore + 1, "day 15 carries a card pack")
    }

    func testASecondCheckTheSameDayPaysNothingMore() {
        let vm = vm(totalDays: 7)
        vm.checkDailyLogin()
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags
        vm.checkDailyLogin()
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags)
        XCTAssertFalse(vm.showLoginReward, "no popup the second time")
    }

    func testDismissingThePopupPaysNothing() {
        let vm = vm(totalDays: 7)
        vm.checkDailyLogin()
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags
        vm.dismissLoginReward()
        XCTAssertFalse(vm.showLoginReward)
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags)
    }

    func testAFreshGameRestartsTheCounterAtItsFirstDay() {
        let vm = vm(totalDays: 20)
        vm.resetToFreshGame()
        // A fresh game runs the first-day login check straight away, so the
        // counter reads 1 -- not the 20 it held, and not 21.
        XCTAssertEqual(vm.loginTotalDays, 1)
    }
}
