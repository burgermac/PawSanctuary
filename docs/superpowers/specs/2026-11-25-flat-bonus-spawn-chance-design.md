# Flat 10% bonus-spawn chance, counted in the economy model

Status: approved by the owner and built, 25 Nov 2026 (D18). Built figures: never-sell 48.3 days, sell-20% 52.8 days; the daily-task coin budget test also moved to the 52-day floor.

## Intent

D17 left one gap: the economy model leaves out bonus spawns. Counted, L50 demand ÷ supply is 0.77, so there is no kibble shortage. Close the gap, and make the model count bonuses so the tests catch it next time.

## Approaches

Measured with a throwaway harness over the model (chances for ×2/×4/×8).

| Approach | L50 (D14) | Trade-off |
|---|---|---|
| **A. Flat 10% (chosen by owner)** | 1.06 | 1 bonus in 10. Fails the old orders-only bands at L50–60. Slim margin. |
| B. 3 / 5 / 5% | 1.14 | Keeps both sets of bands; bonuses become very rare. |
| C. Remove bonuses | 1.23 | Old tests pass as they are; loses the feature. |
| Raise order tier caps | none passed | 42 combinations from L21 up, caps to tier index 11. |

A and B give ×4 and ×8 the same chance. In each tested table where ×8's chance was above ×4's, the ratio dipped when ×8 unlocked at L20.

## Changes

1. **Game.** `bonusSpawnChance` returns 0 at ×1 and 0.10 at ×2, ×4 and ×8. The 85/15 Lucky/Legendary split is unchanged.
2. **Model** (`EconomySimulation.swift`). Demand and recirculation are priced in kibble. For each item tier, use the cheapest unlocked multiplier whose tier is not above it. Its value per kibble, relative to ×1, is `tier worth × (1 + chance × (1 + legendary share) ÷ animal-drop share) ÷ tap cost`. It reads the game's own functions, so a change to prices or chances moves the model.
   - Item quantities stay in merge units, so coin payouts and the checks against generated orders are unaffected.
   - Coin projection: the share of demand a player can fill uses the priced figures. Coins earned per item are unchanged.
   - Sub-object grants keep the model's existing assumption (all kibble spent at ×1).
3. **Targets** (`EconomyTests.swift`).
   - The difficulty bands are asserted on the current rule (D14, orders plus daily tasks): under 0.70 to L30, 0.60–1.00 at L35–40, over 1.00 at L50, 1.00–1.35 at L55–60. All levels, no exemption.
   - The orders-only (D12) band test is retired. Its "never falls as level rises" check stays, as does the D14 one.
   - The coin window for a player selling 20% goes from 55–70 days to **52–70**. The never-sell limits (over 40, at most 75) are unchanged.
4. **Records.** D18 in the Alignment Plan; note that D17's gap is closed; update the Task 4.3 line, the parity audit, code comments and the `PROJECT_STATE.md` row.

## Expected results

D14: L20 0.56, L30 0.61, L35–40 0.73, L50–60 1.06. Never falls. Coins: never-sell about 48.4 days, sell-20% about 52.9. These come from the harness; the build must reproduce them with the real model. If a figure misses a target, stop and ask rather than tune.

## Not in scope

Legendary share, coin payouts, spawn prices, order tiers, kibble supply, and the High-Tier Drop / Hibernate downgrade at ×4 and ×8. No save change.

## Known limits

The model assumes the best case: the player always uses the cheapest multiplier, and a bonus always finds an empty cell. It is not a play simulation. L50 is only 0.06 above its floor.

## Left to the builder

Function names and how the old report helpers are folded into the priced model.
