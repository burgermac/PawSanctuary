# PawSanctuary — Kibble Drive (paid activity-gated ladder)

**Draft. No code written. Not yet entered in the Alignment Plan's D1–D8 log.**

**Self-contained brief.** Assumes no prior conversation. Written cold 4 September 2026 from `Capture_Log.md`'s 4 Sep entry — three Tasty Travels recordings (`ScreenRecording_09-04-2026 10-51-52 / 10-53-16 / 10-54-47_1.MP4`, L105) of a **$4.99 "Charge Challenge"** the user purchased and played through. Catalogue rows in `Capture_Catalogue.md`; contact sheets in the run's outputs.

> **Naming.** The reference calls it "Charge Challenge." That name is unusable here twice over: `charges` is this codebase's producer-fuel vocabulary (`ProducerLevel.maxCharges`, `chargesRemaining`, `CellView.swift:498`), and "Challenge" is the daily-challenge vocabulary (`QuestCoordinator`). This spec calls it the **Kibble Drive** throughout — code, IAP product, player copy — the same rename discipline `Spec_Phase6b_Pass.md` §0 and `Spec_Phase6b_RewardLadder.md` §0 already applied. It sits as a deliberate sibling to the existing `Adoption Drive` event name (`EventSystem.swift:124`); different `EventDefinition`, same naming family.

---

## 0. Why this is not a reskin of anything already shipped

The reference feature is a **paid unlock over an activity-fed ladder**. The player pays $4.99, and that purchase does not deliver a reward — it makes a long ladder of energy rungs claimable, released against a currency the player then earns by playing over a 2d16h window. Headline banner: *"Earn up to 1800 ⚡!"*

Two shipped features are adjacent and neither covers it:

| Shipped | Advances on | Payment posture |
|---|---|---|
| `Spec_Phase6b_Pass.md` — Pass | Order-fulfilment tokens (`EventTokenRiderProvider`) | One purchase unlocks a **parallel paid lane**; the free lane pays regardless |
| `Spec_Phase6b_RewardLadder.md` — Reward Ladder (D8) | **Purchases only** — `advance(trackID:, by: 1)` per rung bought | Every rung is a separate purchase |
| **Kibble Drive (this spec)** | **Player activity** | **One purchase makes the whole ladder claimable; nothing pays without it** |

Pass is the closest structurally — an activity-driven `ProgressTrack` with a paid gate — but Pass's free lane still pays an unpaying player. The Kibble Drive has **no free lane at all**. That single difference is what makes it a distinct offer shape rather than a Pass content variant, and it is why it needs its own spec instead of a registry entry.

### The inversion, and why it is the fifth one

