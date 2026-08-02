# PawSanctuary — Phase 6b: Pass, free + paid lanes (second event type)

**Self-contained brief.** Assumes no prior conversation. Follows the Milestone track (commits `486973c`…`efd5402`, merged to `main` at `afd2b02`).

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

**DRAFT — written cold by Claude Code, not yet reviewed by the design authority.** Per the Alignment Plan's working method (§2), specs are supposed to originate in the design conversation and be handed to Claude Code to implement. No such spec existed for this task, so this one was drafted directly in the implementation session at the user's request. Treat every number in §4 and every judgment call flagged below as provisional — review before implementing, the same way `Spec_Phase6a_Primitives.md`'s header flags its own scope cuts as worth a second look.

---

## 0. Why

Per the Alignment Plan §9 (Phase 6b): *"Pass, free + paid lanes."* Per D5 (§3): the sustainable live-ops cadence is roughly one 3–4 day event per week **plus one continuously-running 30-day track**. The Milestone track (just shipped) is the weekly-cadence event type. The Pass is the 30-day one — same primitive underneath, one lane richer.

Mechanically this is almost the whole Milestone track again: `ProgressTrack.advance`/`claim` already support a paid lane (`claimedPaid`, `paidRewards`, `paidLane: Bool` parameter) — Milestone track's spec (§2, "Target shape") built it that way on purpose and simply never populated the paid side, since a pure milestone track doesn't have one. The primitive was engineered for this before this task existed. Two things are genuinely new:

1. **A way to unlock the paid lane** — a real-money purchase, since the paid lane is the monetization surface the reference games use a battle pass for.
2. **UI for two lanes instead of one.**

**Two things found while reading the code that change this task's shape, flagged before the plan below:**

### Naming collision — "Pass" already means something else in this codebase

`IAPProduct.sanctuaryPass` (`com.pawsanctuary.pass.monthly`) is a **shipped, real** monthly subscription — `StoreManager.isPassActive`, wired through `MergeBoardViewModel.isPassActive`/`passMultiplier`/`effectiveAdKibble`, documented in the GDD (`PawSanctuary_GDD.md:237,402`) as "+20 Kibble/day, ×1.5 multiplier on all claimed Kibble rewards." It is a **permanent, recurring, non-event-scoped** entitlement. It has nothing to do with the Alignment Plan's "Pass, free + paid lanes" — that phrase is genre terminology (season pass / battle pass), and it collides head-on with an existing, differently-shaped feature that happens to share the word.

**This spec calls the new thing the "Event Pass"** everywhere — code, IAP product name, UI copy — specifically to keep it typographically and conceptually distinct from "Sanctuary Pass." If the design authority wants a different player-facing name (many reference games use something thematic — "VIP Pass," "Golden Bone," whatever fits Warmth), that's a copy change, not a structural one; the important part is that it isn't just "Pass."

### The single-active-event model doesn't support what D5 asks for

`EventRegistry.currentEvent` is `allEvents.first { $0.isActive }` — **one event, singular**, and `MergeBoardViewModel.activeEvent`/`checkEventLifecycle()`/both UI entry points (`MergeBoardView.swift:649`, `PanelViews.swift:1578`) are all built on that single value. D5 explicitly wants a weekly Milestone-type event running **concurrently** with a continuous 30-day Pass. The day both are scheduled for real, `currentEvent` picks whichever is `.first` in `allEvents` and the other becomes invisible — not a partial degradation, a silent one, since nothing here throws or asserts.

The rider layer already doesn't have this problem — `OrderRewardRegistry.providers` is a list, and `AdoptionBoard.swift:128` flattens riders from all of them, so two concurrently-registered providers already stack correctly. The scheduler primitive built in 6a (`EventScheduler.activeEvents(at:)`, plural) also doesn't have this problem. **It's specifically `EventRegistry.currentEvent` and everything downstream of it that assumes one.**

