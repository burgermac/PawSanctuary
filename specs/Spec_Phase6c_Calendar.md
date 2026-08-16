# PawSanctuary — Phase 6c: the real 90-day rolling calendar

**Self-contained brief.** Assumes no prior conversation. Follows Phase 6c's concurrent-events prerequisite (`specs/Spec_Phase6c_ConcurrentEvents.md`), which is fully implemented, tested, and design-reviewed as of 16 Aug 2026.

**Written cold by Claude Code at the user's request; design-authority review complete (16 Aug 2026).** Same exception as Pass's, Parallel Board's, and the concurrent-events prereq's own drafts (no prior design-authority spec existed for this task). Review outcome: implementation and target shape both agreed as-is — see §6 for the specific open questions reviewed and accepted without change.

> **Not atomic.** Suggested landing order in §3 below — land as separate commits, verify each, stop if one resists.

**Status (16 Aug 2026): §3.1–§3.2 done, §3.3–§3.5 not started.** The 3 `sanctuary_circle_s*` `EventDefinition`s added to `EventRegistry.allEvents` and their `ProgressTrackRegistry.tracks` entries — verbatim copies of Founders' Circle's 10-milestone table, per §2.2 — added to `LiveOpsEngine.swift`. 6 new tests (`SanctuaryCircleSeasonsTests`, `EventSystemTests.swift`): contiguity (zero gap/overlap across all 3 seasons), 90-day total span, milestone-table presence and verbatim-copy equality, and a scheduler-level check that exactly one season is active at a representative date inside each. One real bug caught while writing these: the first draft of the 90-day span test used a `Calendar` with the device's local timezone against dates parsed as UTC by `ISO8601DateFormatter` — the US's 2026-11-01 DST fall-back (squarely inside this span) shifted the wall-clock delta and made the test read 89 days instead of 90. Fixed by pinning the test's `Calendar` to UTC to match the parser; the underlying calendar data was never wrong, only the test's own arithmetic was.

**§3.2 — weekly track, month 1 (instances 1–4):** `rescue_relay_20260904`, `playtime_rush_20260911`, `rescue_relay_20260918`, `playtime_rush_20260925` added, plus their `ProgressTrackRegistry.tracks` entries — verbatim copies of Adoption Drive's 3-milestone table, per §2.2, same table reused for both flavors. 5 new tests (`WeeklyEventsMonth1Tests`): each is exactly 4 days with a 3-day gap to the next, no two of the 4 overlap each other, each overlaps exactly Season 1 (not zero, not a different season) sampled at both its start and near its end, and each's milestone table matches Adoption Drive's exactly. Applied the same UTC-`Calendar` discipline the §3.1 DST bug taught, throughout, rather than only where it happened to bite.

**§3.3 — weekly track, month 2 (instances 5–9):** `rescue_relay_20261002`, `playtime_rush_20261009`, `rescue_relay_20261016`, `playtime_rush_20261023`, `rescue_relay_20261030` added, same verbatim Adoption Drive table throughout. 9 new tests (`WeeklyEventsMonth2Tests`), most specifically about instance 5's straddle: confirmed it reports exactly Season 1 active at its start and exactly Season 2 active near its end (never both, never neither); confirmed that at the exact boundary instant (2026-10-04, when Season 1 ends and Season 2 begins) exactly 2 events are active — the straddler plus whichever season, never 3 — proving the transition is a clean handoff, not a moment of triple overlap; confirmed instance 9 ends at exactly the same instant Season 2 ends and never spills into Season 3; and added the one cross-batch check neither month's own tests covered in isolation — the 3-day gap from month 1's last instance to month 2's first. All passed on the first run, confirming the calendar's dates and the straddle behavior work exactly as designed.

**§3.4 — weekly track, month 3 (instances 10–13), completing the weekly track:** `playtime_rush_20261106`, `rescue_relay_20261113`, `playtime_rush_20261120`, `rescue_relay_20261127` added, same verbatim Adoption Drive table throughout — all 4 sit entirely inside Season 3, no straddle, same posture as month 1's batch. 7 new tests (`WeeklyEventsMonth3Tests`): duration/gap arithmetic, the month 2→3 cross-batch gap, no overlap among the 4, each overlaps exactly Season 3 throughout, milestone-table match, and a capstone confirming all 13 weekly instances now exist in the registry — landing exactly when the set becomes complete rather than deferred to §3.5. All passed on the first run.

