# PawSanctuary — Spend-Quota Dailies (D6)

**Self-contained brief.** Assumes no prior conversation.

> **Not atomic.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists.

**DRAFT — written cold by Claude Code at the user's request, same exception made for Pass/Parallel Board/the 6c calendar/the Reward Ladder. Not yet reviewed by the design authority.** This spec exists because D6 was decided 18 Aug 2026 (`specs/PawSanctuary_Alignment_Plan.md` §"D6 — Spend-quota tasks in dailies?"): **adopt** — a "Spend N currency" daily-challenge task type, overriding that section's own "out, at least at launch" recommendation. No implementation task existed for this yet; this draft is that task, proposing the concrete shape the Alignment Plan's own entry left unresolved (it says only "size the spend quota against the existing daily-challenge reward curve... not guessed" — it doesn't say which currency, how the task fits the existing daily-challenge generator, or what happens to reward pacing). See §6 for what's flagged rather than assumed.

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
| Currency scope | `RewardKind` (`AnimalSpecies.swift:768-777`, existing enum — already has `.kibble`/`.dogTags`) | Reuse verbatim, no new type. **v1 restricts generation to `.kibble` only** — see §2's currency-choice note below |
| Anchor | `DailyChallengeAnchor` (`QuestCoordinator.swift:256-279`, existing private enum) | New case: `.spendKibble`, added to the existing random pool in `pickDailyChallengeAnchor` (`:292-307`) |
| Difficulty counts | `staggeredCount(after:)` (`QuestCoordinator.swift:313-316`, existing) | Reused as-is — only a new `baseEasyCount` value needed (§4), medium/hard fall out automatically |
| Progress increment | **New** — no existing pathway handles variable-amount progress | `QuestCoordinator.updateDailyChallengesAfterSpend(kind:amount:)`, mirroring `updateDailyChallengesAfterMerge`/`Rescue` but doing `progress += amount` instead of `+= 1` |
| Chokepoint | **New** — no shared spend/deduct helper exists anywhere in the codebase today | `MergeBoardViewModel.updateAllAfterSpend(kind:amount:)`, mirroring `updateAllAfterMerge`/`updateAllAfterRescue`; called additively at each real kibble-spend site (§3.2), leaving the sites' own existing balance math untouched |
| Reward | `checkAllDailyChallengesComplete` (`QuestCoordinator.swift:355-372`, existing, unchanged) | **None new.** Dailies today pay nothing per-slot — only an all-three-complete bonus (2/8 dog tags on a 7-day streak, 30 XP, 400+ coins). A spend-quota slot is just a fourth-shape contributor to that same existing bonus, no new reward mechanic |
| UI | `DailyChallengeTaskCard` (`PanelViews.swift:1503-1540`, existing, unchanged) | None — already fully generic over `QuestGoal` |

### Currency choice: kibble only, dog tags explicitly deferred

The Alignment Plan's instruction is to size this against a modelled curve, not guess. `PawSanctuaryTests/EconomySimulation.swift` (test-target only, never ships) already models kibble supply rigorously — `dailySupply(level:)` puts an engaged player at **~615–745 kibble/day** (passive regen + ad watches + a lump "misc" constant that, notably, already folds in today's zero-kibble-paying daily challenges). **Dog tags have no equivalent model anywhere in the codebase.** Building one from scratch, rather than eyeballing the existing dog-tag sink table (wildcard 100, producers 5/15/30, store items 15-69, etc. — `AnimalSpecies.swift`), is exactly the kind of unmodelled guess the plan's own instruction was written to avoid. **Proposal: `.spendCurrency` generation restricted to `.kibble` for v1** — the enum case itself stays currency-generic (`RewardKind`, not a kibble-only type) so dog-tag spend quotas are a cheap follow-up once a dog-tag economy model exists, but nothing generates one yet. Flagged in §6, not assumed silently.

### Existing kibble-spend sites this hooks into

