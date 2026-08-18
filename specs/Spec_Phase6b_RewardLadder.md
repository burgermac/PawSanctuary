# PawSanctuary — Phase 6b: Reward Ladder (D8, "chain offer")

**Self-contained brief.** Assumes no prior conversation. Follows Milestone track, Pass, and Parallel Board (`specs/Spec_Phase6b_MilestoneTrack.md`/`Spec_Phase6b_Pass.md`/`Spec_Phase6b_ParallelBoard.md`), all shipped and design-reviewed.

> **Not atomic.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists.

**Written cold by Claude Code at the user's request, same exception made for Pass/Parallel Board/the 6c calendar. Design-authority reviewed 18 Aug 2026: the §0/§6 trigger question, §3.4's UI placement, and §4's numbers are all confirmed.** This spec exists because D8 was decided 18 Aug 2026 (Alignment Plan §3): **adopt, as a variant of the Pass primitive, coercive version** (visible-but-locked free nodes, matching both reference titles). That decision resolved *whether* and *which version* — it did not resolve *how this actually gets triggered/scheduled*, *where it lives in the UI*, or *what the exact ladder numbers should be*, all genuinely unaddressed by the Alignment Plan's own D8 entry. This draft proposed answers to all three; all three are now confirmed — see §6 for the one remaining open item (repeat-vs-one-time), not load-bearing for implementation to begin.

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

### 3.2 — Schema: nothing new required — confirmed 18 Aug 2026

Unlike Pass's `passUnlockedEventIDs` (a new `GameState` field was needed because "unlocked" is state `ProgressTrack` itself doesn't track), the Reward Ladder's entire state **is** `progressTrack`'s existing `states[trackID]` entry — already persisted via `ProgressTrack.capture(into:)`/`restore(from:)` (`GameState.progressTracks`, v29). No schema bump, no migration, no new `GameState` field.

**Confirmed, not assumed:** `RewardLadderPersistenceTests` (`PawSanctuaryTests/RewardLadderPurchaseTests.swift`) drives the real public path — `applyPurchase` on one `MergeBoardViewModel`, then `loadGame()` on a fresh second instance — through the actual disk-backed `GameStore`, not an in-memory `Codable` round-trip. A single purchase survives force-quit/relaunch with zero additional persistence code, as claimed.

**Real, unrelated finding surfaced while writing that test:** firing several `applyPurchase` calls with no gap between them can lose progress on relaunch — not a Reward Ladder bug, but a pre-existing race in `GameStore.saveAndSync`'s fire-and-forget `Task.detached` writes (two overlapping saves can finish out of order, and the earlier/stale one can land last). Flagged in `TODO.md` ("Back-to-back `persist()` calls can race each other's disk write") rather than fixed here — it's a persistence-layer issue affecting every IAP, not something this task should patch. The test itself spaces purchases realistically (matching how actual StoreKit confirmations round-trip) rather than working around the race.

### 3.3 — `isMonetizationUnlocked` as the trigger (per §0's proposal)

Add a computed property, `MergeBoardViewModel.isRewardLadderAvailable: Bool { isMonetizationUnlocked }` — a thin, explicitly-named wrapper rather than reusing `isMonetizationUnlocked` directly at every call site, so a future change to the trigger condition (§6) only touches one place. Gate the new UI entry point (§3.4) on this.

### 3.4 — UI: the ladder view + entry points — implemented 18 Aug 2026

New view, structurally its own thing (per §2 — nothing existing fits a vertical rung ladder): `RewardLadderSection`/`RewardLadderRungRow` in `ShopView.swift`. Rungs render top-to-bottom (design-authority call within the confirmed direction — vertical, matching the "ladder" framing literally): purchased rungs show their claimed rewards plainly with a checkmark; the **one** next-purchasable rung shows both reward previews (paid + freed) with a buy CTA at `rewardLadderRung`'s live `displayPrice`; every rung beyond that renders locked/dimmed with a lock icon and no price shown (per the "coercive" decision — the *existence* of future rungs is visible, matching the reference titles' own screenshots, but not purchasable out of order). `RewardLadderSection` degrades to nothing if `rewardLadderTrackID` has no registry content yet (true until Task 3.5 lands) rather than rendering an empty box.

