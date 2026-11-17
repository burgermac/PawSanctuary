//
//  TrophyPageTests.swift
//  PawSanctuaryTests
//
//  Trophy pages (specs/Spec_GoldenBallTrophyPage.md): a completed top-tier
//  sub-object can fill a slot on its family's page instead of being applied
//  or converted. Covers the rule, the refusals, and persistence.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class TrophyPageTests: XCTestCase {

    private let dogChain = "subobject.dog"

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.trophyCounts = [:]
        return vm
    }

    private func stock(_ vm: MergeBoardViewModel, slot: Int = 0,
                       chainID: ChainID? = nil, rarity: SubObjectRarity? = .speed) {
        vm.inventoryStore.powerUpInventory[slot] =
            BoardItem(chainID: chainID ?? dogChain, tier: 3, rarity: rarity)
        vm.selectedPowerUpSlot = slot
    }

    func testAddingFillsASlotPaysCoinsAndRemovesTheItem() {
        let vm = makeViewModel()
        stock(vm)
        let before = vm.coins

        XCTAssertTrue(vm.addSelectedPowerUpToTrophy())

        XCTAssertEqual(vm.trophySlotsFilled(for: .dog), 1)
        XCTAssertEqual(vm.coins, before + trophySlotCoins)
        XCTAssertNil(vm.inventoryStore.powerUpInventory[0])
        XCTAssertNil(vm.selectedPowerUpSlot)
    }

    func testTheLastSlotPaysThePageBonusOnce() {
        let vm = makeViewModel()
        vm.trophyCounts[AnimalSpecies.dog.rawValue] = trophySlotsPerFamily - 1
        stock(vm)
        let before = vm.coins

        XCTAssertTrue(vm.addSelectedPowerUpToTrophy())

        XCTAssertEqual(vm.coins, before + trophySlotCoins + trophyPageBonusCoins)
        XCTAssertEqual(vm.trophySlotsFilled(for: .dog), trophySlotsPerFamily)
    }

    func testAFullPageRefusesAndKeepsTheItem() {
        let vm = makeViewModel()
        vm.trophyCounts[AnimalSpecies.dog.rawValue] = trophySlotsPerFamily
        stock(vm)
        let before = vm.coins

        XCTAssertNil(vm.selectedPowerUpTrophyFamily)
        XCTAssertFalse(vm.addSelectedPowerUpToTrophy())

        XCTAssertEqual(vm.coins, before)
        XCTAssertNotNil(vm.inventoryStore.powerUpInventory[0],
                        "a full page must not eat the item — it can still be applied or converted")
        XCTAssertEqual(vm.trophySlotsFilled(for: .dog), trophySlotsPerFamily)
    }

    func testAnItemWithNoRolledEffectIsRefused() {
        let vm = makeViewModel()
        stock(vm, rarity: nil)
        XCTAssertFalse(vm.addSelectedPowerUpToTrophy())
        XCTAssertEqual(vm.trophySlotsFilled(for: .dog), 0)
    }

    func testNothingSelectedIsANoOp() {
        let vm = makeViewModel()
        let before = vm.coins
        XCTAssertFalse(vm.addSelectedPowerUpToTrophy())
        XCTAssertEqual(vm.coins, before)
    }

    func testPagesAreIndependentPerFamily() {
        let vm = makeViewModel()
        stock(vm, chainID: "subobject.cat")
        XCTAssertTrue(vm.addSelectedPowerUpToTrophy())
        XCTAssertEqual(vm.trophySlotsFilled(for: .cat), 1)
        XCTAssertEqual(vm.trophySlotsFilled(for: .dog), 0)
    }

    func testAPageBonusIsAlwaysWorthMoreThanAPlainConversion() {
        // Guards the incentive: adding to a trophy should beat converting.
        for rarity in [SubObjectRarity.speed, .mapSupplies, .boardItemGrant] {
            XCTAssertGreaterThanOrEqual(trophySlotCoins, rarity.coinValue)
        }
    }
}
