# Gossip Harbor — bundle and live review

**Status: findings only. No PawSanctuary code was read or changed.** Covers steps 1–3 for Gossip Harbor (existing analysis, readable bundle contents, live observation). The three-way comparison against Travel Town and PawSanctuary's code is not done.

Companions: `TravelTown_Bundle_And_Live_Review.md` (same method, same session), and the July FTUE analysis `FTUE_Analysis_GossipHarbor.md` (v3.94.5, six screen recordings, kept outside this repo at `~/Documents/Claude/Claude Code/`).

## 0. Scope, method and limits

- **App:** Gossip Harbor®: Merge & Story, `com.mergegame.icookie`, version **4.12.0** (build 187), Unity 2022.3.62f2, iOS 18.0+. The July analysis measured **3.94.5**, so the installed build is about eight minor versions newer. Namespaces such as `com.microfun.*` match the publisher named in that analysis (Microfun).
- **Read, not modified:** `Info.plist`, `ScriptingAssemblies.json`, the Addressables catalog (21,865 entries), the English text bundle (12,932 strings), and the `dataconfig` bundle.
- **Not read, by choice:**
  - The main executable and `UnityFramework` are FairPlay-encrypted (`cryptid 1`).
  - **Game logic ships as Lua**, in five bundles (`lua_core`, `lua_activity`, `lua_config`, `lua_base`, `lua_test`, about 13 MB in total). Their contents are not plain Lua source or a standard Lua bytecode header; they look packed or obfuscated. That is the developer's own protection, so no unpacking was attempted. Everything about how the game *works* below therefore comes from asset names, strings and observed play, not from logic.
- **Live session:** a **fresh guest profile** on this Mac (level 1, no prior progress), played across two sittings (about 13 minutes of wall time, roughly 5 minutes of actual play) through the opening, the tutorial and the first two orders. The session never reached level 2. Input was driven by mouse automation, and keyboard focus slipped to the Claude app twice mid-batch, which cost several inputs. No terms-of-service, age or purchase prompt appeared in that window, so none were accepted or declined. A "Recover Progress" button was visible and was not touched. No purchases.
- **Caveat on all live observations:** one new profile, first four minutes only. Nothing past the tutorial was seen, so mid-game systems (events, popups, offers) are inferred from asset names, not observed.
- **EULA:** mobile EULAs commonly restrict reverse engineering. Analysis for comparison only; do not reuse assets, strings or code.

## 1. Architecture (from the assembly list and Addressables)

101 assemblies ship (Travel Town: 255). The non-Unity ones are few, and the game's own code is concentrated in one assembly:

| Concern | Evidence | Notes |
|---|---|---|
| Runtime | Unity 2022.3.62f2, IL2CPP (`global-metadata.dat`, 10 MB) | Same Unity version as Travel Town |
| Game code | `Assembly-CSharp`, `Assembly-CSharp-firstpass` | Monolithic. No per-feature assemblies like Travel Town's `TravelTown.*` |
| Game logic | **Lua**, shipped as Addressables text blobs | Packed; not read. Separate bundles for core, base, activity (events), config and a test bundle. The `lua_test` bundle ships in the release build |
| Content delivery | Unity Addressables, 21,865 entries, remote path prefix in the catalog | Roughly 18× Travel Town's entry count, dominated by map art (about 9,700 `Map/` entries) and effects (about 3,100) |
| Animation | `spine-unity`, `DOTween`, `com.microfun.ui` | Spine skeletal animation, where Travel Town leans on DOTween and particles |
| Config | `Newtonsoft.Json`, `LitJson`, plus the Lua config bundle | Economy tables are not in readable Unity assets (see §2) |
| Notifications / social | `Unity.Notifications.iOS`, Facebook SDK, `NativeShare` | |
| Ads / attribution | AppLovin MAX, Moloco, AppsFlyer | Far fewer SDK frameworks than Travel Town |
| Dev tooling in build | `Unity.Recorder`, `Unity.MemoryProfiler`, `com.microfun.profiling` | Present in the shipped assembly list |

**Contrast with Travel Town:** Travel Town is a C# game with a DI container, a graph-driven tutorial system and one assembly per feature, and it reads its configuration from Unity assets. Gossip Harbor is closer to a thin Unity shell: heavy asset streaming, Spine animation, and its rules and event logic in downloadable Lua. That split is what lets it stand up many events without an app release, and it also means much less of its economy is inspectable from the bundle.

