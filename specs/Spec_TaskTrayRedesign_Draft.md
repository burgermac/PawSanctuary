# PawSanctuary — Task tray redesign (draft)

**Status: draft, no code written.** Fifth in the reference-review series, after `Spec_PartyBoard_Draft.md`, `Spec_BoardAnimation_Draft.md`, `Spec_OrdersAndTasks_Draft.md` and `Spec_TravelTownReview_Draft.md`. Not yet entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log.

This spec closes `Spec_TravelTownReview_Draft.md` §3, which flagged `TaskStripView` as real UX debt but offered three options without evaluating them. None of those three is what this spec proposes — the design here came from a new Tasty Travels capture plus a set of decisions taken in review on 31 Aug 2026, recorded in §3.

## 0. Source material

`ScreenRecording_08-31-2026 12-30-46_1.MP4` (21.2s, 1206×2622 @ 59.9fps) — **Tasty Travels**, player level 50.

Analysed with `scripts/refvideo.swift`: contact sheet at 1s, then native-resolution crops of the top band — a 0.15s sweep across the tray collapse (1.8→3.6s), a 0.15s sweep across the expand (10.6→12.4s), and a 0.8s sweep across the full vertical scroll (12.5→20.5s).

**Attribution note.** This clip was first read as Gossip Harbor during review and corrected to Tasty Travels. The correction is consistent with the footage: the order cards carry the multi-item baskets and per-order token values that `Spec_OrdersAndTasks_Draft.md` §1–§2 were built from, both of which are Tasty Travels conventions.

---

## 1. What the reference actually does

Six findings, all measured off the frames rather than inferred.

**1.1 Collapse changes width only — the band height is constant.** Expanded and collapsed, the panel occupies the same vertical band (~445px of 2622, ≈17% of screen height) and the board's top edge never moves. Compare `crop_001.95` (3-wide) against `crop_003.30` (1-wide): identical panel top and bottom. The tray is **not** an overlay that grows down over the board.

**1.2 Collapse is a horizontal translation of one grid, not a second view.** At 2.55s the panel slides left and the **third column** survives at the left edge — the same two tiles that occupied column 3, rows 1–2 of the expanded grid, at the same scroll offset. This is one view translated, not a curated rail swapped in for a grid.

**1.3 Viewport is 2 rows; content was 4 rows × 3 columns = 10 tiles.** Row 4 held a single tile (event ticket, `3d 16h`) sitting in **column 3**, not column 1 — so either the final partial row is trailing-aligned, or ordering is not plain row-major. Unresolved from this footage; see §8.

**1.4 The dots are a continuous position indicator, not pages.** `crop_011.35` is caught mid-scroll with row 1 clipped at the top and row 3 clipped at the bottom — free scrolling, not snapped. Three dots for 4 rows against a 2-row viewport = `rows − visible + 1` positions. Observed green dot: top at 1.95s, middle at 13.30s, bottom at 15.70s. The dots sit on the panel's **left edge**, on a small rounded tab protruding from the panel.

**1.5 Tile status is icon + one status element.** The status is a countdown (`16h 29m`, `03:59:24`, `2d 16h`), a fraction (`7/12`, `0/3`), or a bar (battle pass, the 900-potion). Some tiles carry a red dot badge for "action available" (tiki mask, 15.70s). Fractions and bars render **inside** the tile; countdowns hang on a pill **below** it.

**1.6 Daily tasks are ONE aggregate tile.** The `0/3` checklist tile represents the whole daily set, not one tile per task.

---

## 2. The vertical budget — the binding constraint

The board height is fixed by decision (§3.2), so the tray must fit in the band between the HUD and the board. That band is already fully committed.

**2.1 The board sits exactly at its constraint crossover.** With `cellSpacing = 4` and a 9×7 board (`AnimalSpecies.swift:1617`) on a 393×852 screen, against `cs = max(32, min(csW, csH))` at `MergeBoardView.swift:559-562`:

```
csW = floor((393 − 16 − 24) / 7)  = 50
csH ≈ floor((527 − 72) / 9)       ≈ 50
```

The board is neither height-bound nor width-bound — it is at the balance point, so **every point of vertical taken shrinks cells immediately**. The `csH` figure is an estimate (the bottom storage bar height is assumed), and §9 calls for confirming it on device; the conclusion that there is no slack does not depend on the exact value.

