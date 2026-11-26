# Flat 10% Bonus-Spawn Chance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Boosted taps get a flat 10% bonus chance, and the economy model counts bonus spawns.

**Architecture:** One function changes in the game. The test-target model prices demand and recirculation in kibble through one function, `kibblePrice`; quantities stay in merge units by default.

**Spec:** `docs/superpowers/specs/2026-11-25-flat-bonus-spawn-chance-design.md`

## Global Constraints

- Chance: 0 at ×1, 0.10 at ×2/×4/×8. Legendary share stays 0.15.
- D14 bands, no exemption: <0.70 to L30, 0.60–<1.00 at L35/40, >1.00 at L50, >1.00–<1.35 at L55/60.
- Coin window, selling 20%: 52–70 days. Never selling: over 40, at most 75.
- No save change. No change to coin payouts, prices, order tiers or supply.
- If a figure misses a target, stop and ask. Do not tune.

## Review Focus

- ×1 must never roll a bonus and must keep price = merge worth.
- A level that has not unlocked a multiplier must not get its discount.
- An item below a multiplier's spawn tier must not get its discount.
- Helpers called without a price must still return merge units (coin payouts, generator checks, Smile share test).

(The pricing test in Task 1 pins the first three; the existing unit tests pin the fourth.)

### Task 1: Chance and model

**Files:** `PawSanctuary/AnimalSpecies.swift`, `PawSanctuaryTests/EconomySimulation.swift`, `PawSanctuaryTests/EconomyTests.swift`

**Interfaces (produces):** `EconomySimulation.kibblePrice(tier: Int, level: Int) -> Double`; `mergeUnits(_ tier: Int) -> Double`; a `value:` parameter, default `mergeUnits`, on `expectedLineCost`, both `expectedOrderCost`, `dailyTaskCostDistribution` and `recirculation`.

- [ ] Write tests: chances `[0.00, 0.10, 0.10, 0.10]`; `kibblePrice(3, level: 1) == 8`, `kibblePrice(0, level: 20) == 1`, `kibblePrice(1, level: 4) == 2`, `kibblePrice(1, level: 5) == 2 / (1 + 0.1 * 1.15 / 0.7)`, same ratio for tier 3 at L20; bands moved to `heldItemRow`; `heldItemBandBreaks()` is empty; coin window 52...70.
- [ ] Run `EconomyTests`; expect failure.
- [ ] Set the chance. Price `row`, `heldItemRow`, `dailyTaskDemand` and `grossDemandHeldItem`. In `kibbleIntoOrders`, production = `grossDemand` units × share filled (1 if priced net ≤ supply, else (supply + priced recirculation) ÷ priced gross) × efficiency.
- [ ] Retire the D12 band test and the partial D14 one; keep both monotonic tests.
- [ ] Run `EconomyTests`; expect pass. Compare with the spec's expected figures.

### Task 2: Records and verification

**Files:** `specs/PawSanctuary_Alignment_Plan.md`, `specs/Feature_Parity_Audit.md`, `PROJECT_STATE.md`, the design doc's status line

- [ ] Add D18; mark D17's gap closed; correct the Task 4.3 line, the audit row and the ledger.
- [ ] Run the full suite; expect 0 failures. Review the diff.
- [ ] Do not commit without the owner's request.
