# PawSanctuary — Phase 6b: Reward Ladder (D8, "chain offer")

**Self-contained brief.** Assumes no prior conversation. Follows Milestone track, Pass, and Parallel Board (`specs/Spec_Phase6b_MilestoneTrack.md`/`Spec_Phase6b_Pass.md`/`Spec_Phase6b_ParallelBoard.md`), all shipped and design-reviewed.

> **Not atomic.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists.

**DRAFT — written cold by Claude Code at the user's request, same exception made for Pass/Parallel Board/the 6c calendar. Partially reviewed by the design authority (18 Aug 2026): the §0/§6 trigger question is resolved; §4's numbers and §3.4's UI placement are still open.** This spec exists because D8 was decided 18 Aug 2026 (Alignment Plan §3): **adopt, as a variant of the Pass primitive, coercive version** (visible-but-locked free nodes, matching both reference titles). That decision resolved *whether* and *which version* — it did not resolve *how this actually gets triggered/scheduled* or *what the exact ladder numbers should be*, both genuinely unaddressed by the Alignment Plan's own D8 entry. This draft proposed answers to both; the trigger question (§0) is now confirmed — see §6 for the remaining open items.

---

## 0. Why

Per the Alignment Plan's D8 entry: *"a vertical ladder of reward nodes where free nodes sit padlocked until an adjacent paid node is purchased. Buying releases them and advances the ladder, revealing the next paid rung — same price, slightly richer payout."* Measured at Tasty Travels: a paid node alone returns 40.1 gems/$ — a 20% premium to shelf (48.1 gems/$ for the same currency bought directly) — but **paid node + the free nodes it releases** returns 52.4 gems/$, beating shelf once the released rewards are counted. *"The player is not buying gems — they are buying the release of rewards already visible and padlocked on screen. That inversion is the whole mechanic."*

### Naming collision — "chain offer" collides with this codebase's own vocabulary

Exactly the problem Pass's own spec flagged for the word "Pass" (`Spec_Phase6b_Pass.md` §0): this codebase already uses "chain" extensively and specifically for the merge-chain model (`ChainID`, `ChainCategory`, `MergeChain`, `BoardItem.chainID`, every event type's own `chainID` field). Calling this feature a "chain offer" anywhere in code or player-facing copy would read as if it were about merge chains. **This spec calls it the "Reward Ladder"** everywhere — code, IAP product name, UI copy — for the identical reason Pass renamed itself away from "Pass." If the design authority wants different player-facing copy, that's a naming change, not a structural one.

### This is a smaller structural reuse of Pass than the Alignment Plan's own framing suggests

The Alignment Plan describes this as *"the same primitive... one predicate"* different from Pass. That undersells one real difference, found while reading the code rather than assumed from the plan's own summary:

**Pass's paid lane unlocks all at once, via one purchase, independent of the free lane's own progress driver** (order-fulfillment token accumulation via `EventTokenRiderProvider`). The Reward Ladder has **no separate token-earning faucet at all** — there is nothing to merge or fulfil orders for. The *only* thing that advances the ladder is purchasing the next rung. This means:

- `ProgressTrack`'s **storage shape** (`TrackMilestone`, `TrackState`, free/paid rewards per index) is still directly reusable — see §2.
- `ProgressTrack`'s **driver** is not reused the way Milestone track/Pass reused each other's rider mechanism. `progress(trackID:)` here means "rungs purchased so far," advanced by exactly 1 per purchase — never by merge/order activity.
- There is no `EventTokenRiderProvider` for this feature. `OfferHookRegistry`/`OfferHooking` (Phase 6a) was considered as a fit for "an active offer that can be hooked into" — it turned out to have zero real call sites anywhere in the codebase and is shaped only as a flat list of offer-ID strings, not a structured ladder with prices/rewards/sequencing. It doesn't save any real work here and isn't used.

### The trigger/schedule question — genuinely unresolved, a real proposal follows

Milestone track, Pass, and Parallel Board are all **calendar-scheduled**: a fixed `startDate`/`endDate`, visible to every player during that window, driven by `checkEventLifecycle()`. The Alignment Plan's D8 entry describes the reference titles' version as *"timer-bound, and in both observed cases surfaced at the energy wall"* — which reads as **personalized and player-triggered**, not a calendar event every player sees on the same dates. Nothing in this codebase currently does that; the closest existing mechanism is `isMonetizationUnlocked` (`MergeBoardViewModel.swift:346`, `commerce.hasReachedFirstWall && playerLevel >= monetizationUnlockLevel`, per D7), which today only gates whether the **Shop button itself** is visible — a one-time permanent flip, not a per-offer timer.

