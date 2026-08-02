# PawSanctuary — Phase 1 Implementation Spec: Foundations

**Read this as a complete, self-contained brief.** It assumes no prior conversation. Everything needed is here.

---

## 0. Context

PawSanctuary is a merge-2 iOS game (SwiftUI, ~16,700 lines, schema v24). It is being aligned against three measured competitors — Gossip Harbor, Travel Town and Tasty Travels — whose retention and monetization mechanics were captured and analysed in July 2026.

**This phase is deliberately invisible to players.** Nothing here changes gameplay. Every item is a data-shape or interface change that becomes 5–10× more expensive once later phases stack features on top of it. Resist the urge to implement the behaviour these structures enable — that is Phase 2 and later.

**Definition of done for the whole phase:** the game plays *identically* to today, saves round-trip cleanly, and `PersistenceTests` passes.

---

## 1. Design decisions already made (do not relitigate)

| # | Decision |
|---|---|
| D1 | The "no hard energy walls" principle is replaced by **"generous supply, designed depletion."** Energy depletion becomes a designed moment in Phase 3. |
| D2 | The spawn multiplier becomes **energy-neutral**: `cost = 2^tierIndex`. Phase 2. |
| D3 | Dog Tags / Coins **may** buy board items, stock-limited. Phase 2/4. |
| D4 | Session target moves to **2–4 min × 6–10/day**. |
| D5 | Live-ops cadence: one 3–4 day event weekly, one 30-day album/pass continuous, daily challenges auto-generated. |
| D6 | Spend-quota daily tasks are **out** at launch. |
| D7 | **No monetization surface in session one.** Shop and all offer surfaces gate behind a flag flipping at first genuine kibble depletion or player level 5, whichever is later. Phase 3. |

Phase 1 builds the plumbing D2/D3/D7 and the live-ops work will need. It does not implement any of them.

---

## 2. Task 1.1 — Order rewards become a list

### Why

Reference data: a single order in Tasty Travels at level 102 carried **four reward types simultaneously** — base coins, two different event currencies, and an item — and the mix changed every few days as events rotated.

PawSanctuary currently hardcodes three fields. Every future event that wants to attach a payload to order completion would require editing `AdoptionOrder`, `AdoptionBoard.generateOrder` and `MergeBoardViewModel.autoClaimOrder`. That tax is what makes running four to six concurrent events impractical.

### Current shape

`AnimalSpecies.swift:677`

```swift
struct AdoptionOrder: Identifiable, Codable {
    var id = UUID()
    var familyIndex: Int
    var wantedChainID: ChainID
    var wantedTier: Int
    var wantedCount: Int
    var fulfilled: Int = 0
    var timeRemaining: Double
    var rewardDogTags: Int          // ← replace
    var rewardCoins: Int            // ← replace
    var rewardCardPack: CardPackType? = nil   // ← replace
    var isClaimed: Bool = false
    // … computed helpers
}
```

### Target shape

Add to `AnimalSpecies.swift` near `AdoptionOrder`:

```swift
enum RewardKind: String, Codable, CaseIterable {
    case dogTags
    case coins
    case kibble
    case xp
    case cardPack
    case boardItem     // recirculation — Phase 2
    case material      // wood / metal / cement — Phase 2
    case eventToken    // Phase 6
}

/// A single reward payload attached to an order.
/// `payloadID` / `payloadTier` carry kind-specific detail:
///   .cardPack   → payloadID = CardPackType.rawValue
///   .boardItem  → payloadID = ChainID, payloadTier = tier index
///   .material   → payloadID = material chain ID, payloadTier = tier index
///   .eventToken → payloadID = event token identifier
struct OrderReward: Codable, Equatable {
    var kind: RewardKind
    var amount: Int
    var payloadID: String? = nil
    var payloadTier: Int? = nil
}
```

Replace the three stored fields on `AdoptionOrder` with:

```swift
var rewards: [OrderReward] = []
```

### Keep the views compiling

`PanelViews.swift` and other UI read `rewardDogTags` / `rewardCoins` / `rewardCardPack` to render reward pills. **Do not churn the views.** Add computed accessors to `AdoptionOrder` with the same names:

```swift
extension AdoptionOrder {
    var rewardDogTags: Int { rewards.first { $0.kind == .dogTags }?.amount ?? 0 }
    var rewardCoins: Int   { rewards.first { $0.kind == .coins   }?.amount ?? 0 }
    var rewardCardPack: CardPackType? {
        guard let raw = rewards.first(where: { $0.kind == .cardPack })?.payloadID else { return nil }
        return CardPackType(rawValue: raw)
    }
}
```

### Update the two call sites

**`AdoptionBoard.generateOrder` (`AdoptionBoard.swift:39`)** — currently ends by constructing `AdoptionOrder(... rewardDogTags: tags, rewardCoins: orderCoins, rewardCardPack: packReward)`. Build the array instead:

```swift
var rewards: [OrderReward] = [
    OrderReward(kind: .dogTags, amount: tags),
    OrderReward(kind: .coins,   amount: orderCoins)
]
if let pack = packReward {
    rewards.append(OrderReward(kind: .cardPack, amount: 1, payloadID: pack.rawValue))
}
rewards.append(contentsOf: OrderRewardRegistry.riders(playerLevel: playerLevel))   // Task 1.2
```

**`MergeBoardViewModel.autoClaimOrder` (`MergeBoardViewModel.swift:2274`)** — currently:

```swift
kibbleEngine.dogTags += order.rewardDogTags
grantXP(xpPerOrderFulfil)
earnCoins(order.rewardCoins + cachedActiveBonuses.coinsPerOrderFulfil)
if let pack = order.rewardCardPack { earnCardPack(pack) }
```

Replace with a loop over `order.rewards`:

```swift
grantXP(xpPerOrderFulfil)
for reward in order.rewards {
    switch reward.kind {
    case .dogTags:  kibbleEngine.dogTags += reward.amount
    case .coins:    earnCoins(reward.amount + cachedActiveBonuses.coinsPerOrderFulfil)
    case .kibble:   kibbleEngine.kibble += reward.amount
    case .xp:       grantXP(reward.amount)
    case .cardPack:
        if let raw = reward.payloadID, let pack = CardPackType(rawValue: raw) { earnCardPack(pack) }
    case .boardItem, .material, .eventToken:
        break   // Phase 2 / Phase 6 — intentionally unhandled for now
    }
}
```

> **Preserve the existing behaviour exactly:** the `cachedActiveBonuses.coinsPerOrderFulfil` bonus must still apply once, and kibble must still *not* be a merge reward by default (the existing comment at line 2279 explains why — orders pay dog tags and coins, not kibble). Do not add a `.kibble` reward to generated orders in this phase.

---

## 3. Task 1.2 — Rider injection hook

### Why

Active events need to attach payloads to orders at generation time without editing `AdoptionBoard`.

### Implementation

New file `OrderRewardRegistry.swift`:

```swift
import Foundation

/// A system that can attach extra rewards to newly generated adoption orders.
/// Events register providers; AdoptionBoard queries them at generation time.
protocol OrderRewardProvider: AnyObject {
    func riders(playerLevel: Int) -> [OrderReward]
}

@MainActor
enum OrderRewardRegistry {
    private(set) static var providers: [OrderRewardProvider] = []

    static func register(_ provider: OrderRewardProvider) {
        guard !providers.contains(where: { $0 === provider }) else { return }
        providers.append(provider)
    }

    static func unregister(_ provider: OrderRewardProvider) {
        providers.removeAll { $0 === provider }
    }

    static func riders(playerLevel: Int) -> [OrderReward] {
        providers.flatMap { $0.riders(playerLevel: playerLevel) }
    }
}
```

**No providers are registered in this phase.** `riders()` returns `[]` and order generation is unchanged in behaviour.

---

## 4. Task 1.3 — `ChainCategory.currency`

### Why

All three reference games spawn energy and coins **as merge chains on the board** — `Coin (Lvl 1)` collects 1, `Coin (Lvl 3)` collects 7. This is how players hold far more energy than their meter cap allows, and it's how a returning player sees a reward waiting for them. Phase 4 authors these chains.

