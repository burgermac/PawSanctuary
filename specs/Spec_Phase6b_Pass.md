# PawSanctuary — Phase 6b: Pass, free + paid lanes (second event type)

**Self-contained brief.** Assumes no prior conversation. Follows the Milestone track (commits `486973c`…`efd5402`, merged to `main` at `afd2b02`).

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

**Written cold by Claude Code; implemented (`92bdfae`…`064cd02`, merged `ef1d080`) and since design-reviewed against the shipped code (15 Aug 2026, see `specs/PawSanctuary_Alignment_Plan.md` §9's Pass line for the outcome).** Per the Alignment Plan's working method (§2), specs are supposed to originate in the design conversation and be handed to Claude Code to implement. No such spec existed for this task, so this one was drafted directly in the implementation session at the user's request. **A technical-accuracy pass was done after the first draft** — every file/line reference below was checked against the current source rather than assumed, one real numeric error in §4 was caught and fixed (a dog-tag list with fewer values than its own stated range), and the §5 test-event dates were tightened to close a one-day gap where no event would have been active. **The design-authority review this doc originally said hadn't happened yet has now happened** — it found the implementation faithful to this spec and caught one real bug not in the spec's own scope (a purchase-flow race at event boundaries, fixed in `e124444`). §4's numbers are still exactly what they were — first-cut, not derived from a model — that part of the original caveat stands; only "not yet reviewed" is stale.

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

**Consequence for this task, worked around, not fixed:** the Event Pass test event (§5) cannot run concurrently with the Milestone track's live test event (`adoption_drive_aug2026`, active 2026-08-01 up to but not including 2026-08-05 — `EventDefinition.isActive` is `now >= startDate && now < endDate`). It's scheduled to start exactly 2026-08-05, so the handoff is clean — zero overlap, zero dead gap — and only one event is ever active at a time, same constraint the shipped code already lives under.

---

## 1. Decisions this depends on

- **D5 (cadence):** this task exists because of D5's second clause — the continuous 30-day track. Test event runs 30 days (§5), not 3–4.
- **D8 (chain offer):** does not block this task. D8's variant is described in the Alignment Plan as *"a variant of the Pass primitive"* — i.e., it's a follow-on to this task, not a prerequisite. **Decided 18 Aug 2026** (Alignment Plan §3, D8): adopt, coercive version — still a separate task with no spec of its own yet, unaffected by the decision's timing relative to this one.
- **D3 (Dog Tags buy board items) / D6 (spend-quota dailies):** not directly load-bearing here. D6's Warmth-pillar reasoning is still worth weighing against paid-lane reward *contents* before treating them as final — corrected 15 Aug 2026: this line previously claimed §4 already did that weighing and pointed there, but §4 is a placeholder reward table with no discussion of D6, Warmth, or restraint in it. That weighing hasn't happened yet; it's real remaining work for the design authority, not something already reflected in this spec.

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

`MilestoneTrackRiderProvider` (`EventSystem.swift`) has zero milestone-specific logic in its body — it emits `.eventToken` riders for an `eventID` at some frequency/amount. It was named for its one caller, not because it's milestone-shaped. Rename it to `EventTokenRiderProvider` (keep the same `init(eventID:tokensPerRider:riderFrequency:)` signature — only the type name changes) so the Pass track can reuse it instead of hand-duplicating a second near-identical class. Exactly two type-name references exist in production code — update both:
- `EventSystem.swift`'s declaration and doc comment
- `MergeBoardViewModel.swift:162`, the `activeMilestoneRiderProvider` var's type annotation and doc comment (rename the var too — `activeEventRiderProvider` reads fine), and `MergeBoardViewModel.swift:2945`, the `MilestoneTrackRiderProvider(eventID:)` construction call inside `checkEventLifecycle()`

`PawSanctuaryTests/EventSystemTests.swift` has four references, all inside one test class (`MilestoneTrackRiderProviderTests`, lines 13/16/23/33) — rename the class too (`EventTokenRiderProviderTests`) while updating them.

**Don't touch** `specs/Spec_Phase6b_MilestoneTrack.md` or `specs/PawSanctuary_Alignment_Plan.md` — both reference the old name as historical record of what shipped, same precedent as leaving `rescue_rush_jun2026`/`eventProgress` alone rather than retroactively rewriting closed work.

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

`MergeBoardViewModel` needs read/write access — no new coordinator needed. `eventProgress` is the exact precedent to copy: it's a flat `GameState`-backed property, not owned by a sub-coordinator. Add `var passUnlockedEventIDs: Set<String> = []` alongside `eventProgress` (`MergeBoardViewModel.swift:155`), then wire it the same two places `eventProgress` appears: `passUnlockedEventIDs: passUnlockedEventIDs` in the `GameState(...)` initializer call inside the snapshot builder (alongside `eventProgress: eventProgress`, ~line 884), and `passUnlockedEventIDs = s.passUnlockedEventIDs` as a plain assignment in `apply(_:)` (alongside `eventProgress = s.eventProgress`, ~line 941). No purge on event end — leave it as permanent history, same as `eventTokenWallets`/`progressTracks` already do (nothing purges those either; `TokenWallet.purge(tokensFor:)` exists on the primitive but has zero call sites in production).

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
- If `!viewModel.passUnlockedEventIDs.contains(event.id)`: render a locked paid-lane column next to the free one — reward pills dimmed/greyed (reuse `rewardPill`, wrapped in `.opacity(0.4)` or similar — don't invent a second rendering path for the same pill), with a lock icon, **and** a single purchase CTA for the whole event (not per-row — buying unlocks every milestone's paid lane, present and future, per `ProgressTrack.claimable`'s existing "past thresholds count too" behavior). Suggested placement: one button in `EventSheetView`'s `header` or as its own section above `milestonesSection`, not per-row, since per-row would visually suggest N separate purchases. Wire it to `Task { await storeManager.purchase(...) }` the same way `ShopView.swift:464` does. Add `let storeManager: StoreManager` to `EventSheetView` (`EventPanelView.swift:19-22`, alongside its existing `viewModel`/`event`) and pass it at the one construction site, `MergeBoardView.swift:650` (`EventSheetView(viewModel: viewModel, event: event, storeManager: storeManager)`) — `storeManager` is already a `@State` property on `MergeBoardView` (`MergeBoardView.swift:33`) and is already threaded into sibling sheets the identical way (`ShopView`, `KibbleRefillSheet`), so this is a drop-in, not a new wiring pattern.
- If unlocked: paid-lane column renders live, same claim/claimed/progress states as the free column, calling `claimTrackMilestone(trackID:milestone:paidLane: true)`.

When `!hasPaidLane` (i.e., a Milestone-track-type event): render exactly as today — single column, no lock icon, no purchase CTA. This is the existing `adoption_drive_aug2026` behavior and must not change.

**Reward pill for a paid lane richer than kibble/dog tags** — §4's paid rewards include a card pack (see below), which `rewardPill`'s `switch` doesn't have a case for beyond its `default: "+\(amount)"` fallback. Add a `.cardPack` case: `guard let raw = reward.payloadID, let pack = CardPackType(rawValue: raw) else { break }` then render `pack.displayName` (`CardSystem.swift:89` — `"\(stars)-Star Pack"`, already the label used elsewhere for packs; don't invent a second one).

### 3.6 — Test event content

`ProgressTrackRegistry.tracks` (`LiveOpsEngine.swift`) needs a real entry — see §5.

---

## 4. First-cut numbers — flag before trusting

Same posture as the Milestone track's §4: **no economy model was run for these.** Derived by scaling the Milestone track's own first-cut numbers (rider frequency 0.33, 20 tokens/rider — unchanged, reused via §3.1's generalized provider) across a 30-day window instead of a 3–4 day one, then choosing a milestone count that reads as a season pass rather than three checkpoints. Re-derive if the pacing feels wrong in play — nothing downstream depends on the exact figures the way Phase 2c's coin-channel derivation was load-bearing.

- **Rider frequency / tokens per rider:** unchanged from the Milestone track (0.33, 20) — same rider mechanism, reused via §3.1.
- **Milestone count:** 10, evenly stepped — a genre-standard pass has more checkpoints than a 3-day event's 3.
- **Thresholds:** linear steps of 60 tokens, matching the Milestone track's per-milestone granularity rather than inventing a new curve.

**Sanity check against realistic order volume** (not a model — a bound): Phase 5's economy assumes several order fulfillments/day per engaged player. At the unchanged 0.33 rider frequency × 20 tokens/rider, even a conservative 2–3 fulfillments/day yields roughly 15–20 tokens/day, comfortably clearing 600 tokens well inside 30 days. That's intentional headroom, not a miscalibration — a less consistent player should still be able to finish the free lane, matching D1's "generous supply" posture already adopted for the wall (corrected 15 Aug 2026 — misattributed to D7, which is the session-one monetization decision, not the wall/supply one). If actual play feels too fast or too slow, the anchor to retune is `tokensPerRider`/`riderFrequency`, not the thresholds — same guidance the Milestone track's §4 gave.

**Milestone table** — indices match `TrackMilestone.index` (0-based, matching `ProgressTrackRegistry`'s existing convention). Free-lane dog tags are gated to the back half (index ≥ 3) so the earliest rewards stay kibble-only and simple; paid-lane dog tags run the full pass since the point of paying is a richer lane throughout, not just at the end. Paid kibble is free kibble × ~2.2, rounded. The final milestone's paid reward adds one `.cardPack` (`CardPackType.star4` — the existing mid-upper tier, 4 cards with 1 guaranteed rare per `CardSystem.swift`; not introducing a new pack tier) as the pass's hero reward.

| Index | Threshold | Free kibble | Free dogTags | Paid kibble | Paid dogTags | Paid extra |
|---|---|---|---|---|---|---|
| 0 | 60  | 25  | —  | 55  | 2  | |
| 1 | 120 | 40  | —  | 90  | 3  | |
| 2 | 180 | 50  | —  | 110 | 4  | |
| 3 | 240 | 60  | 3  | 130 | 5  | |
| 4 | 300 | 75  | 4  | 165 | 6  | |
| 5 | 360 | 90  | 5  | 200 | 8  | |
| 6 | 420 | 100 | 6  | 220 | 10 | |
| 7 | 480 | 120 | 8  | 260 | 12 | |
| 8 | 540 | 140 | 10 | 300 | 15 | |
| 9 | 600 | 160 | 15 | 350 | 20 | 1× `.cardPack` (`star4`) |

**This entire table is a placeholder for the design authority to replace, not a designed pass.** It exists so the flow is screen-verifiable; treat the exact reward mix as provisional the same way Milestone track's §4 numbers were.

---

## 5. Task — one screen-verifiable test event

Add a fresh `EventDefinition` to `EventRegistry.allEvents` — **do not** extend `adoption_drive_aug2026` (leave it as-is, historical, per the Milestone spec's own precedent of not overloading old events). Per §0's concurrency workaround: start date **2026-08-05** — the exact instant `adoption_drive_aug2026` goes inactive (`endDate` is exclusive), so the handoff has zero gap and zero overlap — end date 30 days later (**2026-09-04**), matching D5's continuous-track cadence. `ProgressTrackRegistry.tracks[thisEvent.id] = [the 10 TrackMilestones from §4]`.

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
