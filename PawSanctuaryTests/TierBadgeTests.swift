//
//  TierBadgeTests.swift
//  PawSanctuaryTests
//
//  The board's "Lv.N" tier badge (Feature_Parity_Audit.md §1): shown on the
//  chains a player climbs, never on currencies, power-ups or the wildcard.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class TierBadgeTests: XCTestCase {

    func testAnimalTierZeroReadsLevelOne() {
        let item = BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 0)
        XCTAssertEqual(CellView.tierBadgeLevel(for: item), 1)
    }

    func testTheTopAnimalTierReadsTheChainLength() {
        let chainID = ContentRegistry.animalChainID(.dog)
        let top = ContentRegistry.shared.chain(chainID)?.maxTier ?? 0
        let item = BoardItem(chainID: chainID, tier: top)
        XCTAssertEqual(CellView.tierBadgeLevel(for: item), top + 1)
        XCTAssertEqual(top + 1, animalChainTopTier + 1, "the badge must agree with the 12-tier chain")
    }

    func testSupplyMaterialAndToolChainsAreNumberedToo() {
        for chainID in [ContentRegistry.groomingChainID, ContentRegistry.woodChainID,
                        ContentRegistry.toolboxChainID] {
            XCTAssertEqual(CellView.tierBadgeLevel(for: BoardItem(chainID: chainID, tier: 2)), 3, chainID)
        }
    }

    func testCurrencyAndWildcardCarryNoBadge() {
        for chainID in [ContentRegistry.kibbleCurrencyChainID, ContentRegistry.coinCurrencyChainID,
                        ContentRegistry.wildcardChainID] {
            XCTAssertNil(CellView.tierBadgeLevel(for: BoardItem(chainID: chainID, tier: 1)), chainID)
        }
    }

    func testAnUnknownChainCarriesNoBadge() {
        XCTAssertNil(CellView.tierBadgeLevel(for: BoardItem(chainID: "no.such.chain", tier: 0)))
    }
}
