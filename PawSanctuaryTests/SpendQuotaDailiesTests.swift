//
//  SpendQuotaDailiesTests.swift
//  PawSanctuaryTests
//
//  D6 (Spec_SpendQuotaDailies.md) Task 3.1 — QuestGoal.spendCurrency's generic
//  switches (targetCount, description, icon, iconColor, dedupeKey). Both
//  currencies are covered since both generate in v1 (spec §2).
//

import XCTest
@testable import PawSanctuary

final class SpendQuotaDailiesGoalTests: XCTestCase {

    func testTargetCountReturnsTheSpendAmount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).targetCount, 40)
        XCTAssertEqual(QuestGoal.spendCurrency(.dogTags, count: 8).targetCount, 8)
    }

    func testDescriptionNamesTheCurrencyAndAmount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).description, "Spend 40 Kibble")
        XCTAssertEqual(QuestGoal.spendCurrency(.dogTags, count: 8).description, "Spend 8 Dog Tags")
    }

    func testIconAndColorMatchShopViewsExistingIconographyPerCurrency() {
        let kibble = QuestGoal.spendCurrency(.kibble, count: 40)
        XCTAssertEqual(kibble.icon, "pawprint")
        XCTAssertEqual(kibble.iconColor, .green)

        let dogTags = QuestGoal.spendCurrency(.dogTags, count: 8)
        XCTAssertEqual(dogTags.icon, "tag.fill")
        XCTAssertEqual(dogTags.iconColor, .blue)
    }

    func testDedupeKeyDiffersByCurrency() {
        let kibbleKey  = QuestGoal.spendCurrency(.kibble, count: 40).dedupeKey
        let dogTagsKey = QuestGoal.spendCurrency(.dogTags, count: 8).dedupeKey
        XCTAssertEqual(kibbleKey, "spendCurrency:kibble")
        XCTAssertEqual(dogTagsKey, "spendCurrency:dogTags")
        XCTAssertNotEqual(kibbleKey, dogTagsKey)
    }

    /// Guards the invariant every other QuestGoal case already has to respect:
    /// two instances differing only by count still share a dedupeKey (dedup is
    /// about goal *shape*, not the rolled count) — matters if this case is
    /// ever reused for standing quests (spec §2), even though nothing
    /// generates it there yet.
    func testDedupeKeyIgnoresCount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).dedupeKey,
                       QuestGoal.spendCurrency(.kibble, count: 999).dedupeKey)
    }
}

@MainActor
final class SpendQuotaDailiesProducerNeededTests: XCTestCase {

    /// MergeBoardViewModel.producerIsNeeded(_:by:) (private) is exercised
    /// indirectly through retirableProducers, which is the real, public
    /// consequence of that switch being exhaustive. A spendCurrency goal
    /// isn't tied to any specific producer (spec §2's comment on this exact
    /// switch), so a producer with no other goal referencing it should still
    /// show up as retirable — proving the new case falls into the same
    /// "doesn't block retirement" bucket as mergeAny/reachTier, not silently
    /// falling through to some other behavior.
    func testASpendGoalAloneDoesNotBlockProducerRetirement() {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.setProducer(ProducerTile(level: .rescueCrate), at: GridPosition(row: 0, col: 0))
        vm.quests.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
        ]

        XCTAssertTrue(vm.retirableProducers.contains { $0.position == GridPosition(row: 0, col: 0) },
                      "a spendCurrency-only goal must not keep a producer from being offered for retirement")
    }
}
