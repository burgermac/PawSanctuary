# PawSanctuary — Phase 6c prerequisite: concurrent events

**Self-contained brief.** Assumes no prior conversation. Follows Phase 6b (Milestone track, Pass shipped; Parallel board spec-only).

**DRAFT — written cold by Claude Code at the user's request, not yet reviewed by the design authority.** Same exception as Pass's and Parallel board's own drafts (no prior design-authority spec existed for this task).

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

**Status (16 Aug 2026): all of §3 and §4 done. Implementation complete, pending design-authority review of this still-DRAFT spec.** `EventRegistry.activeEvents` added (commit `b023431`), routed through `EventScheduler`. `MergeBoardViewModel.activeEvent` renamed to `activeEvents: [EventDefinition]` (commit `19404b1`). **§3.3 — the load-bearing fix:** `checkEventLifecycle()`'s single `activeEventRiderProvider: EventTokenRiderProvider?` is now `activeEventRiderProviders: [String: EventTokenRiderProvider]`, diffed against `EventRegistry.activeEvents` on every check (commit `ac08fe0`) — two concurrently-active events can each register and keep their own rider, where previously only one could ever hold the slot. **§3.4 — UI wiring:** `TaskSheet.event` gained an associated `String` event ID (dropped `RawRepresentable` for a hand-written `id`/`title`, both exhaustive over the event ID); `TaskStripView`'s single `if let` became `ForEach(viewModel.activeEvents)`, matching the existing quest/daily-challenge `ForEach` pattern in the same strip; `MergeBoardView.swift`'s `routeContent` matches `.task(.event(let eventID))`, looks the ID up in `viewModel.activeEvents`, and dismisses rather than showing a stale sheet if the event ended in the tap-to-presentation gap (commit `908916b`).

