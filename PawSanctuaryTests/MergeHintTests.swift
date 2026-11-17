import XCTest
@testable import PawSanctuary

/// The idle-hint pair search, including bubble merges
/// (specs/Spec_MergeFreesBubble.md).
@MainActor
final class MergeHintTests: XCTestCase {
    private let cat = ContentRegistry.animalChainID(.cat)
    private let hamster = ContentRegistry.animalChainID(.hamster)
    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)
    private let c = GridPosition(row: 0, col: 2)
    private var activeStamp: Double { Date().timeIntervalSince1970 }

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true) }
        }
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, _ chain: ChainID, _ tier: Int, _ pos: GridPosition, bubbledAt: Double? = nil) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chain, tier: tier, bubbledAt: bubbledAt)
        vm.board = board
    }

    func testTwoNormalPiecesStillPair() {
        let vm = makeViewModel()
        place(vm, cat, 2, a); place(vm, cat, 2, b)
        let pair = vm.findMergeableHintPair()
        XCTAssertEqual(pair?.0, a); XCTAssertEqual(pair?.1, b)
    }

    func testNormalAndActiveBubbleOfSameSpeciesAndLevelPair_normalFirst() {
        let vm = makeViewModel()
        place(vm, cat, 3, a, bubbledAt: activeStamp)   // bubble found first in scan order
        place(vm, cat, 3, b)
        let pair = vm.findMergeableHintPair()
        XCTAssertEqual(pair?.0, b, "the piece to drag (normal) comes first")
        XCTAssertEqual(pair?.1, a, "the bubble is the drop target")
    }

    func testNormalBeforeBubbleInScanOrderAlsoPairsNormalFirst() {
        let vm = makeViewModel()
        place(vm, cat, 3, a)
        place(vm, cat, 3, b, bubbledAt: activeStamp)
        let pair = vm.findMergeableHintPair()
        XCTAssertEqual(pair?.0, a); XCTAssertEqual(pair?.1, b)
    }

    func testTwoBubblesNeverPair() {
        let vm = makeViewModel()
        place(vm, cat, 3, a, bubbledAt: activeStamp)
        place(vm, cat, 3, b, bubbledAt: activeStamp)
        XCTAssertNil(vm.findMergeableHintPair())
    }

    func testDecayedBubbleDoesNotPair() {
        let vm = makeViewModel()
        place(vm, cat, 3, a, bubbledAt: 1_000)
        place(vm, cat, 3, b)
        XCTAssertNil(vm.findMergeableHintPair())
    }

    func testBubbleOfDifferentLevelOrSpeciesDoesNotPair() {
        let vm = makeViewModel()
        place(vm, cat, 3, a, bubbledAt: activeStamp)
        place(vm, cat, 2, b)
        place(vm, hamster, 3, c)
        XCTAssertNil(vm.findMergeableHintPair())
    }
}
