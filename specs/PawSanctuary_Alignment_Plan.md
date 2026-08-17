# PawSanctuary — Alignment Plan

**Objective:** bring PawSanctuary's gameplay psychology into line with the three measured reference titles, before launch.
**Supersedes:** the checklist in §D of `PawSanctuary_Gap_Analysis.md`. That checklist was dependency-ordered but not a work plan. This is the work plan.

---

## 0. The chosen path, and its one real risk

**Chosen: complete alignment before launch.** The full sequence, including live-ops, shipping once the retention architecture is in place rather than retrofitting it.

**The risk:** live-ops is the largest single body of work here, and you'd be building it without telemetry telling you which events your players actually respond to.

**The mitigation, built into this plan:** the eight live-ops *primitives* are not speculative. They are the same eight in every game in the genre, and they're generic infrastructure — a token wallet does not care what event uses it. Build those fully. The *event catalogue* is where guessing starts, so ship a deliberately small set (three event types, §Phase 6) and expand post-launch against real data. That gets you a launchable retention lattice without authoring twenty events on instinct.

---

## 1. Organizing principle

Sequence by **what breaks if done late**, not by impact.

| Category | Rule | Examples |
|---|---|---|
| **Foundations** | Cheap now, 5–10× more expensive once features stack on top. Invisible to players. Do first regardless. | Reward riders as a list · player-state history · event primitive interfaces · `ChainCategory.currency` |
| **Atomic** | Must ship together or the game is broken in between | Neutral multiplier + recirculation |
| **Incremental** | Order-flexible once the above are done | Board psychology · orders · individual event types |

---

## 2. Working method

**This chat is the design authority. Claude Code is the implementation surface.**

The measured data, the economy model and the reasoning live here. Every implementation spec must be written **cold** — self-contained, numbers inline, rationale stated — so it can be handed to a coding agent with no memory of this conversation and no access to the capture files.

### Artifacts

| Artifact | Purpose | Lives |
|---|---|---|
| `Merge2_Reference_Blueprint.md` | What good looks like, theme-neutral | Design authority |
| `Phase2_Economy_Model.xlsx` | Every number, tunable | Design authority |
| `PawSanctuary_Alignment_Plan.md` | This file — the master backlog | Design authority |
| **Decision log** (§3 below) | Design calls with reasoning, so they aren't relitigated | Design authority |
| **Per-phase spec** | One per work session, written cold | Handed to Claude Code |

### Session rhythm

```
1. Confirm the decisions that gate the phase
2. I write the implementation spec here (cold, self-contained)
3. You implement in Claude Code
4. Report back what changed and what resisted
5. Verify against the spec, update the backlog, next phase
```

One phase per session where possible. Phases 2 and 6 will need more than one.

**Keep the game playable at every commit.** No phase should leave the build in a state you can't run. Phase 2 is the only one that genuinely can't be split — everything else can land incrementally.

---

## 3. Phase 0 — Decisions

Seven calls gate everything downstream. My recommendation and reasoning on each; override freely, but record the reasoning when you do so it doesn't get relitigated in three weeks.

### D1 — Is the wall real?

Your GDD states "no hard energy walls" as a monetization principle.

**Recommendation: replace it.** New wording: *"generous supply, designed depletion."*

Energy depletion is not a punishment — it's an interruption that leaves the loop open, and it is the single mechanism producing 6–10 sessions a day. You can be genuinely generous about *how much* energy you give (the reference games hand out ~395 free-or-cheap energy daily) while still making the *moment* of running out matter. Generosity is a dial on supply; the wall is a structural feature. The two aren't in tension — the current principle conflates them.

**Blocks:** Phase 3 entirely.

### D2 — Neutral spawn multiplier?

Currently ×8 costs 8 kibble and yields a tier-7 item worth 128 kibble — a 16× arbitrage that opens at level 20.

**Recommendation: yes, go neutral.** `cost = 2^tierIndex`. Neutrality is what makes the mechanic unarbitrageable in both directions and therefore safe to give away freely.

**Note this cannot ship alone.** The multiplier is currently doing all the recirculation work; making it neutral without adding recirculation makes the game unplayable.

**Blocks:** Phase 2.

