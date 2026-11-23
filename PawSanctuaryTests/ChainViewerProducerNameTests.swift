//
//  ChainViewerProducerNameTests.swift
//  PawSanctuaryTests
//
//  Task 2.3 of `specs/Spec_ChainViewerUpgrades_Draft.md` (§5): the chain
//  viewer's "Made by" line. `MergeChain.producerDisplayName` is derived from
//  data that already exists (no table, nothing persisted):
//
//    animal.<species>, subobject.<species>  -> that species' spawnerName
//    supply.<key>                           -> the box whose targetChainID matches
//    everything else                        -> nil (the line is not shown)
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ChainViewerProducerNameTests: XCTestCase {

    private func producer(_ id: ChainID, file: StaticString = #filePath, line: UInt = #line) -> String? {
        guard let chain = ContentRegistry.shared.chain(id) else {
            XCTFail("chain \(id) is not registered", file: file, line: line)
            return nil
        }
        return chain.producerDisplayName
    }

    // MARK: Animal and sub-object chains

    func testTheDogChainIsMadeByItsFamilySpawner() {
        XCTAssertEqual(producer(ContentRegistry.animalChainID(.dog)), AnimalSpecies.dog.spawnerName)
    }

    func testTheCatSubObjectChainIsMadeByTheCatFamilySpawner() {
        XCTAssertEqual(producer("subobject.\(AnimalSpecies.cat.rawValue)"), AnimalSpecies.cat.spawnerName)
    }

    func testEverySpeciesResolvesBothChainsToANonEmptySpawnerName() {
        for species in AnimalSpecies.allCases {
            let animal = producer(ContentRegistry.animalChainID(species))
            let subObject = producer("subobject.\(species.rawValue)")
            XCTAssertEqual(animal, species.spawnerName, "animal chain of \(species)")
            XCTAssertEqual(subObject, species.spawnerName, "sub-object chain of \(species)")
            XCTAssertFalse((animal ?? "").isEmpty, "\(species) has no producer name")
        }
    }

    // MARK: Supply chains

    func testEachSupplyChainIsMadeByItsBox() {
        XCTAssertEqual(producer(ContentRegistry.groomingChainID), "Grooming Box")
        XCTAssertEqual(producer(ContentRegistry.foodChainID), "Feed Station")
        XCTAssertEqual(producer(ContentRegistry.shelterChainID), "Supply Crate")
        // And the strings really are the boxes' own names, not copies.
        XCTAssertEqual(producer(ContentRegistry.groomingChainID), ProducerLevel.groomingBox.displayName)
        XCTAssertEqual(producer(ContentRegistry.foodChainID), ProducerLevel.feedBox.displayName)
        XCTAssertEqual(producer(ContentRegistry.shelterChainID), ProducerLevel.shelterBox.displayName)
    }

    // MARK: No single producer: no line

    func testChainsWithNoSingleProducerHaveNoName() {
        let none: [ChainID] = [
            ContentRegistry.kibbleCurrencyChainID,
            ContentRegistry.coinCurrencyChainID,
            ContentRegistry.woodChainID,
            ContentRegistry.toolboxChainID,
            ContentRegistry.wildcardChainID,
            ContentRegistry.parallelBoardSecondChancesChainID,
        ]
        for id in none {
            XCTAssertNil(producer(id), "\(id) should show no Made by line")
        }
    }
}