**§4 — the overlapping test event (commit pending):** added `foster_weekend_aug2026` to `EventRegistry.allEvents` (`EventSystem.swift`) and a matching free-lane-only 3-milestone table to `ProgressTrackRegistry.tracks` (`LiveOpsEngine.swift`), scheduled 2026-08-14 to 2026-08-18 — inside Founders' Circle's window, genuinely overlapping. Dates deliberately shifted from the spec's original 20–24 Aug proposal to bracket 16 Aug (the date this landed), per the spec's own note to re-verify dates at implementation time, so the overlap is real and verifiable on screen immediately rather than in the future. This required also updating `EventSystemTests.swift`'s `testActiveEventsAgreesWithCurrentEventWhileNoneOverlap` — its premise ("today's real event list never has two events overlap") became false by design; replaced with `testCurrentEventIsAlwaysContainedInActiveEventsWhenNonNil`, a permanent, date-independent structural invariant (whatever `currentEvent` picks must always appear in `activeEvents`) rather than an incidental agreement that depended on array-declaration order and would have been fragile going forward. Verified on screen in the simulator: the task strip shows **two** simultaneous event cards — "Founders' Circle · 0/600 tokens" and "Foster Weekend · 0/150 tokens" — and tapping each opens its own correctly-scoped sheet (Founders' Circle's two-lane paid track vs. Foster Weekend's free-lane-only track, distinct icon/color/copy for each). Order-token rider independence itself (both events' riders firing on the same fulfilled order) wasn't separately exercised on screen this session — it rests on §3.3's diffed-provider logic (unit-tested) plus `OrderRewardRegistry`'s pre-existing `flatMap`-all-providers behavior (also already tested), not a fresh screen check. Full suite verified at 285/285 green, 0 regressions, after all of §3.2/§3.3/§3.4/§4.

Remaining before this spec can be considered fully closed: design-authority review (still DRAFT), and the two §5 acceptance items not directly exercised — the "ending one of the two overlapping events leaves the other unaffected" lifecycle check, and the save/load round-trip check for two simultaneous `progressTracks` entries (both plausible from the code as written, neither freshly verified this session).

---

## 0. Why

D5's cadence commitment is explicit: *"one 3–4 day event per week, one 30-day album/pass running continuously."* Those two run **at the same time** by construction — a continuous 30-day Pass and a rotating weekly event aren't sequential, they overlap every week by design. The app cannot do this today. `EventRegistry.currentEvent` is `allEvents.first { $0.isActive }` — **one event, singular** — and every consumer of it (`MergeBoardViewModel.activeEvent`, `checkEventLifecycle()`, both UI entry points) is built on that single value.

This gap has been flagged three times without being fixed — Milestone track's spec (§7), Pass's spec (§0), and Parallel board's spec (§1), each raising it and each deliberately deferring it. Parallel board's spec said it plainly: *"6c is next. Raise it now, not after a fourth event has to route around it too."* Right now the deferral is free because the three shipped `EventDefinition`s happen to be scheduled back-to-back with zero gap, never overlapping. The real 6c rolling calendar (authoring many events against a real schedule) cannot honor D5's cadence without genuine overlap — a weekly event scheduled *inside* a running Pass's 30-day window is the normal case, not an edge case. This task has to land before 6c's calendar can be authored for real.

**The good news, found while scoping this:** most of the state layer already doesn't assume one event. `GameState.progressTracks`/`eventTokenWallets` are already `[String: _]` dictionaries keyed by event/track ID. `passUnlockedEventIDs` is already a `Set`. `OrderRewardRegistry.providers` is already an array that `flatMap`s across every registered provider. None of that needs to change. The gap is narrower than "add concurrency support" — it's four specific places that pick one winner where the data underneath already supports many.

**Design decision made in scoping this task, not re-litigated here:** when a weekly-cadence event and the continuous Pass are both active, **both render as separate task cards and open separate sheets simultaneously** — not one contested slot won by priority. They're independent reward tracks (different tokens, different progress, different UI), not competitors for the same attention. `EventScheduler.contestedSlotWinner` (Phase 6a, already built, zero real callers) stays reserved for a genuine same-slot conflict — e.g. two weekly-cadence events accidentally double-booked — not the intended weekly+Pass steady state this task targets.

---

## 1. Decisions this depends on

- **D5 (cadence):** this task exists entirely because of D5's "concurrently" clause. Nothing here changes D5's numbers; it makes the app capable of actually running what D5 already specified.
- **D8 (chain offer):** not load-bearing here. If D8 ships later as a Pass variant, it's still just one more event ID flowing through the same generalized path this task builds — no special-casing needed.

---

## 2. Target shape

| Today | Target |
|---|---|
| `EventRegistry.currentEvent: EventDefinition?` — `allEvents.first { $0.isActive }`, arbitrary single winner | `EventRegistry.activeEvents: [EventDefinition]` — backed by `EventScheduler.activeEvents(at:)` (Phase 6a, already returns every currently-active ID), sorted by `priority` desc then `startDate` asc for stable display order |
| `MergeBoardViewModel.activeEvent: EventDefinition?` | `MergeBoardViewModel.activeEvents: [EventDefinition]` — thin wrapper update to match |
| `checkEventLifecycle()` tracks one `activeEventRiderProvider: EventTokenRiderProvider?` | Tracks `activeEventRiderProviders: [String: EventTokenRiderProvider]`, diffed each check: unregister providers for IDs that dropped out of `activeEvents`, register providers for IDs that newly appeared, leave unchanged ones alone. `OrderRewardRegistry` itself needs no change — it already `flatMap`s every registered provider |
| Task strip: `if let event = viewModel.activeEvent { EventTaskCard(...) }` — one card, `PanelViews.swift:1652` | `ForEach(viewModel.activeEvents) { event in EventTaskCard(...) }` — one card per active event, same pattern already used for quests/daily challenges immediately above it in the same strip |
| `TaskSheet.event` — bare case, no associated value (`PanelViews.swift:1110`) | `TaskSheet.event(String)` — carries the tapped card's event ID, since there's no longer one implicit "the" active event to fall back on |
| `MergeBoardView.swift:572`'s `routeContent`: `if let event = viewModel.activeEvent { EventSheetView(...) }` | Looks up the tapped event's ID in `viewModel.activeEvents`, opens that event's sheet specifically |

---

## 3. Tasks, suggested landing order

### 3.1 — `EventRegistry`: single winner → active list

Replace `currentEvent` with:

```swift
static var activeEvents: [EventDefinition] {
    let scheduler = EventScheduler()
    let activeIDs = Set(scheduler.activeEvents(at: Date()))
    return allEvents
        .filter { activeIDs.contains($0.id) }
        .sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.startDate < $1.startDate
        }
}
```

Routes through `EventScheduler` instead of duplicating the `isActive` filter inline — `EventScheduler.activeEvents(at:)` already exists and is already tested (Phase 6a, `Spec_Phase6a_Primitives.md`) against synthetic multi-event overlap; this is its first real caller. No behavior change yet for the current registry (still zero genuinely overlapping events), so this alone is a small, easily-verified commit: same events, same activity, just routed through the scheduler and returned as a list instead of a single optional.

### 3.2 — `MergeBoardViewModel.activeEvent` → `activeEvents`

```swift
var activeEvents: [EventDefinition] { EventRegistry.activeEvents }
```

Update the two UI call sites (§3.4) in the same commit or the next — don't leave `activeEvents` unused between commits if avoidable, per the "keep the game playable" rule; a brief unused-computed-property state between 3.2 and 3.4 is fine if kept to one commit's width.

### 3.3 — `checkEventLifecycle()`: one provider → a diffed set

```swift
private var activeEventRiderProviders: [String: EventTokenRiderProvider] = [:]

func checkEventLifecycle() {
    let currentIDs = Set(EventRegistry.activeEvents.map(\.id))
    let trackedIDs = Set(activeEventRiderProviders.keys)

    for droppedID in trackedIDs.subtracting(currentIDs) {
        if let provider = activeEventRiderProviders.removeValue(forKey: droppedID) {
            OrderRewardRegistry.unregister(provider)
        }
    }
    for newID in currentIDs.subtracting(trackedIDs) {
        let provider = EventTokenRiderProvider(eventID: newID)
        OrderRewardRegistry.register(provider)
        activeEventRiderProviders[newID] = provider
    }
}
```

This is the one genuinely load-bearing fix, not just plumbing: today, if two events were ever simultaneously active, `checkEventLifecycle()` could only ever register a rider for one of them (`activeEventRiderProvider` is a single optional) — the other would silently stop earning tokens from order fulfillment, charged nothing, told nothing, same silent-failure shape as the purchase bug found in Pass's design-authority review earlier. `OrderRewardRegistry` needs zero changes; it already iterates every registered provider.

Still launch-only, same documented gap Milestone track's spec already flagged (§3.2) — an event starting mid-session won't get picked up until next launch or the next explicit `checkEventLifecycle()` call. Not this task's job to fix; not made worse by it either.

### 3.4 — UI: task strip and sheet routing

`PanelViews.swift`:
- `TaskSheet.event` gains an associated value: `case event(String)`. Update `title` to look up the event by ID from `EventRegistry.allEvents` for the sheet's navigation title (fall back to a generic "Active Event" if somehow not found — defensive, shouldn't happen since the ID only ever comes from a currently-active event's own card).
- Task strip (`TaskStripView.body`, ~line 1652): replace the `if let` with `ForEach(viewModel.activeEvents) { event in EventTaskCard(viewModel: viewModel, event: event).onTapGesture { activeSheet = .event(event.id) } }`, matching the `ForEach(viewModel.dailyChallenges)`/`ForEach(viewModel.activeQuests)` pattern immediately above it in the same strip — this task doesn't invent a new list-rendering convention, it reuses the one already there twice.

`MergeBoardView.swift`:
- `routeContent`'s `case .task(.event(let eventID))`: look up `eventID` in `viewModel.activeEvents`, construct `EventSheetView` for that specific event. If the event has since ended between tap and sheet presentation (a real if narrow race — the countdown could hit zero while the sheet is opening), fall back to dismissing rather than presenting a sheet for an event that's no longer active; don't crash or present stale state.

### 3.5 — Migration

**None.** `GameState.progressTracks`, `eventTokenWallets`, and `passUnlockedEventIDs` are already ID-keyed collections (`[String: TrackState]`, `[String: Int]`, `Set<String>`) — every one of them already supports N concurrent events with the schema exactly as it stands today. This entire task is ViewModel and UI wiring; `GameStore.currentVersion` does not move.

---

## 4. Task — one screen-verifiable overlapping test event

No two events in the current registry actually overlap — `rescue_rush_jun2026`, `adoption_drive_aug2026`, and `founders_circle_aug2026` are all sequenced back-to-back with zero gap (confirmed while scoping this task). Unit tests against synthetic `EventScheduler` instances (already exist, Phase 6a) prove the scheduler's own logic, but nothing today proves the full stack — registry, ViewModel, UI, rider registration — actually handles two *real*, currently-active events at once.

Add a fresh `EventDefinition` scheduled entirely inside Founders' Circle's still-open window (`founders_circle_aug2026` runs 2026-08-05 → 2026-09-04): start **2026-08-20**, end **2026-08-24** (4 days, D5-cadence-compliant, genuinely overlapping rather than adjacent). `ProgressTrackRegistry.tracks[thisEvent.id]` gets a small free-lane-only milestone table, same posture as Milestone track's and Parallel board's own test events (test-only content to prove the flow, not real 6c calendar authoring).

This is the first `EventDefinition` in the registry whose sole purpose is proving concurrency, not proving a new event *type* — reuse Milestone track's mechanic (progress track + rider) rather than inventing new UI for it, since the thing under test here is the multi-event plumbing, not another reward-track design.

---

## 5. Acceptance

- [x] `EventRegistry.activeEvents` returns every currently-active event, routed through `EventScheduler.activeEvents(at:)`, sorted by priority then start date
- [x] While §4's test event overlaps Founders' Circle, both appear as separate task-strip cards simultaneously
- [x] Tapping each card opens that event's own sheet — not the other one's, not a stale one
- [ ] Both events' order-token riders fire independently — fulfilling an order can carry tokens for either or both simultaneously; neither event's token accrual starves while the other is active — not freshly verified on screen; rests on §3.3's tested diff logic + `OrderRewardRegistry`'s pre-existing tested `flatMap`
- [ ] Ending one of the two overlapping events (time-travel or a short synthetic window) leaves the other's card, sheet, and rider unaffected — not verified this session
- [ ] Save/load round-trips both events' independent `progressTracks` entries correctly — not verified this session (no test specific to two simultaneous entries)
- [ ] No event active → empty `activeEvents`, no cards, no crash — existing single-event-inactive behavior, unchanged — not freshly verified this session
- [x] Full test suite green
- [ ] Verified on screen: two simultaneously-active event cards, both sheets independently reachable, an order carrying a rider for each — cards and sheets confirmed; rider-carrying order not exercised

---

## 6. Out of scope

- The old `EventProgress`/`trackEventCoins`/`claimEventMilestone` single-global-progress system — already dead, left inert per Milestone track's spec §3.6, not migrated or removed here
- `EventScheduler.contestedSlotWinner` — stays unused; reserved for a genuine same-slot conflict this task doesn't create (e.g. two weekly-cadence events accidentally double-booked), not the weekly+Pass steady state this task targets
- Parallel board — separate 6b task, still spec-only, unaffected by this task either way
- Mid-session event start/end detection — `checkEventLifecycle()` stays launch-only-plus-explicit-call, same documented gap as before this task
- The real 90-day rolling calendar — Phase 6c itself, which this task exists to unblock, not to author
- D8 / chain-offer variant — orthogonal; whichever event type it ships as, it's just one more ID flowing through the same generalized path
