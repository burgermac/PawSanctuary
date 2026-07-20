# PawSanctuary — Feature Expansion Integration Plan
**Prepared:** June 2026  
**Scope:** 15 families × 15 merge stages + per-family sub-object chains + power-up consumables  
**Audience:** Implementation sessions — assumes full codebase familiarity

---

## A. Current State Assessment

### How animal families/chains are currently defined

**`AnimalSpecies.swift`** is the authoring source. The `AnimalSpecies` enum has 15 cases (`.dog`, `.cat`, `.rabbit`, `.bird`, `.hamster`, `.turtle`, `.fox`, `.owl`, `.fish`, `.lizard`, `.ferret`, `.parrot`, `.pony`, `.hedgehog`, `.guineaPig`), each mapped to a family name via `var name: String`. Each case also declares:
- `tierNames: [String]` — **exactly 9 entries** per family, one per `RescueStage`
- `spawnerName`, `spawnerSFSymbol`, `sfSymbol`, `tintColor`

**`ItemChain.swift`** builds the live chain objects. `ContentRegistry.makeAnimalChain(_:)` zips `RescueStage.allCases` (9 cases) with `AnimalSpecies.tierNames` (9 entries) to produce a 9-tier `MergeChain`. The chain ID is `"animal.\(species.rawValue)"` — a stable string stored in saves. `RescueStage.rawValue` (1–9) drives `scoreValue` and `xpValue`.

**Implication:** The current chain length (9) is structurally enforced by `RescueStage.allCases.count`. Expanding to 15 requires decoupling tier count from `RescueStage`.

### How the merge board works

- **Grid:** 9 rows × 7 cols = 63 cells. Rows 7 and 8 start locked (unlock at levels 3 and 8).
- **`BoardCell`** holds either a `BoardItem?` (a merge tile) or a `ProducerTile?` (a spawner), never both.
- **`BoardItem(chainID, tier)`** is the only thing persisted. Display data is looked up from `ContentRegistry` at runtime. Non-Codable colors live in the registry, not in saves.
- **Merge logic** (`MergeBoardViewModel.attemptMergeOrMove`): two items with the same `chainID` and same `tier` merge into `tier + 1`. Top tier check: `next == chain.maxTier`. This is fully data-driven and already handles any chain length — extending to 15 tiers requires only a new chain definition.
- **Spawner model:** `ProducerLevel.familySpawner` (rawValue 20) is the per-family spawner. It costs kibble (=`spawnMultiplier`), has no charges, always drops the family's animal chain at `tier = min(spawnMultiplier - 1, maxTier)`. There is no sub-object drop logic yet.
- **Top-tier celebration** fires in `triggerTopTierCelebration` when reaching `chain.maxTier`. Awards coins, a toolbox, increments `ambassadors`, triggers `MilestoneManager`.

### How inventory is currently structured

- **Animal inventory:** 18 slots (6 free + 2 × 6 purchasable rows). Items routed by `chain.category == .animal`.
- **Tool/material inventory:** 18 slots. Items routed by `category == .tool` or `.material`.
- **Producer storage:** one designated slot per `ProducerLevel.rawValue` + 4 overflow slots.
- Inventory capacity is fixed at 18 slots total; no tab-based separation exists in the current code (the two tabs are visual — they share `InventoryStore`). The GDD v2.0 mentions a "3-tab inventory" but this is not yet implemented in code.

### How quests/orders currently work

- **`QuestGoal`** has four cases: `.mergeAny`, `.mergeInChain(ChainID, count)`, `.reachTier(ChainCategory, tier, count)`, `.spawnBase`.
- `.reachTier(.animal, tier: N, count: C)` uses `RescueStage(rawValue: N + 1)` to get stage labels — meaning it only resolves cleanly for tiers 0–8 (the existing 9 stages).
- **`AdoptionBoard.generateOrder`** uses `RescueStage` cases directly to weight the requested tier. It clamps via `maxAchievableOrderTier(forPlayerLevel:)`, which maps player levels to `RescueStage.xxx.tierIndex` (hardcoded to tiers 0–8).
- **`AdoptionOrder.orderDescription`** and `stageBadgeSymbol` both call `QuestGoal.animalTierSymbol(tier)`, which resolves via `RescueStage(rawValue: tier + 1)` — will return `nil`/fallback for tiers 9–14.

### How map expansion currently works