### D3 — Do Dog Tags buy board items?

Your principle says never.

**Recommendation: allow it, with stock limits.** Two reasons, and the second matters more than the first. It's the highest-converting purchase path in the reference games because it fires at the moment of highest intent — a player blocked on one specific item. But it's also a **recirculation channel**, and you need those (§Phase 2). If you keep the prohibition, recirculation has to come entirely from order rewards and chests, which is achievable but narrower.

This is a values call and I'd defend either answer. Just don't decide it by default.

Corrected 15 Aug 2026: this line originally posed the question for "Dog Tags/Coins" jointly. What actually got built (`Spec_Phase2_Economy.md` §3c, then Pass's spec, then the Alignment Plan's own Phase 2 checklist below) is Dog-Tags-only — the shipped store is named and priced around Dog Tags exclusively (`DogTagStore`, `dogTagStoreBasePrice`, etc.), with no Coins purchase path anywhere. Narrowed here to match; only Phase 1's decision-summary table still carries the old two-currency phrasing.

**Blocks:** Phase 2 (recirculation sizing), Phase 4.

### D4 — Session target

GDD says 5–15 minutes. Reference is 2–4 minutes × 6–10/day.

**Recommendation: move to 2–4 min.** Your implemented economy already assumes it — 100 kibble at ×1 is a few minutes of tapping, not fifteen. The stated target and the built economy currently disagree, and the economy is the one that's right.

Session length drives cap, regen, order pacing, notification cadence and — critically — the number of wall events per day, which is the number of offer impressions.

**Blocks:** Phase 2 tuning, Phase 5.

### D5 — Sustainable live-ops cadence

**Recommendation: commit to a number now, before building the engine.** Realistically, solo, something like: one 3–4 day event per week, one 30-day album/pass running continuously, daily challenges auto-generated.

A lattice you can't feed is worse than a smaller one you can. This number determines how many event *types* are worth building in Phase 6.

**Blocks:** Phase 6 scope.

### D6 — Spend-quota tasks in dailies?

Reference games include "Spend 50 Gems" as a daily-challenge task. It converts the retention system into a monetization one at zero UI cost.

**Recommendation: out, at least at launch.** It's the most aggressive single mechanic found in the three games and it sits badly against your "Warmth" design pillar. It's also trivially addable later once you have conversion data. Nothing downstream is *blocked* on this decision — no task waits for D6 to resolve before it can build. Corrected 15 Aug 2026: this line originally read "nothing downstream depends on it" without qualification, which reads as contradicting D8's entry (added after this one), where "**Depends on:** D6's reasoning — decide the two together" is explicit. Both are true under the distinction above — D8 isn't gated waiting on D6, but D8's own recommendation is meant to track D6's for Warmth-pillar consistency, not sequencing.

### D7 — Session-one monetization silence?

**Recommendation: adopt.** The segment leader shows nothing — no offer, no ad, no store push — across 26 minutes and five levels, then fires the first offer at the first genuine wall around day 2–3.

Cheapest possible implementation: gate the shop and all offer surfaces behind a flag that flips at first genuine energy depletion or player level 5, whichever is later.

**Blocks:** Phase 3.

### D8 — Chain offer? *(added 27 Jul, measured)*

Both Gossip Harbor and Tasty Travels run a mechanic not previously catalogued: a vertical ladder of reward nodes where **free nodes sit padlocked until an adjacent paid node is purchased**. Buying releases them and advances the ladder, revealing the next paid rung — same price, slightly richer payout. Timer-bound, and in both observed cases surfaced at the energy wall.

The economics are the interesting part. Measured at Tasty Travels:

| | Gems/$ |
|---|---|
| Paid node alone (240 gems, $5.99) | 40.1 |
| Shelf price for the same 240 gems (Small pack, $4.99) | 48.1 |
| Paid node + the free nodes it releases | 52.4 |

**On its face the offer is a 20% premium to shelf.** It only becomes competitive once the free nodes are counted. The player is not buying gems — they are buying the release of rewards already visible and padlocked on screen. That inversion is the whole mechanic.

