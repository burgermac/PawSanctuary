# PawSanctuary — Fifteen tiers per family (revision task 5.1)

**Status: Draft, 22 Nov 2026, not reviewed, no code.** Written cold from a read of the code at `70a8f5d` (origin/main on 22 Nov 2026, schema v45) to carry out task **5.1** of `Revision_Plan_ModelOnReferences.md` (W5, triage row 3). Since then `main` has moved to `2ca1c2e`, which merged PR #130 and set `currentVersion = 46`; `GameStore.swift` line numbers below are therefore about 7 lines low on current `main`. Search by name if a number no longer lands. **The owner reviews the migration plan (§5) before any code.** Task 5.2 (art) is the owner's; task 5.3 (build) is split into the session tasks in §9.

**Self-contained brief.** Assumes no prior conversation. Every code claim is cited `file:line`; every history claim cites a commit.

---

## 0. What this is, in one paragraph

Every animal family has 12 tiers today. It had 15 until commit `f646ae9` (27 Jul 2026, Phase 2b) deleted the fourth of five three-tier "eras" from all 15 families: 45 names, old indices 9 to 11. The references run 14 to 15 tiers and ask for **mid-chain** items in orders, so the top tiers are something to aim at, not something an order asks for. This spec puts the 45 names back at indices 9 to 11, which moves today's top era (9 to 11) back up to 12 to 14. That renumbers saved items, so it needs a migration. It keeps the order economy where it is by keeping the order tier caps where they are: orders keep asking for the same tier numbers, and the three new top tiers sit above every order, as the references' top tiers do.

## 1. Decisions this spec answers to

- **D14 §5 (18 Nov 2026).** "Direction accepted for rows 3 ... Row 3 changes saved tier indices (migration) and needs its own spec before any code." D14 "does not reopen D2 (row 3 revisits D2b through its own spec)". This is that spec.
- **D2b (Phase 2b, Alignment Plan §5b; `Spec_Phase2b_TwelveTiers.md`).** Cut 15 to 12 because Phase 2's order cap (9) left tiers 10 to 15 outside the order economy. This spec reverses the cut but **not** the reason: it answers it differently, by making the top tiers deliberately aspirational, as the references do (§3). D2b's record should get a "superseded by D14 row 3, see `Spec_FifteenTiers.md`" note once the owner accepts; this spec does not edit the Alignment Plan.
- **D14 §6 (19 Nov 2026).** The order tier cap `maxAchievableOrderTier` is shared with daily hand-in tasks and legendary quests, and is 8 at L31 to 40 and 10 at L51+. Nothing here changes the cap (Q1 recommends keeping it).
- **D14 §2 and `Spec_HeldItemOrders.md` (built).** Orders are filled from held items. That is what makes a long chain workable: surplus mid-chain items have a use (Triage §2.2, "Dependency: row 2 first").
- **D9.** Retention outranks monetization. Three effects of a longer chain touch it: the Ambassador and Sanctuary Star pace (§6.3, Q3), the Dog Tag store's stock (§6.4, Q4), and the sell/trio coin values (§6.5).
- **D13.** The chain viewer is stateless and the discovery collection is held. This spec adds no discovery state.
- **Revision Plan rule 6.** No unmeasured reference value is invented here. Where a number needs the references, it is marked "needs a recording" (§3.3).

---

## 2. Current behaviour (code at `70a8f5d`)

### 2.1 The chain model

- **15 families**, `AnimalSpecies.allCases` (`AnimalSpecies.swift`, enum starting at the top of the file; `tierNames` at `:133`). Each family is one merge chain, id `"animal.<rawValue>"` (`ItemChain.swift:223`).
- **12 tiers per family.** `tierNames` returns 12 names per family, four eras of three (`AnimalSpecies.swift:124-200`, doc comment `:124-132`).
- **Names resolve at runtime.** `ContentRegistry.makeAnimalChain` builds one `ChainTier` per `tierNames` entry, badges the last one `medal.fill`, colours each from `QuestGoal.animalTierAppearance` (`ItemChain.swift:572-596`). Saves store only `BoardItem(chainID, tier)`; `BoardItem.def` looks the tier up in the registry (`ItemChain.swift:145`), so an out-of-range tier renders an empty cell.
- **`maxTier` is derived:** `MergeChain.maxTier = tiers.count - 1` (`ItemChain.swift:59`); `BoardItem.isTopTier = tier >= chain.maxTier` (`:147`).
- **Art resolves by name and tier index.** `AnimalSpecies.assetName(tier:)` builds `animal_<family>_<species>_tier<NN>_<tiername>` (`AnimalSpecies.swift:209-213`); `artImage(tier:)` returns `nil` when the asset is missing, and every caller falls back to the SF Symbol (`:224-227`; generic resolver `MergeChain.artImage(forTier:)`, `ItemChain.swift:68-`). **The tier index is in the asset name**, so moving a name from index 9 to 12 changes the asset it looks for (§4.3).
- **Stage labels** (used by quest text and tier colours) come from `animalTierAppearance(tier:)` (`AnimalSpecies.swift:808-830`): 0 to 8 are the old `RescueStage` labels ("Rescued" … "Ambassador" at 8), 9 to 11 are "Mythic", "Ancient", "Primordial".
- `RescueStage` is a 9-case enum, tier indices 0 to 8, with `.ambassador` at 8 commented "top tier – sanctuary ambassador" (`AnimalSpecies.swift:302-313`). It has not been the top tier since chains grew past 9.

### 2.2 Every place a top tier, a chain length or a tier ceiling is assumed

