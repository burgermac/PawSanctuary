//
//  AlbumSetRewardRampTests.swift
//  PawSanctuaryTests
//
//  Card-album set-reward ramp (specs/Spec_AlbumGrandPrize.md §4.2, §5.1,
//  §11 Task 4): a completed set pays by completion order from
//  `albumSetRewardRamp`, not by which set it is.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class AlbumSetRewardRampTests: XCTestCase {

    // MARK: Helpers

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.cardInventory = [:]
        vm.completedAlbumIDs = []
        vm.jokerCards = 0
        vm.rareJokerCards = 0
        vm.isPassActive = false
        vm.coins = 0
        vm.kibbleEngine.kibble = 0
        vm.kibbleEngine.dogTags = 0
        return vm
    }

    /// Completes `albumID` through the real path: owns every card but one
    /// common, then fills that one with a joker (`useJoker` runs
    /// `checkAlbumCompletions`).
    private func complete(_ albumID: String, in vm: MergeBoardViewModel,
                          file: StaticString = #filePath, line: UInt = #line) {
        guard let album = CardRegistry.albumsByID[albumID],
              let last = album.cardIDs.first(where: { CardRegistry.cardsByID[$0]?.rarity != .rare })
        else { return XCTFail("no common card in \(albumID)", file: file, line: line) }
        for id in album.cardIDs where id != last { vm.cardInventory[id] = 1 }
        vm.jokerCards += 1
        vm.useJoker(for: last)
        XCTAssertTrue(vm.completedAlbumIDs.contains(albumID), file: file, line: line)
    }

    private struct Balances: Equatable { let kibble: Int; let dogTags: Int; let coins: Int }

    private func balances(_ vm: MergeBoardViewModel) -> Balances {
        Balances(kibble: vm.kibbleEngine.kibble, dogTags: vm.kibbleEngine.dogTags, coins: vm.coins)
    }

    // MARK: The table

    func testRampHasOneRungPerSet() {
        XCTAssertEqual(albumSetRewardRamp.count, CardRegistry.albums.count)
    }

    func testRampIsMonotonicInEveryCurrency() {
        for (a, b) in zip(albumSetRewardRamp, albumSetRewardRamp.dropFirst()) {
            XCTAssertLessThan(a.kibble, b.kibble)
            XCTAssertLessThan(a.dogTags, b.dogTags)
            XCTAssertLessThan(a.coins, b.coins)
        }
    }

    func testRampMatchesTheSpecTable() {
        XCTAssertEqual(albumSetRewardRamp.map(\.kibble),  [100, 180, 260, 340, 420, 500])
        XCTAssertEqual(albumSetRewardRamp.map(\.dogTags), [5, 8, 10, 12, 15, 25])
        XCTAssertEqual(albumSetRewardRamp.map(\.coins),   [0, 500, 750, 1_000, 1_500, 2_500])
        XCTAssertEqual(albumSetRewardRamp.reduce(0) { $0 + $1.kibble },  1_800)
        XCTAssertEqual(albumSetRewardRamp.reduce(0) { $0 + $1.dogTags }, 75)
        XCTAssertEqual(albumSetRewardRamp.reduce(0) { $0 + $1.coins },   6_250)
    }

    func testRungPastTheEndPaysTheLastRung() {
        XCTAssertEqual(albumSetReward(forRung: 99), albumSetRewardRamp.last)
        XCTAssertEqual(albumSetReward(forRung: -1), albumSetRewardRamp.first)
    }

    // MARK: Payout

    /// Completes the sets in reverse registry order; rung N must still pay rung
    /// N, so the ramp follows completion order, not set identity.
    func testRungNPaysRungNWhicheverSetCompletes() {
        let vm = makeViewModel()
        let order = CardRegistry.albums.map(\.id).reversed()
        var total = Balances(kibble: 0, dogTags: 0, coins: 0)

        for (rung, albumID) in order.enumerated() {
            XCTAssertEqual(vm.nextAlbumSetReward, albumSetRewardRamp[rung])
            let before = balances(vm)
            complete(albumID, in: vm)
            let after = balances(vm)
            let expected = albumSetRewardRamp[rung]
            XCTAssertEqual(after.kibble  - before.kibble,  expected.kibble,  "rung \(rung + 1), \(albumID)")
            XCTAssertEqual(after.dogTags - before.dogTags, expected.dogTags, "rung \(rung + 1), \(albumID)")
            XCTAssertEqual(after.coins   - before.coins,   expected.coins,   "rung \(rung + 1), \(albumID)")
            total = after
        }

        XCTAssertEqual(total, Balances(kibble: 1_800, dogTags: 75, coins: 6_250))
    }

    func testPassBonusMultipliesKibbleOnly() {
        let vm = makeViewModel()
        vm.isPassActive = true
        // Rung 2: complete one set first, then measure the second.
        complete("album.fame", in: vm)
        let before = balances(vm)
        complete("album.vet", in: vm)
        let after = balances(vm)
        let rung = albumSetRewardRamp[1]

        XCTAssertEqual(after.kibble - before.kibble, Int(Double(rung.kibble) * passKibbleMultiplier))
        XCTAssertEqual(after.kibble - before.kibble, 270)
        XCTAssertEqual(after.dogTags - before.dogTags, rung.dogTags)
        XCTAssertEqual(after.coins - before.coins, rung.coins)
    }

    func testASetAlreadyCompletedIsNotPaidAgain() {
        let vm = makeViewModel()
        complete("album.wildlife", in: vm)
        let before = balances(vm)

        // Another card-path call that re-runs checkAlbumCompletions.
        guard let other = CardRegistry.albumsByID["album.rescue"]?.cardIDs
            .first(where: { CardRegistry.cardsByID[$0]?.rarity != .rare }) else {
            return XCTFail("no common card in album.rescue")
        }
        vm.jokerCards = 1
        vm.useJoker(for: other)

        XCTAssertEqual(balances(vm), before)
        XCTAssertEqual(vm.completedAlbumIDs, ["album.wildlife"])
    }

    /// A save whose sets were paid under the old per-set rewards is not
    /// back-paid: the next completion pays the rung after the ones it holds.
    func testPreviouslyCompletedSetsAreNotBackPaidAndShiftTheRung() {
        let vm = makeViewModel()
        vm.completedAlbumIDs = ["album.rescue", "album.sanctuary"]
        for id in ["album.rescue", "album.sanctuary"] {
            for card in CardRegistry.albumsByID[id]?.cardIDs ?? [] { vm.cardInventory[card] = 1 }
        }
        XCTAssertEqual(vm.nextAlbumSetReward, albumSetRewardRamp[2])

        let before = balances(vm)
        complete("album.adventures", in: vm)
        let after = balances(vm)

        XCTAssertEqual(after.kibble - before.kibble, albumSetRewardRamp[2].kibble)
        XCTAssertEqual(after.coins - before.coins, albumSetRewardRamp[2].coins)
        XCTAssertEqual(vm.completedAlbumIDs, ["album.rescue", "album.sanctuary", "album.adventures"])
    }

    // MARK: Economy

    /// Album kibble (set ramp plus the one-time grand prize, amortised over 60
    /// days) stays under 7% of a day's supply. The spec first set 5%, but its own
    /// 800-kibble prize took the figure to 43/day (6.2%), so the two
    /// contradicted each other. The owner chose 22 Nov 2026 to raise the guard to
    /// 7% and keep the prize: it is paid once, at the very end of the collection,
    /// and `testDemandSupplyRatioMatchesTheTargetCurve` does not read this figure
    /// (Spec_AlbumGrandPrize.md §12).
    func testAlbumKibbleStaysUnderSevenPercentOfDailySupply() {
        let perDay = EconomySimulation.albumKibblePerDay
        XCTAssertEqual(perDay, Double(1_800 + albumCollectionPrizeKibble) / EconomySimulation.amortisationDays, accuracy: 0.001)
        XCTAssertLessThan(perDay, albumKibbleGuardShareOfDailySupply * Double(EconomySimulation.dailySupply(level: 5)))
    }
}