**Recommendation: adopt, but as a variant of the Pass primitive, not a fourth event type.** Structurally this *is* a pass with the lanes interleaved instead of parallel — free lane and paid lane, with the free lane's unlock condition changed from "reach the tier" to "purchase the adjacent node." It needs the progress track, reward table and offer hook already scheduled in Phase 6a, plus one new unlock predicate. That keeps D5's three-event budget intact.

**Argument against, and it isn't weak:** this is a harder sell than anything else in the plan. It shows the player a reward, locks it, and charges to unlock — mechanically closer to the "Spend 50 Gems" daily rejected in D6 than to the progress-protection framing adopted in D1 (corrected 15 Aug 2026 — was misattributed to D7, which only gates *when* Phase 3's offer can appear, not the framing of the offer itself; the progress-protection framing is D1's, same mixup as the one fixed in Pass's spec §4). It sits against the Warmth pillar for the same reason D6 does. If D6 stays out, the consistent call may be that this stays out too.

**Unresolved:** whether the free nodes must be visible-but-locked (the coercive version, which is what both reference titles ship) or can be earned on a parallel free track (the softer version, which is just a pass and needs no new work at all). This is the decision, and it is a values call rather than a modelling one.

**Blocks:** nothing in Phase 6b — corrected 15 Aug 2026, after Milestone track, Pass, and a Parallel Board draft all shipped or were scoped with D8 still unresolved, each independently concluding in its own spec that D8 doesn't block it. The Recommendation above already says why: adopting D8 keeps D5's three-event budget intact rather than adding a fourth, so it was never going to change Phase 6b's scope regardless of outcome. If anything the dependency runs the other way — D8 needs Pass's two-lane progress-track/purchase-unlock machinery already built, so **D8 is blocked on Pass**, not the reverse. (Corrected 15 Aug 2026: this previously credited "reward table/offer hook" to Pass too — `RewardTableRegistry`/`OfferHookRegistry` are real Phase 6a primitives, but Pass never used either; it's `ProgressTrack` alone that Pass built out and D8 would actually reuse.) (This entry's original "Blocks: Phase 6b scope" is very likely what produced Milestone track's spec briefly getting this backwards too, since fixed there — see that spec's §1.) **Depends on:** D6's reasoning — decide the two together. Also depends on Pass having shipped, which it now has.

---

## 4. Phase 1 — Foundations

*Invisible to players. Every item here gets significantly more expensive once features stack on it.*

- [ ] **1.1** Convert `AdoptionOrder` reward fields → `[OrderReward]` list with a `RewardKind` enum. Update `AdoptionBoard.generateOrder` and the reward distribution path in `MergeBoardViewModel`.
- [ ] **1.2** Add a rider-injection hook so active systems can append to `Order.rewards` at generation time.
- [ ] **1.3** Add `ChainCategory.currency` and the registry plumbing for it. No chains authored yet — just the category.
- [ ] **1.4** Add player-state tracking: rolling average purchase value, purchase count, days since last purchase, current wall. **Start recording from first launch — this cannot be backfilled.**
- [ ] **1.5** Stub the eight live-ops primitive interfaces (scheduler, token wallet, progress track, reward table, rider injection, parallel board, timer service, offer hook). Interfaces only; implementations in Phase 6.
- [ ] **1.6** Schema migration for the above. You're at v24 with an unbroken chain — keep it unbroken.

**Definition of done:** game plays identically to today; save/load round-trips; `PersistenceTests` green.

---

## 5. Phase 2 — Economy correction (atomic)

*The only phase that cannot be split. Specced from `Phase2_Economy_Model.xlsx`.*

- [x] **2.1** Neutral multiplier: decouple `spawnTier` from `spawnMultiplier - 1`; price at `2^tierIndex`.
- [x] **2.2** Recirculation — minimum viable set, sized so the demand/supply ratio lands near 1.0 at mid-game:
  - Orders occasionally pay **board items**, not only currency
  - Chests contain board items
  - A sub-object power-up effect that spawns a tier-N item
  - *(If D3 = allow)* board items purchasable with Dog Tags, stock-limited
