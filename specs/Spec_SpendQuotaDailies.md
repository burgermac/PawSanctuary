# PawSanctuary — Spend-Quota Dailies (D6)

**Self-contained brief.** Assumes no prior conversation.

> **Not atomic.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists.

**Written cold by Claude Code at the user's request, same exception made for Pass/Parallel Board/the 6c calendar/the Reward Ladder. Design-authority reviewed and fully confirmed 18 Aug 2026 — every fork resolved (anchor-sharing, currency scope, §4's numbers, the standing-quest extension). Ready to implement.** This spec exists because D6 was decided 18 Aug 2026 (`specs/PawSanctuary_Alignment_Plan.md` §"D6 — Spend-quota tasks in dailies?"): **adopt** — a "Spend N currency" daily-challenge task type, overriding that section's own "out, at least at launch" recommendation. No implementation task existed for this yet; this draft is that task, proposing the concrete shape the Alignment Plan's own entry left unresolved (it says only "size the spend quota against the existing daily-challenge reward curve... not guessed" — it doesn't say which currency, how the task fits the existing daily-challenge generator, or what happens to reward pacing). See §6 for the full review record.

---

## 0. Why

Per the Alignment Plan's D6 entry: reference games include "Spend 50 Gems" as a daily-challenge task, converting the retention system into a monetization one at zero UI cost. The plan's own recommendation was **against** this at launch — "the most aggressive single mechanic found in the three games," sitting badly against the game's "Warmth" design pillar. **Decided 18 Aug 2026 (design authority): adopt anyway** — the plan's own text is explicit that this overrides, not refutes, the Warmth concern: *"that reasoning wasn't refuted, it was overridden. Revisit if playtesting or reviews show it reads as out of step with the rest of the game's tone."* This spec doesn't re-litigate that call — it builds the mechanic — but §6/§7 carry the revisit trigger forward rather than quietly dropping it.

D6 and D8 (Reward Ladder, `specs/Spec_Phase6b_RewardLadder.md`) were explicitly linked in the plan's own text — *"Depends on: D6's reasoning — decide the two together"* — because D8 is a harder, more coercive version of the same Warmth-pillar tension D6 raises. Both are now decided the same way (adopt), so that consistency question is closed; this spec doesn't need to re-open it.

### This slots into an existing system almost entirely — the smallest of the D6/D8/Reward-Ladder family by a wide margin

Unlike D8, which needed a new coordinator, a new IAP product, a new view, and new registry content, D6 is **one new case in an existing enum, in an existing generator, feeding an existing UI that already renders any `QuestGoal` generically.** The daily-challenge system (`QuestCoordinator.swift`, "MARK: Daily challenges") already has:

- A data model (`DailyChallenge`, `AnimalSpecies.swift:718-726`) with a plain `Int` progress field and generic `isComplete`/`progressFraction`/`progressText` computed properties — no changes needed here.
- A shared-anchor generator (`generateDailyChallenges`, `QuestCoordinator.swift:318-328`) that already picks one goal *shape* per day and derives all three difficulty counts from it via `staggeredCount(after:)` (`:313-316`) — the exact "size it, don't guess it" machinery this spec's new task type can plug straight into, reusing the *same* 0.65–0.85 near-miss stagger every other anchor already gets, rather than inventing new medium/hard numbers by hand.
- A generic UI card (`DailyChallengeTaskCard`, `PanelViews.swift:1503-1540`) that renders `challenge.goal.description`/`.progressFraction`/`.progressText` — a new `QuestGoal` case needs its own `description`/`icon`/`iconColor` switch arms (`AnimalSpecies.swift:619-704`), but the card itself needs zero changes.

**The one genuinely new piece:** every existing goal type increments progress by exactly **+1 per discrete board event** (a merge, a rescue) — `updateDailyChallengesAfterMerge`/`updateDailyChallengesAfterRescue` (`QuestCoordinator.swift:330-351`), called from `MergeBoardViewModel.updateAllAfterMerge`/`updateAllAfterRescue` (`MergeBoardViewModel.swift:2611-2635`). A spend-quota goal needs to advance by a **variable amount** (spending 40 kibble should add 40, not 1) — the first goal type where that's true. This spec's real work is wiring that one new increment pathway to the currency's real spend sites, which today have **no shared choke point at all**: every purchase in the game does its own inline `guard balance >= cost; balance -= cost`, independently (§2).

---

## 1. Decisions and constraints this depends on

- **D6:** decided 18 Aug 2026 (Alignment Plan) — adopt, overriding the plan's own Warmth-pillar objection. This spec exists to build it.
- **D8 (Reward Ladder):** shipped and design-reviewed (`Spec_Phase6b_RewardLadder.md`). No dependency in either direction — the plan's "decide together" instruction was about consistency of the *decision*, not a build-order dependency, and nothing in D8's implementation is reused here (D8 built on `ProgressTrack`; this spec touches `QuestCoordinator`'s daily-challenge machinery instead, a different, older system).
- **The Alignment Plan's explicit instruction:** size the spend quota against the existing daily-challenge reward curve, modelled rather than guessed (§4).
- **Not blocked on anything.** The daily-challenge system, `RewardKind`, and every spend call site this spec touches are all long-shipped.

---

## 2. Target shape

| Piece | Source | This task's job |
|---|---|---|
| Goal type | `QuestGoal` (`AnimalSpecies.swift:619`, existing enum) | New case: `.spendCurrency(RewardKind, count: Int)` |
| Currency scope | `RewardKind` (`AnimalSpecies.swift:768-777`, existing enum — already has `.kibble`/`.dogTags`) | Reuse verbatim, no new type. **Both `.kibble` and `.dogTags` generate in v1** — see §2's currency-choice note below |
| Anchor | `DailyChallengeAnchor` (`QuestCoordinator.swift:256-279`, existing private enum) | New case: `.spendCurrency(RewardKind)`, added to the existing random pool **twice** (once per currency) in `pickDailyChallengeAnchor` (`:292-307`) |
| Difficulty counts | `staggeredCount(after:)` (`QuestCoordinator.swift:313-316`, existing) | Reused as-is — only a new `baseEasyCount` value needed (§4), medium/hard fall out automatically |
| Progress increment | **New** — no existing pathway handles variable-amount progress | `QuestCoordinator.updateDailyChallengesAfterSpend(kind:amount:)`, mirroring `updateDailyChallengesAfterMerge`/`Rescue` but doing `progress += amount` instead of `+= 1` |
| Chokepoint | **New** — no shared spend/deduct helper exists anywhere in the codebase today | `MergeBoardViewModel.updateAllAfterSpend(kind:amount:)`, mirroring `updateAllAfterMerge`/`updateAllAfterRescue`; called additively at each real kibble-spend site (§3.2), leaving the sites' own existing balance math untouched |
| Reward | `checkAllDailyChallengesComplete` (`QuestCoordinator.swift:355-372`, existing, unchanged) | **None new.** Dailies today pay nothing per-slot — only an all-three-complete bonus (2/8 dog tags on a 7-day streak, 30 XP, 400+ coins). A spend-quota slot is just a fourth-shape contributor to that same existing bonus, no new reward mechanic |
| UI | `DailyChallengeTaskCard` (`PanelViews.swift:1503-1540`, existing, unchanged) | None — already fully generic over `QuestGoal` |

### Currency choice: both kibble and dog tags generate in v1 — confirmed by the design authority, 18 Aug 2026

The Alignment Plan's instruction is to size this against a modelled curve, not guess. `PawSanctuaryTests/EconomySimulation.swift` (test-target only, never ships) already models kibble supply rigorously — `dailySupply(level:)` puts an engaged player at **~615–745 kibble/day** (passive regen + ad watches + a lump "misc" constant that, notably, already folds in today's zero-kibble-paying daily challenges). This spec's original draft proposed kibble-only for v1 because **dog tags have no equivalent model anywhere in the codebase** — reviewed and overridden: dog tags generate too, backed by a rough supply estimate built for this spec specifically (§4), not the full rigor of `EconomySimulation.swift`'s tier-distribution machinery. That's a real, acknowledged difference in confidence between the two currencies' numbers — flagged where it matters (§4), not glossed over.

### Existing kibble-spend sites this hooks into

No shared `spend()`/`deduct()` helper exists for kibble anywhere in the codebase — confirmed by grep. Every site independently does its own `guard`+`-=`. The real kibble sinks:

| Site | File:line | Cost |
|---|---|---|
| Rescue-producer spawn | `MergeBoardViewModel.swift:1368` (`finishSpawn`) | `spawnCost(forTier:) = 1 << tier` — 1, 2, 4, 8, 16, 32… by spawn tier |
| Skip an adoption order | `MergeBoardViewModel.swift:3244` (`skipOrder`) | `adoptionSkipCost = 2` |

Both are real, repeatable, everyday actions — not one-time unlocks — so both are real candidates for a daily quota to track. (Dog Tag → Kibble exchange spends dog tags to *gain* kibble — not a kibble sink, excluded.)

### Existing dog-tag-spend sites this hooks into

Same story — no shared helper, every site does its own `guard`+`-=`. A longer list than kibble's, and correspondingly more sites Task 3.3 needs to touch:

| Site | File:line | Cost |
|---|---|---|
| Buy a producer (shop) | `MergeBoardViewModel.swift:1543` (`buyProducer`) | `ProducerLevel.dogTagCost` — rescueCrate 5, shelterPod 15, fosterHome 30 |
| Dog Tag store paid reroll | `MergeBoardViewModel.swift:1563` (`paidRefreshDogTagStore`) | `dogTagStoreRefreshCost = 5` |
| Dog Tag store item purchase | `MergeBoardViewModel.swift:1582` (`purchaseDogTagStoreSlot`) | `DogTagStore.price(forTier:minTier:)` — 15–69 across the 4-tier band |
| Wildcard purchase | `MergeBoardViewModel.swift:1601` (`purchaseWildcard`) | `wildcardCostDogTags = 100` |
| Pop a bubble early | `MergeBoardViewModel.swift:2186` (`popBubbleWithDogTags`) | `bubblePopDogTagCost(tier:) = 3 + tier` |
| Crack the piggy bank | `MergeBoardViewModel.swift:3438` (`crackPiggyBank`) | `piggyBankCrackCostDogTags = 20` |
| Skip the free-chest cooldown | `MergeBoardViewModel.swift:3468` (`claimOrSkipFreeChest`, when not naturally ready) | `freeChestSkipCostDogTags = 10` |

**Excluded, deliberately:** unlocking inventory row 1/2 (`InventoryStore.swift:191,199`, `inventoryRow1Cost = 10`/`inventoryRow2Cost = 25`) — one-time per save, not a repeatable daily action, so a poor fit for a *daily* quota (a player who already unlocked both rows has no way to re-trigger this sink at all).

Seven recurring sinks vs. kibble's two — real additional wiring surface at Task 3.3, and a correspondingly larger surface for a future sink to go unnoticed if it's added without the new call (§3.3's existing caution applies with more weight here).

### Standing quests (`Quest`, not `DailyChallenge`) — out of scope, confirmed by the design authority, 18 Aug 2026

The Alignment Plan's D6 text says "dailies" specifically, and this draft's original text assumed extending to standing quests would be a cheap follow-up given the shared `QuestGoal` type — **that assumption turned out to be wrong, caught by actually reading `generateQuest` (`QuestCoordinator.swift:80-185`) rather than inferring from the type system.** Unlike dailies' shared-anchor/`staggeredCount` machinery (§0), standing quests don't derive their target counts from any formula at all — each of the four difficulty bands hand-codes its own goal pool with individually-picked counts (e.g. `.mergeAny` is 3/6/10 at easy/medium/hard, `.spawnBase` is 5/8/12). A `.spendCurrency` case would need **8 new hand-derived target counts** (4 difficulties × 2 currencies), each needing its own sizing rationale, since standing quests persist until claimed rather than resetting daily — a "spend N kibble" standing quest should plausibly ask for far more than a one-day quota, with no existing precedent to size that against. There's also a real reward-texture question dailies never raise: standing quests already pay `kibbleReward`/`dogTagReward` per difficulty regardless of goal type (`Quest.dogTagReward`/`kibbleReward`, `:176-184`) — claiming a "spend 40 kibble" quest would hand back a few kibble as a partial rebate of the currency just spent, which may or may not read as intended. **Confirmed: kept out of scope**, not attempted as part of this pass — a real follow-up spec's worth of work if ever wanted, not a mechanical extension.

---

## 3. Tasks, suggested landing order

### 3.1 — `QuestGoal.spendCurrency` case + generic switches — implemented 18 Aug 2026

Add to `QuestGoal` (`AnimalSpecies.swift:619`):

```swift
case spendCurrency(RewardKind, count: Int)
```

- `targetCount`: add to the existing tuple-pattern switch (`:625-628`).
- `description`: `"Spend \(c) Kibble"` for `.kibble`, `"Spend \(c) Dog Tags"` for `.dogTags` — both generate in v1 (§2).
- `icon`/`iconColor`: reuse the same iconography `ShopView.swift`'s rows already use for each currency (`"pawprint"`/green for kibble, `"tag.fill"`/blue for dog tags) rather than inventing new symbols.
- `dedupeKey`: `"spendCurrency:\(kind.rawValue)"` — irrelevant to dailies (dedup only matters for standing quests, §2) but keeps the switch exhaustive and correct if this case is ever reused there.

**One more exhaustive switch this section's own draft missed:** `MergeBoardViewModel.producerIsNeeded(_:by:)` (`:727-743`) also switches over `QuestGoal` to decide whether an active goal should block a producer from being offered for retirement. The compiler caught it — added `.spendCurrency` to the existing `case .mergeAny, .reachTier: break` branch, since a spend goal isn't tied to any specific producer the way `.mergeInChain`/`.spawnBase` are.

### 3.2 — Progress pathway: `updateDailyChallengesAfterSpend` + `updateAllAfterSpend` — implemented 18 Aug 2026

`QuestCoordinator.swift`, mirroring `updateDailyChallengesAfterMerge` (`:330-344`) exactly except for the increment amount:

```swift
func updateDailyChallengesAfterSpend(kind: RewardKind, amount: Int) {
    for i in dailyChallenges.indices {
        guard !dailyChallenges[i].isComplete else { continue }
        if case .spendCurrency(let k, _) = dailyChallenges[i].goal, k == kind {
            dailyChallenges[i].progress += amount
        }
    }
}
```

`MergeBoardViewModel.swift`, mirroring `updateAllAfterMerge`/`updateAllAfterRescue` (`:2611-2640`):

```swift
func updateAllAfterSpend(kind: RewardKind, amount: Int) {
    quests.updateDailyChallengesAfterSpend(kind: kind, amount: amount)
    if let rewards = quests.checkAllDailyChallengesComplete(
        coinsPerDailyComplete: cachedActiveBonuses.coinsPerDailyComplete) {
        applyQuestRewards(rewards)
    }
}
```

No overshoot guard needed — `DailyChallenge.progressFraction` already clamps to `1.0` (`AnimalSpecies.swift:725`), and `isComplete`'s `>=` comparison is already overshoot-safe.

### 3.3 — Wire the chokepoint into every real spend site (both currencies)

Additive only — no existing site's own balance math changes. Nine call sites total (§2's two tables):

**Kibble:**
- `finishSpawn(item:at:cost:)` (`MergeBoardViewModel.swift:1368`): after `kibbleEngine.kibble -= cost`, add `updateAllAfterSpend(kind: .kibble, amount: cost)`.
- `skipOrder()` (`MergeBoardViewModel.swift:3244`): after its kibble deduction, add the same call with `amount: adoptionSkipCost`.

**Dog tags:**
- `buyProducer(_:)` (`:1543`): after `kibbleEngine.dogTags -= level.dogTagCost`, add `updateAllAfterSpend(kind: .dogTags, amount: level.dogTagCost)`.
- `paidRefreshDogTagStore()` (`:1563`): `amount: dogTagStoreRefreshCost`.
- `purchaseDogTagStoreSlot(_:)` (`:1582`): `amount:` the slot's actual price paid.
- `purchaseWildcard()` (`:1601`): `amount: wildcardCostDogTags`.
- `popBubbleWithDogTags(_:)` (`:2186`): `amount:` the tier-dependent cost actually paid.
- `crackPiggyBank()` (`:3438`): `amount: piggyBankCrackCostDogTags`.
- `claimOrSkipFreeChest()` (`:3468`, paid-skip branch only): `amount: freeChestSkipCostDogTags`.

**Guard against future sinks going unnoticed:** any *new* spend site added later (either currency) needs this same call, and there's no compiler-enforced way to catch a forgotten one (matches the existing pattern's own risk — `updateAllAfterMerge`/`Rescue` have the identical property, every merge/rescue call site must remember to call them). With nine sites instead of two, this is a real, larger surface for a future miss than kibble alone would have been — flagged, not solved, same posture the rest of this codebase already accepts for this class of problem.

