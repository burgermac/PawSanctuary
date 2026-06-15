# Phase 0 — Generalized Item/Chain Model + Content Registry

**Goal:** Replace the hardcoded `MergeItem(species, stage)` model with a data-driven
`BoardItem(chainID, tier)` model backed by a single content registry — so that
future content (new chains at level 50, tools, materials, spawners) is *authored as
data*, not written as code.

**Non-goal for Phase 0:** No new gameplay. Animal play must be byte-for-byte identical
after the refactor. New chains, finite spawner charges, tools, and the map/area system
are Phases 1–4 — but this phase makes all of them cheap to add.

---

## 1. Why

Today everything is `AnimalSpecies (8) × RescueStage (10)` — one conceptual chain
repeated per species, with merge/spawn/order/quest/spotlight logic hardwired to those
two enums (~120 references across 6 files). You cannot express "a Building Planks chain"
or "a Medical Supplies chain" without inventing parallel enums and duplicating all that
logic. The genre (Travel Town / Tasty Town) is built on *many independent ordered chains*.
Phase 0 makes "a chain" a first-class, data-defined thing.

---

## 2. The new core types

```swift
typealias ChainID = String          // STABLE id, e.g. "animal.dog", "material.plank"

enum ChainCategory: String, Codable, CaseIterable {
    case animal      // the rescue chains (current gameplay)
    case spawner     // producers — Phase 1 makes them finite/charge-based
    case tool        // Phase 3
    case material    // Phase 3
}

/// One rung of a chain. NOT persisted — looked up from the registry at runtime,
/// so it can hold non-Codable `Color` directly.
struct ChainTier {
    let name: String          // "Groomed Dog"
    let shortLabel: String    // "Groomed"  (fits a 62pt cell)
    let symbol: String        // SF Symbol
    let color: Color          // tier accent
    let tint: Color?          // secondary tint (species colour for animals)
    let badge: String?        // e.g. "medal.fill" on the top tier
    let scoreValue: Int       // score awarded when an item REACHES this tier
    let xpValue: Int          // xp awarded likewise
}

struct MergeChain: Identifiable {
    let id: ChainID
    let category: ChainCategory
    let displayName: String
    let tiers: [ChainTier]    // ordered; index 0 = base item
    var maxTier: Int { tiers.count - 1 }
}
```

### The board item (persisted)

```swift
struct BoardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var chainID: ChainID
    var tier: Int
}
```

The **save only ever stores `chainID` (String) + `tier` (Int)** — never display data.
All names/icons/colours come from the registry at runtime. This is what keeps saves
tiny and survivable across content additions.

### Registry — the single source of truth

```swift
struct ContentRegistry {
    static let shared = ContentRegistry()
    private(set) var chains: [ChainID: MergeChain]

    func chain(_ id: ChainID) -> MergeChain?
    func tier(_ id: ChainID, _ t: Int) -> ChainTier?
    func nextTier(_ id: ChainID, after t: Int) -> Int?     // t+1 if in bounds, else nil
    func chains(in category: ChainCategory) -> [MergeChain]
}

extension BoardItem {
    var def: ChainTier?   { ContentRegistry.shared.tier(chainID, tier) }
    var chain: MergeChain? { ContentRegistry.shared.chain(chainID) }
}
```

> Phase 0 keeps the registry **code-defined** (Swift literals + a builder). The boundary
> is kept clean so a later phase can load it from JSON without touching gameplay — that's
> an optimization, not a requirement. "Data-driven" here means *defined as data in one
> place*, not *loaded from a file*.

---

## 3. Bridging the current animals (minimal churn)

`AnimalSpecies` and `RescueStage` **stay** — but only as *authoring sources* for animal
chains. The rest of the game stops referencing them; it references `chainID`/`tier`/registry.
The registry generates the 8 animal chains from the existing enums:

```swift
// Registry init:
for s in AnimalSpecies.allCases {
    let id = "animal.\(s.rawValue)"
    chains[id] = MergeChain(
        id: id, category: .animal, displayName: s.name,
        tiers: RescueStage.allCases.map { stage in
            ChainTier(
                name: "\(stage.label) \(s.name)",
                shortLabel: stage.shortLabel,
                symbol: s.sfSymbol,
                color: stage.color,
                tint: s.tintColor,
                badge: stage == .ambassador ? "medal.fill" : nil,
                scoreValue: stage.rawValue * 25,
                xpValue: stage.rawValue * xpPerMergeBase)
        })
}
```

So tier 0 = Stray, tier 9 = Ambassador, icon = species symbol, colour = stage colour —
exactly today's visuals, now expressed as chain data.

---

## 4. Logic refactor (behaviour preserved)

### Merge rule
```swift
// before: a.species == b.species && a.stage == b.stage && stage.next
// after:
if a.chainID == b.chainID, a.tier == b.tier,
   let next = registry.nextTier(a.chainID, after: a.tier) {
    let merged = BoardItem(chainID: a.chainID, tier: next)
    let tierDef = registry.tier(a.chainID, next)!
    score   += tierDef.scoreValue * (a.chainID == spotlightChainID ? 2 : 1)
    grantXP(tierDef.xpValue)
    if next == registry.chain(a.chainID)!.maxTier {
        triggerTopTierCelebration(chainID: a.chainID)   // was triggerAmbassadorCelebration
    }
    updateAllAfterMerge(chainID: a.chainID, newTier: next)
}
```