- [x] **2.3** Generator-tier progression: new families spawn at higher base tiers as the map unlocks, so the target-tier-minus-base-tier gap stays roughly constant while chains deepen.
- [x] **2.4** Retune the 15-tier chain against the neutral economy using the model's wall-curve targets: below 0.70 through L30, drifting to 0.95 by L40, crossing 1.00 at L41–50, holding 1.05–1.25 thereafter.
- [x] **2.5** Reverse `DogTagKibbleExchange` from a volume discount to a daily-escalating ladder with reset. Target shape: ~320 discounted units/day, then flat.

**Definition of done:** a simulated player at L10/L30/L50 hits the ratio targets; no tier is reachable at a discount to its merge cost. **Met** — corrected 15 Aug 2026: this checklist had sat unchecked despite being fully shipped, contradicted by §5b/§5c below, both of which already describe Phase 2's tuning in the past tense. Confirmed via `GameStore`'s `v27` migration ("economy correction (Phase 2)"), `DogTagStore.swift`, and per-task comments throughout the codebase.

**Note — task numbering mismatch, not corrected here:** the codebase's own `// Task 2.x` comments don't match this checklist's numbers. Code tags recirculation work as **Task 2.3** (`AnimalSpecies.swift:1412`, plus `2.3a`/`2.3b`/`2.3c` for orders/chests/the Dog Tag store) and the Dog Tag ladder reversal as **Task 2.4** (`KibbleEngine.swift:28`, `MergeBoardViewModel.swift:1549`) — one lower each than this doc's 2.2 and 2.5 for the same work. This doc's numbering is kept as the source of record; flagged for awareness rather than renumbered, since renumbering would touch cross-references elsewhere (e.g. the D3 sub-bullet under 2.2 above).

---

## 5b. Phase 2b — Reduce chains to 12 tiers

Added 27 July after Phase 2's tuning revealed that capping order tiers at 9 left Stages 10–15 (90 named items) outside the order economy. Dropping Era 4 from every family brings top-tier cost from 16,384 to 2,048 kibble and puts the top of the chain back inside the loop.

Atomic, like Phase 2. Full spec: `specs/Spec_Phase2b_TwelveTiers.md`.

---

## 5c. Phase 2c — The coin economy

Added 27 July. Phases 2 and 2b tuned kibble; coins were never modelled despite gating the Sanctuary Map (291,900 coins total). Measured: orders yield ~145 coins/day against selling's ~6,500 — a 2,013-day map build-out versus 45. **Selling is currently the coin economy and orders are a rounding error**, which was never a decision.

**Decision made 27 July:** both channels pay coins, orders pay strictly more — orders at ~6.5 coins per kibble of build cost, selling at ~2.75. Orders become the efficient path (but require a matching order); selling stays useful as instant liquidity at a ~2.4x discount. Rejected orders-only (guts selling) and selling-only (the primary faucet is taught nowhere, so players stall with no way to diagnose it). Targets a ~60-day map build-out. Atomic. Full spec: `specs/Spec_Phase2c_CoinEconomy.md`.

---

## 6. Phase 3 — The wall

*Spec this before you get far into UX — the wall is a screen.*

- [x] **3.1** Rebuild `KibbleRefillSheet` as the designed moment: rewarded ad first (free, capped), then the escalating kibble ladder, then the bundle. Landed `ea92de8`.
- [x] **3.2** Move the ad out of any menu surface. It lives **in this dialog only**. Deleted the dead `WatchAdStripView` — it was already the only live ad surface.
- [x] **3.3** Surface the nearest incomplete order or event timer on the sheet — the player must leave seeing what's unfinished. (Event timer will extend naturally once Phase 6 ships real events; only orders exist to surface today.)
- [x] **3.4** First-purchase offer + `hasEverPurchased` gating; suppress all monetization surfaces in session one per D7. `isMonetizationUnlocked = commerce.hasReachedFirstWall && playerLevel >= monetizationUnlockLevel` (the latter a plain `let monetizationUnlockLevel = 5` constant, not a function — corrected 15 Aug 2026) — read D7's "whichever is later" as requiring both, not either.
- [ ] **3.5** Enable Push Notifications capability (already-written scheduling logic is what converts the wall into a return visit). **Blocked on you** — Xcode Signing & Capabilities, not code (see TODO.md).
- [ ] **3.6** Real ad SDK. Now load-bearing rather than optional. **Blocked on an SDK/account decision** (AdMob, AppLovin, etc.) — flag when ready to proceed.