**Confirmed by the design authority, 18 Aug 2026:** the Reward Ladder is **not** an `EventDefinition`/`ParallelBoardEventDefinition`-style scheduled thing at all. It becomes available the instant `isMonetizationUnlocked` flips true (reusing D7's existing gate exactly, no new trigger condition invented), surfaces as a new Shop-adjacent entry point, and **has no expiry timer**. The player can complete it at their own pace, same posture Founders' Circle/Sanctuary Circle's 30-day window already gives Pass, rather than the reference titles' harder countdown-then-lose-it framing. This was the one piece of this draft flagged as most likely to need revision (§6) — reviewed and kept as originally proposed rather than changed to real timer-bound behavior, given the added complexity of the expiry sub-question (what happens to a half-purchased ladder) and no StoreKit revocation flow to hook a refund to.

---

## 1. Decisions and constraints this depends on

- **D8:** decided 18 Aug 2026 (Alignment Plan §3) — adopt, as a Pass variant, coercive version. This spec exists to build it.
- **D6:** decided the same day — adopt. The Alignment Plan's own D8 entry had said *"if D6 stays out, the consistent call may be that this stays out too"* — D6 landing *in* removes that tension; no consistency question left to resolve.
- **D7 (session-one monetization silence):** load-bearing here — the Reward Ladder's proposed trigger (§0) is the existing `isMonetizationUnlocked` gate, not a new condition.
- **Pass having shipped:** met. `ProgressTrack`, the `passUnlockedEventIDs`-style per-feature persisted state, and the `pendingEventPassEventID` time-of-check/time-of-use fix (`Spec_Phase6b_Pass.md` §3.3) are all direct precedent this spec follows.
- **D5 (cadence, 3-event budget):** the Alignment Plan's own reasoning for why D8 doesn't spend this budget — *"one predicate, not a fourth event type"* — assumed a calendar-scheduled event. Under this spec's own §0 proposal (not calendar-scheduled at all), the question doesn't apply the same way; flagged for awareness, not treated as a problem, since a permanent Shop-surface feature was never what D5's weekly/continuous cadence was counting in the first place.

---

## 2. Target shape

| Piece | Source | This task's job |
|---|---|---|
| Ladder storage | `ProgressTrack`/`TrackMilestone` (Phase 6a, already built) | Reuse verbatim — `threshold` = rung index (1, 2, 3…), `freeRewards` = the node released alongside that rung, `paidRewards` = that rung's own direct payout |
| Progress driver | **New** — no separate faucet | Each purchase calls `progressTrack.advance(trackID:, by: 1)` directly; no `EventTokenRiderProvider`-equivalent needed |
| "Which rung is next" | Derived, no new state | `progressTrack.progress(trackID:) + 1` — the only rung ever purchasable |
| Trigger | **New**, proposed in §0 | Reuse `isMonetizationUnlocked` (D7) as-is; no calendar entry, no new registry |
| IAP | `IAPProduct` (existing enum) | One new **repeatable** consumable product — same pattern `kibbleMedium`/`dogTagsMedium` already use (bought more than once), not N distinct SKUs per rung |
| Reward application | `applyPurchase(_:priceUSD:)` (existing) | New case: advance progress, then immediately apply **both** lanes' rewards for the just-purchased rung — no separate claim tap (see §3.2 for why this diverges from Milestone/Pass's claim-on-tap UX) |
| UI | **New** | A ladder view — `EventSheetView`/`MilestoneRowView` are row-per-milestone, table-shaped; this needs a vertical rung-by-rung layout, closer in spirit to `ParallelBoardView`'s own "needed a new view, nothing existing fit" precedent than to anything reusable as-is |

### New coordinator: none

Unlike Parallel Board, this doesn't need a dedicated `@Observable` coordinator — `progressTrack` (already held by `MergeBoardViewModel`) is the entire state surface. A `rewardLadderTrackID` constant (or similar) identifies which `ProgressTrackRegistry` entry this feature reads, the same way Milestone/Pass event IDs already work, just with exactly one fixed ID instead of one per scheduled event instance.

---

## 3. Tasks, suggested landing order

### 3.1 — IAP product + purchase-application logic

Add to `IAPProduct` (`AnimalSpecies.swift`):

```swift
case rewardLadderRung = "com.pawsanctuary.rewardladder.rung"
```

