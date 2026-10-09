//
//  RewardFlightTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_RewardFlight.md: claiming an order records its payout as a burst
//  for the flight overlay. Presentation only -- the rewards are applied exactly
//  as before.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class RewardFlightTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func completeOrder(rewards: [OrderReward]) -> AdoptionOrder {
        var order = AdoptionOrder(familyIndex: 0,
                                  wantedChainID: ContentRegistry.animalChainID(.dog),
                                  wantedTier: 1, wantedCount: 1)
        order.lines[0].fulfilled = 1
        order.rewards = rewards
        return order
    }

    func testClaimingAnOrderRecordsABurstForEachFlyingCurrency() {
        let vm = MergeBoardViewModel()
        let order = completeOrder(rewards: [OrderReward(kind: .coins, amount: 40),
                                            OrderReward(kind: .dogTags, amount: 2)])
        vm.adoptionBoardCoordinator.adoptionOrders = [order]
        vm.autoClaimOrder(at: 0)

        let burst = vm.rewardBursts.first
        XCTAssertNotNil(burst)
        XCTAssertEqual(burst?.sourceID, order.id)
        let kinds = Set(burst?.items.map(\.kind) ?? [])
        XCTAssertEqual(kinds, [.coins, .dogTags, .xp])
        XCTAssertEqual(burst?.items.first { $0.kind == .dogTags }?.amount, 2)
        XCTAssertEqual(burst?.items.first { $0.kind == .xp }?.amount, xpPerOrderFulfil)
    }

    func testTheFlightDoesNotChangeWhatTheOrderPays() {
        let vm = MergeBoardViewModel()
        vm.kibbleEngine.dogTags = 0
        let order = completeOrder(rewards: [OrderReward(kind: .dogTags, amount: 3)])
        vm.adoptionBoardCoordinator.adoptionOrders = [order]
        vm.autoClaimOrder(at: 0)
        XCTAssertEqual(vm.kibbleEngine.dogTags, 3, "the balance moves at once; only the show is delayed")
    }

    func testAnOrderPayingNothingVisibleStillFliesItsXP() {
        let vm = MergeBoardViewModel()
        let order = completeOrder(rewards: [OrderReward(kind: .cardPack, amount: 1, payloadID: "star1")])
        vm.adoptionBoardCoordinator.adoptionOrders = [order]
        vm.autoClaimOrder(at: 0)
        XCTAssertEqual(vm.rewardBursts.first?.items.map(\.kind), [.xp])
    }

    func testTheBurstClearsOnceTheSpritesHaveLanded() async {
        let vm = MergeBoardViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder(rewards: [OrderReward(kind: .coins, amount: 40)])]
        vm.autoClaimOrder(at: 0)
        XCTAssertEqual(vm.rewardBursts.count, 1)
        try? await Task.sleep(for: .seconds(2.2))
        XCTAssertTrue(vm.rewardBursts.isEmpty)
    }

    func testBiggerPayoutsSendMoreSpritesButNeverAFloodOfThem() {
        XCTAssertLessThan(RewardFlightKind.coins.spriteCount(for: 5),
                          RewardFlightKind.coins.spriteCount(for: 500))
        XCTAssertLessThanOrEqual(RewardFlightKind.coins.spriteCount(for: 1_000_000), 6)
        XCTAssertEqual(RewardFlightKind.dogTags.spriteCount(for: 1), 1)
        XCTAssertLessThanOrEqual(RewardFlightKind.dogTags.spriteCount(for: 90), 4)
    }
}