| # | Site | What it assumes | Effect of 15 tiers |
|---|---|---|---|
| 1 | `animalChainTopTier = 11` (`AnimalSpecies.swift:2236-2237`) | A literal, "12 tiers as of Phase 2b" | Must become 14 (better: derived, §9 task 1) |
| 2 | `animalSellValues = (0...animalChainTopTier).map(...)` (`:2436-2438`) | Table length follows #1 | 15 entries, tier 14 sells for 45,056 coins (2.75 × 16,384) |
| 3 | `animalTierAppearance` (`:808-830`) | 12 labelled tiers, `default` = "Primordial" | Restore 15 cases (§4.2) |
| 4 | `makeAnimalChain` (`ItemChain.swift:572-596`) | Badge on `tierNames.count - 1` | Derived; no change |
| 5 | `MergeOutcome.isTopTierCompletion = resultTier == chain.maxTier` (`MergeOutcome.swift:111`) | Derived | Ambassador celebration moves to tier 14 (§6.3) |
| 6 | `triggerTopTierCelebration` (`MergeBoardViewModel.swift:2557-2568`): `ambassadors += 1`, `ambassadorQuestProgress += 1`, 500 coins, a toolbox, 5 Dog Tags, `MilestoneManager.checkMilestones(stars: ambassadors)` | Fires on the true top tier | 8× the kibble to reach (§6.3, Q3) |
| 7 | Ambassador collection quest, `ambassadorQuestGoal = 3`, removes three `isTopTier` animals (`MergeBoardViewModel.swift:2664-2690`); card text "Merge 3 animals to Ambassador tier" (`MergeBoardView.swift:1225`) | Top tier | Same as #6 |
| 8 | Ambassador trio exchange: `recalcExchangeableTrios` reads `isTopTier` (`MergeBoardViewModel.swift:888-898`); value = `animalSellValue(maxTier) × 3 × 1.25` (`:903-908`, multiplier `AnimalSpecies.swift:1724`) | Top tier | 21,120 coins today; 168,960 at tier 14 (§6.5) |
| 9 | Sanctuary Star milestones at 5/15/30/50 Ambassadors (`MilestoneManager.swift:49-58`) | Counts #6 | Pace falls 8× (§6.3) |
| 10 | Info-bar caption "Ambassador — top tier" for any `isTopTier` animal (`MergeBoardViewModel.swift:716-718`) | Calls the top tier "Ambassador" | Already wrong today (§11 item 3) |
| 11 | `maxAchievableOrderTier` (`AnimalSpecies.swift:1952-1963`): 2/3/4/5/6/8/10/10 by level band; caps at `:2583-2584` | Absolute tier numbers | Unchanged under Q1 (a); now means "at most tier 11 of 15" |
| 12 | `orderDifficultyBands` (`:1990-1994`): easy 0-1, medium 2-3, hard 4-5 (75%), 6-7, 8-9, 10-11 | Absolute | Unchanged; the `[10, 11]` entry still collapses onto the cap |
| 13 | Daily hand-in tasks read the same cap (`QuestCoordinator.swift:296-304`) | Shared cap (D14 §6) | Unchanged |
| 14 | Legendary quest pool appends `reachTier` 9, 10, 11 "so the endgame of every chain is a reachable objective" (`QuestCoordinator.swift:178-183`, added by `fdf02df`) | 9 to 11 are the top three tiers | They become mid-upper tiers; still capped by #11 (Q5) |
| 15 | Bubble: `bubbleMinTier = 5`, top tier excluded via #5 (`AnimalSpecies.swift:2194`, `MergeOutcome.swift:111-115`); pop cost `3 + tier` Dog Tags (`:2204`) | Absolute, plus derived top | Tiers 11 to 13 now bubble (pop 14 to 16 tags); tier 14 excluded |
| 16 | Dog Tag store: stock tiers `deepestUnlockedTier − 4 … − 1`, clamped to chain `maxTier` (`DogTagStore.swift:52-77`, offsets `AnimalSpecies.swift:2297-2298`); price `15 + 18 × (tier − minTier)` (`DogTagStore.swift:83-85`) | Relative to deepest; price relative to band, max 69 | A deepest-14 player is offered tiers 10 to 13 at the same 15 to 69 tags (§6.4, Q4) |
| 17 | Recirculation grants: `deepest − 2`, capped at `recirculationMaxItemTier = 6` (`:2253`, `:2268`); Smile bundles capped at `smileBundleMaxItemTier = 4` (`:1532`); order board-item reward `wantedTier − 3` (`:2272`) | Absolute caps | Unchanged |
| 18 | Smile points from the deepest line: <4 → 1, 4-7 → 2, else 3 (`AnimalSpecies.swift:1495-1500`) | Absolute | Unchanged |
| 19 | Board rows unlock on `deepestUnlockedTier` 2/4/6/8/9/10 (`boardRowUnlockTiers`, `:1925`); `deepestUnlockedTier` rises on any `.animal` merge (`MergeBoardViewModel.swift:3121-3126`) | Absolute | Unchanged in cost; the full board still opens at tier 10 |
| 20 | Superpower unlocks at tier 6 (`SuperpowerSystem.swift:52`) | Absolute, start of Era 3 | Unchanged |
| 21 | Spawners spawn tiers 0 to 3 by multiplier (`spawnTierIndex`, `AnimalSpecies.swift:2138-2146`; `MergeBoardViewModel.swift:1784-1811`) | Absolute, clamped to `maxTier` | Unchanged |
| 22 | Sell-vs-order nudge range `3...8` (`:2243`) | Absolute | Unchanged |
| 23 | Chain viewer: rows from `chain.tiers`, "Tier N of M", star on `maxTier` (`MergeBoardView.swift:1787-1815`); owned-count badges live (`ChainViewerOwnedCountTests`) | Derived | Shows 15 rows; no change |
| 24 | Trophy pages: keyed by family, filled by completed **sub-objects** (`MergeBoardViewModel.swift:4038-4080`) | No animal tier | Unaffected |
| 25 | `EconomySimulation`: `assumedDeepestTier(level) = orderTierCap(level)` (`PawSanctuaryTests/EconomySimulation.swift:866-868`); Ambassador coin term `production / spawnCost(animalChainTopTier) × 500` (`:957-959`) | #1 | Ambassador term falls to 1/8 (§7) |
| 26 | Tests pinning 12 tiers (§8.3) | 12 | Rewrite |

Second Chances, the Parallel Board's own 5-tier chain, is registered as `.animal` but has id `parallelboard.secondchances` (`ItemChain.swift:252`, `:72-80`), so every `"animal."`-prefix check below already excludes it.

### 2.3 Persistence

