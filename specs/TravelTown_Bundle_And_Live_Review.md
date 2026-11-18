# Travel Town — bundle and live-play review

**Status: findings only. No PawSanctuary code was read or changed for this document.** It covers steps 1–3 of the review plan (existing spec, readable bundle contents, live observation). The architecture comparison against PawSanctuary's code (step 4) is not done.

Companion to `Spec_TravelTownReview_Draft.md`, which analysed a screen recording. This document adds what the installed app's readable files and a live session show.

## 0. Scope, method and limits

- **App:** Travel Town - Merge Adventure, `io.randomco.travel`, version 2.12.1831 (build 91560), Unity 2022.3.62f2, iOS 18.0+. Installed at `/Applications/TravelTown.app` (iPhone/iPad app running on Apple Silicon).
- **Read, not modified:** `Info.plist`, `ScriptingAssemblies.json`, the Addressables catalog, the localisation and configuration asset bundles, and `global-metadata.dat` (string table only).
- **Not done, by choice:** the main executable and `UnityFramework` are FairPlay-encrypted (`cryptid 1`). No decryption was attempted. Game logic was therefore not read; everything below about code structure is inferred from assembly names and shipped data.
- **Live session:** an existing save at player level 56. Terms of Service were accepted by the user, not by Claude. No purchases were made; no friends were invited; the Travel Pass "give up" prompt was left to the user.
- **Caveat on all live observations:** one account, one session, one day. Offers, events and A/B variants are per-player and time-limited.
- **EULA:** mobile EULAs commonly restrict reverse engineering. This is analysis for comparison only. Do not reuse their assets, strings or code.

## 1. Client architecture (from the assembly list)

255 assemblies ship in `ScriptingAssemblies.json`. The non-Unity ones show the stack:

| Concern | Evidence | Notes |
|---|---|---|
| Runtime | Unity 2022.3, IL2CPP (`global-metadata.dat` present) | Not obfuscated: standard metadata header |
| Dependency injection | `Zenject` | Plus `Strange` (an MVCS framework) and a `Common.StateMachine` assembly |
| Content delivery | Unity Addressables, 1,222 catalog entries, `RemoteContentConfig`, `Merger.RemoteContentManager.Interfaces` | Bundles: board, configuration, localisation, overlays, smilies, sprite atlases, tutorial, UI, live-ops events |
| Live-ops scripting | `ScriptLiveOp.Runtime`, `ScriptedLiveOps`, `com.tencent.puerts.quickjs` | A JavaScript engine (puerts/QuickJS) is embedded; live events appear to be scriptable without a client release. Inferred from names; not confirmed |
| Config serialisation | `Sirenix.Serialization` (Odin), `DysonCore.DynamicJson` | Economy and tutorial configs are Odin-serialised ScriptableObjects in the configuration bundle |
| Authoring graph | `ParadoxNotion.NodeCanvas`, `AnimationGraph*` | Tutorials and animations driven by graph assets |
| Tweening / FX | `DOTween`, `Coffee.UIParticle`, `Lofelt.NiceVibrations` | Haptics via Lofelt |
| Possible ECS | `TravelTown.ECSInstance` | Name only; unconfirmed what it holds |
| Shared framework | `MoonActive.*` namespaces (Telemetry, Keychain, Scenario, ConditionalOutcomes, MoonInput, AgeVerification) | Shared publisher framework layer |
| Telemetry / A-B | `Metrics`, Coralogix, Firebase Remote Config, `ab-tests.asset` | Two energy A/B configs ship in this build |
| Ads / attribution | AppLovin, IronSource, Moloco, Unity Ads, Vungle, FAN, AppsFlyer | |

### Feature modules (`TravelTown.*`)

Board: `MergeBoard`, `MergeBoardQueue`, `MergeBoardInfoBar`, `MergeBoardSellItemCapability`, `MergeBoardSkipCooldownCapability`, `MergeBoardUnlockChestCapability`, `ChainBar`, `ResourceGenerator`, `ItemCollection`, `ItemToOrderRelation`, `RewardOnBlocker`, `PowerBoost`, `ProducerExcitement`.

Orders and rewards: `GenericOrderRush`, `Cloche`, `SmiliesFeature`, `SmiliesExtraBonus`, `RewardsCalendar`, `TimeLimitedItems`, `Achievements` (plus `AchievementsOffer`, `AchievementsMultilaneOffer`, `AchievementsSkinnable`).

Events: `TournamentEvent`, `TownFair`, `GoldenPassEvent`, `PuzzlePaintsEvent`, `BoardMiniGameEvent`, `HiddenGameEvent`, `Meteor`, `TravelTogether`, `Expedition`.

