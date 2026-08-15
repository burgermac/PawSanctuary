# PawSanctuary — Phase 6b: Milestone track (first event type)

**Self-contained brief.** Assumes no prior conversation. Follows Phase 6a (commits `7580cf9`…`79a76c3`, merged to `main` at `a77db63`).

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

**IMPLEMENTED** (commits `486973c`…`efd5402`, 169/169 tests green, verified end-to-end on the simulator). Written cold by Claude Code, approved in-session. Numbers in §4 are still a first cut, not derived from a model — re-derive if the pacing feels wrong in play.

---

## 0. Why

`EventSystem.swift` today is a single bespoke event type: `EventProgress` (one global instance, keyed by `eventId`, single-lane `claimedMilestones: [Int]`) and `EventMilestone` (hardcoded `kibbleReward`/`dogTagsReward: Int` fields). It's driven by a special case in `MergeBoardViewModel.earnCoins` — `trackEventCoins` — that counts **every coin earned from any source** toward the active event, with no way to differentiate order fulfillment, selling, quests, or anything else.

Per the Alignment Plan (§9, 6b) and the Blueprint (§26): *"Milestone track (uses progress track + riders only — cheapest)."* That phrasing is specific — it means reusing two things that already exist and are currently unused in production:

- **`ProgressTrack`** (Phase 6a, `LiveOpsEngine.swift`) — generic, track-ID-keyed, free/paid lanes, zero UI call sites so far.
- **Rider injection** (`OrderRewardRegistry`, Phase 1.2) — lets an active system attach extra rewards to newly-generated orders. Declared complete since 27 July, **zero providers have ever registered**.

Doing this properly is a **faucet change, not just a refactor**: instead of "count all coins," the milestone track earns its own currency (`RewardKind.eventToken`, added Phase 1.1, `payloadID` = token identifier, also never actually used) via a rider attached to a fraction of orders — the same pattern Phase 2's `.boardItem` recirculation rider and Phase 5.3's `.material` rider already established. This is why "riders" is named specifically in the plan rather than "hook into `earnCoins` again."

**Flag, not relitigate:** this changes what the track responds to. Today, opening the shop and selling inventory advances the event same as fulfilling orders. After this change, only orders carrying the rider do. That's the design the plan calls for — say so explicitly here in case it wasn't the intent.

---

## 1. Decisions this depends on

- **D5 (cadence):** one 3–4 day event per week. The only `EventDefinition` on record (`rescue_rush_jun2026`) ran 14 days — outside that window. Not this task's job to fix content authoring (that's §6/6c), but the test event added in §5 should run 3–4 days to match D5, not copy the old 14-day span.
- **D8 (chain offer):** does not block *this task* in either direction — it's scoped to the *Pass* event type instead, a separate 6b task, and Milestone track neither gates it nor is gated by it. A blocking dependency does exist, just not between D8 and Milestone track, and not in the direction this doc originally implied: the Alignment Plan's D8 entry recommends building it "as a variant of the Pass primitive," meaning **D8 depends on Pass**, not the reverse — Pass's own spec (§1) confirms this explicitly ("a follow-on to this task, not a prerequisite"), and the Alignment Plan's own D8 entry now says so directly too ("D8 is blocked on Pass, not the reverse"). Corrected here (15 Aug 2026) after the original "it only gates the Pass event type" phrasing was found to assert the dependency backwards.

---

## 2. Target shape