**2.2 Where the 116pt comes from.** The header is already a single `HStack` (`MergeBoardView.swift:398`). Its ~51pt height comes from its tallest children being three lines each:

| Element | Lines | Source |
|---|---|---|
| Kibble card | count + regen countdown | `MergeBoardView.swift:404-420` |
| Centre stats | Rescued / Ambassadors / coins | `MergeBoardView.swift:430-445` |
| Dog Tags card | count + "Dog Tags" / "Pass Active" | `MergeBoardView.swift:454-472` |
| Shop button | icon + label | `MergeBoardView.swift:484-494` |

Flattening all of these to single-line pills takes the header to ~32pt.

```
97pt  (today's TaskStripView band: taskCardHeight 85 + 12)
+19pt (freed from the header)
─────
116pt available for the tray
```

**2.3 At 40pt tiles this fits with headroom — but only with the status inset.** Two layouts against the 116pt budget:

| Layout | Row height | Band | Verdict |
|---|---|---|---|
| 40pt tile, status **inset** at tile bottom | 40 | `12 + 40 + 6 + 40 = 98pt` | Fits, **18pt spare**, net zero vs. today |
| 40pt tile + 14pt pill **below** | 57 | `12 + 57 + 6 + 57 = 132pt` | Over budget by 16pt |

So the baseline is the inset layout at **~98pt**, which costs the board nothing at all and is in fact 1pt cheaper than today's strip.

**2.4 The consequence, and the one open call.** At a 40pt tile, an inset status has room for a bar, or a label of about four characters — `7/12`, `0/3`, `3/5` all work. **Full countdowns do not**: `16h 29m` and `03:59:24` need roughly 7pt type to fit inside a 40pt tile, which is not legible. The reference renders those on external pills, but it does so under 60pt tiles.

Three ways out, in preference order:

1. **Abbreviate countdowns to ≤4 characters** — `16h`, `2d`, `4m`. Loses minute-level precision on timers measured in hours, which is the majority of them. Costs nothing.
2. **Spend the headroom on a 12pt external pill** for countdown tiles only — band goes to ~122pt, ~6pt over budget, costing the board roughly 1pt per cell. Mixed layout (some tiles taller than others) complicates the grid.
3. **Countdown as a depleting bar** with no text, exact time shown only in the tile's sheet. Cleanest visually, least informative.

**Recommendation: (1).** A player deciding whether to open a tracker needs the order of magnitude, not the minute; the exact figure is one tap away in the sheet. It also keeps every tile a uniform 40pt, which is what makes the translate-to-collapse in §1.2 a single clean geometry.

**This is the only decision in this spec still open.** See §8.1.

---

## 3. Decisions taken

Taken in review 31 Aug 2026. Recorded here because several deviate from the reference or from this spec's own first proposal.

**3.1 Collapse keeps column 3, matching the reference.** An earlier proposal was to collapse toward column 1 instead, so the resting rail would show the two highest-priority trackers rather than whatever happens to occupy the trailing column. **Rejected — follow the reference.** Column 3 survives, and the collapse is implemented as the §1.2 translation.

> **Reversed 1 Sep 2026 — collapse now keeps column 1.** Not a change of mind about the reference, but a consequence of §3.12: once tiles were urgency-sorted, keeping column 3 showed positions 3 and 6 and left the badged, claimable tile off screen. The two decisions were individually reasonable and jointly wrong. See §8.6 for the diagnosis and the options considered. Everything else about §3.1 stands — the collapse is still the single-view narrowing of §1.2, just anchored at the other edge (`.leading` rather than `.trailing`).

**3.2 Board height is fixed.** The tray must fit above the board without shrinking it. This is what forces §2 and rules out the reference-faithful 56pt tile, which would have cost ~4pt per cell.

**3.3 Tile size is 40pt.** Chosen over 56pt precisely to hold §3.2. See §2.4 for what this costs.

**3.4 The horizontal lane carries orders, not quests.** Confirmed. The lane becomes one card per active `AdoptionOrder` — 4 base slots on the easy/medium/medium/hard pattern, growing with Sanctuary Map upgrades, plus the urgent order (`AdoptionBoard.swift:31-52`). This replaces today's single summary `AdoptionOrdersTaskCard` that opens a sheet.