### 3.4 — Add the anchor to the daily-challenge generator

`QuestCoordinator.swift`:

- `DailyChallengeAnchor`: new case `.spendCurrency(RewardKind)`, with `goal(count:)` returning `.spendCurrency(kind, count: count)` and `baseEasyCount` switching on the associated `kind` to return the matching value from §4 (40 for `.kibble`, 8 for `.dogTags`).
- `pickDailyChallengeAnchor` (`:292-307`): add **two** entries to the `pool` array — `.spendCurrency(.kibble)` and `.spendCurrency(.dogTags)` — each independently pickable, unconditionally (both currencies exist from the start of a save, unlike e.g. `.mergeInChain` which needs an unlocked chain first). Two separate pool entries, not one entry that then rolls a currency, so each currency gets an equal, independent shot at being picked — matching how `.mergeAny` and `.spawnBase` already coexist as separate entries despite being conceptually similar.

**Confirmed by the design authority, 18 Aug 2026: allow all three slots to share one spend anchor.** Days where a `.spendCurrency` anchor gets picked make **all three** daily challenges spend-that-currency that day, just at three staggered thresholds — not one spend slot mixed with two others. This was flagged rather than assumed (§6) because it's the exact shape the Warmth-pillar objection this decision already overrode (§0) was worried about; reviewed and kept as the simpler, consistent-with-every-other-anchor default rather than special-cased. No new logic beyond adding the two pool entries — neither gets its own generation path.