**§3.5 — full-calendar regression tests, the spec's last task — done. All of §3 is now complete.** 7 new tests (`FullCalendarRegressionTests`, test-only — no production code changed): the real invariant this whole spec exists to prove, `testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive`, samples all 90 days at midnight UTC (matching how every date here was authored) and confirms the simultaneously-active count from the new batch never exceeds 2 — and explicitly confirms the observed maximum genuinely reaches 2 rather than the test silently passing on a calendar that never actually overlaps. Also: at least one season active every single day (zero coverage gaps); full O(n²) pairwise no-overlap across all 13 weekly events, not just adjacent pairs; a quiet gap-day spot check; all 16 new IDs confirmed to have a `ProgressTrackRegistry` entry; the 4 legacy events confirmed untouched; and the registry's total shape (20 unique IDs, no accidental duplicates across 20 hand-written literal entries). All passed on the first run. Full suite verified at 325/325 green, 0 regressions across all of §3.1–§3.5. Every §5 acceptance item is now checked. **The spec's implementation is complete**, pending the design-authority review its DRAFT header still flags, and the open questions in §6.

---

## 0. Why

The Alignment Plan's Phase 6c has exactly one remaining item: *"Author a rolling 90-day `EventDefinition` calendar. Infrastructure without a calendar is exactly where you are now."* Everything the calendar needs is now built and proven: the concurrent-events prerequisite closed the single-active-event gap, `EventRegistry.activeEvents` correctly reports every genuinely-active event, `checkEventLifecycle()` registers an independent rider per event, and the UI renders any number of simultaneous event cards via `ForEach`. What's missing is the content itself — real `EventDefinition` entries with real dates, scheduled against D5's cadence.

**D5's cadence, restated:** *"one 3–4 day event per week, one 30-day album/pass running continuously."* Two tracks, running concurrently by construction — not sequential. This spec authors both tracks for a 90-day span: 13 weekly events (7-day cadence, 4-day duration each) layered on top of 3 sequential 30-day Passes (contiguous, zero gap, so the continuous track is never dark).

**What this deliberately is not:** a new content-generation *system*. The Alignment Plan's own risk list warns against exactly that temptation — *"Live-ops scope creep. Six event types is more fun to build than three. Three is the number D5 supports. Resist."* The same instinct applies here: this spec authors a literal, static, hand-editable 90-day batch of `EventDefinition` entries, the same way the three that already shipped were authored — not a procedural scheduler, a recurrence-rule engine, or a content-management layer. Phase 7 ("Ongoing") already names the real cost of this choice: someone re-runs a version of this spec every ~90 days. That's the accepted operating model, not a problem to engineer away.

---

## 1. Decisions and constraints this depends on

- **D5 (cadence):** this spec exists to author what D5 already specified. Nothing here changes D5's numbers.
- **D8 (chain offer):** still undecided (*"depends on D6's reasoning — decide the two together"*, Alignment Plan §3). **Not included in this calendar.** Only the two event types with a decided, shipped, tested mechanic — Milestone track and Pass — appear below.
- **Parallel Board is not ready.** Its spec (`Spec_Phase6b_ParallelBoard.md`) is still DRAFT, not design-authority-reviewed, and **not implemented** — "most of what the spec proposes is still new code with no implementation to check it against" (Alignment Plan §9). A 90-day calendar cannot schedule an event type that doesn't exist yet. **This calendar is Milestone-track and Pass only.** When Parallel Board ships, it's a separate follow-up to layer into this same calendar, not a blocker on landing this one now.
- **The concurrent-events prerequisite is fully shipped** (`b023431`…`e0d2d5c`) — `EventRegistry.activeEvents`, diffed multi-provider rider registration, `ForEach`-based UI, all tested and design-reviewed. This spec is pure content authoring on top of that; it introduces no new mechanism.
- **`EventTimer`/`scheduleExpiryNotification` (Phase 6a) is still unwired** — "nothing wires these into `MergeBoardViewModel`... zero UI call sites" per its own spec. Real events not getting an expiry push notification is a pre-existing gap, not introduced or worsened here. **Out of scope** — flagged, not fixed, same as Phase 3.5/3.6's own "blocked, flagged" items.

---

## 2. Target shape

### 2.1 The two tracks

**Continuous track — "Sanctuary Circle," 3 sequential Passes, zero gap:**

