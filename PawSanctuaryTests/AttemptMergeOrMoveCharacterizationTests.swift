import XCTest
@testable import PawSanctuary

/// Characterization tests for `attemptMergeOrMove` (Phase D, D0 — see
/// specs/BoardStateManager_Phase_D_Plan.md). These pin the function's
/// *current* behavior before any `MergeResult` rewrite touches it. They are
/// not a spec of what's "correct" — just a record of what the game does
/// today — so a refactor that changes any of these outcomes gets caught
/// immediately instead of discovered live in the simulator (or by a player).
///
/// This is the first test in `PawSanctuaryTests` to instantiate
/// `MergeBoardViewModel` directly (see `docs/CODE_HEALTH.md` and this
/// project's testing notes on why that's never happened before). `loadGame()`
/// is deliberately never called — it reads `GameStore`/disk and starts the
/// live timer; every fixture here builds a board and drops it straight onto
/// `MergeBoardViewModel.board` instead, so these tests are fast and fully
/// isolated from persistence.
///
/// `.cat` (Felines) and `.hamster` (Rodents) are used as the default test
/// species deliberately: neither is one of the four species with a passive
/// superpower wired into `applyPassivePowers` (dog/rabbit/fox/fish), and
/// neither is `quests.spotlightChainID`'s default (`.dog`) — so ordinary
/// merges in these tests don't accidentally trigger a passive-power side
/// effect or a spotlight score multiplier, which would make the score/XP
/// assertions depend on more than the merge itself.
@MainActor
final class AttemptMergeOrMoveCharacterizationTests: XCTestCase {

    // MARK: Fixtures

    private let catChain = ContentRegistry.animalChainID(.cat)
    private let hamsterChain = ContentRegistry.animalChainID(.hamster)

    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    /// A fully unlocked, fully empty 9x7 board. `attemptMergeOrMove`'s own
    /// guards only care about `isUnlocked`/occupancy, not the locked-row
    /// kibble-cache seeding `freshBoardCell` does for a real new game, so
    /// starting from a plain empty grid keeps every fixture minimal.
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