| Today | Target |
|---|---|
| `EventProgress` (persisted, single global, single-lane) | `GameState.progressTracks[event.id]` via `ProgressTrack.advance`/`claim` (already exists, Phase 6a) — free lane only, no paid lane for a pure milestone track |
| `EventMilestone` (hardcoded `kibbleReward`/`dogTagsReward: Int`) | `TrackMilestone` (already exists: `index`, `threshold`, `freeRewards: [OrderReward]`, `paidRewards: []`) |
| `trackEventCoins` hooked into `earnCoins` (counts everything) | A rider provider attaches `.eventToken` to a fraction of orders while the event is active; `autoClaimOrder`'s already-stubbed `.eventToken` case (`MergeBoardViewModel.swift:2650`, currently `break`) calls `progressTrack.advance` |
| `claimEventMilestone` grants `kibbleReward`/`dogTagsReward` directly | `progressTrack.claim(...)` returns `[OrderReward]`, applied through the same reward-switch `autoClaimOrder` already has (factor out, don't duplicate) |

---

## 3. Tasks, suggested landing order

### 3.1 — Wire `ProgressTrack` into `MergeBoardViewModel`

Add `let progressTrack = ProgressTrack()` alongside `kibbleEngine`, `inventoryStore`, etc. Add `progressTrack.restore(from: s)` to `apply(_:)` and `progressTrack.capture(into: &s)` to the snapshot builder — same one-line wiring every other coordinator already has. **First real call site for the primitive.** No behavior change yet; this alone should be its own small, easily-verified commit.

### 3.2 — Rider provider + event-lifecycle check

New type (`EventSystem.swift` or a new small file):

```swift
@MainActor
final class MilestoneTrackRiderProvider: OrderRewardProvider {
    let eventID: String
    let tokensPerRider: Int   // §4 — flagged first-cut number
    func riders(playerLevel: Int) -> [OrderReward] {
        Double.random(in: 0..<1) < riderFrequency
            ? [OrderReward(kind: .eventToken, amount: tokensPerRider, payloadID: eventID)]
            : []
    }
}
```

Add `checkEventLifecycle()` to `MergeBoardViewModel`, called once at launch (same style as `checkWeeklyGoalReset()` — see `init()`, `MergeBoardViewModel.swift:714`): if `EventRegistry.currentEvent` differs from whatever's currently registered, `OrderRewardRegistry.unregister` the old provider (if any) and `register` a new one for the new event; register nothing when no event is active. This is intentionally launch-only for a first cut — an event starting *mid-session* on a long-lived app instance won't be picked up until next launch. Flag as a known gap, not silently accepted: real fix is periodic (e.g. folded into the existing per-second tick), deferred here to keep this task's diff small.

### 3.3 — Handle `.eventToken` in `autoClaimOrder`

Replace the `break` at `MergeBoardViewModel.swift:2650`:

```swift
case .eventToken:
    guard let eventID = reward.payloadID else { break }
    progressTrack.advance(trackID: eventID, by: reward.amount)
```

### 3.4 — Claim path + reward application

`ProgressTrackRegistry.tracks` needs a real entry for the live event (§4). Add a `claimMilestoneTrack(trackID:milestone:)` method to `MergeBoardViewModel`:

```swift
func claimMilestoneTrack(trackID: String, milestone: Int) {
    let rewards = progressTrack.claim(trackID: trackID, milestone: milestone, paidLane: false)
    guard !rewards.isEmpty else { return }
    apply(rewards)   // factor autoClaimOrder's reward-kind switch into a shared helper; call it from both sites
    persist()
}
```

Extracting `autoClaimOrder`'s `for reward in order.rewards { switch reward.kind { ... } }` body into a shared `private func apply(_ rewards: [OrderReward])` is in scope here — it's the same switch, and duplicating it for the claim path would immediately drift (see `docs/CODE_HEALTH.md`'s QA-04 precedent for why duplicated branch logic here is worth avoiding from the start rather than fixing later).

### 3.5 — UI: `EventPanelView.swift`

`MilestoneRowView`'s three computed properties (`isClaimed`, `isReached`, `canClaim`) currently read `viewModel.eventProgress`. Repoint at `viewModel.progressTrack.claimable(trackID:, paidLaneUnlocked: false)` / `progress(trackID:)`. The claim button calls `viewModel.claimMilestoneTrack(trackID:, milestone:)` instead of `claimEventMilestone(tier:)`. `progressSection`'s progress bar reads `progressTrack.progress(trackID: event.id)` instead of `eventProgress.coinsEarned`.

Reward display currently assumes exactly `kibbleReward`/`dogTagsReward` — since a `TrackMilestone`'s `freeRewards` is a `[OrderReward]` list (Phase 1's whole point), render it as a small loop over reward kinds instead, matching however order-reward pills are already rendered elsewhere (check `PanelViews.swift`'s existing `[OrderReward]` rendering — don't invent a second convention).

### 3.6 — `eventProgress`/`EventProgress`: leave inert, don't migrate

Once nothing writes to it, `eventProgress`/`EventProgress` becomes dead weight in `GameState` — but removing a persisted field is a **structural** migration (see `docs/GameStore.swift`'s v24→v25 precedent for `AdoptionOrder`'s old reward fields). That risk isn't worth it for a field that's simply unused going forward. Leave the struct and the persisted field in place, stop writing to it, delete it in a dedicated cleanup pass later if ever. Flagging so this isn't mistaken for an oversight.

---

## 4. First-cut numbers — flag before trusting

No economy model was run for these (unlike Phase 2c's coin-channel derivation). Reasonable starting points, not measured:

- **Rider frequency:** 1 in 3 orders (`riderFrequency = 0.33`) — matches Phase 2's `.boardItem` recirculation rider frequency, the closest existing precedent for "a fraction of orders carry a bonus payload."
- **Tokens per rider:** 20.
- **Milestone thresholds:** 3 milestones at 60 / 140 / 220 tokens (roughly matching `rescue_rush_jun2026`'s 200/450/700-coin spacing, scaled down since fewer orders will carry a rider than earned coins generally).
- **Rewards per milestone:** keep parity with the existing definition's kibble/dog-tag amounts (50/75/150 kibble, 0/3/8 dog tags), expressed as `freeRewards: [OrderReward]` instead of hardcoded fields.

**Change the anchor (rider frequency or tokens-per-rider) and re-derive the thresholds together** if these feel wrong once played — they're not load-bearing on anything else the way Phase 2c's coin figures were.

---

## 5. Task — one screen-verifiable test event

Add a fresh `EventDefinition` (don't extend the expired `rescue_rush_jun2026` — leave it as a historical record) with dates spanning the verification window, 3–4 days per D5. `ProgressTrackRegistry.tracks[thisEvent.id] = [the three TrackMilestones from §4]`. This is test-only content to prove the flow on screen — not the real 6c rolling calendar, which authors many events at once against a real schedule.

---

## 6. Acceptance

- [ ] `ProgressTrack` wired into `MergeBoardViewModel` with restore/capture, verified via a save/load round-trip
- [ ] While the test event is active, roughly 1 in 3 newly-generated orders carry an `.eventToken` rider (spot-check via debug logging or a test, not just visual sampling)
- [ ] Fulfilling such an order advances the track; fulfilling one without the rider doesn't
- [ ] `EventPanelView` renders progress and milestones from `progressTrack`, not `eventProgress`
- [ ] Claiming a milestone grants its `freeRewards` through the shared reward-application helper (no duplicated switch)
- [ ] No event active -> no rider registered, no crash, panel simply doesn't offer an event (existing `activeEvent == nil` gating, unchanged)
- [ ] Full test suite green
- [ ] Verified on screen: an order with the rider, event coin count increasing on fulfillment, a milestone claim

---

## 7. Out of scope

- Pass (free + paid lanes) — separate 6b task
- Parallel board — separate 6b task, "highest revenue, most expensive"
- D8 / chain-offer variant
- Full 90-day rolling calendar — Phase 6c
- `EventScheduler`'s overlap/priority resolution — only one event exists or is planned right now; `contestedSlotWinner` has no real caller yet and doesn't need one until two events can genuinely overlap
- Mid-session event start/end detection — `checkEventLifecycle()` is launch-only, flagged as a known gap in §3.2
- Removing `EventProgress`/`eventProgress` from `GameState` — left inert per §3.6
- Re-deriving §4's numbers against a real model