No shared `spend()`/`deduct()` helper exists for kibble anywhere in the codebase — confirmed by grep. Every site independently does its own `guard`+`-=`. The real kibble sinks:

| Site | File:line | Cost |
|---|---|---|
| Rescue-producer spawn | `MergeBoardViewModel.swift:1368` (`finishSpawn`) | `spawnCost(forTier:) = 1 << tier` — 1, 2, 4, 8, 16, 32… by spawn tier |
| Skip an adoption order | `MergeBoardViewModel.swift:3244` (`skipOrder`) | `adoptionSkipCost = 2` |

Both are real, repeatable, everyday actions — not one-time unlocks — so both are real candidates for a daily quota to track. (Dog Tag → Kibble exchange spends dog tags to *gain* kibble — not a kibble sink, excluded.)

### Standing quests (`Quest`, not `DailyChallenge`) — out of scope

The Alignment Plan's D6 text says "dailies" specifically. The standing-quest system (`Quest` struct, `QuestCoordinator.swift`'s `generateQuest`/`updateQuestsAfterMerge`) is structurally near-identical and could pick up the exact same `QuestGoal.spendCurrency` case cheaply later, but extending to it isn't attempted here — not asked for, and legendary/hard standing quests already pay real kibble/dog-tag rewards (§3 of `QuestDifficulty`), which changes the "does this need a new reward mechanic" answer this spec's dailies-only scope avoids.

---

## 3. Tasks, suggested landing order

### 3.1 — `QuestGoal.spendCurrency` case + generic switches

Add to `QuestGoal` (`AnimalSpecies.swift:619`):

```swift
case spendCurrency(RewardKind, count: Int)
```

- `targetCount`: add to the existing tuple-pattern switch (`:625-628`).
- `description`: e.g. `"Spend \(c) Kibble"` for `.kibble`; a `default`/`.dogTags` branch can exist for forward-compatibility even though nothing generates it yet (§2).
- `icon`/`iconColor`: reuse the same iconography `ShopView.swift`'s kibble rows already use (`"pawprint"`, green) rather than inventing new symbols.
- `dedupeKey`: `"spendCurrency:\(kind.rawValue)"` — irrelevant to dailies (dedup only matters for standing quests, §2) but keeps the switch exhaustive and correct if this case is ever reused there.

### 3.2 — Progress pathway: `updateDailyChallengesAfterSpend` + `updateAllAfterSpend`

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

### 3.3 — Wire the chokepoint into the two real kibble sinks

Additive only — neither existing site's own balance math changes:

- `finishSpawn(item:at:cost:)` (`MergeBoardViewModel.swift:1368`): after `kibbleEngine.kibble -= cost`, add `updateAllAfterSpend(kind: .kibble, amount: cost)`.
- `skipOrder()` (`MergeBoardViewModel.swift:3244`): after its kibble deduction, add the same call with `amount: adoptionSkipCost`.

**Guard against future sinks going unnoticed:** any *new* kibble sink added later needs this same call, and there's no compiler-enforced way to catch a forgotten one (matches the existing pattern's own risk — `updateAllAfterMerge`/`Rescue` have the identical property, every merge/rescue call site must remember to call them). Flagged, not solved — same posture the rest of this codebase already accepts for this class of problem.

### 3.4 — Add the anchor to the daily-challenge generator

`QuestCoordinator.swift`:

- `DailyChallengeAnchor`: new case `.spendKibble`, with `goal(count:)` returning `.spendCurrency(.kibble, count: count)` and `baseEasyCount` returning the value from §4.
- `pickDailyChallengeAnchor` (`:292-307`): add `.spendKibble` to the `pool` array, unconditionally (kibble always exists from the start of a save, unlike e.g. `.mergeInChain` which needs an unlocked chain first) — so it's eligible from day one, same footing as `.mergeAny`/`.spawnBase`.

