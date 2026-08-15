//
//  MergeOutcome.swift
//  PawSanctuary
//
//  Phase D, D1 of the BoardStateManager extraction — see
//  specs/BoardStateManager_Phase_D_Plan.md. `computeMergeOutcome` extracts
//  the deterministic decision inside attemptMergeOrMove's eligible-merge
//  branch (MergeBoardViewModel.swift, the `if let dstItem = ...` block) as a
//  pure, standalone function — the first piece of that function's logic to
//  become independently unit-testable.
//
//  NOT WIRED IN YET. attemptMergeOrMove still runs its own inline copy of
//  this logic unchanged; nothing player-facing changes in this phase. D2 is
//  the cutover that makes attemptMergeOrMove call this instead.
//
//  Deliberately narrow, per the Phase D doc's §3.1 resolution: this decides
//  the merge's deterministic facts only —
//    - whether the pair is eligible to merge at all (returns `nil` if not;
//      callers fall back to a plain swap, exactly as attemptMergeOrMove does)
//    - the resulting chain/tier, score/XP deltas, and whether it's a
//      top-tier completion vs. a bubble-*eligible* merge
//  It does NOT decide:
//    - whether a bubble-eligible merge actually bubbles — `maybeBubbleMergedItem`
//      additionally rolls `bubbleChance` (0.15) on top of eligibility (see the
//      Phase D doc §3's "second instance" note, found while writing D0)
//    - sub-object/power-up-completion inventory routing, or the passive-power
//      cascade (`applyPassivePowers`) — both stay procedural, reading
//      post-mutation board state and/or rolling their own randomness, which
//      is exactly why a single fully-pure `MergeResult` isn't achievable
//      (Phase D doc §3's forcing fact)
//

import Foundation

/// The deterministic outcome of merging the item at `from` into the item at
/// `to`. Produced by `computeMergeOutcome` — never board state or a game
/// action by itself; something else (eventually `apply(_ result: MergeResult)`,
/// today nothing — see the file header) is responsible for actually writing
/// it to the board and running the side-effect cascade.
struct MergeOutcome: Equatable {
    let from: GridPosition
    let to: GridPosition
    let resultChainID: ChainID
    let resultTier: Int
    /// Non-nil only when `resultChainID` is an `animal.*` chain — mirrors
    /// attemptMergeOrMove's own `AnimalSpecies(rawValue:)` parse, which is
    /// harmless-but-nil for every other chain category.
    let mergedSpecies: AnimalSpecies?
    let scoreDelta: Int
    let xpDelta: Int
    /// True when `resultTier` is `resultChainID`'s chain's max tier — the
    /// Ambassador-celebration path. Mutually exclusive with `isBubbleEligible`.
    let isTopTierCompletion: Bool
    /// True when this merge is a candidate for bubbling: below top tier, an
    /// `.animal`-category result at or above `bubbleMinTier`, and an active
    /// order/quest actually wants it (`isBubbleEligibleForQuestOrOrder`).
    /// Being eligible does not mean it *will* bubble — see the file header.
    let isBubbleEligible: Bool
}

/// Pure decision step for attemptMergeOrMove's eligible-merge branch. Returns
/// `nil` when `srcItem`/`dstItem` aren't eligible to merge — a bubbled
/// destination, an ineligible pair (different chain/tier and neither is a
/// wildcard), or `dstItem` already at its chain's top tier all fall back to
/// `nil`, matching attemptMergeOrMove's own `else { swap }` fallback exactly.
///
/// Takes the spotlight/order/quest state it needs as explicit parameters
/// (Phase D doc §3.6) rather than reading a `MergeBoardViewModel` — the whole
/// point of extracting this step is testing it without one. `ContentRegistry`
/// is the one implicit dependency, same as every other pure helper in this
/// codebase (`isBubbleEligibleForQuestOrOrder`, `spawnCost(forTier:)`) — it's
/// read-only content data, not mutable app state.
func computeMergeOutcome(
    from: GridPosition, to: GridPosition,
    srcItem: BoardItem, dstItem: BoardItem,
    spotlightChainID: ChainID, spotlightMultiplierBonus: Int,
    orders: [AdoptionOrder], urgentOrder: AdoptionOrder?, activeQuests: [Quest]
) -> MergeOutcome? {
    let srcIsWildcard = srcItem.chain?.category == .wildcard
    let dstIsWildcard = dstItem.chain?.category == .wildcard
    let isEligiblePair = srcIsWildcard != dstIsWildcard
        ? true
        : srcItem.chainID == dstItem.chainID && srcItem.tier == dstItem.tier
    guard dstItem.bubbledAt == nil, isEligiblePair else { return nil }

    // A wildcard adopts the other item's identity; a real-item pairing
    // (including a real item dragged onto a wildcard) keeps the source
    // item's own identity — mirrors attemptMergeOrMove's identical
    // `Optional(srcIsWildcard ? dstItem : srcItem)` shadow exactly.
    let identity = srcIsWildcard ? dstItem : srcItem
    guard let resultTier = ContentRegistry.shared.nextTier(identity.chainID, after: identity.tier) else { return nil }

    let tierDef = ContentRegistry.shared.tier(identity.chainID, identity.tier)
    let multiplier = identity.chainID == spotlightChainID ? (2 + spotlightMultiplierBonus) : 1
    let scoreDelta = (tierDef?.scoreValue ?? 0) * multiplier
    let xpDelta = tierDef?.xpValue ?? 0

    let chain = identity.chain
    let isTopTierCompletion = resultTier == (chain?.maxTier ?? Int.max)
    let mergedSpecies = AnimalSpecies(rawValue: identity.chainID.replacingOccurrences(of: "animal.", with: ""))

    var isBubbleEligible = false
    if !isTopTierCompletion, chain?.category == .animal, resultTier >= bubbleMinTier {
        isBubbleEligible = isBubbleEligibleForQuestOrOrder(
            chainID: identity.chainID, tier: resultTier,
            orders: orders, urgentOrder: urgentOrder, quests: activeQuests
        )
    }

    return MergeOutcome(
        from: from, to: to,
        resultChainID: identity.chainID, resultTier: resultTier,
        mergedSpecies: mergedSpecies,
        scoreDelta: scoreDelta, xpDelta: xpDelta,
        isTopTierCompletion: isTopTierCompletion,
        isBubbleEligible: isBubbleEligible
    )
}
