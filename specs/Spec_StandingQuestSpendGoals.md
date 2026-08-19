# PawSanctuary — Standing-Quest Spend Goals (D6 follow-up)

**Self-contained brief.** Assumes no prior conversation.

> **Not atomic.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists.

**Written cold by Claude Code at the user's request, same exception made for Pass/Parallel Board/the 6c calendar/the Reward Ladder/D6 itself. Design-authority review complete (18 Aug 2026): the reward-rebate question is resolved (no special case), currency symmetry is resolved (both currencies at all four difficulties), and §4's numbers are deliberately deferred to playtesting rather than locked in — implementation can proceed using them as a starting point. Ready to implement.** This spec exists because `specs/Spec_SpendQuotaDailies.md` (D6) §2/§6/§7 confirmed extending its `QuestGoal.spendCurrency` goal type to standing quests (the `Quest` struct, distinct from `DailyChallenge`) as **real, separate follow-up work — not the cheap extension its own first draft assumed** — and flagged it as worth its own spec if ever revisited. It was revisited the same day. See §6 for what's left.

---

## 0. Why

D6 built `QuestGoal.spendCurrency(RewardKind, count: Int)` for daily challenges only, deliberately: the Alignment Plan's D6 entry said "dailies" specifically, and — this is the real reason — standing quests turned out not to fit the same generation machinery daily challenges use. Two genuine differences, found by reading `QuestCoordinator.generateQuest` (`QuestCoordinator.swift:80-185`) rather than assumed from the shared `QuestGoal` type:

1. **No shared-anchor/stagger formula to reuse.** Daily challenges derive medium/hard counts from one easy seed via `staggeredCount(after:)` — a single new number (40 kibble, 8 dog tags) was enough to get all three difficulty slots "for free." Standing quests instead hand-code an entirely separate goal pool per difficulty band (easy/medium/hard/legendary), each with its own individually-chosen counts (e.g. `.mergeAny` is 3/6/10 across easy/medium/hard, `.spawnBase` is 5/8/12). A spend-quota goal here needs **8 hand-derived numbers** (4 difficulties × 2 currencies), not 1.
2. **A real reward-texture question daily challenges never raise.** Daily challenges pay nothing per-slot — only an all-three-complete bonus, so a spend-quota slot there costs the player something and gives nothing back until the whole set finishes. Standing quests are different: `claimQuest` (`MergeBoardViewModel.swift:2966-2993`) pays `kibbleReward`/`dogTagReward`/`coinReward`/`xpReward` **per claim, uniformly for every goal type, regardless of what the goal was.** A "spend 40 kibble" standing quest would hand back a few kibble as part of its normal reward — a partial rebate of the currency the player just spent to complete it. §2 proposes a resolution rather than leaving it open.

---

## 1. Decisions and constraints this depends on