- `displayName`: `"Reward Ladder"` (or a per-rung dynamic label at the UI layer, e.g. "Rung 3 of 6" — the IAP product itself is one repeatable SKU, not six distinct ones, so its own static `displayName` can't encode "which rung," matching how `kibbleMedium`'s name doesn't encode a purchase count either).
- `icon`: something distinct from `eventPass`'s `"star.circle.fill"` and `sanctuaryPass`'s `"medal.fill"` — e.g. `"chart.bar.fill"` or `"arrow.up.right.square.fill"` (ladder/ascending motif).
- `kibbleAmount`/`dogTagAmount`/`energyPackContents`: all `nil`/`default` — this product's reward is looked up from `ProgressTrackRegistry` at purchase time via the current rung, not a static per-product amount, same reasoning `eventPass` already established (its own reward comes from `ProgressTrack.claim`, not a fixed field on the enum case).
- Add to `PawSanctuary.storekit`'s consumable list. Suggested `displayPrice`: `"2.99"`, anchored to `dogTagsMedium`'s existing $2.99 price point (§4) — no model behind this number, design-authority to confirm before it's a real listing.

`MergeBoardViewModel.applyPurchase(_:priceUSD:)` — add, mirroring `eventPass`'s existing block shape:

```swift
if product == .rewardLadderRung {
    let nextRung = progressTrack.progress(trackID: rewardLadderTrackID) + 1
    progressTrack.advance(trackID: rewardLadderTrackID, by: 1)
    let paid = progressTrack.claim(trackID: rewardLadderTrackID, milestone: nextRung - 1, paidLane: true)
    let free = progressTrack.claim(trackID: rewardLadderTrackID, milestone: nextRung - 1, paidLane: false)
    applyRewards(paid + free)
}
```

**Why both lanes claim immediately, unlike Milestone/Pass's separate-claim-tap UX:** the reference mechanic's whole psychology (§0) is that a purchase *instantly* releases what was visibly locked — there is no "come back later and tap claim" step in either reference title, and adding one here would be new, unrequested friction with no reuse justification (Milestone/Pass's separate claim step exists because their free lane accrues gradually over days and claiming is a deliberate, separate action from earning; here, purchasing *is* the earning, so the natural moment to grant is the same moment). Flagged as a real, deliberate UX departure from the two precedents this spec otherwise follows closely, not an oversight.

`nextRung` must be captured at button-tap time, not resolved fresh after the async purchase completes — identical time-of-check/time-of-use gap `Spec_Phase6b_Pass.md` §0 found and fixed for `eventPass` (`e124444`) via `pendingEventPassEventID`. Add the equivalent `pendingRewardLadderRung: Int?`, set when the purchase button is tapped, consumed (and cleared) in `applyPurchase`, falling back to a live re-read of `progress(trackID:) + 1` only if nothing was captured this session (matching `pendingEventPassEventID ?? activeEvents.first?.id`'s own fallback shape).

**Guard:** if `nextRung` exceeds the ladder's milestone count (i.e., the player somehow triggers a purchase after already completing it — shouldn't be reachable if the UI correctly hides the CTA once maxed, but StoreKit purchase completion is a genuinely unbounded async wait, same class of race the `eventPass` fix addressed), `applyPurchase` must no-op rather than crash on an out-of-range `claim` call — verify `ProgressTrack.claim`'s existing `guard def.threshold <= state.progress` (`LiveOpsEngine.swift`) already covers this safely (it does — `claim` for a milestone index with no matching `TrackMilestone` returns `[]` via its own `guard let def = ...else { return [] }**, so this is very likely already safe by construction; confirm with a test rather than assuming).

### 3.2 — Schema: nothing new required

Unlike Pass's `passUnlockedEventIDs` (a new `GameState` field was needed because "unlocked" is state `ProgressTrack` itself doesn't track), the Reward Ladder's entire state **is** `progressTrack`'s existing `states[trackID]` entry — already persisted via `ProgressTrack.capture(into:)`/`restore(from:)` (`GameState.progressTracks`, v29). No schema bump, no migration, no new `GameState` field. Confirm this is actually true (not assumed) once 3.1 lands: a fresh purchase should survive force-quit/relaunch with zero additional persistence code written.

### 3.3 — `isMonetizationUnlocked` as the trigger (per §0's proposal)

Add a computed property, `MergeBoardViewModel.isRewardLadderAvailable: Bool { isMonetizationUnlocked }` — a thin, explicitly-named wrapper rather than reusing `isMonetizationUnlocked` directly at every call site, so a future change to the trigger condition (§6) only touches one place. Gate the new UI entry point (§3.4) on this.

### 3.4 — UI: the ladder view + entry point

New view, structurally its own thing (per §2 — nothing existing fits a vertical rung ladder). Rungs 1…N rendered top-to-bottom or left-to-right (design-authority call, not resolved here): purchased rungs show their claimed rewards plainly; the **one** next-purchasable rung shows both reward previews (paid + freed) with a buy CTA at `rewardLadderRung`'s live `displayPrice`; every rung beyond that renders locked/dimmed with no price shown (per the "coercive" decision — the *existence* of future rungs is visible, matching the reference titles' own screenshots, but not purchasable out of order).

Entry point: a new Shop-adjacent surface, gated on `isRewardLadderAvailable` (§3.3) — exact placement (a `TaskStripView` card vs. a `ShopView` section) is a design-authority call, not resolved here; either is a small, mechanical wiring choice once the ladder view itself exists.

