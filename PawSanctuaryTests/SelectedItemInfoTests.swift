import XCTest
@testable import PawSanctuary

/// `MergeBoardViewModel.selectedItemInfo` top-tier suffix: "Ambassador" is the
/// animal top tier's name only, so non-animal chains must say "Top tier".
@MainActor
final class SelectedItemInfoTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private let pos = GridPosition(row: 0, col: 0)

    /// A fully unlocked, empty board with one item at `pos`, selected.
    /// `loadGame()` is never called, so nothing touches disk or timers.
    private func makeViewModel(chainID: ChainID, tier: Int) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        var board: [[BoardCell]] = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier)
        vm.board = board
        vm.selectedCell = pos
        return vm
    }

    private func maxTier(_ id: ChainID) throws -> Int {
        try XCTUnwrap(ContentRegistry.shared.chain(id)).maxTier
    }

    func testTopTierAnimalSaysAmbassador() throws {
        let id = ContentRegistry.animalChainID(.cat)
        let vm = makeViewModel(chainID: id, tier: try maxTier(id))
        let info = try XCTUnwrap(vm.selectedItemInfo)
        XCTAssertTrue(info.text.hasSuffix(" · Ambassador — top tier"), info.text)
        XCTAssertEqual(info.chainID, id)
    }

    func testTopTierSupplySaysTopTier() throws {
        let id = ContentRegistry.groomingChainID
        let vm = makeViewModel(chainID: id, tier: try maxTier(id))
        let info = try XCTUnwrap(vm.selectedItemInfo)
        XCTAssertTrue(info.text.hasSuffix(" · Top tier"), info.text)
        XCTAssertFalse(info.text.contains("Ambassador"), info.text)
        XCTAssertEqual(info.chainID, id)
    }

    func testTopTierMaterialSaysTopTier() throws {
        let id = ContentRegistry.woodChainID
        let vm = makeViewModel(chainID: id, tier: try maxTier(id))
        let info = try XCTUnwrap(vm.selectedItemInfo)
        XCTAssertTrue(info.text.hasSuffix(" · Top tier"), info.text)
        XCTAssertFalse(info.text.contains("Ambassador"), info.text)
    }
}
