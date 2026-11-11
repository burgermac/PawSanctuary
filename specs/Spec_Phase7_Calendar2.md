# PawSanctuary — Phase 7: the second 90-day calendar (2026-12-03 → 2027-03-03)

**Status: Draft spec, ready to implement, no code written.** Written 10 Nov 2026.

**Self-contained brief.** Assumes no prior conversation. This is the follow-up `specs/Spec_Phase6c_Calendar.md` §6 names in advance: *"What happens after 2026-12-03, when this 90-day batch runs out, is explicitly Phase 7's problem (Alignment Plan §10) — another calendar-authoring pass, structurally identical to this one, not a new mechanism."* That is all this spec is. Same tracks, same curves, same names, same ID convention, same verification method, re-dated for the next 90 days, plus the two event layers that shipped after the first calendar (Parallel Board and Kibble Drive), each in its own existing registry.

> **Deadline: implementation merged before 2026-12-01.** The continuous track goes dark at 2026-12-03 00:00 UTC and the next Kibble Drive window opens 2026-12-04. A build carrying this content has to be on players' devices before then, and `checkEventLifecycle()` is launch-only (see §1), so "merged on 12-02" is already late.

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

---

## 0. Why: the content cliff

Every event layer currently in the code runs out within the next three weeks. Each date below was checked against the code, not taken from a spec:

| Layer | Last scheduled window | Ends | Where |
|---|---|---|---|
| Kibble Drive | `kibble_drive_20261106` | **2026-11-09 (already ended)** | `PawSanctuary/KibbleDriveEvents.swift:109-115` (end date at `:114`) |
| Parallel Board | `second_chances_20261110` | **2026-11-13** | `PawSanctuary/ParallelBoardEvents.swift:111-118` (end date at `:117`) |
| Weekly track | `rescue_relay_20261127` | **2026-12-01** | `PawSanctuary/EventSystem.swift:431-444` (end date at `:436`) |
| Continuous track | `sanctuary_circle_s3_20261103` | **2026-12-03** | `PawSanctuary/EventSystem.swift:224-237` (end date at `:229`) |

After 2026-12-03 `EventRegistry.allEvents` (`EventSystem.swift:96`), `ParallelBoardEventRegistry.allEvents` (`ParallelBoardEvents.swift:94`) and `KibbleDriveRegistry.allEvents` (`KibbleDriveEvents.swift:94`) have nothing active at any date. The Pass, the weekly milestone track, the parallel board and the Drive all silently disappear, with no error and no failing test — every existing calendar test samples only dates up to 2026-12-03.

**What this deliberately is not:** a recurrence engine, a procedural scheduler, or a content system. `Spec_Phase6c_Calendar.md` §0 already rejected that and named the accepted cost: someone re-runs this pass every ~90 days. This spec is that re-run.

---

## 1. Decisions and constraints this depends on

- **D5 (cadence)**, unchanged: one 3–4 day event per week, one 30-day pass running continuously. Nothing here changes D5's numbers.
- **Parallel Board cadence** (design authority, 17 Aug 2026, `Spec_Phase6c_Calendar.md` §7 and the doc comment at `ParallelBoardEvents.swift:52-93`): monthly, one instance per Sanctuary Circle season, 3 days long, **starting 7 days into its paired season**.
- **Kibble Drive cadence** (`Spec_KibbleDrive_Draft.md` §4; implemented at `KibbleDriveEvents.swift:50-93`): 3-day windows about four weeks apart. The shipped spacing is **exactly 28 days** (09-11 → 10-09 → 11-06). This spec keeps 28. §4's argument is that rarity is load-bearing: weekly, the Drive becomes the kibble economy and §3.5's ~3.9× margin stops being a margin.
- **Concurrency is a per-registry rule, not an all-surface cap** (see §2.6). Both separate registries were built expecting to overlap the main calendar.
- **No new mechanism.** `EventScheduler.activeEvents(at:)`, `checkEventLifecycle(at:)` (`MergeBoardViewModel.swift:4113`), the rider providers, the Parallel Board coordinator and the Drive lifecycle already handle any number of dated entries. This spec adds array entries and dictionary keys only.
- **Launch-only lifecycle** (pre-existing, `MergeBoardViewModel.swift:4093-4100`): a window opening while the app is already running is picked up on the next launch. Not changed here, but it is why the deadline above has slack built in.
- **`EventTimer`/expiry-notification wiring is still unwired** (Phase 6a). Pre-existing gap, out of scope, same as in the first calendar.

---

## 2. Target shape

### 2.1 ID and date conventions (reused exactly)

