# PawSanctuary — Event expiry notifications ("ends soon")

**Status: Draft — no code written; owner approval needed before any build.** Written cold 11 Nov 2026 (PROJECT_STATE Queue #8). Every file:line below was checked against `main` at `b900435`. Where a spec disagrees with the code, §8 says so.

**Self-contained brief.** Assumes no prior conversation. Phase 6a built an `EventTimer` primitive whose notification half has never been called. This spec lays out ways to wire it, recommends one (§3, the worker's recommendation, not a decision), and breaks that one into committable tasks (§4).

---

## 0. Why

An "event ends soon" local notification brings a player back for something they already started. That is a retention lever, and **D9** (Alignment Plan, decided 8 Oct 2026) says retention wins when it conflicts with monetization. The plumbing for it has existed since Phase 6a and has zero callers. `Spec_Phase6c_Calendar.md` §1 and §7, and `Spec_Phase7_Calendar2.md` §1 and §7, each record it as a pre-existing gap and leave it out of scope.

Notifications in this app are **local only** (`UNUserNotificationCenter`, time-interval and calendar triggers, no APNs). The Push Notifications capability is not needed (verified on the Simulator 10 Nov 2026, `TODO.md` "Local notifications — verified on the Simulator"). Nothing here changes that.

---

## 1. What exists today

### 1.1 The unwired primitive

| Piece | Where | What it does |
|---|---|---|
| `EventTiming` protocol | `PawSanctuary/LiveOpsPrimitives.swift:65-69` | `remaining(eventID:)`, `isUrgent(eventID:)`, `scheduleExpiryNotification(eventID:at:)`. |
| `EventTimer` | `PawSanctuary/LiveOpsEngine.swift:1289-1311` | Conforms to `EventTiming` over an injectable `[EventDefinition]` (default `EventRegistry.allEvents`). `scheduleExpiryNotification` (`:1305-1310`) looks the event up and calls `NotificationManager.shared.scheduleEventExpiry` with body `"\(event.name) — \(event.tagline)"`. Unknown ID: silently does nothing. |
| `NotificationID.eventExpiry(_:)` | `PawSanctuary/NotificationManager.swift:27` | `"pawsanctuary.event.expiry.<eventID>"`. One identifier per event. |
| `scheduleEventExpiry(eventID:at:summary:)` | `PawSanctuary/NotificationManager.swift:219-245` | Guard `isAuthorised`; interval = `date.timeIntervalSinceNow` (`:230`); skip if ≤ 10 s; title fixed `"Event ending soon!"`, body = `summary`, default sound, no badge; `UNTimeIntervalNotificationTrigger`; cancels the same ID, then adds. |
| `cancelEventExpiry(eventID:)` | `PawSanctuary/NotificationManager.swift:247-249` | Cancels that one ID. |
| Tests | `PawSanctuaryTests/LiveOpsEngineTests.swift:398-435` (`EventTimerTests`) | Cover `remaining`/`isUrgent` only. Nothing tests `scheduleExpiryNotification`. |

**No call sites, confirmed by grep** (`EventTimer(`, `.scheduleExpiryNotification`, `scheduleEventExpiry`, `cancelEventExpiry` over `PawSanctuary/` and `PawSanctuaryTests/`). The only hits are the definitions themselves, the doc comment at `LiveOpsEngine.swift:1286`, and the four `EventTimer(events:)` constructions in `EventTimerTests`, none of which call the scheduling method.

### 1.2 The notification cycle any new notification must survive

- **`.active` wipes everything.** `MergeBoardView.swift:437` (scene phase `.active`) and `:396` (`.onAppear`) call `NotificationManager.shared.cancelAll()` (`NotificationManager.swift:397-401`: remove all pending, all delivered, clear badge).
- **`.background` and `.inactive` put things back.** Both call `MergeBoardView.scheduleAllNotifications()` (`MergeBoardView.swift:454-474`), which, when authorised: (1) reschedules kibble-full via the view model, (2) schedules the urgent order's 5-minute warning, (3) calls `NotificationManager.scheduleStandingOnBackground()` (`NotificationManager.swift:366-370`): daily rewards, `scheduleAll()` (daily reset + streak reminder), 48 h re-engagement.
- **`AppEntry`** (`AppEntry.swift:15-34`) schedules `scheduleAll()` at cold launch and the streak reminder + daily reset on every `.active`. Those are then raced by `MergeBoardView`'s `cancelAll()`; the reason `scheduleStandingOnBackground()` exists is that the background pass is the only reliable place (PR #58, `NotificationManagerTests.swift:1-12`).
- **Streak reminder** (`NotificationManager.swift:318-347`): 20:00 local tonight if the player has not played today; 20:00 local tomorrow if they have (PR #63). Skipped when not played and already past 20:00.

**Consequence for this spec:** an event-expiry notification must be (re)scheduled from the background pass. Scheduling it anywhere else (at launch, on `.active`, inside `checkEventLifecycle()`) loses it on the first warm return. Because `.active` clears it and the background pass recomputes it, the notification needs no persisted "already sent" flag: it fires at most once per absence, and once its fire date is past the background pass skips it (`interval > 10` guard).

### 1.3 The test seam

`NotificationCentre` protocol (`NotificationManager.swift:36-43`) plus the test initialiser `init(centre:now:isAuthorised:lastLoginDate:)` (`:91-99`). `NotificationManagerTests.swift` uses a `RecordingCentre` stand-in (`:20-31`) and a fixed clock to replay the scene-phase cycle; 12 tests (`:53-262`). **Gap:** `scheduleEventExpiry` computes its interval from `date.timeIntervalSinceNow` (`:230`), the real wall clock, not the injected `now()`. Tests with a fixed clock that is not "now" get the wrong interval, or a skip. `scheduleRescueExpiring` has the same gap (`:281`). `EventTimer` also hard-wires `NotificationManager.shared` (`LiveOpsEngine.swift:1307`), so it cannot be pointed at a recording centre.

### 1.4 What is already pending when the app backgrounds (iOS keeps the soonest 64)

| ID | Kind | Count |
|---|---|---|
| `pawsanctuary.kibble.full` | one-shot | ≤ 1 |
| `pawsanctuary.order.expiry.<uuid>` | one-shot, urgent order only (`MergeBoardView.swift:462-467`) | ≤ 1 |
| `pawsanctuary.rescue.expiring` | one-shot, scheduled during play by `MergeBoardViewModel.rescheduleRescueExpiring()` (`MergeBoardViewModel.swift:3745-3753`), not by the background pass | ≤ 1 |
| `pawsanctuary.daily.rewards` | repeating 09:00 | 1 |
| `pawsanctuary.daily.reset` | repeating 00:00 | 1 |
| `pawsanctuary.streak.reminder` | one-shot 20:00 | ≤ 1 |
| `pawsanctuary.reengagement` | one-shot +48 h | 1 |
| **Total** | | **≤ 7 of 64** |

The 64 cap is not a constraint for any option here (worst case below is 7 + 4 = 11). The real budget is the player's attention: on a bad day the existing set can already deliver daily rewards (09:00), streak (20:00) and daily reset (00:00), plus kibble-full and order warnings.

### 1.5 Live-ops kinds with end dates

All dates are authored as ISO full dates, which `ISO8601DateFormatter` reads as **00:00 UTC** (`EventSystem.swift:90-94`, `ParallelBoardEvents.swift:46-50`, `KibbleDriveEvents.swift:44-48`). So every event ends at the same instant worldwide: 16:00 the previous day in Los Angeles (PST), 19:00 in New York, 00:00 in London, 09:00 in Tokyo, 11:00 in Sydney (AEDT). Any fixed lead time lands in someone's night, so quiet hours matter.

| Kind | Registry | Type | Length / cadence | Progress state | Covered by `EventTimer`? |
|---|---|---|---|---|---|
| Weekly events (Rescue Relay / Playtime Rush) | `EventRegistry.allEvents`, `EventSystem.swift:96` | `EventDefinition` | 4 days, every 7 | `progressTrack.progress(trackID: eventID)` (`ProgressTrack`, `LiveOpsEngine.swift:1152`), fed by `EventTokenRiderProvider` (`EventSystem.swift:749`), 3-milestone free-only table | Yes |
| Sanctuary Circle seasons (the continuous Pass) | `EventRegistry.allEvents` | `EventDefinition` | 30 days, contiguous | same `ProgressTrack`, 10 milestones, free + paid lane | Yes |
| Event Pass (paid lane) | not a dated entity of its own | — | — | `passUnlockedEventIDs` (`GameStore.swift` `GameState`, view model `:209`) marks a season's paid lane as bought | n/a: it ends when its season ends |
| Parallel Board ("Second Chances") | `ParallelBoardEventRegistry.allEvents`, `ParallelBoardEvents.swift:102`; `activeEvent(at:)` `:158` | `ParallelBoardEventDefinition` | 3 days, one per season | same `ProgressTrack`, keyed by the PB event ID (`ParallelBoardCoordinator.swift:129`); board in `GameState.parallelBoardState` | **No** — different type |
| Kibble Drive | `KibbleDriveRegistry.allEvents`, `KibbleDriveEvents.swift:103`; `activeEvent(at:)` `:160` | `KibbleDriveEventDefinition` | 3 days, every 28 | `GameState.kibbleDrive` (`KibbleDriveState`: `points`, `claimedRungs`, `purchased`; `KibbleDrive.swift:29-47`). **Forfeit on close** (`MergeBoardViewModel.swift:4160-4173`) | **No** — different type |
| Reward Ladder | — | — | untimed, never expires (`Spec_Phase6b_RewardLadder.md` §0) | — | n/a: nothing ends |

Distinguishing weekly from season needs no new field: a season's track has a paid lane. `EventPanelView.swift:38-40` already derives `hasPaidLane` as `milestones.contains { !$0.paidRewards.isEmpty }` from `ProgressTrackRegistry.tracks[id]`.

Lifecycle note: `checkEventLifecycle()` is launch-only (`MergeBoardViewModel.swift:4093-4113`). The planner proposed below reads the registries by date at background time and does not depend on it. An event that started mid-session has no rider provider until the next launch, so its progress is 0 and the progress gate skips it. That is consistent, not a bug.

---

## 2. Options

All options share three rules: schedule only from the background pass (§1.2); never fire after the event's `endDate`; and use copy that fits the Warmth pillar (an invitation, no guilt, no countdown pressure, no mention of purchases).

**Quiet hours (common to all options).** Proposed allowed window 09:00–21:00 local. If a computed fire time falls in 21:00–09:00, move it **earlier** to 19:00 local on the evening before. Because every quiet-window time is after 19:00 of its own evening, the moved time is always before the original fire time and so before the event end. If the moved time is already in the past at scheduling time, skip. 19:00 rather than 20:59 keeps it an hour clear of the 20:00 streak reminder. Worked examples, 6 h lead on an event ending 00:00 UTC in November: Los Angeles 10:00 (unchanged), New York 13:00, London 18:00, Berlin 19:00, India 23:30 → 19:00 (10.5 h before end), Tokyo 03:00 → 19:00 the previous evening (14 h), Sydney 05:00 → 19:00 the previous evening (16 h).

Constants (`eventExpiryLeadHours`, `notificationQuietStartHour`, `notificationQuietEndHour`, `eventExpiryQuietFallbackHour`) go at the bottom of `AnimalSpecies.swift` per `CLAUDE.md`, not inline.

### Option A — one reminder, weekly event only, progress-gated

- **Which events:** the active weekly `EventDefinition` (no paid lane on its track) where `progress > 0` and the track is not finished (a reached milestone is unclaimed, or a milestone is still unreached). The weekly events never overlap (`Spec_Phase7_Calendar2.md` §3.6 test 5), so there is at most one.
- **Lead time:** 6 h before `endDate`, after quiet-hour adjustment.
- **cancelAll / background:** recomputed on every background pass through `EventTimer.scheduleExpiryNotification`; the `.active` pass clears it. Fires at most once per absence.
- **Budget:** +1 identifier (≤ 8 of 64).
- **Copy:** title "Rescue Relay ends soon", body "You have a reward waiting. Come and collect it before the event closes 🐾" (unclaimed reward) or "You're partway along the reward track. A few more rescues before it closes?" (unreached milestone).
- **Persisted shape:** none. Reads `ProgressTrack` state that is already persisted (`GameState.progressTracks`).
- **For:** smallest change, uses `EventTimer` as built, the weekly event is the D5 beat most likely to have a half-finished track. **Against:** ignores the season, the one with the most accumulated reward at stake when it closes.

### Option B — per-kind reminders, with a global cap

- **Which events:** weekly (6 h lead), Sanctuary Circle season (24 h lead, since it is 30 days and the reward pile is larger), Parallel Board (6 h), Kibble Drive (12 h). Each progress-gated: track progress for the first three, `KibbleDrive.points > 0` with an unclaimed reachable rung for the Drive.
- **Global cap:** at most one event-expiry notification per local calendar day and at most 2 pending in total. Ties: unclaimed reward first, then earliest end.
- **cancelAll / background:** same pattern, more candidates.
- **Budget:** up to +2 pending (≤ 9 of 64); without the cap it could be +4 on days like 2026-12-04 when four surfaces are live (`Spec_Phase7_Calendar2.md` §3.6 test 6 peak is 3 events at once).
- **Code cost:** `EventTimer` only takes `[EventDefinition]`. Parallel Board and Drive definitions are different types in their own registries, kept separate on purpose (`Spec_Phase6b_ParallelBoard.md` §0.5, `KibbleDriveEvents.swift:61-70`). Covering them means a small adapter (an `id`/`name`/`endDate` protocol both types conform to) or a second scheduling path.
- **Copy:** season "Your Sanctuary Circle season ends tomorrow. Rewards you've earned are waiting to be claimed"; Parallel Board "Second Chances closes soon. Your board is still set up where you left it"; Drive "The Kibble Drive closes soon. Points don't carry over to the next one".
- **D7 / D9 flags:** the Drive is a $4.99 ladder and the season has a paid lane. The copy above mentions neither purchase, but a reminder that drives traffic to a paid surface is the "revenue lever" case D9 asks to be stated. Copy must never advertise the paid lane, and a Drive reminder should be gated on `isMonetizationUnlocked` (`MergeBoardViewModel.swift:396`) like every other Drive surface. Not a contradiction of D9, but it needs saying in review.
- **Persisted shape:** none (all state needed is already persisted).
- **For:** covers every event a player can lose rewards in. **Against:** most code; most notification volume; two kinds are monetization-adjacent.

### Option C — reuse the re-engagement slot

- **Idea:** no new identifier. On the background pass, if a qualifying event (same gate as A, or A + seasons) ends between now and now + 48 h, the existing `pawsanctuary.reengagement` request (`NotificationManager.swift:376-393`) is **retimed** to the event's quiet-hour-adjusted reminder time and **re-copied** with the event's name. Otherwise it stays the generic 48 h nudge.
- **Lead time:** as A (6 h).
- **cancelAll / background:** unchanged mechanics; same single slot.
- **Budget:** +0.
- **Copy:** as A, under the re-engagement ID.
- **Persisted shape:** none.
- **For:** zero extra notification volume; a player can never get both "misses you" and "event ends soon" for the same absence. **Against:** an event reminder earlier than 48 h replaces the generic nudge, so a player who ignores the event reminder gets no 48 h nudge after it. The re-engagement copy and timing become conditional, which muddies the one notification the 10 Nov Simulator run confirmed pending. It also changes the semantics of an identifier `NotificationManagerTests` already asserts on (the ID set is unchanged, but the trigger interval would no longer always be 48 h).

### Option comparison

| | A: weekly only | B: per kind + cap | C: reuse re-engagement |
|---|---|---|---|
| Events covered | weekly | weekly, season, Parallel Board, Drive | weekly (+ season if chosen) |
| Extra pending IDs | +1 | ≤ +2 (capped) | 0 |
| Touches `EventTimer` type | no | yes (adapter) | no |
| Monetization-adjacent | no | yes (Drive, season paid lane) | no |
| Persisted shape change | none | none | none |
| Schema | stays v44 (`GameStore.swift:388`) | stays v44 | stays v44 |

---

## 3. Recommendation (worker's recommendation, not a decision)

**Option A, widened to every `EventRegistry` event (weekly and season), with a cap of one pending event-expiry notification.** Call it **A+**.

- **Candidates:** active `EventDefinition`s at background time (`EventScheduler().activeEvents(at:)`), eligible for the player's level (`EventScheduler.isEligible`), with `progress > 0` and something left to gain on the track. "Something left" counts the paid lane only if `passUnlockedEventIDs` contains the event, so the reminder never points at an unbought lane.
- **Pick one:** an event with a reached-but-unclaimed reward wins over one without; then the earliest end. The weekly-plus-season same-instant end (for example `rescue_relay_20261030` and Season 2 both ending 2026-11-03) gives one notification, not two.
- **Lead time:** 6 h for both kinds, then quiet hours (§2). One number to tune, not two. Open question 2 asks whether seasons should get 24 h.
- **Exclude Parallel Board and Kibble Drive for now.** They are outside `EventTimer`'s type, and the Drive is the paid surface D9 asks to be careful with. Option B's adapter is the natural follow-up once A+ has been watched firing.
- **Why not C:** it saves one identifier out of 57 spare, and pays for it by making the only generic return nudge conditional.
- **Persisted shape:** none. **Schema stays v44**, so no migration and no `PersistenceTests` case. If any task finds it needs one, stop and raise it (rule 4).
- **D9:** retention-positive, no revenue change, no monetization surface promoted. Consistent with D1–D11; touches none of D1–D8, D10 or D11.

---

## 4. Tasks, suggested landing order (for A+)

Each task builds clean, passes the full suite, and leaves the game playable on its own. One task per session, per working rule 1. Tests use injected dates, a `RecordingCentre`-style stand-in, and a `Calendar` with a **pinned `TimeZone`** (never device-local: the first calendar's DST bug, `Spec_Phase7_Calendar2.md` §3.1).

### 4.1 — `scheduleEventExpiry` reads the injected clock

`NotificationManager.swift:230`: replace `date.timeIntervalSinceNow` with `date.timeIntervalSince(now())`, so the test seam's clock covers it. Production behaviour is unchanged (`now` is `Date.init` in the production initialiser, `:81-82`). Leave `scheduleRescueExpiring` (`:281`) alone; it has the same gap but is outside this spec (§5).

**Verify (new, `NotificationManagerTests.swift`):** with a fixed clock, `scheduleEventExpiry(at: clock + 3 h)` records a request under `NotificationID.eventExpiry(id)` whose `UNTimeIntervalNotificationTrigger.timeInterval` is 10 800; `at: clock + 5 s` records nothing; unauthorised records nothing; scheduling twice for one ID leaves one request.

### 4.2 — Tuning constants and a pure fire-time function

Add the four constants from §2 to the bottom of `AnimalSpecies.swift`. Add a pure function, for example `EventExpiryPlanner.fireDate(endDate:now:calendar:) -> Date?`: `endDate − lead`, moved to 19:00 the previous evening if inside 21:00–09:00 local, `nil` if the result is not after `now` (+10 s) or not before `endDate`. No call sites yet.

**Verify (new `EventExpiryPlannerTests`):** each worked example in §2 (Los Angeles, New York, London, Berlin, India, Tokyo, Sydney) against an event ending 2026-11-17 00:00 UTC with a calendar pinned to that zone; boundary times 08:59/09:00/20:59/21:00; `now` past the adjusted time → `nil`; a US DST-boundary case (event ending 2026-11-03, US clocks change 11-01).

### 4.3 — Candidate selection and copy

In the same planner, a pure `plan(now:events:progress:claimableReward:hasUnreached:isEligible:calendar:) -> EventExpiryReminder?` (event ID, fire date, title, body), taking closures rather than the view model so it can be tested in isolation. Selection and copy as §3; copy strings as §2 Option A plus the season line from Option B. Never mentions a price, a purchase or the paid lane.

`scheduleEventExpiry` gains an optional `title:` parameter defaulting to the current `"Event ending soon!"`, so the existing signature still compiles. `EventTimer` gains an injected `NotificationManager` (default `.shared`) so tests can hand it a recording-centre manager. The `EventTiming` protocol is unchanged.

**Verify:** progress 0 → nil; finished track → nil; unclaimed reward beats an earlier-ending event without one; weekly + season ending at the same instant → one reminder; paid-lane-only remaining with the lane not bought → nil; level below `minLevel` → nil; event not yet started → nil; copy contains the event name and none of "buy", "pass", "$". `EventTimerTests` gains a test that `scheduleExpiryNotification` reaches the recording centre under the right ID, and that an unknown ID schedules nothing.

### 4.4 — Wire it into the background pass

`MergeBoardViewModel.rescheduleEventExpiryNotification(at now: Date = Date())` builds the closures from `progressTrack`, `ProgressTrackRegistry.tracks`, `passUnlockedEventIDs` and `playerLevel`, calls the planner, and schedules through `EventTimer`. `MergeBoardView.scheduleAllNotifications()` (`MergeBoardView.swift:454`) calls it as a new step between the order warning and `scheduleStandingOnBackground()`. Nothing else calls it: not at launch, not on `.active`, not from `checkEventLifecycle()`.

Same commit: update the stale header comment in `NotificationManager.swift:5-10` ("Four notification types") to list the real set.

**Verify:** in `NotificationManagerTests`, replay cold launch → background → `cancelAll()` (warm return) → background against a fixed clock inside `rescue_relay_20261113`'s window with progress, and assert the pending ID set is the existing four plus `NotificationID.eventExpiry("rescue_relay_20261113")`. A second background pass leaves exactly one event-expiry request. A view-model test with `loadGame(at:)`-style injected dates confirms `rescheduleEventExpiryNotification(at:)` picks the expected event, or none.

### 4.5 — Simulator check (no code)

Same method as the 10 Nov run in `TODO.md`: patch a save to give progress in the live weekly event, set the clock or use a test event a few hours from its end, background, and read `PendingNotifications.plist` for `pawsanctuary.event.expiry.<id>` with the expected fire date. Watch it deliver if the timing allows. Record the result in `TODO.md` and this spec's status line.

---

## 5. Out of scope

- Remote push, APNs, or the Push Notifications capability.
- New event mechanics, new event kinds, "event has started" notifications, or any change to `EventScheduler`, `checkEventLifecycle()` or its launch-only posture.
- Retuning anything: event durations, cadences, reward tables, the existing notifications' times or copy (kibble-full, daily rewards, daily reset, streak, re-engagement, order and rescue warnings).
- Calendar changes: no registry entries added, moved or edited.
- Parallel Board and Kibble Drive reminders (Option B follow-up, only after owner sign-off).
- Fixing `scheduleRescueExpiring`'s wall-clock interval (`NotificationManager.swift:281`), or the overlap between the urgent order's two warnings (`order.expiry` at −5 min and `rescue.expiring` at −2 min for the same order). Both noted in §8, neither changed here.
- Any persisted-shape change. If one turns out to be needed, stop and raise it.
- In-app UI (badges, banners, a notification settings screen).

---

## 6. Open questions for the owner

1. **Which option?** A, A+ (recommended), B or C.
2. **Lead time.** 6 h for everything, or 24 h for the 30-day season (more reward at stake, and a full day lets a once-a-day player still reach it)?
3. **Quiet hours.** Is 21:00–09:00 local right, with the fallback at 19:00 the evening before? Or no quiet hours at all, accepting a 03:00 fire in Tokyo?
4. **Gate.** Is "progress > 0 and something left on the track" right, or only "an earned reward is unclaimed" (fewer, sharper notifications)?
5. **Daily volume.** On days the streak reminder also fires, is a second evening-ish notification acceptable, or should the event reminder be dropped when the streak reminder is pending within, say, 3 h of it?
6. **Copy and title.** Is the event name in the title ("Rescue Relay ends soon") preferred over the current generic "Event ending soon!"?
7. **Parallel Board and Kibble Drive.** Worth a follow-up spec (Option B), and should a Drive reminder exist at all, given it points at a $4.99 surface (D9 asks for that to be argued, not assumed)?

---

## 7. Acceptance (for A+)

- [ ] With progress in an active weekly or season event, backgrounding leaves exactly one `pawsanctuary.event.expiry.<id>` pending, at the quiet-hour-adjusted time, before the event's end.
- [ ] It survives warm return → background (the PR #58 cycle).
- [ ] No progress, a finished track, or an event that has not started → nothing scheduled.
- [ ] Never more than one event-expiry request pending.
- [ ] No copy mentions a purchase or the paid lane.
- [ ] Schema still v44; no `GameState` change.
- [ ] Full suite green after each task.

---

## 8. Spec-vs-code discrepancies found while writing this

Per `CLAUDE.md`: where a spec and the code disagree, the code was checked and wins.

1. **`Spec_Phase6a_Primitives.md` §6** says notification scheduling "isn't unit-testable (no `UNUserNotificationCenter` in the test target today)". Stale: the `NotificationCentre` seam and `RecordingCentre` (`NotificationManager.swift:36-43, 91-99`; `NotificationManagerTests.swift:20-31`) make it testable now, which is what §4 relies on.
2. **`scheduleEventExpiry` ignores the injected clock** (`NotificationManager.swift:230`, `timeIntervalSinceNow`), unlike the streak reminder, which uses `now()` (`:323`). Same for `scheduleRescueExpiring` (`:281`). Fixed for event expiry by §4.1 only.
3. **`EventTimer` hard-wires `NotificationManager.shared`** (`LiveOpsEngine.swift:1307`), while its event list is injectable. Its notification half cannot be tested as built. §4.3 adds injection.
4. **`EventTimer` cannot cover Parallel Board or Kibble Drive.** It takes `[EventDefinition]`; those layers use `ParallelBoardEventDefinition` and `KibbleDriveEventDefinition` in their own registries. Anything that reads "EventTimer schedules expiry for live-ops events" as covering all four surfaces overstates it.
5. **`NotificationManager.swift:5-10`** header says "Four notification types" and lists four. There are eight identifiers (`:19-28`): kibble full, daily rewards, daily reset, rescue expiring, streak reminder, re-engagement, order expiry, event expiry. §4.4 corrects it.
6. **`ProgressTrack`'s doc comment** (`LiveOpsEngine.swift:1146-1149`) says it is "Not yet wired into `MergeBoardViewModel`". Stale: the view model owns one (`MergeBoardViewModel.swift:125`) and advances it on every `.eventToken` reward (`:3644-3648`). Not fixed here (comment-only, outside scope); flagged.
7. **`PawSanctuary_GDD.md` §9.8 and the table at `:486`** say the Push Notifications capability is required and not enabled. Stale since 10 Nov 2026: it is not needed (`TODO.md` line 66; Alignment Plan 3.5). GDD §9.8 also lists four notification types. Not fixed here.
8. **"Event Pass" is not a dated kind.** The brief for this spec lists it alongside weekly events and seasons; in code it is the paid lane of a Sanctuary Circle season (`passUnlockedEventIDs`), ending when the season ends. §1.5 treats it that way.