**`SanctuaryMap.swift`** defines `sanctuaryAreas: [SanctuaryArea]` — 6 areas in sequential unlock order:
1. Antique Dog House — tutorial, no new spawner (dog is the day-one starter)
2. Scratching Post — unlocks `.cat` (Felines)
3. Garden Hutch — unlocks `.rabbit` (Lagomorphs)
4. Decorative Birdhouse — unlocks `.bird` (Avians)
5. Wooden Burrow — unlocks `.hamster` (Rodents)
6. Heated Rock — unlocks `.turtle` (Reptiles)

Each area costs tier-5 material combinations and has 2 upgrade tiers that grant `UpgradeBonus` passives. Build costs are hardcoded to material tier 5 (top of the 6-tier chains). The remaining 9 families (Ursids, Aquatics, Amphibians, Marsupials, Primates, Equines, Pachyderms, Bovines, Cervids) have no map areas defined.

**Note:** Aquatics (`.fish`) has a separate milestone unlock path at 50 ambassador-tier completions (`placeRareSpeciesSpawnerForMilestone`). This conflicts with also adding a map area for Aquatics — one path must be chosen.

### What `sanctuaryStars` / ambassador system currently does

"Ambassadors" (`ambassadors: Int`) counts how many times any animal chain has reached its top tier. This feeds `MilestoneManager`, which fires overlay rewards at thresholds 5/15/30/50. The 50-star milestone has a special hardcoded side effect: it calls `placeRareSpeciesSpawnerForMilestone()` which unlocks Aquatics. The `ambassadorQuestProgress` counter drives a standing "collect 3 top-tier animals → 500 coins" repeatable quest. With 15-tier chains, the top tier moves from index 8 to index 14 — the `isTopTier` computed property on `BoardItem` correctly uses `tier >= chain.maxTier`, so the ambassador counter will still fire at the correct tier.

### Gaps and conflicts between current architecture and new requirements

| Gap / Conflict | Location | Severity |
|---|---|---|
| `RescueStage` (9 cases) enforces 9-tier chain length | `AnimalSpecies.tierNames`, `makeAnimalChain`, `AdoptionBoard`, `QuestGoal` | **Critical** — must be decoupled |
| `tierNames` in `AnimalSpecies` only has 9 entries | `AnimalSpecies.swift` | **Critical** — must expand to 15 |
| `maxAchievableOrderTier` caps at tier 8 (`RescueStage.ambassador.tierIndex`) | `AnimalSpecies.swift` | **High** — breaks orders for tiers 9–14 |
| `AdoptionBoard.generateOrder` uses `RescueStage` cases for weighting | `AdoptionBoard.swift` | **High** — needs new weighting table |
| `QuestGoal.animalTierLabel/Symbol/Color` fall back to `RescueStage(rawValue: tier+1)` | `AnimalSpecies.swift` | **High** — returns nil for tiers 9–14 |
| `sellValue(forTier:)` is a 9-entry hardcoded array | `MergeBoardViewModel.swift` | **Medium** — needs 15 entries |
| No sub-object chain category | `ItemChain.swift` | **High** — need new `ChainCategory` |
| No drop logic in family spawner | `MergeBoardViewModel.activateProducer` | **High** — new spawn path needed |
| No power-up consumable model | New file needed | **High** |
| No pity timer state | `GameState` | **Medium** — new fields needed |
| 9 families have no map areas | `SanctuaryMap.swift` | **Medium** — additive, no conflicts |
| Aquatics has dual unlock paths (milestone + potential map area) | `MilestoneManager`, `SanctuaryMap` | **Medium** — decision needed |
| Board may feel cramped with 15-stage chains | `AnimalSpecies.swift` constants | **Low** — configuration question |
| `GameStore.currentVersion = 20` needs a bump | `GameStore.swift` | **Low** — additive migration only |

---

## B. Data Model Plan

### B.1 `AnimalSpecies.swift` changes

**`AnimalSpecies.tierNames` — expand from 9 to 15 entries per family.**

Each array must exactly match the 15 stage names from the reference tables. Example (Canines):
```
["Pup", "Kit", "Houndling", "Terrier", "Spaniel", "Scout",
 "Retriever", "Shepherd", "Husky", "Alpha", "Guardian", "Sentinel",
 "Dire Wolf", "Mythic", "Primordial"]
```
All 15 families × 15 stages must be entered verbatim. This is a pure data edit — no logic changes required in `AnimalSpecies.swift` itself.

**`maxAchievableOrderTier(forPlayerLevel:)` — replace the `RescueStage`-based lookup with a direct tier-index table.** The function signature stays the same (`Int → Int`), but the body must map player levels to 0-based tier indices 0–14. Example mapping (open question: exact level thresholds — see Section E):
```
levels 1–3:  tier 2  (Houndling-equivalent)
levels 4–6:  tier 5  (Scout-equivalent)
levels 7–9:  tier 8  (Husky-equivalent)
levels 10–12: tier 10 (Guardian-equivalent)
levels 13–18: tier 12 (Sentinel-equivalent)
levels 19+:  tier 14 (top tier)
```