- **D6 (`Spec_SpendQuotaDailies.md`):** shipped and fully implemented (Tasks 3.1–3.5, 424/424 tests). `QuestGoal.spendCurrency`, `RewardKind`, and the `updateAllAfterSpend`/`updateDailyChallengesAfterSpend` chokepoint machinery all already exist and are reused verbatim here — this spec adds a parallel `updateQuestsAfterSpend` alongside the existing one, not a new mechanism.
- **The nine real spend call sites** (`MergeBoardViewModel.swift` — `finishSpawn`, `skipOrder`, `buyProducer`, `paidRefreshDogTagStore`, `purchaseDogTagStoreSlot`, `purchaseWildcard`, `popBubbleWithDogTags`, `crackPiggyBank`, `claimOrSkipFreeChest`'s paid-skip branch) already call `updateAllAfterSpend(kind:amount:)` — this spec adds one more line to that same chokepoint (§3.2), not nine new call sites.
- **Not blocked on anything else.** Standing quests, `RewardKind`, and every spend site this spec touches are all long-shipped.

---

## 2. Target shape

| Piece | Source | This task's job |
|---|---|---|
| Goal type | `QuestGoal.spendCurrency` (existing, built for D6) | Reuse verbatim — no new case, no new `RewardKind` |
| Generation | `generateQuest`'s four per-difficulty pools (`QuestCoordinator.swift:114-174`, existing) | Add `.spendCurrency(.kibble, count:)` and `.spendCurrency(.dogTags, count:)` to **all four** pools (easy/medium/hard/legendary) — 8 new literal entries |
| Progress increment | `updateDailyChallengesAfterSpend` (existing, D6) | New sibling: `QuestCoordinator.updateQuestsAfterSpend(kind:amount:)`, identical shape, targeting `activeQuests` instead of `dailyChallenges` |
| Chokepoint | `MergeBoardViewModel.updateAllAfterSpend` (existing, D6) | Add one line — `quests.updateQuestsAfterSpend(kind:amount:)` — alongside the existing `updateDailyChallengesAfterSpend` call, mirroring exactly how `updateAllAfterMerge` already calls both `updateQuestsAfterMerge` *and* `updateDailyChallengesAfterMerge` |
| Reward | `claimQuest` (`MergeBoardViewModel.swift:2966-2993`, existing, **unchanged**) | None new — see below |
| UI | `QuestTaskCard`/quest panel views (existing, generic over `QuestGoal`) | None — already fully generic, same reuse D6 found for `DailyChallengeTaskCard` |

### The reward-rebate question: resolved by consistency, not special-cased — confirmed by the design authority, 18 Aug 2026

**No special case.** `claimQuest`'s reward stays exactly as it already is — uniform across every goal type. A `.reachTier` quest, a `.mergeAny` quest, and a `.spawnBase` quest all pay exactly the same `kibbleReward`/`dogTagReward`/`coinReward`/`xpReward` for a given difficulty, because the reward was never meant to be a 1:1 trade for the goal's cost; it's a structured completion bonus layered on top of activity the player would mostly do anyway. A spend-quota quest paying back a small fraction of what was spent (e.g. legendary: spend 220 kibble, receive 20 kibble + 10–15 dog tags + 1,000 coins + 150 XP back) is the same shape every other quest already has — the "rebate" framing undersells it exactly the way it would for any other goal type if described the same way ("merge quest gives you kibble back for doing something free"). Reviewed and kept as proposed: singling out spend-type quests for suppressed rewards would make this goal type the *only* inconsistent one in the reward system, and zero code changes are needed beyond what §3 already scopes.

---

## 3. Tasks, suggested landing order

### 3.1 — Add `.spendCurrency` to all four `generateQuest` pools

`QuestCoordinator.swift`, inside `generateQuest`'s difficulty switch (`:114-174`) — one literal addition per difficulty, both currencies, unconditional (kibble and dog tags both exist from the start of a save, same reasoning D6 used for the daily-challenge pool):

```swift
case .easy:
    var pool: [QuestGoal] = [
        .mergeAny(count: 3),
        .mergeInChain(mergeableID, count: 2),
        .spawnBase(count: 5),
        .reachTier(.animal, tier: RescueStage.rescued.tierIndex, count: 3),
        .spendCurrency(.kibble, count: 40),
        .spendCurrency(.dogTags, count: 8),
    ]
    // ... unchanged
```

Repeat with each difficulty's own counts (§4) in the `.medium`, `.hard`, and `.legendary` pools. `dedupeKey` (already implemented for `.spendCurrency` in D6, `AnimalSpecies.swift`) already keys on currency, not count, so the existing `excluding:` de-dupe logic in `generateQuest`/`setupQuests`/`claimAndReplace` works unmodified — a kibble-spend quest and a dog-tag-spend quest can coexist among the 3 active quests, but two kibble-spend quests can't.

### 3.2 — Progress pathway: `updateQuestsAfterSpend` + one new chokepoint line

`QuestCoordinator.swift`, mirroring `updateQuestsAfterMerge` (`:189-204`) exactly, and D6's own `updateDailyChallengesAfterSpend`:

```swift
func updateQuestsAfterSpend(kind: RewardKind, amount: Int) {
    for i in activeQuests.indices {
        guard !activeQuests[i].isComplete else { continue }
        if case .spendCurrency(let k, _) = activeQuests[i].goal, k == kind {
            activeQuests[i].progress += amount
        }
    }
}
```

`MergeBoardViewModel.updateAllAfterSpend` (`:2611-2635`-area, existing, D6) — add one line:

```swift
func updateAllAfterSpend(kind: RewardKind, amount: Int) {
    quests.updateQuestsAfterSpend(kind: kind, amount: amount)          // new
    quests.updateDailyChallengesAfterSpend(kind: kind, amount: amount)
    if let rewards = quests.checkAllDailyChallengesComplete(
        coinsPerDailyComplete: cachedActiveBonuses.coinsPerDailyComplete) {
        applyQuestRewards(rewards)
    }
}
```

No new claim-completion check needed here the way `checkAllDailyChallengesComplete` exists for dailies — standing quests are claimed individually via the existing `claimQuest`/`claimAndReplace` flow, unchanged by this spec, whenever the player taps a completed quest card.

### 3.3 — No sink wiring needed

Already done by D6 — all nine real spend sites already call `updateAllAfterSpend`, which now reaches both `activeQuests` and `dailyChallenges` from the one chokepoint added in 3.2.

### 3.4 — Test content: none needed

Same as D6 §3.5's own finding — nothing to seed. `generateQuest`/`setupQuests` already run continuously in production; once 3.1–3.2 land, `.spendCurrency` becomes a real possible outcome of the *existing* quest-generation and quest-replacement paths the next time either fires.

---

## 4. Numbers — first cut, explicitly deferred to playtesting, not adopted as final

Same posture as every first-cut table in this project, and — per design-authority review, 18 Aug 2026 — deliberately **not** locked in the way D6's own daily numbers were. Unlike D6's dailies (sized against a real per-day supply model), standing quests persist until claimed rather than resetting on a fixed cadence, so there's no equivalent "fraction of daily income" anchor to size against directly. The table below is a considered starting point for implementation and playtesting, not a confirmed final table: **reuse D6's own vetted easy-tier numbers as the easy baseline** (40 kibble / 8 dog tags — already checked against the real kibble economy model, not re-derived from scratch), then scale medium/hard/legendary using the same *rate* of growth the existing standing-quest goal types already use between their own difficulty steps (`.mergeAny`: 3→6→10, roughly ×2.0 then ×1.67; `.spawnBase`: 5→8→12, roughly ×1.6 then ×1.5) — so the new goal type's difficulty curve reads consistently with every other quest a player sees, not on its own unrelated scale.

| Difficulty | Kibble target | Dog Tags target |
|---|---|---|
| Easy | 40 | 8 |
| Medium | 70 | 14 |
| Hard | 110 | 22 |
| Legendary | 220 | 44 |

Legendary reaching ~30–36% of a single day's *entire* modelled kibble supply (~615–745/day, D6 §2) is deliberate, not an oversight — legendary is already the tier where other goal types ask for the most (e.g. `reachTier` targeting the deepest, slowest-to-reach chain tiers) and realistically spans multiple days of play before completion, the same way a legendary `reachTier` goal already does. It's also the row with the shakiest derivation (no direct `.mergeAny`/`.spawnBase` legendary precedent to scale from — see §4's own methodology note above) and the single biggest ask in the table, which is exactly why it isn't being treated as settled here. **Implementation can proceed with this table as the starting point (§3 doesn't depend on the exact values), but treat all four rows — legendary especially — as subject to revision once real play data exists, not as confirmed tuning.**

---

## 5. Screen verification

No calendar window, no monetization gate, no debug lever needed (§3.4) — live the moment 3.1–3.2 land, the next time a quest slot generates or refreshes (on `setupQuests` at a fresh install, or via `claimAndReplace` after claiming any existing quest — both fire constantly in normal play). Verify: a standing-quest slot occasionally rolls "Spend N Kibble"/"Spend N Dog Tags" at each difficulty (may take several claims/resets, since it's one of several pool entries picked at random per slot); spending the matching currency via any real sink visibly advances progress on any active quest with a matching goal; claiming a completed spend-quota quest pays the normal per-difficulty reward and replaces it with a fresh quest, same as any other goal type.

---

## 6. Open questions for design-authority review

Design-authority review complete as of 18 Aug 2026 — every fork below was addressed:

- **RESOLVED — the reward-rebate question in §2.** Confirmed: no special case. `claimQuest`'s existing uniform per-difficulty reward applies to spend-quota quests exactly like every other goal type, not suppressed or reduced.
- **DEFERRED — §4's numbers.** Explicitly *not* locked in as final, unlike D6's own daily numbers — reviewed and deliberately left open pending real playtesting data, especially for legendary (the shakiest derivation and the single biggest ask in the table). Implementation can still proceed using the table as a starting point (§3 doesn't depend on the exact values); the numbers themselves just aren't confirmed tuning yet. Revisit once real play data exists.
- **RESOLVED — currency symmetry.** Confirmed: both kibble and dog-tag spend goals are eligible at all four difficulties, symmetrically, matching the draft's default. Kibble and dog tags are both available from the start of a save, unlike `reachTier`'s conditional pruning (driven by actual unlock progression — a stage genuinely isn't reachable yet) — no equivalent state-driven reason exists to exclude either currency from any difficulty.

Nothing left blocking implementation — §4's numbers are deferred by design, not unresolved.

---

## 7. Out of scope

- **Any change to D6's dailies** — this spec only touches the standing-quest (`Quest`) system; `DailyChallenge`'s spend-quota behavior is unchanged.
- **A special reward mechanic for spend-quota quests** — see §2; deliberately reuses the existing uniform per-difficulty reward.
- **Re-deriving §4's numbers against a real standing-quest economy model** — none exists (unlike D6's daily-supply anchor), and building one is a bigger undertaking than this follow-up's own scope; the growth-rate-matching approach is a considered first cut, not a formal model.
- **Extending further to any other goal-bearing system** (e.g. weekly/monthly goals) — not asked for, not investigated.