| Cycle | ID | Start | End |
|---|---|---|---|
| Season 1 | `sanctuary_circle_s1_20260904` | 2026-09-04 | 2026-10-04 |
| Season 2 | `sanctuary_circle_s2_20261004` | 2026-10-04 | 2026-11-03 |
| Season 3 | `sanctuary_circle_s3_20261103` | 2026-11-03 | 2026-12-03 |

Starts the instant Founders' Circle (`founders_circle_aug2026`, ends 2026-09-04) goes inactive — same zero-gap convention already used between Adoption Drive and Founders' Circle. 30+30+30 = 90 days exactly, 2026-09-04 → 2026-12-03.

**Weekly track — 13 events, alternating between two flavors, 7-day cadence, 4-day duration, 3-day gap:**

| # | Flavor | ID | Start | End |
|---|---|---|---|---|
| 1 | Rescue Relay | `rescue_relay_20260904` | 2026-09-04 | 2026-09-08 |
| 2 | Playtime Rush | `playtime_rush_20260911` | 2026-09-11 | 2026-09-15 |
| 3 | Rescue Relay | `rescue_relay_20260918` | 2026-09-18 | 2026-09-22 |
| 4 | Playtime Rush | `playtime_rush_20260925` | 2026-09-25 | 2026-09-29 |
| 5 | Rescue Relay | `rescue_relay_20261002` | 2026-10-02 | 2026-10-06 |
| 6 | Playtime Rush | `playtime_rush_20261009` | 2026-10-09 | 2026-10-13 |
| 7 | Rescue Relay | `rescue_relay_20261016` | 2026-10-16 | 2026-10-20 |
| 8 | Playtime Rush | `playtime_rush_20261023` | 2026-10-23 | 2026-10-27 |
| 9 | Rescue Relay | `rescue_relay_20261030` | 2026-10-30 | 2026-11-03 |
| 10 | Playtime Rush | `playtime_rush_20261106` | 2026-11-06 | 2026-11-10 |
| 11 | Rescue Relay | `rescue_relay_20261113` | 2026-11-13 | 2026-11-17 |
| 12 | Playtime Rush | `playtime_rush_20261120` | 2026-11-20 | 2026-11-24 |
| 13 | Rescue Relay | `rescue_relay_20261127` | 2026-11-27 | 2026-12-01 |

The first weekly event starts the same day as Season 1 (2026-09-04) — deliberately, so the calendar demonstrates D5's "concurrently" clause from day one rather than easing into it. The last weekly event ends 2026-12-01, two days before Season 3 (and the 90-day window) ends 2026-12-03 — a minor, accepted tail gap rather than a 14th event forced to fit awkwardly.