### 3.5 — Test content: none needed

Unlike D8, this doesn't add new registry content — the daily-challenge generator already runs continuously in production. Once 3.1–3.4 land, `.spendCurrency(.kibble)`/`.spendCurrency(.dogTags)` become real possible outcomes of the *existing* daily reset the next time it fires (or immediately, if reached via the existing `resetToFreshGame()` debug tooling — which, unlike the Reward Ladder's monetization gate, has no equivalent blocker here: daily challenges regenerate on every fresh install with no additional unlock condition).

---

## 4. Numbers — confirmed by the design authority, 18 Aug 2026

Same posture as every other numbers section in this project: modelled, not guessed, but at two different levels of rigor for the two currencies — flagged explicitly rather than presented as equally solid. Reviewed and adopted as-is, both seed values below now final rather than first-cut.

### Kibble — anchored to the existing, reviewed `EconomySimulation.swift` model

**Easy-slot kibble quota: 40.** Against the ~615–745 kibble/day modelled supply (§2), 40 is roughly 5–6% of a day's income — comparable in "how much of a normal day's play does this ask for" terms to `.mergeAny`'s easy count of 3 merges (a task of similar throwaway effort, not a grind). Achievable via ~2 mid-tier producer purchases or ~20 order-skips, well within a single session.

