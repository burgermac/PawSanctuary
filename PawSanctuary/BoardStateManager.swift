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
}
