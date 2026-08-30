# PawSanctuary — Travel Town review (draft)

**Status: draft, no code written.** Fourth in the reference-review series, after `Spec_PartyBoard_Draft.md`, `Spec_BoardAnimation_Draft.md` and `Spec_OrdersAndTasks_Draft.md`. Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log.

Unlike the earlier three, most of this recording **confirms** work already shipped rather than opening new gaps. §1 records that confirmation briefly; §2–§5 are the four genuine deltas.

## 0. Source material

`ScreenRecording_08-22-2026 21-30-06_1.MP4` (28.0s, 1206×2622 @ 59.8fps) — **Travel Town**, player level 50. Third distinct reference title reviewed (after Gossip Harbor and Tasty Travels), so conventions differ again.

Analysed with `scripts/refvideo.swift`: contact sheet at 1s, then native-resolution crops of the HUD, order rail and left task column, plus 0.3s frame sweeps across the milestone overlay and an order payout.

---

## 1. What it confirms (no action)

Travel Town independently runs the same two-layer reward structure PawSanctuary now implements, which is worth recording as convergent evidence rather than a third data point to act on:

| Travel Town | PawSanctuary equivalent | Status |
|---|---|---|
| **Starfish +1 badge** on every order card, feeding a **9/12 → 12/12** bar | Smile Points (§2, `bd6d9d6`) — visible per-order value, single cycling threshold | Shipped |
| **Milestone ladder**: cumulative points against thresholds, each paying an item | Care Points (§4, `2f28a18`) — Bronze/Silver/Gold | Shipped |
| Orders request **1–2 specific items** at mid-chain tiers | Order baskets (§1, `9c225e8`…`d543fbc`) | Shipped |
| Bottom info bar: *"Open Book. Merge to reach next level."* | The selected-item info bar | Already existed |
| Energy counter with a live regen countdown (`54`, `37s`) | Kibble + `kibbleRegenSecs` | Already existed |

The starfish/milestone split is the same division of labour Smile Points and Care Points were built to: a fast per-order cycle alongside a slower cumulative ladder. Three titles now do it this way.

**One thing this clip could not settle:** the starfish bar sat at 11/12 when the recording ended, so what a full bar actually pays in Travel Town is unobserved. Do not treat PawSanctuary's board-item bundle as validated by this capture.

---

## 2. Delta — orders pay five currencies at once, each with its own flight

A single order completion (12.3s → 13.7s, ~0.7s) pays, simultaneously and with a separate animation per currency:

1. **Coins** — a stream of coin sprites arcing to the HUD counter (11,383 → 13,924)
2. **Red ticket tokens** (`+40` / `+70` / `+150`) — an event currency
3. **Purple earring tokens** (`+3` / `+6` / `+11`) — a second event currency
4. **Starfish `+1`** — flies to the 12-cycle bar, which ticks 10/12 → 11/12
5. **A bronze bell** — the milestone-ladder token, flying to the left column

Some orders add a **toolbox `+2`** on top.

Every one travels from the order card to *its own* counter, so the player sees five distinct destinations light up at once. The counters are the choreography — nothing is a number that merely changes.

**PawSanctuary already pays comparably many things per order** — coins, dog tags, XP, Care Points, Smile Points, sometimes a card pack or material — but pays them all silently. The counters just change. This is a presentation gap, not an economy one, and it sits naturally alongside `Spec_BoardAnimation_Draft.md`'s Tier A particle work.

## 3. Delta — the task rail is vertical, and everything is visible at once

Travel Town stacks its live tracks in a **left-hand column**, roughly four cards tall, each showing art, progress and its own timer (`2/3` + `7h 29m`; starfish `9/12`; a character event `1d 7h` with a red `9` badge; the bell track with a green bar and `1h 45m`). All of it is on screen permanently, next to the board.

PawSanctuary uses a **horizontal scrolling strip** (`TaskStripView`, `PanelViews.swift`), which now carries a dozen-plus cards: Level Up, Free Chest, Spotlight, event cards, Parallel Board, Reward Ladder, Adoption Orders, daily challenges, quests, ambassador trios, **Smile Points**, **Care Points**, Weekly, Monthly, Loyalty, Invite.

**This is worth acting on, and I have direct evidence rather than a hunch.** Verifying the two features I shipped today required repeatedly swiping that strip to hunt for the right card, overshooting, and opening the wrong sheet twice. If it is awkward to drive deliberately, it is worse for a player glancing at it. The strip has quietly grown past what horizontal scrolling serves.

Not necessarily a port of Travel Town's column — options include prioritising the strip by urgency, collapsing the always-present cards into a summary, or a two-row layout. Flagged as a real UX debt item, not a feature request.

## 4. Delta — milestone horizon is far longer

Travel Town's milestone ladder reads **12,482** current against thresholds of **11.5K ✓ / 27.5K / 58.5K**, with a `1h 45m` timer on the track. Rewards are a graded series (purple, brown ✓, silver, gold bells), and crossing one fires a full-screen **"NEW MILESTONE!"** takeover: dark overlay, the ladder shown with the crossed node ticked, then a single hero item on a radiating glow.

PawSanctuary's Care Points ladder is 120 / 320 / 520 over a week. Both are defensible — Travel Town's numbers imply a much finer-grained point source — but two things are worth noting:

- Their reward is **one hero item**, presented as an event. Care Points pays Dog Tags + XP + a card pack with no ceremony at all.
- The **"NEW MILESTONE!" takeover** is the same celebration grammar as Tasty Travels' "Smile" banner. Two of three titles interrupt the board for this beat; PawSanctuary interrupts for nothing.

## 5. Delta — "Almost there!" customer nudge

At 13.0s, as an order neared completion, the customer's portrait sprouted a speech bubble reading **"Almost there!"** — an in-fiction nudge tying the order's state to the character asking for it.

PawSanctuary has nudges (the merge hint, the sell-vs-order toast) but nothing that speaks *from the order*. Its adoption families already have names and portraits (`AdoptionFamily`), so the surface exists. Cheap, on-theme for the Warmth pillar, and it makes the order board feel populated rather than transactional.

---

## 6. Open questions

1. **What does Travel Town's 12-starfish bar pay?** Unobserved — the clip ends at 11/12. The single most useful thing to capture in a follow-up recording, since it is the direct analogue of Smile Points' bundle.
2. **Are the bells a collectible tier series or just milestone tokens?** Bronze bells ride on order cards *and* appear as ladder nodes in graded colours, which could be one mechanic or two.
3. **What are the two event currencies (red ticket, purple earring) for?** Both are paid per order and neither's sink is visible here.
4. **Task-rail redesign (§3)** — the actual approach is undecided; only the problem is established.

## 7. Suggested next step

§5 (the customer nudge) is small, self-contained and on-theme. §2 (reward flight) folds naturally into the animation spec's Tier A. §3 is the one with real evidence behind it and no chosen solution — worth deciding before the strip grows further.