**On-screen verification is partial, honestly flagged rather than overclaimed:** confirmed via Simulator — clean build, full test suite passing, no crash on launch, and the new UI (both entry points) correctly absent on a fresh install (`isRewardLadderAvailable` false pre-unlock, matching the gating design). **Not verified this session:** the ladder actually rendering with real rungs and a working purchase flow. Two independent blockers, neither a defect in this task's own code: (1) `rewardLadderTrackID` has no `ProgressTrackRegistry` content until Task 3.5, so there is nothing to render yet regardless of gating; (2) reaching `isMonetizationUnlocked` (`hasReachedFirstWall && playerLevel >= 5`) needs real play or debug tooling this codebase doesn't currently have (`resetToFreshGame()` resets to level 1, it doesn't unlock monetization) — out of scope to add here. A Simulator tap-registration issue this session (a specific button not responding to synthetic taps despite several calibrated attempts, unrelated to any code in this task) also blocked deeper interactive poking. Full interactive verification is realistically a Task-3.5-or-later item.

**Entry points — confirmed by the design authority, 18 Aug 2026: both, not either/or.**

- **Primary: a new `ShopView` section**, alongside `VIPSection` (`ShopView.swift:485`) — the closest existing precedent, both being permanent/untimed/progress-driven surfaces living in the Shop sheet rather than the task strip. This is the section that actually hosts the ladder view.
- **Secondary: a new `TaskStripView` card**, next to `EventTaskCard`/`ParallelBoardTaskCard`, gated on `isRewardLadderAvailable` (§3.3), tapping through to the Shop's ladder section rather than opening its own sheet — matching how `EventTaskCard`/`ParallelBoardTaskCard` tap through to their own detail surfaces rather than duplicating one.
- **Real design point this raises, flagged rather than glossed over:** every existing task-strip card carries a `timerLabel` countdown (`EventTaskCard.swift`/`ParallelBoardTaskCard` both render one, `PanelViews.swift:1343`/`1388`) — the strip's whole visual language is built around urgency. The Reward Ladder card would be the **first untimed card in that strip**. It needs a deliberately different treatment in that slot (e.g. a progress fraction — "Rung 3/6" — in place of the countdown badge, not an empty space where one would normally sit) rather than reusing `EventTaskCard`'s layout verbatim. Left as an implementation-time design call within the confirmed "both" placement, not a fork to redecide.

Gating for both surfaces: `isRewardLadderAvailable` (§3.3).

### 3.5 — Test content — implemented 18 Aug 2026

`ProgressTrackRegistry.tracks[rewardLadderTrackID]` (`LiveOpsEngine.swift`) now has the real 6-rung entry from §4, verbatim. `RewardLadderContentTests` (`PawSanctuaryTests/RewardLadderPurchaseTests.swift`) locks down the table itself (exact match against §4, paid-lane-below-shelf, combined-above-shelf, strictly-increasing paid amounts) and the one invariant that would silently break purchasing if it ever drifted: `threshold == index + 1` for every rung, since `applyPurchase`'s `.rewardLadderRung` case derives which milestone to claim from the purchase count, not a stored ID. `RewardLadderPurchaseTests` also gained two tests this content unlocked — a real purchase now grants the correct paid + free rewards, and a second purchase grants rung 2's own rewards rather than rung 1's again. 393/393 tests passing.

Full interactive/on-screen verification is still not possible — same two blockers Task 3.4 already flagged (no debug lever to reach `isMonetizationUnlocked` short of real play, and this session's Simulator tap-registration issue), neither caused by this task. §5 below is the real screen-verifiable path once those are addressed.

---

## 4. Numbers — recalibrated and confirmed by the design authority, 18 Aug 2026

The original placeholder table (this section's first draft) was written cold with no shared unit between the paid lane's dog tags and the free lane's kibble — it couldn't be checked against the reference economics (§0) at the time it was written. This codebase already has an exchange rate between the two: the Shop's tag→kibble exchange (`DogTagKibbleExchange`, `AnimalSpecies.swift:1130`) settles at a flat 60 dog tags → 100 kibble once its daily discount is used up, i.e. **1 kibble ≈ 0.6 dog-tag-equivalent** at steady state. That, plus `dogTagsMedium` (60 dog tags for $2.99, `PawSanctuary.storekit`) as the real "shelf" comparison for this price point, gives a real check the original table never had.

Run through that conversion, the original table's escalation was inconsistent with the reference data it claimed to follow: paid-alone value started at only 17% of shelf and combined value at 62% (both *worse* than shelf — a bad deal at rung 1), while by rung 6 paid-alone reached 47% and combined reached 215% of shelf — a swing far more extreme than the reference's own measured ~83% paid-alone / ~109% combined (§0), and not a smooth *"slightly richer payout"* curve (the Alignment Plan's own D8 quote) so much as a discontinuous jump.

**Recalibrated table, confirmed:** paid-alone value rises steadily from 60% to 90% of shelf across the six rungs (always below shelf, so the paid lane alone never looks like a substitute for just buying `dogTagsMedium`); combined value rises from 102% to 153% of shelf (always above shelf, and growing — genuine, mounting reason to keep going, not a flat repeat).

- **Ladder length:** 6 rungs — kept from the original draft (shorter than Pass's 10, longer than a 3-day weekly event's 3); not revisited in this pass.
- **Price per rung:** $2.99 flat throughout — kept, matches *"same price, slightly richer payout."*
- **No `.cardPack` hero reward** at the final rung — kept, per the original draft's reasoning (this is a repeatable-feeling Shop surface, not a seasonal pass with a singular capstone).

| Rung | Price | Paid (direct) dog tags | Free (released) kibble | Free (released) dog tags | Paid-alone vs. shelf | Combined vs. shelf |
|---|---|---|---|---|---|---|
| 1 | $2.99 | 36 | 35 | 4 | 60% | 102% |
| 2 | $2.99 | 40 | 35 | 4 | 67% | 108% |
| 3 | $2.99 | 43 | 40 | 5 | 72% | 120% |
| 4 | $2.99 | 47 | 40 | 6 | 78% | 128% |
| 5 | $2.99 | 50 | 45 | 7 | 83% | 140% |
| 6 | $2.99 | 54 | 50 | 8 | 90% | 153% |

Still open, deliberately not touched in this pass: whether 6 rungs and $2.99 flat are themselves the right length/price (not challenged here — only the reward *mix* was recalibrated), and any real playtesting-driven tuning once this ships.

---

## 5. Task — one screen-verifiable test instance — content done, real verification still blocked

`rewardLadderTrackID = "reward_ladder"` (`AnimalSpecies.swift`, a fixed constant, not date-stamped — unlike every other event type's IDs, this isn't a calendar instance that gets superseded, per §0/§2) and its `ProgressTrackRegistry.tracks` entry (the 6 rungs from §4) both landed in Task 3.5. Since this isn't calendar-scheduled, there's no date window to wait for the way Parallel Board's real test event had — but this section's original claim that reaching `isMonetizationUnlocked` was **"already achievable today via existing debug/reset tooling, per `resetToFreshGame()`'s existing dev-only paths"** turned out to be wrong, caught while actually trying to verify Task 3.4/3.5 on screen rather than assumed: `resetToFreshGame()` (`MergeBoardViewModel.swift`) resets `progression.playerLevel` to 1 and doesn't touch `commerce.hasReachedFirstWall` — it resets *away* from monetization-unlocked, not toward it. There is currently no debug lever that gets a fresh test account to `isMonetizationUnlocked == true` faster than real play (reach player level 5 and the first kibble wall) would.

- [ ] **Real screen verification, still open:** either play a test account to level 5 + the first wall the normal way, or add a small `#if DEBUG` toggle (mirroring `resetToFreshGame()`'s own precedent) that flips `commerce.hasReachedFirstWall = true` — a design-authority call on whether that debug affordance is worth adding, not assumed here. Once available: confirm the Shop's `RewardLadderSection` and the task-strip `RewardLadderTaskCard` both appear, confirm the ladder view's layout (purchased/next/locked states) matches §3.4's design, and complete a real rung purchase to confirm `applyPurchase` grants the right rewards on screen (unit-tested already in `RewardLadderPurchaseTests`/`RewardLadderContentTests`, but never watched happen).

---

## 6. Open questions for design-authority review

This draft had its first design-authority pass on 18 Aug 2026. Resolved and still-open items below:

- **RESOLVED — the trigger/schedule proposal in §0.** Confirmed permanent-and-untimed: appears once `isMonetizationUnlocked` flips true, no expiry, no start-timestamp, no countdown. Real timer-bound behavior (matching the reference titles) was considered and explicitly not chosen, given the added complexity of the expiry sub-question (what happens to a half-purchased ladder — keep progress forever? reset it?) and no StoreKit revocation flow to hook a refund to.
- **RESOLVED — ladder placement in the UI (§3.4).** Both: primary `ShopView` section (alongside `VIPSection`) plus a secondary `TaskStripView` card that taps through to it. The task-strip card needs its own untimed visual treatment (no `timerLabel` to show) — flagged in §3.4, left as an implementation-time detail rather than a further fork.
- **RESOLVED — §4's numbers.** Recalibrated against the game's real dog-tag/kibble exchange rate and confirmed — see §4 for the table and methodology.
- **Does the ladder repeat once completed**, or stay maxed forever as a one-time unlock? This draft assumes one-time (simplest, matches how a completed Milestone/Pass track just sits claimed) — not stated anywhere in the Alignment Plan's own D8 entry. Still open.

---

## 7. Out of scope

- **Real timer-bound behavior** — see §6; confirmed cut by the design authority, not silently dropped.
- **Repeating/resetting the ladder** — one-time only, per §6's stated assumption.
- **A player-facing name other than "Reward Ladder"** — placeholder chosen only to avoid the "chain" collision (§0); final copy is a design-authority call, same posture `Spec_Phase6b_Pass.md` took for "Event Pass."
- **Full economy modeling / playtesting of §4's numbers.** The recalibration in §4 checks internal consistency (paid-alone vs. shelf, combined vs. shelf, using the game's real exchange rate) — it is not a market-tested economy model, and the ladder length and $2.99 price point were carried over from the original draft without being re-examined.
- **Refunds/revocation handling** for the new IAP product — matches existing precedent (`Spec_Phase6b_Pass.md` §7): no other consumable IAP in this codebase handles StoreKit revocation either.
- **Any change to `EventRegistry`, `ParallelBoardEventRegistry`, `checkEventLifecycle()`, or the calendar** — per §0/§2, this feature deliberately doesn't touch either scheduling system at all.
