# PawSanctuary — Phase 6a: Live-ops primitives

**Self-contained brief.** Assumes no prior conversation. Follows Phase 5 (commit `022cf99`).

> **Not atomic.** Each primitive is independently useful and independently testable — land them as separate commits, in the order below. Do not batch. Stop after any one if something resists; the others don't depend on it.

**DRAFT — written by Claude Code from the existing protocol stubs and the Alignment Plan, not yet reviewed by the design-authority chat.** Numbers, scope cuts and the "out of scope" list below are proposals, not decisions. Read `specs/PawSanctuary_Alignment_Plan.md` §3 (D5, D8) and §9 before approving.

---

## 0. Why

`PawSanctuary/LiveOpsPrimitives.swift` (Phase 1, Task 1.5, commit `31e33a3`) declared eight protocols and two value types — no conformances, nothing registered, nothing calling them. It exists so Phase 6 has a target. This is that phase, part a.

`Merge2_Reference_Blueprint.md` §26: *"Given a lean meta, live-ops is the retention strategy. Build primitives, express events as configuration."* The reference games run their entire event catalogue — timed orders, daily challenges, milestone tracks, parallel boards, passes, card albums — off the same eight primitives. Today PawSanctuary has one hardcoded event (`EventSystem.swift`'s `EventDefinition`/`EventProgress`, singular, not primitive-backed) and it expired 2026-06-15.

D5 (Alignment Plan §3) capped the target cadence at roughly one 3–4 day event/week + one continuously-running 30-day track + auto-generated dailies — not the reference games' four-plus concurrent events. The scheduler and wallet still need to handle real overlap (a weekly event landing mid-pass, a daily challenge active throughout both), just not at reference-game density.

**Scope cut for 6a specifically:** build the six primitives that are pure logic/state (scheduler, token wallet, progress track, reward table, timer service, offer hook) as generic, event-ID-keyed, unit-testable types with **zero UI call sites** — same posture as Phase 1.5, just with real implementations behind the protocols instead of empty ones. Do **not** rewire the existing `EventSystem`/`EventProgress`/the on-screen event card onto them yet, and do **not** build `ParallelBoardHosting` for real. Both of those are 6b's job: 6b's "Milestone track" task is what finally retires the hardcoded single-event model, and 6b's "Parallel board" task is explicitly called out in the Alignment Plan as "highest revenue, most expensive; the one worth the effort" — too large to fold in here. `ParallelBoardHosting` gets a minimal conformance in 6a (task 7 below) just so the file compiles with real types everywhere else; its actual board-hosting logic is out of scope.

---

## 1. Decisions this depends on (already made — do not relitigate)

- **D5 (cadence):** ~1 weekly event + 1 continuous 30-day track + dailies. This is why the scheduler needs real overlap/priority resolution (two-plus concurrent is the normal case) but not six-way resolution.
- **D8 (chain offer):** blocks 6b scope, not 6a. Nothing here depends on it.

---

## 2. Task — Scheduler (`EventScheduling`)

Add `EventScheduler: EventScheduling`, `@MainActor`, no persisted state — it derives everything from `EventRegistry.allEvents` (or an injected list, for testing) plus the query date/level.

```swift
protocol EventScheduling {
    func activeEvents(at date: Date) -> [String]
    func isEligible(eventID: String, playerLevel: Int) -> Bool
    func priority(for eventID: String) -> Int
}
```

- `activeEvents(at:)` — every `EventDefinition` where `date` falls in `[startDate, endDate)`. Already-computable from `EventDefinition.isActive`; the scheduler's job is doing it across the *list*, sorted, not one event in isolation.
- `isEligible` needs a `minLevel: Int` field added to `EventDefinition` (defaults to `0` for the existing `rescue_rush_jun2026` entry — no migration needed, `EventDefinition` isn't persisted).
- `priority` needs a `priority: Int` field added to `EventDefinition` (higher wins a contested slot; default `0`, ties broken by earliest `startDate`).
- **Overlap resolution:** add `func contestedSlotWinner(at date: Date) -> String?` — the single highest-priority *eligible* active event, or `nil` if none. This is the one thing a scheduler actually needs to decide that a plain filter doesn't: which event gets the primary banner when two are both live.

**Test:** three synthetic `EventDefinition`s with overlapping date ranges and distinct priorities; assert `activeEvents` returns all overlapping ones and `contestedSlotWinner` returns the highest-priority eligible one, correctly excluding one that fails `isEligible`.

---

## 3. Task — Token wallet (`TokenWalleting`)

Real currencies now exist to spend: `RewardKind.eventToken` (added Phase 1) already carries `payloadID` as the token identifier. Nothing credits or reads it yet.

Add to `GameState` (schema v29 → v30, additive, no data loss on old saves):

```swift
var eventTokenWallets: [String: Int] = [:]   // token ID -> balance
```

Add `TokenWallet: TokenWalleting`, `@MainActor @Observable`, backed by a closure or weak reference into `GameState`/`MergeBoardViewModel` (match the existing pattern other coordinators use to read/write through the view model rather than owning storage directly — see how `KibbleEngine` is wired).

```swift
protocol TokenWalleting {
    func balance(_ token: String) -> Int
    func credit(_ token: String, _ amount: Int)
    func debit(_ token: String, _ amount: Int) -> Bool   // false + no-op if insufficient
    func purge(tokensFor eventID: String)
}
```

- `debit` never goes negative — returns `false` and leaves the balance untouched if `amount > balance(token)`.
- `purge(tokensFor:)` removes the dictionary entry for that token ID entirely (not just zeroes it) — matches how an expired event's currency should stop existing, not linger as a visible `0`.
- **Open question, flag rather than guess:** is a token ID always == an event ID (one currency per event), or can one event grant a token another event also uses? The protocol takes a bare `token: String` either way, so nothing here forces an answer — just don't assume 1:1 when wiring a real event to it in 6b.

**Test:** credit/debit round-trip, debit-below-zero rejected and balance unchanged, purge removes the key (assert `balance(token) == 0` is not sufficient — assert the key is gone, e.g. via a `hasWallet(_:)` test-only accessor or by checking `eventTokenWallets.keys`), and a `PersistenceTests` case for the new field surviving save/load on both a fresh v30 save and a migrated v29→v30 one (defaults to `[:]`).

---

## 4. Task — Progress track (`ProgressTracking`)

Add to `GameState` (same v30 migration as §3):

```swift
struct TrackState: Codable, Equatable {
    var progress: Int = 0
    var claimedFree: [Int] = []
    var claimedPaid: [Int] = []
}
var progressTracks: [String: TrackState] = [:]   // track ID -> state
```

Add `ProgressTrack: ProgressTracking`, `@MainActor @Observable`, plus a static registry of `[String: [TrackMilestone]]` (track ID → its ordered milestone list) analogous to `EventRegistry` — call it `ProgressTrackRegistry`, empty for now (no track is defined until 6b builds one).

```swift
protocol ProgressTracking {
    func progress(trackID: String) -> Int
    func advance(trackID: String, by amount: Int)
    func claimable(trackID: String, paidLaneUnlocked: Bool) -> [TrackMilestone]
    func claim(trackID: String, milestone: Int, paidLane: Bool) -> [OrderReward]
}
```

- `advance` creates the `TrackState` entry on first use (default `TrackState()`), same lazy-init pattern as `eventProgress` today.
- `claimable` returns every `TrackMilestone` whose `threshold <= progress(trackID)` and isn't already in the relevant claimed list — `claimedFree` when `paidLaneUnlocked == false` is irrelevant to filtering (free-lane milestones are always claimable once reached regardless of paid status; paid-lane milestones only appear when `paidLaneUnlocked == true`).
- `claim` appends the milestone index to the correct lane's claimed list (idempotent — claiming twice returns `[]` the second time, not the same rewards again) and returns that milestone's `freeRewards` or `paidRewards`.

**Test:** advance past a threshold makes it claimable; claim returns the right lane's rewards and is idempotent; a paid-lane milestone is invisible to `claimable` when `paidLaneUnlocked == false` even past threshold; `PersistenceTests` round-trip for `progressTracks` including a v29→v30 migration case.

---

## 5. Task — Reward table (`RewardTabling`)

Static-data primitive, no persisted state (rolls are consumed immediately by the caller, same as `SubObjectSystem`'s existing rarity roll — nothing about *which* roll happened needs to survive a save).

```swift
protocol RewardTabling {
    func roll(tableID: String) -> [OrderReward]
    func table(_ id: String) -> [WeightedReward]
}
```

Add `RewardTableRegistry: RewardTabling`, a `@MainActor enum` (matches `OrderRewardRegistry`'s existing shape) wrapping `static let tables: [String: [WeightedReward]]` — empty dictionary for now, same "no content authored yet, machinery only" posture as `ChainCategory.currency` in Phase 1.3.

- `roll(tableID:)` — weighted-random pick from `table(tableID)` using the existing codebase convention (`Double.random(in:)`, not an injected RNG — see `SubObjectSystem.swift` for the pattern to match). Empty table → `[]`, not a crash.
- `table(_:)` — dictionary lookup, `[]` if the ID isn't registered.

**Test:** with a synthetic table of known weights, roll it a large number of times (matching the statistical-tolerance style already used for `SubObjectSystem`'s rarity tests, if one exists — check `SubObjectSystemTests`-equivalent coverage before inventing a new tolerance convention) and assert each entry's observed frequency is within tolerance of `weight / totalWeight`. Also assert an unregistered table ID rolls `[]` rather than trapping.

**Not machinery-only in the way §5's framing above suggests — there's already a real, waiting consumer.** `Spec_Phase2_Economy.md` §3b (chests) explicitly deferred this: *"if no chest reward table exists yet, add the payload type and wire one chest source; a full table is Phase 6."* Today's weekly/monthly chest payout (`MergeBoardViewModel.swift`, "Recirculation (Task 2.3b)") is a hardcoded tier-offset formula, not a table — it's the natural first thing to migrate onto `RewardTableRegistry` once one exists. Not in scope for 6a itself (that would pull chest behaviour change into a phase whose acceptance criteria require zero observable change on screen), but 6b — or a small dedicated follow-up — should convert it rather than authoring a first table from scratch.

---

## 6. Task — Timer service (`EventTiming`)

Thin wrapper — `EventDefinition` already computes `timeRemaining`/`isUrgent`; this primitive's actual job is the notification half, which nothing currently does for events (only for orders, via `NotificationManager.scheduleOrderExpiry`).

```swift
protocol EventTiming {
    func remaining(eventID: String) -> TimeInterval
    func isUrgent(eventID: String) -> Bool
    func scheduleExpiryNotification(eventID: String, at date: Date)
}
```

- `remaining`/`isUrgent` — look up the event in `EventRegistry.allEvents` and delegate to its existing computed properties. `0`/`false` if the ID isn't found (don't trap on an unknown event — a stale notification firing after an event was removed from the registry is a real scenario, not a bug to crash on).
- `scheduleExpiryNotification(eventID:at:)` — add `NotificationManager.scheduleEventExpiry(eventID: String, at date: Date, summary: String)`, mirroring the existing `scheduleOrderExpiry(orderID:timeRemaining:summary:)` (same identifier-prefixing and cancellation convention — check how `scheduleOrderExpiry`/`cancel(ids:)` key their identifiers so event notifications don't collide with order ones). The protocol method itself doesn't take a `summary`; resolve it from `EventRegistry` (event's `name`/`tagline`) inside the conforming type.

**Test:** `remaining`/`isUrgent` against a synthetic past/future/current event; unknown ID returns `0`/`false` without trapping. Notification scheduling itself isn't unit-testable (no `UNUserNotificationCenter` in the test target today, per `TODO.md`'s Push Notifications capability blocker) — code-review-level confidence is acceptable here, same standard already applied to `checkLevelUnlock`'s unlock-reveal path in Phase 4.2.

---

## 7. Task — Offer hook (`OfferHooking`) and Parallel board stub (`ParallelBoardHosting`)

**Offer hook** — in-memory only, `@MainActor`, same registration-list shape as `OrderRewardRegistry` (Phase 1.2). Not persisted: an active event re-registers its offers on every launch while it's live; there's nothing to survive a save that isn't already reconstructible from "which events are currently active."

```swift
protocol OfferHooking {
    func registerOffer(eventID: String, offerID: String)
    func activeOffers() -> [String]
}
```

`OfferHookRegistry: OfferHooking`, storing `[eventID: [offerID]]`; `activeOffers()` flattens it. Add an `unregister(offersFor eventID: String)` alongside (not in the protocol, but needed internally — same asymmetry the existing `OrderRewardRegistry` doesn't have but this one will, since offers are keyed per-event and need cleanup on expiry the way `TokenWalleting.purge` does).

**Parallel board — stub only, per §0's scope cut:**

```swift
protocol ParallelBoardHosting {
    func makeBoard(eventID: String) -> UUID
    func teardownBoard(eventID: String)
    func energyBalance(eventID: String) -> Int
}
```

Minimal in-memory conformance: `makeBoard` generates and tracks a `UUID` keyed by `eventID` (no actual `[[BoardCell]]`, no chains, no energy regen — `energyBalance` returns `0` always). This exists only so the file has a real type for every protocol, matching the other seven; it is **not** the Phase 6b "Parallel board" event type, which needs its own board grid, its own energy system, and its own spec. Say so explicitly in the doc comment so nobody mistakes this stub for done work.

**Test:** offer hook register/unregister/`activeOffers()`; parallel board stub's `makeBoard` returns a stable UUID for repeated calls with the same `eventID` and a fresh one for a different `eventID`, `teardownBoard` removes it.

---

## 8. Acceptance

- [ ] All eight protocols in `LiveOpsPrimitives.swift` have a real conforming type (six full implementations, one stub explicitly documented as a stub)
- [ ] `GameState` v29 → v30: `eventTokenWallets: [String: Int]` and `progressTracks: [String: TrackState]` added, additive, default `[:]`
- [ ] Migration test: a v29 save loads with both new fields defaulting to empty
- [ ] Unit tests per primitive per the sections above — scheduler overlap/priority, wallet credit/debit/purge, track advance/claim/idempotency/lane-gating, reward table statistical distribution + unknown-ID safety, timer remaining/urgent/unknown-ID safety, offer hook register/unregister, parallel-board-stub UUID stability
- [ ] Zero new UI call sites — `EventSystem.swift`, `MergeBoardView.swift`, and the on-screen event card are untouched
- [ ] Full test suite green (132 existing + new)
- [ ] Game builds and runs identically to Phase 5's end state — nothing observable changes on screen

---

## 9. Out of scope

- Rewiring `EventSystem`/`EventProgress`/the existing event card onto these primitives — Phase 6b, "Milestone track"
- A real `ParallelBoardHosting` implementation (actual board grid, chains, energy) — Phase 6b, "Parallel board"
- Any authored content in `EventRegistry`, `ProgressTrackRegistry`, or `RewardTableRegistry` — machinery only, same posture as Phase 1.3's empty `ChainCategory.currency`. Content is Phase 6c (calendar) and 6b (event types).
- Migrating the existing weekly/monthly chest payout (`MergeBoardViewModel.swift`, Task 2.3b) onto `RewardTableRegistry` — flagged in §5 as the natural first real table, but changing chest behavior isn't compatible with this phase's "zero observable change" acceptance bar. Belongs to 6b or a small dedicated follow-up.
- Pass (free/paid lane UI, purchase-progress promotion), chain-offer variant (D8), milestone track UI — all Phase 6b
- Deciding whether a token ID is always 1:1 with an event ID — flagged as an open question in §3, not resolved here
- `RescueStage`/quest-tier mismatch (`TODO.md`, unrelated pre-existing defect)
- Anything in Phase 7