**This is the spec's biggest open design question, flagged rather than decided here — see §6.** Because one anchor is shared across all three of a day's slots, days where `.spendKibble` gets picked mean **all three** daily challenges are "spend kibble" that day, just at three staggered thresholds — not one spend slot mixed with two others. Whether that reads as fine (consistent with how every other anchor already works) or as exactly the kind of day the Warmth-pillar objection was worried about (three moneyish tasks in a row) isn't something to guess at silently.

### 3.5 — Test content: none needed

Unlike D8, this doesn't add new registry content — the daily-challenge generator already runs continuously in production. Once 3.1–3.4 land, `.spendKibble` becomes a real possible outcome of the *existing* daily reset the next time it fires (or immediately, if reached via the existing `resetToFreshGame()` debug tooling — which, unlike the Reward Ladder's monetization gate, has no equivalent blocker here: daily challenges regenerate on every fresh install with no additional unlock condition).

---

## 4. Numbers — first cut, flag before trusting

Same posture as every other first-cut table in this project: modelled where a model exists (kibble does — see §2), not run through a full economy simulation for this specific quota.

- **Easy-slot kibble quota: 40.** Against the ~615–745 kibble/day modelled supply (§2), 40 is roughly 5–6% of a day's income — comparable in "how much of a normal day's play does this ask for" terms to `.mergeAny`'s easy count of 3 merges (a task of similar throwaway effort, not a grind). Achievable via ~2 mid-tier producer purchases or ~20 order-skips, well within a single session.
- **Medium/hard: not hand-picked.** `staggeredCount(after: 40)` (`QuestCoordinator.swift:313-316`) already produces a random value in roughly the 47–62 range at generation time, and hard follows the same way from medium (roughly 55–95) — this reuses the exact mechanism every other anchor's medium/hard counts already come from, so there's no new formula to get wrong, only the one easy-count seed value above.
- **No new reward number.** The existing all-three-complete bonus (2/8 dog tags, 30 XP, 400+ coins) is unchanged — see §2.

---

## 5. Screen verification

No calendar window, no monetization gate, no debug lever needed (§3.5) — this is live the moment 3.1–3.4 land, the next time `checkDailyChallengeReset` fires (once per real day, or immediately via `resetToFreshGame()`'s existing dev reset). Verify: a fresh install occasionally rolls a "Spend N Kibble" trio (may take several resets, since the anchor is one of ~4-5 in the pool and picked uniformly at random); spending kibble via a producer purchase or order skip visibly advances the progress bar on all matching slots; completing all three still pays the existing bonus.

---

## 6. Open questions for design-authority review

This draft has **not** had a design-authority pass yet — everything below is genuinely open:

- **The biggest one, per §3.4:** should `.spendKibble` sharing the anchor mechanism mean *all three* daily slots can be spend-kibble on the same day, same as every other anchor already works — or does the Warmth-pillar concern this decision explicitly overrode (not refuted, §0) mean spend-quota tasks should be capped to *at most one* of the three slots per day, as a deliberate design accommodation? The former is the simpler, more-consistent-with-existing-code default this draft assumes; the latter is real extra work (breaking the shared-anchor assumption that's been true for every goal type so far) done specifically to soften the mechanic the decision already chose to adopt anyway.
- **Currency scope (§2):** kibble-only for v1, dog tags deferred pending a dog-tag economy model — confirm, or decide dog tags matter enough to model now.
- **§4's numbers** — the 40-kibble easy seed, as always.
- **Whether standing quests should get this goal type too** (§2) — not attempted here, explicitly out of scope, but cheap to add later given the shared `QuestGoal` type.

---

## 7. Out of scope

- **Dog-tag spend quotas** — see §2/§6; the enum case supports it, generation doesn't use it yet.
- **Standing-quest (`Quest`) spend goals** — see §2.
- **A cap on spend-anchor frequency or same-day repeats** — see §6; not addressed, flagged as the main open question instead of guessed at.
- **Any new reward mechanic** — deliberately reuses the existing all-three-complete bonus untouched.
- **Revisiting the Warmth-pillar objection itself** — that's D6's own decision, already made (§0); this spec only builds what was decided.
