import XCTest
@testable import PawSanctuary

/// Unit tests for `computeProducerOutcome` (Phase D, D2's producer-branch
/// step — see specs/BoardStateManager_Phase_D_Plan.md). No `MergeBoardViewModel`
/// needed for the pure-function tests; the last section cross-checks against
/// `attemptMergeOrMove` on a real ViewModel, same structure as `MergeOutcomeTests`.
@MainActor
final class MergeResultTests: XCTestCase {

    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    private func producer(_ level: ProducerLevel) -> ProducerTile { ProducerTile(level: level) }

    // MARK: computeProducerOutcome — pure

    func testSameLevelWithANextLevelUpgrades() {
        let result = computeProducerOutcome(from: a, to: b,
                                             srcProducer: producer(.rescueCrate),
                                             dstProducer: producer(.rescueCrate), dstItem: nil)
        guard case .producerUpgrade(let from, let to, let newLevel) = result else {
            return XCTFail("expected .producerUpgrade, got \(result)")
        }
        XCTAssertEqual(from, a)
        XCTAssertEqual(to, b)
        XCTAssertEqual(newLevel, .shelterPod)
    }

    func testSameLevelWithNoNextLevelSwapsInstead() {
        // .fosterHome has no `.next` — two of them meeting can't upgrade, so
        // this must fall through to the swap branch despite being "same level."
        let result = computeProducerOutcome(from: a, to: b,
                                             srcProducer: producer(.fosterHome),
                                             dstProducer: producer(.fosterHome), dstItem: nil)
        guard case .producerSwap = result else {
            return XCTFail("expected .producerSwap, got \(result)")
        }
    }

    func testDifferentLevelsSwap() {
        let result = computeProducerOutcome(from: a, to: b,
                                             srcProducer: producer(.rescueCrate),
                                             dstProducer: producer(.shelterPod), dstItem: nil)
        guard case .producerSwap(let from, let to, let src, let dst) = result else {
            return XCTFail("expected .producerSwap, got \(result)")
        }
        XCTAssertEqual(from, a)
        XCTAssertEqual(to, b)
        XCTAssertEqual(src.level, .rescueCrate)
        XCTAssertEqual(dst.level, .shelterPod)
    }

    func testEmptyDestinationMoves() {
        let result = computeProducerOutcome(from: a, to: b,
                                             srcProducer: producer(.familySpawner),
                                             dstProducer: nil, dstItem: nil)
        guard case .producerMove(let from, let to, let moved) = result else {
            return XCTFail("expected .producerMove, got \(result)")
        }
        XCTAssertEqual(from, a)
        XCTAssertEqual(to, b)
        XCTAssertEqual(moved.level, .familySpawner)
    }

    func testItemOccupiedDestinationIsANoOp() {
        let result = computeProducerOutcome(from: a, to: b,
                                             srcProducer: producer(.rescueCrate),
                                             dstProducer: nil,
                                             dstItem: BoardItem(chainID: ContentRegistry.animalChainID(.cat), tier: 0))
        guard case .noOp = result else {
            return XCTFail("expected .noOp, got \(result)")
        }
    }

    // MARK: Cross-check against the real attemptMergeOrMove (D0)

    private func makeBoard() -> [[BoardCell]] {
        (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
    }

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = makeBoard()
        return vm
    }

    private func placeProducer(_ vm: MergeBoardViewModel, level: ProducerLevel, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].producer = ProducerTile(level: level)
        vm.board = board
    }

    func testComputedOutcomeMatchesAttemptMergeOrMoveForASameLevelUpgrade() {
        let vm = makeViewModel()
        placeProducer(vm, level: .rescueCrate, at: a)
        placeProducer(vm, level: .rescueCrate, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].producer)
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .shelterPod)
    }

    func testComputedOutcomeMatchesAttemptMergeOrMoveForADifferentLevelSwap() {
        let vm = makeViewModel()
        placeProducer(vm, level: .rescueCrate, at: a)
        placeProducer(vm, level: .shelterPod, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].producer?.level, .shelterPod)
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .rescueCrate)
    }

    func testComputedOutcomeMatchesAttemptMergeOrMoveForAMoveToEmpty() {
        let vm = makeViewModel()
        placeProducer(vm, level: .familySpawner, at: a)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].producer)
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .familySpawner)
    }
}
