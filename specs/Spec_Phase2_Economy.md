# PawSanctuary — Phase 2 Implementation Spec: Economy Correction

**Read this as a complete, self-contained brief.** It assumes no prior conversation.

> ## ⚠️ This phase is atomic
>
> Every task below must land in **one commit**. The game is broken in the intermediate states — a neutral multiplier without recirculation makes late chains unreachable, and recirculation without the multiplier fix makes the existing arbitrage worse. Build it all, test it, commit once.
>
> This is the only phase in the alignment plan with that property.

---

## 0. Context

PawSanctuary is an iOS merge-2 game being aligned against three measured competitors. Phase 1 (foundations) is complete: order rewards are an extensible `[OrderReward]` list, `OrderRewardRegistry` exists for rider injection, `ChainCategory.currency` is declared, commerce state is recording, and live-ops protocol stubs are in place.

Phase 2 fixes the economy. Three defects interlock:

1. **The spawn multiplier is a 16× arbitrage.** `spawnTier = min(spawnMultiplier - 1, maxTier)` at `cost = spawnMultiplier` means ×8 buys an 8-kibble item worth 128 kibble of merging. Unlocks at level 20 and never closes.
2. **There is no recirculation.** Orders pay currency and card packs, never items. The multiplier is currently the *only* thing making deep tiers reachable — which is why it had to be broken.
3. **Spawner Refill is an unbounded kibble faucet** that only becomes visible once the multiplier is fixed. See §3.

---

## 1. Reference targets

Measured from Gossip Harbor, Travel Town and Tasty Travels (July 2026):

| Property | Reference | PawSanctuary today |
|---|---|---|
| Boost pricing | **Exactly energy-neutral** at every level | 16× arbitrage at ×8 |
| Chain depth | 8–14 tiers | **15 tiers × 15 families** |
| Endgame recirculation | **~97%** of order demand | ~0% |
| Energy regen | 1 per 120 s | 1 per 120 s ✓ |
| Energy cap | ~100, barely scales | 100 → 150 at L10 ✓ |
| Ad reward | 25 energy, 3/day | 25, 4/day ✓ |

**Measured daily kibble supply for an engaged L20+ player: ~695 (cap 100), ~745 (cap 150), ~800 with the Sanctuary Pass.** Regen ~520, ads 100, and ~75 from login/Loyalty/quests/challenges/weekly goals.

**Cost to build one item from scratch under neutral pricing is `2^tierIndex` kibble.** Stage 11 = 1,024. Stage 13 = 4,096. Stage 15 = 16,384 — roughly 22 days of *total* income, so it is unreachable by tapping and must come from recirculation.

---

## 2. Task 2.1 — Neutral spawn multiplier

### Current

`MergeBoardViewModel.activateProducer`, ~line 1066 (family spawner) and ~line 1132 (legacy producer):

```swift
let cost = progression.spawnMultiplier              // 1 / 2 / 4 / 8
var spawnTier = min(progression.spawnMultiplier - 1, maxTier)
```

Yields tier index 0/1/3/7 for cost 1/2/4/8 — that is, ×8 pays 8 kibble for an item worth 2⁷ = 128.

### Target

The multiplier selects a **tier**, and cost is `2^tier`:

| Multiplier | Tier index | Stage | Cost | Worth | Ratio |
|---|---|---|---|---|---|
| ×1 | 0 | 1 | 1 | 1 | 1.00 |
| ×2 | 1 | 2 | 2 | 2 | 1.00 |
| ×4 | 2 | 3 | 4 | 4 | 1.00 |
| ×8 | 3 | 4 | 8 | 8 | 1.00 |

Implementation:

```swift
let spawnTier = min(tierIndex(forMultiplier: progression.spawnMultiplier), maxTier)
let baseCost  = 1 << spawnTier      // 2^tier
```

where `tierIndex(forMultiplier:)` maps 1→0, 2→1, 4→2, 8→3 (i.e. `Int(log2(Double(m)))`, or a small switch — prefer the switch, it is clearer and total).

**Preserve these existing modifiers, applied to the new cost:**
- **Bask** (Reptiles `.turtle`): halves cost — keep `max(1, cost / 2)`
- **High-Tier Drop** buff: forces `spawnTier = min(2, maxTier)` — keep, but note it now costs whatever the *selected* multiplier costs, not the forced tier's cost. That is intended: it is a buff.
- **Hibernate** (Ursids `.owl`): forces tier 2 after 5 idle minutes — same treatment

Put the multiplier→tier mapping in `AnimalSpecies.swift` with the other tuning constants, not inline.

---

## 3. Task 2.2 — Remove kibble from the sub-object reward table