### Implementation

`ItemChain.swift:22` — add one case:

```swift
enum ChainCategory: String, Codable, CaseIterable {
    case animal
    case spawner
    case supply
    case tool
    case material
    case subObject
    case powerUp
    case currency    // kibble / coin chains that spawn on the board — Phase 4
}
```

**Safe to add:** category is resolved from `ContentRegistry` at runtime; saves persist only `chainID` and `tier`. No migration needed for this item specifically.

**Author no chains in this phase.**

### Reconnaissance findings — read before implementing

A full search of the codebase was run after this spec was first drafted. The result **inverts the original rationale** for doing this task first:

| Check | Result |
|---|---|
| Exhaustive `switch` over `ChainCategory` | **Exactly one**, in `InventoryStore.addItem` (line ~115) — and it has a `default:` clause |
| `ChainCategory.allCases` usage | **None** — no silent iteration change |
| `ProducerLevel.targetCategory` (`AnimalSpecies.swift:352`) | Switches over `ProducerLevel`, *returns* a category. Unaffected. |
| `QuestGoal.reachTier(ChainCategory, ...)` | Carries a category as an associated value and **is persisted** (`GameStore.swift:437`). Encodes the raw string; existing saves only ever contain `"animal"`. Adding a case is safe — no migration needed. |

**So adding the case will not produce a single compile error.** The risk is the opposite of what this spec originally claimed: `.currency` items would fall silently through `InventoryStore.addItem`'s `default:` into `addToAnimalInventory`, which is wrong — currency items are collected on tap, not stored.

### The one real change

In `InventoryStore.addItem`, add an explicit case **above** the `default:`:

```swift
case .currency:
    // Currency items (kibble / coin chains) are collected by tapping them on the
    // board - they never enter inventory. Phase 4 implements tap-to-collect;
    // until then nothing can produce one, so this path is unreachable.
    return true
```

Making this explicit rather than leaving it to `default:` is the entire point of the task — it records the intent at the exact site where a future silent bug would otherwise live.

---

## 5. Task 1.4 — Player commerce state

### Why

Offer targeting, difficulty scaling and the Phase 3 first-purchase gate all need behavioural history. **This cannot be backfilled** — a player who installs before this ships will never have an early history. It is the single most time-sensitive item in the phase.

### Implementation

New struct, persisted in `GameState`:

```swift
struct PlayerCommerceState: Codable, Equatable {
    var firstLaunchDate: Date? = nil
    var purchaseCount: Int = 0
    /// Total spend in integer micros (USD × 1,000,000) — avoids Double drift.
    var totalSpendMicros: Int = 0
    var lastPurchaseDate: Date? = nil

    /// Times the player has hit zero kibble while trying to act.
    var wallEventsTotal: Int = 0
    var lastWallDate: Date? = nil
    /// What they were blocked on at the most recent wall event.
    var lastWallChainID: String? = nil
    var lastWallTier: Int? = nil

    /// Flips permanently once the player first reaches a genuine wall.
    /// Phase 3 uses this (with player level) to gate monetization surfaces.
    var hasReachedFirstWall: Bool = false

    var hasEverPurchased: Bool { purchaseCount > 0 }
    var averagePurchaseMicros: Int { purchaseCount == 0 ? 0 : totalSpendMicros / purchaseCount }
    var daysSinceLastPurchase: Int? {
        guard let last = lastPurchaseDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
}
```

Add `var commerce = PlayerCommerceState()` to `GameState`.

**Wire three recording points, and nothing else:**

1. **First launch** — set `firstLaunchDate` on new-game creation if nil.
2. **Wall event** — in `MergeBoardViewModel.activateProducer`, at the existing `triggerToast(.noKibble)` sites (two of them, around lines 1058 and 1122): increment `wallEventsTotal`, set `lastWallDate`, record the blocked `chainID`/`tier`, set `hasReachedFirstWall = true`.
3. **Purchase** — in `StoreManager`, on successful transaction: increment `purchaseCount`, add to `totalSpendMicros`, set `lastPurchaseDate`.

**Do not change any behaviour based on these values in this phase.** Record only.

---

