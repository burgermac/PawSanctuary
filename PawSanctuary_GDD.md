# Paw Sanctuary — Game Design Document
**Version 2.1 | June 2026**

> **What changed in v2.1:** Added per-family **Superpowers** — unique passive or active abilities that unlock when a family first reaches Era 3 (Stage 7). Each of the 15 families has a thematically distinct ability that adds strategic differentiation to family choice.
>
> **What changed in v2.0:** Expanded from 8 species × 5 stages to **15 animal families × 15 stages**. Added a five-era progression structure (Infant → Legendary), per-family sub-object spawning chains (4-stage merge), a reward consumable system, and a 3-tab inventory replacing the 3-row layout.

---

## Table of Contents
1. [Game Overview](#1-game-overview)
2. [Core Loop](#2-core-loop)
3. [Board & Merge System](#3-board--merge-system)
4. [Animal System](#4-animal-system)
5. [Sub-Object Spawning](#5-sub-object-spawning)
6. [Family Superpowers](#6-family-superpowers)
7. [Economy & Currencies](#7-economy--currencies)
8. [Progression Systems](#8-progression-systems)
9. [Engagement Systems](#9-engagement-systems)
10. [Inventory System](#10-inventory-system)
11. [Monetization](#11-monetization)
12. [Content Roadmap](#12-content-roadmap)
13. [Technical Architecture](#13-technical-architecture)
14. [Missing Features (Build Priority)](#14-missing-features-build-priority)
15. [Feature Status Tracker](#15-feature-status-tracker)

---

## 1. Game Overview

**Genre:** Merge puzzle / idle casual  
**Platform:** iOS (iPhone primary, iPad secondary)  
**Audience:** Casual mobile gamers, animal lovers, ages 18–45  
**Monetization model:** Free-to-play with IAP and optional subscription  
**Comparable titles:** Travel Town, Tasty Travels, Merge Mansion  
**Differentiator:** Better value per dollar than competitors; pet rescue theme with emotional resonance; 15-stage depth per family gives long-term progression rivals can't match

### Elevator Pitch
Players run an animal sanctuary, rescuing animals across 15 families and merging them through 15 evolutionary stages — from Infant to Legendary. Each family also produces themed sub-objects that merge into powerful consumables. The board fills up, strategy matters, and a rich set of daily and weekly systems keep players coming back.

### Design Pillars
1. **Warmth** — every interaction feels like caring for animals, not grinding
2. **Value** — players always feel the game is generous compared to competitors
3. **Momentum** — there is always a next thing to do; dead ends are eliminated by design
4. **Clarity** — new players understand what to do within 60 seconds

---

## 2. Core Loop

### Session Loop (5–15 minutes)
```
Open app
  → Claim daily login reward
  → Check timed rescue requests (urgent)
  → Rescue animals (spend Kibble)
  → Merge matching animals → advance through 15-stage chain
  → Merge sub-objects → earn consumable rewards
  → Complete daily challenges / active quests
  → Claim rewards (Kibble + Dog Tags)
  → Store excess animals in inventory (Merge tab)
  → Exit when Kibble runs low
```

### Retention Loop (daily)
```
Daily login streak → escalating rewards
Daily challenges reset at midnight → reason to return
Timed rescue requests cycle every 10 min → urgency
Weekly spotlight changes Monday → fresh goal
Push notification: "Your Kibble is full!" → re-engagement
```

### Progression Loop (weeks → months)
```
Unlock board cells (every 3 merges)
Progress through 15 stages × 15 families (225 unique items)
Unlock higher-era families at milestone stages
Complete harder quest tiers
Reach Legendary milestones → exclusive rewards
Seasonal events (future)
```

---

## 3. Board & Merge System

### Board Configuration
- **Grid:** 6 rows × 5 columns = 30 total cells
- **Starting unlocked:** rows 2–5 (20 cells)
- **Locked:** rows 0–1 (10 cells), unlocked via merges
- **Unlock rate:** 1 cell per 3 merges, left-to-right, row 1 before row 0

### Merge Rules
| Scenario | Result |
|---|---|
| Same family + same stage | Merge → next stage |
| Different family OR different stage | Swap positions |
| Source → empty cell | Move |
| Drag off bottom of board | Send to inventory (Merge tab) |

### Spawn Rules
- **Player-triggered rescue:** costs 1 Kibble, spawns a random Infant (Stage 1) in any empty unlocked cell
- **Auto-spawn after merge:** free, spawns immediately after every successful merge
- **Sub-object spawn:** each family's Primary Spawner drops Stage-1 sub-objects periodically (see Section 5)
- **Board full:** rescue button disabled; hint encourages storing items in inventory
- **Species distribution:** fully random; no weighting toward needed species (future: weighted spawns)

### Future Board Features (planned)
- Special cells: golden cells that give 2× score on any merge performed there
- Obstacle cells: locked debris that must be cleared by merging adjacent animals
- Sanctuary zones: dedicated display area for Legendary animals (removed from play board)

---

## 4. Animal System

### Overview
There are **15 animal families**. Each family has **15 merge stages** arranged into 5 Eras. Players unlock families progressively; not all 15 are available from the start.

### Era Structure (5 Eras × 3 Stages)

| Era | Stages | Theme | Visual Treatment |
|---|---|---|---|
| **Era 1 — Infant / Juvenile** | 1–3 | Baby animals, just arrived | Desaturated, small silhouette |
| **Era 2 — Adolescent** | 4–6 | Young but growing | Partial color, medium size |
| **Era 3 — Young Adult** | 7–9 | Full-grown species variants | Full color |
| **Era 4 — Adult** | 10–12 | Powerful, distinguished | Golden border accent |
| **Era 5 — Peak / Legendary** | 13–15 | Mythic / ultimate forms | Animated glow, ⭐ badge |

Stage 15 (Legendary) is removed to the Sanctuary Collection on merge completion and awards a milestone bonus.

### Starter Families (unlocked from the beginning)
Canines, Felines, Avians, Rodents, Aquatics

### Progression-Unlocked Families
The remaining 10 families are unlocked as the player reaches stage milestones in starter families:
- Stage 6 clears (any starter) → Unlock Ursids, Cervids
- Stage 9 clears (any family) → Unlock Equines, Bovines, Reptiles
- Stage 12 clears → Unlock Amphibians, Primates, Lagomorphs
- Stage 14 clears → Unlock Pachyderms, Marsupials

### Animal Merge Progression (15 Stages per Family)

| Family | 1–3 (Infant/Juv) | 4–6 (Adolescent) | 7–9 (Young Adult) | 10–12 (Adult) | 13–15 (Legendary) |
|---|---|---|---|---|---|
| **Canines** | Pup, Kit, Houndling | Terrier, Spaniel, Scout | Retriever, Shepherd, Husky | Alpha, Guardian, Sentinel | Dire Wolf, Mythic, Primordial |
| **Felines** | Kitten, Tabby, Kit | Ocelot, Bobcat, Lynx | Puma, Jaguar, Leopard | Panther, Tiger, Lion | Sabertooth, Sovereign, Apex |
| **Rodents** | Mouse, Hamster, Gerbil | Chipmunk, Squirrel, Rat | Chinchilla, Degu, Beaver | Prairie Dog, Marmot, Nutria | Muskrat, Porcupine, Capybara |
| **Avians** | Hatchling, Chick, Fluff | Sparrow, Finch, Starling | Pigeon, Magpie, Jay | Falcon, Hawk, Owl | Eagle, Vulture, Condor |
| **Bovines** | Calf, Heifer, Oxen | Steer, Bull, Zebu | Bison, Yak, Muskox | Highland, Longhorn, Gaur | Buffalo, Aurochs, Titan |
| **Equines** | Foal, Pony, Shetland | Donkey, Mule, Burro | Mustang, Arabian, Paint | Thoroughbred, Shire, Clydesdale | Zebra, Quagga, Giraffe |
| **Ursids** | Cub, Sun, Sloth | Spectacled, Moon, Black | Panda, Cinnamon, Glacier | Brown, Kodiak, Grizzly | Polar, Ancient, Behemoth |
| **Cervids** | Fawn, Muntjac, Roe | Fallow, Chital, Sika | Caribou, Reindeer, Deer | Red, Wapiti, Elk | Sambar, Pere David, Moose |
| **Aquatics** | Guppy, Tetra, Minnow | Clown, Perch, Bass | Mackerel, Tuna, Salmon | Sword, Sail, Marlin | Shark, Hammerhead, Whale Shark |
| **Reptiles** | Hatch, Gecko, Anole | Skink, Racer, Whiptail | Iguana, Monitor, Tegu | Gila, Spiny, Python | Boa, Caiman, Komodo Dragon |
| **Amphibians** | Tadpole, Froglet, Newt | Tree Frog, Poison, Reed | Bullfrog, Toad, Horned | Salamander, Axolotl, Mud | Hellbender, Giant, Goliath |
| **Primates** | Marmoset, Tamarin, Pygmy | Squirrel, Capuchin, Owl | Macaque, Langur, Guenon | Baboon, Mandrill, Gibbon | Chimpanzee, Orangutan, Gorilla |
| **Pachyderms** | Piglet, Warthog, Peccary | Tapir, Boar, Babirusa | Hippo, Pygmy, Rhino | White Rhino, Black, Indian | Seal, African, Mammoth |
| **Lagomorphs** | Bunny, Cottontail, Rex | Angora, Lop, Harlequin | Hare, Jackrabbit, Snow | Flemish, Belgian, Giant | Desert, Patagonian, Mara |
| **Marsupials** | Joey, Quokka, Honey | Potoroo, Bandicoot, Bilby | Wallaby, Pademelon, Tree | Devil, Quoll, Wombat | Koala, Macropod, Red Kangaroo |

### Stage Score Values

| Era | Stage | Score | Notes |
|---|---|---|---|
| Infant | 1 | 25 | |
| Infant | 2 | 50 | |
| Infant | 3 | 75 | |
| Adolescent | 4 | 125 | |
| Adolescent | 5 | 175 | |
| Adolescent | 6 | 250 | |
| Young Adult | 7 | 375 | |
| Young Adult | 8 | 550 | |
| Young Adult | 9 | 800 | |
| Adult | 10 | 1,200 | |
| Adult | 11 | 1,750 | |
| Adult | 12 | 2,500 | |
| Legendary | 13 | 4,000 | |
| Legendary | 14 | 6,000 | |
| Legendary | 15 | 10,000 | Removed to Sanctuary Collection |

Weekly spotlight species gives **2× score** on all merges.

### Future Animal Features (planned)
- **Rare/event species:** unlockable via Dog Tags or seasonal events
- **Special abilities:** certain families trigger bonus events (Canines occasionally bring a free rescue)
- **Animal encyclopedia:** collectibles screen showing all families/stages discovered
- **Sanctuary display:** gallery of all Legendary animals earned

---

## 5. Sub-Object Spawning

### Overview
Each animal family has a **Primary Spawner** that periodically drops Stage-1 sub-objects onto the board. Sub-objects form independent 4-stage merge chains. Merging to Stage 4 (the consumable) rewards one of four consumable types and clears the board space.

Sub-objects are stored in the **Spawner tab** of the inventory (see Section 9) and never merge with animal pieces.

### Sub-Object Chains (4-Stage Merge per Family)

| Family | Stage 1 | Stage 2 | Stage 3 | Stage 4 (Consumable) |
|---|---|---|---|---|
| **Canines** | Biscuit | Bone | Chew Toy | Golden Ball |
| **Felines** | Bell | Feather Wand | Yarn Ball | Laser Pointer |
| **Rodents** | Seed | Nut | Berry | Corn Cob |
| **Avians** | Down | Plume | Quill | Iridescent Tail |
| **Bovines** | Clover | Hay Bale | Salt Lick | Water Trough |
| **Equines** | Curry Comb | Brush | Sponge | Trophy |
| **Ursids** | Honey Comb | Salmon | Wild Hive | Berry Bush |
| **Cervids** | Leaf | Sprout | Twig | Antler |
| **Aquatics** | Shell | Pearl | Starfish | Treasure Chest |
| **Reptiles** | Pebble | Sand | Warm Moss | Heat Lamp |
| **Amphibians** | Duckweed | Reeds | Lotus Flower | Algae Bloom |
| **Primates** | Banana | Mango | Papaya | Jungle Vine |
| **Pachyderms** | Puddle | Mud Clump | Clay Mound | Rainfall |
| **Lagomorphs** | Lettuce | Carrot | Cabbage | Turnip |
| **Marsupials** | Bud | Flower | Leaf Bundle | Bark |

### Consumable Reward Types (Stage 4 drop)

When a sub-object chain reaches Stage 4 and is merged, it yields one randomized consumable:

| Reward | Effect | Drop Rate |
|---|---|---|
| **Speed Burst** | 2× spawner production speed for 30 seconds | 60% (Common) |
| **Map Supplies** | Rare resource used for area/map expansion | 25% (Uncommon) |
| **Spawner Refill** | Instantly restores all production charges | 10% (Rare) |
| **Drop Guarantee** | Forces the next spawner drop to be Stage 2 or 3 animal | 5% (Epic) |

Consumables are stored in the **Supplies tab** of the inventory (see Section 9) and activated by tapping.

### Spawner Production Rules
- Each family's spawner has a **charge pool** (starts at 5 charges; replenished by Spawner Refill consumable or Dog Tags)
- Drops one Stage-1 sub-object per charge, on a cooldown timer
- Spawner charges are visible as a pip indicator on the spawner tile
- When charges reach 0 the spawner idles until refilled

---

## 6. Family Superpowers

### Overview
Each animal family has one unique **Superpower** — a passive or active ability that unlocks the first time that family reaches **Era 3 (Stage 7)**. Superpowers add strategic differentiation: players who invest deeply in a family gain a tangible board advantage, making family choice meaningful beyond just aesthetic preference.

- **Passive** abilities trigger automatically under a defined condition
- **Active** abilities are triggered by a tap and operate on a cooldown
- All Superpowers are visible (greyed out) before unlock so players can plan ahead

### Superpower Reference

| Family | Type | Name | Ability |
|---|---|---|---|
| **Canines** | Passive | Fetch! | Every 5th merge anywhere on the board, a free Stage-1 Canine appears in a random empty cell |
| **Felines** | Active (90s cooldown) | Nine Lives | Undo the last move — swap two pieces back to their positions before the action |
| **Rodents** | Passive | Hoard | Rodent Spawner drops Stage-2 sub-objects instead of Stage-1 |
| **Avians** | Passive | Scout | Before each rescue, a small preview shows the species of the next 2 incoming rescues |
| **Bovines** | Active (3-min cooldown) | Stampede | Instantly merge all same-family same-stage pairs currently on the board simultaneously |
| **Equines** | Active (60s cooldown) | Sprint | Doubles Kibble regen rate for 60 seconds |
| **Ursids** | Passive | Hibernate Bonus | If no merges are made for 5+ minutes, the next rescue spawns at Stage 3 |
| **Cervids** | Passive | Antler Drop | Every Cervid merge has a 25% chance to drop a bonus Stage-2 sub-object |
| **Aquatics** | Passive | Current | After any merge, sub-object pieces on the board auto-slide to fill the nearest gap |
| **Reptiles** | Passive | Bask | Reptile Spawner charges regenerate at 2× the normal rate |
| **Amphibians** | Active (2-min cooldown) | Leap | Tap any Amphibian to teleport it to any empty board cell |
| **Primates** | Active (90s cooldown) | Mimic | Spawns a free Stage-1 animal matching the family of the last successful merge |
| **Pachyderms** | Passive | Memory | Quest and challenge progress for Pachyderm goals counts double |
| **Lagomorphs** | Passive | Multiply | Every 4th Lagomorph merge spawns two Stage-1 Lagomorphs as the auto-spawn instead of one |
| **Marsupials** | Active (30s hold, 3-min cooldown) | Pouch | Temporarily store up to 2 extra animals outside the inventory for 30 seconds; they return to the board when the timer expires |

### Balance Notes
- **Canines / Lagomorphs** increase board density — useful for players who want to merge faster, but can fill the board if unmanaged
- **Felines** is the only undo mechanic in the game — strategically high value, long cooldown intentional
- **Bovines (Stampede)** requires setup (pairs on board) but can chain-clear a cluttered board
- **Avians (Scout)** reduces randomness — valuable for quest targeting without breaking core random-spawn feel
- **Pachyderms (Memory)** is a pure progression accelerator — no board effect, so it doesn't disrupt balance

### Superpower UI
- A small family-specific icon appears in the corner of every board cell containing that family
- Active ability button appears in a side strip when a family with an unlocked Active power is present on the board
- Greyed-out lock icon shows on the button before Era 3 unlock with "Reach Stage 7 to unlock"
- A brief celebration animation plays on first unlock ("🐾 [Family] Superpower Unlocked!")

---

## 7. Economy & Currencies  

### 🦴 Kibble (Energy Currency)
| Property | Value |
|---|---|
| Starting amount | 20 |
| Regen rate | 1 per minute |
| Regen cap | 100 |
| Max (with purchases) | Unlimited |
| Cost per rescue | 1 |
| Auto-spawn after merge | Free |

**Kibble sources:**
- Timer regen (primary, capped at 100)
- Quest rewards (2–8 per quest)
- Daily challenge bonus (+10 standard, +30 on 7-day streak)
- Daily login reward (5–20 per day)
- IAP purchases (60 / 180 / 600)
- Sanctuary Pass daily bonus (+30/day, subscription)
- Timed rescue request completion bonus (5–10)

### 🪪 Dog Tags (Premium Currency)
| Property | Value |
|---|---|
| Starting amount | 0 |
| Earned via | Quests, challenges, milestones |
| Cannot be earned via | Timer |

**Dog Tag sources:**
- Active quest rewards (1–6 per quest by difficulty)
- Daily challenge bonus (+2 standard, +8 on 7-day streak)
- Weekly spotlight milestone (+5 at 10 merges)
- Daily login rewards (Day 3: +2, Day 5: +3, Day 7: +5)
- IAP purchases (15 / 60 / 175)

**Dog Tag spending:**
- Inventory Supplies tab unlock: 10 tags
- Inventory Spawner tab unlock: 25 tags
- Instant Kibble refill (future): 5 tags → full refill
- Skip rescue request timer (future): 3 tags
- Unlock specific family spawn (future): 8 tags
- Spawner refill (alternative to consumable drop): 3 tags per spawner

### Economy Balance Principles
- A free player should never feel stuck — daily login + quest rewards provide steady Kibble
- Dog Tags should feel earned, not required — core gameplay never requires spending them
- IAP should feel like a genuine value upgrade, not a paywall
- Per-unit Kibble cost should be 30–40% cheaper than Travel Town equivalent

---

## 8. Progression Systems

### Cell Unlock Progression
```
Merges 1–3:   Unlock cell (row 1, col 0)
Merges 4–6:   Unlock cell (row 1, col 1)
...
Merges 13–15: Unlock cell (row 0, col 4)
Total: 30 merges to unlock all 10 locked cells
```
Progress bar with "X more merges" hint keeps player informed.

### Family Unlock Progression
```
Start:             Canines, Felines, Avians, Rodents, Aquatics (5 families)
Stage 6 clear:     +Ursids, Cervids
Stage 9 clear:     +Equines, Bovines, Reptiles
Stage 12 clear:    +Amphibians, Primates, Lagomorphs
Stage 14 clear:    +Pachyderms, Marsupials (all 15 unlocked)
```
Unlocking a new family triggers a short celebration animation and introduces the family's first Infant pair and its Primary Spawner.

### Score Progression
- Score = stage score value (see Section 4 table) × spotlight_multiplier
- Weekly spotlight gives 2× score on featured family
- Score displayed in bottom bar; no leaderboard yet (future feature)
- Score resets per session (future: persistent lifetime score / leaderboard)

### Player Level (not yet built — planned)
- XP earned from merges, quest completion, and login streaks
- Level ups unlock cosmetic rewards: board themes, animal name tags, emojis
- No hard gating behind levels — purely cosmetic progression

### Legendary Milestones (replacing Sanctuary Star Milestones)
```
5 Legendaries:   Title "Junior Rescuer" + 10 Kibble bonus
15 Legendaries:  Title "Animal Friend" + 5 Dog Tags
30 Legendaries:  Title "Sanctuary Guardian" + free inventory tab
50 Legendaries:  Title "Legendary Rescuer" + exclusive rare family unlock
```

---

## 9. Engagement Systems

### 8.1 Daily Login Reward ("Morning Feeding")
| Day | Kibble | Dog Tags |
|---|---|---|
| Day 1 | +5 | — |
| Day 2 | +10 | — |
| Day 3 | +5 | +2 |
| Day 4 | +15 | — |
| Day 5 | +10 | +3 |
| Day 6 | +20 | — |
| Day 7 | +15 | +5 |

- Cycle repeats after Day 7
- Missing a day resets streak to Day 1
- Shown as full-screen modal on first daily open
- Persisted via UserDefaults

### 8.2 Daily Challenges ("Daily Shelter Tasks")
- 3 challenges per day: 1 Easy, 1 Medium, 1 Hard
- Reset at midnight (local time)
- Completing all 3 awards: +10 Kibble, +2 Dog Tags
- 7-day completion streak: +30 Kibble, +8 Dog Tags
- Streak resets if all 3 not completed in a day

**Challenge pool by difficulty:**
| Difficulty | Example Goals |
|---|---|
| Easy | Merge 3 animals; Rescue 4 strays; Merge 2 [family] |
| Medium | Merge 6 animals; Get 1 animal to Era 3; Rescue 8 strays |
| Hard | Get 1 animal to Era 4; Merge 10 animals; Reach Stage 10 with any family |

### 8.3 Active Quests
- 3 active at all times; manually claimed
- Replaced immediately on claim
- Difficulty weighted: 50% Easy, 30% Medium, 20% Hard
- Rewards scale with difficulty (Kibble + Dog Tags)

**Quest goal types:**
- Merge any X animals
- Merge X of a specific family
- Get X animals to a specific era/stage
- Rescue X strays
- Collect X sub-object consumables

### 8.4 Timed Rescue Requests ("Urgent Requests")
- 2 active at all times
- 10-minute countdown per request
- Auto-claimed on completion (bonus awarded immediately)
- Replaced automatically on expiry
- Timer bar turns red in final 2 minutes
- Bonus: 5–10 Kibble + 1–3 Dog Tags on completion

### 8.5 Weekly Family Spotlight
- Featured family rotates by calendar week
- 2× score for all merges of that family
- Weekly milestone: merge 10 spotlight animals → +20 Kibble, +5 Dog Tags
- Golden border shown on board cells containing spotlight family
- Compact banner displayed below currency bar
- Progress resets Monday midnight

### 8.6 Push Notifications (not yet built — planned)
| Trigger | Message |
|---|---|
| Kibble full | "Your Kibble bag is full! Come rescue some animals." |
| Daily challenge reset | "New daily challenges are ready at the sanctuary!" |
| Rescue request expiring | "Your rescue request expires in 2 minutes!" |
| Login streak at risk | "Don't break your streak! Log in before midnight." |
| Weekly spotlight change | "New spotlight family this week: [emoji] [Name]!" |
| Spawner idle | "Your [Family] Spawner has run out of charges!" |

### 8.7 Seasonal Events (not yet built — planned)
- 4 events per year (Spring Rescue, Summer Safari, Autumn Harvest, Winter Warmth)
- Duration: 7 days
- Exclusive rare families/stages available only during event
- Event currency earned through special merges; spent on exclusive rewards
- Leaderboard showing top rescuers during event window

---

## 10. Inventory System

### Overview
The inventory is a **3-tab panel** replacing the previous 3-row layout. Each tab holds a different category of item to reduce clutter and create deliberate "grid pressure."

| Tab | Contents | Default Slots | Unlock Cost |
|---|---|---|---|
| **Merge** | Animal board items | 6 | Free (always open) |
| **Spawner** | Sub-object chain items | 6 | 10 Dog Tags |
| **Supplies** | Consumable rewards | 6 | 25 Dog Tags (requires Spawner tab first) |
| **Total** | All item types | 18 | |

The 3-tab constraint forces players to make choices about what to keep, creating the natural "grid pressure" that drives shop conversions without ever feeling punitive.

### Interaction Model
- **Store from board:** tap animal → tap "Store Selected" button → routes to Merge tab
- **Store via drag:** drag animal off bottom of board → auto-routes to first empty Merge slot
- **Store sub-object:** sub-object pieces dragged off board → route to Spawner tab
- **Retrieve to board:** open inventory → tap item → "Place on Board" → placed in first empty cell
- **Rearrange inventory:** tap slot → tap another slot → swap (within same tab)
- **Inventory tab full:** "[Tab] Full" toast for 3 seconds

### Future Inventory Features (planned)
- Drag-and-drop directly from inventory to board cell
- Sort tab by family or stage
- Favorite/pin slots to prevent accidental overwriting
- Inventory expansion via IAP (additional slots per tab)

---

## 11. Monetization

### IAP Products
| Product ID | Name | Contents | Suggested Price |
|---|---|---|---|
| kibble.small | Small Kibble Bag | 60 Kibble | $0.99 |
| kibble.medium | Medium Kibble Bag | 180 Kibble | $1.99 |
| kibble.large | Large Kibble Bag | 600 Kibble | $4.99 |
| dogtags.small | Dog Tag Pack | 15 Tags | $0.99 |
| dogtags.medium | Dog Tag Bundle | 60 Tags | $2.99 |
| dogtags.large | Dog Tag Jackpot | 175 Tags | $6.99 |
| bundle.starter | Sanctuary Starter Pack | 100 Kibble + 20 Tags | $1.99 |
| pass.monthly | Sanctuary Pass | +30 Kibble/day + perks | $4.99/mo |

### Value Positioning vs. Competitors
- Travel Town equivalent: ~$1.99 for ~20 minutes of energy
- Paw Sanctuary target: $1.99 for ~60 minutes of energy (3× better value)
- Large bundle per-unit cost always 40%+ cheaper than small bundle
- Sanctuary Pass daily bonus recoverable in ~3.3 days at full play

### Sanctuary Pass Perks (subscription)
- +30 Kibble bonus on first daily open
- 1 free timed rescue request skip per day
- 1 free Spawner Refill per day
- Exclusive "Pass" badge on profile (future)
- Early access to seasonal events (future)

### Rewarded Ads (not yet built — planned)
- Option to watch ad for +5 Kibble (max 3× per day)
- Option to watch ad to extend a timed rescue request by 5 minutes
- Never mandatory; always player-initiated
- Shown only when Kibble is at 0

### Monetization Principles
- No paywalled story content
- No energy walls that prevent all play
- No "pay to win" — Dog Tags and Kibble never give board advantages
- Transparent pricing (always show what you're getting)
- Never show purchase prompt more than once per session

---

## 12. Content Roadmap

### Phase 1 — Foundation (Current)
- [x] 6×5 merge board with drag/drop
- [x] Kibble + Dog Tag economy
- [x] Cell unlock progression
- [x] Active quest system (3 quests)
- [x] Daily login rewards
- [x] Daily challenges with streak
- [x] Timed rescue requests
- [x] Weekly spotlight
- [x] IAP scaffold (StoreKit 2)
- [x] Shop UI (preview mode)
- [x] Game state persistence
- [ ] Tutorial / onboarding
- [ ] Sound effects + haptics
- [ ] App icon + launch screen

### Phase 2 — v2.0 Animal Expansion (Next)
- [ ] Expand to 15 animal families × 15 stages (data-driven via ContentRegistry)
- [ ] 5-era visual treatment (Infant → Legendary era borders/effects)
- [ ] Family unlock progression system (stage milestone gates)
- [ ] Sub-object spawning chains (15 families × 4-stage sub-chains)
- [ ] Spawner tile UI (charge pips, idle state)
- [ ] Consumable rewards system (Speed Burst, Map Supplies, Spawner Refill, Drop Guarantee)
- [ ] 3-tab inventory (Merge / Spawner / Supplies)
- [ ] Quest goals updated for sub-objects and 15-stage chain
- [ ] Family Superpowers (15 abilities, unlock at Era 3 per family)
- [ ] Active Superpower button strip UI + cooldown display
- [ ] Legendary celebration animation + Sanctuary Collection

### Phase 3 — Polish & App Store
- [ ] SwiftData persistence (board, inventory, currencies, quests)
- [ ] Push notifications (6+ triggers)
- [ ] StoreKit configuration file (enable Simulator testing)
- [ ] Onboarding flow (first 5 minutes)
- [ ] Haptic feedback on merge, unlock, reward
- [ ] Sound effects (merge, rescue, reward, UI)
- [ ] App icon + launch screen
- [ ] Privacy policy + terms (required for App Store)
- [ ] AI disclosure statement (App Store requirement)
- [ ] Privacy manifest (PrivacyInfo.xcprivacy)

### Phase 4 — Expansion (Post-launch)
- [ ] Sanctuary Collection screen (all Legendaries earned)
- [ ] Player level system (XP + cosmetic rewards)
- [ ] Legendary milestone rewards
- [ ] Rare/exclusive families (seasonal)
- [ ] Rewarded ads integration
- [ ] Push notification system
- [ ] Board themes (cosmetic)
- [ ] Animal encyclopedia / collection log
- [ ] Score leaderboard

### Phase 5 — Live Ops (3+ months post-launch)
- [ ] Seasonal events (4/year)
- [ ] Limited-time families/stages
- [ ] Event leaderboards
- [ ] Friend system (view friend sanctuaries)
- [ ] CloudKit sync (cross-device)
- [ ] iPad layout
- [ ] Localization (Spanish, French, German)
- [ ] Map/area expansion system (uses Map Supplies consumable)

---

## 13. Technical Architecture

### Data Model (v2.0 — Generalized Chain Model)
The game uses a **content-registry pattern** (`ContentRegistry`) so that all 15 families × 15 stages × 15 sub-object chains are authored as data, not code. Adding a new family or stage is a data edit, not a code change.

```swift
typealias ChainID = String   // e.g. "animal.canine", "sub.canine"

struct BoardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var chainID: ChainID     // stable identifier
    var tier: Int            // 0-indexed; 0–14 for animals, 0–3 for sub-objects
}

struct ContentRegistry {
    static let shared = ContentRegistry()
    func chain(_ id: ChainID) -> MergeChain?
    func tier(_ id: ChainID, _ t: Int) -> ChainTier?
    func nextTier(_ id: ChainID, after t: Int) -> Int?
    func chains(in category: ChainCategory) -> [MergeChain]
}
```

The **save only ever stores `chainID` (String) + `tier` (Int)** — never display data. All names/icons/colours come from the registry at runtime.

### Chain Categories
```swift
enum ChainCategory: String, Codable, CaseIterable {
    case animal     // 15 families × 15 stages
    case subObject  // 15 families × 4 stages (sub-object chains)
    case spawner    // Primary Spawner tiles (one per family)
    case tool       // Phase 4+
    case material   // Phase 4+
}
```

### Current State
- **Pattern:** MVVM (SwiftUI + SwiftData)
- **UI framework:** SwiftUI
- **IAP:** StoreKit 2
- **Persistence:** SwiftData (game state), UserDefaults (login streak, daily challenges, spotlight)

### Target File Structure
```
PawSanctuary/
├── App/
│   └── PawSanctuaryApp.swift
│
├── Models/
│   ├── BoardItem.swift
│   ├── BoardCell.swift
│   ├── GridPosition.swift
│   ├── ChainCategory.swift
│   └── ContentRegistry.swift       ← single source of truth for all chains
│
├── Content/
│   ├── AnimalChains.swift          ← 15 families × 15 tiers defined here
│   └── SubObjectChains.swift       ← 15 families × 4 tiers defined here
│
├── Quest Models/
│   ├── QuestGoal.swift
│   ├── Quest.swift
│   ├── DailyChallenge.swift
│   └── RescueRequest.swift
│
├── ViewModels/
│   ├── MergeBoardViewModel.swift
│   ├── QuestViewModel.swift
│   ├── InventoryViewModel.swift
│   └── EngagementViewModel.swift
│
├── Managers/
│   ├── StoreManager.swift
│   ├── PersistenceManager.swift
│   ├── NotificationManager.swift
│   └── HapticManager.swift
│
├── Views/
│   ├── Game/
│   │   ├── MergeBoardView.swift
│   │   ├── CellView.swift
│   │   ├── SpawnerTileView.swift    ← new: charge pips, idle state
│   │   └── BottomBarView.swift
│   ├── Quests/
│   │   ├── QuestCardView.swift
│   │   ├── DailyChallengePanelView.swift
│   │   └── RescueRequestPanelView.swift
│   ├── Engagement/
│   │   ├── LoginRewardView.swift
│   │   └── SpotlightBannerView.swift
│   ├── Inventory/
│   │   ├── InventoryScreenView.swift   ← 3-tab layout
│   │   └── InventorySlotView.swift
│   ├── Shop/
│   │   └── ShopView.swift
│   └── Shared/
│       └── ToastView.swift
│
├── Constants/
│   └── GameConstants.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Sounds/
    └── PawSanctuary.storekit
```

### Persistence Strategy (SwiftData)
```swift
@Model class SavedGameState {
    var board: [[BoardCellData]]
    var inventory: [String: [BoardItemData?]]  // keyed by tab: "merge", "spawner", "supplies"
    var kibble: Int
    var dogTags: Int
    var score: Int
    var mergeCount: Int
    var legendaryCount: Int           // replaces sanctuaryStars
    var rescueCount: Int
    var mergeTabUnlocked: Bool        // always true
    var spawnerTabUnlocked: Bool
    var suppliesTabUnlocked: Bool
    var unlockedChainIDs: [String]    // which families are unlocked
    var activeQuests: [QuestData]
    var spawnerCharges: [String: Int] // chainID → remaining charges
    var lastSaved: Date
}
```

### App Store Requirements Checklist
- [ ] Minimum iOS target: 16.0
- [ ] Privacy manifest (PrivacyInfo.xcprivacy)
- [ ] Privacy nutrition labels (data types used)
- [ ] AI-generated content disclosure (Guideline 2.1)
- [ ] StoreKit products configured in App Store Connect
- [ ] GENERATE_INFOPLIST_FILE = YES
- [ ] Valid signing certificate + provisioning profile
- [ ] App icon (all required sizes via asset catalog)
- [ ] Launch screen
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] Age rating declaration
- [ ] Restore Purchases button (IAP requirement)

---

## 14. Missing Features (Build Priority)

These are ordered by impact and dependency:

### 🔴 Critical (required before shipping)
1. **Tutorial / onboarding** — new users have no guidance; kills retention
2. **App icon + launch screen** — required for App Store submission
3. **Privacy manifest** — required for App Store submission since iOS 17.5
4. **StoreKit config file** — needed to test IAP in Simulator

### 🟠 V2.0 Expansion (core gameplay completeness)
5. **15 families × 15 stages** — expand ContentRegistry with all animal chain data
6. **5-era visual treatment** — era-specific borders, colors, and Legendary glow/animation
7. **Family unlock progression** — gate families behind stage milestone clears
8. **Sub-object spawning** — Spawner tiles, 4-stage sub-object chains per family
9. **Consumable reward system** — Speed Burst, Map Supplies, Spawner Refill, Drop Guarantee
10. **3-tab inventory** — Merge / Spawner / Supplies tabs
11. **Family Superpowers** — 15 unique passive/active abilities; unlock at Era 3 per family; Active Superpower button strip with cooldown display

### 🟡 High Priority (ship soon after launch)
12. **Sound effects** — merge, rescue, reward, UI taps
13. **Haptic feedback** — merge success, unlock, reward claim
14. **Push notifications** — Kibble refill, daily challenge, streak at risk, spawner idle
15. **Legendary milestone rewards** — completing the 15-stage chain needs a payoff
16. **Rewarded ads** — meaningful free-to-play retention tool
17. **iCloud KVS sync** — entitlement already provisioned; activate in Xcode capabilities

### 🟢 Nice to Have (post-launch)
17. Player level + XP system
18. Animal encyclopedia / collection screen
19. Board cell themes (cosmetic)
20. Sanctuary Collection display/gallery
21. Friend system
22. Seasonal events
23. CloudKit cross-device sync
24. iPad layout optimization
25. Localization
26. Map/area expansion (using Map Supplies consumable)

---

## 15. Feature Status Tracker

| Feature | Status | Priority |
|---|---|---|
| Merge board (6×5) | ✅ Done | — |
| Drag and drop | ✅ Done | — |
| Swap on non-match | ✅ Done | — |
| Cell unlock (every 3 merges) | ✅ Done | — |
| Kibble regen (1/min, cap 100) | ✅ Done | — |
| Dog Tags currency | ✅ Done | — |
| Active quests (3) | ✅ Done | — |
| Daily login rewards | ✅ Done | — |
| Daily challenges + streak | ✅ Done | — |
| Timed rescue requests | ✅ Done | — |
| Weekly family spotlight | ✅ Done | — |
| Shop UI (preview mode) | ✅ Done | — |
| StoreKit 2 scaffold | ✅ Done | — |
| Game state persistence | ✅ Done | — |
| 15 families × 15 stages | ❌ Not built | 🟠 V2.0 |
| 5-era visual treatment | ❌ Not built | 🟠 V2.0 |
| Family unlock progression | ❌ Not built | 🟠 V2.0 |
| Sub-object spawning chains | ❌ Not built | 🟠 V2.0 |
| Consumable reward system | ❌ Not built | 🟠 V2.0 |
| 3-tab inventory | ❌ Not built | 🟠 V2.0 |
| Family Superpowers (15 abilities) | ❌ Not built | 🟠 V2.0 |
| Active Superpower UI strip | ❌ Not built | 🟠 V2.0 |
| Tutorial / onboarding | ❌ Not built | 🔴 Critical |
| App icon | ❌ Not built | 🔴 Critical |
| Privacy manifest | ❌ Not built | 🔴 Critical |
| StoreKit config file | ❌ Not built | 🔴 Critical |
| Sound effects | ❌ Not built | 🟡 High |
| Haptic feedback | ❌ Not built | 🟡 High |
| Push notifications | ❌ Not built | 🟡 High |
| Legendary milestone rewards | ❌ Not built | 🟡 High |
| Rewarded ads | ❌ Not built | 🟡 High |
| iCloud KVS sync (Xcode capability) | ❌ Not built | 🟡 High |
| Player level / XP | ❌ Not built | 🟢 Post-launch |
| Animal encyclopedia | ❌ Not built | 🟢 Post-launch |
| Sanctuary Collection gallery | ❌ Not built | 🟢 Post-launch |
| Seasonal events | ❌ Not built | 🟢 Post-launch |
| Friend system | ❌ Not built | 🟢 Post-launch |
| CloudKit sync | ❌ Not built | 🟢 Post-launch |
| iPad layout | ❌ Not built | 🟢 Post-launch |
| Leaderboard | ❌ Not built | 🟢 Post-launch |
| Map/area expansion | ❌ Not built | 🟢 Post-launch |

---

*This document should be updated each time a major feature is completed or the design changes.*

---

## Section 7: Next Development Phases & Feature Roadmap
*Updated: June 2026 — Based on competitive analysis (Travel Town, Tasty Travels) and current build state*

### 7.1 Competitive Positioning

Travel Town (Magmatic Games, 10M+ downloads) and Tasty Travels (Century Games) establish the benchmark for the merge-2 subgenre. The following summarizes what PawSanctuary should adopt, what it should differentiate from, and the strategic reasoning behind each decision.

**Adopt from Travel Town**

Travel Town's nested chain mechanics are worth emulating: some items require merging products from two different chains (e.g., a Cervid item + a Lagomorph item to create a "Forest Scene" decoration for the map). This creates cross-family interdependency and genuine board pressure that single-chain progression cannot replicate. PawSanctuary's Habitat chain concept in Section 7.7 draws directly from this pattern.

Travel Town's order board with time pressure is already well-mirrored in PawSanctuary's AdoptionBoard. The feature worth reinforcing is visual urgency at the two-minute mark — Travel Town's escalating color and animation at low time remaining increases completion rate. PawSanctuary's timer bar already turns red; adding a pulse animation would close the gap.

Travel Town moved away from "auto-producer only" spawning in 2025, shifting toward energy-gated manual spawners that give players more agency over what they produce. PawSanctuary's current manual kibble-cost spawners are already well-positioned here.

Seasonal map areas — limited-time regions that unlock temporary chains and exclusive cosmetic animals — are a proven Travel Town driver of urgency and replayability. PawSanctuary's Seasonal Events system in Section 7.4 is the direct equivalent.

**Differentiate from Travel Town**

Travel Town uses generic objects (tools, furniture, building materials). PawSanctuary's 15 living animal families with individually named stages create substantially stronger emotional attachment. The "Pup → Primordial" arc for Canines is a character journey; a Travel Town wrench has no equivalent pull. This distinction is the game's core competitive moat and should be preserved and amplified in every design decision.

The sub-object buff system planned for Phases 2–4 (sub-objects that grant Speed Burst, Spawner Refill, Map Supplies, and High-Tier Drop Guarantee) has no direct equivalent in Travel Town. This is a second-order differentiator: it gives players a reason to engage with the spawner economy beyond "tap to get animals."

The Ambassador/milestone system — Junior Rescuer → Animal Friend → Sanctuary Guardian → Legendary Rescuer — creates a player identity layer Travel Town does not have. Titles earned from meaningful achievement drive social sharing and session pride.

**Adopt from Tasty Travels**

Tasty Travels' global community mechanic drives daily engagement beyond solo play. A cooperative sanctuary challenge where players contribute toward a shared weekly goal (e.g., "Rescue 10,000 animals this weekend as a community") creates a reason to log in even when personal goals are met. PawSanctuary's Community Rescue Events concept in Section 7.5 implements this.

Tasty Travels ties cosmetic building unlocks to order completion streaks — completing N orders in a row without skipping unlocks a bonus spawner or cosmetic upgrade. This streak-based retention mechanic is distinct from daily login streaks and rewards sustained active play within a session. It is worth integrating into PawSanctuary's AdoptionBoard flow.

---

### 7.2 Phase 5 — Map Area Expansion (9 Remaining Families)
*(See FEATURE_EXPANSION_PLAN.md Section C for full implementation spec)*

Nine new SanctuaryArea entries unlock the remaining animal families: Ursids, Aquatics (via map area — the milestone path is retired per F.Q4), Amphibians, Marsupials, Primates, Equines, Pachyderms, Bovines, and Cervids. Each area requires a build cost scaled to late-game material tiers and grants a new family spawner on completion.

Each area includes two upgrade tiers that grant UpgradeBonus passives. The three new bonus types required for these areas are: sub-object drop rate increase, pity timer reduction, and power-up duration extension (per F.Q9 decision). These require new fields in the UpgradeBonus struct and corresponding handling in `recalcActiveBonuses()`.

Build cost scaling should create a clear sense of late-game investment: later areas cost higher-tier materials in larger quantities or require a mix of material tiers. The goal is for a player completing Phase 5 to feel they have "built" something substantial, not unlocked content passively.

---

### 7.3 Phase 6 — Superpower System
*(Deferred from Phase 5; see TODO.md and GDD v2.1 Section 6)*

When a family first reaches Era 3 (Stage 7), a unique passive or active ability unlocks for that family. The 15 superpowers are defined in Section 6 of this document. Key strategic notes:

Superpowers create long-term build diversity — they give experienced players a reason to develop all 15 families rather than specializing in the two or three most efficient ones. A player who has unlocked Bovines' Stampede (instant mass-merge of same-stage pairs) has a qualitatively different board management strategy than one who has unlocked Avians' Scout (preview of next two incoming rescues).

The active superpower button strip UI and per-ability cooldown display are the primary engineering challenge in this phase. Each family with an unlocked active ability needs a persistent but non-intrusive button; the strip should collapse when no active abilities are available and expand dynamically as more are unlocked.

---

### 7.4 Seasonal Events System

Implement a `SeasonalEventManager: @Observable` class that loads event configuration from a JSON file bundled with the app (or fetched remotely for live updates without an app release). Four events per year: Spring Rescue, Summer Safari, Autumn Harvest, Winter Warmth.

Each event includes a `SeasonalEvent` model with start and end dates, a temporary 4-tier merge chain featuring a seasonal animal variant (e.g., "Festive Fox" at Christmas, "Lunar Rabbit" for Lunar New Year), a seasonal order board with event-exclusive currency, and a prize track with five reward thresholds.

The seasonal chain should not be permanentized on the main board. It lives in a temporary "Event Board" tab alongside the main board and auto-dismisses when the event ends. Players keep any prizes claimed during the event window, but unclaimed event currency expires with the event.

Implementation notes: the event chain is registered in ContentRegistry only while the event is active. Board tab switching already exists in concept via the InventoryScreen tab pattern — apply the same UI primitive to the board context. `SeasonalEventManager` should expose a published `activeEvent: SeasonalEvent?` that drives tab visibility and event UI injection across the app.

---

### 7.5 Social & Community Layer

**Sanctuary Leaderboard.** A weekly ranking of players by ambassador count, using Game Center leaderboard infrastructure (partially in place via the existing `authenticateGameCenter` path). Resets Sunday midnight. The leaderboard reinforces the Ambassador system as a prestige signal beyond solo play.

**Community Rescue Events.** Time-limited cooperative goals where each player contributes their ambassador completions during an event window (e.g., "Rescue 10,000 animals as a community this weekend"). Community milestone rewards are granted to all participants at thresholds of 25%, 50%, 75%, and 100% of the goal. This mechanic drives log-ins even when a player's personal kibble is depleted — contributing to a community goal feels meaningful regardless of session intensity.

**Friend Gifting.** Send one free kibble gift per day to each Game Center friend. Receiving a gift adds 5 kibble (below the energy cap threshold so it never fully refills). Uses the existing InviteSystem infrastructure for friend discovery. The 5-kibble gift amount is intentionally small — enough to feel generous without replacing IAP.

---

### 7.6 Three-Tab Inventory (GDD v2.0 Implementation)

The three-tab inventory is defined in GDD v2.0 but not yet coded. The current implementation uses a single `InventoryStore` with visual tabs that share the same slot pool.

The coded implementation should produce three genuinely separate slot pools:

**Tab 1 — Sanctuary Animals** holds the current animal inventory (18 base slots with unlockable rows). This is the primary merge staging area.

**Tab 2 — Spawners** holds sub-object chain items in transit between the board and merging. 6 base slots, unlockable with Dog Tags per the existing economy design.

**Tab 3 — Building Supplies** is the "limitless" materials tab decided in F.Q6. Materials are displayed as counts by tier rather than individual item slots (e.g., "Wood Tier 3: 7"). Two materials of the same tier auto-merge into the next tier when both are present. There is no slot cap — the tab accumulates indefinitely, with display paging if the count of distinct tiers grows large.

The limitless Tab 3 design eliminates the board-clogging problem of building materials appearing as individual items and removes a major player frustration in the current build.

---

### 7.7 Nested Chain Mechanic (Travel Town Inspiration)

Introduce three "Habitat" chains — one per biome — that require combining high-tier animals from two different families. Completing a Habitat chain grants a permanent passive bonus and a map decoration that signals mastery to the player.

**Forest Habitat:** Merge any Cervid (tier 5+) with any Ursid (tier 5+) → Forest Scene Tier 1. Continue merging Forest Scene items through Tier 4. Completion: permanent +10% kibble regen for both Cervids and Ursids, plus a Forest Clearing decoration placed on the sanctuary map.

**Ocean Habitat:** Merge any Aquatics (tier 5+) with any Amphibian (tier 5+) → Ocean Scene Tier 1 through Tier 4. Completion: permanent +10% kibble regen for both families, plus a Tide Pool decoration.

**Savanna Habitat:** Merge any Bovine (tier 5+) with any Equine (tier 5+) → Savanna Scene Tier 1 through Tier 4. Completion: permanent +10% kibble regen for both families, plus a Watering Hole decoration.

Habitat chains create late-game goals that extend meaningfully beyond Ambassador progression. A player who has completed all 15 family ambassador chains still has three Habitat chains to pursue, each requiring investment in two families simultaneously. The permanent kibble regen bonuses make completing Habitat chains a meaningful economic upgrade rather than a purely cosmetic achievement.

Implementation note: Habitat chains use the same `BoardItem(chainID, tier)` model as all other chains, with chainIDs like `"habitat.forest"`, `"habitat.ocean"`, `"habitat.savanna"`. The cross-family merge input is the only new mechanic: `attemptMergeOrMove` needs a new branch that detects two items from different chain families when both meet a minimum tier threshold and produces the corresponding Habitat Tier 1 item.

---

### 7.8 Board Size Correction

**The correct board size is 9×7 = 63 cells.** GDD v2.0 and v2.1 incorrectly stated 6×5 = 30 cells throughout Sections 3, 8, and the Feature Status Tracker. The implementation is correct. This note supersedes all prior GDD references to board dimensions.

The Feature Expansion Plan (Section A and F.Q10) confirmed this discrepancy in June 2026. The board's two locked rows (rows 7 and 8) unlock at player levels 3 and 8 respectively. All references to "30 cells" or "6×5" in earlier sections of this document are superseded by 63 cells / 9×7.
