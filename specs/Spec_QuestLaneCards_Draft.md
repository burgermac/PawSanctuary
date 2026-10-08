# PawSanctuary — Quest cards on the horizontal lane (draft)

**Status: draft, no code written.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log. Written 7 Oct 2026 from a direct design decision by the developer, not from reference footage.

This spec **amends three recorded decisions** in `Spec_TaskTrayRedesign_Draft.md`: §3.4 ("the horizontal lane carries orders, not quests. Confirmed"), §3.5 ("quests and daily challenges move to the tray") and §3.6 (quests aggregate to one tile). Those were reasoned decisions, so §2 below restates why each is being overridden or kept rather than silently dropping them.

## 0. Provenance

`Spec_TaskStripRedesign_Draft.md` measured the Tasty Travels clip the tray was built from and found the described two-axis design (quests on the horizontal lane, always-present trackers as vertical thumbnails) matches the tray **except that the reference's lane carries orders**; the one quest-like tile in the clip (starfish `7/12`) is in the vertical grid. Asked whether they wanted quests on the lane anyway, the developer chose to depart from the reference: **three quest cards on the lane, after daily tasks and orders; a completed quest sorts forward with a Claim button; the tray's Quests tile is removed.** No reference footage shows this. Treat it as a PawSanctuary design choice, not a measured convention.

---

## 1. Current state (read from the code, `fb3be5a`)

- **Lane** — `OrderLaneView.swift`: one `LazyHStack` of, in order, `unclaimedDailyTasks` (`DailyTaskLaneCard`, 160pt, has a Claim button), the urgent order, then `adoptionOrders` (`OrderLaneCard`, 148pt, no button). Claimed dailies drop out of the lane.
- **Quests** — three standing `Quest`s in `QuestCoordinator.activeQuests` (`AnimalSpecies.swift:823`). Progress accrues automatically; the player claims in the **quest sheet** via `MergeBoardViewModel.claimQuest(id:)` (`:3268`), which calls `claimAndReplace` — the claimed quest is replaced in place by a fresh one, so there is never a "claimed" quest. A claim pays kibble, dog tags, XP, coins, Care Points, toolboxes by difficulty, and sometimes bonus dog tags.
- **Tray** — one tile, `questsTile` (`TaskTrayView.swift:651`): `target` icon, `n/3` label, red dot when any quest is complete, opens `.quests`. There is **no** claim on it.
- **Precedent for presence in both places** — `dailiesTile` stays in the tray even though dailies have lane cards, because "the lane scrolls and the tile does not, so it is the only always-visible answer to 'is anything ready to hand in today?'" (comment at `TaskTrayView.swift:664`). See §6.1: removing the Quests tile gives up exactly that.

## 2. Decisions

**Q1 — One lane card per active quest (three), not an aggregate.** Chosen over a single `Quests n/3` card, which would differ little from today's tile. Overrides §3.6, whose reason (a 40pt tile cannot tell three quests apart) does not apply at lane width.

**Q2 — The quest cards trail the orders; a claimable quest sorts forward.** Lane order:

1. unclaimed daily tasks *(unchanged)*
2. urgent order *(unchanged)*
3. **claimable quests** (complete, unclaimed)
4. orders *(unchanged)*
5. **in-progress quests**

*Interpretation, to confirm (§6.2):* "jumps to the front" is read as *ahead of the orders and the other quests*, not ahead of daily tasks or the urgent order. Dailies expire at midnight and the urgent order expires in minutes; a complete quest never expires (claim-and-replace has no clock), so it is the one card that loses nothing by waiting a few more seconds.

**Q3 — The tray's Quests tile is removed.** Overrides §3.5/§3.6. Cost recorded in §6.1.

**Q4 — The card claims directly, through the existing path.** Claim calls `claimQuest(id:)` unchanged. No reward, generation or persistence change; **no schema change**, so no migration or `PersistenceTests` case is needed.

**Q5 — Cards show the goal text and the existing SF Symbol, not illustrated art.** `Spec_DailyHandInTasks.md` moved dailies to real creature art because a hand-in names specific creatures. A quest goal is a count of an action (`Complete 12 merges`, `Spend 20 Kibble`), so there is no creature to illustrate for most goals. Art for `mergeInChain`/`reachTier` goals is possible later and is out of scope.

---

## 3. Card

`QuestLaneCard`, width **160pt** — the daily card's width, for the daily card's reason (`DailyTaskLaneView.swift`: a card with a button needs the extra 12pt to keep its label legible) — height `trayBandHeight`.

