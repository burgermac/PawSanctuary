# Paw Sanctuary — Game Design Document
**Version 1.0 | June 2026**

---

## Table of Contents
1. [Game Overview](#1-game-overview)
2. [Core Loop](#2-core-loop)
3. [Board & Merge System](#3-board--merge-system)
4. [Animal System](#4-animal-system)
5. [Economy & Currencies](#5-economy--currencies)
6. [Progression Systems](#6-progression-systems)
7. [Engagement Systems](#7-engagement-systems)
8. [Inventory System](#8-inventory-system)
9. [Monetization](#9-monetization)
10. [Content Roadmap](#10-content-roadmap)
11. [Technical Architecture](#11-technical-architecture)
12. [Missing Features (Build Priority)](#12-missing-features-build-priority)
13. [Feature Status Tracker](#13-feature-status-tracker)

---

## 1. Game Overview

**Genre:** Merge puzzle / idle casual  
**Platform:** iOS (iPhone primary, iPad secondary)  
**Audience:** Casual mobile gamers, animal lovers, ages 18–45  
**Monetization model:** Free-to-play with IAP and optional subscription  
**Comparable titles:** Travel Town, Tasty Travels, Merge Mansion  
**Differentiator:** Better value per dollar than competitors; pet rescue theme with emotional resonance

### Elevator Pitch
Players run an animal sanctuary, rescuing stray animals and merging them through care stages — from Stray to Sanctuary Star. The board fills up, strategy matters, and a rich set of daily and weekly systems keep players coming back. Purchases feel fair, not predatory.

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
  → Merge matching animals
  → Advance rescue stages
  → Complete daily challenges / active quests
  → Claim rewards (Kibble + Dog Tags)
  → Store excess animals in inventory
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

### Progression Loop (weeks)
```
Unlock board cells (every 3 merges)
Unlock inventory rows (Dog Tags)
Complete harder quest tiers
Reach Sanctuary Star milestones
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
| Same species + same stage | Merge → next stage |
| Different species OR different stage | Swap positions |
| Source → empty cell | Move |
| Drag off bottom of board | Send to inventory |

### Spawn Rules
- **Player-triggered rescue:** costs 1 Kibble, spawns a random Stray in any empty unlocked cell
- **Auto-spawn after merge:** free, spawns immediately after every successful merge
- **Board full:** rescue button disabled; hint encourages storing items in inventory
- **Species distribution:** fully random; no weighting toward needed species (future feature: weighted spawns)

### Future Board Features (planned)
- Special cells: golden cells that give 2× score on any merge performed there
- Obstacle cells: locked debris that must be cleared by merging adjacent animals
- Sanctuary zones: dedicated display area for Sanctuary Stars (removed from play board)

---

## 4. Animal System

### Species (8 total)
| Species | Emoji | Notes |
|---|---|---|
| Dog | 🐕 | |
| Cat | 🐈 | |
| Rabbit | 🐇 | |
| Bird | 🐦 | |
| Hamster | 🐹 | |
| Turtle | 🐢 | |
| Fox | 🦊 | |
| Owl | 🦉 | |

### Rescue Stages (5 per species)
| Stage | Label | Color | Score Multiplier |
|---|---|---|---|
| 1 | Stray | Gray | 25pts |
| 2 | Rescued | Orange | 50pts |
| 3 | Groomed | Blue | 75pts |
| 4 | Adopted | Green | 100pts |
| 5 | Sanctuary Star | Yellow | 125pts |

**Stage visual rules:**
- Stray: desaturated (grayscale 60%)
- Rescued–Adopted: full color species emoji
- Sanctuary Star: ⭐ replaces emoji; removed to Sanctuary collection (future)
- Weekly spotlight species: golden border on board cells

### Future Animal Features (planned)
- **Rare species:** unlockable via Dog Tags or seasonal events (e.g., 🦁 Lion, 🐼 Panda)
- **Special abilities:** certain species trigger bonus events (e.g., Dogs occasionally bring a free rescue)
- **Animal encyclopedia:** collectibles screen showing all species/stages discovered
- **Sanctuary display:** gallery of all Sanctuary Stars earned

---

## 5. Economy & Currencies

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
- Inventory Row 2 unlock: 10 tags
- Inventory Row 3 unlock: 25 tags
- Instant Kibble refill (future): 5 tags → full refill
- Skip rescue request timer (future): 3 tags
- Unlock specific species spawn (future): 8 tags

### Economy Balance Principles
- A free player should never feel stuck — daily login + quest rewards provide steady Kibble
- Dog Tags should feel earned, not required — core gameplay never requires spending them
- IAP should feel like a genuine value upgrade, not a paywall
- Per-unit Kibble cost should be 30–40% cheaper than Travel Town equivalent

---

## 6. Progression Systems

### Cell Unlock Progression
```
Merges 1–3:   Unlock cell (row 1, col 0)
Merges 4–6:   Unlock cell (row 1, col 1)
...
Merges 13–15: Unlock cell (row 0, col 4)
Total: 30 merges to unlock all 10 locked cells
```
Progress bar with "X more merges" hint keeps player informed.

### Score Progression
- Score = stage.rawValue × 25 × spotlight_multiplier
- Weekly spotlight gives 2× score on featured species
- Score displayed in bottom bar; no leaderboard yet (future feature)
- Score resets per session (future: persistent lifetime score / leaderboard)

### Player Level (not yet built — planned)
- XP earned from merges, quest completion, and login streaks
- Level ups unlock cosmetic rewards: board themes, animal name tags, emojis
- No hard gating behind levels — purely cosmetic progression

### Sanctuary Star Milestones (not yet built — planned)
```
5 Stars:   Title "Junior Rescuer" + 10 Kibble bonus
15 Stars:  Title "Animal Friend" + 5 Dog Tags
30 Stars:  Title "Sanctuary Guardian" + free inventory row
50 Stars:  Title "Legendary Rescuer" + exclusive rare species unlock
```

---

## 7. Engagement Systems

### 7.1 Daily Login Reward ("Morning Feeding")
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

### 7.2 Daily Challenges ("Daily Shelter Tasks")
- 3 challenges per day: 1 Easy, 1 Medium, 1 Hard
- Reset at midnight (local time)
- Completing all 3 awards: +10 Kibble, +2 Dog Tags
- 7-day completion streak: +30 Kibble, +8 Dog Tags
- Streak resets if all 3 not completed in a day

**Challenge pool by difficulty:**
| Difficulty | Example Goals |
|---|---|
| Easy | Merge 3 animals; Rescue 4 strays; Merge 2 [species] |
| Medium | Merge 6 animals; Get 1 animal to Groomed; Rescue 8 strays |
| Hard | Get 1 animal to Adopted; Merge 10 animals; Rescue 12 strays |

### 7.3 Active Quests
- 3 active at all times; manually claimed
- Replaced immediately on claim
- Difficulty weighted: 50% Easy, 30% Medium, 20% Hard
- Rewards scale with difficulty (Kibble + Dog Tags)

**Quest goal types:**
- Merge any X animals
- Merge X of a specific species
- Get X animals to a specific stage
- Rescue X strays

### 7.4 Timed Rescue Requests ("Urgent Requests")
- 2 active at all times
- 10-minute countdown per request
- Auto-claimed on completion (bonus awarded immediately)
- Replaced automatically on expiry
- Timer bar turns red in final 2 minutes
- Bonus: 5–10 Kibble + 1–3 Dog Tags on completion

### 7.5 Weekly Species Spotlight
- Featured species rotates by calendar week (8 species = 8-week cycle)
- 2× score for all merges of that species
- Weekly milestone: merge 10 spotlight animals → +20 Kibble, +5 Dog Tags
- Golden border shown on board cells containing spotlight species
- Compact banner displayed below currency bar
- Progress resets Monday midnight

### 7.6 Push Notifications (not yet built — planned)
| Trigger | Message |
|---|---|
| Kibble full | "Your Kibble bag is full! Come rescue some animals." |
| Daily challenge reset | "New daily challenges are ready at the sanctuary!" |
| Rescue request expiring | "Your rescue request expires in 2 minutes!" |
| Login streak at risk | "Don't break your streak! Log in before midnight." |
| Weekly spotlight change | "New spotlight animal this week: [emoji] [Name]!" |

### 7.7 Seasonal Events (not yet built — planned)
- 4 events per year (Spring Rescue, Summer Safari, Autumn Harvest, Winter Warmth)
- Duration: 7 days
- Exclusive rare species available only during event
- Event currency earned through special merges; spent on exclusive rewards
- Leaderboard showing top rescuers during event window

---

## 8. Inventory System

### Configuration
| Row | Slots | Cost | Status |
|---|---|---|---|
| Row 1 | 6 | Free | Always unlocked |
| Row 2 | 6 | 10 Dog Tags | Purchasable |
| Row 3 | 6 | 25 Dog Tags | Requires Row 2 first |
| **Total** | **18** | | |

### Interaction Model
- **Store from board:** tap animal → tap "Store Selected" button
- **Store via drag:** drag animal off bottom of board → auto-routes to first empty slot
- **Retrieve to board:** open inventory → tap animal → "Place on Board" → placed in first empty cell → returns to game view
- **Rearrange inventory:** tap slot → tap another slot → swap
- **Inventory full:** "Inventory Full" toast for 3 seconds
- **Board full:** "Board is Full" toast for 3 seconds

### Future Inventory Features (planned)
- Drag-and-drop directly from inventory to board cell (bypasses "Place on Board" step)
- Sort inventory by species or stage
- Favorite/pin slots to prevent accidental overwriting
- Inventory expansion via IAP (additional rows beyond 3)

---

## 9. Monetization

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

## 10. Content Roadmap

### Phase 1 — Foundation (Current)
- [x] 6×5 merge board with drag/drop
- [x] 8 species × 5 stages
- [x] Kibble + Dog Tag economy
- [x] Cell unlock progression
- [x] Active quest system (3 quests)
- [x] Daily login rewards
- [x] Daily challenges with streak
- [x] Timed rescue requests
- [x] Weekly spotlight
- [x] Inventory (18 slots, tiered unlock)
- [x] IAP scaffold (StoreKit 2)
- [x] Shop UI (preview mode)
- [ ] Game state persistence
- [ ] Tutorial / onboarding
- [ ] Sound effects + haptics

### Phase 2 — Polish (Next)
- [ ] SwiftData persistence (board, inventory, currencies, quests)
- [ ] Push notifications (6 triggers)
- [ ] StoreKit configuration file (enable Simulator testing)
- [ ] Onboarding flow (first 5 minutes)
- [ ] Haptic feedback on merge, unlock, reward
- [ ] Sound effects (merge, rescue, reward, UI)
- [ ] App icon + launch screen
- [ ] Privacy policy + terms (required for App Store)
- [ ] AI disclosure statement (App Store requirement)

### Phase 3 — Expansion (Post-launch)
- [ ] Sanctuary Stars collection screen
- [ ] Player level system (XP + cosmetic rewards)
- [ ] Sanctuary Star milestones
- [ ] Rare/exclusive species (Lion, Panda, Dolphin, etc.)
- [ ] Rewarded ads integration
- [ ] Push notification system
- [ ] Board themes (cosmetic)
- [ ] Animal encyclopedia / collection log
- [ ] Score leaderboard

### Phase 4 — Live Ops (3+ months post-launch)
- [ ] Seasonal events (4/year)
- [ ] Limited-time species
- [ ] Event leaderboards
- [ ] Friend system (view friend sanctuaries)
- [ ] CloudKit sync (cross-device)
- [ ] iPad layout
- [ ] Localization (Spanish, French, German)

---

## 11. Technical Architecture

### Current State
- **Single file:** ~1,900 lines in PawSanctuary.swift
- **Pattern:** MVVM (Model-View-ViewModel)
- **UI framework:** SwiftUI
- **IAP:** StoreKit 2
- **Persistence:** UserDefaults (login streak, daily challenges, spotlight — partial)
- **No persistence:** board state, inventory, currencies, quest progress

### Target File Structure (refactor needed)
```
PawSanctuary/
├── App/
│   └── PawSanctuaryApp.swift         @main entry point
│
├── Models/
│   ├── AnimalSpecies.swift
│   ├── RescueStage.swift
│   ├── MergeItem.swift
│   ├── BoardCell.swift
│   └── GridPosition.swift
│
├── Quest Models/
│   ├── QuestGoal.swift
│   ├── Quest.swift
│   ├── DailyChallenge.swift
│   └── RescueRequest.swift
│
├── ViewModels/
│   ├── MergeBoardViewModel.swift      core game logic
│   ├── QuestViewModel.swift           quest + challenge logic
│   ├── InventoryViewModel.swift       inventory management
│   └── EngagementViewModel.swift      login, spotlight, requests
│
├── Managers/
│   ├── StoreManager.swift             StoreKit 2
│   ├── PersistenceManager.swift       SwiftData
│   ├── NotificationManager.swift      push notifications
│   └── HapticManager.swift            haptics
│
├── Views/
│   ├── Game/
│   │   ├── MergeBoardView.swift
│   │   ├── CellView.swift
│   │   └── BottomBarView.swift
│   ├── Quests/
│   │   ├── QuestCardView.swift
│   │   ├── DailyChallengePanelView.swift
│   │   └── RescueRequestPanelView.swift
│   ├── Engagement/
│   │   ├── LoginRewardView.swift
│   │   └── SpotlightBannerView.swift
│   ├── Inventory/
│   │   ├── InventoryScreenView.swift
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

### Persistence Strategy (SwiftData — to implement)
```
@Model class SavedGameState
  - board: [[BoardCellData]]
  - inventory: [MergeItemData?]
  - kibble: Int
  - dogTags: Int
  - score: Int
  - mergeCount: Int
  - sanctuaryStars: Int
  - rescueCount: Int
  - inventoryRow1Unlocked: Bool
  - inventoryRow2Unlocked: Bool
  - activeQuests: [QuestData]
  - lastSaved: Date
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

## 12. Missing Features (Build Priority)

These are ordered by impact and dependency:

### 🔴 Critical (required before shipping)
1. **Game state persistence** — board and inventory reset on close; biggest UX problem
2. **Tutorial / onboarding** — new users have no guidance; kills retention
3. **App icon + launch screen** — required for App Store submission
4. **Privacy manifest** — required for App Store submission since iOS 17.5
5. **StoreKit config file** — needed to test IAP in Simulator

### 🟡 High Priority (ship soon after launch)
6. **iCloud KVS sync** — entitlement already provisioned in code; activate via Xcode → target → Signing & Capabilities → + Capability → iCloud → check "Key-value storage"
7. **Sound effects** — merge, rescue, reward, UI taps
8. **Haptic feedback** — merge success, unlock, reward claim
9. **Push notifications** — Kibble refill, daily challenge, streak at risk
10. **Sanctuary Star milestone rewards** — completing the 5-stage loop needs a payoff
11. **Rewarded ads** — meaningful free-to-play retention tool

### 🟢 Nice to Have (post-launch)
11. Player level + XP system
12. Animal encyclopedia / collection screen
13. Board cell themes (cosmetic)
14. Sanctuary Stars display/gallery
15. Friend system
16. Seasonal events
17. CloudKit cross-device sync
18. iPad layout optimization
19. Localization

---

## 13. Feature Status Tracker

| Feature | Status | Priority |
|---|---|---|
| Merge board (6×5) | ✅ Done | — |
| Drag and drop | ✅ Done | — |
| Swap on non-match | ✅ Done | — |
| Cell unlock (every 3 merges) | ✅ Done | — |
| 8 species × 5 stages | ✅ Done | — |
| Kibble regen (1/min, cap 100) | ✅ Done | — |
| Dog Tags currency | ✅ Done | — |
| Active quests (3) | ✅ Done | — |
| Daily login rewards | ✅ Done | — |
| Daily challenges + streak | ✅ Done | — |
| Timed rescue requests | ✅ Done | — |
| Weekly species spotlight | ✅ Done | — |
| Inventory (18 slots, tiered) | ✅ Done | — |
| Shop UI (preview mode) | ✅ Done | — |
| StoreKit 2 scaffold | ✅ Done | — |
| Game state persistence | ✅ Done | — |
| iCloud KVS sync (Xcode capability) | ❌ Not built | 🟡 High |
| Tutorial / onboarding | ❌ Not built | 🔴 Critical |
| App icon | ❌ Not built | 🔴 Critical |
| Privacy manifest | ❌ Not built | 🔴 Critical |
| StoreKit config file | ❌ Not built | 🔴 Critical |
| Sound effects | ❌ Not built | 🟡 High |
| Haptic feedback | ❌ Not built | 🟡 High |
| Push notifications | ❌ Not built | 🟡 High |
| Sanctuary Star milestones | ❌ Not built | 🟡 High |
| Rewarded ads | ❌ Not built | 🟡 High |
| Player level / XP | ❌ Not built | 🟢 Post-launch |
| Animal encyclopedia | ❌ Not built | 🟢 Post-launch |
| Seasonal events | ❌ Not built | 🟢 Post-launch |
| Friend system | ❌ Not built | 🟢 Post-launch |
| CloudKit sync | ❌ Not built | 🟢 Post-launch |
| iPad layout | ❌ Not built | 🟢 Post-launch |
| Leaderboard | ❌ Not built | 🟢 Post-launch |

---

*This document should be updated each time a major feature is completed or the design changes.*
