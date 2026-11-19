# Spec — Orders filled from held items (D14, task W1)

**Status: Draft, 18 Nov 2026. Written cold, not yet reviewed by the owner. No code written.** This is task 1.1 of `Revision_Plan_ModelOnReferences.md`. The owner sees it before any W1 code is built; tasks 1.2 to 1.8 stay blocked until it is accepted. Citations are to `origin/main` at `6d5a409`.

**Read first:** `PawSanctuary_Alignment_Plan.md` D14 (supersedes D12), `Triage_ModelOnReferences.md` §2.1 and §2.9, `Spec_DailyHandInTasks.md` (the board-census precedent).

---

## 0. What changes for the player, in one paragraph

Today an order fills by itself the moment a merge or a spawn *makes* the item it wants; holding the item does nothing. After this change, an order card shows one slot per wanted item. When a wanted item is standing on the board, its slot and its board tile get a soft highlight. When every wanted item is on the board, the highlight brightens and a **Deliver** button appears on the card. Pressing it takes those items off the board and the rewards fly out. A half-filled card shows no button and pays nothing. Items bought in the Dog Tag store, won from orders or chests, or left over from a split now count as soon as they are on the board.

## 1. The rule (fixed by D14; restated so this spec stands alone)

1. Each order line (`OrderLine`, `AnimalSpecies.swift:1007`) is shown as slots: one slot per copy wanted (`count` is 1 or 2).
2. A slot is **held** when the board holds enough copies of that exact chain and tier (§3.1 defines "the board").
3. Held slots, and the board tiles that hold them, show a **muted** highlight.
4. When every slot on a card is held, the card is **ready**: the highlight on its slots and its tiles turns **vivid**, and the **Deliver** button appears.
5. A card that is not ready has no button and pays nothing. There is no partial delivery.
6. Pressing Deliver removes the items from the board, pays the order's rewards exactly as today, and replaces the order exactly as today.
7. Matching is by chain and tier only.

The urgent order (`AdoptionBoard.urgentOrder`, `AdoptionBoard.swift:25`) follows the same rule; its timer runs until it is **delivered**, not until it is filled.

## 2. What the code does today (and where it disagrees with D14)

| Area | Today | Citation |
|---|---|---|
| Crediting | A spawn or a merge that produces chain/tier X calls `updateOrdersAfterMerge`, which adds +1 to the first unfilled matching line of every open order, and auto-claims any order that became complete | `MergeBoardViewModel.swift:1640` (spawn), `:3083` (merge), `:3657`; `AdoptionBoard.swift:224-259` |
| One event, many orders | One produced item credits **every** open order that wants it, plus the urgent order | `AdoptionBoard.swift:224-234`, `:238-244` |
| Claiming | Automatic, no button: `autoClaimOrder` / `autoClaimUrgentOrder` pay out and schedule a replacement 2 s later | `MergeBoardViewModel.swift:3746-3776`, `:3778-3800` |
| Items on delivery | Nothing leaves the board; the item that credited the order stays and can be merged on | same |
| Progress state | Persisted counter `OrderLine.fulfilled`; `isComplete` derives from it | `AnimalSpecies.swift:1012-1014`, `:1079` |
| Card tint | Green when **one more merge** could make the item (`mergeReadyKeys`, which counts board **and inventory**) | `MergeBoardViewModel.swift:817-829`; `PanelViews.swift:297-322`, `:443`; `OrderLaneView.swift:31`, `:69`, `:165` |
| Board tint | Board tiles are tinted only for daily hand-in tasks (`dailyTaskHighlights`: `.wanted` / `.stocked`), not for orders | `MergeBoardViewModel.swift:773-799`; `MergeBoardView.swift:871-872` |
| Held-item precedent | Daily tasks read `boardTaskCensus` (unlocked cells, bubbled items excluded, inventory excluded), claim with a button, and remove items row-major with `surrenderBoardItems` | `MergeBoardViewModel.swift:762-770`, `:3572-3592`, `:3598-` |
| Generation | Board-blind: random family, random unlocked animal chain per line, tier from `orderDifficultyBands` capped by `maxAchievableOrderTier` | `AdoptionBoard.swift:72-170` |

