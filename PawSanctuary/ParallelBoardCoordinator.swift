//
//  ParallelBoardCoordinator.swift
//  PawSanctuary
//
//  Owns one active Parallel Board event's second-board state. Mirrors the
//  existing seven-sub-coordinator composition pattern MergeBoardViewModel
//  already uses (kibbleEngine, inventoryStore, quests, ...) — not a new
//  architecture. See specs/Spec_Phase6b_ParallelBoard.md §2.
//
//  Built incrementally: this task (§3.3) adds the fresh-board setup and the
//  generator mechanic. attemptMerge (§3.4) and event lifecycle (§3.7) land
//  in later tasks.
//

import Foundation
import Observation

@Observable
@MainActor
final class ParallelBoardCoordinator {
    let eventID: String
    let chainID: ChainID
    let boardState = BoardStateManager()
    var energy = ParallelBoardEnergy()

    /// Fixed for the event's lifetime. Per §3.3: the generator isn't a
    /// distinct cell type — it's an ordinary cell at a known position,
    /// tracked here, not by anything in the cell's own data. The UI queries
    /// this to render generator chrome on that one cell.
    let generatorPosition = GridPosition(row: 0, col: 0)

    init(eventID: String, chainID: ChainID) {
        self.eventID = eventID
        self.chainID = chainID
        boardState.board = (0..<parallelBoardRows).map { row in
            (0..<parallelBoardCols).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, producer: nil, isUnlocked: true)
            }
        }
        boardState.recalc()
    }

    /// Spends `parallelBoardGeneratorCost` energy to place a fresh base-tier
    /// item of the event's chain on a random empty cell — never on
    /// `generatorPosition` itself, which must stay clear for the next
    /// generation. Safely no-ops (no energy spent) when no eligible cell is
    /// open or the energy balance is insufficient. Mirrors `placeFreeTile`'s
    /// existing "find an empty cell, place an item" shape
    /// (MergeBoardViewModel.swift) without a producer struct, a cooldown, or
    /// a species field, none of which apply here.
    func collectFromGenerator() {
        let candidates = boardState.emptyUnlockedCells.filter { $0.position != generatorPosition }
        guard let target = candidates.randomElement() else { return }
        guard energy.spend(parallelBoardGeneratorCost) else { return }
        boardState.setItem(BoardItem(chainID: chainID, tier: 0), at: target.position)
        boardState.recalc()
    }
}
