# PawSanctuary — Party Board (draft)

**Status: draft, open design questions unresolved, no code written yet.** Not yet entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat; this is a working draft assembled from a single reference-video review (26 Aug 2026) at the implementation surface, ahead of design-authority review. Placeholder name throughout: **"Party Board."**

## 0. Source material

Observed in `ScreenRecording_08-01-2026 20-38-01_1.MP4`, a merge-game reference title's "Party Time" offer: a 4-column grid of 12 prize tiles wrapped around a party-themed mascot illustration, one tile pre-marked as a guaranteed free first pull ("The first spin is on us! You're guaranteed to win 25⚡"), collected tiles get a checkmark and darken, and the PLAY button's label switches from free to a priced real-money button (`PLAY $0.99`) the moment the free pull is spent. No reward-reveal animation is in scope for this draft — that recording didn't actually contain one (an earlier read of it mistook part of the idle shimmer for a reveal sequence; corrected here). Reveal-animation choreography will be drafted once later reference videos actually show one.

## 1. What this draft covers, and what it deliberately doesn't

**In scope here:** the board mechanic itself — grid of prizes, the guaranteed-free-pull hook, the paywalled-repeat-pull structure, and how to reskin it with PawSanctuary's own currencies/characters/items.

**Explicitly deferred, not decided:**
- **Presentation surface and cadence.** In the reference titles, features like this live on the game's home/map screen behind an icon arrayed around the map's edge, and are available on a *rotating* basis for a period of days alongside other reward/IAP surfaces — not always-on, not tied to any single event slot we've catalogued yet. Before committing this to a specific home (the Phase 6c 90-day calendar, an evergreen Shop entry, a new map-icon system, or something else), the plan is to pull together *all* of the reward/IAP feature screens across the reference videos, lay them out side by side, and land on one timing/placement scheme that fits all of them — not bolt this one on ad hoc. Nothing below assumes an answer to this.
- **Reward-reveal animation.** No reveal choreography is specified here. Revisit once a reference video actually shows one.
- **Exact tuning numbers** (currency amounts, IAP price, board-reset behavior). Flagged as placeholders below.

## 2. Currency reskin

The reference used a generic energy currency, a gem-like premium currency, and small consumable packs. Mapping to PawSanctuary's real wallet:

| Reference | PawSanctuary equivalent |
|---|---|
| Energy currency (large amounts, e.g. 350/550/2000) | **Kibble** |
| Gem-like premium currency (small amounts, e.g. 50/150/250) | **Dog Tags** |
| Small consumable packs | Existing Supply-chain items (Grooming/Food/Shelter) at a low tier |
| Mystery/jackpot box | A genuinely rare tangible item (see §3) |

**Deliberately not using Coins here.** `Coins` was added in `c235a76` as a sink for completed sub-objects, with its own commit message flagging it as reserved for "a dedicated exchange/collection-book system... closer to how Travel Town/Gossip Harbor/Tasty Travels treat their own top-tier tokens," deferred to v2. Folding Coins into this board's prize pool would either compete with or preempt that future system. If you want Coins in this board instead of (or alongside) Dog Tags, that should be a deliberate call against that roadmap item, not a default.

## 3. Tangible-item prize candidates

Per your call to mix currency with tangible items rather than pure numbers, candidates already in the economy that would read as "special" rather than "another number":

- **Wildcard** (`special_wildcard_t00`) — single-tier, already a real Shop-purchasable rarity; a strong jackpot-slot candidate since players already know its value (advances any chain by a tier).
- **Toolbox top tier** ("Cargo Chest") — already the richest tier of an existing chain, no new content needed.
- **A Material chain's top tier** (Hardwood Kit / Steel Girder / Foundation Kit) — useful if area-building materials are a real bottleneck at the player levels this surfaces to.
- **A Superpower charge** — if `SuperpowerSystem` has a spendable/grantable unit, this fits the "flashy but not currency" slot.

None of these need new art or new mechanics — they're all existing inventory-affecting grants, just distributed through a new surface.

## 4. Example 12-tile layout (illustrative — values are placeholders, not tuned)

Mirrors the reference's 4-column grid with the host character occupying the two center cells across the middle two rows:

