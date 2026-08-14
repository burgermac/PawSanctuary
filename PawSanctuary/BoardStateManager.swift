//
//  BoardStateManager.swift
//  PawSanctuary
//
//  Board state extracted from MergeBoardViewModel — Phase B of the extraction
//  in specs/BoardStateManager_Extraction_Plan.md. Owns the board array and its
//  derived "is it full / which cells are open" cache.
//
//  Deliberately narrow for this phase: merge resolution, spawning, and every
//  other board-mutating function stay on MergeBoardViewModel, reaching `board`
//  through the computed passthrough there (same technique already used for
//  `kibble`/`dogTags` forwarding to KibbleEngine) — none of this file's ~40
//  direct `board[...]` call sites needed to change. Moving that logic here is
//  Phase D, deliberately not attempted in this pass; see the plan doc for why.
//

import SwiftUI
import Observation

@Observable
@MainActor
class BoardStateManager {
    var board: [[BoardCell]] = []
    private(set) var boardIsFull: Bool = false
    /// Empty, unlocked cells — recomputed once in `recalc()` instead of
    /// re-scanning all 63 cells at every call site that needs a spawn/
    /// placement target. Moved verbatim from the old `recalcBoardIsFull()`.
    private(set) var emptyUnlockedCells: [BoardCell] = []

    /// Recomputes `boardIsFull`/`emptyUnlockedCells` from `board`. Callers that
    /// also need `exchangeableTrios` refreshed should go through
    /// `MergeBoardViewModel.recalcBoardIsFull()`, which wraps this and handles
    /// that separately — trio eligibility isn't board state, so it doesn't
    /// belong on this class.
    func recalc() {
        let flat = board.flatMap { $0 }
        let unlocked = flat.filter { $0.isUnlocked }
        boardIsFull = unlocked.allSatisfy { !$0.isEmpty }
        emptyUnlockedCells = unlocked.filter { $0.isEmpty }
    }

    // MARK: Read/write primitives (Phase C)
    //
    // Added on demand as real call sites migrate — not a guessed-up-front API.
    // First three callers: MergeBoardViewModel.sendBoardItemToInventory,
    // .storeSelectedItemToInventory, .sellSelectedAnimal (see the extraction
    // plan's Phase C). Callers remain responsible for their own bounds checks
    // and for calling `recalc()`/`MergeBoardViewModel.recalcBoardIsFull()`
    // afterward — these primitives don't do either, matching what the direct
    // `board[...]` access they replace did.

    func item(at pos: GridPosition) -> BoardItem? { board[pos.row][pos.col].item }
    func hasProducer(at pos: GridPosition) -> Bool { board[pos.row][pos.col].producer != nil }
    func clearItem(at pos: GridPosition) { board[pos.row][pos.col].item = nil }

    /// Sets (or overwrites) the item at `pos`. Added for the superpower group
    /// (Phase C): `applyAquaticsCurrent` is the first caller, sliding a
    /// sub-object into a newly-emptied cell.
    func setItem(_ item: BoardItem?, at pos: GridPosition) { board[pos.row][pos.col].item = item }

    /// Sets or clears the bubble timestamp on the item at `pos`. No-op if the
    /// cell is empty — matches the optional-chaining behavior of the direct
    /// `board[...].item?.bubbledAt = ...` writes this replaces. Added for the
    /// bubble-mechanic group (Phase C, round 2): `maybeBubbleMergedItem` sets
    /// it, `popBubbleWithDogTags`/`popBubbleWithAd` clear it.
    func setBubbledAt(_ timestamp: Double?, at pos: GridPosition) {
        board[pos.row][pos.col].item?.bubbledAt = timestamp
    }
}
