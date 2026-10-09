# Spec — Main-board orders feed the Parallel Board's energy

**Written and implemented 9 Oct 2026.** Takes the one shape-changing delta from `Spec_ParallelBoardReview_Draft.md` §2.1/§2.6: in Travel Town's Greek Fest the main board keeps the parallel board playable — orders and milestones pay the event's currency, and the game sells a "200% MORE" booster on that flow. PawSanctuary's parallel board ran a wholly self-contained energy pool (`Spec_Phase6b_ParallelBoard.md` §3.2).

## 1. Rule

- While a Parallel Board event is live, **every order claimed on the main board adds +1 energy** to the parallel board (`parallelBoardEnergyPerOrder`). Persistent and urgent orders both count.
- Energy may be **banked above the regen cap, up to 60** (`parallelBoardEnergyBankCap`, twice the 30 cap). Regen still tops the bar up to 30 on its own; it does nothing once the balance is at or above 30. Bonus energy is therefore never wasted by arriving while the bar is full.
- The passive regen is **kept**. The reference runs with no timer at all; that is deliberately not adopted (see §3).
- With no event live there is no coordinator, so orders add nothing.

## 2. The economy run (9 Oct 2026)

Run with the economy model's own functions (`EconomySimulation.ordersPerDay`, `dailySupply`, `row`) and the real `second_chances_20261011` track. The model has **no parallel-board term** (the same gap `Spec_DailyHandInTasks.md` §5a found for hand-ins), so this applies its constants to a new flow; it was a throwaway test and is not committed.

- A full track is **160 tokens = 16 top-tier completions = 512 energy** (16 base items per top tier × 2 energy per tap) and pays **395 kibble + 20 Dog Tags**. Averaged over the roughly monthly cadence that is 13.2 kibble a day, **1.77 % of daily supply**; the wall ratio moves by at most 0.02 (L45 1.081 → 1.062, L60 1.239 → 1.217), inside every target band.
- **The baseline was already generous.** On regen alone, at the cap each session, a player opening the game 4 times a day completes ~70 % of the track in the 3-day window; 8 times a day, all of it; 2 times a day, 35 %. The existing numbers had never been modelled (`AnimalSpecies.swift`: "First-cut numbers, not derived from a model").
- Level-30 order volume is 48 a day, so +1 per order is **+144 energy** over a 3-day event.

| Player | Regen only | +1 per order, bank to 60 | +2 per order, bank to 60 |
|---|---|---|---|
| Light (2 sessions/day) | 35 % | **63 %** (+135 kibble) | 70 % |
| Medium (4/day) | 70 % | **98 %** (+115 kibble) | 100 % |
| Heavy (8/day) | 100 % | 100 % (+0) | 100 % |

**Reading:** the faucet is a catch-up for casual players. Heavy players gain nothing; the cost to the economy is capped at the 395 kibble the track already holds. Banking above the cap matters more than the rate (without it roughly half the bonus is wasted against a full bar — an **assumption**, not a measurement). **+2 is too much**: it lets a medium player finish the whole event, removing the reason to push.

**Assumptions to distrust:** sessions far enough apart to refill the cap; perfect merging with no wasted taps; enough board space; 3-day events; level 30. No playtest stands behind this.

## 3. Decisions — flagged for review

1. **Hybrid, not reference-faithful (D9).** The reference removes regen so the main board is the only source. Here that would punish exactly the player D9 protects — the lapsed one returning to an event they can no longer play. Regen stays as the floor; orders are an accelerant.
2. **+1 and a bank of 60.** From the table above. Both are constants in `AnimalSpecies.swift`.
3. **No booster.** The reference sells "200% MORE" on this flow. That is a monetization surface; D9 says revenue yields to retention, and the faucet has not yet been shown to need selling. Not built.
4. **Orders only.** The reference also pays from milestones. Quest claims, daily tasks and Care Points milestones do not feed energy here.
5. **A caption, not a counter animation.** The parallel board now says orders add energy. A per-order toast would fire ~48 times a day; a reward-flight sprite was left out for the same reason (see `Spec_RewardFlight.md` §3).
6. **Live window.** `second_chances_20261011` opens 11 Oct. This ships only if merged before then; otherwise the first window it applies to is 10 Nov.

## 4. Tests and verification

`ParallelOrderEnergyTests` (10): bonus fills the bar then banks above the cap; the bank stops at 60 and never lowers an over-cap balance; regen does nothing to a banked pool but still refills a low one; claiming a persistent order and the urgent order each add +1 during a live event; no event live changes nothing; many orders stop at the bank cap; a banked balance survives save and restore without being clamped back to 30. 712/712.

**Seen on screen, but not in the running app.** The Simulator cannot move its clock (`TODO.md`, 18 Aug) and changing the Mac's is not mine to do, so no Parallel Board event can be live today. I rendered the real `ParallelBoardView` in a throwaway test (not committed) with two energy values: **20 → "20/30" with the 1:30 regen countdown**, and **45 → "45" with a green "+15 banked"** and no countdown, both under the new caption "Orders you finish on the main board add +1 energy, up to 60." Not seen: an order claim actually crediting a live event end to end — that is covered by the tests, and will be visible from 11 Oct when `second_chances_20261011` opens.

## 5. Status

**Implemented 9 Oct 2026.** `AnimalSpecies.swift` (`parallelBoardEnergyPerOrder`, `parallelBoardEnergyBankCap`), `ParallelBoardEnergy.swift` (`addBonus`, `isBanked`), `MergeBoardViewModel.swift` (`feedParallelBoardEnergy`, called from both order-claim paths), `ParallelBoardView.swift` (the banked display and the caption). No schema change: the balance was already persisted as a plain integer and restore does not clamp it.

**Not yet decided:** whether milestones (not just orders) should feed energy, as the reference's do; and whether to sell a boost on this flow (§3.3).