### Dog tags — a new rough estimate, built for this spec, lighter-weight than the kibble model

No existing model to anchor against (§2), so one was built from the same real constants §2's sink table cites, at the same "engaged player, ~2h/day" assumption `EconomySimulation.swift` already uses for kibble (reused directly for consistency, not re-derived):

- **Orders:** `AdoptionBoard.swift`'s per-order tag formula is `max(1, (tier+1)/2) + Int.random(in: 0...2)` (expected value of the random term = 1). Averaged across tiers 0–5, which dominate most of the leveling range before endgame tiers unlock, that's **~2.5 tags/order**. Order throughput reuses `EconomySimulation.ordersPerDay(level:)` directly — `(slotCount(level) + 1) × orderCyclesPerDay`, e.g. `(5+1) × 8 = 48` orders/day past the level-13 slot unlock — giving **~120 tags/day from orders**, the dominant term by far (this mirrors how kibble's own supply model is also order-cycle-dominated).
- **Standing quests:** mixing easy/medium/hard tag rewards (1–2 / 3–4 / 5–6, excluding legendary, matching `EconomySimulation.averageQuestCoins`'s own choice to exclude it) ≈ 3.5 tags/claim × `questClaimsPerDay = 2.0` ≈ **7 tags/day**.
- **Daily-challenge streak bonus:** +2/day normally, +8 every 7th day → blended **~2.9 tags/day**.
- **Weekly spotlight:** +5/week → **~0.7 tags/day**.
- **Total: ~130 dog tags/day** (range roughly 115–155 depending on level and order-tier mix).

**Easy-slot dog-tag quota: 8.** Mirroring kibble's ~5–6%-of-daily-supply sizing: 5–6% of ~130 ≈ 7–8. Also checks out against §2's sink table in absolute terms — 8 tags is about one Dog Tag Store reroll (5) plus pocket change, or a meaningful chunk of one `rescueCrate` producer (5) — a single cheap, achievable action, same "throwaway effort" bar the kibble quota and `.mergeAny`'s easy count both hit.

### Medium/hard — not hand-picked, for either currency

`staggeredCount(after: 40)` and `staggeredCount(after: 8)` (`QuestCoordinator.swift:313-316`) already produce random values in roughly the 47–62 and 9–12 ranges respectively at generation time, and hard follows the same way from medium — this reuses the exact mechanism every other anchor's medium/hard counts already come from, so there's no new formula to get wrong for either currency, only the two easy-count seed values above.

### No new reward number

The existing all-three-complete bonus (2/8 dog tags, 30 XP, 400+ coins) is unchanged — see §2.

---

## 5. Screen verification

No calendar window, no monetization gate, no debug lever needed (§3.5) — this is live the moment 3.1–3.4 land, the next time `checkDailyChallengeReset` fires (once per real day, or immediately via `resetToFreshGame()`'s existing dev reset). Verify: a fresh install occasionally rolls a "Spend N Kibble" or "Spend N Dog Tags" trio (may take several resets, since each spend anchor is one of ~5-6 in the pool and picked uniformly at random); spending the matching currency via any of §2's real sink actions visibly advances the progress bar on all matching slots, for both currencies independently; completing all three still pays the existing bonus.

---

## 6. Open questions for design-authority review

This draft's design-authority review is complete as of 18 Aug 2026 — every fork below was resolved rather than left assumed:

- **RESOLVED — the anchor-sharing question in §3.4.** Confirmed: all three slots can share one spend anchor on the same day, same as every other anchor. Not special-cased to soften the mechanic.
- **RESOLVED — currency scope (§2).** Confirmed: both kibble and dog tags generate in v1. Dog tags run on a new, lighter-weight estimate built for this spec (§4) rather than an `EconomySimulation.swift`-grade model — that confidence gap is real and flagged, not something to forget once this is implemented.
- **RESOLVED — §4's numbers.** Confirmed: the 40-kibble and 8-dog-tag easy seeds are adopted as final, including the dog-tag supply estimate's own assumptions (order-tier average, "engaged player" throughput reused from the kibble model) — reviewed and accepted despite being new and untested against real telemetry, not deferred pending more data.
- **RESOLVED — whether standing quests should get this goal type too (§2).** Confirmed: no. Turned out to be real, separate work (8 hand-derived target counts, a reward-rebate texture question), not the cheap extension this draft originally assumed — worth its own spec if ever revisited, not folded in here.

Nothing left open — this spec is ready to implement.

---

## 7. Out of scope

- **A full `EconomySimulation.swift`-grade dog-tag model** — §4's dog-tag supply estimate is a new, lighter-weight, first-cut number built for this spec, not an addition to that file or an equivalent formal simulation.
- **Standing-quest (`Quest`) spend goals** — confirmed out of scope (§2/§6); real, separate follow-up work if ever wanted, not a cheap extension.
- **A cap on spend-anchor frequency or same-day repeats** — considered and confirmed unnecessary (§3.4/§6); all three daily slots may share one spend anchor, same as every other anchor.
- **Any new reward mechanic** — deliberately reuses the existing all-three-complete bonus untouched.
- **Revisiting the Warmth-pillar objection itself** — that's D6's own decision, already made (§0); this spec only builds what was decided.
