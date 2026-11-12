# PawSanctuary — Phase 7: the third 90-day calendar (2027-03-03 → 2027-06-01)

**Status: In progress — §3.1 done (11 Nov 2026), §3.2 done (11 Nov 2026), §3.3 done (11 Nov 2026), §3.4 done (11 Nov 2026), §3.5 done (12 Nov 2026), §3.6 not started.** Written 11 Nov 2026 from a read of `main` at `b900435` (Calendar 2 fully merged, PRs #64–#69).

**§3.1 — continuous track:** `sanctuary_circle_s7_20270303`, `sanctuary_circle_s8_20270402`, `sanctuary_circle_s9_20270502` added to `EventRegistry.allEvents` (after `playtime_rush_20270226`), plus their `ProgressTrackRegistry.tracks` entries (verbatim Founders' Circle tables, after the S6 key). Running-total pin 36 → 39; Calendar 2's §4.8 `EventRegistry` half converted to subset assertions (Parallel Board / Drive halves untouched until §3.5). 7 new tests (`SanctuaryCircleSeasons3Tests`, UTC-pinned). Full suite green. No schema change.

**§3.2 — weekly events, month 1:** `rescue_relay_20270305`, `playtime_rush_20270312`, `rescue_relay_20270319`, `playtime_rush_20270326` added to `EventRegistry.allEvents` (after `sanctuary_circle_s9_20270502`), cosmetics copied verbatim from the existing Rescue Relay / Playtime Rush entries, plus 4 `ProgressTrackRegistry.tracks` entries (verbatim Adoption Drive tables, after the `playtime_rush_20270226` key). Running-total pin 39 → 43. 8 new tests (`WeeklyEvents3Month1Tests`, `EventSystemTests.swift`): exact IDs/names/dates, 4-day durations, 3-day gaps, the 3-day seam from `playtime_rush_20270226` with flavor alternation, no pairwise overlap, exactly S7 underneath every day, verbatim table equality. Full suite 814/814 green. No schema change (v44).
**§3.3 — weekly events, month 2:** `rescue_relay_20270402`, `playtime_rush_20270409`, `rescue_relay_20270416`, `playtime_rush_20270423`, `rescue_relay_20270430` added to `EventRegistry.allEvents` (after `playtime_rush_20270326`) plus 5 verbatim Adoption Drive tables in `ProgressTrackRegistry.tracks`. Running-total pin 43 → 48. 9 new tests (`WeeklyEvents3Month2Tests`); full suite 823/823 green: dates/names, 4-day durations, 3-day gaps, month 1→2 seam with alternation, no overlap, instance-5 boundary start (04-01 {S7}; 04-02 {S8, instance 5}), instance-9 straddle (2 events at/±1s of 05-02; S8 on 04-30/05-01, S9 on 05-02/05-03), S8-only under instances 6–8, table equality. No schema change (v44).
**§3.4 — weekly events, month 3:** `playtime_rush_20270507`, `rescue_relay_20270514`, `playtime_rush_20270521`, `rescue_relay_20270528` added to `EventRegistry.allEvents` (after `rescue_relay_20270430`) plus 4 verbatim Adoption Drive tables in `ProgressTrackRegistry.tracks`. Running-total pin 48 → 52, this batch's final `EventRegistry` total. 9 new tests (`WeeklyEvents3Month3Tests`): dates/names, 4-day durations, 3-day gaps, month 2→3 seam with alternation, no overlap (incl. instance 9), inside S9 with only S9 underneath, instance 13 `endDate == sanctuary_circle_s9_20270502.endDate` (asserted), table equality, and the 13-ID capstone (each once with tables, alternating from Rescue Relay, 4 on / 3 off, 7-day cadence). No schema change (v44).
**§3.5 — Parallel Board and Kibble Drive:** `second_chances_20270310`, `second_chances_20270409`, `second_chances_20270509` appended to `ParallelBoardEventRegistry.allEvents` (after `second_chances_20270208`) plus 3 verbatim `second_chances_20260911` tables in `ProgressTrackRegistry.tracks`; `kibble_drive_20270326`, `kibble_drive_20270423`, `kibble_drive_20270521` appended to `KibbleDriveRegistry.allEvents` (after `kibble_drive_20270226`). Both doc-comment tables extended. Same commit: `ParallelBoardCalendarLayerTests` count 6 → 9 with `seasonalIDs` / `pairedSeasonIDs` extended to S7–S9; Calendar 2's §4.8 Parallel Board and Drive halves rewritten as subset checks (the test had drifted to `EventSystemTests.swift:2279-2305`, not `:1701-1724`). 9 new tests (`Calendar3BoardAndDriveTests.swift`): +7-day season offsets with exact dates and verbatim cosmetics, table equality, no Parallel Board window 02-20/03-03/03-09, 28-day Drive chain from `kibble_drive_20270226`, no Drive 03-01 → 03-26 day by day, lifecycle at 03-11 (Second Chances, no Drive) and 03-27 (empty `kibble_drive_20270326`, no Parallel Board). No schema change (v44).

**Self-contained brief.** Assumes no prior conversation. This is the pass `Spec_Phase7_Calendar2.md` §6 names in advance: *"After 2027-03-03: the next calendar-authoring pass, same shape again."* `Spec_Phase6c_Calendar.md` §6 set the rule: each batch is *"another calendar-authoring pass, structurally identical to this one, not a new mechanism."* That is all this spec is. Same four layers, same tracks, same curves, same names, same ID convention, same verification method as Calendar 2, re-dated for the next 90 days. Every start date below is derived from the real last window in code, not from Calendar 2's prose; each derivation cites file:line.

> **Deadline: implementation merged before 2027-02-15.** The continuous track goes dark at 2027-03-03 00:00 UTC and the next weekly event is due 2027-03-05. `checkEventLifecycle()` is launch-only (§1), and a build has to clear review and reach devices before then. 2027-02-15 leaves about two weeks of slack. Six tasks at one task per session fit comfortably; start no later than late January.

> **Not atomic.** Suggested landing order is in §3. Land each task as its own commit, verify it, and stop if one resists.

---

## 0. Why: the next content cliff

Calendar 2 is in the code and every layer runs out within four days of 2027-03-01. Each date below was checked against the code at `b900435`:

| Layer | Last scheduled window | Ends | Where |
|---|---|---|---|
| Kibble Drive | `kibble_drive_20270226` | **2027-03-01** | `PawSanctuary/KibbleDriveEvents.swift:146-152` (end date at `:151`) |
| Weekly track | `playtime_rush_20270226` | **2027-03-02** | `PawSanctuary/EventSystem.swift:686-699` (end date at `:691`) |
| Continuous track | `sanctuary_circle_s6_20270201` | **2027-03-03** | `PawSanctuary/EventSystem.swift:481-494` (end date at `:486`) |
| Parallel Board | `second_chances_20270208` | **2027-02-11** | `PawSanctuary/ParallelBoardEvents.swift:143-150` (end date at `:149`) |

After 2027-03-03, `EventRegistry.allEvents` (`EventSystem.swift:96`), `ParallelBoardEventRegistry.allEvents` (`ParallelBoardEvents.swift:102`) and `KibbleDriveRegistry.allEvents` (`KibbleDriveEvents.swift:103`) have nothing active on any date. No error is raised and no test fails: every calendar test samples dates up to 2027-03-03 at most.

**What this deliberately is not:** a recurrence engine, a procedural scheduler, or a content system. `Spec_Phase6c_Calendar.md` §0 rejected that and accepted the cost that someone re-runs this pass every ~90 days. This spec is the second re-run.

---

## 1. Decisions and constraints this depends on

These are unchanged from `Spec_Phase7_Calendar2.md` §1 and are restated here only so this spec can be read on its own.

- **D5 (cadence)**, unchanged: one 3–4 day event per week and one 30-day pass running continuously.
- **Parallel Board cadence** (design authority, 17 Aug 2026; doc comment at `ParallelBoardEvents.swift:52-93`): monthly, one instance per Sanctuary Circle season, 3 days long, **starting 7 days into its paired season**.
- **Kibble Drive cadence**: 3-day windows **exactly 28 days apart**. Owner decision **Q9 (2026-11-10)**: keep the 28-day spacing. Recorded in the code comment at `KibbleDriveEvents.swift:82-85` and asserted for Calendar 2 by `Calendar2BoardAndDriveTests.testEachNewDriveStartsExactlyTwentyEightDaysAfterThePreviousOne` (`PawSanctuaryTests/Calendar2BoardAndDriveTests.swift:92-108`). The test floor is 21 days (`KibbleDriveLifecycleTests.swift:62-68`), but the decided number is 28.
- **Concurrency is a per-registry rule, not an all-surface cap** (§2.6). See `Spec_Phase7_Calendar2.md` §2.6.
- **No new mechanism.** `EventScheduler.activeEvents(at:)`, `checkEventLifecycle(at:)` (`MergeBoardViewModel.swift:4113`), the rider providers, the Parallel Board coordinator and the Drive lifecycle already handle any number of dated entries. This spec adds array entries and dictionary keys only.
- **Launch-only lifecycle** (pre-existing): a window that opens while the app is already running is picked up on the next launch. This spec does not change that, but it is why the deadline has slack.
- **`EventTimer` / expiry-notification wiring is still not connected** (Phase 6a). This is a pre-existing gap and is out of scope, as it was in both earlier calendars.

---

## 2. Target shape

### 2.1 ID and date conventions (reused exactly)

- IDs are `<flavor>_<yyyymmdd of startDate>`. Seasons are `sanctuary_circle_s<N>_<yyyymmdd>`, and N continues from 6. Every window gets its own ID because progress, token wallets, `ParallelBoardSaveState` and `KibbleDriveState` are all keyed by event ID. A reused ID would open a new window already filled from the previous one.
- Dates use `date("yyyy-MM-dd")` through each registry's private `ISO8601DateFormatter` with `.withFullDate`, which parses as **midnight UTC**. `startDate` is inclusive and `endDate` is exclusive.
- Every new `EventDefinition` uses `minLevel: 0`, `priority: 0` and `milestones: []`. The real milestone data lives in `ProgressTrackRegistry.tracks`.

### 2.2 Window end: 2027-06-01, and why

The batch runs **2027-03-03 → 2027-06-01**, exactly 90 days. The end date comes from the season arithmetic rather than being picked:

- S7 must start the instant S6 ends, `2027-03-03` (`EventSystem.swift:486`). Three 30-day seasons then end at 03-03 + 90 = **2027-06-01**. March has 31 days and April 30, so 03-03 + 30 = 04-02, 04-02 + 30 = 05-02 and 05-02 + 30 = 06-01.
- The weekly track lines up on its own. Weekly #13 (05-28 → 06-01) ends exactly at S9's end, so this batch has no weekly event running past the window and no tail beyond the ordinary 3-day off-period. That off-period is 06-01 → 06-04, the same seam shape as 03-02 → 03-05 at the start.
- Rejected alternatives: ending on a weekly boundary (06-04) or a calendar-month boundary (05-31 or 06-30). Either option breaks the 30-day season, which is a retune and out of scope.

### 2.3 Continuous track — Sanctuary Circle S7–S9, 30 days each, zero gap

| Cycle | ID | Start | End |
|---|---|---|---|
| Season 7 | `sanctuary_circle_s7_20270303` | 2027-03-03 | 2027-04-02 |
| Season 8 | `sanctuary_circle_s8_20270402` | 2027-04-02 | 2027-05-02 |
| Season 9 | `sanctuary_circle_s9_20270502` | 2027-05-02 | 2027-06-01 |

S7 starts the instant S6 ends (`EventSystem.swift:486`), the same zero-gap handoff as S1 through S6.

**DST note for the tests.** S7 contains both spring clock changes: US DST starts 2027-03-14 and EU DST starts 2027-03-28. With an unpinned device-local `Calendar`, a 30-day span across either change counts wrong. This is the same bug the first calendar's §3.1 hit across the 2026-11-01 fall-back. Every `Calendar` used for day arithmetic must be pinned to UTC.

### 2.4 Weekly track — 13 events, alternating, 7-day cadence, 4-day duration, 3-day gap

| # | Flavor | ID | Start | End | Season(s) underneath |
|---|---|---|---|---|---|
| 1 | Rescue Relay | `rescue_relay_20270305` | 2027-03-05 | 2027-03-09 | S7 |
| 2 | Playtime Rush | `playtime_rush_20270312` | 2027-03-12 | 2027-03-16 | S7 |
| 3 | Rescue Relay | `rescue_relay_20270319` | 2027-03-19 | 2027-03-23 | S7 |
| 4 | Playtime Rush | `playtime_rush_20270326` | 2027-03-26 | 2027-03-30 | S7 |
| 5 | Rescue Relay | `rescue_relay_20270402` | 2027-04-02 | 2027-04-06 | S8 (starts on S8's first instant, **not** a straddle) |
| 6 | Playtime Rush | `playtime_rush_20270409` | 2027-04-09 | 2027-04-13 | S8 |
| 7 | Rescue Relay | `rescue_relay_20270416` | 2027-04-16 | 2027-04-20 | S8 |
| 8 | Playtime Rush | `playtime_rush_20270423` | 2027-04-23 | 2027-04-27 | S8 |
| 9 | Rescue Relay | `rescue_relay_20270430` | 2027-04-30 | 2027-05-04 | **S8 → S9** (straddles 05-02) |
| 10 | Playtime Rush | `playtime_rush_20270507` | 2027-05-07 | 2027-05-11 | S9 |
| 11 | Rescue Relay | `rescue_relay_20270514` | 2027-05-14 | 2027-05-18 | S9 |
| 12 | Playtime Rush | `playtime_rush_20270521` | 2027-05-21 | 2027-05-25 | S9 |
| 13 | Rescue Relay | `rescue_relay_20270528` | 2027-05-28 | 2027-06-01 | S9 (ends exactly at S9's end) |

**Phase and alternation continue Calendar 2 without a break.** The last existing weekly event is `playtime_rush_20270226` (02-26 → 03-02, `EventSystem.swift:687-691`). The next start on the 7-day cadence is 02-26 + 7 = **03-05**, and the flavor after a Playtime Rush is **Rescue Relay**. Both match `Spec_Phase7_Calendar2.md` §6's predicted seam. 2027-03-05 is a Friday, so every weekly event in this batch starts on a Friday, as all 26 existing weekly events do. The 03-02 → 03-05 gap is the ordinary 3-day off-period. It is not a tail gap, for the reason `Spec_Phase7_Calendar2.md` §2.3 gives.

**One straddle, plus one exact-boundary start.** Calendar 2 had two straddles. This batch has one (instance 9, across 05-02). Instance 5 starts on 04-02, the same instant S8 starts. At 2027-04-02 00:00 UTC, S7 has just ended (exclusive), and S8 and instance 5 have just started. Exactly 2 `EventRegistry` events are active and only S8 is underneath. The day before (04-01), S7 is active alone, because instance 4 ended 03-30. Tests in §3.3 pin this, because it is the boundary most likely to produce an off-by-one when someone authors it by hand.

### 2.5 Parallel Board — "Second Chances", one per season

| Season | ID | Start | End |
|---|---|---|---|
| S7 | `second_chances_20270310` | 2027-03-10 | 2027-03-13 |
| S8 | `second_chances_20270409` | 2027-04-09 | 2027-04-12 |
| S9 | `second_chances_20270509` | 2027-05-09 | 2027-05-12 |

Each instance starts 7 days into its paired season (03-03 + 7, 04-02 + 7, 05-02 + 7) and runs 3 days, exactly the rule in the doc comment at `ParallelBoardEvents.swift:74-75`. Copy these fields verbatim from the existing six entries (`ParallelBoardEvents.swift:103-150`): `name: "Second Chances"`, `icon: "arrow.triangle.2.circlepath"`, `chainID: ContentRegistry.parallelBoardSecondChancesChainID`.

The 2027-02-11 → 2027-03-10 dark period is **27 days**, the same as every existing inter-instance gap. It is by design and gets no window.

### 2.6 Kibble Drive — 3-day windows, 28 days apart

| Instance | ID | Start | End |
|---|---|---|---|
| 8 | `kibble_drive_20270326` | 2027-03-26 | 2027-03-29 |
| 9 | `kibble_drive_20270423` | 2027-04-23 | 2027-04-26 |
| 10 | `kibble_drive_20270521` | 2027-05-21 | 2027-05-24 |

The phase continues from `kibble_drive_20270226` (`KibbleDriveEvents.swift:147-151`): 02-26 + 28 = 03-26, + 28 = 04-23, + 28 = 05-21. The next date, 06-18, falls after 06-01 and belongs to the next batch. That gives **3** Drives this batch, against Calendar 2's 4: 90 days hold three or four 28-day steps depending on phase, and this batch's phase allows three. The 03-01 → 03-26 dark period is **25 days**, the same as every existing inter-Drive gap (28 − 3). Copy these fields verbatim: `name: "Kibble Drive"`, `icon: "shippingbox.fill"`. **No per-window content is needed.** `KibbleDriveLadder.rungs` is one global table, so a Drive window is a registry entry and nothing else.

28 is a multiple of 7, so every Drive starts on a weekly-event start day (Friday): 03-26 with weekly #4, 04-23 with #8 and 05-21 with #12. All three fall on Playtime Rush instances, which is an artefact of phase and has no design meaning.

### 2.7 Concurrency — the max-concurrent rule, as the code defines it

The rules are the same per-registry rules as `Spec_Phase7_Calendar2.md` §2.6:

1. **`EventRegistry` batch: at most 2 active** (one season plus at most one weekly event).
2. **Parallel Board: at most 1 active.** `activeEvent(at:)` returns `.first` (`ParallelBoardEvents.swift:158-160`), and non-overlap is asserted by `ParallelBoardCalendarLayerTests.testNoTwoSeasonalInstancesEverOverlap` (`ParallelBoardEventsTests.swift:196-201`).
3. **Kibble Drive: at most 1 active.** Same `.first` shape (`KibbleDriveEvents.swift:160-162`). Non-overlap is asserted by `KibbleDriveLifecycleTests.testWindowsAreThreeDaysLongAndNoneOverlap` (`:46-57`).
4. **Overlap across registries is allowed, on purpose** (`KibbleDriveEvents.swift:61-70`; `KibbleDriveLifecycleTests.testOverlapWithOtherEventSurfacesIsAllowed`).

The all-surface ceiling is 4 by construction. The observed maximum in this batch is **3**, reached on 15 days:

- 03-12 (S7 + weekly #2 + Second Chances)
- 03-26 → 03-28 (S7 + weekly #4 + Drive)
- 04-09 → 04-11 (S8 + weekly #6 + Second Chances)
- 04-23 → 04-25 (S8 + weekly #8 + Drive)
- 05-09 → 05-10 (S9 + weekly #10 + Second Chances)
- 05-21 → 05-23 (S9 + weekly #12 + Drive)

No Second Chances window ever overlaps a Drive window in this batch, so a 4-way overlap never happens. The tests in §4 assert rules 1–3 and pin the all-surface peak at 3, as a check on the calendar's shape rather than as a product rule.

### 2.8 Reward-curve reuse, not new numbers

Every number below is an existing, shipped table, copied under each new ID:

- **Sanctuary Circle S7–S9:** a verbatim copy of `ProgressTrackRegistry.tracks["founders_circle_aug2026"]` (`LiveOpsEngine.swift:142`), as used for S1–S6.
- **All 13 weekly events, both flavors:** a verbatim copy of `ProgressTrackRegistry.tracks["adoption_drive_aug2026"]` (`LiveOpsEngine.swift:121`), with thresholds 60/140/220 and `paidRewards: []`.
- **Second Chances ×3:** a verbatim copy of `ProgressTrackRegistry.tracks["second_chances_20260911"]` (`LiveOpsEngine.swift:229`), 8 milestones with thresholds 20…160.
- **Kibble Drive ×3:** no table to add.

Copy the cosmetic fields (`name`, `tagline`, `icon`, `accentColor`, `gradientColors`) from the existing entries rather than retyping them: Sanctuary Circle from `EventSystem.swift:481-494`, Rescue Relay from `:248-260` and Playtime Rush from `:262-274`. The values are listed in `Spec_Phase7_Calendar2.md` §2.7 and are unchanged.

### 2.9 The full window table

Every window in 2027-03-03 → 2027-06-01, across all four layers, by start date:

| Start | End | Layer | ID |
|---|---|---|---|
| 2027-03-03 | 2027-04-02 | Continuous | `sanctuary_circle_s7_20270303` |
| 2027-03-05 | 2027-03-09 | Weekly #1 | `rescue_relay_20270305` |
| 2027-03-10 | 2027-03-13 | Parallel Board | `second_chances_20270310` |
| 2027-03-12 | 2027-03-16 | Weekly #2 | `playtime_rush_20270312` |
| 2027-03-19 | 2027-03-23 | Weekly #3 | `rescue_relay_20270319` |
| 2027-03-26 | 2027-03-30 | Weekly #4 | `playtime_rush_20270326` |
| 2027-03-26 | 2027-03-29 | Kibble Drive | `kibble_drive_20270326` |
| 2027-04-02 | 2027-05-02 | Continuous | `sanctuary_circle_s8_20270402` |
| 2027-04-02 | 2027-04-06 | Weekly #5 (boundary start) | `rescue_relay_20270402` |
| 2027-04-09 | 2027-04-13 | Weekly #6 | `playtime_rush_20270409` |
| 2027-04-09 | 2027-04-12 | Parallel Board | `second_chances_20270409` |
| 2027-04-16 | 2027-04-20 | Weekly #7 | `rescue_relay_20270416` |
| 2027-04-23 | 2027-04-27 | Weekly #8 | `playtime_rush_20270423` |
| 2027-04-23 | 2027-04-26 | Kibble Drive | `kibble_drive_20270423` |
| 2027-04-30 | 2027-05-04 | Weekly #9 (straddle) | `rescue_relay_20270430` |
| 2027-05-02 | 2027-06-01 | Continuous | `sanctuary_circle_s9_20270502` |
| 2027-05-07 | 2027-05-11 | Weekly #10 | `playtime_rush_20270507` |
| 2027-05-09 | 2027-05-12 | Parallel Board | `second_chances_20270509` |
| 2027-05-14 | 2027-05-18 | Weekly #11 | `rescue_relay_20270514` |
| 2027-05-21 | 2027-05-25 | Weekly #12 | `playtime_rush_20270521` |
| 2027-05-21 | 2027-05-24 | Kibble Drive | `kibble_drive_20270521` |
| 2027-05-28 | 2027-06-01 | Weekly #13 | `rescue_relay_20270528` |

That is **22 windows**: 16 `EventDefinition`s (3 seasons and 13 weekly events), 3 `ParallelBoardEventDefinition`s and 3 `KibbleDriveEventDefinition`s.

### 2.10 Target shape table

| Today (`b900435`) | Target |
|---|---|
| `EventRegistry.allEvents`: 36 entries, last ends 2027-03-03 | 36 existing **unchanged, not removed**, + 16 new = **52** |
| `ParallelBoardEventRegistry.allEvents`: 6, last ends 2027-02-11 | 6 + 3 = **9** |
| `KibbleDriveRegistry.allEvents`: 7, last ends 2027-03-01 | 7 + 3 = **10** |
| `ProgressTrackRegistry.tracks` (`LiveOpsEngine.swift:115`) | **+19 keys**: 16 for the new `EventDefinition`s and 3 for the new Second Chances windows. None for the Drive. |
| Nothing scheduled after 2027-03-03 | Real content through 2027-06-01 on every layer |

### 2.11 Persisted shape: no change

No `GameState` field, Codable type or schema version changes. The schema stays at **v44** (`static let currentVersion = 44`, `GameStore.swift:388`), verified at `b900435`. Everything new is static registry data, and every piece of persisted state that touches events is already keyed by an event-ID `String` and handles an unseen ID. See `Spec_Phase7_Calendar2.md` §2.10 for the per-field walk-through, which this batch changes nothing about. No migration and no `PersistenceTests` case. If implementation finds otherwise, stop and raise it: that would be a mechanism change, which is out of scope.

---

## 3. Tasks, suggested landing order

The shape is the same as `Spec_Phase7_Calendar2.md` §3 (seasons → weekly by month → Parallel Board + Drive → regression tests). Each task is additive only: new array entries, new dictionary keys, new tests. Each must build cleanly and pass the full suite on its own. One task per session, per working rule 1. Put a comment block before each new group of entries in the style of `EventSystem.swift:445-452` (*"Phase 7 third calendar (Spec_Phase7_Calendar3.md §2.x/§3.x) — …"*). Put the new `ProgressTrackRegistry` keys next to the Calendar 2 keys of the same kind.

**Pinned assertions that this batch breaks.** Every other existing calendar test either checks subsets or samples dates up to 2027-03-03 and stays green. The ones below fail as soon as entries are added, so each must change **in the same commit** that changes the count:

| Pin | Where | Breaks in | Change |
|---|---|---|---|
| Running total of `EventRegistry` IDs | `FullCalendarRegressionTests.testRegistryHasExpectedRunningTotalOfUniqueEventIDsNoDuplicates`, `EventSystemTests.swift:852-856` (value at `:854`, doc comment `:843-851`) | 3.1, 3.2, 3.3, 3.4 | 36 → **39** (3.1) → **43** (3.2) → **48** (3.3) → **52** (3.4). Extend the doc comment's running tally each time. |
| Calendar 2 registry shape, `EventRegistry` half | `FullCalendar2RegressionTests.testRegistrySizesHaveNoDuplicatesAndKeepEveryExistingID`, `EventSystemTests.swift:1701-1724`: `eventIDs.count == 36` at `:1706` and exact-set equality at `:1721` | 3.1 | Recommended: change both to subset assertions (`existingEventIDs ∪ newBatchEventIDs ⊆ Set(eventIDs)`). The exact total moves to the running-total pin above and to Calendar 3's own §4.8 test. Do **not** list Calendar 3 IDs inside the Calendar 2 class. |
| Calendar 2 registry shape, Parallel Board and Drive halves | same test: `parallelIDs.count == 6` / `driveIDs.count == 7` at `:1707-1708`; exact-set equality at `:1722-1723` | 3.5 | Same subset rewrite. |
| Parallel Board instance count | `ParallelBoardCalendarLayerTests.testEverySeasonalInstanceExistsInTheRegistry`, `ParallelBoardEventsTests.swift:170-175` (value at `:174`) | 3.5 | 6 → **9**. Also extend `seasonalIDs` (`:147-155`) and `pairedSeasonIDs` (`:157-164`) with the 3 new instances and S7/S8/S9. The class's other five tests then cover the new windows automatically. |

No existing Kibble Drive test pins a count. `KibbleDriveLifecycleTests.testWindowsAreThreeDaysLongAndNoneOverlap` and `testInstancesAreAboutFourWeeksApartNotWeekly` iterate the whole registry in array order, so append the new Drives in date order and both tests cover them unchanged.

### 3.1 — Continuous track: `sanctuary_circle_s7/s8/s9` + tracks

Add the 3 `EventDefinition`s from §2.3 to `EventRegistry.allEvents`, after `playtime_rush_20270226` (`EventSystem.swift:686-699`). Add 3 `ProgressTrackRegistry.tracks` entries, each a verbatim copy of Founders' Circle's table.

**Same commit:** running-total pin 36 → 39, and the Calendar 2 §4.8 `EventRegistry` half rewritten as subset checks (see the table above).

**Verify (new `SanctuaryCircleSeasons3Tests`, `EventSystemTests.swift`, mirroring `SanctuaryCircleSeasons2Tests` at `:865`):**

- exact IDs and dates;
- S6's end equals S7's start;
- S7 → S8 → S9 contiguous, with zero gap and zero overlap;
- S7's start to S9's end is 90 days, 30 each, on a **UTC-pinned `Calendar`** (§2.3 DST note);
- each table equals Founders' Circle's;
- exactly the matching season is active at 03-15, 04-15 and 05-15;
- exactly one season is active at each boundary instant 03-03, 04-02 and 05-02.

### 3.2 — Weekly events, month 1 (instances 1–4, March)

Add `rescue_relay_20270305`, `playtime_rush_20270312`, `rescue_relay_20270319` and `playtime_rush_20270326`, plus 4 tables copied verbatim from Adoption Drive. **Same commit:** running-total pin 39 → 43.

**Verify (new `WeeklyEvents3Month1Tests`):**

- exact IDs, names and dates;
- each event lasts 4 days, with a 3-day gap to the next;
- **the cross-batch seam:** `playtime_rush_20270226.endDate` to `rescue_relay_20270305.startDate` is exactly 3 days, and the flavor alternates across it (Calendar 2 ends on Playtime Rush, Calendar 3 starts on Rescue Relay);
- no pairwise overlap;
- exactly S7 is underneath on every day of each event;
- tables match Adoption Drive's.

### 3.3 — Weekly events, month 2 (instances 5–9, April)

Add `rescue_relay_20270402`, `playtime_rush_20270409`, `rescue_relay_20270416`, `playtime_rush_20270423` and `rescue_relay_20270430`, plus tables. **This month holds the straddle and the boundary start.** **Same commit:** running-total pin 43 → 48.

**Verify (new `WeeklyEvents3Month2Tests`):**

- durations, gaps, and the month 1→2 seam with alternation;
- **instance 5's boundary start:** on 04-01 the `EventRegistry` active set is exactly {S7}. At the instant 2027-04-02 it is exactly {S8, `rescue_relay_20270402`}, with 2 events and S7 absent. On 04-02 through 04-05, only S8 is underneath.
- **instance 9's straddle:** exactly S8 on 04-30 and 05-01, and exactly S9 on 05-02 and 05-03. At the instant 2027-05-02, exactly 2 `EventRegistry` events are active (the straddler and S9). The same holds one second before and one second after.
- instances 6–8 have only S8 underneath on every day;
- tables match.

### 3.4 — Weekly events, month 3 (instances 10–13, May)

Add `playtime_rush_20270507`, `rescue_relay_20270514`, `playtime_rush_20270521` and `rescue_relay_20270528`, plus tables. All four sit inside S9, with no straddle. **Same commit:** running-total pin 48 → 52, which is this batch's final `EventRegistry` total.

**Verify (new `WeeklyEvents3Month3Tests`):**

- durations, gaps, the month 2→3 seam, no overlap;
- each event lies inside S9 with only S9 underneath;
- instance 13 ends at **exactly S9's end** (`rescue_relay_20270528.endDate == sanctuary_circle_s9_20270502.endDate`). This differs from Calendar 2, where instance 13 ended one day before S6. Assert the equality so a re-dating shows up.
- tables match;
- capstone: all 13 new weekly IDs exist exactly once with tables, alternate starting on Rescue Relay, and run 4 days on with 3-day gaps throughout.

### 3.5 — Parallel Board and Kibble Drive windows

Append the 3 `ParallelBoardEventDefinition`s from §2.5 to `ParallelBoardEventRegistry.allEvents`, after `second_chances_20270208` (`ParallelBoardEvents.swift:143-150`). Add 3 `ProgressTrackRegistry` entries copied verbatim from Second Chances' table, after `second_chances_20270208`'s (`LiveOpsEngine.swift:392`).

Append the 3 `KibbleDriveEventDefinition`s from §2.6 to `KibbleDriveRegistry.allEvents`, after `kibble_drive_20270226` (`KibbleDriveEvents.swift:146-152`).

Extend both doc-comment tables with the new rows: `ParallelBoardEvents.swift:78-85` and its following paragraph, and `KibbleDriveEvents.swift:72-85`. Two separate commits are fine; both are pure data.

**Same commit:** `ParallelBoardEventsTests.swift:174` 6 → 9, plus the `seasonalIDs` / `pairedSeasonIDs` extensions. Also the Calendar 2 §4.8 Parallel Board and Drive halves, rewritten as subset checks.

**Verify (new file `PawSanctuaryTests/Calendar3BoardAndDriveTests.swift`, mirroring `Calendar2BoardAndDriveTests.swift`; the test target uses file-system-synchronised groups, so no `project.pbxproj` edit is needed):**

- each new Second Chances instance starts exactly 7 days after its season's start, and its table equals `second_chances_20260911`'s;
- the 02-11 → 03-10 Parallel Board gap has no window (`activeEvent(at:)` is nil at 2027-02-20, 03-03 and 03-09);
- each new Drive starts exactly 28 days after the previous one, counted from `kibble_drive_20270226`, and runs 3 days;
- no Drive window opens between 2027-03-01 and 2027-03-26 (checked day by day, plus `activeEvent(at: 03-26)?.id == "kibble_drive_20270326"`);
- `checkEventLifecycle(at: 2027-03-11)` creates a coordinator for `second_chances_20270310` and no Drive;
- `checkEventLifecycle(at: 2027-03-27)` creates `KibbleDriveState(eventID: "kibble_drive_20270326")` with 0 points, and no Parallel Board coordinator.

Use the `GameStore.clear()` setUp/tearDown pattern from `Calendar2BoardAndDriveTests.swift:37-45`.

### 3.6 — Full-calendar regression tests

These are the cross-cutting invariants that only mean something once 3.1–3.5 are all in. See §4. The task is test-only, with no production code.

---

## 4. Verification approach

The method is the same as both earlier calendars. Every date is static data, so every assertion queries a **synthetic, injected date**: `EventScheduler(events: EventRegistry.allEvents).activeEvents(at:)`, `ParallelBoardEventRegistry.activeEvent(at:)`, `KibbleDriveRegistry.activeEvent(at:)` or `MergeBoardViewModel.checkEventLifecycle(at:)`. **Never use `Date()`, `EventRegistry.activeEvents`, `currentEvent`, `isActive` or `timeRemaining`.** They read the wall clock, which is how earlier tests rotted. Every `Calendar` used for day arithmetic is pinned to UTC.

The model is Calendar 2's `FullCalendar2RegressionTests` (class at `EventSystemTests.swift:1484`): a day-by-day loop at midnight UTC that uses the `days(from:to:)` and `allSurfaceActiveIDs(at:)` helpers (`:1545-1572`). All transitions land on day boundaries, so a daily sample cannot miss one.

Add a new class, **`FullCalendar3RegressionTests`**, in `EventSystemTests.swift` after the month-3 class, with one test per item:

1. **Never more than 2 batch-3 `EventRegistry` events active**, checked day by day over 2027-03-03 → 2027-06-01 (exclusive). Assert `≤ 2` every day, `sampledDays == 90`, and observed max `== 2`.
2. **No gap in the continuous track:** exactly one of S7/S8/S9 is active on every one of the 90 days.
3. **No gap across the batch seam:** exactly one season (S6 or S7–S9) is active on every day from 2027-02-01 to 2027-06-01, which is 120 days. This proves the S6 → S7 handoff at 2027-03-03.
4. **The weekly track is never dark longer than its own cadence:** walk from 2027-02-26 to 2027-06-01 using the 13 new weekly IDs plus `playtime_rush_20270226`. The longest dark run is exactly 3 (asserted `== 3`, which covers the 03-02 → 03-05 seam).
5. **No two of the 13 new weekly events overlap** (full O(n²) pairwise check), and none overlaps `playtime_rush_20270226`.
6. **Per-registry concurrency, day by day across the same 90 days:**
   - at most 1 Parallel Board instance and at most 1 Drive are active. Count with `allEvents.filter`, not `activeEvent(at:)`.
   - the all-surface total (batch-3 `EventRegistry` events + Parallel Board + Drive) never exceeds 4, and the observed max is **3** (§2.7).
7. **Every new ID has its table:** the 16 new `EventDefinition` IDs and the 3 new Second Chances IDs each have a `ProgressTrackRegistry.tracks` entry equal to their reference table (Founders' Circle, Adoption Drive, `second_chances_20260911`).
8. **Registry shape:**
   - `EventRegistry.allEvents` has **52** unique IDs, `ParallelBoardEventRegistry` has **9**, and `KibbleDriveRegistry` has **10**;
   - no duplicates in any registry;
   - the existing 36 / 6 / 7 IDs are all present;
   - exact ID sets equal existing ∪ batch 3.

   This is now the only exact-set pin (see the §3 pin table), and the next batch rewrites it the same way.
9. **Representative spot checks** of the exact active set across all four registries:

   | Date | Expected active set | Why |
   |---|---|---|
   | 2027-03-03 | {S7} | seam day; Drive and weekly both off |
   | 2027-03-12 | {S7, `playtime_rush_20270312`, `second_chances_20270310`} | |
   | 2027-03-26 | {S7, `playtime_rush_20270326`, `kibble_drive_20270326`} | |
   | 2027-04-02 | {S8, `rescue_relay_20270402`} | boundary start |
   | 2027-05-02 | {S9, `rescue_relay_20270430`} | straddle boundary |
   | 2027-05-31 | {S9, `rescue_relay_20270528`} | last day |

Calendar 1's and Calendar 2's tests stay green unchanged, apart from the pins listed in §3.

**On-screen verification:** none of this content is active on the day it lands, so the deterministic tests are the real verification. Natural on-screen confirmation happens on 2027-03-03 in production. A Simulator check before then needs a clock override that the Simulator does not expose (`TODO.md`). Do not seed or fake a save for it.

---

## 5. Acceptance

- [ ] 16 new `EventDefinition`s in `EventRegistry.allEvents`, with dates and IDs exactly as in §2.3/§2.4
- [ ] 3 new `ParallelBoardEventDefinition`s and 3 new `KibbleDriveEventDefinition`s, exactly as in §2.5/§2.6
- [ ] 19 new `ProgressTrackRegistry.tracks` entries, each a verbatim copy of its reference table (§2.8)
- [ ] S6 → S7 → S8 → S9 contiguous, with zero gap and zero overlap; exactly one season active every day 2027-03-03 → 2027-06-01
- [ ] Weekly track never dark more than 3 days, including across the 03-02 → 03-05 seam
- [ ] At most 2 batch-3 `EventRegistry` events, 1 Parallel Board and 1 Drive active on any day, verified day by day
- [ ] All tests use injected dates and UTC-pinned calendars only
- [ ] Every pin in §3's table updated in the same commit that changes the count
- [ ] No production code changed outside the three registries, their doc comments and `ProgressTrackRegistry.tracks`; no schema change (v44)
- [ ] Full suite green
- [ ] **Merged to `main` before 2027-02-15**

---

## 6. Open questions

- **Real-world holidays.** Calendar 2 gave holidays no special handling. Neither its spec nor any registry comment mentions one, Christmas Day 2026 opened an ordinary `rescue_relay_20261225`, and New Year's Day opened an ordinary `playtime_rush_20270101` alongside `kibble_drive_20270101`. This spec follows the same approach. For the owner's information, this batch's collisions are:
  - **Easter weekend** (Good Friday 03-26 to Easter Monday 03-29, 2027) falls exactly on `kibble_drive_20270326`, alongside `playtime_rush_20270326`. This is one of the 3-surface peak stretches.
  - **US Mother's Day** (Sun 05-09) is the first day of `second_chances_20270509`, inside `playtime_rush_20270507`.
  - **UK Mothering Sunday** (03-07) falls inside `rescue_relay_20270305`.
  - **US Memorial Day** (05-31) is the last day of `rescue_relay_20270528`.

  None needs a change unless the owner wants holiday-themed content. Themed content would mean a new flavor, which is out of scope here and would need its own spec.
- **Inherited and unchanged:** both weekly flavors share identical numbers, one name is used across seasons, and two flavors alternate. All were reviewed and accepted in `Spec_Phase6c_Calendar.md` §6 and are not reopened here.
- **Three Drives instead of four.** This follows from the 28-day phase (§2.6) and is not a choice. It is listed only so the lower count is not mistaken for a mistake.
- **After 2027-06-01:** the next calendar-authoring pass, same shape again. The seams it inherits are S10 at 2027-06-01, weekly #1 at 2027-06-04 (Playtime Rush), Second Chances at 2027-06-08 and the next Drive at 2027-06-18. That is the third consecutive manual pass. `Spec_Phase6c_Calendar.md` §0 accepted that recurring cost, and whether to keep paying it is the owner's call, not this spec's.

---

## 7. Out of scope

- New event flavors, names, icons, colors or event types, including holiday-themed variants (§6).
- Retuning any number: durations, cadences (7-day weekly, 30-day season, 3-day Parallel Board at +7 days, 28-day Drive), reward tables, ladder rungs or prices.
- `EventTimer` / `scheduleExpiryNotification` wiring, a pre-existing gap from Phase 6a.
- Any new mechanism: no recurrence rules, generated schedules or mid-session lifecycle polling, and no changes to `EventScheduler`, `EventRegistry.currentEvent`/`activeEvents`, `checkEventLifecycle()`, the coordinators or any UI call site.
- Any persisted-shape change (§2.11).
- Removing or editing any existing registry entry. Expired entries stay as inert history.
- A cap on all-surface concurrency (§2.7).
- The Kibble Drive's outstanding StoreKit gaps (`TODO.md`).

---

## 8. Spec-vs-code discrepancies found while writing this

Per `CLAUDE.md`, where a spec and the code disagree, the code was checked and wins.

1. **`Spec_Phase7_Calendar2.md`'s status header** says *"merge to `main` before 2026-12-01 still required (§5)"*. All six tasks are merged (PRs #64–#69, `main` at `b900435`), so that line is stale. Its §5 acceptance checkboxes are also still unticked. This spec does not edit it.
2. **`Spec_Phase7_Calendar2.md` §4** says the first calendar's tests stay green *"except for the two pinned counts"*. That was true for Calendar 2. For Calendar 3 there are **three** places to touch: the running-total pin, the Parallel Board count, and Calendar 2's own §4.8 test. That test (`EventSystemTests.swift:1701-1724`) added exact-set and exact-count assertions that Calendar 1's suite never had (§3 pin table). This is not a bug, but the next spec should expect it.
3. **Line numbers in `Spec_Phase7_Calendar2.md` §0–§2** (for example `KibbleDriveEvents.swift:109-115`, `ParallelBoardEvents.swift:111-118` and `:126-128`) have shifted with Calendar 2's own additions. This spec cites `b900435` line numbers. The citations in this spec will drift the same way as each task lands; re-find them by ID, not by line.
4. **`CLAUDE.md`'s document table** lists `Spec_Phase6c_Calendar.md` but neither `Spec_Phase7_Calendar2.md` nor this spec. Not edited here, because `CLAUDE.md` is out of bounds for this task. It is flagged for the owner.
5. **Calendar 2's §2.3 rationale for instance 13** (*"the next calendar's first weekly event (3 days later, 2027-03-05) closes that"*) checks out against the code. `playtime_rush_20270226` ends 03-02 (`EventSystem.swift:691`), and 03-05 is a Friday. No discrepancy; recorded because the seam was verified, not assumed.