| | Col 1 | Col 2 | Col 3 | Col 4 |
|---|---|---|---|---|
| Row 1 | Mystery Chest (mixed) | 300 Kibble | Grooming Supply (low tier) | **50 Dog Tags — guaranteed free pull** |
| Row 2 | 20 Dog Tags + 100 Kibble | *[host art]* | Food Supply (low tier) | |
| Row 3 | 1500 Kibble | *[host art]* | | Wildcard (rare) |
| Row 4 | 40 Dog Tags + 200 Kibble | 400 Kibble | 75 Dog Tags | Toolbox "Cargo Chest" (rare) |

Two rare tangible slots (Wildcard, Cargo Chest) anchor the bottom-right and mid-right the way the reference reserved its highest-denomination gem tiles for those positions — the jackpot slots read as most valuable at a glance without needing to read the numbers.

## 5. Host character

You've chosen to reuse an existing PawSanctuary character rather than invent a new one or go mascot-less. Two ways to do that:

- **Recommended: tie the host to whichever species is currently `Spotlight`** (`viewModel.spotlightChainID`, already a rotating "featured species" mechanic in `QuestCoordinator`). The board's host art changes with the Spotlight rotation instead of being fixed forever, keeping the feature visually fresh across recurrences for free, and reinforcing the existing Spotlight system instead of introducing an unrelated one.
- **Simpler fallback: always use Canines (dog)** — the starter species every player has from day one, no rotation logic needed.

**Real art requirement either way:** every existing illustrated asset in the game (Animals, Sub-Objects, Superpowers, Economy Chains, Special & Spawners) is a naturalistic tier-progression icon, not a personality/costume pose. The reference's mascot is drawn celebrating — arms up, sunglasses, party outfit. Reusing an existing species as "host" still means commissioning **one new personality-pose illustration** per species used as host (one if you pick the static fallback; up to 15 if the Spotlight rotation reaches every species over time) — this isn't reusing existing art unmodified, it's a new one-off delivery in the same vein as the Wildcard/Second-Chances specials.

## 6. Guaranteed first pull

Carry over as-is: one visually-distinguished tile (gold border vs. the others' tan/orange) is the committed, non-random reward for the player's first pull on this board, framed explicitly in copy ("first pull's on the house") so it doesn't read as rigged once they notice the border difference before tapping. Recommend the guaranteed slot's value stay modest (a Kibble amount or small Dog Tags amount, not a rare tangible) so it doesn't cannibalize the incentive to pay for repeat pulls.

## 7. Repeat-pull monetization

**Decided: real-money IAP**, matching the reference exactly and consistent with the existing purchase pattern the Reward Ladder (`RewardLadderSection`) already uses. No new purchase infrastructure needed — `StoreManager.swift` + the `IAPProduct` enum (`AnimalSpecies.swift:970`) already handle StoreKit 2 purchase/grant/transaction-listening. This would add one new case, e.g.:

```swift
case partyBoardPull = "com.pawsanctuary.partyboard.pull"   // price TBD, reference used $0.99
```

Whether every repeat pull costs the same flat price, or the price escalates the more of the board a player has already claimed, is untuned — flagged as open below.

## 8. Open questions

1. **Presentation surface & cadence** — deliberately deferred per §1, pending a side-by-side review of more reference-video reward/IAP screens.
2. **Board reset behavior** — once all 12 tiles are claimed, does a fresh board spawn immediately, does the feature just sit "done" until its next scheduled occurrence, or does the timer expiring forfeit unclaimed tiles?
3. **Repeat-pull pricing** — flat price per pull, or an escalating curve?
4. **Guaranteed-pull value** — exact Kibble/Dog Tags amount, needs sizing against the existing exchange rate (`DogTagKibbleExchange`) the same way every other tuning number in this plan was modelled.
5. **Are paid pulls random across the remaining 11 tiles, or does the player have any influence/preview?** The source video didn't show a second pull, so this is unconfirmed even for the reference, let alone decided for PawSanctuary.
6. **Host art scope** — commit to the Spotlight-rotation approach (needs up to 15 new illustrations delivered over time) or the static single-species fallback (needs exactly 1) before any art gets commissioned.

## 9. Suggested next step

Send the remaining reference-video/screenshot material for other reward/IAP surfaces so they can be grouped together, per your note — then we return to resolve Open Question 1 (and by extension, how "Party Board" actually gets triggered and how long it stays up) before this draft is ready for design-authority review or an implementation spec.