## 2. What is and isn't readable

| Data | Gossip Harbor | Travel Town |
|---|---|---|
| Energy rules | Not in readable assets (Lua config); measured live instead | In a ScriptableObject (`1 per 120 s, max 100`) |
| Resource definitions | Not in readable assets | Readable (six currencies) |
| Tutorial list | Not readable (Lua / `novicetask` event bundles) | Readable (about 60 graphs) |
| Item and chain names | Readable in English text | Readable (art folders + strings) |
| Asset registries | Readable: `dataconfig` is a set of resource manifests (audio, image, prefab, scene, role, customer, map, UI), not balance tables | n/a |

`dataconfig` holds `MapConfig`, `RoleConfig`, `CustomerConfig`, `SceneConfig`, `SlotBoundsConfig` and `InseasonConfig`. None holds economy numbers.

## 3. Content scale (from the Addressables catalog and English strings)

- **Renovation map:** areas `Area0` through `Area49` (50 areas) under `Map/`. Per-area character prefabs are named by area and character (`area1_lucy`, `area1_norman`, `area2_amala`, …).
- **Story:** about 616 `DynamicConfig/Story` entries and about 305 `DynamicConfig/Timeline` entries, plus story illustrations per area and 20+ character "intimacy" and story string groups (`character_intimacy`: 521 strings, `character_story`: 237).
- **Item names:** 331 numbered `item_####_name` strings plus 9 `item_main_g_*` chain-group names (Piggy Bank, Glimmering Coal, Cracked Nugget, Gold Ore, Ring of Royals, Knightly Goblet, Ancient Amphora, Sterling Songbird, Audacious Stag). Per-chain tier counts are not recoverable from strings alone.
- **Languages:** 10 (en, de, es, fr, it, ko, pt, jp, cn, tw), plus a small patch text file. Travel Town ships 16.
- **Task content:** about 4,360 `task_#` strings, the largest single string group (chores and quests).
- **Events/activities (34 folders with "Activity" in the name):** Advance, Adventure, Album, Battle, Butterfly, CardFactory, Combo, Contiorders, Dash, Dig, ExtraCustomer, Farmboard, FourTasks, GeneratorBoost, Lotto, MainDecor / MainDecorNew, MapExplore, Mission, Multiboards, Multirank, NoviceTask, Pairup, Pass, Preview, PureBoard, Race, Rise, Stagecha, Stickerboard, Team, TokenChain, TriggerProgress, WheelPack. Further event folders without the word: Streak, Bingo, Wheel, Calendar, ScoreRush, BakeOut, CookingFrenzy, OrderBoost, BoostCharge, Puzzle, Upward, FloatRace, PropertyBuff, HitBricks, OnePlusNGift, NewWeeklyBundle, DailyRating, WeeklyActiveQuest, Break, Exped, Pairwork, Room, Avenue.
- **Seasonal albums:** separate UI asset sets exist for at least a Halloween and a Christmas 2026 album, alongside the base album, so the card album is a rotating season feature, not one fixed album.
- **Card album strings:** a "Star Store" for duplicates, a "Prestige Rewards" upgrade, and a "restart the Collection" option that discards remaining stars. These extend what the July analysis recorded.
- **UI vocabulary confirmed in strings:** "Recharging" (generator cooldown), "Board Full", "Chores", "Daily Specials", "Hot Sales", "Buy Energy" ("Producing items costs Energy, you can buy more here"), "Energy Refilled" push notification, "Unlocks at level {0}", "Level Up by collecting more XP", "VIP PASS", "Piggy Bank". Items can double the recharge speed of surrounding items for 2 hours.

## 4. Live observations (fresh profile, about four minutes)

### 4.1 Opening sequence

1. Launch, "Initializing (3/3)" loading bar, version stamp (v4.12.0) top-left.
2. **3D cinematic** (a group scene, then the burning restaurant), no gameplay.
3. **Landscape story scene** with tap-to-continue dialogue (Quinn and Olivia: restaurant destroyed, food-poisoning question, sabotage hook, Olivia is hungry). One line per tap, a skip-forward button is available, and a Continue button appears at the end. About 10 taps.
4. Meta map with the first coin-cost chore visible (0/26 coins), then a tutorial arrow pointing at a **Kitchen** button.
5. **Kitchen board** with the line "This is the Kitchen board. Whoa it's filthy in here! We need to tidy up."