### Why this is in Phase 2 and not deferred

`SubObjectSystem.swift:149` grants a flat `+20` kibble for a tier-2 Spawner Refill, bypassing `kibbleRegenCap`. Effect is keyed on merged tier, so 4 tier-0 sub-objects → 1 Spawner Refill, and 20% of spawner activations produce a sub-object.

Expected return per activation = `p(drop) × 20 / 4`:

| Condition | Drop rate | Kibble per activation |
|---|---|---|
| Base | 0.20 | **1.00** |
| Full area upgrades (+45 pp) | 0.65 | **3.25** |
| Base + Hoard (Rodents) | 0.20 | **2.00** |
| Full upgrades + Hoard | 0.65 | **6.50** |

Under today's pricing an ×8 tap costs 8 kibble, so this is a ~12% rebate — invisible. **Under Task 2.1's neutral pricing an ×1 tap costs 1 kibble and returns 1.00 in expectation** — self-funding at base rate, outright profitable with upgrades, with no cooldown, no daily cap, and 6 power-up slots that spill into animal inventory rather than capping.

Reducing the grant does not fix the shape. The rebate and the cost are denominated in the same per-tap unit, so any per-tap currency grant fights neutral pricing at some drop rate.

### Change — restore rarity-selected effects, and drop kibble from the table

**Decision (27 July):** wire the rarity roll through to effect selection, rather than repurposing the dead upgrades. This turns out to be the *same* change as removing the kibble faucet, so both land here.

The current tier-keyed mapping is drift. The GDD's own overview line has always said "reaching tier 3 (the top tier) yields a power-up consumable" — effects were meant to be rolled, not chosen by stopping at a tier.

**Target behaviour:**

1. Sub-objects spawn at tier 0 (tier 1 with the Rodents Hoard superpower) and merge normally through the 4-tier chain.
2. **Only tier 3 is a usable power-up.** Tiers 0–2 are inert intermediates — applying one does nothing (or is disallowed in the UI; prefer disallowing).
3. When a sub-object reaches tier 3, roll its effect **at that moment** via `weightedRarityRoll()`, honouring the accumulated `PityState` for that family. Store the rolled rarity on the resulting item so it survives save/load and is visible in the power-up inventory.
4. `powerUpEffect(for:)` reads the stored rarity instead of switching on `item.tier`.

**Revised effect table** — Spawner Refill is replaced, the weights are unchanged:

| Effect | Weight | Payload |
|---|---|---|
| Speed Burst | 60% | 2× spawner speed, 30s + `powerUpDurationBonus` |
| Map Supplies | 25% | 4 random wood/metal/cement items, tier 0–2 |
| **Board Item Grant** | 10% | **NEW** — replaces Spawner Refill. One board item from a random unlocked animal chain at tier `max(0, deepestUnlockedTier - 2)`, placed on the board or to inventory if full. Track "deepest unlocked tier" in `GameState`. |
| High-Tier Drop | 5% | Forces the next spawn to tier ≥ 2 |

**Why this kills the exploit rather than just shrinking it.** The player can no longer target the reward by stopping at tier 2 — it is a 10% roll on a tier-3 merge, gated by pity. And the payload is an *item*, not energy, so it is immune to the per-tap arithmetic entirely. It becomes a recirculation channel scaling with tenure (§4), which is exactly what the endgame needs.

**This also repairs three recorded defects at once:**
- `pityTimerReduction` on 8 Sanctuary Map upgrades starts doing something — players stop paying for a no-op
- `SubObjectRarity`, `weightedRarityRoll()` and `PityState` stop being dead code
- GDD §5 (already rewritten from source on 27 July) becomes accurate again for a second reason

**Persistence:** the rolled rarity must be stored on the `BoardItem` (or in a side table keyed by item ID) and migrated. Existing tier-3 sub-objects in saved games have no stored rarity — assign them Speed Burst on migration, the most common outcome, rather than re-rolling.

**Trade-off, accepted:** players lose the ability to choose their effect by choosing when to stop merging. That agency was an accident of the drift, not a designed feature, but it *was* better play than a random roll. If the loss is felt in testing, the mitigation is the pity timer — which now works — rather than reverting to tier-keyed selection.

## 4. Task 2.3 — Recirculation

Endgame arithmetic: a Stage-15 item costs 16,384 kibble. If a player spends ~20% of ~700 daily kibble on top-chain progress, taps supply ~2,000 over two weeks. Recirculation must supply the remaining **~14,400 — about 1,030 kibble-equivalent per day in items.**

That is roughly four Stage-9 items (256 each) or one Stage-11 (1,024) per day, arriving from rewards. It must scale with tenure.

