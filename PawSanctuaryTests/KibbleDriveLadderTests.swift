//
//  KibbleDriveLadderTests.swift
//  PawSanctuaryTests
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) §6 step 4 — the §3.3 rung
//  table, the claim path, and §3.5's safety ratio re-derived from the economy
//  model so a later retune fails loudly.
//
//  Dates are fixed registry dates, never Date().
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleDriveLadderTests: XCTestCase {

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

    private func runningDrive(points: Int, purchased: Bool) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date("2026-09-12"))
        vm.kibbleDrive?.points = points
        vm.kibbleDrive?.purchased = purchased
        return vm
    }

    // MARK: The table

    func testLadderMatchesSection33() {
        let rungs = KibbleDriveLadder.rungs
        XCTAssertEqual(rungs.count, 15)
        XCTAssertEqual(rungs.map(\.index), Array(0..<15))
        XCTAssertEqual(KibbleDriveLadder.topThreshold, 300)
        XCTAssertEqual(KibbleDriveLadder.totalKibble, 540, "headline copy is 'Earn up to 540 Kibble'")

        let packs = rungs.flatMap(\.paidRewards).filter { $0.kind == .cardPack }
        XCTAssertEqual(packs.compactMap(\.payloadID), ["star4", "star5"])
        XCTAssertEqual(rungs[9].paidRewards.contains { $0.payloadID == "star4" }, true)
        XCTAssertEqual(rungs[14].paidRewards.contains { $0.payloadID == "star5" }, true)
    }

    func testThresholdsStrictlyAscendAndThereIsNoFreeLane() {
        let thresholds = KibbleDriveLadder.rungs.map(\.threshold)
        XCTAssertEqual(thresholds, thresholds.sorted())
        XCTAssertEqual(Set(thresholds).count, thresholds.count)
        XCTAssertTrue(KibbleDriveLadder.rungs.allSatisfy { $0.freeRewards.isEmpty },
                      "§2: the Drive has no free lane")
    }

    // MARK: Claiming

    func testNothingIsClaimableUntilPurchased() {
        let vm = runningDrive(points: 120, purchased: false)
        XCTAssertTrue(vm.kibbleDriveClaimableRungs.isEmpty)
        let before = vm.kibbleEngine.kibble
        vm.claimKibbleDriveRung(index: 0)
        XCTAssertEqual(vm.kibbleEngine.kibble, before)
        XCTAssertEqual(vm.kibbleDrive?.claimedRungs, [])
    }

    func testPurchasedDriveOffersExactlyTheRungsThePointsReach() {
        let vm = runningDrive(points: 50, purchased: true)
        XCTAssertEqual(vm.kibbleDriveClaimableRungs.map(\.index), [0, 1, 2, 3],
                       "thresholds 10, 22, 35, 50")
    }

    func testClaimingPaysTheRungAndMarksItClaimed() {
        let vm = runningDrive(points: 50, purchased: true)
        let before = vm.kibbleEngine.kibble
        vm.claimKibbleDriveRung(index: 1)
        XCTAssertEqual(vm.kibbleEngine.kibble, before + 30)
        XCTAssertEqual(vm.kibbleDrive?.claimedRungs, [1])
        XCTAssertEqual(vm.kibbleDriveClaimableRungs.map(\.index), [0, 2, 3])
    }

    func testARungCannotBePaidTwice() {
        let vm = runningDrive(points: 50, purchased: true)
        vm.claimKibbleDriveRung(index: 0)
        let after = vm.kibbleEngine.kibble
        vm.claimKibbleDriveRung(index: 0)
        XCTAssertEqual(vm.kibbleEngine.kibble, after)
        XCTAssertEqual(vm.kibbleDrive?.claimedRungs, [0])
    }

    func testARungAboveThePointsCannotBeClaimed() {
        let vm = runningDrive(points: 49, purchased: true)
        let before = vm.kibbleEngine.kibble
        vm.claimKibbleDriveRung(index: 3)       // threshold 50
        XCTAssertEqual(vm.kibbleEngine.kibble, before)
        XCTAssertEqual(vm.kibbleDrive?.claimedRungs, [])
    }

    func testClaimingEveryRungPaysTheFullLadder() {
        let vm = runningDrive(points: 300, purchased: true)
        let before = vm.kibbleEngine.kibble
        for rung in KibbleDriveLadder.rungs { vm.claimKibbleDriveRung(index: rung.index) }
        XCTAssertEqual(vm.kibbleEngine.kibble, before + 540)
        XCTAssertEqual(vm.pendingCardPacks, [.star4, .star5])
        XCTAssertTrue(vm.kibbleDriveClaimableRungs.isEmpty)
    }

    func testAnUnknownRungIndexIsIgnored() {
        let vm = runningDrive(points: 300, purchased: true)
        vm.claimKibbleDriveRung(index: 99)
        XCTAssertEqual(vm.kibbleDrive?.claimedRungs, [])
    }

    func testClaimedRungsSurviveARelaunch() {
        let vm = runningDrive(points: 100, purchased: true)
        vm.claimKibbleDriveRung(index: 0)
        let saved = vm.kibbleDrive
        XCTAssertEqual(saved?.claimedRungs, [0])
        // The lifecycle must not reset a Drive that already belongs to the
        // running event (§6c) — a relaunch inside the window keeps its claims.
        vm.checkEventLifecycle(at: date("2026-09-12"))
        XCTAssertEqual(vm.kibbleDrive, saved)
    }

    // MARK: §3.5's ratio, against the economy model

    /// Points an engaged player earns per day, rebuilt from the model's own
    /// constants (§3.2) rather than read from `kibbleDrivePointsPerDay`, so a
    /// retune of `carePointsPerOrder`, `orderCyclesPerDay` or the quest values
    /// fails here instead of silently opening the faucet.
    private var modelledPointsPerDay: Double {
        let level = EconomySimulation.projectionLevel
        let orders = EconomySimulation.ordersPerDay(level: level) * Double(carePointsPerOrder)
        let sweep = Double(carePointsPerDailySweep) * 6.0 / 7.0
        let averageQuest = Double(carePoints(forQuest: .easy)
                                  + carePoints(forQuest: .medium)
                                  + carePoints(forQuest: .hard)) / 3.0
        let quests = EconomySimulation.questClaimsPerDay * averageQuest
        return orders + sweep + quests
    }

    func testTheShippedPointsPerDayMatchesTheModel() {
        XCTAssertEqual(modelledPointsPerDay, Double(kibbleDrivePointsPerDay), accuracy: 2.0,
                       "kibbleDrivePointsPerDay must be re-derived when a Care Points source is retuned")
    }

    func testTheLadderCannotBeLoopedForKibble() {
        let spentPerPoint = Double(EconomySimulation.dailySupply(level: EconomySimulation.projectionLevel))
            / modelledPointsPerDay
        let paidPerPoint = Double(KibbleDriveLadder.totalKibble) / Double(KibbleDriveLadder.topThreshold)

        XCTAssertEqual(paidPerPoint, 1.8, accuracy: 0.001)
        let margin = spentPerPoint / paidPerPoint
        XCTAssertGreaterThan(margin, 3.0, "§3.5 measured ~3.9x")
        // And with the worst-case late-purchase grant (§6d) still above 2x.
        XCTAssertGreaterThan(margin / (1 + kibbleDriveCatchUpCap), 2.0)
    }
}
