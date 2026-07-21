# Paw Sanctuary — Game Design Document
**Version 3.0 | July 2026**

> **This is a full refresh, not an incremental edit.** Versions up to 2.1 had drifted far from the actual implementation — most of the "Not built" items in the old Feature Status Tracker were in fact shipped, the board dimensions were wrong throughout, and several systems that exist in the live game (Coins, the card collection/trading layer, the Sanctuary Map, the Loyalty Club, weekly/monthly goals) weren't documented at all. This version was written by reading the current codebase directly, not by extending the previous draft. Section 15 (Technical Architecture) and Section 16 (Status & Remaining Work) are the ones most worth re-reading if you only skim one thing.
>
> **Prior history:** v2.1 added per-family Superpowers. v2.0 expanded from 8 species × 5 stages to 15 animal families × 15 stages, introduced sub-object spawning and a reward-consumable system. Both are now implemented; see Section 16 for what v2.0/2.1 still got wrong about *how* they were implemented.

---

## Table of Contents
1. [Game Overview](#1-game-overview)
2. [Core Loop](#2-core-loop)
3. [Board & Merge System](#3-board--merge-system)
4. [Animal System](#4-animal-system)
5. [Sub-Object Spawning & Power-Ups](#5-sub-object-spawning--power-ups)
6. [Family Superpowers](#6-family-superpowers)
7. [Economy & Currencies](#7-economy--currencies)
8. [Progression Systems](#8-progression-systems)
9. [Engagement Systems](#9-engagement-systems)
10. [Inventory & Storage](#10-inventory--storage)
11. [Sanctuary Map & Building](#11-sanctuary-map--building)
12. [Card Collection & Trading](#12-card-collection--trading)
13. [Monetization](#13-monetization)
14. [Social Systems](#14-social-systems)
15. [Technical Architecture](#15-technical-architecture)
16. [Status & Remaining Work](#16-status--remaining-work)

---

## 1. Game Overview

**Genre:** Merge puzzle / idle casual
**Platform:** iOS (iPhone primary, iPad secondary)
**Audience:** Casual mobile gamers, animal lovers, ages 18–45
**Monetization model:** Free-to-play with IAP and an optional subscription
**Comparable titles:** Travel Town, Tasty Travels, Merge Mansion
**Differentiator:** 15 named animal families, each with a 15-stage evolutionary arc (Pup → Primordial) instead of generic objects; a per-family Superpower system that rewards developing every family rather than specializing in two or three efficient ones; a card-collection/trading meta-layer running alongside the merge board.

### Elevator Pitch
Players run an animal sanctuary: rescue animals across 15 families, merge them through 15 stages from Infant to Legendary, and build out a Sanctuary Map with materials earned along the way. Each family also spawns themed sub-objects that merge into power-ups, and unlocks a unique Superpower once it matures. A card-collection meta-game, adoption orders from named families, and a full daily/weekly engagement loop round out the retention layer.

### Design Pillars
1. **Warmth** — every interaction feels like caring for animals, not grinding
2. **Value** — players always feel the game is generous compared to competitors
3. **Momentum** — there is always a next thing to do; dead ends are eliminated by design
4. **Clarity** — new players understand what to do within 60 seconds (see the 3-step tutorial in Section 9.7)

---

## 2. Core Loop

### Session Loop (5–15 minutes)
```
Open app
  → Claim daily login reward (if first open today)
  → Check adoption orders from named families (timed, 15 min each)
  → Rescue animals (spend Kibble at family spawners)
  → Merge matching animals → advance through the 15-stage chain
  → Merge sub-objects → earn power-ups (Speed Burst, Map Supplies, Spawner Refill, High-Tier Drop)
  → Complete daily challenges / active quests
  → Claim rewards (Kibble, Dog Tags, Coins, XP, occasional card packs)
  → Spend Coins + materials building/upgrading Sanctuary Map areas
  → Store excess animals or materials, exit when Kibble runs low
```

### Retention Loop (daily)
```
Daily login streak (7-day cycle) → escalating Kibble/Dog Tag rewards
Daily challenges reset at midnight → 3 challenges, streak bonus every 7 days
Adoption orders replace themselves automatically every 15 min → steady goal churn
Weekly spotlight family (2× score) → resets Monday
Weekly/monthly Coin goals (Bronze/Silver/Gold) → resets weekly/monthly
Loyalty Club (unlocks at player level 20) → 7-day reward cycle, separate from login streak
```

### Progression Loop (weeks → months)
```
Level up via XP → unlocks supply producers, card packs, higher spawn multipliers
Build Sanctuary Map areas with materials → unlocks new families + board rows
Progress through 15 stages × 15 families (225 unique named items)
Reach Stage 7 (Era 3) with a family → unlock its Superpower
Reach top tier (Stage 15) → Ambassador celebration, Sanctuary Star milestones
Collect cards across 6 albums → album-completion rewards; trade duplicates via Game Center
```

---

## 3. Board & Merge System

### Board Configuration
- **Grid:** 9 rows × 7 columns = **63 total cells**. (Earlier GDD drafts said 6×5 = 30 — that was always wrong; the implementation has been 9×7 since the generalized chain model shipped.)
- **Starting unlocked:** rows 0–6 (49 cells)
- **Locked:** rows 7 and 8 (14 cells) — row 7 unlocks at **player level 3**, row 8 at **player level 8**. Unlocking is level-gated, not merge-count-gated.

### Merge Rules
| Scenario | Result |
|---|---|
| Same chain + same tier | Merge → next tier |
| Different chain OR different tier | Swap positions |
| Source → empty cell | Move |
| Drag off bottom of board | Send to inventory / material accumulator, by item category |

### Spawn Rules
- **Family spawner tap:** costs Kibble (`spawnMultiplier` — 1/2/4/8, unlocked at levels 1/5/10/20), spawns at a tier proportional to the multiplier, or a sub-object per the drop table in Section 5
- **Legacy rescue-tier producers** (Rescue Crate / Shelter Pod / Foster Home): finite-charge producers bought from the shop with Dog Tags; spawn a random *unlocked* animal chain. Superseded in practice by family spawners, which are earned via the Sanctuary Map, but the legacy path still exists in code for the shop.
- **Supply producers** (Grooming Box / Feed Station / Supply Crate): unlock automatically at levels 15/20/25, produce Grooming/Food/Shelter supply-chain items on a cooldown, no charges consumed by kibble
- **Board full:** rescue/spawn actions show a "Board Full" toast instead of spawning

### Future Board Features (still just ideas, not committed)
- Golden cells giving bonus score
- Obstacle/debris cells cleared by merging
- A dedicated Sanctuary display area for Legendary animals, separate from the play board

---

## 4. Animal System

### Overview
**15 animal families**, each with **15 merge tiers** (indices 0–14) arranged into 5 conceptual eras of 3 tiers each. All 15 families and all 225 tier names are fully authored in `AnimalSpecies.tierNames` — this is done, not aspirational.

### Family List (internal case → display family)
| Case | Family | | Case | Family |
|---|---|---|---|---|
| `.dog` | Canines | | `.fish` | Aquatics |
| `.cat` | Felines | | `.lizard` | Amphibians |
| `.rabbit` | Lagomorphs | | `.ferret` | Marsupials |
| `.bird` | Avians | | `.parrot` | Primates |
| `.hamster` | Rodents | | `.pony` | Equines |
| `.turtle` | Reptiles | | `.hedgehog` | Pachyderms |
| `.fox` | Cervids | | `.guineaPig` | Bovines |
| `.owl` | Ursids | | | |

### Starter Family
Only **Canines** are available on day one (`startingChainIDs`). Every other family is unlocked by building its Sanctuary Map area — see Section 11. This replaces the old "5 starter families + stage-milestone unlocks" design; it never shipped that way. There is no dual unlock path anymore: the one early plan to also unlock Aquatics via a 50-Ambassador milestone was retired in favor of the map-area path (see Section 8).

### Animal Tier Progression (15 tiers per family, index 0→14)
All 15×15 = 225 stage names are defined verbatim in `AnimalSpecies.tierNames`, matching the reference table from earlier design drafts (e.g. Canines: Pup, Kit, Houndling, Terrier, Spaniel, Scout, Retriever, Shepherd, Husky, Alpha, Guardian, Sentinel, Dire Wolf, Mythic, Primordial). Tier 14 (top tier) triggers the Ambassador celebration.

### Tier Score & XP Values
`scoreValue = (index + 1) × 25`, `xpValue = (index + 1) × 5`, so tier 0 = 25 score / 5 XP and tier 14 = 375 score / 75 XP. Weekly spotlight gives **2× score** on the featured family's merges.

### Sell Values
`sellValue(forTier:)` is a 15-entry table in `MergeBoardViewModel`, geometric from tier 0 up through 100,000 coins at the top tier.

---

## 5. Sub-Object Spawning & Power-Ups

### Overview
Each family spawner has a **20% base chance** per activation of producing a sub-object instead of an animal (`SubObjectDropConfig.baseSubObjectChance`). Sub-objects form independent 4-tier merge chains (`chainID` prefix `"subobject."`), never merge with animal pieces, and reaching tier 3 (the top tier) yields a **power-up** consumable.

### Sub-Object Chains
All 15 families have a named 4-stage chain (e.g. Canines: Biscuit → Bone → Chew Toy → Golden Ball), fully authored in `ItemChain.makeSubObjectChain`.

### Power-Up Rarity & Drop Rates
When a sub-object drops, its rarity is resolved by `SubObjectSystem.resolveSpawnerDrop`:

| Rarity | Effect | Weight |
|---|---|---|
| Speed Burst | 2× spawner speed for 30s (+ any `powerUpDurationBonus` from area upgrades) | 60% |
| Map Supplies | 4 random wood/metal/cement items (tier 0–2), direct to material storage | 25% |
| Spawner Refill | +20 Kibble (family spawners have unlimited charges, so this substitutes) | 10% |
| High-Tier Drop Guarantee | Forces the *next* spawn to tier ≥ 2 | 5% |

### Pity Timers
Per-family `PityState` tracks spawns since the last Rare/Epic drop. **30 spawns** guarantees a Spawner Refill; **60 spawns** guarantees a High-Tier Drop Guarantee. Both thresholds can be reduced by an area-upgrade bonus (`pityTimerReduction`).

### Power-Up Inventory
6 dedicated slots (`InventoryStore.powerUpInventory`), separate from the animal inventory. Players drag a power-up onto any spawner to apply it.

---

## 6. Family Superpowers

### Overview
Each family has one Superpower, unlocking the first time that family reaches **tier index 6** (the 7th stage). This is fully implemented — passives fire automatically from hooks in `MergeBoardViewModel`, and actives are dispatched via `activateSuperpower(for:)` with per-species cooldown tracking.

### Superpower Reference
| Family | Type | Name | Ability |
|---|---|---|---|
| Canines | Passive | Fetch! | Every 5th merge anywhere spawns a free Stage-1 Canine |
| Felines | Active (90s) | Nine Lives | Undo the last merge |
| Lagomorphs | Passive | Multiply | Every 4th Lagomorph merge spawns two free Stage-1s |
| Avians | Passive | Scout | Spawner tiles preview whether the next rescue is an animal or sub-object |
| Rodents | Passive | Hoard | Rodent Spawner drops Stage-2 sub-objects instead of Stage-1 |
| Reptiles | Passive | Bask | Reptile family spawner costs half Kibble |
| Cervids | Passive | Antler Drop | 25% chance of a bonus Stage-2 sub-object on any Cervid merge |
| Ursids | Passive | Hibernate Bonus | After 5 idle minutes, the next rescue anywhere spawns at Stage 3 |
| Aquatics | Passive | Current | After any merge, adjacent sub-objects auto-slide toward the nearest gap |
| Amphibians | Active (120s) | Leap | Teleport any Amphibian to any empty board cell |
| Marsupials | Active (180s) | Pouch | Store up to 2 animals off-board for 30s, then they return |
| Primates | Active (90s) | Mimic | Spawn a free Stage-1 animal of the last-merged family |
| Equines | Active (60s) | Sprint | Doubles Kibble regen rate for 60 seconds |
| Pachyderms | Passive | Memory | Pachyderm quest/challenge progress counts double |
| Bovines | Active (180s) | Stampede | Instantly merges all same-family same-tier pairs on the board |

### UI
A collapsible button strip shows one button per family with an unlocked *active* ability; a cooldown ring and countdown label render while on cooldown. A celebration banner plays on first unlock per family.

---

## 7. Economy & Currencies

Four currencies exist, not two.

### 🦴 Kibble (energy)
| Property | Value |
|---|---|
| Starting amount | 20 |
| Regen rate | 1 per 120 seconds |
| Regen cap | 100 (rises to **150 at player level 10**) |
| Cost per rescue | `spawnMultiplier` (1/2/4/8) |

Sources: timer regen, quests, daily challenges, daily login, adoption order rewards, rewarded ads (+25, up to 4/day, resets 09:00 UTC), Sanctuary Pass (+20/day × 1.5 multiplier on all claimed kibble), IAP.

### 🪪 Dog Tags (premium, earned not bought-to-progress)
Sources: quests (1–15 depending on difficulty), daily challenge streak bonus (+2, or +8 every 7th day), weekly spotlight milestone (+5), daily login, adoption order rewards, IAP.
Spend on: inventory row unlocks (10 / 25 tags), the Dog-Tag→Kibble exchange (40→100, 80→240, 120→480), the shop's legacy producer tier (Rescue Crate/Shelter Pod/Foster Home).

### 🪙 Coins
Introduced for the map-building and card-album economy — **not in earlier GDD drafts at all**. Earned from Ambassador merges (+10, more with area upgrades), adoption order fulfillment, album completion, weekly/monthly goal chests, and quest claims. Spent on Sanctuary Map area builds/upgrades alongside materials.

### ⭐ Stars
Earned from duplicate cards (1 for a common dupe, 5 for a rare dupe) or by converting all duplicates at once. Spent in the Star Shop on 1★–3★ card packs and joker cards (see Section 12).

---

## 8. Progression Systems

### Player Level & XP
Fully implemented (earlier drafts said "not yet built"). `xpRequired(forLevel:) = level × 150`. XP sources: merges (`(tier+1) × 5`), rescues (+2), order fulfillment (+15), all-dailies-complete (+30), quest claims (10/25/50/150 by difficulty).

Level-up rewards: supply producers at 15/20/25; card packs at levels 3, 6, 9, 12, 15, 18, 20, 22, 25, 30 (escalating pack tier); higher spawn multipliers at 5/10/20; board rows at 3/8; Invite system unlocks at level 5; Loyalty Club unlocks at level 20.

### Ambassador Milestones (Sanctuary Stars)
`ambassadors` counts chains that have reached top tier. `MilestoneManager` fires at 5 / 15 / 30 / 50:
```
5:  "Junior Rescuer"     + 10 Kibble
15: "Animal Friend"      + 5 Dog Tags
30: "Sanctuary Guardian" + a free inventory row
50: "Legendary Rescuer"  + 100 Kibble + 50 Dog Tags
```
The 50-star milestone previously also unlocked Aquatics; that path was retired once Aquatics got its own Sanctuary Map area, so the milestone now just pays out currency instead.

### Weekly & Monthly Coin Goals
`WeeklyGoalTier`: Bronze (50 coins), Silver (120), Gold (250) — each with escalating Kibble/Dog Tag/Toolbox/XP rewards. Monthly goal requires 3 Gold weeks in a calendar month (reducible by an area upgrade).

### Loyalty Club
Unlocks at player level 20. A 7-day reward cycle (separate from the daily login streak) paying Kibble, Dog Tags, and occasional card packs, topping out at a 6★-adjacent reward on Day 7.

---

## 9. Engagement Systems

### 9.1 Daily Login Reward
7-day cycle, Kibble + Dog Tags escalating, Day 3/5/7 also grant Dog Tags. Missing a day resets the streak. Shown as a full-screen modal on first daily open.

### 9.2 Daily Challenges
3 per day (Easy/Medium/Hard), reset at local midnight. Completing all 3 grants +15 Coins (plus any area-upgrade bonus), +2 Dog Tags, +30 XP; the streak bonus rises to +8 Dog Tags every 7th consecutive day.

### 9.3 Active Quests
3 active at all times, replaced immediately on claim. Difficulty roll: 45% Easy / 30% Medium / 20% Hard / 5% Legendary, capped by player level so early players never see unreachable goals. Goal types: merge any N, merge N of a specific chain, reach a specific tier N times, rescue N animals — the same four `QuestGoal` cases cover both animal and supply-chain progress.

### 9.4 Adoption Orders (formerly "Timed Rescue Requests")
Requests come from a fixed roster of 12 named adopting families/individuals (e.g. "The Chen Family", "Dr. Sarah Park"), not anonymous rescue slots. At least 2 orders active at all times (extendable via area upgrades). Each order wants a specific chain + tier (tier-weighted by player level), 15-minute countdown, auto-replaces on expiry or claim. Rewards: Dog Tags + Coins, and sometimes a card pack (guaranteed above certain Dog Tag thresholds). Skippable for 2 Kibble.

### 9.5 Weekly Family Spotlight
Rotates by calendar week across unlocked families. 2× score on the spotlighted family's merges; hitting 10 spotlight merges in the week grants +5 Dog Tags.

### 9.6 Seasonal Events
Infrastructure (`EventSystem.swift`, `EventRegistry`) is complete: time-boxed events with coin milestones and a themed UI. **Only one event is defined** (`rescue_rush_jun2026`, June 1–15 2026) and it has already expired — there is currently no active event. New `EventDefinition` entries need to be authored before this system does anything visible to players.

### 9.7 Onboarding
A functional, skippable 3-step tutorial (rescue → merge → claim a quest reward) with a pulsing highlight ring and speech-bubble callouts. Shown once, tracked via UserDefaults.

### 9.8 Push Notifications
Scheduling logic is fully implemented in `NotificationManager` (Kibble-full, daily-challenge-reset, order-expiring, re-engagement). **The Push Notifications capability is not yet enabled in the Xcode project**, so permission prompts and delivery won't function on-device until that's toggled in Signing & Capabilities.

### 9.9 Rewarded Ads
The interface (`RewardedAdProvider`) and reward logic (up to 4/day, +25 Kibble, resets 09:00 UTC) are wired, but `StubAdProvider` just waits 1.5 seconds and always succeeds — no real ad SDK (AdMob/AppLovin/etc.) is integrated yet.

---

## 10. Inventory & Storage

The old GDD's "3-tab Merge/Spawner/Supplies inventory" concept was never built as described. What actually shipped is architecturally different and, in practice, better suited to the material-heavy building economy that emerged in later phases:

| Store | Contents | Capacity |
|---|---|---|
| **Animal inventory** | Board items dragged off-board (animals, sub-objects as fallback) | 18 slots: 6 free + 2 unlockable rows of 6 (10 / 25 Dog Tags) |
| **Power-up inventory** | Sub-object top-tier consumables | 6 fixed slots |
| **Material accumulator** | Wood / Metal / Cement, 6 tiers each | **Limitless** — tracked as per-tier counts, not individual slots; two of the same tier auto-cascade into the next tier |
| **Producer storage** | Retired producers, keyed by `ProducerLevel` | 1 designated slot per producer level (level-gated) + 4 overflow slots |

The limitless material accumulator (decided during the Sanctuary Map build-out) intentionally avoids the board-clutter problem individual material items would otherwise cause.

---

## 11. Sanctuary Map & Building

### Overview
Not present at all in earlier GDD drafts. Players spend Coins + tiered materials (wood/metal/cement) to build **15 Sanctuary Areas** in a fixed unlock order, starting with the tutorial-only "Antique Dog House" (Canines, day one) through 14 further areas that each unlock one new family's spawner (and, for the first four, a new board row).

### Per-Area Structure
Each area has:
- A one-time build cost (materials + implicitly gated by `requiresPrevious`)
- An `AreaReward` — new family spawner, sometimes a new board row, plus bonus Kibble/Dog Tags/XP
- **4 upgrade tiers**, each costing Coins + higher-tier materials, granting a permanent `UpgradeBonus` (12 distinct bonus fields: coin multipliers, extra adoption-order slots, weekly-goal discounts, spotlight multiplier bonus, sub-object drop-rate bonus, pity-timer reduction, power-up duration bonus, and more). All active bonuses are summed by `recalcActiveBonuses()`.

Later areas scale materials to higher tiers and larger quantities, so late-game building feels like a genuine investment rather than a passive unlock.

---

## 12. Card Collection & Trading

Entirely new since the last GDD draft.

### Cards & Albums
**54 cards** across **6 albums** (Rescue Profiles, Sanctuary Friends, Animal Kingdom, Vet Records, Adventures Abroad, Hall of Fame), each card Common or Rare. Completing an album pays out Kibble/Dog Tags/Coins (scaling from the first album's modest reward up to Hall of Fame's 100 Kibble / 25 Dog Tags / 250 Coins).

### Packs
6 pack tiers (1★–6★), each with a fixed card count (2 up to 6) and escalating rare odds/guarantees — 1★ has a 5% rare chance and no guarantee; 6★ guarantees 3 rares out of 6 cards. 1★–3★ packs and joker cards (fill any missing common/rare) are buyable in the Star Shop with Stars earned from duplicates; 4★–6★ packs come only from gameplay milestones or IAP.

### Trading
Duplicate cards can be sent to Game Center friends (up to a daily send cap), routed through **CloudKit's public database** — this was the one part of the system that was fully stubbed out until this refresh cycle; it's now wired end-to-end (upload/fetch/claim, plus a fix so the sender's UI actually reflects a claimed trade instead of showing "Pending" forever). It still needs the Game Center and CloudKit capabilities toggled on in Xcode, and the CloudKit schema deployed, before it's live — see Section 16.

---

## 13. Monetization

### IAP Products
12 products configured in a local `.storekit` file (Simulator-testable) and wired to StoreKit 2:

| Product | Contents |
|---|---|
| Kibble Small / Medium / Large | 60 / 180 / 600 Kibble |
| Dog Tag Pack / Bundle / Jackpot | 15 / 60 / 175 Dog Tags |
| Sanctuary Starter Pack | 100 Kibble + 20 Dog Tags |
| Sanctuary Pass (subscription) | +20 Kibble/day, ×1.5 multiplier on all claimed Kibble rewards |
| Energy Pack Small/Medium/Large/XL | Kibble + Dog Tags + a legacy producer + a card pack, bundled |

### Rewarded Ads
See Section 9.9 — reward logic done, ad SDK integration is a stub.

### Monetization Principles (unchanged from earlier drafts, still true in code)
No paywalled story content, no hard energy walls, Dog Tags/Coins never buy board advantages, transparent pricing.

---

## 14. Social Systems

### Game Center
`authenticateGameCenter` runs at launch. Friend loading (`loadGameCenterFriends`) and the leaderboard-adjacent Ambassador count are wired; card trading (Section 12) depends on this being authenticated.

### Invite-a-Friend
Unlocks at player level 5. Milestone rewards at 1/3/5 invites sent (Kibble and/or Dog Tags), a `ShareSheet` wrapper for the native iOS share flow. **The App Store URL is still a placeholder** (`id0000000000`) and needs the real listing URL before launch.

---

## 15. Technical Architecture

### Data Model — Generalized Chain Model
Every mergeable item is `BoardItem(chainID: String, tier: Int)`. All display data (names, colors, symbols, score/XP values) comes from `ContentRegistry` at runtime — saves store only the chain ID and tier, never display data, so content can be added without a save migration.

```swift
enum ChainCategory: String, Codable, CaseIterable {
    case animal, spawner, supply, tool, material, subObject, powerUp
}

struct ContentRegistry {
    static let shared = ContentRegistry()
    func chain(_ id: ChainID) -> MergeChain?
    func tier(_ id: ChainID, _ t: Int) -> ChainTier?
    func nextTier(_ id: ChainID, after t: Int) -> Int?
    func chains(in category: ChainCategory) -> [MergeChain]
}
```

### Pattern & Frameworks
- **Pattern:** MVVM (SwiftUI + a set of `@Observable` domain coordinators — `KibbleEngine`, `PlayerProgression`, `QuestCoordinator`, `AdoptionBoard`, `InventoryStore` — orchestrated by `MergeBoardViewModel`)
- **UI:** SwiftUI
- **IAP:** StoreKit 2, local `.storekit` config for Simulator testing
- **Persistence:** a single `GameState` snapshot, currently at **schema v24**, with an unbroken chain of additive/structural migrations back through v8 (saves from v1–v7 predate the generalized chain model and are detected and discarded with a user-facing alert rather than silently — see Section 16)

### Actual File Structure
```
PawSanctuary/
├── AppEntry.swift, LaunchScreen.swift
├── AnimalSpecies.swift        ← families, RescueStage, BoardCell/GridPosition, constants
├── ItemChain.swift             ← ChainCategory, ChainTier, MergeChain, ContentRegistry
├── SubObjectSystem.swift       ← sub-object drop resolution, pity state, power-up effects
├── SuperpowerSystem.swift      ← Superpower model + per-family registry
├── GameStore.swift             ← GameState + save/load/migration (v8→v24)
├── MergeBoardViewModel.swift   ← core gameplay orchestrator (~2,500 lines)
├── MergeBoardView.swift        ← root game view, banners, overlays
├── CellView.swift, PanelViews.swift, InventoryScreen.swift, InventoryStore.swift
├── KibbleEngine.swift, PlayerProgression.swift, QuestCoordinator.swift, AdoptionBoard.swift
├── SanctuaryMap.swift, MapView.swift
├── CardSystem.swift, CardTrading.swift, CardAlbumView.swift
├── EventSystem.swift, EventPanelView.swift
├── MilestoneManager.swift, MilestoneOverlayView.swift
├── InviteSystem.swift, InvitePanelView.swift
├── StoreManager.swift, AdProvider.swift, ShopView.swift
├── NotificationManager.swift, SoundManager.swift, HapticManager.swift
├── OnboardingView.swift
├── Assets.xcassets/ (real app icon + launch assets), PawSanctuary.storekit, PrivacyInfo.xcprivacy
└── PawSanctuaryTests/PersistenceTests.swift  ← ~1,100 lines covering save/load/migration
```

### Persisted State (`GameState`, abridged)
Board, currencies (kibble/dogTags/coins), score/rescueCount/ambassadors, player level/XP, unlocked chain IDs, animal + power-up inventory, material counts, producer storage, quests/challenges/adoption orders, spotlight state, sanctuary map progress + area upgrade levels, spawn multiplier, card inventory + star count + album completions + pending packs + jokers, pending/incoming card trades, weekly/monthly goal state, login/daily-challenge/loyalty-club bookkeeping, event progress, invite progress, pity states, superpower unlock/cooldown state, pouch/sprint buff state.

### App Store Requirements — actual status
| Item | Status |
|---|---|
| Minimum iOS target (17.0) | ✅ Done |
| Privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ Present |
| App icon (all sizes) | ✅ Present (real PNGs, not placeholders) |
| StoreKit config file | ✅ Present, all 12 products match `IAPProduct` |
| Restore Purchases | ✅ Implemented (`StoreManager.restorePurchases`) |
| Push Notifications capability | ❌ Not enabled in Xcode |
| iCloud (Key-Value + CloudKit) capability | ❌ Not enabled in Xcode |
| Game Center capability | ❌ Not enabled in Xcode |
| Privacy policy / terms of service URLs | ❌ Not found anywhere in the repo |
| AI-generated content disclosure | ❌ Not addressed |
| Age rating declaration | ❌ App Store Connect metadata, not code |

---

## 16. Status & Remaining Work

This replaces the old "Missing Features" list and "Feature Status Tracker" — both were wrong often enough to be actively misleading. Everything below reflects the codebase as read directly, not carried forward from prior drafts.

### ✅ Actually done (previously marked "Not built" in error)
- 15 families × 15 stages, fully authored content registry
- 9×7 = 63-cell board with level-gated row unlocks
- Family unlock via Sanctuary Map (15 areas, 4 upgrade tiers each)
- Sub-object spawning, pity timers, all 4 power-up effects
- All 15 family Superpowers (passive hooks + active dispatch/cooldowns)
- Player level/XP system
- Tutorial/onboarding
- App icon, launch screen, privacy manifest, StoreKit config file
- Sound effects (system-sound placeholders — see below) and haptic feedback
- Push-notification *scheduling logic* (capability toggle still pending)

### 🔴 Genuinely blocking / needs a real integration
1. **Rewarded ads** — `StubAdProvider` is a 1.5-second fake; needs a real SDK (AdMob/AppLovin/etc.)
2. **Real sound assets** — `SoundManager` currently plays `AudioServicesPlaySystemSound` IDs, not bundled audio files
3. **Xcode capability toggles** (Signing & Capabilities, not code): Push Notifications, iCloud (Key-Value + CloudKit), Game Center
4. **CloudKit schema deployment** for card trading — record type + queryable-field configuration, then Development→Production promotion
5. **Privacy policy / terms of service URLs**, **AI disclosure**, **age rating** — App Store Connect / legal, not code

### 🟠 Content gaps
6. **Seasonal events registry has one expired event** — infrastructure works, nothing is currently active; needs new `EventDefinition` entries
7. **Placeholder App Store URL** in the invite system (`id0000000000`)
8. **All 54 cards use SF Symbols, not illustrated art** — a content/asset-production task

### 🟡 Known code-quality debt (see `docs/CODE_HEALTH.md` for full detail; most items were addressed in the July 2026 pass)
- The single largest remaining structural item is extracting board manipulation out of `MergeBoardViewModel` (2,500+ lines) into a dedicated `BoardStateManager` — flagged as a "dedicated sprint" item, deliberately not attempted piecemeal because of its size and risk.

### 🟢 Post-launch / nice-to-have (unchanged in spirit from earlier drafts, still not built)
Animal encyclopedia / collection log, Sanctuary Collection gallery for Legendaries, board cosmetic themes, score leaderboard, CloudKit *cross-device* save sync (the KVS half exists; full CloudKit sync does not), iPad-specific layout, localization.

---

*This document should be re-verified against the codebase — not just extended — the next time it's updated. The failure mode that produced the July 2026 refresh was incremental edits drifting away from a fast-moving implementation; re-reading the source is cheaper than that drift compounding again.*
