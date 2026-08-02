# PawSanctuary — Phase 2c: The coin economy

**Self-contained brief.** Assumes no prior conversation. Follows Phase 2b (commit `f646ae9`).

> **Atomic.** Formula changes, table re-derivation, simulation extension and threshold rescaling land in one commit.

---

## 0. Why

Phases 2 and 2b modelled **kibble** supply against kibble demand and hit the target ratio curve. **Coins were never modelled** — yet coins gate the Sanctuary Map, the game's forever goal.

Measured current state:

| | Value |
|---|---|
| Total map cost | **291,900 coins** (61 entries, 80 → 35,000) |
| Order coin payout — `(tier+1)*2 + rand(0…2)` | ~9–25 coins |
| Quest claims (easy/med/hard/legendary) | 2 / 5 / 10 / 25 |
| Daily challenges (all three) | ~15 |
| Ambassador merge / trio exchange | 10 / 50 |
| Album completions (one-time, all six) | 625 |
| **Non-sell daily income** | **~145 coins** → **2,013 days to complete the map** |
| **Sell value, tier 11** | **18,000 coins** |
| **Sell channel daily income** | **~6,500 coins** → **45 days** |

Selling is currently the entire coin economy and orders are a rounding error. That was never a decision — it is where two independently plausible tables happened to land.

**Two problems with the status quo.** Selling is **taught nowhere** (zero references in `OnboardingView.swift`; the only affordance is a `$` button in the item info bar), so the primary faucet is undiscoverable — a player who never finds it cannot finish the map and has no way to diagnose why. And the gap between optimal and casual play is enormous.

---

## 1. Decision (made — do not relitigate)

**Both channels pay coins. Orders pay strictly more.**

| Channel | Rate | Role |
|---|---|---|
| **Fulfil an adoption order** | **~6.5 coins per kibble of build cost** | The efficient path. Requires a matching order, so it costs patience. |
| **Sell an animal** | **~2.75 coins per kibble of build cost** | Instant liquidity for items no order wants. Always available, ~2.4× worse. |

Rationale:

- **Nobody stalls.** Coins arrive automatically from order fulfilment, which onboarding already teaches. Selling becomes an optimisation rather than a prerequisite.
- **Selling stays genuinely useful** rather than being gutted — a real choice each time a high-tier item completes: wait for a matching order and earn 2.4×, or take liquidity now.
- **The mechanism already exists.** Phase 1's `OrderReward` list carries a `.coins` kind and orders already pay it. This is a formula change, not new machinery.

Rejected: orders-only (guts selling, big visible nerf) and selling-only (undiscoverable primary faucet).

---

## 2. Target

**A full map build-out should take roughly 60 days of engaged play.**

```
291,900 coins ÷ 60 days   = ~4,865 coins/day
```

Phase 2's ratio curve has orders consuming ~745 kibble/day, so:

```
4,865 ÷ 745 = ~6.5 coins per kibble of order build cost
```

Selling surplus adds on top — at ~20% of production diverted to sales, roughly another 400 coins/day, pulling the projection to ~56 days.

**That 6.5 figure is the anchor.** Change the 60-day target if you disagree, then re-derive everything below from it.

---

## 3. Task — order coin payout

Replace `AdoptionBoard.generateOrder`'s:

```swift
let orderCoins = (tier + 1) * 2 + Int.random(in: 0...2)
```

with a payout **proportional to the kibble the order actually costs to fulfil**:

```swift
let buildCost  = (1 << tier) * wantedCount           // 2^tier per item
let orderCoins = max(1, Int(Double(buildCost) * coinsPerKibbleOfOrder))   // ~6.5
```

Add `coinsPerKibbleOfOrder` to `AnimalSpecies.swift` with the other tuning constants. Keep a ±10% random spread so payouts don't read as mechanical.

**Why proportional rather than a table:** the tier distribution has already been re-swept twice (Phases 2 and 2b). A proportional formula stays correct automatically; a hand-tuned table would need re-deriving each time.

