//
//  KibbleDriveGateTests.swift
//  PawSanctuaryTests
//
//  The Drive's tile shows before monetization unlocks (decided 8 Oct 2026), so
//  `isKibbleDriveBuyAvailable` is the one place D7's "no monetization in
//  session one" holds for it. A Debug build has no StoreKit configuration, so
//  the real price button never renders and the gate cannot be seen working —
//  `Spec_KibbleDrive_Draft.md` §6h — which is why it is tested here.
//
//  Dates are a fixed registry date, never Date().
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleDriveGateTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// A running, unpurchased Drive with monetization in the given state.
    private func vm(wall: Bool, level: Int, purchased: Bool = false) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2026-09-12"))
        vm.kibbleDrive?.purchased = purchased
        vm.commerce.hasReachedFirstWall = wall
        vm.progression.playerLevel = level
        return vm
    }

    func testBuyIsWithheldBeforeTheFirstWallEvenAtTheUnlockLevel() {
        XCTAssertFalse(vm(wall: false, level: monetizationUnlockLevel).isKibbleDriveBuyAvailable)
    }

    func testBuyIsWithheldBelowTheUnlockLevelEvenAfterTheWall() {
        XCTAssertFalse(vm(wall: true, level: monetizationUnlockLevel - 1).isKibbleDriveBuyAvailable)
    }

    func testBuyIsOfferedOnceBothMonetizationConditionsHold() {
        let vm = vm(wall: true, level: monetizationUnlockLevel)
        XCTAssertTrue(vm.isMonetizationUnlocked)
        XCTAssertTrue(vm.isKibbleDriveBuyAvailable)
    }

    func testBuyIsNotOfferedForADriveAlreadyPurchased() {
        XCTAssertFalse(vm(wall: true, level: monetizationUnlockLevel, purchased: true)
            .isKibbleDriveBuyAvailable)
    }

    func testBuyIsNotOfferedWhenNoDriveIsRunning() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2026-09-20"))      // between windows
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertNil(vm.kibbleDrive)
        XCTAssertFalse(vm.isKibbleDriveBuyAvailable)
    }

    /// The gate follows the shared D7 condition rather than a copy of it, so a
    /// future change to `isMonetizationUnlocked` reaches the Drive too.
    func testTheGateTracksIsMonetizationUnlocked() {
        for (wall, level) in [(false, 1), (true, 1), (false, 99), (true, 99)] {
            let vm = vm(wall: wall, level: level)
            XCTAssertEqual(vm.isKibbleDriveBuyAvailable, vm.isMonetizationUnlocked,
                           "wall=\(wall) level=\(level)")
        }
    }
}