**`RescueStage` — keep as-is for now, but stop using it as the authoritative tier count.** Its 9 cases will continue to supply the generic stage colors/symbols used in quest display for tiers 0–8. Tiers 9–14 need new color/symbol assignments added either to `RescueStage` (by adding 6 more cases) or by adding a separate `animalTierColor(Int)` / `animalTierSymbol(Int)` function that handles the full 0–14 range directly. **Recommendation:** Add a standalone `animalTierAppearance(tier: Int) -> (label: String, symbol: String, color: Color)` function in `AnimalSpecies.swift` that switches over all 15 tiers, and replace all call sites of `QuestGoal.animalTierLabel/Symbol/Color` with it. `RescueStage` remains as an authoring artifact but no new gameplay code should reference it.

**`sellValue(forTier:)` in `MergeBoardViewModel.swift` — extend to 15 entries.** Current: `[1,2,5,10,20,50,100,200,500]`. Suggested extension (open question for balancing — see Section E): add tiers 9–14 following the geometric progression: `[..., 1000, 2000, 5000, 10000, 25000, 100000]`. Exact values need Tim's sign-off.

### B.2 `ItemChain.swift` changes

**`ContentRegistry.makeAnimalChain(_:)` — only one line changes.** The `zip(RescueStage.allCases, s.tierNames)` pattern must be replaced with a simple `s.tierNames.enumerated()` loop that assigns score/xp values based on the index rather than `stage.rawValue`. Proposed scale: `scoreValue = (index + 1) * 25`, `xpValue = (index + 1) * xpPerMergeBase`. The badge (`"medal.fill"`) moves from `stage == .ambassador` to `index == 14`.

**New `ChainCategory` cases.** Add two cases to the `ChainCategory` enum:
```swift
case subObject  // per-family 4-stage merge chain (produces power-up on completion)
case powerUp    // power-up consumable (drag onto spawner to apply)
```
These follow the same data-driven pattern: `BoardItem(chainID, tier)` with lookup via `ContentRegistry`.

**New stable ChainIDs for sub-object chains.** One per family, pattern: `"subobject.\(species.rawValue)"`. Example: `"subobject.dog"` for the Canines chain (Biscuit → Bone → Chew Toy → Golden Ball).

**`ContentRegistry.init()` — register sub-object chains.** Add a loop:
```swift
for species in AnimalSpecies.allCases { register(Self.makeSubObjectChain(species)) }
```
Each call to `makeSubObjectChain(_:)` produces a 4-tier `MergeChain` in category `.subObject` using the stage names from the reference table. The top tier (stage 4) is the power-up item.

**New `makeSubObjectChain(_:)` static method.** Returns a `MergeChain` with 4 tiers. The tier-3 item (index 3) gets `badge: "bolt.fill"` to indicate it's the power-up. The `name` of tier 3 is the power-up name (e.g., "Golden Ball" for Canines). All four tiers share the family's `tintColor`.

**Power-up drop rate table — new file: `SubObjectSystem.swift`.** This file should not exist yet and must be created. It houses:

- `SubObjectRarity` enum (four cases: `.speed`, `.mapSupplies`, `.spawnerRefill`, `.highTierDrop`) with associated drop weights (60/25/10/5).
- `PowerUpEffect` enum with the four effect types and their parameters (2× speed 30s; refill; force tier 2–3 output; map supplies).
- `SpawnDropResult` enum: `.animal(tier: Int)` or `.subObject(chainID: ChainID, tier: Int)`.
- `SubObjectDropConfig` struct: base animal drop chance (configurable), sub-object drop rates, pity counter thresholds.
- A `PityState` struct (Codable): `subObjectSpawnsSinceLastRare: Int`, `subObjectSpawnsSinceLastEpic: Int`, pity thresholds (e.g., 30 for Rare guarantee, 60 for Epic guarantee — open question).

**`GameState` additions (new fields for pity state and power-up inventory):**
```swift
// v21 additions
var pityStates: [String: PityState] = [:]     // keyed by AnimalSpecies.rawValue
var powerUpInventory: [BoardItem?]             // dedicated slots for power-up items
```
`powerUpInventory` follows the same `[BoardItem?]` pattern. Initial capacity: 6 slots (one per unlocked family, expandable).

### B.3 New file: `SubObjectSystem.swift`