### 3.5 — Test content

`ProgressTrackRegistry.tracks[rewardLadderTrackID]` needs a real entry — see §5.

---

## 4. First-cut numbers — flag before trusting

Same posture as every other Phase 6b spec's §4: **no economy model was run for these.** Anchored against the closest existing real price point (`dogTagsMedium`, 60 dog tags for $2.99, `PawSanctuary.storekit`) rather than the reference titles' own gem economy, which doesn't map onto this game's currencies.

- **Ladder length:** 6 rungs — shorter than Pass's 10 (a permanent Shop feature reads as smaller than a 30-day pass), longer than a 3-day weekly event's 3 (this isn't time-boxed, so more room to build anticipation).
- **Price per rung:** $2.99 flat throughout, matching the Alignment Plan's own *"same price, slightly richer payout"* — richness scales in the reward table, not the price.
- **Paid-lane (direct) reward:** dog tags only, deliberately **below** what $2.99 buys via `dogTagsSmall` (15 dog tags for $0.99, i.e. ~45 dog tags' worth at that per-dollar rate) — the reference economics (§0) show the paid node *alone* underperforms shelf price; this game's version should too, so the combined total is what earns its keep. Starting at 10 dog tags, escalating.
- **Free-lane (released) reward:** kibble + dog tags, richer than the paid lane at every rung, scaling up faster — this is the reward the player is "unlocking," so it should read as the better half of the pair, matching the reference's own inversion (§0).
- **No `.cardPack` hero reward** at the final rung, unlike Pass's — deliberately: this is a repeatable-feeling Shop surface, not a seasonal pass with a singular capstone; revisit if playtesting wants a stronger finish.

| Rung | Price | Paid (direct) dog tags | Free (released) kibble | Free (released) dog tags |
|---|---|---|---|---|
| 1 | $2.99 | 10 | 40  | 3  |
| 2 | $2.99 | 12 | 55  | 4  |
| 3 | $2.99 | 15 | 70  | 6  |
| 4 | $2.99 | 18 | 90  | 8  |
| 5 | $2.99 | 22 | 115 | 10 |
| 6 | $2.99 | 28 | 145 | 14 |

**This entire table is a placeholder for the design authority to replace, not a designed ladder.** It exists so the flow is screen-verifiable; treat the exact reward mix, rung count, and price as provisional, same as every other first-cut table in this project.

---

## 5. Task — one screen-verifiable test instance

Add `rewardLadderTrackID = "reward_ladder"` (a fixed constant, not date-stamped — unlike every other event type's IDs, this isn't a calendar instance that gets superseded, per §0/§2) and its `ProgressTrackRegistry.tracks` entry (the 6 rungs from §4). Since this isn't calendar-scheduled, there's no date window to pick — it becomes screen-verifiable the moment `isMonetizationUnlocked` is true for a test account (already achievable today via existing debug/reset tooling, per `resetToFreshGame()`'s existing dev-only paths), not gated on any future date the way Parallel Board's real test event was.

---

## 6. Open questions for design-authority review

This draft had its first design-authority pass on 18 Aug 2026. Resolved and still-open items below:

- **RESOLVED — the trigger/schedule proposal in §0.** Confirmed permanent-and-untimed: appears once `isMonetizationUnlocked` flips true, no expiry, no start-timestamp, no countdown. Real timer-bound behavior (matching the reference titles) was considered and explicitly not chosen, given the added complexity of the expiry sub-question (what happens to a half-purchased ladder — keep progress forever? reset it?) and no StoreKit revocation flow to hook a refund to.
- **Ladder placement in the UI** (§3.4) — Shop section vs. task-strip card vs. something else entirely. Still open.
- **Does the ladder repeat once completed**, or stay maxed forever as a one-time unlock? This draft assumes one-time (simplest, matches how a completed Milestone/Pass track just sits claimed) — not stated anywhere in the Alignment Plan's own D8 entry.
- **§4's numbers**, as always.

---

## 7. Out of scope

- **Real timer-bound behavior** — see §6; confirmed cut by the design authority, not silently dropped.
- **Repeating/resetting the ladder** — one-time only, per §6's stated assumption.
- **A player-facing name other than "Reward Ladder"** — placeholder chosen only to avoid the "chain" collision (§0); final copy is a design-authority call, same posture `Spec_Phase6b_Pass.md` took for "Event Pass."
- **Re-deriving §4's numbers against a real model.**
- **Refunds/revocation handling** for the new IAP product — matches existing precedent (`Spec_Phase6b_Pass.md` §7): no other consumable IAP in this codebase handles StoreKit revocation either.
- **Any change to `EventRegistry`, `ParallelBoardEventRegistry`, `checkEventLifecycle()`, or the calendar** — per §0/§2, this feature deliberately doesn't touch either scheduling system at all.
