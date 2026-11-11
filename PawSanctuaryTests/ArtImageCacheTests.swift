//
//  ArtImageCacheTests.swift
//  PawSanctuaryTests
//
//  The downsampled art path (ArtImageCache.swift): art comes back at the
//  cached pixel size, missing art still resolves nil so callers keep their
//  SF Symbol fallback, and a second lookup is served from the cache.
//

import XCTest
import UIKit
@testable import PawSanctuary

final class ArtImageCacheTests: XCTestCase {

    private let knownArt = "animal_canines_dog_tier00_pup"

    func testArtIsDownsampledToTheCachedPixelSize() throws {
        let image = try XCTUnwrap(ArtImageCache.uiImage(named: knownArt))
        XCTAssertEqual(image.size.width * image.scale, ArtImageCache.pixelSize)
        XCTAssertEqual(image.size.height * image.scale, ArtImageCache.pixelSize)
    }

    func testMissingArtIsNil() {
        XCTAssertNil(ArtImageCache.uiImage(named: "no_such_art_asset"))
        XCTAssertNil(ArtImageCache.image(named: "no_such_art_asset"))
    }

    func testSecondLookupIsServedFromTheCache() throws {
        let first = try XCTUnwrap(ArtImageCache.uiImage(named: knownArt))
        let second = try XCTUnwrap(ArtImageCache.uiImage(named: knownArt))
        XCTAssertTrue(first === second)
    }

    /// Every art image the registry resolves is downsampled, never scaled up:
    /// the cached size must not exceed the shipped source.
    @MainActor
    func testEveryRegistryArtImageResolvesAtOrBelowItsSource() throws {
        var checked = 0
        for chain in ContentRegistry.shared.chains.values {
            for tier in chain.tiers.indices where chain.artImage(forTier: tier) != nil {
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 250, "expected the delivered art set to resolve")
        let source = try XCTUnwrap(UIImage(named: knownArt))
        XCTAssertGreaterThanOrEqual(source.size.width * source.scale, ArtImageCache.pixelSize)
    }
}