- IDs are `<flavor>_<yyyymmdd of startDate>`; seasons are `sanctuary_circle_s<N>_<yyyymmdd>`. Every window gets its own ID because progress, token wallets, `ParallelBoardSaveState` and `KibbleDriveState` are all keyed by event ID — a reused ID would open a new window already filled from the last one.
- Dates are `date("yyyy-MM-dd")` via each registry's private `ISO8601DateFormatter` with `.withFullDate`, which parses as **midnight UTC**. `startDate` is inclusive, `endDate` exclusive (`date >= start && date < end`).
- `minLevel: 0`, `priority: 0` throughout, `milestones: []` on every new `EventDefinition` (real milestone data lives in `ProgressTrackRegistry.tracks`).

### 2.2 Continuous track — Sanctuary Circle S4–S6, 30 days each, zero gap

| Cycle | ID | Start | End |
|---|---|---|---|
| Season 4 | `sanctuary_circle_s4_20261203` | 2026-12-03 | 2027-01-02 |
| Season 5 | `sanctuary_circle_s5_20270102` | 2027-01-02 | 2027-02-01 |
| Season 6 | `sanctuary_circle_s6_20270201` | 2027-02-01 | 2027-03-03 |

S4 starts the instant S3 ends (`EventSystem.swift:229`) — the same zero-gap handoff S1→S2→S3 already use. 30 + 30 + 30 = 90 days exactly (December's 31 days and February 2027's 28 are both accounted for: 12-03 + 30 = 01-02, 01-02 + 30 = 02-01, 02-01 + 30 = 03-03).

### 2.3 Weekly track — 13 events, alternating, 7-day cadence, 4-day duration, 3-day gap

| # | Flavor | ID | Start | End | Season(s) underneath |
|---|---|---|---|---|---|
| 1 | Playtime Rush | `playtime_rush_20261204` | 2026-12-04 | 2026-12-08 | S4 |
| 2 | Rescue Relay | `rescue_relay_20261211` | 2026-12-11 | 2026-12-15 | S4 |
| 3 | Playtime Rush | `playtime_rush_20261218` | 2026-12-18 | 2026-12-22 | S4 |
| 4 | Rescue Relay | `rescue_relay_20261225` | 2026-12-25 | 2026-12-29 | S4 |
| 5 | Playtime Rush | `playtime_rush_20270101` | 2027-01-01 | 2027-01-05 | **S4 → S5** (straddles 01-02) |
| 6 | Rescue Relay | `rescue_relay_20270108` | 2027-01-08 | 2027-01-12 | S5 |
| 7 | Playtime Rush | `playtime_rush_20270115` | 2027-01-15 | 2027-01-19 | S5 |
| 8 | Rescue Relay | `rescue_relay_20270122` | 2027-01-22 | 2027-01-26 | S5 |
| 9 | Playtime Rush | `playtime_rush_20270129` | 2027-01-29 | 2027-02-02 | **S5 → S6** (straddles 02-01) |
| 10 | Rescue Relay | `rescue_relay_20270205` | 2027-02-05 | 2027-02-09 | S6 |
| 11 | Playtime Rush | `playtime_rush_20270212` | 2027-02-12 | 2027-02-16 | S6 |
| 12 | Rescue Relay | `rescue_relay_20270219` | 2027-02-19 | 2027-02-23 | S6 |
| 13 | Playtime Rush | `playtime_rush_20270226` | 2027-02-26 | 2027-03-02 | S6 |

**Phase and alternation continue the first calendar unbroken.** The last existing weekly event is `rescue_relay_20261127` (11-27 → 12-01), so the next on the 7-day cadence starts 12-04 and is a Playtime Rush. Every weekly event is therefore a Friday-start, exactly as all 13 existing ones are.

**The 2026-12-01 → 2026-12-03 "tail gap" is closed by continuing the cadence, not by adding an event.** `Spec_Phase6c_Calendar.md` §2.1 called 12-01 → 12-03 a tail gap because its 90-day window ended there; with the cadence carried across the batch boundary, 12-01, 12-02, 12-03 are simply the regular 3-day off-period between instance 13 of batch 1 and instance 1 of batch 2, identical to every other gap in both calendars. Read precisely, "no day without a weekly event" cannot hold under D5's 4-on/3-off shape without retuning the 4-day duration (out of scope); what this spec guarantees, and tests (§4), is that **the weekly track is never dark for more than the cadence's own 3 days**, including across the batch seam. Rejected alternative: starting batch 2 on 12-01 to touch `rescue_relay_20261127`'s end. That produces a 0-day gap once and then a 4-day dark tail at 02-27 → 03-03, moving the anomaly rather than removing it, and breaks the "every gap is exactly 3 days" property the first calendar's tests assert.