**Discrepancies found while reading (recorded, not fixed here):**

1. **The comment that stated the old rule is stranded.** It begins "Chain/tier pairs the player could produce with one merge" at `MergeBoardViewModel.swift:734`, above `boardTaskCensus` instead of `mergeReadyKeys` (`:817`). Open PR #110 moves it back. Task 1.3 deletes or rewrites it, so #110 and 1.3 touch the same lines: whichever lands second rebases.
2. **`autoClaimOrder`'s comment** ("Adoption orders are fulfilled by merging animals on the board", `:3751`) becomes false. Task 1.5 rewrites it.
3. **`EconomySimulation`'s daily-task note** (`PawSanctuaryTests/EconomySimulation.swift:164-185`) says a hand-in "spends that same item a second time" because orders "credit on merge and never consume". Under D14 that premise is gone: orders consume, so an item handed in to a daily task is an item that cannot go to an order. Task 1.2 must rewrite this note and add the demand term it declined to add (§6).
4. **`mergeReadyKeys` counts inventory; `boardTaskCensus` does not.** D14 says "on the board". This spec follows D14 and the census (§3.1). The order tint therefore changes meaning *and* scope.
5. **`maybeShowSellVsOrderNudge`** (`:2014-2035`) reads only the first line of an order (`wantedChainID`/`wantedTier`, `AnimalSpecies.swift:1066`), so a basket's later lines are ignored. Pre-existing, unrelated to D14; noted for code health.
6. **`OrderFulfilmentRuleTests.swift`** pins the D12 rule (four tests). Every one of them must flip or be removed in task 1.6; this is expected, and D14 already says so.
7. **Old copy of the rule in D3's text.** D12's "Effect on D3" paragraph (Alignment Plan) is now history; D14 §4 already restates the effect. No edit needed.

## 3. The open points from D14 §3, settled

Points marked **(spec)** are settled here because they are technical or follow directly from D14. Points marked **(owner)** are the owner's call; each has options and a recommendation, and is listed in `PROJECT_STATE.md` under Decisions waiting. Until the owner answers, the build uses the recommendation only if the owner says so; tasks 1.3 to 1.5 do not start before the answers.

### 3.1 What counts as "on the board" (spec)

The existing `boardTaskCensus` (`MergeBoardViewModel.swift:762`), unchanged: items on **unlocked** cells, **not bubbled**. Items in storage (inventory) do **not** count; the player takes them out first. Reasons: D14's wording, one rule for held items across orders and daily tasks (D14 §2), and the census is already tested. Consequence to state in the UI copy: a bought item that is banked to storage because the board was full (`placeOrBankItem`, `:2085-2093`) does not count until it is placed.

Producers, spawners, chests and locked cells never count. A wildcard never counts as a held item of another chain (§3.3).

### 3.2 Which copy is taken (spec)

When the board holds more copies than the order needs, delivery removes copies in **row-major scan order** (top row first, left to right), the order `surrenderBoardItems` already uses for daily tasks (`:3598`). Copies of one chain and tier are identical in every saved field that matters, so the only visible effect is which cell empties. Recording R1 step 4 will show what Travel Town does; if it differs visibly (for example, it takes the copy nearest the card), that is a cosmetic follow-up, not a rule change.

The two removal paths (daily tasks and orders) share one helper: task 1.5 generalises `surrenderBoardItems` to take `[ChainTierKey: Int]` rather than daily-task lines, so the scan order cannot drift between them.

### 3.3 The wildcard (owner — Q18 a)

Today the wildcard (`purchaseWildcard`, `:1917`; 100 Dog Tags, `AnimalSpecies.swift:2195`) merges with any one item and becomes that item one tier up (`MergeOutcome.swift:80-102`). Recording R2 (does either reference let a joker fill an order?) has not been made.