Responsible for:
1. Resolving what drops when a family spawner fires (animal or sub-object, which rarity).
2. Pity timer logic (per-family counters tracked in `GameState.pityStates`).
3. Applying a power-up effect when a tier-3 sub-object is dragged onto a spawner.

The drop resolution function signature:
```swift
func resolveSpawnerDrop(species: AnimalSpecies,
                        pityState: inout PityState,
                        spawnTier: Int) -> SpawnDropResult
```

The power-up apply function signature (called in `MergeBoardViewModel`):
```swift
func applyPowerUp(effect: PowerUpEffect, to producer: inout ProducerTile)
```

For **Speed Burst 2×/30s**: add `speedBurstActive: Bool` and `speedBurstRemaining: Double` to `ProducerTile`. The spawner cooldown is halved while active; the `tickProducers()` loop decrements `speedBurstRemaining`.

For **Spawner Refill**: set `chargesRemaining = producer.level.maxCharges`. For `familySpawner` (unlimited), award a fixed number of free kibble-cost spawns instead.

For **High-Tier Drop Guarantee**: set a flag `nextDropGuaranteedHighTier: Bool` on `ProducerTile`. On next activation, force `spawnTier` to 2 or 3 regardless of `spawnMultiplier`.

For **Map Supplies**: award a random mix of wood/metal/cement items directly to `toolInventory` (bypass the board).

### B.4 Summary: what changes vs. what is new

| File | Action | Notes |
|---|---|---|
| `AnimalSpecies.swift` | **Modify** — expand `tierNames` to 15 entries; replace `maxAchievableOrderTier`; add `animalTierAppearance(tier:)` | Major data edit, no structural change |
| `ItemChain.swift` | **Modify** — update `makeAnimalChain` loop; add `.subObject`/`.powerUp` to `ChainCategory`; add `makeSubObjectChain`; register sub-object chains in `ContentRegistry.init()` | Additive; no existing chain IDs change |
| `GameStore.swift` | **Modify** — bump `currentVersion` to 21; add `migrateV20toV21` (inject `pityStates: [:]`, `powerUpInventory: []`) | Additive migration only |
| `MergeBoardViewModel.swift` | **Modify** — update `activateProducer` for sub-object drops; add power-up drag-apply handler; extend `sellValue(forTier:)`; add `tickSpeedBursts()` | Core gameplay changes |
| `AdoptionBoard.swift` | **Modify** — replace `RescueStage`-based weighting with direct tier-index weighting | Behaviorally transparent |
| `SanctuaryMap.swift` | **Modify** — add 9 new `SanctuaryArea` entries for remaining families | Purely additive |
| `InventoryStore.swift` | **Modify** — add `powerUpInventory` slot management | Additive |
| `AnimalSpecies.swift` constants | **Modify** — update `sellValue` to 15 entries | Numbers TBD |
| `SubObjectSystem.swift` | **Create new** | All pity/drop logic lives here |
| `ProducerTile` (in `AnimalSpecies.swift`) | **Modify** — add `speedBurstActive`, `speedBurstRemaining`, `nextDropGuaranteedHighTier` | Requires custom Codable + migration |
| `QuestGoal.animalTierLabel/Symbol/Color` | **Modify** — reroute to `animalTierAppearance(tier:)` | 3 call-site changes |

---

## C. Phased Implementation Plan

### Phase 1 — 15-Tier Animal Chains (foundation, no new content type)

**What gets built:**
- `AnimalSpecies.tierNames` expanded to 15 entries per family (all 15 families × 15 stage names from the reference table).
- `ContentRegistry.makeAnimalChain` loop changed from `zip(RescueStage.allCases, tierNames)` to `tierNames.enumerated()`.
- `animalTierAppearance(tier: Int)` added to `AnimalSpecies.swift`; `QuestGoal.animalTierLabel/Symbol/Color` rerouted.
- `maxAchievableOrderTier(forPlayerLevel:)` updated to cover tiers 0–14.
- `AdoptionBoard.generateOrder` weighting table updated for 15 tiers.
- `sellValue(forTier:)` extended to 15 entries.
- `GameStore.currentVersion` bumped to 21, `migrateV20toV21` adds only `pityStates: [:]`.

**Files modified:** `AnimalSpecies.swift`, `ItemChain.swift`, `AdoptionBoard.swift`, `MergeBoardViewModel.swift`, `GameStore.swift`

**Files created:** None

