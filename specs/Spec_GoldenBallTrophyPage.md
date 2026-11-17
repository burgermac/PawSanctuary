# Spec — Trophy pages (a home for completed Golden Balls)

**Status: building, 17 Nov 2026.** This is the "v2" that `TODO.md` ("Completed sub-objects had no sink") deferred: a per-family collection page that a completed top-tier sub-object feeds. The flat "Convert to Coins" sink (22 Aug 2026) stays.

## 0. What the evidence is, and is not

A research pass on peer games (17 Nov 2026) found thin evidence. Confirmed: Merge Mansion lets players sell items for coins (official help page). From the owner's own captures: Gossip Harbor's Golden Mountain and Travel Town's top coin pay out on completion, and a Parallel Board event item shows "Tap to collect" at max level. **No peer was found to use a per-family trophy page.** That part is PawSanctuary's own design, built on the card-album idea already in `CardSystem.swift`. Numbers in §2 are mine, not measured.

## 1. The player's problem

A completed family top tier (Canines' Golden Ball) becomes a power-up in the 6-slot Supplies inventory. Players who do not want or cannot use the power-up could only convert it to a flat coin amount, buried in the Supplies tab. There was no longer-term goal for them.

## 2. Rule

- Each of the 15 animal families has a **Trophy page of 5 slots**.
- On the Supplies tab, a selected completed sub-object shows a third button, **Trophy +N**, beside "Choose Spawner on Board" and **Coins +N** (the old "Convert to Coins"), laid out in two rows so labels fit on a phone. It is hidden when that family's page is already full.
- Adding fills the family's next slot, pays **100 coins** for the slot, and removes the item from Supplies. Filling the fifth slot pays a **one-time page bonus of 500 coins** on top.
- Once a family's page is full, its completed sub-objects keep working exactly as today: apply as a power-up, or convert to coins. Nothing is blocked, so nothing can clog.
- **No gems, energy or real-money surface anywhere.** Coins only.
- A "Trophy Pages" section on the Supplies tab lists all 15 families with their filled slots.
- Slot order and rarity do not matter; the rolled effect is given up when an item is added (the same as converting it).
- Existing players: stockpiled Golden Balls already in Supplies simply gain the new button. No migration of items, nothing is taken or auto-converted.

## 3. Numbers (mine — flag for tuning)

`trophySlotsPerFamily = 5`, `trophySlotCoins = 100`, `trophyPageBonusCoins = 500`, in `AnimalSpecies.swift` with the other tuning constants. Full page = 15 x (5 x 100 + 500) = 15,000 coins across the whole game; a single ball is worth 100 coins as a trophy against 15 to 200 as a plain conversion. These need a check against the coin economy (`TODO.md`, "The coin economy").

## 4. Persistence

Schema **v45**: `trophyCounts: [String: Int]` (species raw value to slots filled), non-Optional, default empty. It gets an `additiveDefaultsSinceV8` entry and a dispatch entry for v44. `PersistenceTests` covers the migration and a round trip.

## 5. Out of scope

A daily cap on coin conversion; auto-collecting balls without a tap; a separate full-screen Trophy screen; slot art; trophy rewards other than coins; the Parallel Board's own items.

## 6. Tests

`TrophyPageTests`: adding fills a slot and pays; the fifth slot pays the bonus once; a full page refuses and leaves the item; a non-sub-object or rarity-less item is refused; the item is removed from Supplies; counts survive save and reload. Two `PersistenceTests` cases.

## 7. Open (owner)

Whether 5 slots and 100/500 coins feel right; whether trophies should eventually grant something other than coins.