This matches the July analysis's cinematic-before-gameplay finding and its wording, so the opening sequence survived from 3.94.5 to 4.12.0 at least through the first board.

### 4.2 First board

- **Geometry:** 7 columns × 9 rows, shown in a portrait board inside a landscape window.
- **Opening state:** almost fully sealed. Most tiles are sand-coloured with debris, and a small pocket in the centre-left is playable. Locked tiles carry padlock badges: **energy caches (20, 10, 30, 50, 100)**, mystery chests, a gem, and a red item.
- **Opening a tile:** merging two items **adjacent to sand clears the neighbouring sand tiles**, revealing buried items (a burger, fries, bread). The tutorial prompt for this step: "Uncover a buried item by merging it."
- **Tutorial merge chain:** two items → "Little Brown Bag (Lvl 2)" → "Shopping Bag (Lvl 3)" → "Overflowing Bag (Lvl 4)", which is a **generator**. Merging cost no energy.
- **Info bar:** shows `Name (Lvl N)` and a hint. Plain items read "MERGE to reach its next level." A generator reads "MERGE to reach its next level. TAP to produce new items." Before any item is selected it reads "TAP an item to read its details here."
- **Generator tap:** each tap spawns one item and costs **1 energy** (100 → 99 → 98 → 97 over three taps).

### 4.3 Energy (measured live)

- Starts at **100**. A regen countdown appears under the counter after the first spend.
- Read as **1:53, then 1:48 five seconds later**, consistent with a **120-second** interval. This matches the July analysis (cap 100, 1 per 120 s, 1 per tap).
- Not re-tested: cap growth with level, over-cap behaviour, and the three energy faucets the July analysis listed.

### 4.4 Orders and HUD

- **HUD:** energy (with a `+` button), coins, gems (red), and a shop/cart button. Player level badge and portrait at top-left. A "Recover Progress" button sits at the right.
- **First order:** one customer portrait with **one requested item (a loaf of bread)** and **one reward (+2 coins)**. It sits at the top-left of the board and the tutorial gave no forced path to it in the time observed. The order was completed in the continuation session (§4.6).
- **Contrast with Travel Town:** a Travel Town order card shows several reward stacks (energy, coins, starfish, two event tokens, a tournament ball, sometimes a toolbox). Gossip Harbor's first order shows one coin reward. That difference may be the tutorial stage (level 1) rather than the shipped design.

### 4.5 What was not seen

- Any purchase offer, popup, ad, or terms prompt (none appeared in the whole session, about 13 minutes of wall time and roughly 5 minutes of actual play; consistent with the July "no monetization in session one" finding, but only for a fresh profile at level 1).
- Chores, the shop, events, the card album, or a level-up.
- The returning-player flow, which is where Travel Town stacked about 24 interrupts. A short re-open after about seven idle minutes showed the board with no interrupts, but that is far from a day-two return.

### 4.6 Continuation session (same profile, still level 1)

- **Energy over idle time:** left at 97, it was back at **100** after about seven minutes, consistent with the 120-second interval (3.5 units).
- **Chain names (flour line):** a flour sack (Lvl 1) merges to **Proofed Dough (Lvl 2)**, which merges to **Beginner's Bread (Lvl 3)**. The info bar for a Lvl 2 item shows a **red trash button** at the right; the generator (Lvl 4 "Overflowing Bag") shows none.
- **Merge rules seen:** items of different tiers do not merge (a flour sack dropped on a dough stayed put). **Cobwebbed items could not be dragged** at all (a webbed loaf did nothing when dragged toward the order). Webs appear to mark items that are not yet unlocked; the rule for lifting them was not isolated.
- **Idle hint:** after a few idle seconds a pointing hand appears and alternates between a source item and its merge target. Following it produced the Lvl 3 bread. It points at a valid merge, not necessarily the cheapest one.
- **Generator input:** the first tap on a generator **selects** it (info bar: "TAP to produce new items"); later taps produce one item each at **1 energy per tap** (energy 100 → 98 after two). In one stretch, taps on the generator did nothing while the open area looked full, and spawning resumed after merges freed tiles. No "Board Full" toast was captured, so the cause is inferred, not confirmed.
- **Serving an order:** when the requested item exists on the board, a green **Serve** button appears on the order card (with a guided hand during the tutorial: "We finished baking the bread! Let's Serve it to Olivia."). Tapping it consumed the item, flew a coin to the HUD, and paid **+2 coins** (0 → 2). Dragging an item onto the order card was not tried with an unlocked item, so serving by drag is untested.
- **Next order immediately:** a new customer appeared at once asking for a **club-sandwich-style item for +32 coins**. That is a **16× jump** from +2 to +32 between the first and second order, and it matches the +32 first-order figure in the July analysis (which may have been the second order). The sandwich sits much higher in the chain than the bread, so the second order needs many more merges than the first.
- **HUD at level 1:** energy, coins, gems and shop button only; no XP bar was visible.
- **Not reached:** level 2, the first gem grant, chores, sell, or the store. Reaching them needs a high-tier item first.