Meta and shell: `Main`, `Installers`, `MoonShop`, `Vod`, `SayHello`, `BuildingUpgradeUX`, `ScheduledTimers`, `IconsCenter`.

**Pattern worth noting:** board behaviours are small "Capability" assemblies (sell, skip-cooldown, unlock-chest), and each event or reward feature is its own assembly. Compare against how PawSanctuary splits board behaviour from feature surfaces in step 4.

## 2. Data shipped in the bundle

### Energy (two A/B variants, identical in this build)

`ResourceConfig_AbTest_energy_2.11` and `ResourceConfig_AbTest_energy_fill_120_sec` both define regeneration of **1 unit per 120 s, max 100**, for two resources (id 1 = Energy, id 5 unnamed here, same rule). Treat the interval as the shipped default, not a verified live rate: no regen countdown was timed in this session.

Observed live: the energy balance reached **914**. Rewards and claims push the balance above the regen cap of 100, so the cap limits regeneration, not holdings. Whether PawSanctuary's `kibbleRegenSecs` cap behaves the same way is a step 4 check.

### Resource definitions

Six currencies are defined: XP, Energy, a hard currency ("HC"/diamond), a soft currency ("SC"/coin), Event XP, and a second energy-like resource. Item graph ids: `resource-xp`, `resource-energy`, `resource-diamond`, `resource-coin`.

### Merge-chain ids shipped as "builtin"

Chain art folders include: `sea-shell` (15 tiers, `_00`–`_14`), `resource-diamond` / `resource-energy` / `resource-smiley` (5 tiers each), `sand-castle` (5), `bucket` (9), `chest-energy` variants (daily, first-session, mid-session, retention), `time-twister`, `booster-order-box`, and several boosters. The starfish is **tier 5 of the `sea-shell` chain**, and the "smiley" chain is a separate 5-tier resource. So the starfish currency is a board item chain, not a bare counter.

### Tutorials (names only)

About 60 tutorial graphs ship, including a numbered onboarding series `BotG_00`–`BotG_17` (merging and producer, board queue, merge producers, second producer, store unlocked, item communication, joker, energy crate, secondary producer, bubbled item, tool, coin collect) and feature tutorials (power boost, cards, pets, town fair, puzzle paints, flame cards, vanity, inventory, sell, stacking, no-energy, prevent order requirement overshoot). The requirement vocabulary in a tutorial config includes triggers such as `NoEnergyLeft`, `BoardIsFull`, `HasBubbledItemsOnBoard`, `CanOvershootOrderRequirement`, `OrderCountCompleted`, `HasNoMergableItemsOnBoard`.

### Characters

17 order characters are configured (`AvailableOrderCharacters`). Order requests come from a named character, as in your `AdoptionFamily`.

### Localisation

16 languages. English strings were read only to identify feature names and UI wording; story text was not reproduced here.

## 3. Live observations

### 3.1 Board and HUD (player level 56)

- **Board:** 7 columns × 9 rows. Producers carry a small lightning-bolt badge.
- **Header:** energy, coins, gems, player level badge, shop button, and a "1+4" offer badge with a countdown.
- **Top band:** three order cards above the board, each with a character portrait. A left column holds task tiles: weekly goals (0/8), starfish bar (2/12), a character event (5d 7h), and a bell/Cloche track (13h 47m).
- **Selecting an item:** corner brackets plus an info bar. The lowest-tier grape showed "Grape. Merge to reach next level." with a **trash** icon; after merging, the next tier showed a **$ sell** icon. One pair observed, so treat as a hint, not a rule.
- **Merge:** dragging one grape onto another produced the next tier at the target cell with a sparkle. **No energy was spent**; energy stayed 914. Merging counts toward "Merge Items" quests.

### 3.2 Order card payout (observed on all three visible orders)

Each order card shows several reward stacks before completion:

| Card | Shown rewards |
|---|---|
| Order 1 | energy +100, coins +4,900, starfish +2, a yarn-ball token +8, a spade-hexagon token +85, tournament ball 25, a 1h 48m timer |
| Order 2 (highlighted, special) | a spade-hexagon token +50, toolbox +2, starfish +1, yarn-ball token +5, tournament ball 11 |
| Order 3 | a spade-hexagon token +65, coins +3,600, starfish +1, yarn-ball token +6, tournament ball 11 |

This matches the spec's "orders pay five currencies" finding and adds the **tournament ball** as another per-order payout. Each card asks for 1–2 items (tiers were not inspected). Order completion itself was not triggered, so flight animations were not re-observed.