**Player-facing result:** Animals can now merge through 15 stages. Families show their proper stage names at every tier. Adoption orders and quests reference the correct tier labels for all 15 stages. Existing boards with tier 0–8 items continue to work unmodified (saved tiers are still valid indices; they just aren't at max tier anymore).

**Stable before Phase 2:** All persistence tests pass. A fresh game and a loaded save both correctly display tier names at tiers 0–14. Adoption orders generate for all 15 tiers based on player level. Ambassador celebration still fires at `chain.maxTier` (now tier 14).

---

### Phase 2 — Sub-Object Chain Data + Registry

**What gets built:**
- `ChainCategory` gains `.subObject` and `.powerUp` cases.
- `SubObjectSystem.swift` created with `SubObjectRarity`, `PowerUpEffect`, `SpawnDropResult`, `SubObjectDropConfig`, `PityState`.
- `ContentRegistry.makeSubObjectChain(_:)` added; all 15 sub-object chains registered.
- `GameState` gains `pityStates: [String: PityState]` and `powerUpInventory: [BoardItem?]` (v21 — can merge with Phase 1 bump if Phase 1 and 2 ship together).
- `InventoryStore` gains `powerUpInventory` slot management and a routing rule in `addItem(_:)` for `.powerUp` items.

**Files modified:** `ItemChain.swift`, `SubObjectSystem.swift` (new), `GameStore.swift`, `InventoryStore.swift`

**Files created:** `SubObjectSystem.swift`

**Player-facing result:** Sub-object chains exist in the registry and can appear on the board if manually placed (debug only at this stage). The power-up inventory exists in the UI. No actual drops yet.

**Stable before Phase 3:** Build is green. `ContentRegistry` contains 15 animal chains, 15 sub-object chains, 3 supply chains, 3 material chains, 1 toolbox chain. Round-trip save/load with `pityStates` and `powerUpInventory` passes persistence tests.

---

### Phase 3 — Sub-Object Drop Logic in Family Spawners

**What gets built:**
- `MergeBoardViewModel.activateProducer` updated: when a `familySpawner` fires, call `SubObjectSystem.resolveSpawnerDrop(species:pityState:spawnTier:)` to determine whether the output is an animal or a sub-object.
- `PityState` per-species counters tracked in `GameState.pityStates`, updated after every spawn.
- Sub-object items placed on the board exactly like animal items (same `BoardItem` model, different `chainID`).
- Sub-object merge logic works automatically (the existing merge code is chain-agnostic).
- When a sub-object reaches tier 3 (the power-up), merging two of them produces the `.powerUp` item, which routes to `powerUpInventory`.
- Drop rate display added to spawner info text in `selectedItemInfo`.

**Files modified:** `MergeBoardViewModel.swift`, `SubObjectSystem.swift`, `GameStore.swift` (pityStates capture/restore)

**Player-facing result:** Tapping a family spawner now has a chance to produce sub-objects (Biscuits, Bones, etc.) instead of animals. Merging sub-objects through 4 stages produces a power-up item in the power-up inventory. Pity timers prevent long streaks without Rare/Epic drops.

**Stable before Phase 4:** All 15 families produce the correct sub-object types. Drop rates observable in debug (print statements or a debug overlay). Pity timers advance and reset correctly across sessions.

---

### Phase 4 — Power-Up Application Mechanics

**What gets built:**
- `ProducerTile` gains three optional effect fields: `speedBurstActive: Bool`, `speedBurstRemaining: Double`, `nextDropGuaranteedHighTier: Bool`. Custom `Codable` updated with `decodeIfPresent` for all three (backward-compatible).
- `tickProducers()` in `MergeBoardViewModel` extended to decrement `speedBurstRemaining` and clear `speedBurstActive` when it reaches zero.
- `activateProducer` respects `speedBurstActive` (halve effective cooldown) and `nextDropGuaranteedHighTier` (force higher spawn tier, then clear the flag).
- A new gesture/interaction: dragging a power-up item from `powerUpInventory` onto a spawner calls `SubObjectSystem.applyPowerUp(effect:to:)`.
- Map Supplies power-up: award a random `[BoardItem]` lot directly to `toolInventory` (same pattern as `buildToolboxLot`).
- Spawner Refill: for unlimited `familySpawner`, award a fixed kibble credit instead of restoring charges.
- `CellView` / spawner rendering: add a visual indicator (glow or badge) when `speedBurstActive` or `nextDropGuaranteedHighTier` is active.

**Files modified:** `AnimalSpecies.swift` (`ProducerTile`), `MergeBoardViewModel.swift`, `SubObjectSystem.swift`, `CellView.swift`

**Player-facing result:** Players can drag power-ups from their power-up inventory onto any family spawner. Visual feedback confirms the buff is active. Speed Burst visibly accelerates the spawner ring. High-Tier Guarantee produces a noticeably better drop on the next spawn.

**Stable before Phase 5:** All four power-up effects apply correctly. `speedBurstRemaining` decrements in real time and across offline progress. Save/load preserves active buffs. A Speed Burst that is active when the app closes resumes correctly on reopen.

---

### Phase 5 — Map Area Expansion (9 remaining families)

**What gets built:**
- 9 new `SanctuaryArea` entries appended to `sanctuaryAreas` in `SanctuaryMap.swift`, unlocking the remaining families: Ursids (`.owl`), Aquatics (`.fish` — see open questions), Amphibians (`.lizard`), Marsupials (`.ferret`), Primates (`.parrot`), Equines (`.pony`), Pachyderms (`.hedgehog`), Bovines (`.guineaPig`), Cervids (`.fox`).
- Each area has a `newFamilySpawner` reward, 2 upgrade tiers with new `UpgradeBonus` fields (or reuse existing fields with different magnitudes).
- `UpgradeBonus` may need new fields depending on what bonuses the new areas grant (open question — see Section E).
- Build cost scaling: later areas cost higher-tier materials and larger quantities, or a mix of material tiers, to reflect the late-game pacing.
- If the Aquatics milestone path is retired (see Section E), `placeRareSpeciesSpawnerForMilestone` in `MergeBoardViewModel` becomes a no-op or is removed; the milestone at 50 stars grants a different reward.

**Files modified:** `SanctuaryMap.swift`, `MergeBoardViewModel.swift` (if Aquatics milestone changes), `AnimalSpecies.swift` (if new `UpgradeBonus` fields needed)

**Player-facing result:** All 15 families are unlockable through the map. Players have a clear late-game build path extending far beyond the current 6 areas.

**Stable before shipping:** Each new area's spawner placement, chain unlock, and upgrade bonuses work end-to-end. No family spawner can appear on the board before its area is built (guarded by `unlockedChainIDs` check, which is already enforced).

---

## D. Risk & Conflict Assessment

### D.1 Energy wall / kibble economy

The current cost to spawn is `spawnMultiplier` kibble (1, 2, 4, or 8). With 15-stage chains, players need roughly 14 successive merges per chain (vs. 8) to reach top tier — 75% more merges per ambassador. If the kibble cost and regen rate are unchanged, players will hit the energy wall more frequently and progress will slow significantly. **Recommendation:** Either (a) increase the regen cap from 100 or reduce spawn cost for higher-multiplier modes, or (b) accept the slower pace as intentional for a deeper game. This is a balance decision, not a code conflict, but it must be decided before Phase 3 ships to players.

### D.2 Existing inventory logic

`InventoryStore.addItem(_:)` currently routes `.tool` and `.material` to `toolInventory`, everything else to `inventory`. Adding `.subObject` and `.powerUp` categories means this switch needs two new cases. Sub-objects should route to the main animal inventory (they live on the merge board). Power-ups should route to the new `powerUpInventory`. The routing logic is simple but must be explicit — if omitted, sub-objects will silently route to the animal inventory, which is probably acceptable as a default, but power-ups must go somewhere dedicated.

### D.3 Current quest system

`QuestGoal.reachTier(.animal, tier: N, count: C)` where N ≥ 9 will produce a label like "Tier 10" because `RescueStage(rawValue: N + 1)` returns `nil` for N ≥ 9. This is visually broken but not a crash. The fix (Phase 1) is the `animalTierAppearance(tier:)` function. However, **any existing saved quests with `.reachTier(.animal, tier: ≥ 9)` would never exist in the wild** (current chains only go to tier 8), so there is no migration concern here. New quests generated post-Phase-1 will use the correct labels. No migration of saved quest goals is needed.

### D.4 Ambassador / star system

`MilestoneManager` hardcodes 4 milestones at 5/15/30/50 ambassador counts. With 15-stage chains, reaching the top tier (tier 14 = "Primordial"/"Apex"/etc.) is significantly harder than reaching tier 8 was. The milestone thresholds may need to be raised to remain meaningful mid-game checkpoints rather than trivial early ones. This is a balance question, not a code conflict. The code itself works correctly for any threshold value.

The 50-star milestone (`placeRareSpeciesSpawnerForMilestone`) hardcodes Aquatics as the unlocked family. If Aquatics is also unlocked via a map area in Phase 5, this creates a duplicate unlock path. The function already guards with `if !unlockedChainIDs.contains(chainID)`, so a double-trigger is safe but confusing. The question of which path survives needs a decision (see Section E, open question 4).

### D.5 Save data migration

Existing saves at v20 have animal board items with tiers 0–8. After Phase 1, those are still valid — they just represent a position in a longer chain. No tier-shifting migration is needed (unlike v17→v18, which had to shift tiers down by 1 because a tier was removed). The v21 migration is purely additive: inject `pityStates: [:]` and `powerUpInventory: []`. This is handled by `migrateByInjecting(defaults:into:)` — the simplest possible migration path.

**Risk:** `ProducerTile` gains new optional fields in Phase 4. These must use `decodeIfPresent` in `ProducerTile`'s custom `init(from:)`, which already exists and uses this pattern for the `species` field. Adding to an established pattern is low-risk.

### D.6 Board size and 15-stage chain depth

The current board is 9×7=63 cells. With 15 stages, a player working a single family needs 14 merges to reach top tier (compared to 8). Two items of the same tier require 2^(tier) spawns from tier 0 — reaching tier 14 requires 2^14 = 16,384 spawns theoretically, though in practice players merge continually. The board size itself is not a hard blocker — Travel Town uses comparable board sizes with long chains — but **board management becomes the central skill**. The existing inventory system (18 slots + 2 unlockable rows) is probably insufficient for 15-stage chains across 15 families. Whether to expand inventory capacity or add a dedicated "family staging area" tab is an open question (see Section E).

---

## E. Open Questions

These require Tim's decisions before the affected phase can be implemented.

**1. Does the existing 9-tier chain get replaced or extended to 15?**
The reference table shows new stage names at positions 1–15, but the current code has stages at positions 1–9. For Canines the current 9 are: Pup, Kit, Terrier, Spaniel, Retriever, Shepherd, Husky, Wolf, Dire Wolf. The reference table has 15: Pup, Kit, Houndling, Terrier, Spaniel, Scout, Retriever, Shepherd, Husky, Alpha, Guardian, Sentinel, Dire Wolf, Mythic, Primordial. The first two match (Pup, Kit), then they diverge. **Decision needed:** Are existing players migrated from the 9-tier names to the 15-tier names (a content change to existing stages), or does the game start fresh with 15 tiers? If existing stages change names, no tier-shifting migration is needed in the save — only the display strings change (they come from the registry, not from saves). But players with saved tiers 0–8 will see those same items renamed. If that's acceptable, no migration logic is needed at all. If it's not acceptable, a data freeze on the existing 9 names is needed.

**2. Kibble economy rebalancing for 15-stage chains.**
With 75% more merges per ambassador, does the regen cap (currently 100), regen rate (1 per 120s), and spawn cost (1–8 kibble) need adjustment? Specifically: (a) Should the regen cap increase for late-game players? (b) Should family spawners for unlocked higher-era families cost less kibble to incentivize exploring them? (c) Should the sub-object drop rate reduce the effective kibble-per-progression-step by providing occasional free value?

**3. Sell value scale for tiers 9–14.**
The current scale stops at tier 8 → 500 coins. What is the sell value for each of tiers 9–14? The geometric progression of the existing scale suggests: 1,000 / 2,000 / 5,000 / 10,000 / 25,000 / 100,000 — but this makes the top tier extremely valuable, which affects the coin economy and the weekly goal system.

**4. Aquatics (`.fish`) — map area vs. milestone unlock.**
Currently Aquatics is unlocked at 50 ambassador stars via `placeRareSpeciesSpawnerForMilestone`. Phase 5 proposes a map area for Aquatics (as the 9th new area). These two paths conflict in spirit even if the code handles it safely. Options: (a) Keep the milestone unlock and skip a map area for Aquatics; (b) Replace the milestone unlock with the map area unlock; (c) Keep both (milestone is an early access; map area upgrades the spawner). Decision needed before Phase 5.

**5. Pity timer thresholds.**
What is the spawn count after which a Rare sub-object is guaranteed? After which an Epic is guaranteed? These numbers affect both player experience and board management pressure. A tighter pity (lower threshold) makes sub-objects feel more reliable; a looser pity (higher threshold) makes Epic drops feel more special.

**6. Inventory expansion for 15-stage chains.**
Do the current 18 animal inventory slots remain sufficient, or should Phase 1 or Phase 5 add a "family archive" tab with deeper storage? The 3-tab inventory mentioned in GDD v2.0 is not yet coded. Should this be implemented alongside the chain expansion?

**7. Superpower system (GDD v2.1).**
GDD v2.1 introduces per-family superpowers that unlock when a family first reaches Era 3 (Stage 7). This is not in the feature brief for this expansion but the GDD flags it as the most recent addition. Should this system be planned as a Phase 6, or is it out of scope for this implementation cycle?

**8. Sub-object drop probability from spawner (base rate).**
The reference spec gives sub-object rarity split (60/25/10/5) but does not specify what percentage of spawner activations drop a sub-object at all vs. always dropping an animal. Is the 60/25/10/5 the split *among sub-object drops only* (with some base rate determining how often a sub-object drops at all), or does every spawn produce one of: 60% Speed Burst sub-object, 25% Map Supplies sub-object, 10% Refill sub-object, 5% High-Tier sub-object (leaving 0% for animals)? The most balanced interpretation is a configurable base drop rate (e.g., 20% chance of any sub-object per spawn), then the 60/25/10/5 rarity split applies within that 20%. Confirm.

**9. New upgrade bonuses for the 9 new map areas.**
The 6 existing areas each have 2 upgrade tiers granting specific `UpgradeBonus` fields. What bonuses should the 9 new areas grant? The existing `UpgradeBonus` struct has 12 fields — most are already allocated to existing areas. New areas may need new bonus types (e.g., sub-object drop rate bonus, pity timer reduction, power-up duration extension). These require new fields in `UpgradeBonus` and new handling in `recalcActiveBonuses()`.

**10. Board size.**
The GDD v2.0 specifies 6×5=30 cells, but the code has 9×7=63 cells. The GDD is clearly out of date with the implementation. Confirming: the 9×7 board is correct and the GDD needs updating, not the code.

---

## Appendix: File Change Summary

| File | Phase | Type | Estimated scope |
|---|---|---|---|
| `AnimalSpecies.swift` | 1 | Modify | Large (data entry: 15×15 names + 15-tier helpers) |
| `ItemChain.swift` | 1, 2 | Modify | Medium (loop change + new categories/builder) |
| `AdoptionBoard.swift` | 1 | Modify | Small (tier weighting table) |
| `MergeBoardViewModel.swift` | 1, 3, 4 | Modify | Medium (spawner drop path, power-up apply, sell values) |
| `GameStore.swift` | 1, 2 | Modify | Small (version bump + additive migration) |
| `InventoryStore.swift` | 2, 4 | Modify | Small (new category routing + powerUpInventory) |
| `SubObjectSystem.swift` | 2, 3, 4 | **Create** | Medium (drop logic, pity state, power-up apply) |
| `SanctuaryMap.swift` | 5 | Modify | Large (9 new area definitions + upgrade tiers) |
| `CellView.swift` | 4 | Modify | Small (speed burst / high-tier buff indicator) |

---

## F. Decisions Record
**Date:** June 2026

All open questions from Section E resolved. Decisions locked for implementation.

| # | Question | Decision |
|---|---|---|
| Q1 | 9-tier vs. 15-tier chain | **Replace** existing 9-tier chain with the new 15-tier chain (new stage names replace old ones). No tier-shifting migration needed — only display strings change. |
| Q2 | Kibble economy rebalancing | Regen cap increases from **100 → 150 at player level 10**. Sub-object drops provide occasional free value to offset the longer grind. |
| Q3 | Sell values for tiers 9–14 | **1,000 / 2,000 / 5,000 / 10,000 / 25,000 / 100,000** (continues geometric progression from tier 8 → 500). |
| Q4 | Aquatics unlock path | **Option B — replace milestone unlock with map area.** Remove `placeRareSpeciesSpawnerForMilestone()` for Aquatics; the 50-star milestone awards a different reward. |
| Q5 | Pity timer thresholds | **30 spawns** guarantee a Rare sub-object; **60 spawns** guarantee an Epic. Sustained gameplay engagement prioritized over IAP pressure. |
| Q6 | Inventory expansion | Build materials auto-merge and are held in a **limitless** inventory tab (no slot cap). Earlier merge stages await additional materials in the same tab. Sell-for-coins feature already implemented. Both confirmed resolved. |
| Q7 | Superpower system | **Deferred to Phase 6.** Added to TODO.md. |
| Q8 | Sub-object base drop rate | **20% base rate** per spawner tap produces a sub-object; the **60/25/10/5 rarity split** applies within that 20%. Remaining 80% of taps produce animals normally. |
| Q9 | New upgrade bonuses | New `UpgradeBonus` fields required: **sub-object drop rate bonus**, **pity timer reduction**, **power-up duration extension**. Requires new fields in `UpgradeBonus` struct and handling in `recalcActiveBonuses()`. |
| Q10 | Board size | **9×7 = 63 cells confirmed.** GDD to be updated (currently states 6×5 = 30 cells). Code is correct as-is. Added to TODO.md. |