**3.5 Quests and daily challenges move to the tray.** Both are progress trackers with no per-item board action, so they belong in the tray rather than the lane.

**3.6 Quests and dailies aggregate to one tile each.** Not separately decided — **forced by 3.3**. A 40pt tile holds an icon and a four-character status; three quest tiles would be three identical icons distinguished only by a fraction. This matches finding §1.6, and takes the tray from 16 tiles to 12. Today's `ForEach(viewModel.dailyChallenges)` and `ForEach(viewModel.activeQuests)` (`PanelViews.swift:2051-2058`) each collapse to a single tile showing `n/3`.

**3.7 `RetireProducerTaskCard` is deleted outright.** Dragging a producer to storage is already the canonical retirement path — the hint text at `MergeBoardViewModel.swift:669` reads "Drag off-board to move to storage", and the comment at `:712` confirms family spawners are "still retirable by dragging to the storage basket". The `retirableProducers` computed property is only a **nudge** list. Deleting the card removes discovery, not capability. `retirableProducers` (`MergeBoardViewModel.swift:703-721`) becomes dead and goes with it.

**3.8 `AmbassadorTrioTaskCard` moves into the tray.** It has no progress bar and is a transient claim action, so it is the one tray tile that is a button rather than a tracker. Its status field shows the coin value.

**3.9 Rescued and Ambassadors move to a new profile sheet.** No profile surface exists today — there is no `ProfileView`, and neither `SheetRoute` (`MergeBoardView.swift:1533`) nor `TaskSheet` (`PanelViews.swift:1192`) has a profile case. This is new scope, not a move, and it is what makes the single-line HUD possible.

**3.10 Coins stay in the HUD, centre, on the same row as kibble and dog tags.** The three currency pills read left-to-right as kibble · coins · dog tags.

**3.11 Countdowns render as a depleting bar, with no text.** Decided 31 Aug 2026, resolving §8.1 — option 3 of the three that section offered. This keeps every tile a uniform 40pt and avoids the abbreviation compromise, at the cost of the two consequences below.

*Denominators exist.* A bar needs the full interval where text needed only the remainder. Both countdown tiles can supply one: Free Chest from `freeChestCooldownHours` (`AnimalSpecies.swift:2000`), events from `EventDefinition.startDate`/`endDate` (`EventSystem.swift:42-43`). Verified before adopting.

*Accepted consequence — a bar has no scale.* Two-thirds full reads identically whether the timer runs four hours or seven days, and a seven-day bar barely moves between sessions. The mitigation is that the tile's icon identifies which tracker it is, so the player knows the scale from what they are looking at, and the exact figure is one tap away in the sheet. Worth revisiting if playtesting shows people mis-reading long timers as stalled.

*Countdown bars are tinted differently from progress bars* so "time draining away" and "progress earned" are not the same visual language on adjacent tiles.

**3.12 Tiles are sorted by urgency.** Decided 31 Aug 2026, resolving §8.2. Because the tray spends most of its time collapsed showing one column (§3.1), the tiles visible at rest are decided by sort position — so ordering is what a player sees by default, not a cosmetic preference. (Written when collapse still kept column 3; §8.6 then moved it to column 1 precisely so this sort would reach the resting view.)

*The instability §8.2 warned about is handled by sorting into coarse buckets, not on a continuous score.* Four ranks — something to collect, a window closing, progress under way, idle — with ties broken by a fixed catalogue order. A tile therefore only moves when it crosses a bucket boundary, which is a real change of state worth showing, rather than drifting every time a bar ticks. A continuous sort would have reshuffled the tray under the player's thumb.

*"Something to collect" is the badge*, so the rank and the red dot can never disagree — one derives from the other.

---

## 4. Target layout

```
┌──────────────────────────────────────────────────────────────┐
│ [lvl] │ 🐾 115  4:32 │  🪙 8,320  │  🏷 7 │        [Shop]     │  ~32pt  single row
├──────────────────────────────────────────────────────────────┤
│ ┌─────────────────────┐ ┌────────────────────────────────┐   │
│ •│ ▣  ▣  ▣ │          │ │  Order card    │  Order card   │   │  ~98pt  tray + lane
│ •│ ▣  ▣  ▣ │          │ │                │               │   │
│ •└─────────────────────┘ └────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                      board — unchanged                       │
```