---

## 4. Task — re-derive the sell table

`animalSellValues` becomes `round(2.75 × 2^tier)`:

| Tier | Build cost | **Sell (2.75×)** | **Order (6.5×)** | Premium for waiting |
|---|---|---|---|---|
| 0 | 1 | 3 | 7 | 2.3× |
| 3 | 8 | 22 | 52 | 2.4× |
| 6 | 64 | 176 | 416 | 2.4× |
| 9 | 512 | 1,408 | 3,328 | 2.4× |
| 11 | 2,048 | **5,632** | **13,312** | 2.4× |

A flat ratio across every tier is deliberate: there is no tier at which selling is *relatively* better, so no farming incentive anywhere on the chain. It also makes the tradeoff legible — the premium is always about 2.4×, whatever the player is holding.

**Tier-11 sell value drops 18,000 → 5,632.** That is the intended magnitude.

**Assert as a test:** for every tier 0–11, `sellValue(tier) < orderCoinPayout(tier, count: 1)`.

---

## 5. Task — surface the choice

Selling is now one half of a real decision, so it needs to be visible. Minimum:

- The sell affordance should show **what the item would earn if an order wanted it**, alongside the sell price — the player cannot weigh the tradeoff without both numbers.
- Mention selling once in onboarding, or as a contextual prompt the first time the player holds a mid-tier item with no matching order.

This is not cosmetic. A choice the player cannot see is not a choice.

---

## 6. Task — extend the simulation

Phase 2 §5's debug simulation reports kibble supply, demand and ratio by band. Add coins:

- **Coin supply/day** by band — orders, selling at an assumed surplus rate, quests, daily challenges, ambassador merges, album completions amortised
- **Coin demand** — the map's remaining cost at that band's expected progress
- **Projected days to full map build-out**, reported twice: for a player who never sells, and for one who sells 20% of production

Targets: **55–70 days** for the selling player, and **no worse than ~75 days** for one who never sells. If the never-sells figure is much worse than that, orders are carrying too little and the 6.5 anchor needs raising.

---

## 7. Task — audit the remaining faucets

With orders re-anchored, the smaller faucets are miscalibrated by comparison:

- **Weekly goal thresholds** — Bronze 50 / Silver 120 / Gold 250 coins *earned*. **Most urgent.** These are thresholds denominated in the currency whose faucet just moved by ~45×; a single mid-tier order will clear Bronze outright. They live in a different file from the change and will break silently.
- **Quest claims** (2/5/10/25) — should a legendary quest be worth more or less than one average order (~405 coins)?
- **Daily challenges** (~15 for all three)
- **Ambassador merge** (10) and **trio exchange** (50) — these mark real achievements and currently pay less than a tier-3 order will
- **Album completions** (625 across six albums)

Give each a stated rationale rather than a uniform multiplier.

---

## 8. Acceptance

- [ ] Order coin payout proportional to build cost, driven by a named constant
- [ ] `sellValue(tier) < orderCoinPayout(tier)` for every tier, asserted in a test
- [ ] The premium ratio is roughly constant (~2.4×) across all tiers
- [ ] Sell UI shows both the sell price and the order-equivalent value
- [ ] Simulation projects 55–70 days selling, ≤75 days never selling
- [ ] Weekly/monthly goal thresholds rescaled
- [ ] Smaller faucets audited with rationale
- [ ] Full test suite green
- [ ] Sanity-play: fulfil an order and sell a comparable item; confirm the relative values read correctly on screen

---

## 9. Out of scope

- Map costs (291,900 total) — treat as fixed; tune the faucet, not the sink
- Renaming the sell mechanic — worth considering separately for theme, but it is a strings change and does not belong in an economy commit
- Dog Tag economy — separate currency, separate pass
- Anything in Phases 3–6
- GDD updates — its economy section will be stale after this; flag, don't fix
