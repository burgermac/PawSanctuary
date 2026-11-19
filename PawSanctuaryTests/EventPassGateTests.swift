//
//  EventPassGateTests.swift
//  PawSanctuaryTests
//
//  The event tile and the free lane show before monetization unlocks, so
//  `isEventPassOfferAvailable(eventID:)` is the one place D7's "no
//  monetization in session one" holds for the Event Pass (the same role
//  `isKibbleDriveBuyAvailable` plays for the Drive, see KibbleDriveGateTests).
//  A Debug build has no StoreKit configuration, so the price button never
//  renders and the gate cannot be seen working, which is why it is tested here.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EventPassGateTests: XCTestCase {

    private let eventID = "pass_gate_test_event"

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func vm(wall: Bool, level: Int, passBought: Bool = false) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.commerce.hasReachedFirstWall = wall
        vm.progression.playerLevel = level
        if passBought { vm.passUnlockedEventIDs.insert(eventID) }
        return vm
    }

    func testOfferIsWithheldBeforeTheFirstWallEvenAtTheUnlockLevel() {
        XCTAssertFalse(vm(wall: false, level: monetizationUnlockLevel)
            .isEventPassOfferAvailable(eventID: eventID))
    }

    func testOfferIsWithheldBelowTheUnlockLevelEvenAfterTheWall() {
        XCTAssertFalse(vm(wall: true, level: monetizationUnlockLevel - 1)
            .isEventPassOfferAvailable(eventID: eventID))
    }

    func testOfferIsShownOnceBothMonetizationConditionsHold() {
        let vm = vm(wall: true, level: monetizationUnlockLevel)
        XCTAssertTrue(vm.isMonetizationUnlocked)
        XCTAssertTrue(vm.isEventPassOfferAvailable(eventID: eventID))
    }

    func testOfferIsNotShownForAnEventWhosePassIsAlreadyBought() {
        let vm = vm(wall: true, level: monetizationUnlockLevel, passBought: true)
        XCTAssertFalse(vm.isEventPassOfferAvailable(eventID: eventID))
        // Buying one event's pass does not hide the offer on another event.
        XCTAssertTrue(vm.isEventPassOfferAvailable(eventID: "some_other_event"))
    }

    /// The gate follows the shared D7 condition rather than a copy of it, so a
    /// future change to `isMonetizationUnlocked` reaches the Event Pass too.
    func testTheGateTracksIsMonetizationUnlocked() {
        for (wall, level) in [(false, 1), (true, 1), (false, 99), (true, 99)] {
            let vm = vm(wall: wall, level: level)
            XCTAssertEqual(vm.isEventPassOfferAvailable(eventID: eventID),
                           vm.isMonetizationUnlocked,
                           "wall=\(wall) level=\(level)")
        }
    }
}