`Capture_Log.md` has catalogued this same inversion four times (27 Jul chain offer, 29 Jul Crazy Offer 1+4, 1 Aug Baker's Path, 22 Aug 1+1 Greek Fest): **pay to release rewards that are already visible on screen.** The Kibble Drive is the fifth, and the first where the release condition is **player effort rather than a padlock**. That is a materially better version of the inversion for a solo-developed game: it converts a purchase into retention rather than into a single dopamine hit, because the player must return across the whole window to realise what they bought.

---

## 1. The architecture worth taking: non-rivalrous multi-crediting

This is the part to actually build, and it is smaller than the feature it enables.

In the reference, one coin counter feeds the Kibble-Drive-equivalent ladder **and** the daily task score **and** the daily/weekly/monthly resetting event trackers, all at once. The coins are not consumed by the ladder — the ladder is one of several subscribers reading the same activity stream. That is what makes the offer's real incremental cost to the player $4.99 and nothing else: they were going to generate the currency anyway.

**PawSanctuary already has the chokepoints and is one broadcast short.** Care Points (`Spec_OrdersAndTasks_Draft.md` §4a, shipped `2f28a18`, schema v38) banks at exactly three sites:

| Chokepoint | Care Points | Source |
|---|---|---|
| `claimQuest` | 8 / 15 / 30 / 60 by difficulty | `AnimalSpecies.swift:1340` |
| Daily-challenge sweep | 25, via `applyQuestRewards` | `carePointsPerDailySweep`, `:1349` |
| Order claim (persistent + urgent) | 1 | `carePointsPerOrder`, `:1358` |

**Correction to this spec's own first draft — the seam already exists.** The first version of §1 proposed replacing "three direct writes" with a broadcast method. Reading the code rather than the §4a write-up: `awardCarePoints(_ amount: Int)` is already there (`MergeBoardViewModel.swift:3946`), already the sole funnel, already called from **five** sites (`:3146` daily sweep, `:3175` quest claim, `:3332` task claim, `:3454`/`:3480` persistent and urgent order claims). Its entire body is:

```swift
func awardCarePoints(_ amount: Int) {
    guard amount > 0 else { return }
    carePointsThisWeek += amount
}
```

So the destination is hardcoded *inside an existing chokepoint*, not scattered across call sites. **The architectural change is two lines in one method.** That is the whole of step 1 in §6, and it is why this feature is cheap: the expensive part was already built for Care Points and nobody noticed it generalised.

Today that single destination is `carePointsThisWeek` (`GameStore.swift:116`), against a Bronze 120 / Silver 320 / Gold 520 ladder sharing `checkWeeklyGoalReset`'s boundary.

**Proposed change — no new faucet, no new call sites.** Widen the existing method to credit every active subscriber:

1. `carePointsThisWeek` — the existing weekly bar, unchanged behaviour
2. The active Kibble Drive track, if one is running and purchased
3. Any future resetting tracker, at zero further cost

This is deliberately **not** a new currency and **not** a new earning site. The player's activity produces the same points it produces today; more things read them. `EconomySimulation`'s faucet model is untouched, which matters — §4a records that Care Points pay no kibble and no coins precisely so `miscKibblePerDay` stays honest. **The Kibble Drive breaks that rule and pays kibble; §4 below re-derives the faucet rather than waving it through.**

### The weekly-reset trap

`carePointsThisWeek` zeroes at the weekly boundary. A Drive window that straddles that boundary would zero its own ladder mid-event and destroy a purchase. **The Drive must therefore hold its own event-scoped accumulator**, fed by the same broadcast but reset on its own lifecycle — never by reading `carePointsThisWeek`. This is the single most likely implementation error in the whole feature and the reference's own design confirms the shape: its ladder counter is independent of the daily/weekly trackers it runs alongside.

---

## 2. Target shape

| Piece | Source | Job |
|---|---|---|
| Ladder storage | `ProgressTrack` / `TrackMilestone` (Phase 6a) | Reuse verbatim. `threshold` = Drive Points, `paidRewards` = that rung's kibble. **`freeRewards` empty on every rung** — there is no free lane |
| Progress driver | **New** — `awardCarePoints` broadcast (§1) | Credits `driveState.points` alongside `carePointsThisWeek` |
| Accumulator | **New** — `KibbleDriveState`, event-scoped | `points`, `claimedRungs: [Int]`, `purchased: Bool`, `eventID` |
| Scheduling | `EventDefinition` + `checkEventLifecycle()` | Calendar-scheduled, unlike Reward Ladder. Cadence per §5 |
| Purchase gate | `IAPProduct` (existing enum) | One new **non-consumable-per-event** product, §3.1 |
| Monetization gate | `isMonetizationUnlocked` (D7) | Reuse as-is. Do not invent a new condition |
| Surface | `TaskTrayView` tile + `EventPanelView` | Tray tile shows points/next rung; panel is the scrolling rung list |

### Behaviour, precisely

- Points accrue **whether or not the Drive is purchased.** The unpurchased player sees the ladder filling and every rung greyed with a price tag on the whole board. That visible-but-locked accumulation *is* the offer — same coercive posture D8 already adopted, applied to effort instead of a padlock.
- Purchase flips `purchased = true` and makes every already-passed rung immediately claimable. It grants nothing directly.
- Rungs are claimed by tapping, one at a time, each firing a kibble flight to the HUD. Do not auto-claim: the reference's serial tapping is the payoff moment and `Spec_BoardAnimation_Draft.md` §3's burst is already built to carry it.
- At window close, unclaimed rungs are **forfeit**. Points do not roll over.

---

## 3. The numbers, derived natively — not copied

The reference's "1800⚡ for $4.99" cannot be transplanted. Both titles regenerate energy at 1 per 2:00 against a cap of 100 (`kibbleRegenCap = 100`, `kibbleRegenSecs = 120`), so the *regen* scale matches exactly — but the **shelves do not**, and the shelf is what the offer has to be priced against.

### 3.1 What kibble actually costs in PawSanctuary today

`DogTagKibbleExchange` (`AnimalSpecies.swift:1508`) sells 100 kibble at a climbing daily ladder of **15 / 30 / 60 dog tags**, and — unlike the reference — **the last rung repeats forever** (`isAtFlatRate`). So there is no daily cap here; the marginal price of kibble is permanently 60 tags per 100.

Against the shelf the code itself nominates (`LiveOpsEngine.swift:670` cites `dogTagsMedium` — 60 tags for $2.99 = **20.1 tags/$**):

| Source | Kibble per $ |
|---|---|
| Exchange rung 1 (15 tags/100) | 134 |
| Exchange rung 2 (30 tags/100) | 67 |
| **Exchange rung 3+ — the marginal rate** | **33.5** |
| `energyLarge` IAP ($4.99 → 120 kibble + 40 tags + spawner + star5 pack) | 24 (kibble alone) |

The reference's Charge Challenge returns **3.0×** its own marginal shelf rate. Holding that multiple:

> **3.0 × 33.5 ≈ 100 kibble per dollar → ~500 kibble at $4.99.**

### 3.2 Points per day, computed from `EconomySimulation` — not estimated

The first draft of this spec guessed ~74 points/day by scaling Care Points Gold. That was wrong. Read off the model's own constants at the projection level (L45, `EconomySimulation.projectionLevel`):

| Source | Model constant | Points/day |
|---|---|---|
| Orders | `ordersPerDay` = (`slotCount` 5 + 1 urgent) × `orderCyclesPerDay` 8 = **48**, at `carePointsPerOrder` 1 | 48.0 |
| Daily sweep | `carePointsPerDailySweep` 25, on the 6-of-7 days assumed at `AnimalSpecies.swift:1469` | 21.4 |
| Quests | `questClaimsPerDay` 2.0 at the mixed easy/medium/hard average (8+15+30)/3 = 17.7 | 35.3 |
| **Total** | | **≈ 105 / day** |

Cross-check: 105 × 7 = 735/week against Care Points Gold at 520 — Gold lands around day 5, and two days yields 210, well short. That satisfies both properties `CarePointsTests` asserts, so this figure is consistent with the shipped tuning rather than a competing estimate.

### 3.3 Proposed ladder

**Window: 3 days.** At 105/day an engaged player banks ~315. Top rung set at **300** — clearable by an engaged player with about half a day of slack, comfortably out of reach for a casual one.

15 rungs, arithmetic-ramp thresholds (the reference's mid-ladder steps grow +3000/+3500/+4000/+4500 — a ramp, not a geometric curve), denominated in Drive Points:

| Rung | Threshold | Reward |
|---|---|---|
| 1 | 10 | 30 kibble |
| 2 | 22 | 30 |
| 3 | 35 | 30 |
| 4 | 50 | 30 |
| 5 | 66 | 30 |
| 6 | 83 | 30 |
| 7 | 102 | 40 |
| 8 | 122 | 40 |
| 9 | 144 | 40 |
| 10 | 167 | 40 kibble **+ star4 card pack** |
| 11 | 191 | 40 |
| 12 | 216 | 40 |
| 13 | 243 | 40 |
| 14 | 271 | 40 |
| 15 | **300** | 40 kibble **+ star5 card pack** |

**Total: 540 kibble + 2 card packs.** Headline copy: *"Earn up to 540 Kibble!"*

540 / $4.99 = **108 kibble/$**, or **3.2× the marginal exchange rate** — deliberately within rounding of the reference's 3.0×. The card packs at rungs 10 and 15 mirror the reference, whose claim sequence contained a card-pack reveal, so "540 kibble" is the headline rather than the whole payout.

### 3.4 RESOLVED — reposition `energyLarge`

**Decided 4 September 2026.** The `energyLarge` collision (also $4.99, 120 kibble) is resolved by repositioning the pack, not by repricing the Drive. The Drive keeps $4.99 and owns the volume tier.

The comparison only bites because the pack family is **kibble-led by name and by content** — "Energy Packs," kibble listed first in every `EnergyPackContents`. That framing invites a kibble-per-dollar comparison the pack cannot win against a three-day grind, and never could.

**Proposed reposition — gear-led upper tier.** Leave `energySmall`/`energyMedium` alone: they are impulse relief at the wall, they are bought for the kibble, and at $0.99/$2.99 they do not sit against the Drive. Shift the two upper SKUs so kibble is the garnish rather than the headline:

| SKU | Today | Proposed |
|---|---|---|
| `energyLarge` $4.99 | 120 kibble · 40 tags · 1 `fosterHome` · star5 | 60 kibble · **70 tags** · **2 `fosterHome`** · star5 |
| `energyXL` $9.99 | 250 kibble · 80 tags · 2 `fosterHome` · star6 | 120 kibble · **150 tags** · **3 `fosterHome`** · star6 |

Tags are the lever: at `dogTagsMedium`'s 20.1 tags/$ shelf, 70 tags is $3.48 of headline value on its own, and tags convert to kibble through `DogTagKibbleExchange` anyway — so a player who *wants* kibble can still get there, just at their own choice of exchange rung. The pack stops being a worse kibble deal and starts being a different purchase.

**Two consequences to accept going in.** `energyLarge` is presumably carrying revenue today, and changing the contents of a live SKU changes its conversion in ways this spec cannot predict — this is a revenue experiment, not a content edit. And more tags in circulation means more `DogTagKibbleExchange` volume, which is a kibble faucet by another route; §3.6's accounting should cover both.

### 3.5 RESOLVED — the ratio is safe, by roughly 4×

The Drive pays 540 kibble against 300 points: **1.80 kibble per Drive Point.**

Against what a point *costs* the player. In steady state a player spends essentially their whole daily supply, and `dailySupply(level: 45)` = `regenPerDayAtCap150` 570 + ads (`maxDailyAdWatches` 4 × `adKibbleReward` 25) 100 + `miscKibblePerDay` 75 = **745 kibble/day**, against §3.2's 105 points/day:

> **745 ÷ 105 = 7.1 kibble spent per Drive Point earned, against 1.80 paid back.**
>
> **Margin of safety ≈ 3.9×. The Drive is not a net kibble source and cannot be looped.**

Checked at the tight end too — at L10 (`slotCount` 4, so 40 orders/day → 96.7 points/day, supply still 745) the figure is 7.7, slightly *safer*, and D7's `isMonetizationUnlocked` gate means lower levels never see the feature anyway. The ratio is not level-sensitive in a way that threatens it.

**Supply impact.** 540 kibble over a 3-day window is 180/day, **+24% of daily supply for purchasers during the window** — visible, which is the point of buying it. Amortised over the ~4-week cadence in §4 it is 19/day, **+2.6%**. Both are within tolerance; the cadence is what keeps the second number small, which is §4's whole argument.

**The one leak worth naming.** This holds because nearly every point source is downstream of spending kibble. The exception is any quest goal completable *without* play — a pure "log in N days" goal pays 8–60 points for zero kibble. At `questClaimsPerDay` 2.0 that is a small share, but if login-only goals ever become a large fraction of the quest pool, this calculation degrades. Worth an assertion in the eventual test rather than a comment.

### 3.6 Faucet accounting

`EconomySimulation.dailySupply` models kibble as a fixed `miscKibblePerDay` covering "login bonus, Loyalty Club, quests, daily challenges, weekly goals." A Drive paying 540 kibble over 3 days is **180 kibble/day for the duration**, to purchasers only, on a ~4-week cadence. That is a large, spiky, purchase-conditional inflow that `miscKibblePerDay` does not represent.

It should be modelled as its own term — a purchaser-only supply line with a duty cycle — not folded into `miscKibblePerDay`, whose whole value is that it is a flat baseline. **`Phase2_Economy_Model.xlsx` is untouched by this spec; this is a proposed addition for the design authority.**

---

## 4. Cadence and D5

The user's observation on the reference is that the event runs **every 2–3 weeks, not weekly** — recorded as his read, not measured from a single capture.

D5 fixed a 3-event live-ops budget. The Kibble Drive should **not** consume one of those slots on a weekly basis. Proposed: a ~4-week cadence, scheduled in the existing 90-day rolling calendar (`Spec_Phase6c_Calendar.md`), running concurrently with whatever else is live — which `Spec_Phase6c_ConcurrentEvents.md` already made possible and which the reference does aggressively (`Spec_ParallelBoardReview_Draft.md` §2.5 records 3+ concurrent event surfaces).

Rarity is doing real work here. At a 4-week cadence the Drive is an occasion; weekly it becomes the kibble economy, and §3.5's ratio stops being a safety margin and starts being the game.

---

## 5. Schema and migration

New persisted shape → version bump, migration, and a `PersistenceTests.swift` test, per working rule 4.

```swift
struct KibbleDriveState: Codable, Equatable {
    var eventID: String
    var points: Int = 0
    var claimedRungs: [Int] = []
    var purchased: Bool = false
}
```

Held as `var kibbleDrive: KibbleDriveState?` on `GameState` — `nil` when no Drive is scheduled. Additive-optional, so it should ride `additiveDefaultsSinceV8` the way `carePointsThisWeek` did at v37→v38 (`GameStore.swift:656`) rather than needing a bespoke migrator.

New IAP product, following the `eventPass` precedent (`AnimalSpecies.swift:1081`) — per-event, one-time, reward resolved from the registry at claim time rather than a static amount on the product:

```swift
case kibbleDrive = "com.pawsanctuary.kibbledrive"
```

**Time-of-check/time-of-use.** `Spec_Phase6b_Pass.md` §3.3's `pendingEventPassEventID` fix applies verbatim: a purchase that resolves after the Drive's window closes must not credit the next Drive. Follow that pattern rather than re-deriving it.

---

## 6. Landing order

Not atomic. Separate commits, verify each on screen, stop if one resists.

1. **`KibbleDriveState` + schema bump + migration test.** No UI, no behaviour. (§1's broadcast seam already exists — `awardCarePoints` needs widening, not building, and that lands in step 2 alongside the thing it feeds rather than as a no-op commit of its own.)
2. **Second subscriber.** Widen `awardCarePoints` to credit the Drive accumulator alongside `carePointsThisWeek`. Existing `CarePointsTests` must stay green untouched — that is the proof the weekly bar is unaffected. Test the weekly-reset independence explicitly; §1's trap is the thing most likely to be got wrong.
3. **IAP + purchase/claim logic**, `eventPass` pattern, including the TOCTOU guard.
4. **Registry content** — §3.3's ladder, with a test asserting §3.5's ratio holds against `EconomySimulation` so a later retune of `carePointsPerOrder` or `orderCyclesPerDay` fails loudly instead of silently opening the faucet.
5. **`energyLarge`/`energyXL` reposition** (§3.4) — separable from the rest and separately revertible, which matters because it is a live-revenue change.
6. **UI** — tray tile, then the panel rung list.
7. **On-screen acceptance** — purchase, earn past a rung, claim it, watch kibble land.

---

## 7. Open questions

1. ~~**§3.4's price collision with `energyLarge`**~~ — **resolved 4 Sep 2026: reposition the pack.** Contents proposal in §3.4; the live-SKU revenue risk is accepted, not eliminated.
2. ~~**§3.5's kibble-per-point ratio**~~ — **resolved 4 Sep 2026: computed, 7.1 spent vs 1.80 paid, ~3.9× margin.** Both blockers are clear; §3.3's numbers can be treated as final pending playtest.
3. **Does an unpurchased player accrue points?** §2 says yes, on the D8 coercive-posture precedent. The alternative (accrual starts at purchase) is less coercive and materially weaker as an offer, and would also make late purchasers unable to finish. Worth confirming rather than assuming.
4. **Forfeit on close** — §2 says unclaimed rungs are lost. That is the reference's framing but PawSanctuary chose the *softer* posture on Reward Ladder (no expiry at all, `Spec_Phase6b_RewardLadder.md` §0). Two features with opposite expiry postures needs to be deliberate.
5. **Refund exposure.** A player who buys on day 3 of 3 and clears two rungs has a legitimate grievance. There is no StoreKit revocation flow here (§0 of the Reward Ladder spec records the same gap). Options: hard-stop sales in the final 24h, or scale a late-purchase catch-up grant.
6. **What the reference's own completion banner meant** — `Capture_Log.md` 4 Sep finding 4 records the reference showing "Challenges complete!" over visibly unfilled bars. If that is a second, separate task set feeding the ladder, this spec's single-accumulator model is missing a layer. Unresolved from the capture; queued for deep dive.

---

## 8. Out of scope

- Any change to `carePointsPerOrder` / `carePointsPerDailySweep` / quest point values. The broadcast reads the existing faucet; it does not retune it.
- Re-pointing the weekly Bronze/Silver/Gold bar. §4a decided against that once, deliberately.
- `Phase2_Economy_Model.xlsx`. §3.6 is a proposal.
- The reference's ranking/leaderboard surface (`Capture_Log.md` 4 Sep finding 5) — a different feature that happened to be in the same capture.
- Any animation work beyond reusing `Spec_BoardAnimation_Draft.md` §3's existing burst.
