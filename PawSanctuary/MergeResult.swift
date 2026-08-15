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
//  most of it unused. Producer and eligible-merge cases exist so far; the
//  superpower-piece-spent/ineligible-swap/empty-move cases arrive with
//  their own D2 steps.
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
    /// Nothing on the board changes — a producer dragged onto an
    /// item-occupied cell (attemptMergeOrMove's producer branch has no
    /// `else` for that combination). Named for the producer branch
    /// specifically, not a generic "no-op" — `apply(_:)` still runs the
    /// producer branch's recalc+deselect tail for this case (matching the
    /// original inline code exactly), which is *not* the right tail for
    /// every branch's idea of "nothing happened" (the top-level from==to/
    /// out-of-bounds/locked guards, for instance, do nothing at all — no
    /// recalc, no deselect). A future branch's own no-op gets its own case
    /// once it exists, rather than this one being stretched to cover it.
    case producerBlocked
    case merge(MergeOutcome)
    /// A superpower piece (e.g. `superpower.cat`, the Splitter) dragged onto
    /// `target` at `to`. Unlike `.merge`, there's no companion `computeX`
    /// free function — the "decision" here is a one-line category check
    /// already at attemptMergeOrMove's call site, and `applySuperpowerMerge`
    /// (the actual dispatcher to Splitter/Stampede/Sprint/Leap/Mimic) is
    /// itself procedural, not something a pure step could decide in advance
    /// — each handler "owns whatever mutation the target cell needs," per
    /// its own doc comment. This case exists to carry data across the
    /// compute/apply boundary, same shape as the others, not because there
    /// was a deterministic outcome worth extracting.
    case superpowerPieceSpent(from: GridPosition, to: GridPosition, pieceChainID: ChainID, target: BoardItem)
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
        return .producerBlocked
    }
}
