//
//  MergeImplosionTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_BoardAnimation_Draft.md §8, task 8.1: a merge records its two
//  source items (read before the board write) as a short-lived MergeImplosion
//  for the view, then removes it after mergeImplosionDuration. No other
//  outcome records one. Task 8.2: a new attemptMergeOrMove naming an
//  in-flight implosion's destination (as from or to) settles it first.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class MergeImplosionTests: XCTestCase {

    private let catChain = ContentRegistry.animalChainID(.cat)
    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// An empty unlocked grid, no loadGame() — SpawnFlightTests' fixture pattern.
    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, chainID: ChainID, tier: Int, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier)
        vm.board = board
    }

    private func placeProducer(_ vm: MergeBoardViewModel, level: ProducerLevel, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].producer = ProducerTile(level: level)
        vm.board = board
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    func testAMergeRecordsAnImplosionWithBothSourceItems() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 1, at: a)
        place(vm, chainID: catChain, tier: 1, at: b)

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertEqual(vm.mergeImplosions.count, 1, "one merge records exactly one implosion")
        let record = vm.mergeImplosions.first
        XCTAssertEqual(record?.from, a)
        XCTAssertEqual(record?.to, b)
        XCTAssertEqual(record?.sourceItem.chainID, catChain)
        XCTAssertEqual(record?.sourceItem.tier, 1)
        XCTAssertEqual(record?.targetItem.chainID, catChain)
        XCTAssertEqual(record?.targetItem.tier, 1)
        // The model has already moved on: the result is on the board now.
        XCTAssertEqual(vm.boardState.item(at: b)?.tier, 2)
        XCTAssertNil(vm.boardState.item(at: a))
    }

    func testTheImplosionClearsAfterItsDuration() async {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)

        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.mergeImplosions.count, 1)

        await settle(mergeImplosionDuration + 0.25)
        XCTAssertTrue(vm.mergeImplosions.isEmpty, "the record is removed once the implosion window ends")
    }

    func testSwapsMovesAndProducerActionsRecordNoImplosion() {
        // Plain move onto an empty cell.
        let move = makeViewModel()
        place(move, chainID: catChain, tier: 2, at: a)
        move.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(move.boardState.item(at: b)?.tier, 2, "fixture check: it moved")
        XCTAssertTrue(move.mergeImplosions.isEmpty, "a move records no implosion")

        // Swap: an ineligible pair (different tiers).
        let swap = makeViewModel()
        place(swap, chainID: catChain, tier: 0, at: a)
        place(swap, chainID: catChain, tier: 3, at: b)
        swap.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(swap.boardState.item(at: a)?.tier, 3, "fixture check: they swapped")
        XCTAssertTrue(swap.mergeImplosions.isEmpty, "a swap records no implosion")

        // Producer upgrade: two matching producers.
        let upgrade = makeViewModel()
        placeProducer(upgrade, level: .rescueCrate, at: a)
        placeProducer(upgrade, level: .rescueCrate, at: b)
        upgrade.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(upgrade.boardState.producer(at: b)?.level, .shelterPod, "fixture check: it upgraded")
        XCTAssertTrue(upgrade.mergeImplosions.isEmpty, "a producer upgrade records no implosion")

        // Producer move onto an empty cell.
        let producerMove = makeViewModel()
        placeProducer(producerMove, level: .rescueCrate, at: a)
        producerMove.attemptMergeOrMove(from: a, to: b)
        XCTAssertTrue(producerMove.mergeImplosions.isEmpty, "a producer move records no implosion")

        // Producer swap: mismatched producers.
        let producerSwap = makeViewModel()
        placeProducer(producerSwap, level: .rescueCrate, at: a)
        placeProducer(producerSwap, level: .shelterPod, at: b)
        producerSwap.attemptMergeOrMove(from: a, to: b)
        XCTAssertTrue(producerSwap.mergeImplosions.isEmpty, "a producer swap records no implosion")

        // Superpower piece spent on a target.
        let spend = makeViewModel()
        place(spend, chainID: ContentRegistry.superpowerChainID(.cat), tier: 0, at: a)
        place(spend, chainID: catChain, tier: 2, at: b)
        spend.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(spend.boardState.item(at: a), "fixture check: the piece was spent")
        XCTAssertTrue(spend.mergeImplosions.isEmpty, "a superpower spend records no implosion")
    }

    func testAWildcardMergeRecordsTheWildcardAsItsSource() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 2, at: b)

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertEqual(vm.mergeImplosions.count, 1)
        let record = vm.mergeImplosions.first
        XCTAssertEqual(record?.sourceItem.chainID, ContentRegistry.wildcardChainID,
                       "the dragged wildcard is drawn as itself, not as a copy of the target")
        XCTAssertEqual(record?.sourceItem.tier, 0)
        XCTAssertEqual(record?.targetItem.chainID, catChain)
        XCTAssertEqual(record?.targetItem.tier, 2)
        XCTAssertEqual(vm.boardState.item(at: b)?.chainID, catChain, "fixture check: it merged")
        XCTAssertEqual(vm.boardState.item(at: b)?.tier, 3)
    }

    // MARK: - Task 8.2: settle-on-input

    func testASecondMergeOntoAnImplodingCellSettlesTheFirst() async {
        let vm = makeViewModel()
        let c = GridPosition(row: 1, col: 0)
        place(vm, chainID: catChain, tier: 1, at: a)
        place(vm, chainID: catChain, tier: 1, at: b)
        place(vm, chainID: catChain, tier: 2, at: c)

        vm.attemptMergeOrMove(from: a, to: b)          // b becomes tier 2, imploding
        let first = vm.mergeImplosions.first
        XCTAssertNotNil(first)

        vm.attemptMergeOrMove(from: c, to: b)          // rapid chain merge onto b
        XCTAssertEqual(vm.boardState.item(at: b)?.tier, 3, "fixture check: the chain merge happened")
        XCTAssertEqual(vm.mergeImplosions.count, 1, "the first implosion was settled, the second recorded")
        XCTAssertFalse(vm.mergeImplosions.contains { $0.id == first?.id }, "the settled record is gone")
        XCTAssertEqual(vm.mergeImplosions.first?.from, c)
        XCTAssertEqual(vm.mergeImplosions.first?.targetItem.tier, 2,
                       "the new record's target is the (hidden) tier-2 result of the first merge")

        // The first merge's delayed removal must not disturb anything; the
        // second's clears on its own schedule.
        await settle(mergeImplosionDuration + 0.25)
        XCTAssertTrue(vm.mergeImplosions.isEmpty)
    }

    func testMovingTheResultAwaySettlesItsImplosion() {
        let vm = makeViewModel()
        let c = GridPosition(row: 1, col: 0)
        place(vm, chainID: catChain, tier: 1, at: a)
        place(vm, chainID: catChain, tier: 1, at: b)

        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.mergeImplosions.count, 1)

        vm.attemptMergeOrMove(from: b, to: c)          // drag the hidden result away
        XCTAssertEqual(vm.boardState.item(at: c)?.tier, 2, "fixture check: the result moved")
        XCTAssertTrue(vm.mergeImplosions.isEmpty, "dragging the result away settles its implosion")
    }

    func testAnUnrelatedMergeLeavesAnInFlightImplosionAlone() {
        let vm = makeViewModel()
        let c = GridPosition(row: 1, col: 0)
        let d = GridPosition(row: 1, col: 1)
        place(vm, chainID: catChain, tier: 1, at: a)
        place(vm, chainID: catChain, tier: 1, at: b)
        place(vm, chainID: catChain, tier: 0, at: c)
        place(vm, chainID: catChain, tier: 0, at: d)

        vm.attemptMergeOrMove(from: a, to: b)
        let first = vm.mergeImplosions.first

        vm.attemptMergeOrMove(from: c, to: d)
        XCTAssertEqual(vm.mergeImplosions.count, 2, "merges in different cells do not settle each other")
        XCTAssertEqual(vm.mergeImplosions.first?.id, first?.id, "the first record is untouched")
        XCTAssertEqual(vm.mergeImplosions.last?.to, d)
    }

    func testTheImplosionTimingsSitInsideTheMeasuredReferenceRange() {
        XCTAssertGreaterThanOrEqual(mergeSlideDuration, 0.04)
        XCTAssertLessThanOrEqual(mergeSlideDuration, 0.08)
        XCTAssertGreaterThanOrEqual(mergeImplodeDuration, 0.06)
        XCTAssertLessThanOrEqual(mergeImplodeDuration, 0.12)
        XCTAssertEqual(mergeImplosionDuration, mergeSlideDuration + mergeImplodeDuration, accuracy: 1e-9)
    }

    // MARK: - Task 8.3: the Tier A pop waits for the implosion

    func testTheMergePopWaitsForTheImplosion() async {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)

        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.animatingCell, "no pop straight after release")

        await settle(mergeImplosionDuration + 0.15)
        XCTAssertEqual(vm.animatingCell, b, "the pop fires once the implosion window ends")
    }

    func testASettledImplosionNeverFiresItsPop() async {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)
        vm.attemptMergeOrMove(from: a, to: b)

        // Drag the hidden result away to a free cell: settles the implosion.
        let c = GridPosition(row: 1, col: 3)
        vm.attemptMergeOrMove(from: b, to: c)
        XCTAssertTrue(vm.mergeImplosions.isEmpty)

        await settle(mergeImplosionDuration + 0.15)
        XCTAssertNil(vm.animatingCell, "a settled implosion fires no stray burst")
    }
}