### 3.3 The post-login popup queue

Opening the app on an idle save produced about **24 consecutive screens** before the board was usable. They fall into the 11 stages below (stage 11 groups eight screens):

1. Terms of Service (first run, user-accepted)
2. Daily Rewards (day 8 of a 30-day ladder with chest nodes at 8 / 15 / 22 / 30)
3. Weekly Goals ended: claim 15 energy
4. "Crazy Offer 1+4 Free": a $6.99 bundle that unlocks four free items
5. Event Collection ended: claim 20 energy
6. Van Voyage event ended: claim energy, gems and coins
7. "Super Skydive Pack" $1.99, limit 1
8. Invite Friends (50 energy per friend reaching level 6)
9. Weekly Goals (new week)
10. Travel Pass ended, with a $4.99 "VIP pass" upsell, then a "Last chance, give up earned rewards?" step
11. Town Tournament intro, Dress Up Dash intro, Room Rush with Summer intro, Stamp Card, Daily Challenge, Fantasy Island intro, Order Rave (Cloche), new Travel Pass

About a quarter were reward claims for ended events, and about five were purchase offers or purchase-driven loyalty screens. Several interrupts had no close button, only a forward button.

### 3.4 Live-ops features seen

| Feature | What was visible |
|---|---|
| **Weekly Goals** | 7-day tab strip. Five tasks (login 2 days, collect starfish 0/10, merge items 0/650, collect tournament points 0/250, create item 0/40) each pay points plus an item; points fill a 100-point track with reward nodes and a 100-gem top prize |
| **Daily Challenge** | 8 tasks (e.g. merge 140 items, spend 5 gems, collect 3,000 / 6,000 coins) fill a bar to a grand-prize chest |
| **Town Tournament** | Ranked leaderboard of 5+ entries, volleyball points, top 3 earn an item pack, energy and a chest (200 / 100 / 50 energy), ranks 4–5 energy only; ~7 h timer |
| **Dress Up Dash** | "NEW DROP" event: complete special orders, drag the reward item onto a character, 8 stages, grand prize 125 energy + 15 gems + a mystery box |
| **Room Rush with Summer** | 5-day character event |
| **Fantasy Island** | 12-day event with its own world and entry gateway |
| **Order Rave / Cloche** | Collect coins from orders to earn a currency that upgrades a Cloche through bronze / silver / gold tiers at 850, 12.5K, 28K and 56.5K; upgrading makes the board spawn better items; the boost ends when the timer ends (13 h 49 m) |
| **Travel Pass** | Two-column pass (free left, locked VIP right) driven by a key currency (0/80), 9 d 7 h. A forced tutorial pointed at VIP "Activate" and only showed a Skip button after pressing Escape |
| **Stamp Card** | Stamps are earned by purchasing any offer; three stamps pay 50 energy, a ticket and a mystery box |

## 4. Answers to open questions in `Spec_TravelTownReview_Draft.md` §6

1. **What does the 12-starfish bar pay?** Still unobserved. This session showed the bar at 2/12 and confirmed starfish also count toward a weekly task ("collect 10"), but not what a full bar pays.
2. **Are bells a tier series or milestone tokens?** **Resolved:** they are the Cloche tiers of the Order Rave feature (bronze / silver / gold bells at ~12.5K / 28K / 56.5K coin points), and the reward for upgrading is a temporary better-items boost, not just a ladder item.
3. **What are the red-ticket and purple-earring event currencies?** Not resolved. This session saw a yarn-ball token (consistent with the craft-room Room Rush event, inferred from theme only) and a spade-hexagon token whose purpose was not identified. The tournament ball is confirmed as the Town Tournament currency.
4. **Task-rail redesign:** not applicable to this review.

## 5. Not done

- Decompiling game logic (encrypted; deliberately not attempted).
- Completing an order, spending energy at a producer, or filling the starfish bar, so payout animations and the starfish reward are unobserved.
- Opening the Cloche, Fantasy Island, Town Fair or pets screens beyond their intro popups.
- Reading economy balance tables (order requirement curves, producer cooldowns, chain spawn weights). These likely live in remote content, not in the installed bundle.
- Any comparison against PawSanctuary's code.

## 6. Suggested next steps

1. Step 4: a gap analysis mapping the module inventory in §1 and the features in §3.4 onto PawSanctuary's code, starting with board capabilities, event/reward surfaces and the popup scheduler.
2. A follow-up live session that completes one order and one starfish cycle to close §4 items 1 and 3.
3. If the popup-queue behaviour matters for PawSanctuary, record its order and gating (what interrupts a returning player, and how many) in a separate short spec.