Three channels, all using the Phase 1 `[OrderReward]` list:

### 3a. Orders pay items

In `AdoptionBoard.generateOrder`, append a `.boardItem` reward to a fraction of orders.

- **Frequency:** start at **1 order in 3**
- **Tier:** `wantedTier - 3`, floored at 0 — a meaningful fraction of the order's own cost, never the full item
- **Chain:** a random unlocked animal chain, not necessarily the one requested

Handle `.boardItem` in `MergeBoardViewModel.autoClaimOrder` — the switch already has the case stubbed with `break`.

### 3b. Chests contain items

Wherever chests currently pay currency, add a board item at the same tier rule. If no chest reward table exists yet, add the payload type and wire one chest source; a full table is Phase 6.

### 3c. Board items purchasable with Dog Tags

Per recorded decision D3, stock-limited. Reference pricing: mid-tier items sell for 9–70 gems with stock limits, and a store reroll costs less than the cheapest item.

- Offer **3 slots**, rotating daily
- Tier range: `deepestUnlockedTier - 4` through `deepestUnlockedTier - 1`
- Stock limit **1 each**
- Price scaled to tier — anchor so the top slot is a meaningful but not trivial Dog Tag spend

This is also a conversion path that fires at the moment of highest intent: a player blocked on one specific item.

---

## 5. Task 2.4 — Reverse the Dog Tag → Kibble ladder

`AnimalSpecies.swift:879` currently:

```
40 tags → 100 kibble   (2.5 kibble/tag)
80 tags → 240 kibble   (3.0)
120 tags → 480 kibble  (4.0)
```

A **volume discount** — it rewards bulk absorption and lets a payer flatten the pacing curve.

The reference games do the opposite: an **escalating daily ladder that resets**. Measured: 10 → 20 → 40 gems for an identical 100 energy, with roughly 320 discounted energy available per day before the rate goes flat.

Replace with a within-day escalating ladder, keyed off a `lastExchangeResetDate` in `GameState`:

| Purchase # today | Kibble | Dog Tags | Rate |
|---|---|---|---|
| 1st | 100 | 15 | 6.7 |
| 2nd | 100 | 30 | 3.3 |
| 3rd+ | 100 | 60 | 1.7 |

Resets daily. Tune the tag costs against your Dog Tag income — the *shape* is the requirement, the absolute numbers are yours.

This caps how much cheap energy any player can absorb per day, which is what protects the pacing curve.

---

## 6. Task 2.5 — Retune and validate

Add a **debug-only simulation** (not shipped) that reports, for representative player levels:

- Daily kibble supply (regen + ads + login + Loyalty + quests + challenges)
- Daily kibble demand (orders at their generated tiers, at expected completion rate)
- **Ratio = demand / supply**

Target curve:

| Band | Ratio | Reading |
|---|---|---|
| L1–30 | < 0.70 | Comfortable — required for the "no monetization in session one" decision to hold |
| L31–40 | 0.70 → 0.95 | Tightening; player learns energy is finite |
| **L41–50** | **crosses 1.00** | **First genuine wall. Phase 3 puts the first-purchase offer here.** |
| L51+ | 1.05 – 1.25 | Persistent, never punitive |

Above 1.30 anywhere is a churn risk, not a monetization opportunity.

**Tune `maxAchievableOrderTier` and the order tier-weighting table in `AdoptionBoard.generateOrder` to hit this curve.** Those are the primary dials. Do not tune by changing regen or cap — those match the measured reference and are correct.

---

## 7. Acceptance

- [ ] No multiplier level produces an item at a discount to its merge cost — verify all four arithmetically in a test
- [ ] Sub-object farming returns **zero kibble**; a tier-2 power-up grants a board item
- [ ] At least one order in three carries a `.boardItem` reward, and `autoClaimOrder` places it correctly
- [ ] Dog Tag exchange escalates within a day and resets
- [ ] The simulation reports a ratio curve matching §6 within ~0.1
- [ ] `PersistenceTests` green; new state (`deepestUnlockedTier`, `lastExchangeResetDate`, store stock) migrated with a version bump and a test
- [ ] Game is playable start to finish — sanity-play L1 through the first wall

---

## 8. Out of scope

- The dead rarity/pity subsystem and the 8 no-op map upgrades — recorded in `TODO.md`, separate fix
- `RescueStage` limiting quests to tiers 0–8 — recorded, belongs with Phase 5
- Anything touching the kibble refill sheet, ad placement, or offer gating — Phase 3
- Currency merge chains on the board — Phase 4
- Order slot count or difficulty distribution — Phase 5
