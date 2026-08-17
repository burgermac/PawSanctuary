//
//  ParallelBoardCoordinator.swift
//  PawSanctuary
//
//  Owns one active Parallel Board event's second-board state. Mirrors the
//  existing seven-sub-coordinator composition pattern MergeBoardViewModel
//  already uses (kibbleEngine, inventoryStore, quests, ...) — not a new
//  architecture. See specs/Spec_Phase6b_ParallelBoard.md §2.
//
//  Built incrementally: §3.3 added the fresh-board setup and the generator
//  mechanic; this task (§3.4) adds merge resolution. Event lifecycle (§3.7)
//  lands in a later task.
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

    /// Reuses `computeMergeOutcome` for the merge *decision* (Phase D) and
    /// writes a small new application step on top of it — deliberately a
    /// fifth of `attemptMergeOrMove`'s size (`MergeBoardViewModel.swift`):
    /// no producer branch (nothing on this board is a producer, per §3.3),
    /// no superpower branch (the event's chain has no superpower pieces), no
    /// bubbling (`orders`/`activeQuests` passed empty guarantees
    /// `isBubbleEligible` is always `false`), no Nine Lives snapshot (a
    /// 3-day side board doesn't need the undo guard the main board's own
    /// economy needed). Neutral spotlight — nothing on this board earns a
    /// spotlight bonus.
    func attemptMerge(from: GridPosition, to: GridPosition) {
        guard from != to,
              boardState.isUnlocked(at: from), boardState.isUnlocked(at: to),
              let srcItem = boardState.item(at: from) else { return }
        guard let dstItem = boardState.item(at: to) else {
            boardState.setItem(srcItem, at: to)
            boardState.clearItem(at: from)
            boardState.recalc()
            return
        }
        if let outcome = computeMergeOutcome(
            from: from, to: to, srcItem: srcItem, dstItem: dstItem,
            spotlightChainID: "parallelboard.none", spotlightMultiplierBonus: 0,
            orders: [], urgentOrder: nil, activeQuests: []
        ) {
            boardState.setItem(BoardItem(chainID: outcome.resultChainID, tier: outcome.resultTier), at: to)
            boardState.clearItem(at: from)
            boardState.recalc()
            if outcome.isTopTierCompletion {
                // award the event's ProgressTrack — see §3.5
            }
        } else {
            boardState.setItem(srcItem, at: to)
            boardState.setItem(dstItem, at: from)
        }
    }
}
