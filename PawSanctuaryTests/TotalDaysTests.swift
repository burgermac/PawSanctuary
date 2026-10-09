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

    // MARK: Claiming

    private func vm(totalDays: Int, kibble: Int = 0, tags: Int = 0) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.quests.loginTotalDays = totalDays
        vm.quests.loginStreakDay = 1
        vm.showLoginReward = true
        vm.kibbleEngine.kibble = kibble
        vm.kibbleEngine.dogTags = tags
        return vm
    }

    func testAnOrdinaryDayPaysOnlyTheDayReward() {
        let vm = vm(totalDays: 3)
        vm.claimLoginReward()
        XCTAssertEqual(vm.kibbleEngine.kibble, loginDailyRewards[0].kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, loginDailyRewards[0].dogTags)
    }

    func testAMilestoneDayPaysTheDayRewardPlusTheBonusInOneClaim() {
        let vm = vm(totalDays: 15)
        let packsBefore = vm.pendingCardPacks.count
        vm.claimLoginReward()
        let bonus = try! XCTUnwrap(loginMilestone(forTotalDays: 15))
        XCTAssertEqual(vm.kibbleEngine.kibble, loginDailyRewards[0].kibble + bonus.kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, loginDailyRewards[0].dogTags + bonus.dogTags)
        XCTAssertEqual(vm.pendingCardPacks.count, packsBefore + 1, "day 15 carries a card pack")
    }

    func testTheBonusCannotBePaidTwice() {
        let vm = vm(totalDays: 8)
        vm.claimLoginReward()
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags
        vm.claimLoginReward()
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
