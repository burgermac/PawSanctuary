# PawSanctuary — Phase 7: the fourth 90-day calendar (2027-06-01 → 2027-08-30)

**Status: Draft — spec only, not started.** Written 12 Nov 2026 from a read of `main` at `c0ef746` (Calendar 3 fully merged; its last two tasks landed as PR #89 `cal3/3-5-board-and-drive` and PR #90 `cal3/3-6-regression-tests`).

**Self-contained brief.** Assumes no prior conversation. This is the pass `Spec_Phase7_Calendar3.md` §6 names in advance: *"After 2027-06-01: the next calendar-authoring pass, same shape again."* `Spec_Phase6c_Calendar.md` §6 set the rule: each batch is *"another calendar-authoring pass, structurally identical to this one, not a new mechanism."* That is all this spec is. Same four layers, same tracks, same curves, same names, same ID convention, same verification method as Calendar 3, re-dated for the next 90 days. Every start date below is derived from the real last window in code, not from Calendar 3's prose; each derivation cites file:line at `c0ef746`.

> **Deadline: implementation merged before 2027-05-15.** The continuous track and the weekly track both go dark at 2027-06-01 00:00 UTC. `checkEventLifecycle()` is launch-only (§1), and a build has to clear review and reach devices before then. 2027-05-15 leaves a little over two weeks of slack. Six tasks at one task per session fit comfortably; start no later than late April 2027.

> **Not atomic.** Suggested landing order is in §3. Land each task as its own commit, verify it, and stop if one resists.

---

## 0. Why: the next content cliff

Calendar 3 is in the code and every layer runs out by 2027-06-01. Each date below was checked against the code at `c0ef746`:

| Layer | Last scheduled window | Ends | Where |
|---|---|---|---|
| Parallel Board | `second_chances_20270509` | **2027-05-12** | `PawSanctuary/ParallelBoardEvents.swift:176-183` (end date at `:182`) |
| Kibble Drive | `kibble_drive_20270521` | **2027-05-24** | `PawSanctuary/KibbleDriveEvents.swift:175-181` (end date at `:180`) |
| Weekly track | `rescue_relay_20270528` | **2027-06-01** | `PawSanctuary/EventSystem.swift:935-948` (end date at `:940`) |
| Continuous track | `sanctuary_circle_s9_20270502` | **2027-06-01** | `PawSanctuary/EventSystem.swift:735-748` (end date at `:740`) |

After 2027-06-01, `EventRegistry.allEvents` (`EventSystem.swift:96`), `ParallelBoardEventRegistry.allEvents` (`ParallelBoardEvents.swift:109`) and `KibbleDriveRegistry.allEvents` (`KibbleDriveEvents.swift:109`) have nothing active on any date. No error is raised and no test fails: every calendar test samples dates up to 2027-06-01 at most.

**What this deliberately is not:** a recurrence engine, a procedural scheduler, or a content system. `Spec_Phase6c_Calendar.md` §0 rejected that and accepted the cost that someone re-runs this pass every ~90 days. This spec is the third re-run.

---

## 1. Decisions and constraints this depends on

These are unchanged from `Spec_Phase7_Calendar3.md` §1 and are restated here only so this spec can be read on its own.

- **D5 (cadence)**, unchanged: one 3–4 day event per week and one 30-day pass running continuously.
- **Parallel Board cadence** (design authority, 17 Aug 2026; doc comment at `ParallelBoardEvents.swift:52-108`, rule at `:74-75`): monthly, one instance per Sanctuary Circle season, 3 days long, **starting 7 days into its paired season**.
- **Kibble Drive cadence**: 3-day windows **exactly 28 days apart**. Owner decision **Q9 (2026-11-10)**: keep the 28-day spacing. Recorded in the code comment at `KibbleDriveEvents.swift:85-91` and asserted for Calendar 3 by `Calendar3BoardAndDriveTests.testEachNewDriveStartsExactlyTwentyEightDaysAfterThePreviousOne` (`PawSanctuaryTests/Calendar3BoardAndDriveTests.swift:112-134`). The test floor is 21 days (`KibbleDriveLifecycleTests.swift:62`), but the decided number is 28.
- **Concurrency is a per-registry rule, not an all-surface cap** (§2.7). See `Spec_Phase7_Calendar2.md` §2.6.
- **No new mechanism.** `EventScheduler.activeEvents(at:)` (`LiveOpsEngine.swift:28`), `checkEventLifecycle(at:)` (`MergeBoardViewModel.swift:4153`), the rider providers, the Parallel Board coordinator and the Drive lifecycle already handle any number of dated entries. This spec adds array entries and dictionary keys only.
- **Launch-only lifecycle** (pre-existing): a window that opens while the app is already running is picked up on the next launch. This spec does not change that, but it is why the deadline has slack.
- **`EventTimer` / expiry-notification wiring is still not connected** (Phase 6a). This is a pre-existing gap and is out of scope, as it was in all three earlier calendars.
- **No holiday special-casing.** Owner decision for batch 3: none. This batch follows it (§6).

---

## 2. Target shape

### 2.1 ID and date conventions (reused exactly)

- IDs are `<flavor>_<yyyymmdd of startDate>`. Seasons are `sanctuary_circle_s<N>_<yyyymmdd>`, and N continues from 9. Every window gets its own ID because progress, token wallets, `ParallelBoardSaveState` and `KibbleDriveState` are all keyed by event ID. A reused ID would open a new window already filled from the previous one.
- Dates use `date("yyyy-MM-dd")` through each registry's private `ISO8601DateFormatter` with `.withFullDate`, which parses as **midnight UTC**. `startDate` is inclusive and `endDate` is exclusive.
- Every new `EventDefinition` uses `minLevel: 0`, `priority: 0` and `milestones: []`. The real milestone data lives in `ProgressTrackRegistry.tracks`.

### 2.2 Window end: 2027-08-30, and why

The batch runs **2027-06-01 → 2027-08-30**, exactly 90 days. The end date comes from the season arithmetic rather than being picked:

- S10 must start the instant S9 ends, `2027-06-01` (`EventSystem.swift:740`). Three 30-day seasons then end at 06-01 + 90 = **2027-08-30**. June has 30 days and July 31, so 06-01 + 30 = 07-01, 07-01 + 30 = 07-31 and 07-31 + 30 = 08-30.
- **The weekly track does not line up with the season end this time.** Weekly #13 (08-27 → 08-31) ends **one day after** S12. The weekly phase slides by 90 mod 7 = 6 days per batch relative to the season grid: Calendar 1's last weekly ended 2 days before its season end, Calendar 2's 1 day before, Calendar 3's exactly on it, and Calendar 4's 1 day after. This is the first batch whose last weekly event runs past its last season. §2.4 explains why it is still authored here and what that means on 2027-08-30.
- Rejected alternatives: ending on a weekly boundary (08-31) or a calendar-month boundary (08-31). Either breaks the 30-day season, which is a retune and out of scope.

### 2.3 Continuous track — Sanctuary Circle S10–S12, 30 days each, zero gap

| Cycle | ID | Start | End |
|---|---|---|---|
| Season 10 | `sanctuary_circle_s10_20270601` | 2027-06-01 | 2027-07-01 |
| Season 11 | `sanctuary_circle_s11_20270701` | 2027-07-01 | 2027-07-31 |
| Season 12 | `sanctuary_circle_s12_20270731` | 2027-07-31 | 2027-08-30 |

S10 starts the instant S9 ends (`EventSystem.swift:740`), the same zero-gap handoff as S1 through S9. Note the two-digit season number in the ID: `sanctuary_circle_s10_…`, not `s010`. The convention is `s<N>` with no padding.

**DST note for the tests.** No US or EU clock change falls inside 2027-06-01 → 2027-08-30 (US DST runs 03-14 → 11-07, EU 03-28 → 10-31, both spanning the whole batch). Pin every `Calendar` used for day arithmetic to UTC anyway: it is the house rule, the seam tests reach back into earlier batches, and a test copied forward into a batch that does contain a change must not silently break.

### 2.4 Weekly track — 13 events, alternating, 7-day cadence, 4-day duration, 3-day gap

| # | Flavor | ID | Start | End | Season(s) underneath |
|---|---|---|---|---|---|
| 1 | Playtime Rush | `playtime_rush_20270604` | 2027-06-04 | 2027-06-08 | S10 |
| 2 | Rescue Relay | `rescue_relay_20270611` | 2027-06-11 | 2027-06-15 | S10 |
| 3 | Playtime Rush | `playtime_rush_20270618` | 2027-06-18 | 2027-06-22 | S10 |
| 4 | Rescue Relay | `rescue_relay_20270625` | 2027-06-25 | 2027-06-29 | S10 |
| 5 | Playtime Rush | `playtime_rush_20270702` | 2027-07-02 | 2027-07-06 | S11 (starts one day after S11) |
| 6 | Rescue Relay | `rescue_relay_20270709` | 2027-07-09 | 2027-07-13 | S11 |
| 7 | Playtime Rush | `playtime_rush_20270716` | 2027-07-16 | 2027-07-20 | S11 |
| 8 | Rescue Relay | `rescue_relay_20270723` | 2027-07-23 | 2027-07-27 | S11 |
| 9 | Playtime Rush | `playtime_rush_20270730` | 2027-07-30 | 2027-08-03 | **S11 → S12** (straddles 07-31) |
| 10 | Rescue Relay | `rescue_relay_20270806` | 2027-08-06 | 2027-08-10 | S12 |
| 11 | Playtime Rush | `playtime_rush_20270813` | 2027-08-13 | 2027-08-17 | S12 |
| 12 | Rescue Relay | `rescue_relay_20270820` | 2027-08-20 | 2027-08-24 | S12 |
| 13 | Playtime Rush | `playtime_rush_20270827` | 2027-08-27 | 2027-08-31 | S12, then **no batch-4 season on 08-30** (runs one day past S12's end) |

**Phase and alternation continue Calendar 3 without a break.** The last existing weekly event is `rescue_relay_20270528` (05-28 → 06-01, `EventSystem.swift:935-940`). The next start on the 7-day cadence is 05-28 + 7 = **06-04**, and the flavor after a Rescue Relay is **Playtime Rush**. Both match `Spec_Phase7_Calendar3.md` §6's predicted seam. 2027-06-04 is a Friday, so every weekly event in this batch starts on a Friday, as all 39 existing weekly-track events from `rescue_relay_20260904` onward do. The 06-01 → 06-04 gap is the ordinary 3-day off-period (`Spec_Phase7_Calendar2.md` §2.3).

**Flavor parity flips relative to Calendar 3.** Calendar 3 started on Rescue Relay, so its odd instances were Rescue Relay. Calendar 4 starts on Playtime Rush, so its **odd instances are Playtime Rush** and the capstone test (task 4.4) checks alternation starting on Playtime Rush. This is the alternation continuing, not a change.

**One straddle, no exact-boundary start, one batch-end overrun.**

- **Instance 9 straddles S11 → S12** at 07-31, the same shape as Calendar 3's instance 9 at 05-02.
- **No exact-boundary start.** Calendar 3's instance 5 started on S8's first instant. Here S11 starts 07-01 (a Thursday) and instance 5 starts 07-02, one day later. Instance 4 ended 06-29. So 06-29, 06-30 and 07-01 are weekly-dark; at the instant 2027-07-01 exactly 1 `EventRegistry` event is active (S11), with S10 just ended. Tests in task 4.3 pin this season handoff, which is the boundary most likely to produce an off-by-one when authored by hand.
- **Instance 13 overruns the batch by one day.** It starts 08-27 inside S12 and ends 08-31, one day after S12 ends 08-30. **Default used: author it here, as the cadence dictates.** Until Calendar 5 lands, 2027-08-30 has `playtime_rush_20270827` active with no season underneath; once Calendar 5 adds S13 at 08-30, instance 13 becomes an ordinary straddle (S12 → S13), exactly like instance 9. Rejected alternatives: stopping at 12 events leaves the weekly track dark 08-24 → 09-03 (10 days), breaking the "never dark longer than 3 days" invariant; shortening instance 13 to 3 days is a duration retune; leaving 08-27 for Calendar 5 to author means a batch authoring a window that starts before its own range. A weekly event without a season underneath for one day is harmless to the mechanism: `EventScheduler` and `checkEventLifecycle` treat every `EventDefinition` independently, and the ≤ 2 per-registry rule still holds (it is 1 that day). It is the content cliff Calendar 5 closes, the same as every batch's cliff.

### 2.5 Parallel Board — "Second Chances", one per season

| Season | ID | Start | End |
|---|---|---|---|
| S10 | `second_chances_20270608` | 2027-06-08 | 2027-06-11 |
| S11 | `second_chances_20270708` | 2027-07-08 | 2027-07-11 |
| S12 | `second_chances_20270807` | 2027-08-07 | 2027-08-10 |

Each instance starts 7 days into its paired season (06-01 + 7, 07-01 + 7, 07-31 + 7) and runs 3 days, exactly the rule in the doc comment at `ParallelBoardEvents.swift:74-75`. Copy these fields verbatim from the existing nine entries (`ParallelBoardEvents.swift:110-183`): `name: "Second Chances"`, `icon: "arrow.triangle.2.circlepath"`, `chainID: ContentRegistry.parallelBoardSecondChancesChainID`.

The 2027-05-12 → 2027-06-08 dark period is **27 days**, the same as every existing inter-instance gap. It is by design and gets no window.

Because the season start days are Tue / Thu / Sat, the Second Chances instances fall differently against the weekly track than in Calendar 3: the S10 instance (06-08 → 06-11) sits **entirely in a weekly off-period** (instance 1 ends 06-08, instance 2 starts 06-11), while the S11 and S12 instances overlap weekly #6 (on 07-09, 07-10) and weekly #10 (on 08-07 → 08-09). Phase artefact, no design meaning.

### 2.6 Kibble Drive — 3-day windows, 28 days apart

| Instance | ID | Start | End |
|---|---|---|---|
| 11 | `kibble_drive_20270618` | 2027-06-18 | 2027-06-21 |
| 12 | `kibble_drive_20270716` | 2027-07-16 | 2027-07-19 |
| 13 | `kibble_drive_20270813` | 2027-08-13 | 2027-08-16 |

The phase continues from `kibble_drive_20270521` (`KibbleDriveEvents.swift:175-180`): 05-21 + 28 = 06-18, + 28 = 07-16, + 28 = 08-13. The next date, 09-10, falls after 08-30 and belongs to the next batch. That gives **3** Drives this batch, the same as Calendar 3. The 05-24 → 06-18 dark period is **25 days**, the same as every existing inter-Drive gap (28 − 3). Copy these fields verbatim: `name: "Kibble Drive"`, `icon: "shippingbox.fill"`. **No per-window content is needed.** `KibbleDriveLadder.rungs` is one global table, so a Drive window is a registry entry and nothing else.

28 is a multiple of 7, so every Drive starts on a weekly-event start day (Friday): 06-18 with weekly #3, 07-16 with #7 and 08-13 with #11. All three fall on Playtime Rush instances again (odd instances are Playtime Rush this batch), which is an artefact of phase and has no design meaning.

### 2.7 Concurrency — the max-concurrent rule, as the code defines it

The rules are the same per-registry rules as `Spec_Phase7_Calendar2.md` §2.6 and `Spec_Phase7_Calendar3.md` §2.7:

1. **`EventRegistry` batch: at most 2 active** (one season plus at most one weekly event). Observed max over the 90 days: **2**.
2. **Parallel Board: at most 1 active.** `activeEvent(at:)` returns `.first` (`ParallelBoardEvents.swift:191-193`), and non-overlap is asserted by `ParallelBoardCalendarLayerTests.testNoTwoSeasonalInstancesEverOverlap` (`ParallelBoardEventsTests.swift:203`).
3. **Kibble Drive: at most 1 active.** Same `.first` shape (`KibbleDriveEvents.swift:189-191`). Non-overlap is asserted by `KibbleDriveLifecycleTests.testWindowsAreThreeDaysLongAndNoneOverlap` (`:46`).
4. **Overlap across registries is allowed, on purpose** (`KibbleDriveEvents.swift:61-70`; `KibbleDriveLifecycleTests.testOverlapWithOtherEventSurfacesIsAllowed`, `:82`).

The all-surface ceiling is 4 by construction. The observed maximum in this batch is **3**, reached on **14 days** (Calendar 3 had 15):

- 06-18 → 06-20 (S10 + weekly #3 + Drive)
- 07-09 → 07-10 (S11 + weekly #6 + Second Chances)
- 07-16 → 07-18 (S11 + weekly #7 + Drive)
- 08-07 → 08-09 (S12 + weekly #10 + Second Chances)
- 08-13 → 08-15 (S12 + weekly #11 + Drive)

No Second Chances window ever overlaps a Drive window in this batch, so a 4-way overlap never happens. The S10 Second Chances (06-08 → 06-10) contributes only 2-surface days, because it sits in a weekly off-period (§2.5). The tests in §4 assert rules 1–3 and pin the all-surface peak at 3 on exactly these 14 days, as a check on the calendar's shape rather than as a product rule.

2027-08-30 is outside the 90 sampled days. On that day the batch-4 surfaces active are exactly {`playtime_rush_20270827`} (§2.4).

### 2.8 Reward-curve reuse, not new numbers

Every number below is an existing, shipped table, copied under each new ID:

- **Sanctuary Circle S10–S12:** a verbatim copy of `ProgressTrackRegistry.tracks["founders_circle_aug2026"]` (`LiveOpsEngine.swift:142`), as used for S1–S9.
- **All 13 weekly events, both flavors:** a verbatim copy of `ProgressTrackRegistry.tracks["adoption_drive_aug2026"]` (`LiveOpsEngine.swift:121`), with thresholds 60/140/220 and `paidRewards: []`.
- **Second Chances ×3:** a verbatim copy of `ProgressTrackRegistry.tracks["second_chances_20260911"]` (`LiveOpsEngine.swift:229`), 8 milestones with thresholds 20…160.
- **Kibble Drive ×3:** no table to add.

Copy the cosmetic fields (`name`, `tagline`, `icon`, `accentColor`, `gradientColors`) from the existing entries rather than retyping them: Sanctuary Circle from `sanctuary_circle_s9_20270502` (`EventSystem.swift:735-748`), Rescue Relay from `rescue_relay_20270528` (`:935-948`) and Playtime Rush from `playtime_rush_20270521` (`:921-934`). The values are listed in `Spec_Phase7_Calendar2.md` §2.7 and are unchanged.

### 2.9 The full window table

Every window in 2027-06-01 → 2027-08-30 (plus instance 13's one-day overrun), across all four layers, by start date:

| Start | End | Layer | ID |
|---|---|---|---|
| 2027-06-01 | 2027-07-01 | Continuous | `sanctuary_circle_s10_20270601` |
| 2027-06-04 | 2027-06-08 | Weekly #1 | `playtime_rush_20270604` |
| 2027-06-08 | 2027-06-11 | Parallel Board | `second_chances_20270608` |
| 2027-06-11 | 2027-06-15 | Weekly #2 | `rescue_relay_20270611` |
| 2027-06-18 | 2027-06-22 | Weekly #3 | `playtime_rush_20270618` |
| 2027-06-18 | 2027-06-21 | Kibble Drive | `kibble_drive_20270618` |
| 2027-06-25 | 2027-06-29 | Weekly #4 | `rescue_relay_20270625` |
| 2027-07-01 | 2027-07-31 | Continuous | `sanctuary_circle_s11_20270701` |
| 2027-07-02 | 2027-07-06 | Weekly #5 | `playtime_rush_20270702` |
| 2027-07-08 | 2027-07-11 | Parallel Board | `second_chances_20270708` |
| 2027-07-09 | 2027-07-13 | Weekly #6 | `rescue_relay_20270709` |
| 2027-07-16 | 2027-07-20 | Weekly #7 | `playtime_rush_20270716` |
| 2027-07-16 | 2027-07-19 | Kibble Drive | `kibble_drive_20270716` |
| 2027-07-23 | 2027-07-27 | Weekly #8 | `rescue_relay_20270723` |
| 2027-07-30 | 2027-08-03 | Weekly #9 (straddle) | `playtime_rush_20270730` |
| 2027-07-31 | 2027-08-30 | Continuous | `sanctuary_circle_s12_20270731` |
| 2027-08-06 | 2027-08-10 | Weekly #10 | `rescue_relay_20270806` |
| 2027-08-07 | 2027-08-10 | Parallel Board | `second_chances_20270807` |
| 2027-08-13 | 2027-08-17 | Weekly #11 | `playtime_rush_20270813` |
| 2027-08-13 | 2027-08-16 | Kibble Drive | `kibble_drive_20270813` |
| 2027-08-20 | 2027-08-24 | Weekly #12 | `rescue_relay_20270820` |
| 2027-08-27 | 2027-08-31 | Weekly #13 (overruns by 1 day) | `playtime_rush_20270827` |

That is **22 windows**: 16 `EventDefinition`s (3 seasons and 13 weekly events), 3 `ParallelBoardEventDefinition`s and 3 `KibbleDriveEventDefinition`s. All dates were computed by script (Python `datetime`, 7-day / 30-day / 28-day steps from the cited last windows) and cross-checked day by day for the §2.7 figures.

### 2.10 Target shape table

| Today (`c0ef746`) | Target |
|---|---|
| `EventRegistry.allEvents`: 52 entries, last ends 2027-06-01 | 52 existing **unchanged, not removed**, + 16 new = **68** |
| `ParallelBoardEventRegistry.allEvents`: 9, last ends 2027-05-12 | 9 + 3 = **12** |
| `KibbleDriveRegistry.allEvents`: 10, last ends 2027-05-24 | 10 + 3 = **13** |
| `ProgressTrackRegistry.tracks` (`LiveOpsEngine.swift:115`) | **+19 keys**: 16 for the new `EventDefinition`s and 3 for the new Second Chances windows. None for the Drive. |
| Nothing scheduled after 2027-06-01 | Real content through 2027-08-30 on every layer (weekly through 08-31) |

### 2.11 Persisted shape: no change

No `GameState` field, Codable type or schema version changes. The schema stays at **v44** (`static let currentVersion = 44`, `GameStore.swift:388`), verified at `c0ef746`. Everything new is static registry data, and every piece of persisted state that touches events is already keyed by an event-ID `String` and handles an unseen ID. See `Spec_Phase7_Calendar2.md` §2.10 for the per-field walk-through, which this batch changes nothing about. No migration and no `PersistenceTests` case. If implementation finds otherwise, stop and raise it: that would be a mechanism change, which is out of scope.

---

## 3. Tasks, suggested landing order

The shape is the same as `Spec_Phase7_Calendar3.md` §3 (seasons → weekly by month → Parallel Board + Drive → regression tests). Each task is additive only: new array entries, new dictionary keys, new tests. Each must build cleanly and pass the full suite on its own. One task per session, per working rule 1. Put a comment block before each new group of entries in the style of `EventSystem.swift:700-706` (*"Phase 7 fourth calendar (Spec_Phase7_Calendar4.md §2.x/§3.x) — …"*). Put the new `ProgressTrackRegistry` keys next to the Calendar 3 keys of the same kind (tasks 4.1, 4.2 and 4.5 give the exact anchors).

**Future-proofing rule for every new test.** Any assertion about a date **outside** 2027-06-01 → 2027-08-30 (in practice, only 2027-08-30 itself, instance 13's overrun day) must intersect the active set with batch-4 IDs rather than compare the whole registry. Calendar 5 will add S13 at 2027-08-30, and a whole-registry assertion on that day would break then. Inside the 90 days, whole-registry exact sets are fine: later batches never add windows inside earlier ranges.

**Pinned assertions that this batch breaks.** Every other existing calendar test either checks subsets or samples dates up to 2027-06-01 and stays green. The ones below fail as soon as entries are added, so each must change **in the same commit** that changes the count:

| Pin | Where (at `c0ef746`) | Breaks in | Change |
|---|---|---|---|
| Running total of `EventRegistry` IDs | `FullCalendarRegressionTests.testRegistryHasExpectedRunningTotalOfUniqueEventIDsNoDuplicates`, `PawSanctuaryTests/EventSystemTests.swift:855-859` (value at `:857`, doc comment `:843-854`) | 4.1, 4.2, 4.3, 4.4 | 52 → **55** (4.1) → **59** (4.2) → **64** (4.3) → **68** (4.4). Extend the doc comment's running tally each time ("Fourth calendar (Spec_Phase7_Calendar4.md §4.1: +3 seasons = 55; …)"). |
| Calendar 3 registry shape, `EventRegistry` half | `FullCalendar3RegressionTests.testRegistrySizesHaveNoDuplicatesAndExactlyExistingPlusBatchThree`, `EventSystemTests.swift:1811-1838`: `eventIDs.count == 52` at `:1816` and exact-set equality at `:1835` | 4.1 | Change both to subset assertions (`≥ 52`; `existingEventIDs ∪ newBatchEventIDs ⊆ Set(eventIDs)`), exactly the rewrite Calendar 3 §3.1 applied to `FullCalendar2RegressionTests` (now at `:2594-2624`, which is the model). Keep the duplicate checks and the existing-subset checks. Update the test's doc comment (`:1808-1810`, *"The next calendar rewrites this as subset checks"*). Do **not** list Calendar 4 IDs inside the Calendar 3 class. |
| Calendar 3 registry shape, Parallel Board and Drive halves | same test: `parallelIDs.count == 9` / `driveIDs.count == 10` at `:1817-1818`; exact-set equality at `:1836-1837` | 4.5 | Same subset rewrite (`≥ 9` / `≥ 10`; `⊆`). |
| Parallel Board instance count | `ParallelBoardCalendarLayerTests.testEverySeasonalInstanceExistsInTheRegistry`, `PawSanctuaryTests/ParallelBoardEventsTests.swift:177-182` (value at `:181`) | 4.5 | 9 → **12**. Also extend `seasonalIDs` (`:147-159`) and `pairedSeasonIDs` (`:161-171`) with the 3 new instances and S10/S11/S12, under a `// Phase 7 fourth calendar` comment. The class's other five tests then cover the new windows automatically. |

After this batch, the only exact-set pin across the three registries is Calendar 4's own §4.8 test, and Calendar 5 rewrites it the same way.

**Checked and not breaking:** `Calendar3BoardAndDriveTests.swift` has no count or exact-set pins (its 8 tests name specific IDs and date ranges up to 2027-05-24). `FullCalendar2RegressionTests` is already subset-only. `FullCalendar3RegressionTests` §4.1–§4.7 and §4.9 sample only 2027-02-01 → 2027-06-01 and intersect with batch-3 IDs where it matters; its §4.6 peak-day pin covers batch-3 days only. `WeeklyEvents3Month3Tests.testInstanceThirteenEndsAtExactlySeasonNinesEnd` (`EventSystemTests.swift:1509-1517`) checks only that S9 and `rescue_relay_20270528` are absent at 06-01, which stays true. No existing Kibble Drive test pins a count: `KibbleDriveLifecycleTests.testWindowsAreThreeDaysLongAndNoneOverlap` (`:46`) and `testInstancesAreAboutFourWeeksApartNotWeekly` (`:62`) iterate the whole registry in array order, so append the new Drives in date order and both tests cover them unchanged. The fixed lifecycle dates in `KibbleDriveLifecycleTests` (`:30`) and `ParallelBoardLifecycleTests` (`:33-35`) are all in September 2026.

### 4.1 — Continuous track: `sanctuary_circle_s10/s11/s12` + tracks

Add the 3 `EventDefinition`s from §2.3 to `EventRegistry.allEvents`, after `rescue_relay_20270528` (`EventSystem.swift:935-948`, the last entry before the array closes at `:949`). Add 3 `ProgressTrackRegistry.tracks` entries, each a verbatim copy of Founders' Circle's table, after `sanctuary_circle_s9_20270502`'s (`LiveOpsEngine.swift:1129-1179`).

**Same commit:** running-total pin 52 → 55, and the Calendar 3 §4.8 `EventRegistry` half rewritten as subset checks (see the table above).

**Verify (new `SanctuaryCircleSeasons4Tests`, `EventSystemTests.swift`, mirroring `SanctuaryCircleSeasons3Tests` at `:983`):**

- exact IDs and dates;
- S9's end equals S10's start;
- S10 → S11 → S12 contiguous, with zero gap and zero overlap;
- S10's start to S12's end is 90 days, 30 each, on a **UTC-pinned `Calendar`** (§2.3 DST note);
- each table equals Founders' Circle's;
- exactly the matching season is active at 06-15, 07-15 and 08-15;
- exactly one season is active at each boundary instant 06-01, 07-01 and 07-31.

### 4.2 — Weekly events, month 1 (instances 1–4, June)

Add `playtime_rush_20270604`, `rescue_relay_20270611`, `playtime_rush_20270618` and `rescue_relay_20270625` after `sanctuary_circle_s12_20270731`, plus 4 tables copied verbatim from Adoption Drive after `rescue_relay_20270528`'s key (`LiveOpsEngine.swift:1523-1535`, before the `rewardLadderTrackID` key). **Same commit:** running-total pin 55 → 59.

**Verify (new `WeeklyEvents4Month1Tests`):**

- exact IDs, names and dates;
- each event lasts 4 days, with a 3-day gap to the next;
- **the cross-batch seam:** `rescue_relay_20270528.endDate` to `playtime_rush_20270604.startDate` is exactly 3 days, and the flavor alternates across it (Calendar 3 ends on Rescue Relay, Calendar 4 starts on Playtime Rush);
- no pairwise overlap;
- exactly S10 is underneath on every day of each event;
- tables match Adoption Drive's.

### 4.3 — Weekly events, month 2 (instances 5–9, July)

Add `playtime_rush_20270702`, `rescue_relay_20270709`, `playtime_rush_20270716`, `rescue_relay_20270723` and `playtime_rush_20270730`, plus tables. **This month holds the straddle and the season handoff.** **Same commit:** running-total pin 59 → 64.

**Verify (new `WeeklyEvents4Month2Tests`):**

- durations, gaps, and the month 1→2 seam with alternation;
- **the S10 → S11 handoff with no weekly event:** on 06-30 the `EventRegistry` active set is exactly {S10}. At the instant 2027-07-01 it is exactly {S11}, with 1 event and S10 absent. On 07-02 through 07-05, only S11 is underneath instance 5. (This replaces Calendar 3's instance-5 boundary-start check; there is no boundary start this batch, §2.4.)
- **instance 9's straddle:** exactly S11 underneath on 07-30, and exactly S12 on 07-31, 08-01 and 08-02. At the instant 2027-07-31, exactly 2 `EventRegistry` events are active (the straddler and S12). The same holds one second before (straddler and S11) and one second after.
- instances 6–8 have only S11 underneath on every day;
- tables match.

### 4.4 — Weekly events, month 3 (instances 10–13, August)

Add `rescue_relay_20270806`, `playtime_rush_20270813`, `rescue_relay_20270820` and `playtime_rush_20270827`, plus tables. Instances 10–12 sit inside S12 with no straddle; instance 13 overruns the batch by one day (§2.4). **Same commit:** running-total pin 64 → 68, which is this batch's final `EventRegistry` total.

**Verify (new `WeeklyEvents4Month3Tests`):**

- durations, gaps, the month 2→3 seam, no overlap;
- instances 10–12 each lie inside S12 with only S12 underneath;
- **instance 13's overrun:** `playtime_rush_20270827.endDate` is **exactly one day after** `sanctuary_circle_s12_20270731.endDate` (UTC calendar), and equals 2027-08-31. Only S12 is underneath on 08-27, 08-28 and 08-29. On 08-30, **none of S10–S12** is active and `playtime_rush_20270827` is (assert by intersecting with batch-4 IDs, per the §3 future-proofing rule; do not assert the whole registry is {instance 13}, which Calendar 5's S13 will change). At 2027-08-31, instance 13 is gone. Assert the `+1 day` so a re-dating shows up;
- tables match;
- capstone: all 13 new weekly IDs exist exactly once with tables, alternate **starting on Playtime Rush**, and run 4 days on with 3-day gaps throughout; first start 2027-06-04, last end 2027-08-31.

### 4.5 — Parallel Board and Kibble Drive windows

Append the 3 `ParallelBoardEventDefinition`s from §2.5 to `ParallelBoardEventRegistry.allEvents`, after `second_chances_20270509` (`ParallelBoardEvents.swift:176-183`). Add 3 `ProgressTrackRegistry` entries copied verbatim from Second Chances' table, after `second_chances_20270509`'s (`LiveOpsEngine.swift:491-522`).

Append the 3 `KibbleDriveEventDefinition`s from §2.6 to `KibbleDriveRegistry.allEvents`, after `kibble_drive_20270521` (`KibbleDriveEvents.swift:175-181`).

Extend both doc-comment tables with the new rows: `ParallelBoardEvents.swift:78-88` and its following paragraph (`:90-97`), and `KibbleDriveEvents.swift:72-83` and its following paragraph (`:85-91`, whose last sentence *"the next (2027-06-18) falls after that batch's 2027-06-01 end"* must be updated to say the next after this batch is 2027-09-10). Two separate commits are fine; both are pure data.

**Same commit:** `ParallelBoardEventsTests.swift:181` 9 → 12, plus the `seasonalIDs` / `pairedSeasonIDs` extensions. Also the Calendar 3 §4.8 Parallel Board and Drive halves, rewritten as subset checks.

**Verify (new file `PawSanctuaryTests/Calendar4BoardAndDriveTests.swift`, mirroring `Calendar3BoardAndDriveTests.swift`; the test target uses file-system-synchronised groups, so no `project.pbxproj` edit is needed):**

- each new Second Chances instance starts exactly 7 days after its season's start, with exact dates and verbatim cosmetics, and its table equals `second_chances_20260911`'s;
- the 05-12 → 06-08 Parallel Board gap has no window (`activeEvent(at:)` is nil at 2027-05-20, 06-01 and 06-07; `activeEvent(at: 06-08)?.id == "second_chances_20270608"`);
- each new Drive starts exactly 28 days after the previous one, counted from `kibble_drive_20270521`, and runs 3 days;
- no Drive window opens between 2027-05-24 and 2027-06-18 (checked day by day, 25 days, plus `activeEvent(at: 06-18)?.id == "kibble_drive_20270618"`);
- `checkEventLifecycle(at: 2027-06-09)` creates a coordinator for `second_chances_20270608` and no Drive;
- `checkEventLifecycle(at: 2027-06-19)` creates `KibbleDriveState(eventID: "kibble_drive_20270618")` with 0 points, and no Parallel Board coordinator.

Use the `GameStore.clear()` setUp/tearDown pattern from `Calendar3BoardAndDriveTests.swift:39-47`.

### 4.6 — Full-calendar regression tests

These are the cross-cutting invariants that only mean something once 4.1–4.5 are all in. See §4. The task is test-only, with no production code.

---

## 4. Verification approach

The method is the same as all three earlier calendars. Every date is static data, so every assertion queries a **synthetic, injected date**: `EventScheduler(events: EventRegistry.allEvents).activeEvents(at:)`, `ParallelBoardEventRegistry.activeEvent(at:)`, `KibbleDriveRegistry.activeEvent(at:)` or `MergeBoardViewModel.checkEventLifecycle(at:)`. **Never use `Date()`, `EventRegistry.activeEvents`, `currentEvent`, `isActive` or `timeRemaining`.** They read the wall clock, which is how earlier tests rotted. Every `Calendar` used for day arithmetic is pinned to UTC.

The model is Calendar 3's `FullCalendar3RegressionTests` (class at `EventSystemTests.swift:1564`): a day-by-day loop at midnight UTC that uses the `days(from:to:)` and `allSurfaceActiveIDs(at:)` helpers (`:1635-1661`). All transitions land on day boundaries, so a daily sample cannot miss one.

Add a new class, **`FullCalendar4RegressionTests`**, in `EventSystemTests.swift` directly after `WeeklyEvents4Month3Tests`, with one test per item:

1. **Never more than 2 batch-4 `EventRegistry` events active**, checked day by day over 2027-06-01 → 2027-08-30 (exclusive). Assert `≤ 2` every day, `sampledDays == 90`, and observed max `== 2`.
2. **No gap in the continuous track:** exactly one of S10/S11/S12 is active on every one of the 90 days.
3. **No gap across the batch seam:** exactly one season (S9 or S10–S12) is active on every day from 2027-05-02 to 2027-08-30, which is 120 days. This proves the S9 → S10 handoff at 2027-06-01.
4. **The weekly track is never dark longer than its own cadence:** walk from 2027-05-28 to 2027-08-31 (95 days) using the 13 new weekly IDs plus `rescue_relay_20270528`. The longest dark run is exactly 3 (asserted `== 3`), which covers the 06-01 → 06-04 seam: dark on 06-01, 06-02, 06-03; live again 06-04 with `playtime_rush_20270604`. The walk ends at 08-31 so instance 13's last day, 08-30, is included.
5. **No two of the 13 new weekly events overlap** (full O(n²) pairwise check), and none overlaps `rescue_relay_20270528`.
6. **Per-registry concurrency, day by day across the same 90 days:**
   - at most 1 Parallel Board instance and at most 1 Drive are active. Count with `allEvents.filter`, not `activeEvent(at:)`.
   - the all-surface total (batch-4 `EventRegistry` events + Parallel Board + Drive) never exceeds 4, and the observed max is **3**, with the peak days pinned to exactly §2.7's 14: 06-18, 06-19, 06-20, 07-09, 07-10, 07-16, 07-17, 07-18, 08-07, 08-08, 08-09, 08-13, 08-14, 08-15.
7. **Every new ID has its table:** the 16 new `EventDefinition` IDs and the 3 new Second Chances IDs each have a `ProgressTrackRegistry.tracks` entry equal to their reference table (Founders' Circle, Adoption Drive, `second_chances_20260911`).
8. **Registry shape:**
   - `EventRegistry.allEvents` has **68** unique IDs, `ParallelBoardEventRegistry` has **12**, and `KibbleDriveRegistry` has **13**;
   - no duplicates in any registry;
   - the existing 52 / 9 / 10 IDs are all present (copy the sets from `FullCalendar3RegressionTests`'s `existing…IDs` plus its `new…IDs`, `EventSystemTests.swift:1566-1620`);
   - exact ID sets equal existing ∪ batch 4.

   This is now the only exact-set pin (see the §3 pin table), and the next batch rewrites it the same way.
9. **Representative spot checks** of the exact active set across all four registries:

   | Date | Expected active set | Why |
   |---|---|---|
   | 2027-06-01 | {S10} | seam day; weekly, Parallel Board and Drive all off |
   | 2027-06-08 | {S10, `second_chances_20270608`} | Parallel Board in a weekly off-period (new shape this batch) |
   | 2027-06-18 | {S10, `playtime_rush_20270618`, `kibble_drive_20270618`} | |
   | 2027-07-01 | {S11} | season handoff, no weekly |
   | 2027-07-09 | {S11, `rescue_relay_20270709`, `second_chances_20270708`} | |
   | 2027-07-31 | {S12, `playtime_rush_20270730`} | straddle boundary |
   | 2027-08-29 | {S12, `playtime_rush_20270827`} | last day of the 90 |
   | 2027-08-30 | batch-4 IDs ∩ active == {`playtime_rush_20270827`} | overrun day; **intersect only** (§3 future-proofing rule) |

Calendar 1's, 2's and 3's tests stay green unchanged, apart from the pins listed in §3.

**On-screen verification:** none of this content is active on the day it lands, so the deterministic tests are the real verification. Natural on-screen confirmation happens on 2027-06-01 in production. A Simulator check before then needs a clock override that the Simulator does not expose (`TODO.md`). Do not seed or fake a save for it.

---

## 5. Acceptance

- [ ] 16 new `EventDefinition`s in `EventRegistry.allEvents`, with dates and IDs exactly as in §2.3/§2.4
- [ ] 3 new `ParallelBoardEventDefinition`s and 3 new `KibbleDriveEventDefinition`s, exactly as in §2.5/§2.6
- [ ] 19 new `ProgressTrackRegistry.tracks` entries, each a verbatim copy of its reference table (§2.8)
- [ ] S9 → S10 → S11 → S12 contiguous, with zero gap and zero overlap; exactly one season active every day 2027-06-01 → 2027-08-30
- [ ] Weekly track never dark more than 3 days, including across the 06-01 → 06-04 seam; instance 13 ends 2027-08-31
- [ ] At most 2 batch-4 `EventRegistry` events, 1 Parallel Board and 1 Drive active on any day, verified day by day
- [ ] All tests use injected dates and UTC-pinned calendars only; no whole-registry assertion on 2027-08-30
- [ ] Every pin in §3's table updated in the same commit that changes the count
- [ ] No production code changed outside the three registries, their doc comments and `ProgressTrackRegistry.tracks`; no schema change (v44)
- [ ] Full suite green
- [ ] **Merged to `main` before 2027-05-15**

---

## 6. Defaults used (no owner questions)

Nothing in this batch needs a new owner decision. The defaults below are the same as batch 3, plus one derived consequence of the phase.

- **Real-world holidays: no special handling** (owner decision for batch 3: none; same here). For the owner's information only, this batch's collisions are:
  - **US/UK Father's Day** (Sun 06-20) and **Juneteenth** (Sat 06-19) fall inside `playtime_rush_20270618` + `kibble_drive_20270618`, a 3-surface peak stretch.
  - **US Independence Day** (Sun 07-04) falls inside `playtime_rush_20270702`.
  - **UK Summer bank holiday** (Mon 08-30) is instance 13's overrun day, with no batch-4 season active until Calendar 5 lands.

  None needs a change. Themed content would mean a new flavor, which is out of scope and would need its own spec.
- **Instance 13 overruns the batch by one day** (§2.4). Derived from the cadence, not a choice; authored here rather than dropped or shortened. Calendar 5's S13 (08-30) turns it into an ordinary straddle.
- **Inherited and unchanged:** both weekly flavors share identical numbers, one name is used across seasons, and two flavors alternate. All were reviewed and accepted in `Spec_Phase6c_Calendar.md` §6 and are not reopened here.
- **Three Drives, again.** Follows from the 28-day phase (§2.6), same as Calendar 3.
- **After 2027-08-30:** the next calendar-authoring pass, same shape again. The seams it inherits are S13 at **2027-08-30**, weekly #1 at **2027-09-03** (Rescue Relay; instance 13 ends 08-31, so 08-31 → 09-03 is the ordinary 3-day gap), Second Chances at **2027-09-06** and the next Drive at **2027-09-10**. Calendar 5's month-1 weekly seam test should measure from `playtime_rush_20270827.endDate` (08-31), not from S12's end. That will be the fourth consecutive manual pass. `Spec_Phase6c_Calendar.md` §0 accepted that recurring cost, and whether to keep paying it is the owner's call, not this spec's.

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

1. **Line numbers in `Spec_Phase7_Calendar3.md` have drifted** with Calendar 3's own additions, as its §8.3 predicted. At `c0ef746`: the running-total pin is `EventSystemTests.swift:855-859` (value `:857`), not `:852-856` (`:854`); the Parallel Board count is `ParallelBoardEventsTests.swift:181`, not `:174`; `ParallelBoardEventRegistry.allEvents` and `KibbleDriveRegistry.allEvents` both start at `:109`, not `:102` / `:103`; `checkEventLifecycle(at:)` is `MergeBoardViewModel.swift:4153`, not `:4113`. This spec cites `c0ef746`; re-find by ID, not by line, as tasks land.
2. **`FullCalendar2RegressionTests` now sits after the Calendar 3 classes** in `EventSystemTests.swift` (class at `:2377`, after `FullCalendar3RegressionTests` at `:1564` and the `WeeklyEvents2Month*Tests` classes at `:1872-2202`). File order no longer matches calendar order. Harmless; Calendar 3 §3.6's status line already recorded the drift. Calendar 4's classes should follow the Calendar 3 block (after `FullCalendar3RegressionTests`, before `WeeklyEvents2Month1Tests`) so the batch-3/batch-4 code reads together.
3. **`Spec_Phase7_Calendar3.md` §5 acceptance checkboxes are all unticked** although its status header says all six tasks are complete (last PR #90). Same pattern as Calendar 2 (its §8.1). Not edited here.
4. **`Spec_Phase7_Calendar3.md` §3.5's status line says 9 new tests in `Calendar3BoardAndDriveTests`; the file holds 8** (lines `:52, :73, :88, :98, :112, :136, :157, :168`). Its own §3.6 status line already notes this. Recorded so the next reader does not count again.
5. **`CLAUDE.md`'s document table** still lists `Spec_Phase6c_Calendar.md` but none of `Spec_Phase7_Calendar2.md`, `Spec_Phase7_Calendar3.md` or this spec (first flagged in Calendar 3 §8.4). Not edited here, because `CLAUDE.md` is out of bounds for this task. Flagged for the owner.
6. **Calendar 3 §6's predicted seams check out against the code:** S10 at 2027-06-01 (`EventSystem.swift:740`), weekly #1 at 2027-06-04 Playtime Rush (`rescue_relay_20270528` ends 06-01, `:940`; 06-04 is a Friday), Second Chances at 2027-06-08 and the next Drive at 2027-06-18 (`kibble_drive_20270521` starts 05-21, `KibbleDriveEvents.swift:179`; the code comment at `:90-91` already names 2027-06-18). No discrepancy; recorded because the seams were verified, not assumed.
7. **Calendar 3 §2.2's description of the weekly phase** (*"The weekly track lines up on its own"*) was true for that batch only. The phase slides 6 days per batch (90 mod 7), so Calendar 4 is the first batch whose instance 13 overruns the season grid (§2.2, §2.4). Not an error in Calendar 3; the next spec should not assume alignment.
