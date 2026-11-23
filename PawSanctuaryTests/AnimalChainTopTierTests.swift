//
//  AnimalChainTopTierTests.swift
//  PawSanctuaryTests
//
//  Fifteen tiers, task 1 (specs/Spec_FifteenTiers.md §9): `animalChainTopTier`
//  is derived from the chain length instead of the literal 11. Nothing moves
//  today: the chains are still 12 long. These tests pin that every family
//  agrees on the length, so deriving from one family is safe, and that the
//  derived value is still today's 11.
//

import XCTest
@testable import PawSanctuary

final class AnimalChainTopTierTests: XCTestCase {

    func testEveryFamilyHasTheSameChainLength() {
        let lengths = Set(AnimalSpecies.allCases.map { $0.tierNames.count })
        XCTAssertEqual(lengths.count, 1, "families disagree on chain length: \(lengths)")
    }

    func testTheTopTierIsDerivedFromTheChainLength() {
        for species in AnimalSpecies.allCases {
            XCTAssertEqual(animalChainTopTier, species.tierNames.count - 1, "\(species)")
        }
    }

    func testTheRegisteredChainsAgreeWithTheDerivedTopTier() {
        for species in AnimalSpecies.allCases {
            let chain = ContentRegistry.shared.chain(ContentRegistry.animalChainID(species))
            XCTAssertEqual(chain?.maxTier, animalChainTopTier, "\(species)")
        }
    }

    func testNothingMovedTodayTheChainsAreStillTwelveLong() {
        XCTAssertEqual(animalChainTopTier, 11)
    }
}