    private func place(_ vm: MergeBoardViewModel, chainID: ChainID, tier: Int,
                        at pos: GridPosition, bubbledAt: Double? = nil) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier, bubbledAt: bubbledAt)
        vm.board = board
    }

    private func placeProducer(_ vm: MergeBoardViewModel, level: ProducerLevel, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].producer = ProducerTile(level: level)
        vm.board = board
    }

    private func lock(_ vm: MergeBoardViewModel, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].isUnlocked = false
        vm.board = board
    }

    private func makeOrder(chainID: ChainID, tier: Int) -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0, wantedChainID: chainID, wantedTier: tier, wantedCount: 1)
    }

    // MARK: Guards — no-op cases

    func testSamePositionIsNoOp() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        vm.attemptMergeOrMove(from: a, to: a)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain)
        XCTAssertEqual(vm.board[a.row][a.col].item?.tier, 0)
    }

    func testOutOfBoundsDestinationIsNoOp() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        let outOfBounds = GridPosition(row: -1, col: 0)
        vm.attemptMergeOrMove(from: a, to: outOfBounds)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain, "source item must be untouched")
    }

    func testLockedDestinationIsNoOp() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        lock(vm, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain, "source untouched")
        XCTAssertNil(vm.board[b.row][b.col].item, "locked destination stays empty")
    }

    func testLockedSourceIsNoOp() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        lock(vm, at: a)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain, "item stays put behind the lock")
        XCTAssertNil(vm.board[b.row][b.col].item)
    }

    func testBubbledSourceCannotBeMoved() {
        // Distinct from a bubbled *destination* (below): a bubbled source fails
        // the function's very first item guard, so nothing happens at all —
        // not even the swap a bubbled destination falls back to.
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 3, at: a, bubbledAt: 1_000)
        place(vm, chainID: hamsterChain, tier: 3, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain, "bubbled source never leaves its cell")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, hamsterChain, "destination untouched")
    }

    func testDestinationProducerBlocksItemMerge() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        placeProducer(vm, level: .rescueCrate, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, catChain, "item never left — target cell has a producer")
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .rescueCrate)
    }

    // MARK: Producer branch

    func testProducerSameLevelMergeUpgradesInPlace() {
        let vm = makeViewModel()
        placeProducer(vm, level: .rescueCrate, at: a)
        placeProducer(vm, level: .rescueCrate, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].producer, "source cleared")
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .shelterPod, "upgraded to the next level")
    }

    func testProducerDifferentLevelSwapsPositions() {
        let vm = makeViewModel()
        placeProducer(vm, level: .rescueCrate, at: a)
        placeProducer(vm, level: .shelterPod, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].producer?.level, .shelterPod, "the two producers swapped")
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .rescueCrate)
    }

    func testProducerMovesToEmptyCell() {
        let vm = makeViewModel()
        placeProducer(vm, level: .familySpawner, at: a)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].producer, "source cleared")
        XCTAssertEqual(vm.board[b.row][b.col].producer?.level, .familySpawner)
    }

    func testProducerOntoItemOccupiedCellIsNoOp() {
        // Neither producer-branch condition (`dstProducer` present, or
        // `dstItem == nil`) is met, so the producer-vs-item collision is
        // silently absorbed — nothing on the board changes.
        let vm = makeViewModel()
        placeProducer(vm, level: .rescueCrate, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].producer?.level, .rescueCrate, "producer never left")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain, "item untouched")
    }

    // MARK: Plain item move / ineligible swap

    func testItemMovesToEmptyCell() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 2, at: a)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].item, "source cleared")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 2)
    }

    func testIneligiblePairSwapsInsteadOfMerging() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: hamsterChain, tier: 3, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, hamsterChain, "swapped")
        XCTAssertEqual(vm.board[a.row][a.col].item?.tier, 3)
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 0)
    }

    func testBubbledDestinationBlocksMergeAndSwapsInstead() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 3, at: a)
        place(vm, chainID: catChain, tier: 3, at: b, bubbledAt: 1_000)
        vm.attemptMergeOrMove(from: a, to: b)
        // Same chain + tier would normally be eligible to merge — the bubble
        // on the destination is what forces the fallback to a plain swap.
        XCTAssertEqual(vm.board[a.row][a.col].item?.bubbledAt, 1_000, "the bubbled item moved to `a`")
        XCTAssertEqual(vm.board[b.row][b.col].item?.bubbledAt, nil, "the un-bubbled item moved to `b`")
    }

    func testAlreadyTopTierPairCannotMergeFurtherSoSwaps() {
        let vm = makeViewModel()
        let top = animalChainTopTier
        place(vm, chainID: catChain, tier: top, at: a)
        place(vm, chainID: catChain, tier: top, at: b)
        let scoreBefore = vm.score
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.tier, top, "swap, not a merge — both stay at top tier")
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, top)
        XCTAssertEqual(vm.score, scoreBefore, "a swap awards nothing")
    }

    // MARK: Successful merges

    func testSameChainSameTierMergeAdvancesTierAndAwardsScoreAndXP() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)
        let tierDef = ContentRegistry.shared.tier(catChain, 0)!
        let scoreBefore = vm.score
        let mergeCountBefore = vm.mergeCount

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[a.row][a.col].item, "source cleared")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 1, "advanced one tier")
        XCTAssertEqual(vm.score, scoreBefore + tierDef.scoreValue, "no spotlight multiplier for a non-spotlight chain")
        XCTAssertEqual(vm.mergeCount, mergeCountBefore + 1)
        XCTAssertEqual(vm.lastMergedSpeciesRaw, AnimalSpecies.cat.rawValue)
    }

    func testWildcardAsSourceAdoptsDestinationIdentity() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 2, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].item, "wildcard consumed")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain, "result carries the real item's identity")
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 3, "advanced from the real item's tier")
    }

    func testWildcardAsDestinationAdoptsSourceIdentity() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 2, at: a)
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].item, "real item consumed")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain, "result lands at `to` with the real item's identity")
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 3)
    }

    func testTwoWildcardsNeverMergeJustSwap() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: a)
        place(vm, chainID: ContentRegistry.wildcardChainID, tier: 0, at: b)
        let mergeCountBefore = vm.mergeCount
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, ContentRegistry.wildcardChainID, "still there — just swapped")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, ContentRegistry.wildcardChainID)
        XCTAssertEqual(vm.mergeCount, mergeCountBefore, "a swap, not a merge")
    }

    /// An eligible order is *necessary* but not *sufficient* — `maybeBubbleMergedItem`
    /// additionally rolls `Double.random(in: 0..<1) < bubbleChance` (0.15) even once
    /// eligibility is confirmed, discovered when a single-shot version of this test
    /// failed intermittently. So this can't assert "eligible ⇒ bubbles" for one merge;
    /// it repeats the merge many times and checks the observed rate lands near 15%,
    /// the same statistical style `QuestCoordinatorTests` already uses for this
    /// codebase's other RNG-gated systems. At n=300, p=0.15, a [5%, 30%] band is
    /// roughly ±3.6 standard deviations from the expected rate — wide enough that a
    /// correct implementation essentially never trips it, tight enough to still catch
    /// bubbleChance being changed to something wildly different (e.g. 0 or 1) or the
    /// eligibility gate being bypassed (which would push the rate toward 100%).
    func testMidTierMergeBubblesAtRoughlyBubbleChanceWhenEligibleForAMatchingOrder() {
        let trials = 300
        var bubbledCount = 0
        for _ in 0..<trials {
            let vm = makeViewModel()
            place(vm, chainID: catChain, tier: bubbleMinTier, at: a)
            place(vm, chainID: catChain, tier: bubbleMinTier, at: b)
            vm.adoptionOrders = [makeOrder(chainID: catChain, tier: bubbleMinTier + 1)]
            vm.attemptMergeOrMove(from: a, to: b)
            if vm.board[b.row][b.col].item?.bubbledAt != nil { bubbledCount += 1 }
        }
        let rate = Double(bubbledCount) / Double(trials)
        XCTAssertGreaterThan(rate, 0.05, "eligibility should make bubbling possible at roughly bubbleChance (0.15)")
        XCTAssertLessThan(rate, 0.30, "and not far above it — eligibility alone must not guarantee a bubble")
    }

    func testMidTierMergeDoesNotBubbleWithoutAnEligibleOrderOrQuest() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: bubbleMinTier, at: a)
        place(vm, chainID: catChain, tier: bubbleMinTier, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[b.row][b.col].item?.bubbledAt, "no order/quest wants this — lands normally")
    }

    func testTopTierMergeTriggersAmbassadorCelebrationNotABubble() {
        let vm = makeViewModel()
        let top = animalChainTopTier
        place(vm, chainID: catChain, tier: top - 1, at: a)
        place(vm, chainID: catChain, tier: top - 1, at: b)
        let ambassadorsBefore = vm.ambassadors
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.ambassadors, ambassadorsBefore + 1, "top-tier completion is an ambassador, not a bubble")
        XCTAssertNil(vm.board[b.row][b.col].item?.bubbledAt, "top-tier completion never bubbles — celebration and bubbling are mutually exclusive branches")
    }

    func testSuperpowerUnlocksAtItsDesignatedTier() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.unlockedSuperpowerSpecies.contains(AnimalSpecies.cat.rawValue))
        place(vm, chainID: catChain, tier: Superpower.unlockTier - 1, at: a)
        place(vm, chainID: catChain, tier: Superpower.unlockTier - 1, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertTrue(vm.unlockedSuperpowerSpecies.contains(AnimalSpecies.cat.rawValue))
        XCTAssertTrue(vm.showSuperpowerUnlockBanner)
    }

    func testNineLivesSnapshotIsCapturedAfterASuccessfulMerge() {
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 0, at: a)
        place(vm, chainID: catChain, tier: 0, at: b)
        XCTAssertNil(vm.preMoveSnapshot, "no snapshot before any merge")
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNotNil(vm.preMoveSnapshot, "a successful merge arms Nine Lives undo")
        // The captured snapshot must reflect the board as it was *before* this
        // merge — both items still present at their original tier — not the
        // post-merge state assigning it from would trivially (and wrongly) satisfy.
        XCTAssertEqual(vm.preMoveSnapshot?.board[a.row][a.col].item?.tier, 0)
        XCTAssertEqual(vm.preMoveSnapshot?.board[b.row][b.col].item?.tier, 0)
    }

    func testNineLivesSnapshotIsNotArmedByANonMergeMove() {
        // Only the eligible-merge branch touches preMoveSnapshot today — a
        // plain move, swap, or producer action must not arm undo.
        let vm = makeViewModel()
        place(vm, chainID: catChain, tier: 2, at: a)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.preMoveSnapshot)
    }

    // MARK: Superpower piece spent

    func testSuperpowerPieceSpentConsumesTheSourcePiece() {
        // .cat's active superpower is the Splitter piece (applySplitterPiece):
        // the target drops one tier and a second copy is placed elsewhere.
        // Exercised here only as a smoke test that attemptMergeOrMove's
        // dispatch/consume wiring works — applySplitterPiece's own internals
        // were already live-verified in Phase C round 3.
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.superpowerChainID(.cat), tier: 0, at: a)
        place(vm, chainID: catChain, tier: 2, at: b)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertNil(vm.board[a.row][a.col].item, "the superpower piece is consumed")
        XCTAssertEqual(vm.board[b.row][b.col].item?.chainID, catChain)
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 1, "Splitter drops the target one tier")
    }

    func testSuperpowerPieceOnABubbledTargetFizzlesAndConsumesNothing() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.superpowerChainID(.cat), tier: 0, at: a)
        place(vm, chainID: catChain, tier: 2, at: b, bubbledAt: 1_000)
        vm.attemptMergeOrMove(from: a, to: b)
        XCTAssertEqual(vm.board[a.row][a.col].item?.chainID, ContentRegistry.superpowerChainID(.cat),
                        "a failed spend leaves the piece in place")
        XCTAssertEqual(vm.board[b.row][b.col].item?.tier, 2, "bubbled target untouched")
    }
}