- `GameState` (`GameStore.swift:20-265`), `static let currentVersion = 45` at `70a8f5d` (`:394`); **46 on current `main`** (`2ca1c2e`, PR #130, `claimedCollectionPrizeIDs`).
- The dispatch table is flat: each old version jumps straight to the current one (`readValid`, `:660-728`), and every path ends in `finishMigration` (`:832-846`), which runs version-gated rewrites: `sourceVersion < 28` remaps 15-tier indices to 12 (`:835`), `< 32` recovers spawners, `< 37` collapses orders into baskets, `< 40` resets daily challenges.
- The Phase 2b remap: `remappedAnimalTier` maps old 0-8 → 0-8, 9-11 → 8, 12-14 → 9-11 (`:998-1002`); `remapAnimalTiersForTwelveTierChains` applies it to board, inventory, power-up inventory, pouch, pending material lots, flat-shape `adoptionOrders[].wantedTier` and `rewards[].payloadTier`, `activeQuests`/`dailyChallenges` `reachTier` goals, Dog Tag store slots, `deepestUnlockedTier` and `commerce.lastWallTier` (`:1006-1117`). It is pinned by `PersistenceTests.swift:1031-1110`, `:1874-1907`.

---

## 3. What the references show, and what is unmeasured

### 3.1 Measured

- **Chain length.** Travel Town's bundle has a 15-tier chain (`sea-shell`, art `_00` to `_14`) beside 5- and 9-tier ones (`TravelTown_Bundle_And_Live_Review.md:60`). Gossip Harbor 4.12.0: "Half a Ham Sandwich" shows 15 slots, "Cut Potatoes" 7 (`Triage_ModelOnReferences.md` §2.8). July notes: 14+ tiers. **So 15 is the references' long-chain length, not a uniform one**; both run shorter chains too. PawSanctuary's animal families are all one length; this spec keeps them uniform (non-uniform chains are out of scope).
- **Orders ask for mid-chain items.** Gossip Harbor's first order on a level-1 profile asked for Half a Ham Sandwich at **level 8 of 15** (Triage §2.8). Travel Town orders seen during play asked for Lv 3, 5, 5, 7 and 4 items (`Spec_OrdersAndTasks_Draft.md:36`; chain lengths of those items not recorded). Travel Town config: "1–2 specific items at mid-chain tiers" (`Spec_TravelTownReview_Draft.md:25`).
- **Store prices** run a few gems up to ~153 for one item, small stock, daily refresh (Triage §2.10 (a)).

### 3.2 What "mid-chain order targets" means numerically here

Under Q1 (a) the caps stay as today, so on a 15-tier chain (1-based "tier N of 15"):

| Player level | Highest tier an order can ask for | Share of the chain |
|---|---|---|
| 1-3 | tier 3 of 15 | 20% |
| 10-20 | tier 6 of 15 | 40% |
| 21-30 | tier 7 of 15 | 47% |
| 31-40 | tier 9 of 15 | 60% |
| 41-50, 51+ | tier 11 of 15 | 73% |

The hard slot's headline line is tier 5 or 6 of 15 three times in four (`orderDifficultyBands[.hard]`, 75% on indices 4-5). Tiers 12 to 15 of 15 are never asked for by an order, a daily task or a quest. That is the references' pattern as far as it was measured: top tiers aspirational, orders mid-chain.

### 3.3 Not measured (needs a recording; nothing below is guessed)

- **How deep the references' orders go by player level.** One Gossip Harbor order at level 1 (8 of 15) and five Travel Town items without chain lengths are not a distribution. Note the one Gossip Harbor reading (53% of the chain at player level 1) is far deeper than PawSanctuary's level-1 cap (20%); whether that is typical, or an artefact of Gossip Harbor's generators starting mid-chain, is unknown. **Proposed recording (call it R10; not yet in `Recording_Guide.md`):** in each game at three player levels (low, ~20, ~50), open five orders and the chain viewer for each wanted item; note the item's level and its chain's length.
- **What the references pay for reaching a chain's top tier**, and whether a top-tier item can be sold or ordered at all.
- **Whether any reference store stocks a chain's top tiers.**

Until R10 exists, the caps are not moved (Q1).

---

## 4. Target behaviour

### 4.1 The names (recovered from `f646ae9`)

Restore old indices 9 to 11 exactly as `f646ae9` removed them (`git show f646ae9 -- PawSanctuary/AnimalSpecies.swift`); nothing is renamed. Today's 9 to 11 move to 12 to 14.

| Family (`case`) | Index 8 (stays) | **Restored 9** | **Restored 10** | **Restored 11** | Moves 9→12 | 10→13 | 11→14 |
|---|---|---|---|---|---|---|---|
| Canines (`.dog`) | Husky | **Alpha** | **Guardian** | **Sentinel** | Dire Wolf | Mythic | Primordial |
| Felines (`.cat`) | Leopard | **Panther** | **Tiger** | **Lion** | Sabertooth | Sovereign | Apex |
| Lagomorphs (`.rabbit`) | Snow | **Flemish** | **Belgian** | **Giant** | Desert | Patagonian | Mara |
| Avians (`.bird`) | Jay | **Falcon** | **Hawk** | **Owl** | Eagle | Vulture | Condor |
| Rodents (`.hamster`) | Beaver | **Prairie Dog** | **Marmot** | **Nutria** | Muskrat | Porcupine | Capybara |
| Reptiles (`.turtle`) | Tegu | **Gila** | **Spiny** | **Python** | Boa | Caiman | Komodo Dragon |
| Cervids (`.fox`) | Deer | **Red** | **Wapiti** | **Elk** | Sambar | Pere David | Moose |
| Ursids (`.owl`) | Glacier | **Brown** | **Kodiak** | **Grizzly** | Polar | Ancient | Behemoth |
| Aquatics (`.fish`) | Salmon | **Sword** | **Sail** | **Marlin** | Shark | Hammerhead | Whale Shark |
| Amphibians (`.lizard`) | Horned | **Salamander** | **Axolotl** | **Mud** | Hellbender | Giant | Goliath |
| Marsupials (`.ferret`) | Tree | **Devil** | **Quoll** | **Wombat** | Koala | Macropod | Red Kangaroo |
| Primates (`.parrot`) | Guenon | **Baboon** | **Mandrill** | **Gibbon** | Chimpanzee | Orangutan | Gorilla |
| Equines (`.pony`) | Paint | **Thoroughbred** | **Shire** | **Clydesdale** | Zebra | Quagga | Giraffe |
| Pachyderms (`.hedgehog`) | Rhino | **White Rhino** | **Black** | **Indian** | Seal | African | Mammoth |
| Bovines (`.guineaPig`) | Muskox | **Highland** | **Longhorn** | **Gaur** | Buffalo | Aurochs | Titan |

45 restored names; 180 → 225. No restored name repeats a name in its own family. Two repeat a name in another family (Avians' restored "Owl" and Primates' index 5 "Owl"; Lagomorphs' restored "Giant" and Amphibians' "Giant", index 13 after the move). Cross-family repeats already exist and are allowed (`testEveryFamilyHasTwelveTiers` checks uniqueness within a family only); the asset names cannot collide because the family is part of them.

### 4.2 Stage labels and colours

Restore `animalTierAppearance` to its pre-`f646ae9` 15-case form: 9 "Elite" (`bolt.circle.fill`, RGB 0.60/0.20/0.90), 10 "Champion" (`sparkles`, 0.50/0.18/0.82), 11 "Legendary" (`seal.fill`, 0.70/0.50/0.90), 12 "Mythic", 13 "Ancient", 14 (default) "Primordial", the last three with today's 9/10/11 colours. Quest text changes accordingly (`QuestGoal.description` prints the label and `Tier \(tier + 1)`): a tier-10 goal reads "Champion (Tier 11)" instead of today's "Ancient (Tier 11)", which `QuestCoordinatorTests.swift:22` pins and must change.

### 4.3 Art

- **What exists:** 180 animal imagesets in `PawSanctuary/Assets.xcassets/Animals`, tier00 to tier11 for each family, added by `f73aa63` (21 Aug 2026, "Wire real illustrated art", "Animals (180)"), **a month after** the cut. Both delivery folders beside the repo (`Animals xcassets/PawSanctuary_Animals_Delivery`, `PawSanctuary_Animals_Delivery 2`) also hold 180. No commit in the repository's history ever contained an animal imageset at tier 12 to 14 or for any of the 45 restored names (checked over all refs).
- **What is missing: all 45 restored tiers' art.** Owner task 5.2. Until it arrives those tiers show the family's SF Symbol, as any missing art already does (`AnimalSpecies.swift:216-227`); the game stays playable.
- **What must be renamed, not redrawn: today's 45 top-era imagesets.** Because the index is in the asset name (§2.1), `animal_canines_dog_tier09_dire_wolf` must become `animal_canines_dog_tier12_dire_wolf`, and so on for tier 10 → 13 and 11 → 14 in every family: 45 imageset folders, each with its inner file and the `filename` in its `Contents.json`. This lands in the same commit as the names (§9 task 3), or every top-era item loses its art. A script is the safe way (rename by pattern, then assert every `assetName(tier:)` for tiers 0-8 and 12-14 resolves).
- **Naming for the 45 new files** (for the art brief): `animal_<family>_<species>_tier09_alpha` etc., by the same rule (`AnimalSpecies.swift:209-213`: lower case, spaces to underscores), e.g. `animal_rodents_hamster_tier09_prairie_dog`.
- `docs/PawSanctuary_Graphical_Element_Inventory.xlsx` lists 180 animal elements; regenerate it from source after task 3 (CLAUDE.md: never hand-edit).

---

## 5. Migration plan (owner review required before any code)

### 5.1 The mapping

Saves written at schema v28 up to the version before this change hold 12-tier indices. They map to 15-tier indices as follows (**Q2 (a), recommended: keep the item the player sees**):

```
saved 0–8   →  0–8     unchanged (Eras 1–3)
saved 9–11  →  12–14   shift up by 3 (today's top era keeps its names: Dire Wolf stays Dire Wolf)
(new 9–11 are empty on every migrated save; nothing maps there)
```

This is the exact inverse of `f646ae9`'s shift for its 12–14 → 9–11 half, and it is lossless: every saved item keeps its name, art and top-tier status. Its cost is that those items become worth 8× more in kibble terms (a Dire Wolf was 512 kibble at index 9 and is 4,096 at index 12), because worth is `2^tier` (`spawnCost`, `AnimalSpecies.swift:2234`). Pre-launch, only test saves exist.

Applied to an animal tier `t` (`chainID` has prefix `"animal."`; `parallelboard.secondchances` and every sub-object, supply, material, currency, toolbox and superpower chain are untouched):

```swift
/// 12-tier index → 15-tier index (schema vN, Spec_FifteenTiers.md §5).
static func expandedAnimalTier(_ old: Int) -> Int {
    old <= 8 ? max(0, old) : min(14, old + 3)
}
```

(`min(14, …)` clamps a corrupt out-of-range value rather than inventing a tier; `max(0, …)` likewise.)

### 5.2 Every persisted place an animal tier lives, and what happens to it

Found by reading every `GameState` field (`GameStore.swift:20-265`) and every Codable type it holds.

| JSON path in the save | Today's shape | Rule |
|---|---|---|
| `board[r][c].item` `{chainID, tier}` | `BoardItem` | expand if `animal.` |
| `inventory[i]` | `[BoardItem?]` | expand if `animal.` |
| `powerUpInventory[i]` | `[BoardItem?]` (v27) | expand if `animal.` |
| `pouchItems[i]` | `[BoardItem?]` (v24, Marsupials Pouch) | expand if `animal.` |
| `pendingMaterialLots[l][i]` | `[[BoardItem]]` | walk with the same chain-gated helper (a no-op in practice; materials have their own tier space) |
| `adoptionOrders[i].lines[j].tier` | `OrderLine` (v37) | expand if line `chainID` is `animal.` |
| `adoptionOrders[i].rewards[k].payloadTier` | `OrderReward` | expand if `payloadID` is `animal.` (`.boardItem` rewards; `.material` payloads are material chains and stay) |
| `urgentOrder.lines[j].tier`, `urgentOrder.rewards[k].payloadTier` | `AdoptionOrder?` (v29) | same as above. **Not covered by the Phase 2b remap** (the field did not exist then) |
| `activeQuests[i].goal.reachTier` `{"_0": "animal", "tier": N, "count": C}` | `QuestGoal` | expand when `_0 == "animal"`; `supply` goals stay |
| `dailyChallenges[i].lines[j].tier` | `DailyTaskLine` (v40) | expand if `animal.`. **New shape since the Phase 2b remap**, which walked the old `goal` shape |
| `dogTagStoreSlots[i].tier` | `DogTagStoreSlot` | expand if `animal.`; **price is left as stored** (the slot was priced when rolled; it refreshes daily) |
| `deepestUnlockedTier` | `Int` | expand (it only ever records animal tiers, `MergeBoardViewModel.swift:3121-3126`) |
| `commerce.lastWallTier` | `Int?` | expand **only if** `commerce.lastWallChainID` has prefix `animal.` (Phase 2b's remap did not check the chain; `recordWallEvent` writes the spawner's chain, `MergeBoardViewModel.swift:1764-1769`, `:1793`) |

**Checked and deliberately not touched:** `parallelBoardState.board` (holds only `parallelboard.secondchances` items and its generator; chain-gating would skip them anyway, so the migration does not walk it); `producerStorage`, `overflowProducerStorage`, `familySpawnerStorage` (producers carry a level and a species, no tier); `materialCounts`, `pityStates` (material and sub-object tier spaces); `trophyCounts` (family-keyed counts of sub-objects); `cardInventory`, `completedAlbumIDs`, `claimedCollectionPrizeIDs` (card ids); `progressTracks`, `eventTokenWallets`, `passUnlockedEventIDs`, `kibbleDrive` (event state, no tiers); `ambassadors`, `ambassadorQuestProgress` (counts, not tiers; a migrated top-tier item stays top tier, so the counts stay consistent); `unlockedSuperpowerSpecies` (unlock tier 6 is below the change); `playtestMetrics` (no tier fields); every `BoardCell.isUnlocked` (rows already opened stay open). **Outside `GameState`:** Sanctuary Star claimed thresholds live in `UserDefaults` (`MilestoneManager.swift:65-`) and hold counts, not tiers. **Chain viewer / discovery:** no persisted state exists (D13 held it); owned counts are derived live.

### 5.3 Schema version

- At `70a8f5d` the schema was v45. PR #130 has since merged v46 (`claimedCollectionPrizeIDs`). Other work in flight may take v47 first. **The build session takes `currentVersion + 1` from the `main` it branches from** and names the version and tests accordingly. This spec writes it as **vN** (expected v47).
- A bump is required, not optional: the remap must run for exactly the saves written by 12-tier builds, and the version is the only marker of that.
- Dispatch: add `if version == N-1 { return migrateByInjecting(from: N-1, defaults: [:], into: data) }   // 15-tier expand runs in finishMigration for every sourceVersion < N`, beside the latest lines (`GameStore.swift:714-717` at `70a8f5d`). Add the vN line to the version history comment and set `currentVersion = N`. No `additiveDefaultsSinceV8` entry (no field is added).
- `finishMigration` gets **one new line, placed last, after** `resetDailyChallengesForHandIn`:

```swift
if sourceVersion >= 28 && sourceVersion < N { expandAnimalTiersForFifteenTierChains(&json) }   // Q6 (b) drops the >= 28
```

  Placing it last means it only ever sees today's shapes (`lines` on orders, `lines` on daily tasks), because `collapseOrdersIntoBaskets` (`< 37`) and `resetDailyChallengesForHandIn` (`< 40`) have already run. It must not walk the flat `wantedTier` shape.
- **Helper names.** CLAUDE.md's convention is `migrateVNtoVN+1`; since v29 additive bumps use `migrateByInjecting` with no helper. This bump has a rewrite, but the rewrite must run for every source version from 28 up (the table is flat), so, like the v28, v37 and v40 rewrites, it lives in `finishMigration` as `expandAnimalTiersForFifteenTierChains`. A one-line `migrateV(N-1)toVN(_:)` wrapper calling `finishMigration(&json, from: N-1)` is optional and only for naming symmetry with `migrateV27toV28` (`GameStore.swift:968-971`).

### 5.4 Saves from before v28 (Q6)

Pre-v28 saves already hold **15-tier** indices (chains were 15 long from `2874697`, 19 Jul 2026, to `f646ae9`). Today `finishMigration` squeezes them to 12 (`:835`). Two choices:

- **(a) Identity for pre-v28 saves.** Stop calling the 15→12 remap for `sourceVersion < 28` and do not expand them either: their indices are native again. Lossless. Changes the behaviour of a July migration and rewrites three of its tests.
- **(b) Compose (recommended).** Leave the 15→12 remap exactly as it is and run the expand after it for every `sourceVersion < N` (drop the `>= 28` guard above). A pre-v28 save's 0-8 and 12-14 come back unchanged; its 9-11 stay demoted to 8 (Husky), as they are today. Touches no existing migration code, only adds a step; the loss affects only July-era test saves, which already took it once.

### 5.5 Risks to the migration chain (explicit)

1. **Double application.** If a save is expanded twice, 12 → 15 → clamped 14. Guarded by the version gate (`< N`) and by `encode` stamping `currentVersion` (`GameStore.swift:651-656`). Tested (§8.2 case 5).
2. **Missing a tier-bearing field** leaves an item pointing at the wrong animal, silently (an in-range wrong tier still resolves). Mitigation: the §5.2 table, and a test that seeds **every** path and asserts each one (§8.2 case 1).
3. **Shape drift.** The new step reads `lines`, not `wantedTier`. If someone later moves the line above `collapseOrdersIntoBaskets`, pre-v37 orders would be skipped. A comment at the call site and §8.2 case 3 (a v36 save) pin the order.
4. **Older-build downgrade.** An older build reading a vN save fails the version guard and treats it as "no save" (`readValid`, `:725`); `load()` then prefers another copy by `lastActiveDate` (`:577-604`). A device left on an old TestFlight build could write a fresh save with a later date to iCloud and win. Pre-existing for every bump; worth one line in the PR.
5. **Pre-v18 saves are already off by one.** v8 to v16 saves dispatch through `migrateByInjecting` and never receive `migrateV17toV18`'s −1 shift (only `version == 17` calls it, `:690`; `finishMigration` has no `< 18` step). Not caused or fixed here (§11 item 1); noted because Q6 (a) or (b) both compose on top of it.
6. **Content and migration must land together.** Restoring names without the migration, or the migration without the names, mislabels every saved item at 9 to 11 for the length of that build. One commit (§9 task 3), as Phase 2b did.

---

## 6. Economy and feel: what changes

### 6.1 What does not move (by construction, under the recommended options)

Item worth is `2^tier` at every tier (`spawnCost`), and every order, daily-task, quest, recirculation and row-unlock rule is written in absolute tier numbers (§2.2 rows 11-22). With Q1 (a) the caps do not move, so `EconomySimulation`'s demand (`orderTierCap`), supply (measured, pinned at 695/745 by `EconomyTests.swift:780-784`), recirculation (absolute caps 6 and 4) and board capacity (`boardRowUnlockTiers`) are **unchanged**. `testDemandSupplyRatioMatchesTheTargetCurve` (`EconomyTests.swift:754-771`), the D14 held-item rows (`:862-891`) and the congestion figures should produce the same numbers. Task 3 must run them to show it, not assume it.

### 6.2 What a 15-tier chain costs

| | 12 tiers (today) | 15 tiers |
|---|---|---|
| Top-tier build cost | 2,048 kibble | 16,384 kibble |
| Days of total income at ~745/day | ~2.7 | ~22 |
| Days at 20% attention (Phase 2b's own table) | ~14 | ~110 |
| Highest tier an order asks for | 10 of 0-11 | 10 of 0-14 |

The top is no longer orderable and is not meant to be (§3.2).

### 6.3 Ambassador, the Ambassador quest and Sanctuary Stars (Q3)

Everything keyed to `isTopTier` (§2.2 rows 5-9) moves to tier 14. With no other change: one Ambassador costs 8× the kibble; the Ambassador collection quest (three of them) goes from ~8 days of total income to ~66; the first Sanctuary Star (5 Ambassadors) from ~14 days to ~110; the 50-star milestone from ~137 days to ~3 years. Under D9 that is a retention cost with nothing gained. `EconomySimulation.otherCoinIncome`'s Ambassador term (`:957-959`) falls to 1/8, which slightly lengthens the projected map build-out (`testMapBuildOutLandsInTheTargetWindow`, `EconomyTests.swift:442-451`; size not computed here, task 4 runs it). Q3 recommends pinning the Ambassador milestone to a fixed tier (11, today's top) so none of these paces change.

### 6.4 Dog Tag store (Q4)

The store's band is relative to the deepest tier merged (§2.2 row 16), so a player who reaches tier 14 is offered tiers 10 to 13 at the same 15 to 69 tags. A tier-13 item is 8,192 kibble of build cost; today the dearest a store slot can ever be is tier 10 (deepest 11 − 1). That is new value entering a Dog Tag economy `EconomySimulation` does not model (D13 noted the gap), and D13 says nothing about store stock is tuned to make it convert better. Q4 recommends capping the store at today's ceiling.

### 6.5 Sell and trio values

The sell rate is flat per kibble (2.75, `coinsPerKibbleOfSale`), so a longer table creates no farming tier (`testSellRateIsFlatAcrossTiers`). In absolute terms one tier-14 animal sells for 45,056 coins and an Ambassador trio pays 168,960 (58% of the 291,900-coin map), against 5,632 and 21,120 today. That is not arbitrage, because it costs 49,152 kibble of production, but it means one trio is a large single coin event. If Q3 (b) moves "Ambassador" to tier 11, the trio should follow it (tier-11 trio value is unchanged at 21,120); the true top's sell value stays derived.

### 6.6 What the economy task (task 4) delivers

1. `EconomySimulation`: replace `spawnCost(forTier: animalChainTopTier)` in the Ambassador term with the Ambassador tier chosen in Q3.
2. Run and report: the ratio table (D12 and D14 rows) at the report levels before and after; `daysToFullMap` with and without selling; the congestion figures. Expected: unchanged ratio rows; map build-out unchanged under Q3 (b), slower under Q3 (a).
3. If any target band moves, the lever is order tiers or line counts (the model's own rule), not supply, and the owner sees the numbers first. Under Q1 (a) none should move.

### 6.7 Retune that needs a recording first (not in this spec's tasks)

Moving the order caps toward the references' depth (Gossip Harbor's single 8-of-15 reading at level 1) waits on R10 (§3.3). Not guessed here.

---

## 7. D9 and D7 checks

- **D9.** Under the recommended answers, no pace the player feels today gets slower: orders, dailies, quests, rows, Ambassadors and stars keep their tier numbers and costs; the three new tiers are extra headroom. Q3 (a) would cut retention-side rewards hard and is not recommended. Q4 (a) would raise store value and is a monetization change with an economy cost; not recommended. **Nothing here raises revenue at a retention cost.**
- **D7.** No new purchase surface; the store keeps its existing gate.

---

## 8. Tests

### 8.1 Content and rules (task 3 unless stated)

Rewrite the Phase 2b block in `EconomyTests.swift:466-536`:
- `testEveryFamilyHasTwelveTiers` → `testEveryFamilyHasFifteenTiers` (15 per family, unique within family, 225 total).
- `testDroppedEraIsGoneAndSurvivingErasKeptTheirNames` → `testRestoredEraSitsAtNineToElevenAndTheTopEraMovedUp` (the Canines array in full; Alpha/Guardian/Sentinel at 9/10/11; Dire Wolf/Mythic/Primordial at 12/13/14).
- `testEveryAnimalChainRegistersTwelveTiersWithABadgedTop` → `maxTier == 14`, badge on 14 only.
- `testTopTierItemIsReachableWithinAFewDaysOfIncome` → replace with `testNoOrderDailyTaskOrQuestAsksForTheTopThreeTiers` (for every level 1-80, `maxAchievableOrderTier < 12`) and, under Q3 (b), `testAmbassadorTierIsReachableWithinAFewDaysOfIncome` (the old assertion moved to the Ambassador tier).
- `testSellRateIsFlatAcrossTiers`: 15 entries. `testSuperpowerUnlockTierSurvivesTheCut`: `< 15`.
- `testEveryRestoredAndMovedTierHasTheAssetNameItsArtIsFiledUnder` (new): for tiers 0-8 and 12-14 of every family, `UIImage(named: assetName)` is non-nil (proves the 45 renames); for 9-11, `assetName` has the documented form (art may be missing).
- `QuestCoordinatorTests.swift:22-23`: new stage-label text.
- `TierBadgeTests.swift:25` message; tests that read `animalChainTopTier` (`MergeOutcomeTests`, `AttemptMergeOrMoveCharacterizationTests`, `ParallelBoardCoordinatorTests`, `SmilePointsTests`) need only a run, unless Q3 (b) introduces a separate Ambassador constant they should read instead.
- Task 4: whatever §6.6 restates; `testDemandSupplyRatioMatchesTheTargetCurve` and `testMapBuildOutLandsInTheTargetWindow` must pass unchanged, or change only with the owner's agreement. Under Q4 (b), `testStoreNeverStocksAboveTheCap`.

### 8.2 `PersistenceTests.swift` (task 2 writes the pure-function tests; task 3 the load tests)

Under a `// MARK: v(N-1) → vN (fifteen tiers)` heading, pattern of `testV27toV28RemapsEveryTierBearingField` (`:1081`):

1. `testExpandedAnimalTierMapsTwelveTierIndicesToFifteen` (pure): 0-8 → 0-8; 9/10/11 → 12/13/14; out of range clamps into 0…14; never returns 9, 10 or 11.
2. `testVPrevSaveExpandsEveryTierBearingField`: a v(N−1) blob from `makeSampleState()` seeded at tiers 8, 9, 10, 11 in every path of the §5.2 table (board, inventory, power-up inventory, pouch, an order line, an order `.boardItem` reward, the urgent order's line and reward, a `reachTier` quest, a daily-task line, a store slot, `deepestUnlockedTier`, `lastWallTier` with an `animal.` chain); assert 8, 12, 13, 14 in each, and `version == currentVersion`.
3. `testV36SaveWithAFlatOrderStillExpandsAfterTheBasketCollapse`: proves the step runs after `collapseOrdersIntoBaskets` (a v36 flat order at `wantedTier: 10` arrives as a line at 13).
4. `testNonAnimalTiersAreUntouchedByTheExpand`: a sub-object, a supply item, a material in `pendingMaterialLots`, a `.material` order reward, a `supply` `reachTier` quest, a `parallelBoardState` Second Chances item at tier 4, and `lastWallTier` with a nil chain all keep their tiers.
5. `testACurrentSaveIsNotExpandedAgain`: a vN save holding tiers 9, 10, 11 (the restored era) loads unchanged.
6. `testEveryExpandedTierResolvesInTheRegistry`: like `:1874`, for case 2's save.
7. Pre-v28 (Q6): rewrite `testV27toV28RemapsEveryTierBearingField`, `testEveryMigratedTierResolvesInTheRegistry` and `testOlderSavesAlsoGetTheTierRemap` (`:1081`, `:1874`, `:1890`) to the final mapping. Under (b) a v27 save's old 8/10/13/14 load as 8/8/13/14; under (a) as 8/10/13/14. `testTierRemapCollapsesTheDroppedEraAndShiftsTheTop` (`:1033`) stays as is (it tests the unchanged pure function) under (b).
8. `testVPrevSaveWithATopTierItemKeepsItsAmbassadorStatus`: a saved tier-11 animal arrives at 14 and `isTopTier` is true.

Full suite green before every commit, per CLAUDE.md.

---

## 9. Implementation tasks (one per session; the game is playable after each)

### Task 1 — Remove the 12-tier literals (no behaviour change)

- `animalChainTopTier` derived from the chain length rather than the literal 11 (for example `AnimalSpecies.dog.tierNames.count - 1`, with a test that all families agree), so task 3 changes one place.
- Legendary quest pool (`QuestCoordinator.swift:178-183`): per Q5, express the 9/10/11 goals as named constants beside the caps.
- If Q3 (b): add `ambassadorMilestoneTier = 11` to the tuning constants and point rows 6-9 and the `EconomySimulation` term at it **now**, while it still equals the top tier, so task 3 changes no pace. Rename nothing the player sees yet.
- **Tests:** full suite green with no expectation changed (proves no behaviour moved).

### Task 2 — The migration function, written and tested but not wired

- `GameStore.expandedAnimalTier` and `expandAnimalTiersForFifteenTierChains(_:)` per §5.1-§5.2, not yet called from `finishMigration`, no version bump.
- **Tests:** §8.2 case 1, plus a direct JSON-dictionary test of the walker for every §5.2 path and for case 4's exclusions (no load, since nothing is wired).

### Task 3 — Fifteen tiers, atomically (content + art rename + migration wired + bump)

- `tierNames` (§4.1), `animalTierAppearance` (§4.2), doc comments (`AnimalSpecies.swift:124-132`, `ItemChain.swift:572-573`, `:2236`).
- Rename the 45 top-era imagesets tier09-11 → tier12-14 (§4.3), by script, and check the result.
- Wire the expand in `finishMigration` (§5.3), Q6's pre-v28 choice, bump to vN, history comment.
- Store cap per Q4 if (b) or (c) (`DogTagStore.makeStock`, constant in `AnimalSpecies.swift`).
- **Tests:** §8.1 (content), §8.2 cases 2-8; `EconomyTests` green with unchanged ratio numbers (attach the before/after report to the PR).
- **Simulator check:** a migrated v(N−1) save shows Dire Wolf with its art at "Tier 13 of 15"; a fresh game; the chain viewer lists 15 rows with SF Symbols at 10-12 (1-based).

### Task 4 — Economy check and report

- §6.6: model term, full report to the owner, map build-out. No rule change unless the owner asks after seeing the numbers.

### Task 5 — Art drop-in (after owner task 5.2 delivers)

- Add the 45 imagesets under the §4.3 names; the generic resolver picks them up with no code (`AnimalSpecies.swift:216-227`). Extend the art test to tiers 9-11. Regenerate `docs/PawSanctuary_Graphical_Element_Inventory.xlsx`.

### Task 6 — Docs

- `PawSanctuary_GDD.md` tier tables (stale since Phase 2b, `f646ae9` message); Feature Parity Audit / Comparison rows for chain length; `Revision_Plan` W5 to done. The Alignment Plan's D2b supersession note is the owner's or the project manager's to record, not a build task.

Tasks 1, 2 and 5 can run in parallel with other lanes (they touch few files). Task 3 touches `GameStore.swift`, `AnimalSpecies.swift` and the asset catalogue, so it must not overlap another schema bump: take the version number at branch time.

---

## 10. Out of scope

- Moving the order, daily-task or quest tier caps (Q1; waits on R10).
- Non-uniform chain lengths per family, as the references have (§3.1).
- New art (owner task 5.2); this spec only specifies names and the rename.
- Sub-object, supply, material, currency, toolbox, superpower and Second Chances chains.
- A discovery collection or `?` slots (D13).
- Repricing the Dog Tag store, the wildcard, bubbles or sell rates beyond Q4's cap.
- Fixing the pre-v18 off-by-one (§5.5 item 5, §11 item 1), the stranded Ambassador caption (§11 item 3), or the first-line-only order readers (§11 item 5). Each is noted for its own task.
- Parallel Board content.
- Editing the Alignment Plan's decision log.

---

## 11. Spec vs code and doc discrepancies found

1. **Pre-v18 saves never get the 10→9 shift.** Only `version == 17` dispatches to `migrateV17toV18` (`GameStore.swift:690`); v8 to v16 go through `migrateByInjecting` (`:664-689`), and `finishMigration` has no `< 18` step (`:832-846`). Those saves keep pre-v18 indices, one tier high. Unrelated to this spec; flagged because CLAUDE.md says to look at v8-v24 first for save bugs.
2. **The Phase 2b remap does not check `lastWallChainID`** before rewriting `lastWallTier` (`GameStore.swift:1112-1116`). Harmless today (only animal spawns record a tier), but this spec's expand checks it.
3. **"Ambassador" means two tiers.** `animalTierAppearance(8)` and `RescueStage.ambassador` call tier 8 "Ambassador" (`AnimalSpecies.swift:825`, `:313`), while the info bar, the celebration banner, the quest card and the trio exchange call the top tier (11) "Ambassador" (`MergeBoardViewModel.swift:717-718`, `:2557`; `MergeBoardView.swift:1225`). `RescueStage.ambassador`'s comment "top tier" has been false since chains outgrew 9 tiers. Q3 (b) would make tier 11 the Ambassador tier, which still disagrees with the tier-8 stage label; the label fix is a separate copy task.
4. **`animalChainTopTier` is a literal** (`AnimalSpecies.swift:2237`) though `maxTier` is derived everywhere else; Phase 2b's own acceptance criterion was "no hardcoded top-tier reference". Task 1 fixes it.
5. **First-line-only readers.** `isBubbleEligibleForQuestOrOrder` checks `wantedChainID`/`wantedTier`, the first line of a basket only (`AnimalSpecies.swift:2221-2222`), like `maybeShowSellVsOrderNudge` (already noted in `Spec_HeldItemOrders.md` §2 item 5). Unrelated to tier count.
6. **The legendary quest comment is stale in waiting.** "Target those top three tiers directly so the endgame of every chain is a reachable objective" (`QuestCoordinator.swift:178-180`): after this change 9 to 11 are not the top three; and since D14 §6 tier 11 is already never reached (cap 10 at L51+), so one of the three goals is dead today.
7. **The Triage's description is slightly off.** It says the deletion "renumbered old 12–14 to 9–11" (true) and that 45 names "are in git history" (true, `f646ae9`), but the restored tiers' **art** never existed in the repository: art arrived on 21 Aug (`f73aa63`) for the 12-tier chain only, so restoring needs 45 new images plus 45 renames, not a recovery.
8. **Sanctuary Star claimed thresholds are in `UserDefaults`, not `GameState`** (`MilestoneManager.swift:65-`), so they are not in the save, not in iCloud and not covered by `PersistenceTests`. Not a tier issue; noted because it sits on the Ambassador path this spec touches.
9. **`assumedDeepestTier(level) = orderTierCap(level)`** (`EconomySimulation.swift:866-868`) assumes the deepest tier a player has merged equals the order cap. With three extra tiers above the cap, real players can be deeper than the model assumes, which matters only for deepest-relative rules (the store band, §6.4; recirculation is capped absolutely at 6). Q4 (b) removes the store's exposure.
10. **CLAUDE.md lists `Spec_Phase2b_TwelveTiers.md` nowhere and the GDD tier tables have been stale since July** (`f646ae9`'s message says so). Task 6.

---

## 12. Open questions for the owner

1. **Q1. Order, daily-task and quest tier caps on a 15-tier chain?** (a) Keep today's numbers: orders reach at most tier 11 of 15, tiers 12-15 are aspirational, and the economy model is unchanged; (b) scale the caps with the chain (×14/11): roughly an 8× rise in top-band demand, breaks every band; (c) keep (a) now and re-sweep after recording R10 (§3.3). **Recommend (a), with (c)'s recording added to `Recording_Guide.md`.** It is the references' pattern as far as measured, and it costs no retune.
2. **Q2. How saved 12-tier items map.** (a) Keep what the player sees: 9-11 → 12-14 (Dire Wolf stays Dire Wolf, worth 8× more); (b) keep the index: no tier remap at all, a held Dire Wolf becomes an Alpha (same worth) and the art and top-tier status change under the player; (c) move them to 9-11 *and* shift values back by trading in (not offered: invents a mechanic). **Recommend (a):** lossless, the inverse of `f646ae9`, and only test saves exist.
3. **Q3. What counts as an "Ambassador"** (celebration rewards, Ambassador quest, trio exchange, Sanctuary Stars)? (a) The true top tier (14): every one of those paces falls 8×; (b) a fixed Ambassador tier, 11 (today's top): every pace stays exactly as today, tier 14 gets the badge and a celebration banner but no new reward; (c) tier 8, matching the "Ambassador" stage label: all of them get 8× faster, a retune. **Recommend (b):** D9 says do not slow retention rewards for nothing, and it keeps the top tiers aspirational.
4. **Q4. Dog Tag store band.** (a) Leave it relative to the deepest tier (up to tier 13 for 69 tags); (b) cap stock at tier 10, today's effective ceiling, so no new value enters; (c) cap at the player's order cap (`maxAchievableOrderTier`), so the store only sells what an order can ask for. **Recommend (b):** keeps the store's economics exactly as today (D9, D13); (c) is the more principled long-term rule but lowers today's L31-40 ceiling from 10 to 8.
5. **Q5. The legendary quest goals at tiers 9, 10, 11.** (a) Keep the numbers (they become upper-mid tiers, still capped); (b) retarget them to 12-14 (never reachable under the cap, so in effect remove them); (c) retarget to the Ambassador tier from Q3. **Recommend (a):** no change in what players are asked, and it matches the mid-chain rule.
6. **Q6. Saves from before v28** (which hold 15-tier indices). (a) Identity: stop squeezing them to 12, lossless, rewrites a July migration and three tests; (b) compose: keep the July squeeze and expand after it, their 9-11 stay at 8 as today, no existing migration code touched. **Recommend (b):** least risk to the oldest, least-proven part of the chain (CLAUDE.md), for a loss only July test saves see.
7. **Q7. Ship before the art?** (a) Yes: tiers 9-11 show the family's SF Symbol until task 5; (b) hold task 3 until all 45 images exist. **Recommend (a):** the fallback already exists and is how the game ran before 21 Aug; the migration is better landed while few saves exist.

Also for the owner to know, not to decide: a test save at tier 9-11 today becomes 8× more valuable on load (Q2 a); the top tier now takes ~22 days of total income, by design; and the art is 45 new images plus a scripted rename of 45 existing ones.