| Region | Content |
|---|---|
| Header | difficulty name in `QuestDifficulty.color` + the coin reward (as `DailyTaskLaneCard`'s header) |
| Body | `QuestGoal.icon` in `iconColor`, then `description` on two lines |
| Progress | bar from `progressFraction`, `progressText` (`3/10`) |
| Footer | **Claim** button, only when `isComplete`; absent otherwise (the bar takes the space) |

`QuestGoal.description` runs from short (`Complete 5 merges`) to 39 characters (`Get 3 animals to Community Fav (Tier 8)`); at 9pt and ~140pt of text width the long end is two lines, which is the budget. Anything longer must truncate, not grow the card. The text is not yet measured on a device — see §7.

| State | Look | Tap |
|---|---|---|
| In progress | neutral tint, bar, no button | opens quest sheet |
| Complete | blue tint and border as a stocked daily, **Claim** enabled | Claim → `claimQuest`; elsewhere opens quest sheet |

There is no claimed state: the claim replaces the quest, so the same slot immediately shows a new in-progress quest (§6.4).

## 4. Effect on lane length

Worst case today: 3 dailies + 1 urgent + 4 orders ≈ `3×160 + 5×148 + 7×8` ≈ **1,280pt**. With three quests: ≈ **1,800pt**, against ~249pt (tray open) to ~341pt (tray collapsed) visible — roughly **5.3–7.2 viewport widths**, up from **3.8–5.1**. This is the horizontal-length problem `Spec_TravelTownReview_Draft.md` §3 flagged, partly given back. The sort rule (claimable quests early, in-progress quests last) keeps the actionable cards near the front; it does not shorten the lane.

## 5. Tasks

One per session, game playable after each.

**5.1 — Quest lane card and lane integration, tile kept.** Build `QuestLaneCard`; extract the lane's ordering into one pure, testable function (daily → urgent → claimable quests → orders → in-progress quests); add the cards to `OrderLaneView`. Leave `questsTile` in place so the change is additive and revertible.

**5.2 — Remove the Quests tile.** Delete `questsTile` and its entry in the tile list (`TaskTrayView.swift:447`); confirm the dot count, urgency ranking and `trayBandHeight` are unaffected (the tile list is conditional, so the count already varies).

**5.3 — Tests and on-screen check.** See §7.

## 6. Open questions

1. **Keep the tile after all?** `dailiesTile` is the standing counter-example: a tile is the only thing that stays on screen while the lane scrolls, and with quests last in a ~1,800pt lane they will usually be off screen. The developer chose removal; the recommendation here is to ship 5.1 first and decide 5.2 after seeing it in play. 5.1 is built to allow that.
2. **Confirm Q2's reading of "front."** If a claimable quest should lead the whole lane, ahead of dailies and the urgent order, the sort is one line different but the lane's first card then changes under the player whenever a quest completes.
3. **Tutorial.** `tutorialStep == .quest` (`MergeBoardView.swift:90`) opens `.task(.quests)`; the tutorial highlights the whole band frame, not the tile, so it should survive 5.2 — to be confirmed on screen, not assumed.
4. **Claim animation.** The claimed card is replaced in place. Whether it needs a visible hand-off (fade/slide) so the player sees a *new* quest arrived, rather than the old one resetting, is unspecified.
5. **Mitigating lane length** (§4) — a cap on in-progress quest cards, or collapsing the three in-progress ones into one `Quests n/3` card behind the claimable ones — is not decided and not needed to start.

## 7. Acceptance

- Lane order matches Q2 for each combination of: claimable/in-progress quests, with and without an urgent order, with and without unclaimed dailies — as a unit test on the extracted ordering function.
- Claiming from the card pays exactly what claiming from the sheet pays, and the slot holds a fresh quest with `progress == 0` (`claimQuest` is exercised today only incidentally, by `PlaytestMetricsTests` and `ToolboxDropRateTests` — there is no direct reward/replace test, so add one for the card path).
- A not-yet-complete quest offers no Claim control.
- On the Simulator: three quest cards render at 160pt without clipping, including the longest `reachTier` description; a completed quest shows Claim and sorts ahead of the orders; Claim pays and replaces; the board's cell size is unchanged (band height stays `trayBandHeight`).
- No `GameState` change.

## 8. Out of scope

Quest generation, difficulty or reward numbers (and the economy model); quest art; the quest sheet; the daily-task and order cards; tray geometry; any schema change.
