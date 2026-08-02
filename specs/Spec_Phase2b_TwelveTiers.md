# PawSanctuary — Phase 2b: Reduce chains from 15 tiers to 12

**Self-contained brief.** Assumes no prior conversation. Follows Phase 2 (commit `a36faed`).

> **Atomic, like Phase 2.** Content, code, migration and re-tune land in one commit. The game is unplayable in between.

---

## 0. Why

Phase 2's tuning capped `maxAchievableOrderTier` at 9 against a 15-tier chain. That was the correct call for the ratio curve, but it left **Stages 10–15 — six of fifteen stages across fifteen families, 90 named items — outside the order economy entirely.** Their only remaining purpose was the Ambassador milestone, collection completeness and score.

Twelve tiers puts the top of the chain back inside the loop:

| | 15 tiers | 12 tiers |
|---|---|---|
| Top-tier cost (neutral pricing, `2^tier`) | 16,384 kibble | **2,048 kibble** |
| Days at ~745/day total income | ~22 | **~2.7** |
| Days at 20% attention | ~110 | **~14** |
| Reachable by orders? | No (capped at 9) | **Yes** |

It also partially mitigates a recorded defect: `RescueStage` limits quest goals to tiers 0–8, which now covers nine of twelve stages rather than nine of fifteen.

---

## 1. The content change

`AnimalSpecies.tierNames` is formatted in source as **five rows of three** — the five conceptual eras. Delete **the fourth row from every family**, preserving the 3-tier era grouping (12 = 4 eras × 3).

Canines, as the worked example:

```swift
case .dog: return ["Pup", "Kit", "Houndling",          // Era 1
                   "Terrier", "Spaniel", "Scout",       // Era 2
                   "Retriever", "Shepherd", "Husky",    // Era 3
                   "Dire Wolf", "Mythic", "Primordial"] // Era 4 (was Era 5)
```

Removed: `"Alpha", "Guardian", "Sentinel"` — old indices 9, 10, 11.

Apply the identical rule to all 15 families: **drop old indices 9–11, keep 0–8 and 12–14.** Do not rename or resequence anything else. 225 names → 180.

New max tier index = **11**.

---

## 2. Code changes

### 2.1 Hardcoded top-tier references

`grep` for `14`, `15`, `maxTier`, `ambassador` and `isTopTier` across the codebase. Every top-tier check must derive from the chain's actual `maxTier`, never a literal.

Known sites to verify: the Ambassador celebration trigger, `MilestoneManager`'s ambassador counting, `PersistenceTests`' `makeSampleState()` (which previously hardcoded a "top tier" fox and was already corrected once for exactly this reason).

### 2.2 `sellValue(forTier:)` — `MergeBoardViewModel.swift:470`

Currently a 15-entry table:

```swift
[1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 25000, 100000]
```

Deleting indices 9–11 leaves a 500 → 10,000 jump. **Re-derive as a smooth 12-entry geometric series** rather than splicing. Suggested, roughly 2.6× per step:

```swift
[1, 2, 5, 12, 30, 75, 180, 450, 1100, 2800, 7000, 18000]
```

Sell value should stay meaningfully below the item's kibble cost (`2^tier`) at low tiers and above it at high tiers, so selling is a late-game liquidity option rather than an early-game exploit. Verify that property holds before committing.

### 2.3 Superpower unlock

Unlocks at tier index 6 (start of Era 3). **Unaffected** — Era 3 survives, and index 6 still lands on the same stage. Confirm rather than assume.

### 2.4 `recirculationMaxItemTier`

Currently 7, derived against a 15-tier chain where top = 16,384. Against a 12-tier chain top = 2,048, so a cap at 7 (128 kibble) is now a much larger fraction of the top. **Re-derive from the simulation** in §4 — do not carry the old value forward.

---

## 3. Migration (the risky part)

Existing saves contain items, adoption orders, quest goals and collection entries at tiers 0–14. There is precedent: `migrateV17toV18` already performed a tier remap when chains shrank from 10 to 9.

**Mapping:**

```
old 0–8   →  new 0–8    (unchanged)
old 9–11  →  new 8      (Alpha/Guardian/Sentinel collapse to Husky)
old 12–14 →  new 9–11   (shift down by 3)
```

Collapsing 9–11 to 8 is a demotion, chosen because mapping upward would collide with the shifted 12–14 range. Pre-launch this only affects development saves.

**Every stored tier must be remapped, not just board items.** Audit at minimum:
- `board` items
- animal inventory and power-up inventory
- `adoptionOrders[].wantedTier`
- `QuestGoal.reachTier` associated values
- `activeQuests` and `dailyChallenges` goals
- any card/collection or milestone state keyed on tier
- `deepestUnlockedTier` (added in Phase 2)

Bump to **v28**, follow the existing `migrateV17toV18` structural pattern, and **add the new defaults to `additiveDefaultsSinceV8`** so the flat dispatch handles them — the consolidated table introduced in Phase 2 exists precisely for this.

Add a `PersistenceTests` case constructing a v27 save containing items at old tiers 8, 10, 13 and 14, and asserting they land at new 8, 8, 10 and 11.

---

## 4. Re-tune

Phase 2's `maxAchievableOrderTier` (2/3/4/5/7/8/9) and `orderTierBands` (0.38/0.28/0.24/0.06/0.02/0.02) were swept against a 15-tier chain. Both are now invalid.

Re-run the Phase 2 §5 debug simulation and re-sweep jointly against the same target curve:

| Band | Ratio | Reading |
|---|---|---|
| L1–30 | < 0.70 | Comfortable |
| L31–40 | 0.70 → 0.95 | Tightening |
| **L41–50** | **crosses 1.00** | First genuine wall |
| L51+ | 1.05 – 1.25 | Persistent, never punitive |

**New requirement:** the top band's `maxAchievableOrderTier` should now reach **10 or 11**. If the curve can only be satisfied by capping below 10, say so and stop — that would mean 12 tiers is still too deep and the number needs revisiting, which is exactly what this phase exists to test.

Re-derive `recirculationMaxItemTier` in the same sweep. Watch for the failure mode found in Phase 2, where recirculation outgrows demand and the ratio *falls* in late bands.

---

## 5. Acceptance

- [ ] All 15 families have exactly 12 tier names; old indices 9–11 removed, nothing renamed
- [ ] No hardcoded 14 or 15 remains as a top-tier reference
- [ ] `sellValue` is a smooth 12-entry series with the cost relationship in §2.2 verified
- [ ] A v27 save with items at old tiers 8/10/13/14 migrates to new 8/8/10/11, with **all** tier-bearing state remapped
- [ ] Simulation hits the §4 curve within ~0.1, with top-band order tier ≥ 10
- [ ] Full test suite green
- [ ] Sanity-play from a fresh save through the first wall, and from a migrated save

---

## 6. Out of scope

- `RescueStage` still limiting quests to tiers 0–8 — improved but not fixed; recorded in `TODO.md`, belongs with Phase 5
- Anything in Phases 3–6
- GDD updates — the tier tables in §4 will be stale after this; flag it, don't fix it in the same commit
