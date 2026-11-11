//
//  QuestLaneCardsTests.swift
//  PawSanctuaryTests
//
//  Spec_QuestLaneCards_Draft.md Task 5.1 — lane order and the claim path the
//  card uses.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class QuestLaneCardsTests: XCTestCase {

    private func quest(progress: Int, target: Int = 5) -> Quest {
        Quest(goal: .mergeAny(count: target), difficulty: .easy,
              progress: progress, dogTagReward: 1, kibbleReward: 2)
    }

    func testClaimableQuestsLeadThenInProgressInOriginalOrder() {
        let a = quest(progress: 1), b = quest(progress: 5), c = quest(progress: 2)
        XCTAssertEqual(laneOrderedQuests([a, b, c]).map(\.id), [b.id, a.id, c.id])
    }

    func testQuestsPrecedeEveryOtherCardKind() {
        for urgent in [false, true] {
            let kinds = laneCardKinds(claimableQuests: 1, inProgressQuests: 2,
                                      dailyTasks: 3, hasUrgentOrder: urgent, orders: 4)
            XCTAssertEqual(Array(kinds.prefix(3)),
                           [.claimableQuest, .inProgressQuest, .inProgressQuest])
            XCTAssertEqual(kinds.contains(.urgentOrder), urgent)
            let firstNonQuest = kinds.firstIndex { $0 == .dailyTask }
            XCTAssertEqual(firstNonQuest, 3)
            if urgent {
                XCTAssertLessThan(kinds.firstIndex(of: .urgentOrder)!,
                                  kinds.firstIndex(of: .order)!)
            }
        }
        XCTAssertEqual(laneCardKinds(claimableQuests: 0, inProgressQuests: 0,
                                     dailyTasks: 0, hasUrgentOrder: false, orders: 2),
                       [.order, .order])
    }

    func testCardClaimPaysAndReplacesWithFreshQuest() {
        let vm = MergeBoardViewModel()
        vm.activeQuests = [quest(progress: 5), quest(progress: 0, target: 9)]
        let doneID = vm.activeQuests[0].id
        let tagsBefore = vm.kibbleEngine.dogTags

        vm.claimQuest(id: doneID)

        XCTAssertGreaterThanOrEqual(vm.kibbleEngine.dogTags, tagsBefore + 1)
        XCTAssertEqual(vm.activeQuests.count, 2)
        XCTAssertFalse(vm.activeQuests.contains { $0.id == doneID })
        XCTAssertEqual(vm.activeQuests[0].progress, 0)
    }

    func testClaimIgnoredWhileIncomplete() {
        let vm = MergeBoardViewModel()
        vm.activeQuests = [quest(progress: 2)]
        let id = vm.activeQuests[0].id
        vm.claimQuest(id: id)
        XCTAssertEqual(vm.activeQuests[0].id, id)
    }
}
