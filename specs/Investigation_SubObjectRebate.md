# Claude Code prompt — trace the sub-object → kibble return rate

**Investigation only. Change no code.** I need numbers read out of the implementation, not from the GDD — the GDD has already proven wrong on this system once.

## Why

Phase 2 makes the spawn multiplier energy-neutral (`cost = 2^tierIndex`). Under that pricing, tapping at ×1 becomes a legitimate strategy rather than a beginner's default. That makes any *per-tap* kibble rebate scale inversely with cost, and the sub-object system looks like it contains one.

Rough sketch of the concern, to be confirmed or demolished:

- `SubObjectDropConfig.baseSubObjectChance = 0.20` — 20% of spawner activations yield a sub-object instead of an animal
- `SubObjectSystem.powerUpEffect(for:)` maps **tier**, not drop rarity → tier 2 = `.spawnerRefill`
- Reaching tier 2 needs 4 tier-0 sub-objects → ~20 activations
- If Spawner Refill grants +20 kibble, 20 activations at ×1 cost 20 kibble and return 20 — **break-even, while still yielding 16 animals.** Free progress, indefinitely.

Under current (non-neutral) pricing this is invisible: at ×8 a tap costs 8 kibble and the rebate is ~12%. Under neutrality it may be unbounded.

## What to find

Report exact values with file and line references.

1. **The Spawner Refill grant.** Where does `.spawnerRefill` actually add kibble, and how much? Look in `SubObjectSystem.applyPowerUp` and its call site in `MergeBoardViewModel`. `grep` for the toast string `"Bonus kibble added"` and work outward — a previous search found the toast but not the grant, so confirm the grant exists at all. **If it does not exist, say so** — that would mean the GDD's "+20 Kibble" is aspirational and the effect is currently a no-op.

2. **Confirm the tier → effect mapping.** Is `powerUpEffect(for:)` genuinely keyed on `item.tier` (0 = Speed Burst, 1 = Map Supplies, 2 = Spawner Refill, 3 = High-Tier Drop)? If so, what is the weighted rarity roll at drop time (`weightedRarityRoll`, 60/25/10/5) actually used for, given it doesn't select the effect? Trace whether the returned `rarity` influences anything beyond pity counters.

3. **Sub-object chain depth.** Confirm `ItemChain.makeSubObjectChain` produces exactly 4 tiers, and that 2 items merge to the next tier (so 4 tier-0 → 1 tier-2).

4. **Modifiers.** Does `cachedActiveBonuses.subObjectDropRateBonus` from Sanctuary Map upgrades raise the 20%? By how much at full upgrade across all areas? Same question for `pityTimerReduction` and the Rodents "Hoard" superpower (which spawns sub-objects at tier 1 instead of 0 — that would halve the cost of reaching tier 2).

5. **Natural throttles.** What limits how many power-ups a player can farm and hold? `InventoryStore.powerUpInventory` is 6 slots — confirm. Is there any cooldown, daily cap, or board-space constraint that bounds the loop in practice?

## Report back

Give me a short table:

| Question | Value | File:line |
|---|---|---|

Then one derived number, showing your working:

> **Effective kibble returned per spawner activation**, assuming a player merges every sub-object to tier 2 and applies it — at base 20% drop rate, and again at the maximum drop rate reachable through area upgrades.

If that number approaches or exceeds 1.0, the ×1 tapping loop is self-funding under neutral pricing and Phase 2 needs a countermeasure before any other number is set.

## Explicitly out of scope

Do not fix, rebalance, or refactor anything. Do not touch the GDD. This is a read-and-report task — the fix depends on the number, and the number is what I don't have.