**Tray geometry.** Expanded: `3 × 40 + 2 × 8 + 12 = 144pt` wide. Collapsed: `40 + 12 ≈ 52pt`. Band height ~98pt in both states (§1.1).

**Lane width.** 393 − 144 = ~249pt with the tray expanded; ~341pt collapsed. At ~150pt per order card that is 1.6 and 2.2 cards visible respectively — comparable to the reference, which shows 2–3.

**Right-hand cluster deliberately omitted.** The reference floats an event portal and offer pack over the right end of the lane (order cards scroll behind them, visible comparing 2.25s to 3.00s). PawSanctuary's equivalents — active event, Parallel Board, Reward Ladder — are tray tiles here instead. Adding a third pinned surface is out of scope; see §7.

---

## 5. Tile inventory

Twelve tiles for a mid-to-late-game player, four rows, three scroll positions — the same shape as the reference's 10 tiles in 4 rows.

| # | Tile | Status field | Condition | Replaces |
|---|---|---|---|---|
| 1 | Level Progress | bar | always | `LevelProgressTaskCard` |
| 2 | Free Chest | countdown | always | `FreeChestTaskCard` |
| 3 | Spotlight | `n/N` | always | `SpotlightTaskCard` |
| 4 | Quests | `n/3` | always | 3 × `QuestTaskCard` (§3.6) |
| 5 | Daily Challenges | `n/3` | always | 3 × `DailyChallengeTaskCard` (§3.6) |
| 6 | Smile Points | bar | always | `SmilePointsTaskCard` |
| 7 | Care Points | bar | always | `CarePointsTaskCard` |
| 8 | Weekly Goal | bar | always | `WeeklyGoalTaskCard` |
| 9 | Monthly Goal | bar | always | `MonthlyGoalTaskCard` |
| 10 | Event | countdown | per active event | `EventTaskCard` |
| 11 | Parallel Board | bar | when live | `ParallelBoardTaskCard` |
| 12 | Reward Ladder | `n/6` | when available | `RewardLadderTaskCard` |
| 13 | Loyalty | `n/N` | when unlocked | `LoyaltyTaskCard` |
| 14 | Invite | `n/N` | when unlocked | `InviteTaskCard` |
| 15 | Ambassador Trio | coin value | per exchangeable trio | `AmbassadorTrioTaskCard` (§3.8) |
| 16 | Pass Daily Claim | red dot | when claimable | `PassDailyClaimView` (§6.5) |

Ordering is unresolved — see §8.2.

---

## 6. Tasks

One per session, per the project working rules. Each must leave the game playable.

**6.1 — Flatten the HUD to a single row, add the profile sheet.** Three single-line currency pills (kibble · coins · dog tags) plus level badge and Shop button. Kibble pill carries a compact trailing regen countdown. Rescued and Ambassadors move to a new `ProfileView` behind a new `SheetRoute.profile`, opened from the level badge. "Pass Active" becomes a tint on the dog-tag pill rather than a second line. Verify the header measures ~32pt on device.

**6.2 — Build the tile primitive.** `TrayTileView`: 40pt square, icon, inset status (bar / ≤4-char label per §2.4), optional red dot badge. Pure presentation, no view-model coupling.

**6.3 — Build the tray container.** `TaskTrayView`: 3-wide `LazyVGrid` in a fixed ~98pt 2-row viewport with free vertical scrolling; collapse/expand by narrowing to one column (§1.2, §3.1 — column 1, per the §8.6 reversal); position dots on the left-edge tab, `rows − 2 + 1` of them. Collapsed state persists in `UserDefaults`, **not** `GameState` — no schema bump, no migration.

> **Done, and it absorbed the always-present half of 6.4.** The split above was wrong: a container with nothing in it cannot be verified on screen any more than 6.2's tile could, and this project has no SwiftUI previews. 6.3 therefore also migrated §5 rows 1–9 and removed those nine cards from `TaskStripView`, so nothing is duplicated. 6.4 is now the conditional tiles only.
>
> **Implementation note — do not use `.offset` for the collapse.** The first attempt translated the grid with `.offset`, which moves rendering but not layout or hit-testing: the collapsed tray drew column 3 at the leading edge while its tap target stayed two columns right, and column 2's invisible target answered touches over the visible tile. It also broke vertical scrolling, because the `ScrollView`'s own hit region was displaced off the tiles, so drags landed on button targets instead of the scroller. Narrowing the frame with `.trailing` alignment moves the layout, and `.contentShape(Rectangle())` after `.clipped()` stops the off-screen columns staying touchable — `.clipped()` clips drawing only.

