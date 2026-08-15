import XCTest
@testable import PawSanctuary

/// Unit tests for `computeMergeOutcome` (Phase D, D1 — see
/// specs/BoardStateManager_Phase_D_Plan.md). Unlike
/// `AttemptMergeOrMoveCharacterizationTests`, these need no `MergeBoardViewModel`
/// at all — that's the point of extracting a pure function. The last two tests
/// are a deliberate exception: they cross-check `computeMergeOutcome` against
/// the real `attemptMergeOrMove` (already characterized in D0) to build
/// confidence the extraction is faithful, not just internally self-consistent.
@MainActor
final class MergeOutcomeTests: XCTestCase {

    private let catChain = ContentRegistry.animalChainID(.cat)
    private let hamsterChain = ContentRegistry.animalChainID(.hamster)
    private let subObjectChain = "subobject.\(AnimalSpecies.hamster.rawValue)"
    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    private func makeOrder(chainID: ChainID, tier: Int) -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0, wantedChainID: chainID, wantedTier: tier, wantedCount: 1)
    }

    /// Neutral defaults: no spotlight multiplier, no orders/quests. Individual
    /// tests override only the parameters they care about.
    private func compute(srcItem: BoardItem, dstItem: BoardItem,
                          spotlightChainID: ChainID = ContentRegistry.animalChainID(.dog),
                          spotlightMultiplierBonus: Int = 0,
                          orders: [AdoptionOrder] = [], urgentOrder: AdoptionOrder? = nil,
                          activeQuests: [Quest] = []) -> MergeOutcome? {
        computeMergeOutcome(from: a, to: b, srcItem: srcItem, dstItem: dstItem,
                             spotlightChainID: spotlightChainID, spotlightMultiplierBonus: spotlightMultiplierBonus,
                             orders: orders, urgentOrder: urgentOrder, activeQuests: activeQuests)
    }

    // MARK: Eligibility → nil

    func testIneligibleDifferentChainAndTierReturnsNil() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                              dstItem: BoardItem(chainID: hamsterChain, tier: 3))
        XCTAssertNil(result)
    }

    func testBubbledDestinationReturnsNilEvenForAnOtherwiseEligiblePair() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 3),
                              dstItem: BoardItem(chainID: catChain, tier: 3, bubbledAt: 1_000))
        XCTAssertNil(result)
    }

    func testDestinationAlreadyAtTopTierReturnsNil() {
        let top = animalChainTopTier
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: top),
                              dstItem: BoardItem(chainID: catChain, tier: top))
        XCTAssertNil(result)
    }

    func testTwoWildcardsReturnNil() {
        let wc = ContentRegistry.wildcardChainID
        let result = compute(srcItem: BoardItem(chainID: wc, tier: 0), dstItem: BoardItem(chainID: wc, tier: 0))
        XCTAssertNil(result)
    }

    // MARK: Eligible merges — identity and tier

    func testSameChainSameTierAdvancesOneTier() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                              dstItem: BoardItem(chainID: catChain, tier: 0))
        XCTAssertEqual(result?.resultChainID, catChain)
        XCTAssertEqual(result?.resultTier, 1)
        XCTAssertEqual(result?.from, a)
        XCTAssertEqual(result?.to, b)
        XCTAssertEqual(result?.mergedSpecies, .cat)
    }

    func testWildcardAsSourceAdoptsDestinationIdentity() {
        let result = compute(srcItem: BoardItem(chainID: ContentRegistry.wildcardChainID, tier: 0),
                              dstItem: BoardItem(chainID: catChain, tier: 2))
        XCTAssertEqual(result?.resultChainID, catChain)
        XCTAssertEqual(result?.resultTier, 3)
    }

    func testWildcardAsDestinationAdoptsSourceIdentity() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 2),
                              dstItem: BoardItem(chainID: ContentRegistry.wildcardChainID, tier: 0))
        XCTAssertEqual(result?.resultChainID, catChain)
        XCTAssertEqual(result?.resultTier, 3)
    }

    func testNonAnimalChainMergeHasNoMergedSpecies() {
        let result = compute(srcItem: BoardItem(chainID: subObjectChain, tier: 0),
                              dstItem: BoardItem(chainID: subObjectChain, tier: 0))
        XCTAssertEqual(result?.resultChainID, subObjectChain)
        XCTAssertNil(result?.mergedSpecies)
    }

    // MARK: Score / XP

    func testScoreAndXPMatchTheSourceTierDefinitionAtOneXMultiplier() {
        let tierDef = ContentRegistry.shared.tier(catChain, 0)!
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                              dstItem: BoardItem(chainID: catChain, tier: 0),
                              spotlightChainID: ContentRegistry.animalChainID(.dog)) // not .cat — no multiplier
        XCTAssertEqual(result?.scoreDelta, tierDef.scoreValue)
        XCTAssertEqual(result?.xpDelta, tierDef.xpValue)
    }

    func testSpotlightChainDoublesScoreButNotXP() {
        let tierDef = ContentRegistry.shared.tier(catChain, 0)!
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                              dstItem: BoardItem(chainID: catChain, tier: 0),
                              spotlightChainID: catChain, spotlightMultiplierBonus: 0)
        XCTAssertEqual(result?.scoreDelta, tierDef.scoreValue * 2, "base spotlight multiplier is 2x")
        XCTAssertEqual(result?.xpDelta, tierDef.xpValue, "spotlight only affects score, not XP — matches attemptMergeOrMove")
    }

    func testSpotlightMultiplierBonusAddsToTheBase2x() {
        let tierDef = ContentRegistry.shared.tier(catChain, 0)!
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                              dstItem: BoardItem(chainID: catChain, tier: 0),
                              spotlightChainID: catChain, spotlightMultiplierBonus: 3)
        XCTAssertEqual(result?.scoreDelta, tierDef.scoreValue * 5, "2 base + 3 bonus")
    }

    // MARK: Top-tier completion vs. bubble eligibility

    func testTopTierCompletionSetsFlagAndNeverBubbleEligible() {
        let top = animalChainTopTier
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: top - 1),
                              dstItem: BoardItem(chainID: catChain, tier: top - 1))
        XCTAssertTrue(result!.isTopTierCompletion)
        XCTAssertFalse(result!.isBubbleEligible, "top-tier completion and bubbling are mutually exclusive")
    }

    func testBelowBubbleMinTierIsNeverBubbleEligibleRegardlessOfOrders() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: bubbleMinTier - 2),
                              dstItem: BoardItem(chainID: catChain, tier: bubbleMinTier - 2),
                              orders: [makeOrder(chainID: catChain, tier: bubbleMinTier - 1)])
        XCTAssertFalse(result!.isBubbleEligible, "result tier is still below bubbleMinTier")
    }

    func testAtOrAboveBubbleMinTierWithAMatchingOrderIsBubbleEligible() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: bubbleMinTier),
                              dstItem: BoardItem(chainID: catChain, tier: bubbleMinTier),
                              orders: [makeOrder(chainID: catChain, tier: bubbleMinTier + 1)])
        XCTAssertTrue(result!.isBubbleEligible)
    }

    func testAtOrAboveBubbleMinTierWithoutAMatchingOrderOrQuestIsNotBubbleEligible() {
        let result = compute(srcItem: BoardItem(chainID: catChain, tier: bubbleMinTier),
                              dstItem: BoardItem(chainID: catChain, tier: bubbleMinTier))
        XCTAssertFalse(result!.isBubbleEligible)
    }

    func testNonAnimalChainIsNeverBubbleEligibleEvenWithAMatchingOrder() {
        // subObject/material/etc. chains can merge (this function doesn't
        // restrict identity to .animal), but only .animal results bubble —
        // matches attemptMergeOrMove's `else if srcItem.chain?.category == .animal`.
        let result = compute(srcItem: BoardItem(chainID: subObjectChain, tier: bubbleMinTier),
                              dstItem: BoardItem(chainID: subObjectChain, tier: bubbleMinTier),
                              orders: [makeOrder(chainID: subObjectChain, tier: bubbleMinTier + 1)])
        // (subObjectChain only has 4 tiers, so bubbleMinTier=5 would already be
        // out of range for nextTier — this exercises the eligibility guard too.)
        XCTAssertNil(result, "sanity check: this chain has no tier past its 4-stage max")
    }

    func testNonAnimalChainBelowItsTopTierIsNeverBubbleEligible() {
        let result = compute(srcItem: BoardItem(chainID: subObjectChain, tier: 0),
                              dstItem: BoardItem(chainID: subObjectChain, tier: 0),
                              orders: [makeOrder(chainID: subObjectChain, tier: 1)])
        XCTAssertNotNil(result, "tier 0 -> 1 is well within the sub-object chain's 4 stages")
        XCTAssertFalse(result!.isBubbleEligible, "bubbling is animal-only regardless of order eligibility")
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

    private func place(_ vm: MergeBoardViewModel, chainID: ChainID, tier: Int, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier)
        vm.board = board
    }

    func testComputedOutcomeMatchesWhatAttemptMergeOrMoveActuallyProducesForAnOrdinaryMerge() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)
        let scoreBefore = vm.score

        let predicted = compute(srcItem: BoardItem(chainID: catChain, tier: 0),
                                 dstItem: BoardItem(chainID: catChain, tier: 0),
                                 spotlightChainID: vm.quests.spotlightChainID,
                                 spotlightMultiplierBonus: 0)
        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, predicted?.resultChainID)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, predicted?.resultTier)
        XCTAssertEqual(vm.score, scoreBefore + (predicted?.scoreDelta ?? -1))
    }

    func testComputedOutcomeMatchesWhatAttemptMergeOrMoveActuallyProducesForAWildcardMerge() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 2, at: b)

        let predicted = compute(srcItem: BoardItem(chainID: ContentRegistry.wildcardChainID, tier: 0),
                                 dstItem: BoardItem(chainID: catChain, tier: 2),
                                 spotlightChainID: vm.quests.spotlightChainID)
        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, predicted?.resultChainID)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, predicted?.resultTier)
    }
}