**Two straddles, not one.** 30 is not a multiple of 7, so the season boundary drifts against the weekly cadence; this batch happens to put two boundaries (01-02 and 02-01) inside a weekly event. Same harmless shape as `rescue_relay_20261002` in the first calendar: seasons are contiguous, so exactly one season is active underneath at every instant, and only its identity changes mid-event.

### 2.4 Parallel Board — "Second Chances", one per season

| Season | ID | Start | End |
|---|---|---|---|
| S4 | `second_chances_20261210` | 2026-12-10 | 2026-12-13 |
| S5 | `second_chances_20270109` | 2027-01-09 | 2027-01-12 |
| S6 | `second_chances_20270208` | 2027-02-08 | 2027-02-11 |

Each starts 7 days into its paired season (12-03 + 7, 01-02 + 7, 02-01 + 7) and runs 3 days, exactly the rule at `ParallelBoardEvents.swift:74-75`. `name: "Second Chances"`, `icon: "arrow.triangle.2.circlepath"`, `chainID: ContentRegistry.parallelBoardSecondChancesChainID`, verbatim from the existing three entries.

**The 2026-11-13 → 2026-12-10 Parallel Board gap is by design and gets no window.** The cadence is one instance per season, S3's instance (`second_chances_20261110`) already exists, and the cadence puts S4's at 12-10. The resulting 27-day dark period matches the existing ones exactly (09-14 → 10-11 and 10-14 → 11-10 are also 27 days). Adding a window inside it would be a fourth instance in S3, i.e. a cadence change, which the design authority set and this spec does not touch.

### 2.5 Kibble Drive — 3-day windows, 28 days apart

| Instance | ID | Start | End |
|---|---|---|---|
| 4 | `kibble_drive_20261204` | 2026-12-04 | 2026-12-07 |
| 5 | `kibble_drive_20270101` | 2027-01-01 | 2027-01-04 |
| 6 | `kibble_drive_20270129` | 2027-01-29 | 2027-02-01 |
| 7 | `kibble_drive_20270226` | 2027-02-26 | 2027-03-01 |

`name: "Kibble Drive"`, `icon: "shippingbox.fill"`, verbatim. **No per-window content is needed**: the ladder is one global table (`KibbleDriveLadder.rungs`, `KibbleDriveLadder.swift:33-49`), not keyed by event ID, so a Drive window is a registry entry and nothing else.