**6.4 — Migrate the conditional tiles.** §5 rows 10–14: events, Parallel Board, Reward Ladder, Loyalty, Invite. Each keeps its existing `activeSheet` / `showParallelBoard` / `onOpenShop` tap route.

> **Done.** Conditionals sort ahead of the always-present tiles within a rank, because they are the transient ones — an event window closes, the weekly goal will still be there tomorrow.
>
> **A tile with both a bar and a deadline shows the bar, and the deadline sets its rank.** Events and the Parallel Board are the only tiles with both, and there is one status slot. Progress is the part the player can act on, so it takes the slot; the countdown is not lost, it expresses itself by pushing the tile up the tray as the window closes. Showing the countdown instead would have been the more literal reading of the reference but would have hidden the only number the player can change.
>
> Verified on screen: event tile (opens its sheet), Reward Ladder (`3/6`, opens the Shop rather than a sheet), Invite (present, ranked idle, found by scrolling to row 3). **Loyalty and Parallel Board could not be reached** — Loyalty is gated above level 5, and Parallel Board needs a live event window, which `TODO.md` records as blocked until 2026-09-11. Both are built identically to the three that were verified.

**6.5 — Migrate the two irregular tiles.** `AmbassadorTrioTaskCard` → tray button tile (§3.8). `PassDailyClaimView` → tray tile; it currently inserts an entire conditional strip at `MergeBoardView.swift:524-528` that would break the fixed band height whenever it appears.

> **Done.** Both old views were deleted rather than left dead, since nothing else referenced them.
>
> Claim tiles sort ahead of everything within a rank — they always rank `.claimable`, are pure "collect this", and disappear the moment they are used.
>
> **Neither could be verified on screen, for different reasons.** Ambassador trios need three top-tier animals of one species on the board, which is real play rather than a state that can be arranged. The Pass daily needs an active Sanctuary Pass, and `isPassActive` turns out to be **derived from StoreKit entitlements, not persisted** — `StoreManager.checkPassEntitlement()` runs on init and `MergeBoardView.swift:300` syncs it across. Editing the save cannot fake it, and it is correct that it cannot: the entitlement is the source of truth and a persisted copy would be forgeable. **Do not "fix" this by adding `isPassActive` to `GameState`.** Seeing the tile needs a StoreKit purchase under a proper Xcode Run, which `TODO.md` already records as outstanding for the Reward Ladder.
>
> What was confirmed: removing the Pass strip leaves the header at one row and the band at its fixed height, so the layout no longer shifts when a claim comes up — the reason this migration mattered beyond tidiness.

**6.6 — Build the order lane.** One card per `AdoptionOrder` plus the urgent order, replacing the single `AdoptionOrdersTaskCard`. Reuses the per-line basket rendering already shipped in `Spec_OrdersAndTasks_Draft.md` §1.

**6.7 — Delete the old surfaces.** `TaskStripView` (`PanelViews.swift:2011-2100`), `RetireProducerTaskCard` (§3.7), `MergeBoardViewModel.retirableProducers` (`:703-721`), and the `taskCardWidth` / `taskCardHeight` constants (`PanelViews.swift:1227-1228`).

---

## 7. Out of scope

- **The reference's floating right-hand cluster** (§4). Its contents are tray tiles here.
- **Order card visual redesign.** The lane reuses the basket rendering already shipped; only the container changes.
- **Per-currency reward flight animations** — `Spec_TravelTownReview_Draft.md` §2, which belongs with `Spec_BoardAnimation_Draft.md` Tier A.
- **The milestone celebration and "Almost there!" nudge** — `Spec_TravelTownReview_Draft.md` §4–§5.
- **Any schema change.** Nothing here touches a persisted shape; collapsed state is `UserDefaults` (§6.3). If that turns out to be wrong, the rule in `CLAUDE.md` applies — version bump, migration, `PersistenceTests` case.

---

## 8. Open questions