## 6. Task 1.5 — Live-ops primitive interfaces

### Why

The reference games run four to six concurrent events at horizons from four minutes to twenty-nine days. They do not have twenty event implementations — they have a small primitive set and express events as configuration. `EventSystem.swift` currently implements roughly one of eight primitives (a coin-milestone progress track).

Phase 6 implements these. Phase 1 defines the interfaces so nothing gets built against the wrong shape.

### Implementation

New file `LiveOpsPrimitives.swift` — **protocols and value types only, no implementations.**

```swift
import Foundation

// 1. Scheduler — lifecycle, eligibility, and overlap/priority resolution.
protocol EventScheduling {
    func activeEvents(at date: Date) -> [String]        // event IDs
    func isEligible(eventID: String, playerLevel: Int) -> Bool
    /// Which event owns a contested UI slot when several are active.
    func priority(for eventID: String) -> Int
}

// 2. Token wallet — arbitrary named currencies with an end-of-event lifecycle.
protocol TokenWalleting {
    func balance(_ token: String) -> Int
    func credit(_ token: String, _ amount: Int)
    func debit(_ token: String, _ amount: Int) -> Bool
    func purge(tokensFor eventID: String)
}

// 3. Progress track — ordered milestones, supporting parallel free/paid lanes.
struct TrackMilestone: Codable, Equatable {
    var index: Int
    var threshold: Int
    var freeRewards: [OrderReward]
    var paidRewards: [OrderReward]
}

protocol ProgressTracking {
    func progress(trackID: String) -> Int
    func advance(trackID: String, by amount: Int)
    func claimable(trackID: String, paidLaneUnlocked: Bool) -> [TrackMilestone]
    func claim(trackID: String, milestone: Int, paidLane: Bool) -> [OrderReward]
}

// 4. Reward table — weighted random payloads. Every variable-ratio reward routes here.
struct WeightedReward: Codable, Equatable {
    var weight: Int
    var rewards: [OrderReward]
}

protocol RewardTabling {
    func roll(tableID: String) -> [OrderReward]
    func table(_ id: String) -> [WeightedReward]
}

// 5. Timer service — countdowns, deadlines, expiry, and attached notifications.
protocol EventTiming {
    func remaining(eventID: String) -> TimeInterval
    func isUrgent(eventID: String) -> Bool
    func scheduleExpiryNotification(eventID: String, at date: Date)
}

// 6. Offer hook — lets an active event register its own offers.
protocol OfferHooking {
    func registerOffer(eventID: String, offerID: String)
    func activeOffers() -> [String]
}

// 7. Parallel board instance — a second board with its own chains, energy and offers.
protocol ParallelBoardHosting {
    func makeBoard(eventID: String) -> UUID
    func teardownBoard(eventID: String)
    func energyBalance(eventID: String) -> Int
}

// 8. Rider injection — see OrderRewardRegistry.swift (Task 1.2).
```

**Nothing conforms to these yet.** They exist so Phase 6 has a target and so nothing is built against a shape that will change.

---

## 7. Task 1.6 — Schema migration v24 → v25

### Why

Task 1.1 changes the persisted shape of `AdoptionOrder`. Task 1.4 adds `commerce` to `GameState`. `GameStore` is at v24 with an unbroken migration chain back to v8 — keep it unbroken.

### Implementation

1. `GameStore.swift:199` — bump `static let currentVersion = 25`.
2. Add to the migration chain (after the `version == 23` line, ~line 347):

```swift
if version == 24 { return migrateV24toV25(data) }
```

3. Implement a **structural** migration (not `migrateByInjecting` — the order shape changes):