**Every weekly-to-weekly gap is exactly 3 days** (event N ends, 3 days pass, event N+1 starts) — genuinely non-overlapping by construction, so no two weekly events are ever simultaneously active. Every weekly event overlaps the continuous track throughout its run, per D5 — but **not always the same season**: since 30 (a season's length) isn't a multiple of 7 (the weekly cadence), one instance, week 5 (Rescue Relay, 2026-10-02 → 2026-10-06), straddles the Season 1→2 boundary (2026-10-04), running under Season 1 for its first two days and Season 2 for its last two. This is verified harmless, not a bug worth hand-tuning away: seasons are contiguous with zero gap, so at every moment exactly one season is active underneath — the straddle just means that season's *identity* changes mid-event, the same transition `checkEventLifecycle()`'s diffing already handles (§4). The simultaneously-active count from this batch never exceeds 2 at any point across the full 90 days, confirmed by day-by-day simulation, not just spot checks — see §4.

### 2.2 Reward-curve reuse, not new numbers

Every number below is a **direct reuse of an already-shipped, already-reviewed reward curve** — deliberately, to avoid the exact "guessing" the Alignment Plan's §0 flags as the real risk in this phase (*"the event catalogue is where guessing starts"*). Nothing here is derived from a new model; it's the existing shipped numbers, re-dated.

- **Sanctuary Circle** (all 3 seasons): **verbatim reuse** of Founders' Circle's 10-milestone table (`ProgressTrackRegistry.tracks["founders_circle_aug2026"]`) — same 10 thresholds (60→600, +60 to +60 spacing), same free/paid reward amounts at every tier, same final `.cardPack` hero reward at milestone 9. Only the track ID changes per season (token wallets and progress are ID-keyed, so each season must have its own key — reusing one ID across all three would make Season 2 open with Season 1's already-maxed progress).
- **Rescue Relay** and **Playtime Rush** (all 13 instances, both flavors): **verbatim reuse** of Adoption Drive's 3-milestone free-lane-only table (`ProgressTrackRegistry.tracks["adoption_drive_aug2026"]`) — thresholds 60/140/220, same free-lane kibble/dog-tag amounts, `paidRewards: []` throughout (matching Adoption Drive's and Foster Weekend's posture — a short weekly event has no business offering its own paid-lane unlock). Both flavors share the exact same numbers; they differ only in name, tagline, icon, and color. This is a deliberate simplification, not an oversight — see §6.

### 2.3 Flavor/cosmetic content (provisional — see §6)

| Field | Rescue Relay | Playtime Rush | Sanctuary Circle |
|---|---|---|---|
| `name` | "Rescue Relay" | "Playtime Rush" | "Sanctuary Circle" |
| `tagline` | "Team up to rescue as many animals as you can this week!" | "Play it up — fulfil orders for bonus rewards this week!" | "A season of rewards for the sanctuary's circle of supporters." |
| `icon` | `"figure.run"` | `"star.circle.fill"` | `"trophy.fill"` (reused from Founders' Circle) |
| `accentColor` | `Color(red: 0.80, green: 0.35, blue: 0.20)` (warm orange-red) | `Color(red: 0.15, green: 0.55, blue: 0.45)` (teal-green) | `Color(red: 0.72, green: 0.50, blue: 0.10)` (reused from Founders' Circle) |
| `gradientColors` | `[Color(red: 1.00, green: 0.92, blue: 0.85), Color(red: 0.97, green: 0.78, blue: 0.65)]` | `[Color(red: 0.85, green: 0.97, blue: 0.93), Color(red: 0.68, green: 0.90, blue: 0.82)]` | reused from Founders' Circle |

`minLevel: 0` and `priority: 0` throughout, matching every existing event — no level gating or contested-slot priority has ever been decided for any event type, and nothing about this calendar changes that.

### 2.4 Target shape table

| Today | Target |
|---|---|
| `EventRegistry.allEvents` has 4 entries: `rescue_rush_jun2026`, `adoption_drive_aug2026`, `founders_circle_aug2026`, `foster_weekend_aug2026` (test-only, expires 2026-08-18) | 4 existing entries **unchanged, not removed** (matches existing convention — expired events stay in the array as inert history, same as `rescue_rush_jun2026`/`adoption_drive_aug2026` today) **plus 16 new entries**: 3 `sanctuary_circle_s*` + 13 weekly events |
| `ProgressTrackRegistry.tracks` has 3 entries: `adoption_drive_aug2026`, `founders_circle_aug2026` (both real content), `foster_weekend_aug2026` (test-only, §4 of the concurrent-events prereq) | **plus 16 new entries**, one per new `EventDefinition` above, each pointing at one of the two reused table shapes in §2.2 |
| Nothing schedules real content past 2026-09-04 (Founders' Circle's end) | Real, active content scheduled through 2026-12-03 |

---

## 3. Tasks, suggested landing order

Each task is additive-only — new array entries, new dictionary keys. No existing code path changes. Every task should build clean and pass the full suite on its own; land them separately per this project's "one task per session" rule rather than batching.

### 3.1 — The continuous track: 3 `sanctuary_circle_s*` events + tracks

Add the 3 `EventDefinition` entries from §2.1's first table to `EventRegistry.allEvents`, and 3 corresponding entries to `ProgressTrackRegistry.tracks`, each an exact copy of Founders' Circle's 10-milestone table (§2.2) under the new season-specific key. Smallest, most mechanical task — good first landing, and it alone proves the "continuous, zero-gap, three cycles" half of the calendar independent of the weekly track.

**Verify:** a synthetic-date test (see §4) confirming the 3 seasons are contiguous with no gap and no overlap between consecutive seasons.

### 3.2 — Weekly events, month 1 (instances 1–4)

Add `rescue_relay_20260904`, `playtime_rush_20260911`, `rescue_relay_20260918`, `playtime_rush_20260925` to `EventRegistry.allEvents`, plus their 4 matching `ProgressTrackRegistry.tracks` entries (all four an exact copy of Adoption Drive's 3-milestone table, per §2.2).

**Verify:** synthetic-date tests confirming each of the 4 is genuinely non-overlapping with its neighbors, and genuinely overlapping with Season 1 throughout.

### 3.3 — Weekly events, month 2 (instances 5–9)

Same pattern: `rescue_relay_20261002` through `rescue_relay_20261030` (5 instances). This batch contains the one weekly event that straddles a season boundary — instance 5 (`rescue_relay_20261002`) runs under Season 1 for its first two days and Season 2 for its last two, per §2.1. Instance 9 (`rescue_relay_20261030`) ends exactly as Season 2 ends (2026-11-03) — contained cleanly within Season 2, not a second straddle.

### 3.4 — Weekly events, month 3 (instances 10–13)

Same pattern: `playtime_rush_20261106` through `rescue_relay_20261127` (4 instances), completing the 13-event weekly track.

### 3.5 — Full-calendar regression tests

One task dedicated to the cross-cutting invariants that only make sense once every entry from 3.1–3.4 exists — see §4 for the specific tests. Distinct from the per-batch spot-checks in 3.1–3.4 because these need the whole calendar assembled to be meaningful (e.g. "at no point across the full 90 days are more than 2 events simultaneously active" can't be asserted from a partial calendar).

---

## 4. Verification approach — and why it's stronger here than the prerequisite's

The concurrent-events prerequisite's own tests were necessarily guarded/probabilistic in places (`EventRegistry.activeEvents` isn't injectable — it reads the real wall clock against the real hardcoded list, so proving "two events overlap" meant guarding on today's real date actually falling in a real overlap window). **This spec doesn't have that problem.** Once the calendar's `EventDefinition`s exist in the real `EventRegistry.allEvents`, their dates are fixed, static data — `EventScheduler(events: EventRegistry.allEvents).activeEvents(at:)` can be queried at *any* synthetic date, past or future, with a fully deterministic, non-probabilistic expected answer. Every test below should use this pattern, not the real wall clock.

Recommended tests (exact set to be finalized when 3.5 lands, once all entries exist to check against):

- Every consecutive pair of `sanctuary_circle_s*` events is contiguous: season N's `endDate` equals season N+1's `startDate`, for all 3 seasons.
- No two weekly events (any of the 13) are ever simultaneously active — for every pair, one's `endDate` is at or before the other's `startDate`.
- Every weekly event overlaps a season somewhere in its run (proving the "always overlapping with the continuous track" half of D5's cadence claim, not just asserted in prose) — but **not** "fully contained within exactly one season": §2.1 identifies one weekly event (`rescue_relay_20261002`) that straddles the Season 1→2 boundary by construction (30 isn't a multiple of 7), so a test asserting full containment for all 13 would be asserting something false. Assert the weaker, actually-true thing instead.
- **The real invariant that matters:** across the full 90 days, day-by-day (not just spot-checked), the count of simultaneously-active events from this new batch never exceeds 2 — proving D5's "concurrently" pairing stays exactly weekly+continuous even through the one straddling instance, never accidentally 3-way. Spot checks alone would risk missing exactly the boundary day this matters most for.
- Spot-check `activeEvents(at:)` at a handful of representative dates across the 90 days (a weekly-event day, a gap day, a season boundary, and the straddle day itself) returns exactly the expected ID set — including confirming `rescue_relay_20261002` pairs with `sanctuary_circle_s1` on 2026-10-02/03 and with `sanctuary_circle_s2` on 2026-10-04/05, the same event ID throughout, just a different season partner.
- `ProgressTrackRegistry.tracks` has an entry for every one of the 16 new `EventDefinition` IDs — no event silently missing its milestone table (which would show a card with permanently-0 `maxTokens`, a real and easy-to-miss authoring mistake at this volume).

**On-screen verification:** unlike the prerequisite, this spec's content is dated in the future relative to today (2026-08-16) — nothing in it is active *right now*, so there is nothing to screen-verify at landing time the way Foster Weekend's overlap was screen-verified. The deterministic tests above are the real verification for this spec; on-screen confirmation naturally happens organically as each date arrives in production, the same way every prior event's actual firing was never separately "simulator-verified in advance" either.

---

## 5. Acceptance

- [x] All 16 new `EventDefinition` entries added to `EventRegistry.allEvents`, dates matching §2.1 exactly
- [x] All 16 new `ProgressTrackRegistry.tracks` entries added, each reusing one of the two table shapes from §2.2 verbatim — `testAllSixteenNewEventsHaveAMatchingProgressTrack`
- [x] The 3 `sanctuary_circle_s*` events are contiguous — zero gap, zero overlap, covering 2026-09-04 → 2026-12-03 — `SanctuaryCircleSeasonsTests`, §3.1
- [x] No two of the 13 weekly events are ever simultaneously active — `testNoTwoOfAllThirteenWeeklyEventsEverOverlapFullPairwise`, full O(n²) pairwise, not just adjacent
- [x] No more than 2 events from this new batch are ever simultaneously active at any point across the full 90 days, verified day-by-day rather than spot-checked — true even through `rescue_relay_20261002`, the one weekly event that straddles the Season 1→2 boundary and so overlaps parts of two different seasons across its 4-day run — `testAtNoPointAcrossTheFullNinetyDaysAreMoreThanTwoNewBatchEventsActive`, all 90 days sampled, max observed count confirmed to genuinely reach exactly 2 (not just staying under a loose bound)
- [x] Existing 4 events untouched — no regressions to `rescue_rush_jun2026`/`adoption_drive_aug2026`/`founders_circle_aug2026`/`foster_weekend_aug2026` — `testExistingFourLegacyEventsAreUntouched`
- [x] Full test suite green, including the new §4 regression tests — 325/325
- [x] No UI/registry code changes needed — confirms the concurrent-events prerequisite was genuinely sufficient infrastructure, not just sufficient for a 2-event proof case — §3.1–§3.5 landed as pure additive content, zero lines changed outside `EventRegistry.allEvents`/`ProgressTrackRegistry.tracks`/tests

---

## 6. Open questions for design-authority review

**Resolved 16 Aug 2026: reviewed and accepted as written, no changes requested.** Left in place below as the record of what was explicitly reviewed rather than silently decided, per the working method's "record the reasoning so it doesn't get relitigated" principle (Alignment Plan §3).

- **Both weekly flavors share identical numbers** (§2.2) — differing only in cosmetic presentation. This was a deliberate choice to avoid inventing an unmodelled reason for one to pay more than the other, but it does mean "Rescue Relay" and "Playtime Rush" are mechanically the same event wearing two skins. If real variety is wanted (harder/richer alternating weeks, a different faucet mechanic, etc.), that's a new number this spec didn't derive and shouldn't guess at.
- **Flavor names/taglines/icons/colors** were picked for internal consistency with existing naming, not derived from a model — reviewed and kept as-is. The structural cadence (§2.1) was always the part that actually mattered and is independent of naming; a future rebrand would only touch cosmetic fields, not dates or reward tables.
- **"Sanctuary Circle" reuses "Sanctuary Circle" as the name for all 3 seasons** rather than 3 distinct names (real games often do this — "Season 1/2/3" of one recurring pass brand — but it's a judgment call, not a measured one).
- **The two-flavor, alternating-week structure** (vs. e.g. three or four flavors in rotation, or fully bespoke weekly content) was chosen to keep the total new design surface small, matching this phase's own stated risk mitigation. More flavors is easy to add later; this spec deliberately didn't reach for it up front.
- **What happens after 2026-12-03**, when this 90-day batch runs out, is explicitly Phase 7's problem (Alignment Plan §10) — another calendar-authoring pass, structurally identical to this one, not a new mechanism.

---

## 7. Out of scope

- Parallel Board content — Parallel Board itself isn't implemented; nothing here can schedule it. Revisit this calendar once it ships.
- D8 (chain offer) content — still undecided per D6/D8's joint dependency.
- `EventTimer`/expiry-notification wiring — pre-existing gap (Phase 6a's `EventTimer`/`scheduleExpiryNotification` have zero call sites), not introduced or worsened here, not fixed here either.
- Any change to `EventRegistry.currentEvent`, `activeEvents`, `checkEventLifecycle()`, or any UI call site — the concurrent-events prerequisite already built and proved everything this content needs; this spec adds zero new mechanism.
- Retiring or removing the 4 existing (mostly expired) `EventDefinition` entries — left in place, matching existing convention for historical/inert events.
- A 14th weekly event to close the 2026-12-01→2026-12-03 tail gap — accepted as a minor, deliberate simplification (§2.1).