- **(a) A wildcard never fills a slot. Recommended.** It keeps its one job: turning one copy at tier N−1 into the missing tier-N item, which then fills the slot. The "one item short" purchase still works, it just takes one drag. Nothing new to price, and the wildcard's 100-tag value is not changed by this spec.
- **(b) A wildcard on the board fills any one empty slot.** The most convenient, but a 100-tag item then buys any order outright, including a hard order's deepest line, which the economy has not been sized for (`EconomySimulation` has no Dog Tag term; D13 noted the same gap).
- **(c) Decide after R2.** Build (a) now; revisit if R2 shows a reference doing (b).

### 3.4 One held item wanted by two cards (owner — Q18 b)

Two open orders (or an order and the urgent order) can want the same chain and tier while the board holds one copy. The same can happen between an order and a daily hand-in task.

- **(a) Each card checks the board on its own; first delivered wins. Recommended.** Both cards may show the item as held and both may show Deliver; pressing one takes the copy, and the other card drops back to muted or unlit at once. This is exactly how daily tasks behave today (each task checks `isStocked` against the same census independently, `AnimalSpecies.swift:901-903`), so orders and daily tasks keep one rule. Simple to test and to explain.
- **(b) Allocate copies to cards in a fixed order** (urgent order first, then slots left to right, then daily tasks), so a copy is only ever highlighted on one card. More "honest" about what the board can pay, but a card can then show an item as missing while the item is visibly on the board, which reads as a bug, and the allocation must be recomputed on every board change.
- **(c) Decide after R1 step 5** (which asks exactly this of the references). Build (a) now.

### 3.5 The red-cart buy path on a missing slot (owner — Q18 c)

Travel Town shows a red shopping-cart badge on an unfilled slot (`Triage` §2.9); its price is unmeasured (R1 step 2). D13 requires any buy shortcut to sit behind the D7 gate (`isMonetizationUnlocked`, `:396`) and to route through `purchaseDogTagStoreSlot` (`:1894`) so stock, price and the spend counter stay in one place. D9: no price is tuned to make it convert. This is task 1.8, already blocked on R1.

- **(a) No cart in the first W1 build; decide the shape after R1. Recommended.** The rule change (1.3 to 1.5) does not need it, and building it now means guessing a price.
- **(b) A cart only on slots the Dog Tag store currently stocks**, buying that store slot through `purchaseDogTagStoreSlot`. Fully inside D13. Because the store's stock is random (`DogTagStore.swift:49`), the cart would rarely appear, so it is a weak copy of the reference.
- **(c) A cart on every missing slot, priced by a formula.** Matches the reference best, but it is a new price path outside `purchaseDogTagStoreSlot`, so **it needs D13's routing constraint amended first** and a Dog Tag price model. Flagged: this option contradicts a recorded decision as written.

Whatever is chosen, the bought item lands through `placeOrBankItem` and counts only once on the board (§3.1).

### 3.6 Order generation and board awareness (owner — Q18 d)

Generation is board-blind today. Under D14 a freshly generated order can be ready the moment it appears, if the board happens to hold its items (common for low tiers). That is not an economic leak: every held item was paid for in kibble, or came from a recirculation source the model already counts as supply (§6). It changes feel, not balance.

- **(a) Keep generation board-blind. Recommended.** The references' generators are unreadable; nothing measured says they look at the board; and an order that is instantly ready is a small, legible reward for having built ahead. It also keeps `EconomySimulation`'s demand formula valid as written (§6).
- **(b) Re-roll an order that would be ready on arrival** (at most N re-rolls, then accept). Keeps every order a fresh goal, at the cost of quietly steering demand away from what the player holds, which makes surplus items harder to use, against D14's "consumes surplus" point.
- **(c) Bias generation toward items the player holds** (Travel Town-style "you have it, hand it over"). Unmeasured in both references; would need its own modelling. Not recommended for this task.

