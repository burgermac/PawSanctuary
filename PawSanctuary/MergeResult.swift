//
//  MergeResult.swift
//  PawSanctuary
//
//  Phase D, D2 of the BoardStateManager extraction — see
//  specs/BoardStateManager_Phase_D_Plan.md. `MergeResult` is the dispatch
//  type §3.1 sketched: one case per structurally distinct outcome
//  attemptMergeOrMove can produce. Grown incrementally, one branch's cases
//  at a time, by that branch's first real caller — the same discipline
//  BoardStateManager's read/write primitives used (see that file's own doc
//  comment) — rather than declaring the full shape up front and leaving
//  most of it unused. Only the producer-branch cases exist so far; the
//  merge/superpower/swap/move cases arrive with their own D2 steps.
//
//  `MergeBoardViewModel.apply(_ result: MergeResult)` is the other half —
//  it lives in MergeBoardViewModel.swift itself, next to attemptMergeOrMove,
//  since applying a result is a genuine stateful ViewModel operation, not
//  pure logic. This file holds only the pure pieces: the enum and the free
//  functions that compute its cases.
//

import Foundation

enum MergeResult {
    case producerUpgrade(from: GridPosition, to: GridPosition, newLevel: ProducerLevel)
    case producerSwap(from: GridPosition, to: GridPosition, srcProducer: ProducerTile, dstProducer: ProducerTile)
    case producerMove(from: GridPosition, to: GridPosition, producer: ProducerTile)
    /// Nothing on the board changes. Used today for a producer dragged onto
    /// an item-occupied cell (attemptMergeOrMove's producer branch has no
    /// `else` for that combination) — reused as-is by later branches' own
    /// no-op cases rather than growing a new case per branch.
    case noOp
}

/// Computes what dragging the producer at `from` onto `to` should do —
/// attemptMergeOrMove's producer branch, extracted as a pure function.
/// Never nil: every input combination has a defined outcome, including the
/// currently-a-no-op case of a destination occupied by an item.
///
/// `dstProducer`/`dstItem` are passed in rather than looked up from a board,
/// same reasoning as `computeMergeOutcome` (MergeOutcome.swift) — testable
/// with fixture values, no `MergeBoardViewModel` required.
func computeProducerOutcome(
    from: GridPosition, to: GridPosition,
    srcProducer: ProducerTile, dstProducer: ProducerTile?, dstItem: BoardItem?
) -> MergeResult {
    if let dst = dstProducer {
        if srcProducer.level == dst.level, let nextLevel = srcProducer.level.next {
            return .producerUpgrade(from: from, to: to, newLevel: nextLevel)
        } else {
            return .producerSwap(from: from, to: to, srcProducer: srcProducer, dstProducer: dst)
        }
    } else if dstItem == nil {
        return .producerMove(from: from, to: to, producer: srcProducer)
    } else {
        return .noOp
    }
}
