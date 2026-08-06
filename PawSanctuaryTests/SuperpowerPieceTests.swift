//
//  SuperpowerPieceTests.swift
//  PawSanctuaryTests
//
//  Active superpowers became single-use board pieces (5 Aug 2026) instead of a
//  permanent unlock + cooldown button. Covers the ContentRegistry registration
//  half of that change — the only part of the feature that's pure, deterministic
//  lookup logic rather than MergeBoardViewModel board-mutation code.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class SuperpowerPieceTests: XCTestCase {

    private var activeSpecies: [AnimalSpecies] {
        AnimalSpecies.allCases.filter { $0.superpower.isActive }
    }

    func testEveryActiveSuperpowerHasARegisteredSingleTierChain() {
        for species in activeSpecies {
            let chainID = ContentRegistry.superpowerChainID(species)
            let chain = ContentRegistry.shared.chain(chainID)
            XCTAssertNotNil(chain, "\(species.rawValue) is active but has no registered superpower chain")
            XCTAssertEqual(chain?.category, .superpower)
            XCTAssertEqual(chain?.maxTier, 0, "\(species.rawValue)'s superpower piece must be single-tier")
            XCTAssertEqual(chain?.tiers.first?.symbol, species.superpower.sfSymbol)
            XCTAssertEqual(chain?.tiers.first?.name, species.superpower.name)
        }
    }

    func testPassiveSpeciesHaveNoSuperpowerChain() {
        for species in AnimalSpecies.allCases where !species.superpower.isActive {
            let chainID = ContentRegistry.superpowerChainID(species)
            XCTAssertNil(ContentRegistry.shared.chain(chainID),
                        "\(species.rawValue) is passive and must not have a superpower piece")
        }
    }

    func testSuperpowerPieceNeverMergesWithItself() {
        for species in activeSpecies {
            let chainID = ContentRegistry.superpowerChainID(species)
            XCTAssertNil(ContentRegistry.shared.nextTier(chainID, after: 0),
                        "\(species.rawValue)'s superpower piece must be a dead end — spent via the eligible-target merge, not stacked")
        }
    }

    func testActiveSuperpowerCountMatchesSuperpowerSystemRegistry() {
        // Sanity check against SuperpowerSystem.swift's own registry (cat, guineaPig,
        // pony, lizard, ferret, parrot) — catches drift if a future ability is added
        // there without updating ItemChain's registration loop.
        XCTAssertEqual(activeSpecies.count, 6)
    }
}