### Spawning / producers
Producers keep today's behaviour (emit a **random unlocked animal chain** at a start tier):
```swift
// rescueCrate → tier 0, shelterPod → tier 1, fosterHome → tier 2
let chainID = unlockedChainIDs(in: .animal).randomElement()!
board[target].item = BoardItem(chainID: chainID, tier: producer.startTier)
```
`ProducerTile` gains `targetCategory: ChainCategory` (+ `startTier`). (Phase 1 will let a
producer target a *specific* chain and add charges.)

### QuestGoal (generalised, current meaning preserved)
```swift
enum QuestGoal: Codable {
    case mergeAny(count: Int)
    case mergeInChain(ChainID, count: Int)                 // was mergeSpecies(AnimalSpecies)
    case reachTier(ChainCategory, tier: Int, count: Int)   // was reachStage(RescueStage)
    case spawnBase(count: Int)                             // was rescueStrays
}
```
`reachTier(.animal, tier: 6, …)` == "any animal reaches Adopted" — same as today, because
all animal chains share the stage template.

### AdoptionOrder
`wantedSpecies → wantedChainID`, `wantedStage → wantedTier`. Description is built from
`registry.tier(wantedChainID, wantedTier)?.name`.

### Spotlight & unlocks
- `spotlightSpecies: AnimalSpecies` → `spotlightChainID: ChainID`
- `unlockedSpecies: [AnimalSpecies]` → `unlockedChainIDs: [ChainID]`
- level-up unlocks append chain IDs (`"animal.hamster"` at L3, etc.)

---

## 5. Persistence & migration

`GameState` changes:
| before | after |
|---|---|
| `board` cells hold `MergeItem?` | hold `BoardItem?` |
| `inventory: [MergeItem?]` | `[BoardItem?]` |
| `unlockedSpecies: [AnimalSpecies]` | `unlockedChainIDs: [ChainID]` |
| `spotlightMergesThisWeek` (+ `spotlightSpecies` derived) | unchanged + `spotlightChainID` derived |
| quests/challenges/orders use species/stage | use chainID/tier |

**Migration policy:** bump `GameStore.currentVersion` 1 → 2. Pre-launch there are no real
saves, so old saves are discarded by the existing version guard (clean). The mapping is
**documented here** in case a post-launch migration is ever needed:

```
MergeItem(species, stage)  ->  BoardItem(chainID: "animal.\(species.rawValue)",
                                         tier: stage.rawValue - 1)
unlockedSpecies: [s]       ->  ["animal.\(s.rawValue)", …]
spotlightSpecies: s        ->  "animal.\(s.rawValue)"
```

The persistence unit tests get updated to the `BoardItem` shape; new round-trip tests
cover `BoardItem` and the chain-based `QuestGoal`.

---

## 6. Implementation order (build green between every step)

1. **Add new types + registry** alongside the old model (nothing references them yet). Build.
2. **Swap the board/inventory model**: `BoardCell.item` & `inventory` → `BoardItem`;
   add a registry-driven `CellView`/`InventorySlotView` rendering path. Build + sim.
3. **Migrate ViewModel logic**: merge/move/spawn/producer/orders/quests/spotlight/unlocks
   onto chainID+tier. Build + sim (gameplay identical).
4. **Migrate `GameState`** + bump version; update tests. `xcodebuild test`.
5. **Delete the dead `MergeItem` path**; keep `AnimalSpecies`/`RescueStage` as authoring
   sources only. Final build + test + sim run.

Each step is independently compilable, so a regression surfaces immediately.

---

## 7. Verification checklist (must all hold)

- Build green; all persistence tests pass (updated to `BoardItem`).
- Sim run: producers emit random animals at the right tier; same-species+stage merge
  advances; top-tier (Ambassador) celebration fires; adoption orders read e.g.
  "a Groomed Cat"; spotlight 2× applies to one animal chain; level-ups unlock species.
- A new round-trip test: a board containing a `BoardItem` from a *non-animal* dummy chain
  survives save/load (proves the model is genuinely general, not animal-special-cased).

---

## 8. Decisions made (flag if you disagree)

1. **Each species = its own chain** (`"animal.dog"` … **15 chains** as of build), because
   merge already requires same species AND same stage = same chain AND same tier. Matches
   the genre. (Started at 8; expanded to 15 — adding species is now a one-enum edit since
   the registry generates a chain per `AnimalSpecies` case.)
2. **Keep `AnimalSpecies`/`RescueStage`** as content-authoring helpers (not deleted) to
   minimise churn; the *gameplay* stops referencing them directly.
3. **Registry is code-defined for now** (JSON-loadable later). Colours live in the
   registry, never in the save.
4. **Version bump + discard** for the save migration (pre-launch); mapping documented for
   post-launch safety.
5. **Producers keep "random unlocked animal chain" behaviour** in Phase 0; targeting a
   specific chain + charges is Phase 1.