**Definition of done:** hitting zero kibble produces the full ladder in order; a fresh account sees no monetization surface in session one. **Met for 3.1–3.4**, verified on screen 31 July 2026. Phase 3 is not fully closed until 3.5/3.6 land.

---

## 7. Phase 4 — Board psychology

- [x] **4.1** Kibble and Coin merge chains that spawn on the board (`ChainCategory.currency` from 1.3). Landed `d3c90f2`: 10% of family-spawner taps, 6 tiers each, tap-to-collect (2^(t+1)-1 value curve per the measured reference), drag-merge via the existing generic path. Side-fix: `triggerTopTierCelebration` was firing the animal-only Ambassador banner for any chain's top tier (including sub-objects already) — now guarded to `.animal`.
- [x] **4.2** Pre-seed locked rows with visible, unreachable kibble caches released on unlock. Landed `0d6ee51`: every locked cell holds a Kibble cache (tier authored per row, richer for deeper unlocks) rendered dimmed with a lock badge; `checkLevelUnlock` needed zero changes since it only ever flipped `isUnlocked`. Verified rendering + locked-tap no-op on screen; the unlock-reveal transition itself is a code-review-level guarantee (unchanged unlock logic), not screen-verified — a stuck simulator system dialog blocked further interaction that session.
- [x] **4.3** Bonus layer ("Lucky!"/"Legendary!") gated to boosted spawns, scaling with multiplier. Landed `30307f4`: 0/10/25/40% chance by multiplier tier (×1/×2/×4/×8), 85/15 Lucky/Legendary split, routed through the existing `finishSpawn` so a bonus still counts as a rescue and can fulfil an order. Not screen-verified this session — a stuck simulator notification-permission dialog blocked interaction; confidence is code-review-level (simple roll + tier bump, `finishSpawn` itself is exercised by every normal spawn).
- [x] **4.4** Bubble mechanic: probability *p* on merge, opened by ad (capped) / gems / waiting, **decaying into a lesser reward — never nothing**. Landed `6986959`: 15% of below-top-tier animal merges bubble instead of landing normally (top tier keeps its own Ambassador celebration); tapping an active bubble opens a sheet to pop for full value via rewarded ad (shares the kibble sheet's daily cap — `KibbleEngine.watchRewardedAd` refactored to a generic `onEarned` closure to make that sharing possible) or Dog Tags (cost scales with tier); left for 10 minutes it decays to a 50%-floor coin payout, auto-collected on tap, never zero. `BoardItem.bubbledAt: Double?` is a new optional defaulted to `nil` — no migration needed. Verified on screen: bubble creation via merge, active-bubble tap → pop sheet, ad-pop, Dog Tags pop button's disabled-when-unaffordable state, and decay → auto-collect. 129/129 tests passing.

**Phase 4 complete.**

---

## 8. Phase 5 — Orders

- [x] **5.1** 2 slots → 4, with a fixed 1 easy / 2 medium / 1 hard spread replacing the uniform tier roll. `AdoptionOrder` generation is now per-slot: slot 0 always rolls `.easy` (tiers 0-1), slots 1-2 `.medium` (2-3), slot 3 `.hard` (4-11, weighted toward the cheap end so a *guaranteed* hard order isn't as costly as the old ~6% chance of one) — see `orderSlotDifficultyPattern`/`orderDifficultyBands` in `AnimalSpecies.swift`. Slots beyond the base 4 (from Sanctuary Map upgrades) repeat the same 4-slot pattern.
  Doubling the base slot count roughly doubled order-driven demand on its own, so this retuned the Phase 2.5 economy dial alongside it: `EconomySimulation` now models slot count (4, or 5 from L13) and averages each slot's fixed-difficulty distribution instead of one shared table, and `orderDifficultyBands`' weights were re-derived against `testDemandSupplyRatioMatchesTheTargetCurve` until the original measured ratio curve held again (L1-30 < 0.70, L35/40 ≈ 0.88, crosses 1.00 at L45/50, settles at ≈1.19 for L55/60 — inside the 1.05-1.25 band). All 129 tests pass; verified on screen that 4 orders render and generate correctly (the Adoption Board panel already renders any count, no layout change needed).
- [x] **5.2** Split the roles: long-lived persistent orders (no timer, or many hours) + a separate short timed-order *event* carrying urgency. The 4 slots from 5.1 dropped `AdoptionOrder.timeRemaining` entirely — they now sit until fulfilled, no expiry, no auto-replace. A single separate `AdoptionBoard.urgentOrder` carries the countdown instead: 15 min to fulfil (`urgentOrderDuration`, the old shared constant, now repurposed for just this one slot), rolls `.medium` difficulty with guaranteed rewards scaled ×1.5 (`urgentOrderRewardMultiplier`) so it's worth rushing for. Missing it forfeits the reward outright and opens a real empty gap — `urgentOrderRespawnCooldown` (30 min) before a new one appears, shown as a distinct "on its way" placeholder card — the stakes the persistent slots never had. Schema v28→v29 (structural: `timeRemaining` removed from the persisted shape, not just superseded); old saves get `urgentOrder == nil` and spawn one on next load via `AdoptionBoard.ensureUrgentOrder`. `EconomySimulation` folds the urgent order in as +1 always-`.medium` slot; ratio curve held with no further retuning needed. 130/130 tests pass; verified on screen: urgent card shows a live countdown bar with no skip button, persistent cards show "Open — no rush" with skip still available.
  Reward composition still doesn't differentiate by difficulty (`orderBoardItemFrequency` is the same for every slot) — the blueprint's "hard slot pays PART" idea is 5.3's job, not folded in here.
- [x] **5.3** One slot dedicated to meta-progression materials, giving the map economy its own bottleneck. The hard slot (index 3) now always carries a `.material` `OrderReward` alongside its usual dogTags/coins — a random wood/metal/cement chain, `materialRewardCount` (1) items at `toolboxMaxTier(level) - materialRewardTierOffset (2)`, deterministic rather than a chance roll (matching the blueprint's per-difficulty payout table: easy/medium → COIN, hard → PART). Claiming routes into the same `InventoryStore.absorbMaterialItems` accumulator Toolboxes already use (cascade included), not a new mechanic. Toolboxes (quest-driven) remain the primary faucet; this is a smaller, reliable second one gated by order fulfillment instead of quest luck. No material-economy simulation exists yet (unlike the coin economy's `EconomySimulation`), so the quantity/tier is a conservative first cut, not empirically derived. 132/132 tests pass (2 new: every hard-slot order carries exactly one valid material reward; no other slot ever does). Verified on screen: the hard slot's card shows a leaf icon `+1` alongside its dog-tag/coin rewards; the other 3 slots don't.

**Phase 5 complete.**

---

## 9. Phase 6 — Live-ops

*Largest body of work. Build the engine fully; ship a small catalogue.*

**6a — Primitives (implement the Phase 1 stubs)** — spec `specs/Spec_Phase6a_Primitives.md`, written cold by Claude Code from this section + the existing `LiveOpsPrimitives.swift` stubs. Implemented across 6 commits (`7580cf9`…`dbce315`), 166/166 tests green, zero UI call sites — nothing wires these into `MergeBoardViewModel` or the on-screen event card yet, per the spec's scope cut.
- [x] Scheduler with overlap and priority resolution (`EventScheduler.contestedSlotWinner`) — tested against synthetic multi-event overlap; three real events exist now (corrected 15 Aug 2026 — was "only one"), but all three are sequenced back-to-back with zero gap, never concurrently, so the four-plus-concurrent case is still unexercised in practice
- [x] Token wallet · progress track (parallel free/paid lanes) · reward table · timer service · offer hook — real implementations (`TokenWallet`, `ProgressTrack`, `RewardTableRegistry`, `EventTimer`, `OfferHookRegistry`)
- [x] Parallel board instance — **stub only** (`ParallelBoardStub`): UUID bookkeeping, no board grid, no chains, no energy. The real thing is 6b's "Parallel board" item below, unchanged.

**6b — Event types (three only, per D5)**
- [x] Milestone track (uses progress track + riders only — cheapest) — spec `specs/Spec_Phase6b_MilestoneTrack.md`. Implemented across 6 commits (`096a9e2`…`efd5402` — excludes `486973c`, the spec-draft commit, matching how the Pass line below cites implementation commits only), 169/169 tests green. `EventProgress`/`eventProgress`/`EventMilestone` left inert per §3.6, not deleted. Faucet is now a rider-carrying fraction of orders (`MilestoneTrackRiderProvider`, 33%/20 tokens, first-cut numbers), not general coin income. Verified end-to-end on the simulator with a live test event (`adoption_drive_aug2026`): rider fired from real order fulfillment, milestone claimed, reward applied, state survived a force-quit/relaunch round trip. `checkEventLifecycle()` is launch-only — an event starting mid-session won't register its rider until next launch, flagged as a known gap in the spec. **Design-authority-reviewed against the shipped code 15 Aug 2026** (the same pass done for Pass): implementation faithful to the spec, numbers match §4 exactly, the `applyRewards` extraction the spec asked for avoided the duplication it was meant to. One real bug found and fixed (`edca93e`): both the task-strip card and the event sheet's milestone rows displayed event-token progress hardcoded as `"...coins"` — a leftover from the pre-6b `EventProgress.coinsEarned` system, never updated when this task switched the faucet to `.eventToken`, and actively misleading since the game has a real, separate coins currency. Now reads `"...tokens"` in both spots.
- [x] Pass, free + paid lanes — spec `specs/Spec_Phase6b_Pass.md`, written cold by Claude Code at the user's request (no prior design-authority spec existed). Implemented across 6 commits (`92bdfae`…`064cd02`, merged `ef1d080`) weeks before this checkbox was updated — this entry sat stale as "not yet reviewed" long after the code shipped; implementation raced ahead of the design-authority review the working method calls for. **That review happened 15 Aug 2026** (against the shipped code, not just the spec) and found the implementation faithful to the spec — numbers match §4's table exactly, migration tests present and correct, and the implementer found and closed a real gap in `ProgressTrack` along the way (`isClaimed`, needed because `claimable`'s OR-combined design can't tell which lane is claimed once both render at once). One real bug found and fixed (`e124444`): `applyPurchase` read `activeEvent?.id` only *after* the async StoreKit purchase resolved, so a purchase confirmation straddling the event's end date could charge real money and silently drop the unlock. Fixed by capturing the event at button-tap time instead. Still flags what it always flagged: the naming collision workaround (`sanctuaryPass` vs. the new `eventPass`) and the single-active-event model gap (`EventRegistry.currentEvent`) that D5's concurrent weekly-event-plus-Pass model will eventually need — deliberately not fixed, raise before 6c.
  - [ ] *(If D8 = adopt)* Chain-offer variant: same primitive, free-lane unlock predicate changed from "tier reached" to "adjacent paid node purchased." One predicate, not a fourth event type — this is why it does not spend D5's budget.
- [x] Parallel board — highest revenue, most expensive; the one worth the effort. Spec `specs/Spec_Phase6b_ParallelBoard.md`, written cold by Claude Code at the user's request, same exception made for Pass. Two open architectural forks (§0.1/§3.1 — `ParallelBoardHosting`'s fate; §0.5 — registry placement) and one open persistence question (§3.7 — does the board survive a force-quit?) were all put to the design authority directly rather than decided unilaterally: retire the stub protocol, keep parallel-board events out of `EventRegistry` in their own small separate registry, and persist board+energy (reversing this doc's own draft recommendation of "cheaper, don't persist"). **Implemented across 7 commits (§3.1–§3.7, `595d7b0`…`736e869`) plus a content-authoring pass (§5, `205da50`), all 16 Aug 2026.** `ParallelBoardCoordinator` owns an independent `BoardStateManager`/`ParallelBoardEnergy`/`ProgressTrack`-sharing merge-and-generator board; `attemptMerge` reuses `computeMergeOutcome` (Phase D) at roughly a fifth of `attemptMergeOrMove`'s size; a dedicated full-screen `ParallelBoardView` reuses `CellView` directly (it turned out to already be fully decoupled from `MergeBoardViewModel` — resolved the spec's own open question); board/energy persist via `GameState.parallelBoardState` (schema v35→v36); a real test event ("Second Chances," `second_chances_20260911`, 2026-09-11→09-14) is registered, deliberately overlapping Sanctuary Circle S1 and Playtime Rush's second instance as a three-way concurrency proof. 366/366 tests green. **Not yet reviewed by the design authority against the shipped code** (same gap Milestone track/Pass had before their own 15 Aug review) — do that pass before relying on this entry as settled. **One item still genuinely open, not just unreviewed:** the spec's own "verified on screen" acceptance item — the real test event doesn't open until 2026-09-11, so the actual tap-generator-merge-watch-progress flow has never been watched happen on a running instance of the app (a same-day attempt to shortcut this via the iOS Simulator's clock didn't succeed and was abandoned rather than forced; see `TODO.md` and the spec's own §5 status note). A one-time scheduled reminder exists for that date.

**6c — Calendar**
- [x] **Prerequisite, added 15 Aug 2026:** fix the single-active-event model (`EventRegistry.currentEvent`) — flagged three times without being fixed (Milestone track §7, Pass §0, Parallel board §1), and the real calendar below can't honor D5's "concurrently" clause without it. Spec `specs/Spec_Phase6c_ConcurrentEvents.md`, written cold by Claude Code at the user's request. Implemented across 6 commits (`b023431`…`0cd351c`, 16 Aug 2026) — `EventRegistry.activeEvents`, `checkEventLifecycle()`'s diffed multi-provider rider registration, UI wiring for concurrent event cards/sheets, and a real overlapping test event (`foster_weekend_aug2026`) proving it on screen. Design-authority review complete the same day.
- [x] Author a rolling 90-day `EventDefinition` calendar. Infrastructure without a calendar is exactly where you are now. Spec `specs/Spec_Phase6c_Calendar.md`, written cold by Claude Code at the user's request (16 Aug 2026), same exception made for Pass/Parallel Board/the concurrent-events prereq. Implemented across 5 commits (`95b27ce`…`1ada2fc`, 16 Aug 2026) — 13 weekly events (two alternating flavors, reusing Adoption Drive's exact reward-curve shape) plus 3 sequential 30-day Passes ("Sanctuary Circle," reusing Founders' Circle's exact curve) covering 2026-09-04 → 2026-12-03, deliberately Milestone-track and Pass only since Parallel Board isn't implemented and D8 is still undecided. Pure content authoring on top of the already-shipped concurrent-events infrastructure — introduced no new mechanism. 34 new tests, 325/325 green, including a day-by-day (not spot-checked) simulation across the full 90 days proving the calendar never produces more than 2 simultaneously-active events even through the one weekly instance that straddles a season boundary. **Design-authority review complete the same day** — reviewed and accepted as written, no changes requested.

---

## 10. Phase 7 — Ongoing

Content calendar feeding. Not a phase that ends — this is the operating cost of the model you've chosen, and D5 is the honest estimate of what you can carry.

---

## 11. What could go wrong

**Phase 2 spirals.** Retuning a 15-tier × 15-family chain against a new economy is the most open-ended work here. Mitigation: tune one family end-to-end first, validate against the model, then apply the pattern.

**Live-ops scope creep.** Six event types is more fun to build than three. Three is the number D5 supports. Resist.

**The UX work and Phase 3 collide.** The wall is a screen and you're building screens. Spec Phase 3 before that screen gets built, or it gets built twice.

**The chain offer gets adopted on economics alone.** It measures well and it is cheap to build on top of the Pass primitive, which makes it easy to wave through. But D6 rejected a *less* aggressive mechanic on Warmth grounds. Deciding D8 on the spreadsheet while D6 was decided on the pillar is how a design stops being coherent. Decide them together or revisit D6.

**Foundations get skipped because they're invisible.** Phase 1 produces no visible change and is the easiest thing to defer. It's also the phase whose omission makes Phase 6 twice as expensive.

---

*Companion to `Merge2_Reference_Blueprint.md`, `Phase2_Economy_Model.xlsx`, `PawSanctuary_Gap_Analysis.md`, and `Findings_26July.md`.*