```swift
/// v24 → v25: AdoptionOrder's three fixed reward fields collapse into a
/// `rewards: [OrderReward]` list; GameState gains `commerce`.
private static func migrateV24toV25(_ data: Data) -> GameState? {
    guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

    if var orders = json["adoptionOrders"] as? [[String: Any]] {
        for i in orders.indices {
            var rewards: [[String: Any]] = []
            if let tags = orders[i]["rewardDogTags"] as? Int, tags > 0 {
                rewards.append(["kind": "dogTags", "amount": tags])
            }
            if let coins = orders[i]["rewardCoins"] as? Int, coins > 0 {
                rewards.append(["kind": "coins", "amount": coins])
            }
            if let pack = orders[i]["rewardCardPack"] as? String {
                rewards.append(["kind": "cardPack", "amount": 1, "payloadID": pack])
            }
            orders[i]["rewards"] = rewards
            orders[i].removeValue(forKey: "rewardDogTags")
            orders[i].removeValue(forKey: "rewardCoins")
            orders[i].removeValue(forKey: "rewardCardPack")
        }
        json["adoptionOrders"] = orders
    }

    if json["commerce"] == nil {
        json["commerce"] = ["purchaseCount": 0, "totalSpendMicros": 0,
                            "wallEventsTotal": 0, "hasReachedFirstWall": false]
    }

    json["version"] = currentVersion
    guard let patched = try? JSONSerialization.data(withJSONObject: json) else { return nil }
    do { return try JSONDecoder().decode(GameState.self, from: patched) }
    catch { assertionFailure("GameStore: v24→v25 migration decode failed — \(error)"); return nil }
}
```

> **Check `rewardCardPack`'s encoded form before relying on the cast above.** `CardPackType` is an enum — if it encodes as a raw `String` the cast works as written; if it encodes as a nested object, adjust to read the raw value out of it. Verify with a real v24 save rather than assuming.

4. Add a migration test to `PersistenceTests.swift` mirroring the existing v23→v24 test: construct a v24 blob with populated orders, migrate, assert the `rewards` array reproduces the original three fields and that `commerce` is present with defaults.

---

## 8. Order of work — REVISED

The original ordering deferred the migration until after both persistence-shape changes, which would leave existing saves undecodable in between. That violates the "keep the game playable at every commit" rule in the plan. Corrected sequencing:

| Session | Tasks | Schema | Rationale |
|---|---|---|---|
| **0** | 1.3 — `ChainCategory.currency` | none | Self-contained. Per §4 reconnaissance it produces no compile errors; the work is the deliberate `InventoryStore` case. ✅ **Done** |
| **A** | 1.1 (rewards → list) + 1.2 (registry) + its migration | v24 → **v25** | 1.1 changes a persisted shape, so its migration must land in the same commit. 1.2 is called from `generateOrder`, so it lands here too. |
| **B** | 1.4 (commerce state) + its migration | v25 → **v26** | Separate persisted addition, separate bump. Smaller diff, save loads at every commit. |
| **C** | 1.5 (live-ops protocols) | none | Pure interfaces, no dependencies. Can be done any time. |

Two schema bumps rather than one. That costs nothing and buys smaller reviewable diffs plus a loadable save at every commit.

**Task 1.6 as written in §7 is therefore split**: the `adoptionOrders` rewrite belongs to session A's v24→v25 migration; the `commerce` injection belongs to session B's v25→v26 migration. Each needs its own `PersistenceTests` case.

---

## 9. Explicitly out of scope

Do **not** implement any of the following in this phase, even though the plumbing now exists for them:

- Any change to spawn tier or multiplier cost (Phase 2)
- Any recirculation — orders paying board items (Phase 2)
- Any change to the kibble refill sheet or ad placement (Phase 3)
- Any currency merge chains (Phase 4)
- Any change to order slot count or difficulty distribution (Phase 5)
- Any event implementation (Phase 6)
- Any gating of the shop or offer surfaces (Phase 3)

---

## 10. Acceptance

- [ ] Game plays identically to today — no visible change whatsoever
- [ ] A v24 save loads, migrates, and preserves order rewards exactly
- [ ] A fresh install creates a v25 save with `commerce.firstLaunchDate` set
- [ ] Hitting zero kibble increments `wallEventsTotal` and records the blocked item
- [ ] A completed purchase increments `purchaseCount` and `totalSpendMicros`
- [ ] `PersistenceTests` green, including a new v24→v25 case
- [ ] `OrderRewardRegistry.riders()` returns `[]` and order generation is behaviourally unchanged
- [ ] `LiveOpsPrimitives.swift` compiles with no conformances