**Decision for this task: do not fix it.** Generalizing "the active event" to a plural model touches the two UI entry points, `checkEventLifecycle()`, and `activeEvent` itself — real surface area, and `CLAUDE.md` Rule 5 says ask before large refactors. It's also not this task's problem to solve alone: 6c (the rolling calendar) is where concurrent events actually start getting authored, and generalizing the single-event model without a second real concurrent event to test it against risks guessing the wrong shape. Milestone track's own spec deferred the identical thing (§7, "`EventScheduler`'s overlap/priority resolution — only one event exists or is planned right now") — this is the same deferral, now flagged twice, which is the point at which it should be raised explicitly rather than deferred a third time. **Raise before 6c.**

**Consequence for this task, worked around, not fixed:** the Event Pass test event (§5) cannot run concurrently with the Milestone track's live test event (`adoption_drive_aug2026`, active through 2026-08-05). It's scheduled to start 2026-08-06, after that one ends, so only one event is ever active at a time — same constraint the shipped code already lives under.

---

## 1. Decisions this depends on

- **D5 (cadence):** this task exists because of D5's second clause — the continuous 30-day track. Test event runs 30 days (§5), not 3–4.
- **D8 (chain offer):** does not block this task. D8's variant is described in the Alignment Plan as *"a variant of the Pass primitive"* — i.e., it's a follow-on to this task, not a prerequisite. Still unresolved (Alignment Plan §3, D8) and still a separate task.
- **D3 (Dog Tags buy board items) / D6 (spend-quota dailies):** not directly load-bearing here, but D6's reasoning is the reason to be deliberate about paid-lane reward *contents* — see §4.

---

## 2. Target shape