**The gap since 2026-11-09.** The first new window is the first date the shipped 28-day spacing allows after `kibble_drive_20261106`: 11-06 + 28 = **2026-12-04**. That is after 2026-12-01, so the cadence does **not** fit a window before 12-01. The 11-09 → 12-04 dark period is 25 days, the same as every existing inter-Drive gap (28 − 3). The only way to land one before 12-01 is to shorten the spacing to 21 days (`kibble_drive_20261127`, 11-27 → 11-30) — the minimum `KibbleDriveLifecycleTests.testInstancesAreAboutFourWeeksApartNotWeekly` (`KibbleDriveLifecycleTests.swift:62-68`) allows. Not taken by default: it changes a shipped number (the 28-day spacing that §3.5's +2.6% amortised supply figure is computed against), it needs the build live by 11-27 rather than by 12-01, and 21 days is the reference's "2–3 weeks" rather than §4's "~4 weeks". Recorded as an open question (§6), not decided here.

The 28-day cadence is a multiple of 7, so every Drive starts on a weekly-event start day (Fridays), the same phase relationship the existing three Drives have.

### 2.6 Concurrency — the max-concurrent rule, as the code defines it

There is no single all-surface cap in the code. The rules that exist, and that this calendar must keep, are per registry:

1. **`EventRegistry` batch: at most 2 active** (one season + at most one weekly), asserted day-by-day by `FullCalendarRegressionTests.testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive` (`PawSanctuaryTests/EventSystemTests.swift:753-780`).
2. **Parallel Board: at most 1 active** — `ParallelBoardEventRegistry.activeEvent(at:)` returns `.first` (`ParallelBoardEvents.swift:126-128`), and `ParallelBoardCalendarLayerTests.testNoTwoSeasonalInstancesEverOverlap` asserts non-overlap (`PawSanctuaryTests/ParallelBoardEventsTests.swift:189-194`).
3. **Kibble Drive: at most 1 active** — same `.first` shape (`KibbleDriveEvents.swift:123-125`), non-overlap asserted by `KibbleDriveLifecycleTests.testWindowsAreThreeDaysLongAndNoneOverlap` (`KibbleDriveLifecycleTests.swift:46-57`).
4. **Overlap across registries is allowed, deliberately.** `KibbleDriveEvents.swift:61-70` records that a "never share days with another premium offer" rule was written once, found to be unsourced and contradicting `Spec_KibbleDrive_Draft.md` §4, and removed; `KibbleDriveLifecycleTests.testOverlapWithOtherEventSurfacesIsAllowed` (`:82-89`) asserts the permission.

This calendar keeps rules 1–3 on every day. By construction the all-surface ceiling is 4; the observed maximum in this batch is **3** (e.g. 2026-12-04: S4 + `playtime_rush_20261204` + `kibble_drive_20261204`). No new Parallel Board window coincides with a new Drive window. For comparison the first calendar peaked at 4 on 2026-09-11 → 09-13 (S1 + `playtime_rush_20260911` + `second_chances_20260911` + `kibble_drive_20260911`). The tests in §4 assert rules 1–3 and record the all-surface figure without capping it, since a cap would be a new rule.

### 2.7 Reward-curve reuse, not new numbers

Every number is an existing, shipped table, re-keyed per ID:

- **Sanctuary Circle S4–S6:** verbatim copy of Founders' Circle's 10-milestone table, `ProgressTrackRegistry.tracks["founders_circle_aug2026"]` (`LiveOpsEngine.swift:142-192`) — thresholds 60…600, both lanes, `.cardPack` (`star4`) hero on milestone 9. Same as S1–S3 (`:333-485`).
- **All 13 weekly events, both flavors:** verbatim copy of Adoption Drive's 3-milestone free-lane-only table, `ProgressTrackRegistry.tracks["adoption_drive_aug2026"]` (`LiveOpsEngine.swift:121-133`) — thresholds 60/140/220, `paidRewards: []`.
- **Second Chances ×3:** verbatim copy of the existing 8-milestone free-lane-only table (`LiveOpsEngine.swift:229-260`) — thresholds 20…160 in steps of 20.
- **Kibble Drive ×4:** no table to add; `KibbleDriveLadder.rungs` is global (above).

Flavor/cosmetic fields are copied from the existing entries, unchanged:

| Field | Rescue Relay | Playtime Rush | Sanctuary Circle |
|---|---|---|---|
| `name` | "Rescue Relay" | "Playtime Rush" | "Sanctuary Circle" |
| `tagline` | "Team up to rescue as many animals as you can this week!" | "Play it up — fulfil orders for bonus rewards this week!" | "A season of rewards for the sanctuary's circle of supporters." |
| `icon` | `"figure.run"` | `"star.circle.fill"` | `"trophy.fill"` |
| `accentColor` | `Color(red: 0.80, green: 0.35, blue: 0.20)` | `Color(red: 0.15, green: 0.55, blue: 0.45)` | `Color(red: 0.72, green: 0.50, blue: 0.10)` |
| `gradientColors` | `[Color(red: 1.00, green: 0.92, blue: 0.85), Color(red: 0.97, green: 0.78, blue: 0.65)]` | `[Color(red: 0.85, green: 0.97, blue: 0.93), Color(red: 0.68, green: 0.90, blue: 0.82)]` | `[Color(red: 1.00, green: 0.96, blue: 0.85), Color(red: 0.96, green: 0.85, blue: 0.60)]` |

Copy them from `EventSystem.swift:248-260` (Rescue Relay), `:262-274` (Playtime Rush) and `:224-237` (Sanctuary Circle) rather than retyping.

### 2.8 The full window table

Every window in 2026-12-03 → 2027-03-03, all four layers, by start date:

| Start | End | Layer | ID |
|---|---|---|---|
| 2026-12-03 | 2027-01-02 | Continuous | `sanctuary_circle_s4_20261203` |
| 2026-12-04 | 2026-12-08 | Weekly #1 | `playtime_rush_20261204` |
| 2026-12-04 | 2026-12-07 | Kibble Drive | `kibble_drive_20261204` |
| 2026-12-10 | 2026-12-13 | Parallel Board | `second_chances_20261210` |
| 2026-12-11 | 2026-12-15 | Weekly #2 | `rescue_relay_20261211` |
| 2026-12-18 | 2026-12-22 | Weekly #3 | `playtime_rush_20261218` |
| 2026-12-25 | 2026-12-29 | Weekly #4 | `rescue_relay_20261225` |
| 2027-01-01 | 2027-01-05 | Weekly #5 (straddle) | `playtime_rush_20270101` |
| 2027-01-01 | 2027-01-04 | Kibble Drive | `kibble_drive_20270101` |
| 2027-01-02 | 2027-02-01 | Continuous | `sanctuary_circle_s5_20270102` |
| 2027-01-08 | 2027-01-12 | Weekly #6 | `rescue_relay_20270108` |
| 2027-01-09 | 2027-01-12 | Parallel Board | `second_chances_20270109` |
| 2027-01-15 | 2027-01-19 | Weekly #7 | `playtime_rush_20270115` |
| 2027-01-22 | 2027-01-26 | Weekly #8 | `rescue_relay_20270122` |
| 2027-01-29 | 2027-02-02 | Weekly #9 (straddle) | `playtime_rush_20270129` |
| 2027-01-29 | 2027-02-01 | Kibble Drive | `kibble_drive_20270129` |
| 2027-02-01 | 2027-03-03 | Continuous | `sanctuary_circle_s6_20270201` |
| 2027-02-05 | 2027-02-09 | Weekly #10 | `rescue_relay_20270205` |
| 2027-02-08 | 2027-02-11 | Parallel Board | `second_chances_20270208` |
| 2027-02-12 | 2027-02-16 | Weekly #11 | `playtime_rush_20270212` |
| 2027-02-19 | 2027-02-23 | Weekly #12 | `rescue_relay_20270219` |
| 2027-02-26 | 2027-03-02 | Weekly #13 | `playtime_rush_20270226` |
| 2027-02-26 | 2027-03-01 | Kibble Drive | `kibble_drive_20270226` |

23 windows: 16 `EventDefinition`s, 3 `ParallelBoardEventDefinition`s, 4 `KibbleDriveEventDefinition`s.

### 2.9 Target shape table

| Today | Target |
|---|---|
| `EventRegistry.allEvents`: 20 entries, last ends 2026-12-03 | 20 existing **unchanged, not removed** + 16 new = **36** |
| `ParallelBoardEventRegistry.allEvents`: 3, last ends 2026-11-13 | 3 existing unchanged + 3 new = **6** |
| `KibbleDriveRegistry.allEvents`: 3, last ended 2026-11-09 | 3 existing unchanged + 4 new = **7** |
| `ProgressTrackRegistry.tracks`: one key per existing event | **+19 keys**: 16 for the new `EventDefinition`s, 3 for the new Second Chances windows. None for the Drive. |
| Nothing scheduled after 2026-12-03 | Real content through 2027-03-03 on every layer |

### 2.10 Persisted shape: no change

No `GameState` field, Codable type, or schema version changes (schema stays at **v44**, `GameStore.swift:388`). Everything new is static registry data. Each piece of persisted state that touches events is already keyed by an event-ID `String` and handles an unseen ID: rider-provider bookkeeping and token wallets (ID-keyed), `ParallelBoardSaveState` (`GameStore.swift:249`, restored only when `saved.eventID == event.id`, `MergeBoardViewModel.swift:4132-4141`), and `KibbleDriveState` (`GameStore.swift:260`, recreated when the ID differs, forfeited when no window is open, `:4150-4175`). No migration, no `PersistenceTests` case. If implementation finds otherwise, stop and raise it — it would be a mechanism change, out of scope.

---

## 3. Tasks, suggested landing order

Same shape as `Spec_Phase6c_Calendar.md` §3, with one task added for the two layers that live in their own registries (in the first calendar they landed afterwards, as §7's Parallel Board addendum and the Drive's own §6 step 3a). Each task is additive only — new array entries, new dictionary keys, new tests. Each must build clean and pass the full suite on its own. One task per session, per working rule 1.

### 3.1 — Continuous track: `sanctuary_circle_s4/s5/s6` + tracks

Add the 3 `EventDefinition`s from §2.2 to `EventRegistry.allEvents`, after `rescue_relay_20261127`, with a comment block in the style of `EventSystem.swift:187-195` pointing at this spec. Add 3 `ProgressTrackRegistry.tracks` entries, each a verbatim copy of Founders' Circle's table under the new key.

**Same commit, required:** `FullCalendarRegressionTests.testRegistryHasExactlyTwentyUniqueEventIDsNoDuplicates` (`EventSystemTests.swift:846-850`) pins the count at 20, so it fails as soon as any entry is added. Change it to the running total for this commit (23) and rename it to describe a count rather than "twenty", or rewrite it to assert `20 + new-batch count`; 3.5/3.6 bring it to 36. This is the only existing `EventRegistry` assertion that the additive change breaks; every other existing calendar test checks subsets or samples dates before 2026-12-03.

**Verify (new `SanctuaryCircleSeasons2Tests`):** S3's end equals S4's start, and S4→S5→S6 are contiguous with zero gap and zero overlap; S4 start → S6 end is 90 days measured with a **UTC-pinned `Calendar`** (the first calendar's §3.1 DST bug: the US clocks fall back on 2026-11-01, and an unpinned device-local calendar miscounts across it); each table equals Founders' Circle's; at 2026-12-15, 2027-01-15 and 2027-02-15 exactly the matching season is active.

### 3.2 — Weekly events, month 1 (instances 1–4, December)

`playtime_rush_20261204`, `rescue_relay_20261211`, `playtime_rush_20261218`, `rescue_relay_20261225`, plus 4 `ProgressTrackRegistry` entries, each Adoption Drive's table verbatim.

**Verify (new `WeeklyEvents2Month1Tests`):** each is 4 days with a 3-day gap to the next; **the cross-batch seam** — `rescue_relay_20261127.endDate` to `playtime_rush_20261204.startDate` is exactly 3 days; alternation continues (batch 1 ends on Rescue Relay, batch 2 starts on Playtime Rush); no two of the 4 overlap; each overlaps exactly S4 throughout; tables match Adoption Drive's.

### 3.3 — Weekly events, month 2 (instances 5–9, January)

`playtime_rush_20270101`, `rescue_relay_20270108`, `playtime_rush_20270115`, `rescue_relay_20270122`, `playtime_rush_20270129`, plus tables. **This batch holds both straddles.**

**Verify (new `WeeklyEvents2Month2Tests`):** durations, gaps, and the month 1→2 seam; instance 5 has exactly S4 active on 01-01 and exactly S5 active on 01-03/01-04; instance 9 has exactly S5 on 01-29/01-31 and exactly S6 on 02-01; at the exact boundary instants 2027-01-02 and 2027-02-01, exactly 2 `EventRegistry` events are active (the straddler + one season), never 3; instances 6–8 overlap only S5.

### 3.4 — Weekly events, month 3 (instances 10–13, February)

`rescue_relay_20270205`, `playtime_rush_20270212`, `rescue_relay_20270219`, `playtime_rush_20270226`, plus tables. All inside S6, no straddle. Instance 13 ends 2027-03-02, one day before S6 ends; the next calendar's first weekly event (3 days later, 2027-03-05) closes that the same way §2.3 closes 12-01 → 12-03.

**Verify (new `WeeklyEvents2Month3Tests`):** durations, gaps, the month 2→3 seam, no overlap, each inside S6, tables match; capstone: all 13 new weekly IDs exist.

### 3.5 — Parallel Board and Kibble Drive windows

Append the 3 `ParallelBoardEventDefinition`s from §2.4 to `ParallelBoardEventRegistry.allEvents` and 3 `ProgressTrackRegistry` entries (Second Chances' 8-milestone table, verbatim). Append the 4 `KibbleDriveEventDefinition`s from §2.5 to `KibbleDriveRegistry.allEvents`. Extend both registries' doc-comment tables (`ParallelBoardEvents.swift:78-82`, `KibbleDriveEvents.swift:72-76`) with the new rows. Two separate commits are fine if preferred; both are pure data.

**Same commit, required:** `ParallelBoardCalendarLayerTests.testAllThreeSeasonalInstancesExistInTheRegistry` pins `ParallelBoardEventRegistry.allEvents.count` at 3 (`ParallelBoardEventsTests.swift:163-168`). Extend that class's `seasonalIDs` and `pairedSeasonIDs` (`:147-157`) with the three new instances and their seasons, and change the count to 6. Its other tests then cover the new windows automatically (3 days each, inside the paired season, no overlap, same name/chain, identical table). No Drive test pins a count; `testInstancesAreAboutFourWeeksApartNotWeekly` and `testWindowsAreThreeDaysLongAndNoneOverlap` iterate the whole registry and cover the new windows unchanged.

**Verify (new tests):** each new Second Chances instance starts exactly 7 days after its season's start; the 11-13 → 12-10 Parallel Board gap contains no window (`activeEvent(at:)` is nil at 2026-11-20 and 2026-12-05); each new Drive starts exactly 28 days after the previous one, counted from `kibble_drive_20261106`; no Drive window opens between 2026-11-09 and 2026-12-04; `checkEventLifecycle(at: 2026-12-05)` creates `KibbleDriveState(eventID: "kibble_drive_20261204")` and no Parallel Board coordinator; `checkEventLifecycle(at: 2026-12-11)` creates a coordinator for `second_chances_20261210` and no Drive. Use the existing `GameStore.clear()` setUp/tearDown pattern from `KibbleDriveLifecycleTests.swift:30-38` for the lifecycle cases.

### 3.6 — Full-calendar regression tests

Cross-cutting invariants that only mean something once 3.1–3.5 are all in — see §4. Test-only; no production code.

---

## 4. Verification approach

Same method as the first calendar (`Spec_Phase6c_Calendar.md` §4): every date in these registries is static data, so every assertion queries a **synthetic, injected date** — `EventScheduler(events: EventRegistry.allEvents).activeEvents(at:)`, `ParallelBoardEventRegistry.activeEvent(at:)`, `KibbleDriveRegistry.activeEvent(at:)`, `MergeBoardViewModel.checkEventLifecycle(at:)`. **Never `Date()`, `EventRegistry.activeEvents`, `currentEvent`, `isActive`, or `timeRemaining`** — those read the wall clock and are what made earlier tests rot (`TODO.md`'s resolved test-rot entry; `KibbleDriveEvents.swift:118-122`). Every `Calendar` used for day arithmetic is pinned to UTC.

The model is `FullCalendarRegressionTests.testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive` (`PawSanctuaryTests/EventSystemTests.swift:753-780`, class at `:725`): a day-by-day loop at midnight UTC that counts active IDs from the batch, asserts the bound every day, counts the samples, and asserts the observed maximum actually reaches the bound so the test cannot pass on a calendar that never overlaps. All transitions land on day boundaries, so a daily sample cannot miss one.

New class **`FullCalendar2RegressionTests`** in `EventSystemTests.swift`, alongside the first one:

1. **Never more than 2 `EventRegistry` events from batch 2 active**, day by day from 2026-12-03 to 2027-03-03 (exclusive): asserts `≤ 2` every day, `sampledDays == 90`, and observed max `== 2`. Direct mirror of `:753`.
2. **No gap in the continuous track, 2026-12-03 → 2027-03-03:** exactly one of S4/S5/S6 active on every one of the 90 days.
3. **No gap across the batch seam:** exactly one season (S3 or S4–S6) active on every day from 2026-11-03 to 2027-03-03 — proves S3 → S4 hands off with nothing missing at 2026-12-03.
4. **Weekly track never dark longer than its own cadence:** walking day by day from 2026-11-27 to 2027-03-02, the longest run of days with no weekly event active is exactly 3 (asserted `== 3`, not just `≤ 3`, so the test checks real gaps).
5. **No two of the 13 new weekly events overlap**, full O(n²) pairwise; and none overlaps `rescue_relay_20261127`.
6. **Per-registry concurrency, day by day across the same 90 days:** at most 1 Parallel Board instance and at most 1 Drive active (count with `allEvents.filter`, not `activeEvent(at:)`, which returns `.first` and would hide an overlap). Also record the all-surface total (season + weekly + Parallel Board + Drive) and assert it never exceeds 4 (the construction ceiling) and that the observed max is 3. The `== 3` is a pin on this calendar's shape so an accidental re-dating shows up in review, not a new product rule; if a later calendar intends a 4-way overlap (as 2026-09-11 had), change the pin.
7. **Every new ID has its table:** all 16 new `EventDefinition` IDs and all 3 new Second Chances IDs have a `ProgressTrackRegistry.tracks` entry, and each equals its reference table (Founders' Circle, Adoption Drive, `second_chances_20260911`). A missing table shows a card with a permanently-0 denominator — the authoring mistake most likely at this volume.
8. **Registry shape:** `EventRegistry.allEvents` has 36 unique IDs; `ParallelBoardEventRegistry.allEvents` 6; `KibbleDriveRegistry.allEvents` 7; no duplicate IDs in any of them; the existing 20 / 3 / 3 IDs all still present.
9. **Representative spot checks** returning the exact active set across all four registries: 2026-12-04 (S4 + weekly #1 + Drive), 2026-12-09 (S4 only — a quiet day), 2026-12-11 (S4 + weekly #2 + Second Chances), 2027-01-02 (S5 + weekly #5, the straddle boundary; Drive still active), 2027-02-01 (S6 + weekly #9; Drive just ended — `kibble_drive_20270129` ends 02-01, exclusive).

The first calendar's tests stay green unchanged except for the two pinned counts named in §3.1 and §3.5.

**On-screen verification:** none of this content is active on the day it lands, so — as with the first calendar — the deterministic tests are the real verification. Natural on-screen confirmation happens 2026-12-03/04 in production. If a Simulator check is wanted before then, it needs a clock override the Simulator does not expose (see `TODO.md`); do not seed or fake a save for it.

---

## 5. Acceptance

- [ ] 16 new `EventDefinition`s in `EventRegistry.allEvents`, dates and IDs exactly as §2.2/§2.3
- [ ] 3 new `ParallelBoardEventDefinition`s and 4 new `KibbleDriveEventDefinition`s, exactly as §2.4/§2.5
- [ ] 19 new `ProgressTrackRegistry.tracks` entries, each a verbatim copy of its reference table (§2.7)
- [ ] S3 → S4 → S5 → S6 contiguous, zero gap, zero overlap; exactly one season active every day 2026-12-03 → 2027-03-03
- [ ] Weekly track never dark more than 3 days, including across the 12-01 → 12-04 seam
- [ ] At most 2 batch-2 `EventRegistry` events, 1 Parallel Board and 1 Drive active on any day, verified day by day, observed `EventRegistry` max confirmed to reach 2
- [ ] All tests use injected dates only
- [ ] The two pinned counts (`EventSystemTests.swift:846-850`, `ParallelBoardEventsTests.swift:163-168`) updated in the same commits that change the counts
- [ ] No production code changed outside the three registries and `ProgressTrackRegistry.tracks`; no schema change
- [ ] Full suite green
- [ ] **Merged to `main` before 2026-12-01**

---

## 6. Open questions

- **A Drive before 12-01?** §2.5 keeps the shipped 28-day spacing, so the next Drive is 2026-12-04. A 21-day spacing would allow `kibble_drive_20261127` (11-27 → 11-30). That is a cadence decision, not a calendar-authoring one, and it changes the number §3.5's amortised supply impact is computed against; it needs the owner's call. If taken, the rest of §2.5 should be re-derived from the new phase (e.g. 11-27, 12-25, 01-22, 02-19), not patched one row.
- **Inherited, unchanged:** both weekly flavors share identical numbers; one name across seasons; two-flavor alternation. All reviewed and accepted in `Spec_Phase6c_Calendar.md` §6 and not reopened here.
- **After 2027-03-03:** the next calendar-authoring pass, same shape again. Natural seams it inherits: weekly #1 at 2027-03-05 (Rescue Relay), S7 at 2027-03-03, Second Chances at 2027-03-10, the next Drive at 2027-03-26.

---

## 7. Out of scope

- New event flavors, names, icons, colors, or event types.
- Retuning any number: durations, cadences (7-day weekly, 30-day season, 3-day Parallel Board at +7 days, 28-day Drive), reward tables, ladder rungs, prices.
- `EventTimer` / `scheduleExpiryNotification` wiring — pre-existing gap from Phase 6a, untouched.
- Any new mechanism: no recurrence rules, generated schedules, mid-session lifecycle polling, changes to `EventScheduler`, `EventRegistry.currentEvent`/`activeEvents`, `checkEventLifecycle()`, the coordinators, or any UI call site.
- Any persisted-shape change (§2.10). None is needed; if one turns out to be, stop.
- Removing or editing any existing registry entry (expired entries stay as inert history, per convention).
- A cap on all-surface concurrency (§2.6) — no such rule exists, and inventing one is what `KibbleDriveEvents.swift:61-70` records undoing.
- The Kibble Drive's outstanding StoreKit gaps (`TODO.md`: no `com.pawsanctuary.kibbledrive` entry in `PawSanctuary.storekit`, App Store Connect registration, the real-Xcode-Run purchase check). They predate this calendar and apply equally to the windows already shipped.

---

## 8. Spec-vs-code discrepancies found while writing this

Per `CLAUDE.md`: where a spec and the code disagree, the code was checked and wins.

1. **`Spec_KibbleDrive_Draft.md` §4** says the Drive is "scheduled in the existing 90-day rolling calendar (`Spec_Phase6c_Calendar.md`)". It is not: it lives in its own `KibbleDriveRegistry` (`KibbleDriveEvents.swift:43-126`), and `Spec_Phase6c_Calendar.md` has no Drive entry (its §7 addendum covers Parallel Board only). This spec is the first calendar document that schedules Drive windows.
2. **`Spec_KibbleDrive_Draft.md` §4 says "~4-week cadence"**; the code is exactly 28 days, and the test floor is 21 (`KibbleDriveLifecycleTests.swift:62-68`). This spec follows the code (28).
3. **`Spec_Phase6c_Calendar.md` §4/§5's "never more than 2 simultaneously active"** reads as a global rule but is scoped to that batch's `EventRegistry` IDs only (`EventSystemTests.swift:762`, `.intersection(newBatchIDs)`). Counting the separate registries the first calendar peaked at 4 (2026-09-11 → 09-13). Not a bug — cross-registry overlap is intended (`KibbleDriveEvents.swift:61-70`) — but §2.6 states the rule as the code actually enforces it.
4. **`Spec_Phase6c_Calendar.md` §2.4/§5** describe `EventRegistry` as 20 entries, and `EventSystemTests.swift:846-850` hard-codes 20; `ParallelBoardEventsTests.swift:167` hard-codes 3. Both are correct today and both must change with this batch (§3.1, §3.5).
5. **`Spec_Phase6c_Calendar.md` §1** still says "Parallel Board is not ready … not implemented". Stale since 17 Aug 2026; its own §7 addendum records the shipped Parallel Board layer.
6. **`Spec_Phase6c_Calendar.md` §2.1** calls 12-01 → 12-03 a "tail gap". With the cadence continued across batches it is the ordinary 3-day weekly off-period (§2.3).
7. **`CLAUDE.md` working rule 4** says `GameStore` is at schema v24; the code is at **v44** (`GameStore.swift:388`). Not touched by this spec; noted for whoever next edits `CLAUDE.md`.