**8.1 Countdown legibility at 40pt (§2.4).** ~~Abbreviate to ≤4 characters, spend the 18pt headroom on an external pill, or drop to a bar. Recommendation is abbreviate. **Blocks 6.2.**~~ — **Resolved 31 Aug 2026: depleting bar, no text.** Option 3 was taken over this section's own recommendation. See §3.11 for the decision and the two consequences accepted with it.

**8.2 Tile ordering.** ~~Fixed order, or sorted by urgency?~~ — **Resolved 31 Aug 2026: urgency-sorted.** See §3.12.

**8.6 §3.1 and §3.12 pull against each other — the collapsed tray hides the urgent tiles.** Found on screen once both were implemented, 31 Aug 2026.

Urgency sorting puts the most urgent tile at position 1. Collapsing to column 3 shows positions **3 and 6**. So the sort's whole purpose — surface what needs attention — is defeated in exactly the state the tray spends most of its time in. Observed directly: with Free Chest claimable and ranked first with a red badge, the collapsed tray showed Daily Challenges and Spotlight, and the badge was off screen.

The two decisions are individually reasonable and jointly wrong. Four ways out:

1. **Collapse toward column 1** — the resting pair becomes positions 1 and 4, the two most urgent. This was §8.2's original recommendation, rejected in §3.1 in favour of matching the reference. It is the only option where both decisions keep their intent; it costs only fidelity to Tasty Travels, which sorts its own tray differently (its collapsed column is not an urgency top-2 either).
2. **Fill the grid column-major**, so reading order runs down each column and position 1 lands in column 3. Keeps the reference's collapse, but the expanded grid then reads top-to-bottom-then-across, which no other list in this app does.
3. **A dedicated collapsed view** showing the top 2 by rank regardless of grid position. Abandons the single-translation model (§1.2) and reintroduces the two-layouts-to-keep-in-sync problem.
4. **Accept it** — the collapsed tray is a launcher, not a status display, and the player expands it to see what needs doing.

**Recommendation: 1.** It is a two-line change, and it makes the collapsed state answer "what needs me?" instead of "what happens to be third?".

> **Resolved 1 Sep 2026: option 1 taken.** Collapse now keeps column 1, so the resting pair is positions 1 and 4. §3.1 carries the reversal note. The single-view narrowing of §1.2 is unchanged — only the anchor edge moved.
>
> **What this costs:** the tray is no longer a faithful copy of Tasty Travels' collapse. That is a smaller loss than it first appears, because the reference does not appear to urgency-sort its own tray — its collapsed column is not a top-2 by anything. Copying its collapse while sorting differently was reproducing the mechanism without the reason for it.

**8.3 Row 4 alignment in the reference (§1.3).** The single leftover tile sat in column 3, not column 1. Trailing-aligned final row, non-row-major fill, or an artefact of that tile's sort position — unresolved, and worth one more look at a longer capture before copying it.

**8.4 What triggers collapse and expand.** Unobserved in the reference, which collapsed at ~2.5s and expanded at ~11s with no visible cause in frame. **Partly settled by implementation (Task 6.3): tapping the leading-edge handle toggles it**, which is unambiguous and keeps tile taps meaning "open this tracker". The handle carries the position dots when open and a chevron when shut. Still open: whether board interaction should *auto*-collapse it, as the reference appears to. Needs a capture with touch indicators enabled.

**8.5 Whether the tray belongs on the left at all.** `Spec_TravelTownReview_Draft.md` §3 records Travel Town running a permanently-visible vertical column of ~4 cards down the left side, next to the board rather than above it. That is a different answer to the same problem, and it does cost board width. This spec follows Tasty Travels; the Travel Town shape is not evaluated here.

---

## 9. Acceptance

1. Header measures ~32pt; all three currencies on one row with coins centre (§3.10).
2. Tray band measures ~98pt; **board cell size is unchanged from today's build** — verify `cs` on device before and after, confirming the §2.1 estimate.
3. Tray expands to 3-wide and collapses to column 3 by translation, preserving scroll offset across the transition.
4. Vertical scroll is free, not snapped; dot count is `rows − 2 + 1` and tracks position continuously.
5. Every tile opens the same sheet its predecessor card did.
6. Order lane shows one card per order; the urgent order is distinguishable.
7. A producer can still be retired by dragging it to storage after `RetireProducerTaskCard` is gone (§3.7).
8. `PassDailyClaimView` appearing does not change the band height (§6.5).