| Piece | Source | This task's job |
|---|---|---|
| Track state, two lanes | `ProgressTrack`/`TrackState` (already built, Phase 6a) | Populate `paidRewards` on real `TrackMilestone`s — currently empty on every entry |
| Faucet | Order rider → `.eventToken` (already built, Phase 6b Milestone) | Reuse as-is; generalize the rider provider's name (see §3.2 — it's not milestone-specific in body, only in name) |
| Paid-lane unlock | **New** | A real-money purchase (`IAPProduct.eventPass`) that flips a per-event-ID persisted flag |
| UI | `EventPanelView.swift` (Milestone track's, already built) | Add a paid-lane column per milestone row + a purchase CTA when locked |

---

## 3. Tasks, suggested landing order

### 3.1 — Generalize the rider provider

`MilestoneTrackRiderProvider` (`EventSystem.swift`) has zero milestone-specific logic in its body — it emits `.eventToken` riders for an `eventID` at some frequency/amount. It was named for its one caller, not because it's milestone-shaped. Rename it to `EventTokenRiderProvider` (keep the same `init(eventID:tokensPerRider:riderFrequency:)` signature — only the type name changes) so the Pass track can reuse it instead of hand-duplicating a second near-identical class. Update:
- `EventSystem.swift`'s declaration and doc comment
- `MergeBoardViewModel.checkEventLifecycle()`'s one construction call site (`MergeBoardViewModel.swift:2941-2946`) and the `activeMilestoneRiderProvider` var's doc comment (rename the var too if it reads oddly post-rename — `activeEventRiderProvider` reads fine)
- `PawSanctuaryTests/EventSystemTests.swift`'s references (`grep -rn MilestoneTrackRiderProvider` first to get the exact call sites — one file, unknown count of references)

**No behavior change.** This is a pure rename; verify by running the existing Milestone track tests unchanged in intent, just recompiled against the new name.

### 3.2 — Paid-lane unlock state

Add to `GameState` (schema v30 → v31, additive, no data loss):

```swift
/// Event IDs whose Event Pass paid lane has been purchased. Per-event, not
/// global — buying the Pass for one event doesn't carry over to the next one
/// the way Sanctuary Pass's subscription does. See specs/Spec_Phase6b_Pass.md
/// §0 for why this is deliberately not named anything with "sanctuary" or
/// reusing IAPProduct.sanctuaryPass.
var passUnlockedEventIDs: Set<String> = []
```

Bump `GameStore.currentVersion` to `31`. Add `if version == 30 { return migrateByInjecting(from: 30, defaults: [:], into: data) }` to the dispatch chain (mirrors the existing `version == 29` line), and add `"passUnlockedEventIDs": [String]()` to `additiveDefaultsSinceV8` — purely additive, same shape as `eventTokenWallets`/`progressTracks`' own v30 migration.

`MergeBoardViewModel` needs read/write access — no new coordinator needed, this is a flat `Set<String>` read/written directly off `GameState`-backed state the way `coins`/`kibble` already are (check `MergeBoardViewModel`'s existing pattern for a top-level `GameState`-backed `var` — likely just add `var passUnlockedEventIDs: Set<String> = []` alongside `eventProgress` and wire it into `apply(_:)`/snapshot capture the same way).

### 3.3 — IAP product

Add to `IAPProduct` (`AnimalSpecies.swift`):

```swift
case eventPass = "com.pawsanctuary.eventpass"
```

- `displayName`: `"Event Pass"` — deliberately not "Season Pass" or anything containing "Sanctuary," per §0.
- `icon`: pick something distinct from `sanctuaryPass`'s `"medal.fill"` — e.g. `"star.circle.fill"`.
- `kibbleAmount`/`dogTagAmount`/`isSubscription`: all fall through to their existing `default`/`false` cases — this product's only effect is unlocking a lane, not a direct currency grant (the paid-lane *rewards* are what pay out, via the existing claim path).
- Add the product to `PawSanctuary.storekit` (`consumableIAPProducts` — this is a one-time-per-event purchase, structurally closer to the existing consumable packs than to `sanctuaryPass`'s auto-renewing subscription entry, since it doesn't renew and isn't tied to a subscription group). Suggested `displayPrice`: `"4.99"` — no model behind this number, matching every other placeholder price already in the file; the design authority should confirm before this is a real listing.

`MergeBoardViewModel.applyPurchase(_:priceUSD:)` — add:

```swift
if product == .eventPass, let eventID = activeEvent?.id {
    passUnlockedEventIDs.insert(eventID)
}
```

Guarding on `activeEvent` (not a hardcoded track ID) means the purchase always unlocks whichever event is live at the moment of purchase — correct under the current single-active-event model (§0), and it's the one place that assumption is actually convenient rather than a liability.

**Not filtered into the generic shop list as a purchase source** — see §3.5. `ShopView`'s existing `iap.energyPackContents != nil { EmptyView() } else { ... }` guard (`ShopView.swift:441`) needs a matching exclusion (`iap.energyPackContents != nil || iap == .eventPass`) so it doesn't render context-free in the general product list; a "$4.99 to unlock the Pass" tile with no visible event or milestones behind it is confusing outside the event sheet, and if no pass-type event is active the purchase would have nothing to attach to (`activeEvent?.id` would be `nil` and `applyPurchase` would silently no-op — flag this as the reason the storefront must not offer it out of context, not just a UX nicety).

### 3.4 — Claim path: generalize past "free lane only"

`MergeBoardViewModel.claimMilestoneTrack(trackID:milestone:)` (`MergeBoardViewModel.swift`, added by Milestone track) is hardcoded to `paidLane: false` — its own doc comment says *"Free lane only — a pure milestone track has no paid lane; that's the Pass event type's differentiator."* That differentiator is this task. Rename/extend it:

```swift
func claimTrackMilestone(trackID: String, milestone: Int, paidLane: Bool) {
    if paidLane {
        guard passUnlockedEventIDs.contains(trackID) else { return }
    }
    let rewards = progressTrack.claim(trackID: trackID, milestone: milestone, paidLane: paidLane)
    guard !rewards.isEmpty else { return }
    applyRewards(rewards)
    persist()
}
```

The `passUnlockedEventIDs` guard is defense-in-depth — `EventPanelView` (§3.5) shouldn't offer a paid-lane claim button before purchase, but nothing stops a second call path from trying, and `ProgressTrack.claim` itself has no concept of "unlocked," only "claimed" (§0 of the Milestone spec already established the paid/free split lives in the primitive; *whether* the paid lane is even available is state the primitive doesn't own — same design as `claimable(trackID:paidLaneUnlocked:)` taking that as a caller-supplied `Bool` rather than tracking it itself).

Update `MilestoneRowView`'s existing call site (`EventPanelView.swift:203`) to `viewModel.claimTrackMilestone(trackID: event.id, milestone: milestone.index, paidLane: false)` — no behavior change for the Milestone track.

### 3.5 — UI: paid lane in `EventSheetView`/`MilestoneRowView`

`hasPaidLane` — derive from data, don't add a parallel `EventDefinition` field that could drift from it: `ProgressTrackRegistry.tracks[event.id]?.contains { !$0.paidRewards.isEmpty } ?? false`. Put this as a computed property on `EventSheetView` (mirrors how `milestones` is already computed there) and thread it down to `MilestoneRowView`.

When `hasPaidLane`:
- If `!viewModel.passUnlockedEventIDs.contains(event.id)`: render a locked paid-lane column next to the free one — reward pills dimmed/greyed (reuse `rewardPill`, wrapped in `.opacity(0.4)` or similar — don't invent a second rendering path for the same pill), with a lock icon, **and** a single purchase CTA for the whole event (not per-row — buying unlocks every milestone's paid lane, present and future, per `ProgressTrack.claimable`'s existing "past thresholds count too" behavior). Suggested placement: one button in `EventSheetView`'s `header` or as its own section above `milestonesSection`, not per-row, since per-row would visually suggest N separate purchases. Wire it to `Task { await storeManager.purchase(...) }` the same way `ShopView.swift:464` does — needs `storeManager` threaded into `EventSheetView`'s init (it currently only takes `viewModel`/`event`; check `MergeBoardView.swift:649-650`'s call site for how `storeManager` is already available in that scope to pass down).
- If unlocked: paid-lane column renders live, same claim/claimed/progress states as the free column, calling `claimTrackMilestone(trackID:milestone:paidLane: true)`.

When `!hasPaidLane` (i.e., a Milestone-track-type event): render exactly as today — single column, no lock icon, no purchase CTA. This is the existing `adoption_drive_aug2026` behavior and must not change.

**Reward pill for a paid lane richer than kibble/dog tags** — §4's paid rewards include a card pack (see below), which `rewardPill`'s `switch` doesn't have a case for beyond its `default: "+\(amount)"` fallback. Add a `.cardPack` case rendering the pack's name (check `CardPackType`'s existing display-name accessor, likely already used in `CardSystem.swift`/`ShopView.swift` — don't invent a new label for a type that already has one).

### 3.6 — Test event content

`ProgressTrackRegistry.tracks` (`LiveOpsEngine.swift`) needs a real entry — see §5.

---

## 4. First-cut numbers — flag before trusting

Same posture as the Milestone track's §4: **no economy model was run for these.** Derived by scaling the Milestone track's own first-cut numbers (rider frequency 0.33, 20 tokens/rider — unchanged, reused via §3.1's generalized provider) across a 30-day window instead of a 3–4 day one, then choosing a milestone count that reads as a season pass rather than three checkpoints. Re-derive if the pacing feels wrong in play — nothing downstream depends on the exact figures the way Phase 2c's coin-channel derivation was load-bearing.

- **Rider frequency / tokens per rider:** unchanged from the Milestone track (0.33, 20) — same rider mechanism, reused via §3.1.
- **Milestone count:** 10, evenly stepped — a genre-standard pass has more checkpoints than a 3-day event's 3.
- **Thresholds:** 60 / 120 / 180 / 240 / 300 / 360 / 420 / 480 / 540 / 600 tokens (linear steps of 60, matching the Milestone track's per-milestone granularity rather than inventing a new curve).
- **Free-lane rewards:** modest, escalating — kibble-only for the first few, small dog-tag amounts folded in from milestone 4 onward. Roughly:  25/40/50/60/75/90/100/120/140/160 kibble, plus dog tags starting at milestone 4 (3/4/5/6/8 for milestones 4–10 — not 6–10, recount before implementing) so the free lane alone stays a reasonable value even for a player who never buys the pass, matching D6/D7's "generous free tier" posture already adopted elsewhere in the plan.
- **Paid-lane rewards:** meaningfully richer, not just 2×, to make the purchase legible — kibble roughly 2–2.5× the free amount at each tier, dog tags from milestone 1 (not gated to 4+ the way free is), and one `.cardPack` reward at the final milestone (milestone 10) as the "hero" reward, using whichever `CardPackType` is already the mid-tier option (check `CardPackType`'s cases — don't introduce a new pack tier for this).

**This entire table is a placeholder for the design authority to replace, not a designed pass.** It exists so the flow is screen-verifiable; treat the exact reward mix as provisional the same way Milestone track's §4 numbers were.

---

## 5. Task — one screen-verifiable test event

Add a fresh `EventDefinition` to `EventRegistry.allEvents` — **do not** extend `adoption_drive_aug2026` (leave it as-is, historical, per the Milestone spec's own precedent of not overloading old events). Per §0's concurrency workaround: start date **2026-08-06** (the day after `adoption_drive_aug2026` ends), end date 30 days later (**2026-09-05**), matching D5's continuous-track cadence. `ProgressTrackRegistry.tracks[thisEvent.id] = [the 10 TrackMilestones from §4]`.

This is test-only content to prove the two-lane flow end to end — not 6c's real rolling calendar.

---

## 6. Acceptance

- [ ] `EventTokenRiderProvider` (renamed from `MilestoneTrackRiderProvider`) compiles and is used by both the existing Milestone track event and this task's test event with no change to either's observed behavior
- [ ] `GameState` v30 → v31: `passUnlockedEventIDs: Set<String>` added, additive, defaults to `[]`; migration test for a v30 save loading with the new field empty
- [ ] `IAPProduct.eventPass` added, present in `PawSanctuary.storekit`, purchasable in a local StoreKit-testing run
- [ ] Purchasing Event Pass while the test event is active inserts its ID into `passUnlockedEventIDs`; purchasing with no active event is a safe no-op (verify — don't just assume `activeEvent == nil` guards cleanly)
- [ ] Before purchase: `EventSheetView` shows a locked/dimmed paid-lane column and one purchase CTA; free lane claims normally
- [ ] After purchase: paid-lane rewards for **already-reached** milestones become claimable immediately (not just future ones) — this is `ProgressTrack.claimable`'s existing retroactive behavior; verify it actually surfaces in the UI, don't just trust the primitive
- [ ] Claiming a paid-lane milestone before purchase is rejected (via the `passUnlockedEventIDs` guard in `claimTrackMilestone`), even if called directly
- [ ] A Milestone-type event (no `paidRewards` anywhere in its track) renders with zero paid-lane UI — `hasPaidLane` correctly reads `false`
- [ ] Full test suite green
- [ ] Verified on screen: locked paid lane, purchase flow (sandbox/StoreKit-testing), unlocked paid lane claim, retroactive unlock of an already-passed milestone's paid reward

---

## 7. Out of scope

- **Generalizing `EventRegistry.currentEvent`/`activeEvent` to support truly concurrent events** — flagged prominently in §0 as a real gap D5 will eventually require, deliberately not fixed here. Raise before 6c.
- D8 / chain-offer variant — the Alignment Plan describes it as built on top of this task's Pass primitive, not part of it
- Parallel board — separate 6b task, "highest revenue, most expensive"
- Full 90-day rolling calendar — Phase 6c
- Re-deriving §4's numbers against a real model
- A player-facing name other than "Event Pass" — placeholder chosen only to avoid the `sanctuaryPass` collision (§0); final copy is a design-authority call
- Refunds/revocation handling for `IAPProduct.eventPass` (e.g. `Transaction.currentEntitlements`/`revocationDate` bookkeeping) — `sanctuaryPass` has some of this via its subscription-renewal path in `StoreManager`; a consumable one-time unlock doesn't have an equivalent StoreKit revocation flow to hook, and none of the other consumable IAPs (kibble/dog-tag packs) handle revocation either, so this matches existing precedent rather than being a gap unique to this task