## 5. Gossip Harbor vs Travel Town (what the two sessions support)

| | Gossip Harbor 4.12.0 | Travel Town 2.12.1831 |
|---|---|---|
| Engine | Unity 2022.3.62f2 | Unity 2022.3.62f2 |
| Where logic lives | Packed Lua (not read) plus one C# assembly | C# feature assemblies + readable configs |
| Assemblies | 101 | 255 |
| Addressables entries | 21,865 | 1,222 |
| Animation | Spine | DOTween, particles |
| Board | 7×9, opens ~mostly sealed | 7×9 |
| Energy | 100, 1 per 120 s, 1 per tap (live + July) | 1 per 120 s, max 100 in config |
| Info bar | `Name (Lvl N)` + hint | `Name. Merge to reach next level.` |
| First-run prompts | Cinematic, story dialogue, no popups seen | Terms, then a long popup queue on a returning save |
| Event surface | 34+ activity folders | about a dozen event assemblies |
| Map / meta | 50 renovation areas, story-led | Island upgrade map |
| Languages | 10 | 16 |

Both use the same Unity version, so any engine-level behaviour (input, frame pacing, memory) can be compared like for like.

**Not comparable yet:** economy values. Travel Town's energy config was readable; Gossip Harbor's is only measured. Order payout, chore and shop prices need the live session to go further than four minutes.

## 6. Differences from the July analysis worth rechecking

The July analysis recorded 3.94.5; this build is 4.12.0.

- **Opening sequence:** unchanged through the first board.
- **Energy:** unchanged (100, 1 per 120 s, 1 per tap).
- **Info bar wording:** the July analysis quotes "Blast of Energy (Lvl 2) — Tap to collect 6 energy. Merge to reach the next level." That is a different item type. This session saw "MERGE to reach its next level." Same pattern, different string.
- **Seasonal albums:** the July analysis recorded one 33-day "Water Wonders" album; the catalog now lists Halloween and Christmas 2026 album sets, so the album has rotated at least once.
- **Everything past level 5 (store, chores, events, piggy bank, card prices):** not rechecked.

## 7. Not done

- Reading Lua logic (packed; deliberately not attempted).
- Past the first two orders: level-ups, chores, sell, store, events, the album, piggy bank, popups. Reaching level 5 takes many more merges than automated input can do efficiently; a human-played session to level 5 with screen recording (the way the July analysis was captured) is the better way to re-measure the level-5 live-ops layer on 4.12.0.
- Economy tables: payouts, prices, curves, spawn weights.
- Chain depth per item (the July analysis found 14 tiers for one chain; not rechecked here).
- Any comparison against PawSanctuary's code.

## 8. Suggested next steps

1. **A human-played, screen-recorded session to level 5**, to re-measure the July analysis's level-5 live-ops layer on 4.12.0 and to reach the chore, sell and store systems. A longer automated attempt stalled at the second order (§4.6); recordings can be analysed with `scripts/refvideo.swift`, as the earlier reviews were.
2. **Three-way comparison** (Gossip Harbor / Travel Town / PawSanctuary code): board capabilities, event surfaces, and where each game keeps its rules (Lua, C# assemblies, or SwiftUI coordinators). One architectural question is how much of PawSanctuary's event logic could be data-driven, as Gossip Harbor's is.
3. **A decision on the two doc files:** this and `TravelTown_Bundle_And_Live_Review.md` are uncommitted on `docs/traveltown-bundle-review`; they could be renamed or merged into one reference-review series.