## 4. Card and board presentation

- **Slots.** One slot per wanted copy. Slot states: empty, held (muted), ready (vivid, on every slot of a ready card), delivered (the existing "Adopted!" state during the 2 s replacement pause).
- **Board tiles.** A tile whose chain/tier is wanted by any open order gets the muted highlight; if any card it can serve is ready, vivid. Reuse the daily-task highlight's "one colour, two intensities" treatment (`DailyTaskHighlight`, `:773-781`; `Spec_DailyHandInTasks.md` D-B) so the board has **one** highlight language for held items, with `.stocked`/vivid winning when a tile serves several cards. If orders and daily tasks need different hues, that is a visual question for the owner at the Simulator review (task 1.7), not a rule question.
- **Button.** "Deliver" (working label; Gossip Harbor says Serve, Travel Town GO). Shown only on a ready card; on press it disables at once to prevent a double pay.
- **The old merge-ready tint** (`mergeReadyKeys`) is removed from order cards by D14 §4. Whether it survives anywhere else (for example as a hint on the board) is out of scope; if nothing reads it after task 1.4, delete it.
- Accessibility: each slot's label says "held" or "missing"; the button's label names the family and the rewards.

## 5. Persistence

**No new persisted field and no schema bump are needed.** Held state is derived live from the board, like daily tasks.

- `OrderLine.fulfilled` (`AnimalSpecies.swift:1012`) stays in the Codable shape (removing it would be a shape change). It is no longer advanced by merges. On delivery, task 1.5 sets each line's `fulfilled = count` and `isClaimed = true`, so `isComplete` keeps meaning "delivered" for the card's "Adopted!" state and for the guards that read it (`nearestIncompleteOrder` `:593-603`, `maybeShowSellVsOrderNudge` `:2020-2023`, `rescheduleRescueExpiring` `:3805`, urgent tick `AdoptionBoard.swift:200`, offline progress `:304`).
- **Old saves.** A v45 save may hold orders with `0 < fulfilled < count` (partly credited under D12). Under D14 that credit means nothing. Task 1.3 resets `fulfilled` to 0 on every **unclaimed** order when the game state is restored (`AdoptionBoard.restore`, `:328`). This is a value normalisation, not a shape change, so it does not need a version bump under CLAUDE.md rule 4; it **does** get a `PersistenceTests` case because it changes what a loaded save means (§8). The game is pre-launch, so only test saves lose partial progress; the owner should know this (it is stated in the PR).
- If the owner prefers a version bump to mark the semantic change anyway, it would be v45 → v46 via the existing `migrateByInjecting` pattern; the spec does not recommend it.

## 6. The economy: how demand is re-sized (method; the numbers are task 1.2)

`EconomySimulation` is a flow model: kibble per day in (`dailySupply`, pinned at 695 / 745 by `EconomyTests.swift:780-784`) against kibble per day asked for (`grossDemand = ordersPerDay × expectedOrderCost`, `EconomySimulation.swift:265-270`), less recirculation. The target curve is pinned by `testDemandSupplyRatioMatchesTheTargetCurve` (`EconomyTests.swift:754-771`).

What D14 changes in that model:

1. **Order demand: the formula stays; its meaning gets stricter.** `grossDemand` already charges each order its full build cost `2^t` per line. Under D12 that overstated real demand: one merge could credit several orders at once (§2, "one event, many orders"), and the item stayed on the board to be merged on toward a deeper order, so the same kibble often paid for two orders. Under D14 every delivered item is consumed by exactly one order, so the formula becomes an accurate charge rather than an upper bound. **Expected effect: the game gets harder in play at every level, while the modelled ratio for orders alone is unchanged.** Task 1.2 must say this plainly to the owner, because the ratio test passing does not show it.
2. **Daily hand-in tasks become real demand.** The model deliberately added no demand term for daily tasks (`EconomySimulation.swift:164-185`) on the premise that orders never consume. That premise is gone: an item handed in to a daily task is an item that cannot fill an order. Task 1.2 adds a daily-task demand term (three tasks per day × the expected basket cost the model already enumerates for the coin side, `:192-252`) to `grossDemand`, and reports the ratio with and without it.
3. **Recirculation is unchanged in form.** Store purchases, `.boardItem` order rewards (`AdoptionBoard.swift:139-145`), chests and Smile bundles are already counted as supply in kibble value (`EconomySimulation.swift:275-322`). Under D14 they can fill an order directly instead of only feeding a merge, which the kibble-value model already assumes. No change.
4. **The urgent order** stays in the model as today (`:96`, `:160`).
5. **Board congestion (stock model, `:325-`).** Orders now hold cells until delivery. Task 1.2 adds the open orders' expected held items to the "spoken for" count beside the daily tasks' and reports free cells, as the congestion model does for daily tasks today.

**What task 1.2 delivers to the owner:** the ratio table at the report levels before and after (2) is added; if any target band is broken, the proposed lever, which per the model's own header is **order tiers or line counts** (`orderDifficultyBands`, `orderBasketLineCounts`, `orderCyclesPerDay`), never the measured supply values; and the congestion figures. The rule change (1.3) does not ship until the owner has seen those numbers. If (1) alone is judged too hard in play, the honest response is a tier retune in 1.2, not a hidden discount.

**Decided 19 Nov 2026 (owner, Q22 / tracker 1.3q): the order tier cap stays shared.** `maxAchievableOrderTier` also caps daily hand-in tasks and legendary quests, so the option B caps chosen after task 1.2 lower what those can ask for too: tier 11 no longer appears in either at level 51 and up, and tier 9 no longer appears in daily tasks at levels 31 to 40. The owner chose to keep one shared cap rather than give those two their old limits. Task 1.2's numbers already assumed this, because the model's daily-task demand term reads the same function, so nothing needs re-checking.

## 7. Tasks (one per session; W1 is one lane, run in order)

| Id | Task | Depends on |
|---|---|---|
| 1.2 | Economy re-size per §6; restate the targets; show the owner the numbers. Test-target code only (`EconomySimulation`, `EconomyTests`); no game-rule change | owner accepts this spec |
| 1.3 | The rule: remove the production-credit path (`updateOrdersAfterMerge` calls at `:1640`, `:3083`; `creditLine`'s callers), add `orderHeldState` derived from `boardTaskCensus` (per line, per card: held / ready), stop auto-claiming; old-save normalisation (§5); Q18 a/b/d as answered | 1.2 accepted |
| 1.4 | Card and board UI per §4 (slots, muted/vivid, Deliver button; remove the merge-ready tint from cards) | 1.3 |
| 1.5 | Delivery: `deliverOrder(at:)` / `deliverUrgentOrder()` re-check readiness, remove items via the shared surrender helper (§3.2), pay via the existing `applyRewards` + burst + Care/Smile/Parallel-energy path, mark claimed, replace after 2 s; urgent timer runs until delivery | 1.3 (may share a PR with 1.4 only if the owner prefers one review) |
| 1.6 | Tests (§8), alongside 1.3 to 1.5 | — |
| 1.7 | Simulator run, screenshots of every card state (empty, part-held, ready, delivered; two cards sharing one item; the urgent order), shown to the owner | 1.4, 1.5 |
| 1.8 | Red-cart buy path per Q18 c | R1, 1.4, owner's Q18 c |

Definition of done for each code task: build green, full test suite green (local and CI), `EconomyTests` green, `PersistenceTests` green, no force-unwraps, Swift 6 `@MainActor` conventions, branch off `main`, PR opened, owner merges.

## 8. Tests

Replace `OrderFulfilmentRuleTests.swift` (its four D12 tests) with a D14 suite. Each negative test keeps a control, as the old file did.

- `testAHeldItemMakesItsSlotHeldButAPartCardIsNotReady` — a two-line basket, one item on the board: line held, card not ready, no delivery possible (`deliverOrder` returns false, nothing removed, nothing paid).
- `testEveryItemHeldMakesTheCardReady` and `testDeliveringRemovesExactlyTheWantedItemsAndPays` — counts on the board drop by exactly the wanted counts; rewards equal `order.rewards`; order marked claimed; replaced after the delay.
- `testAStorePurchaseOfTheWantedItemMakesTheSlotHeld` — the D12 test inverted; a purchase banked to storage on a full board does **not** (§3.1).
- `testAMergeNoLongerCreditsAnOrderOnItsOwn` — producing the item highlights it but does not pay; nothing is auto-claimed.
- `testInventoryAndBubbledItemsDoNotCount`; `testOnlyTheExactChainAndTierCounts`.
- `testRowMajorCopyIsTakenWhenSpareCopiesAreHeld` (§3.2).
- `testTwoCardsSharingOneHeldItemFirstDeliveryWins` (if Q18 b = a) or the allocation test (if b).
- `testAWildcardDoesNotFillASlot` (if Q18 a = a).
- `testUrgentOrderTimerRunsUntilDelivery` and `testUrgentOrderExpiresWhileHeldButUndelivered`.
- `testDailyTaskAndOrderCompeteForTheSameCopy` — claiming one leaves the other unready.
- `PersistenceTests`: `testV45SaveWithPartlyCreditedOrderLoadsWithNoCreditAndIntactLines` (§5) and `testDeliveredOrderStateRoundTrips`.
- `EconomyTests`: whatever 1.2 restates; `testDemandSupplyRatioMatchesTheTargetCurve` must pass with the daily-task demand term included, or be changed only with the owner's agreement to new bands.

## 9. Out of scope

- The wildcard's price, the Dog Tag store's stock rules or prices (D3, D13, D9).
- Fifteen tiers and mid-chain order targets (W5; it depends on this task, not the reverse).
- Order characters, portraits or dialogue (row 8, owner's pick).
- Parallel Board orders and event orders: this spec covers adoption orders and the urgent order only. Whether Parallel Board orders follow D14 is a separate question for its own spec.
- Changing `orderCyclesPerDay`, supply values or the target curve itself (only the owner can move the bands).
- Any persisted shape change (§5).
- Reward amounts per order.

## 10. Owner questions (also in `PROJECT_STATE.md`, Decisions waiting, as Q18)

**Resolved 18 Nov 2026: the owner accepted all four recommendations (relayed to the project manager by the coordinating session).** (a) A wildcard does not fill an order slot. (b) Each card checks the board on its own; the first delivery takes a shared item. (c) The red-cart buy button is left out of the first build until recording R1 shows the price. (d) Order generation stays blind to the board. Sections 3.3 to 3.6 are therefore settled as their option (a), and the "(owner)" markers there are closed. Task 1.8 stays blocked on R1.

- **Q18 a — Wildcard:** may a wildcard fill an order slot? (a) no, it stays a merge helper; (b) yes, any one slot; (c) build (a), revisit after R2. **Recommend (a).**
- **Q18 b — One item, two cards:** (a) each card checks the board on its own, first delivery wins (as daily tasks do); (b) allocate each copy to one card; (c) build (a), revisit after R1 step 5. **Recommend (a).**
- **Q18 c — Red cart on a missing slot:** (a) not in the first build, decide after R1 shows the price; (b) only where the Dog Tag store already stocks the item; (c) every missing slot at a formula price (needs D13 amended). **Recommend (a).**
- **Q18 d — May order generation look at the board?** (a) no, stays board-blind; (b) re-roll orders that would be ready on arrival; (c) bias toward held items. **Recommend (a).**

Also for the owner to know, not to decide: old test saves lose any partly credited order progress (§5), and the game will play harder than today at the same modelled ratio (§6 point 1); task 1.2 shows by how much the daily-task term moves the curve.
