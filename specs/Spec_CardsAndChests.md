# Spec — Cards bought with kibble; a bought chest becomes a spawner

**Status: Draft, 22 Nov 2026; owner answered Q1–Q14 on 23 Nov 2026 (§10), two of them against the recommendation (Q3, Q7); no code.** This is task **8.1** of `Revision_Plan_ModelOnReferences.md` (W8, triage rows 15 and 16). Every code citation is `file:line` on `origin/main` at **`de3e8b2`** ("Merge pull request #133", 22 Nov 2026). Line numbers drift; search by name if one no longer lands. §4 and §7 below still describe the original proposal; where an answer changes it, a note marked **Answered 23 Nov** says so. §10 is the record.

**Read first:** `PawSanctuary_Alignment_Plan.md` D3, D7, D9, D13, D14; `Triage_ModelOnReferences.md` §1 rows 15 and 16; `Spec_AlbumGrandPrize.md` (the album's kibble faucet, just built); `Spec_HeldItemOrders.md` §6 (the D14 ratio table).

**In one paragraph, for the player.** Today a player who is missing a card spends *stars* (earned from duplicate cards) on jokers that fill any gap, common or rare. After this change, a missing **rare** card shows a kibble price on its empty slot and can be bought outright, the way the reference album sells its high-rarity cards for energy; commons still come only from packs. Separately, the Dog Tag kibble exchange at the energy wall gains a **Kibble Crate** rung: instead of crediting kibble, it puts a crate on the board that the player taps out into kibble pieces, which they can collect at once or merge for a little more. Every other chest and reward keeps working as it does today unless the owner chooses otherwise in §10.

---

## 1. Scope

Two triage rows, both verdict "Converge after modelling" (`Triage_ModelOnReferences.md` §1):

| Row | Reference (as the triage states it) | PawSanctuary (as the triage states it) |
|---|---|---|
| 15 Card purchase | Paid in energy, high rarity only | Paid in stars, jokers |
| 16 Chest as purchased spawner | Bought chest becomes a spawner | Packs credit currency directly |

§5 of this spec shows that row 16's PawSanctuary column is only partly true, and §3 that each reference column rests on **one** measured title, not both.

---

## 2. Current behaviour (code as read)

### 2.1 Cards: how they are obtained

- **Two rarities only.** `CardRarity` is `common` / `rare` (`CardSystem.swift:14-31`); a duplicate pays 1 star (common) or 5 (rare) (`CardSystem.swift:19`). Each of the six sets holds 7 commons and 2 rares, 54 cards, 12 rares in all (`CardSystem.swift:290`).
- **Stars live on packs, not cards.** `CardPackType` runs `star1`…`star6`; the type sets cards per pack, guaranteed rares and the rare-draw chance (`CardSystem.swift:63-142`; `guaranteedRares` `:122`, `rareDrawChance` `:132`). `drawCards` draws uniformly from the common or rare pool (`CardSystem.swift:369-385`).
- **Where packs come from** (all through `earnCardPack`, which only appends to `pendingCardPacks`, `MergeBoardViewModel.swift:2874-2876`): IAP energy packs (`MergeBoardViewModel.swift:4925`), level-up rewards (`AnimalSpecies.swift:2516-2521`), Loyalty days 3 and 7 (`AnimalSpecies.swift:1860-1866`), login milestones (`AnimalSpecies.swift:2545-2548`), Care Point tiers (`MergeBoardViewModel.swift:4812-4820`, pack at `:4818`), order and event rewards of kind `.cardPack` (`AdoptionBoard.swift:131`, `LiveOpsEngine.swift:190` and others), the Kibble Drive ladder (`KibbleDriveLadder.swift:26`).
- **Opening** a pack draws cards; a new card sets `cardInventory[id] = 1`, a duplicate adds stars (`MergeBoardViewModel.swift:2879-2899`), then `checkAlbumCompletions` pays the next rung of the set ramp by completion order (`MergeBoardViewModel.swift:2924-2937`; ramp `AnimalSpecies.swift:2614`, 100 → 500 kibble, 1,800 in total). The whole-collection prize is claimed once (`claimCollectionPrize`, `MergeBoardViewModel.swift:2987`; 800 kibble, 100 Dog Tags, 5,000 coins, `AnimalSpecies.swift:2638-2640`).

### 2.2 Cards: how they are bought today

- **Star Shop**, paid only in stars: 1★/2★/3★ packs for 20/35/55 stars, a **Joker** (fills any missing common) for 40, a **Rare Joker** (fills any missing rare) for 120 (`StarShopItem`, `CardSystem.swift:148-203`; prices `:170-177`). `buyFromStarShop` deducts stars and grants the pack or joker (`MergeBoardViewModel.swift:3012-3024`).
- **Using a joker**: `useJoker(for:)` checks the card is unowned and spends a joker of the card's rarity (`MergeBoardViewModel.swift:2901-2915`). UI: the shop grid (`CardAlbumView.swift:239-262`), the joker balance bar and a "Use Joker" button on each empty slot (`CardAlbumView.swift:828-858`, `:929-931`).
- **Nothing on the card side costs kibble or real money.** The album is reached from the map (`MapView.swift:423-425`) and is not behind the D7 gate.
- Persisted card state: `cardInventory`, `starCount`, `pendingCardPacks`, `jokerCards`, `rareJokerCards` (`GameStore.swift:90-95`), `claimedCollectionPrizeIDs` (`GameStore.swift:139`, v46).

### 2.3 Chests, packs and bundles: what credits currency and what places items

| Source | What it pays | Credit or board? | Citation |
|---|---|---|---|
| Kibble IAPs (60 / 180 / 600) | kibble | **credited** | `AnimalSpecies.swift:1339-1346`; `applyPurchase` `MergeBoardViewModel.swift:4919` |
| Dog Tag IAPs, Starter Bundle (100 kibble, 20 tags) | tags, kibble | **credited** | `AnimalSpecies.swift:1344`, `:1348-1355`; `:4919-4920` |
| IAP energy packs ($0.99 to $9.99) | kibble and tags **credited**; a charged **producer tile placed**; a card pack queued | **mixed** | `energyPackContents` `AnimalSpecies.swift:1360-1381`; `applyPurchase` `MergeBoardViewModel.swift:4921-4926` |
| Dog Tag → kibble ladder (15 / 30 / 60 tags for 100 kibble, daily reset) | kibble | **credited** | `DogTagKibbleExchange` `AnimalSpecies.swift:1786-1809`; `KibbleEngine.swift:151-160` |
| Free chest (4 h, skip 10 tags) | a toolbox **item** | **board** (inventory fallback) | `claimOrSkipFreeChest` `MergeBoardViewModel.swift:4371-4389`; constants `AnimalSpecies.swift:2376-2381` |
| Toolbox item (tap) | materials into inventory | item → inventory | `absorbToolbox` `MergeBoardViewModel.swift:3588-3611` |
| Weekly goal chests | kibble, tags, XP credited; toolboxes and recirculated animals **placed** | mixed | `claimWeeklyGoal` `MergeBoardViewModel.swift:4822-4846` |
| Monthly chest | 50 kibble, 20 tags, XP credited; 3 toolboxes, 2 animals placed | mixed | `claimMonthlyGoal` `MergeBoardViewModel.swift:4848-4858` |
| Smile bundle | 3 recirculated animals **placed** | **board** | `claimSmileBundle` `MergeBoardViewModel.swift:4601-4616` |
| Album set ramp, grand prize | kibble, tags, coins | **credited** | `:2924-2937`, `:2987` |
| Dog Tag store, wildcard | one item | **board** (inventory fallback) | `purchaseDogTagStoreSlot` `:1956-1970`, `purchaseWildcard` `:1979-1989` |

Item placement goes through `placeOrBankItem`: a random empty unlocked cell, else inventory, else an "inventory full" toast and `false` (`MergeBoardViewModel.swift:2147-2156`). The Dog Tag paths call it **before** deducting, so a full board costs nothing (`:1962-1963`).

**The energy-pack producer** goes through a different helper, `placeProducerReward`: a random empty cell, **else 10 kibble** (`MergeBoardViewModel.swift:1999-2007`). It never tries producer storage. The four packs place 1 Rescue Crate, 1 Shelter Pod, 1 Foster Home and 2 Foster Homes respectively (`AnimalSpecies.swift:1362-1377`); the shop row lists the spawner by name (`ShopView.swift:949-951`).

### 2.4 Spawners and producers on the board

All are `ProducerTile` (`AnimalSpecies.swift:518` onward), keyed by `ProducerLevel` (an **Int**-raw enum, `AnimalSpecies.swift:386-516`). `ProducerTile` has a hand-written decoder that tolerates missing and legacy keys (`AnimalSpecies.swift:581-609`).

| Level (raw) | Per tap | Charges | Cooldown | Emits | Placed by |
|---|---|---|---|---|---|
| `rescueCrate` (1), `shelterPod` (2), `fosterHome` (3) | kibble, `spawnCost(tier)` | 5 / 8 / 12, then the tile is removed | 30 / 45 / 60 s | a random unlocked animal | IAP energy packs only (`isShopProducer` is false, comment calls them "superseded by family spawners", `AnimalSpecies.swift:405-412`) |
| `groomingBox` (10), `feedBox` (11), `shelterBox` (12) | **free** | 6, then removed | 25 s | its supply chain, tier 0 | `buyProducer` for Dog Tags (`MergeBoardViewModel.swift:1918-1928`), level-up rewards |
| `familySpawner` (20) | kibble, tier-priced | not consumed | 30 s after every 150 kibble spent (`Spec_SpawnerCooldown.md`) | its family's animals, sub-objects, or kibble/coin currency items | map unlocks |

Values: `maxCharges` `AnimalSpecies.swift:488-494`, `cooldown` `:437-443`, `startTier` `:463-468`, `targetChainID` `:454-461`. Tap handling is `activateProducer` (`MergeBoardViewModel.swift:1778-1916`): the family-spawner branch (`:1781-1864`), the legacy rescue branch that charges kibble and burns a charge (`:1865-1892`), and the **free, charged** branch every other level falls into, which places `targetChainID` at `startTier`, starts the cooldown, burns a charge and removes the tile at zero (`:1893-1912`). A board-full tap toasts and consumes nothing (`:1908-1910`).

Producers can be retired into storage: one designated slot per level once `storageUnlockLevel` is reached, else up to `totalProducerOverflowSlots` overflow slots (`InventoryStore.swift:38-47`, `retireProducer` `:225-244`; view-model wrapper `MergeBoardViewModel.swift:2767-2777`).

**Kibble currency items already exist on the board.** `currency.kibble` is a 6-tier chain; a tap collects `2^(t+1) − 1` kibble (1, 3, 7, 15, 31, 63), so every merge is worth more than its two inputs (`AnimalSpecies.swift:2439-2456`; collect `collectCurrencyItem` `MergeBoardViewModel.swift:3621-3645`). Family spawners drop them now.

### 2.5 Gates and counters this spec touches

- **D7 gate:** `isMonetizationUnlocked = commerce.hasReachedFirstWall && playerLevel >= monetizationUnlockLevel` (5) (`MergeBoardViewModel.swift:399-401`; `AnimalSpecies.swift:1847`). It hides the Shop button (`MergeBoardView.swift:644`) and the refill sheet's ad, exchange and bundle rows (`MergeBoardView.swift:1304`).
- **Spend counter:** kibble spent at a spawner reports through `updateAllAfterSpend(kind: .kibble, …)` (`MergeBoardViewModel.swift:1690-1691`, `:3226-3228`), which feeds spend-goal quests (D6). The Dog Tag ladder does **not** report its Dog Tag spend (`MergeBoardViewModel.swift:1994-1997` calls `KibbleEngine.exchangeTagsForKibble` directly).
- **D14 census:** orders and daily tasks read items on **unlocked board cells only**, not inventory, not bubbled (`boardTaskCensus`, `MergeBoardViewModel.swift:747-754`); delivery is `deliverOrder` (`:3829`).

---

## 3. What the references show

Tags: **[M]** measured in a capture, with its source; **[I]** inferred, not seen.

### 3.1 Card purchase (row 15)

- **[M]** On the "Water Wonders" album's Undersea Party set, missing cards show buy prices in energy: **35⚡ on a 4★ card, 50⚡ on three 5★ cards**; the missing 3★ cards on the same page show **no** price. Source: `Screen Shots/analyzed images/Screenshot 2026-07-26 at 2.12.17 PM.png`, re-read in `Feature_Parity_Audit.md` §6 (13 Nov 2026).
- **[M, one source only]** "3★ = 25 energy, 4★ = 35, 5★ = 50 … only high-rarity cards are purchasable at all, and only a subset is offered at any moment. Common cards come from packs" (`Findings_26July.md` §5c). The 3★ = 25 figure is not visible in the screenshot above.
- **Which game.** `Findings_26July.md` §5b names it ("Gossip Harbor sells album cards for energy"). The 13 Nov re-check did not confirm the title from the frame. **Travel Town's card prices are unmeasured**; its albums are measured only for size and set structure (`Reference_Data_Extract.md` §11). So row 15 rests on **one** title.
- **[M]** The album pays the player: about 4,350 energy returned over 33 days against an estimated 1,000–1,500 spent on gap-fillers (`Findings_26July.md` §5c; `Merge2_Reference_Blueprint.md` §12). The spend figure is **[I]**, an estimate in that document.
- **[M]** Duplicates → stars → a Star Store; strings for "Prestige Rewards" and "restart the Collection" (`GossipHarbor_Bundle_And_Live_Review.md`, card album strings). Star Shop chests at 100/200/500 stars (`Reference_Data_Extract.md` §11). **No joker or wild-card card has been seen in either reference album.** Whether the Star Store sells packs only is **[I]**.
- **[I]** Whether the price varies with tenure, the album, or the set; whether "a subset is offered" rotates on a timer; whether bought cards count for the set reward. None is visible.

### 3.2 Chest as purchased spawner (row 16)

- **[M] Travel Town, level 46, the 26 July out-of-energy capture** (`Findings_26July.md` §5b; `Merge2_Reference_Blueprint.md` §10–11, §24): the wall offers an escalating daily ladder, Energy Pack 100 for 10 → 20 → 40 gems, with **Energy Chest ~120 for 24 and then 48 gems** interleaved. "Chest #1 ties pack #2, chest #2 ties pack #3+." About 320 energy a day is available at the discounted rates.
- **[M]** "A purchased chest does not credit energy. It lands in the holding slot, the player places it on the board, and it becomes a spawner producing mergeable energy items. The full merge succession yields 100 energy; remnants sit on the board or go to inventory" (`Findings_26July.md` §5b). Note the two figures: "~120" on the offer and "100" from the merge succession, unreconciled in the source.
- **[M]** Real-money bundles carry energy directly in their listed contents (out-of-energy bundle $7.99: 150 gems + 850 energy + a card pack, `Reference_Data_Extract.md` §2); the Super Skydive Pack lists "2 chests" ($14.99). Whether those energy amounts are credited or delivered as chests is **[I]**, not seen.
- **Gossip Harbor: unmeasured.** No capture shows a Gossip Harbor energy chest. Row 16 also rests on **one** title.
- **[I]** Charges per chest, tier of each piece, cooldown between taps, what happens on a full board, whether a chest can be stored, whether two chests merge.
- **[M]** Travel Town's art ships `chest-energy` variants named daily, first-session, mid-session and retention (`TravelTown_Bundle_And_Live_Review.md` §2). That more than one kind of energy chest exists is measured; what each holds is not.

### 3.3 Recordings that would firm up each unmeasured point

None is required to build the first stages; every proposal below is labelled so it can be re-tuned.

| Open point | Recording | Note |
|---|---|---|
| Travel Town card prices; whether a subset rotates; Gossip Harbor 4.12 prices | **None of R1–R9 covers the album.** `Recording_Guide.md` R6 is first discovery, R8 store offers. Needs a new album request (open the album, hold each set page with missing high-rarity cards, tap one price and stop at the confirmation). Not written here. | `Feature_Parity_Audit.md` notes the Gossip Harbor FTUE capture reaches the album's opening at level 5 and may already hold an album frame |
| Chest contents, charges, cooldown, full-board behaviour | **R-store** (`TODO.md`, "Recording R-store", step 6: record one cheap purchase) if the owner buys one energy chest from Travel Town's ladder and taps it out to empty; **R3** (out-of-energy screens) for Gossip Harbor's ladder | R-store as written is about the item store; the chest would be an addition the owner can choose to make |
| Whether real-money bundles credit energy or deliver chests | **R8** (store offers, three times) | Only if a bundle is bought or its "i" opened |
| Whether Gossip Harbor has a chest at all | **R3** and **R-store** for Gossip Harbor | |

---

## 4. Target behaviour

### 4.1 Rare cards bought with kibble (row 15)

1. **What can be bought.** A missing **rare** card. Commons cannot be bought, matching "common cards come from packs, full stop" (§3.1). Owned cards show no price. (Owner Q1.)
2. **Price basis (proposal).** **50 kibble** per rare, one flat constant `rareCardKibblePrice` in the tuning block of `AnimalSpecies.swift`. Reasoning:
   - PawSanctuary's "rare" is its top rarity, so it takes the reference's top-rarity price (5★ = 50). The two economies are on the same energy scale: PawSanctuary's regen cap and interval match every reference measurement (`Comparison_TravelTown_GossipHarbor_PawSanctuary.md`, opening-energy and generator rows), and the opening balance is 100 in both.
   - Buying all 12 rares costs 600 kibble against 2,600 the album pays in kibble (1,800 ramp + 800 prize): **23%**, inside the reference's measured-against-estimated 23–34% (1,000–1,500 of 4,350). The album still pays the player.
   - Amortised over the model's 60-day horizon (`EconomySimulation.swift:920`), 600 kibble is **10 kibble a day, 1.4%** of the level-5 supply of 695 (`EconomyTests.swift:780-784`).
   (Owner Q2.)
3. **Offer.** Every missing rare shows its price at once (proposal). The reference offers "only a subset at any moment"; copying that needs rotation state and a schema bump and is unmeasured in how it rotates. (Owner Q3.)
   **Answered 23 Nov: a rotating subset, 3 missing rares at a time, rotating daily.** See §10 Q3 and the new Q13 (how the 3 are chosen).
4. **Flow.** A new `purchaseCardWithKibble(_ cardID:) -> Bool` on the view-model, modelled on `purchaseDogTagStoreSlot` (`MergeBoardViewModel.swift:1956-1970`): guard the card is rare, unowned and affordable; deduct kibble; report `updateAllAfterSpend(kind: .kibble, …)` (Owner Q6); set `cardInventory[id] = 1`; `checkAlbumCompletions()`; `persist()`. A bought card counts for its set exactly as a drawn one does.
5. **UI.** On each missing rare slot in `AlbumDetailView`, a kibble price button beside (or instead of, per Q4) "Use Joker" (`CardAlbumView.swift:929-931`), with a one-tap confirmation, disabled when unaffordable. Behind the D7 gate per Q5.
6. **Stars and jokers.** Stars stay: duplicates still pay them and the Star Shop still sells packs. Jokers are an owner choice (Q4): keep both, retire both from sale, or retire the common joker only. Any retirement **stops selling** them; balances already held stay usable through `useJoker`, so no save changes.

### 4.2 A bought chest becomes a spawner (row 16)

**What a chest spawner is.** A new producer level, **`kibbleCrate`**, reusing `ProducerTile` unchanged and the free, charged branch of `activateProducer` (`MergeBoardViewModel.swift:1893-1912`), which already does exactly what the reference describes: tap, place one item, burn a charge, vanish at zero.

| Property | Proposal | Basis |
|---|---|---|
| Raw value | `30` (Int, next free block after 10–12 and 20) | `ProducerLevel` is Int-raw (§11) |
| Emits | `currency.kibble` at tier **3** (15 kibble each) | "mergeable energy items" [M]; the chain exists (§2.4) |
| Charges | **8** | 8 × 15 = **120** kibble collected raw, matching the reference offer's "~120" [M]; merged fully, 8 × tier 3 → 2 × tier 5 = **126** |
| Cost per tap | free | already paid for; the supply-producer branch is free |
| Cooldown | **0 s** | unmeasured [I]; a paid crate should not make the player wait (D9). Owner Q11 |
| Merges with another crate | no (`next` = nil) | unmeasured |
| Name, face | "Kibble Crate", a kibble-tinted crate icon with the existing charge pips | `CellView.swift:409-437` routes non-animal producers to `supplyProducerContent` |
| Storage | designated slot from level 1 (`storageUnlockLevel` = 1), overflow otherwise | reuses `retireProducer` |

**Where it goes when bought.** A new `placeOrStoreProducer(_:) -> Bool`: a random empty unlocked cell; else the producer storage slot (`InventoryStore.retireProducer`); else `false`. (Owner Q10.)
- For a **Dog Tag** purchase it is called **before** deducting, as the Dog Tag store does, so a full board and full storage charge nothing and toast `.boardFull`.
- For a **real-money** purchase the money is already taken, so the last fallback credits the crate's raw value in kibble directly (120), never less than today's credit.

**On a full board while tapping.** Existing behaviour: toast, no charge burnt (`MergeBoardViewModel.swift:1908-1910`).

**Which chests become spawners.**

| Source | Proposal | Why |
|---|---|---|
| **Dog Tag kibble ladder** | **Becomes a crate on two rungs** (below) | The one measured case: the reference's wall ladder with chests interleaved |
| IAP energy packs | **Unchanged contents**; fix the full-board fallback so the paid producer goes to storage rather than becoming 10 kibble (Owner Q7, Q9). **Answered 23 Nov: Q7 also includes paid chests, read as option (b): the kibble in an energy pack is delivered as a Kibble Crate instead of credited.** Sizes are open (Q14) | Already place a spawner; the real-money bundle case is unmeasured [I] |
| Kibble IAPs, Dog Tag IAPs, Starter Bundle | unchanged (credited) | Real-money bundles credit energy in the reference's listing [M]; changing a live paid SKU needs a D9 argument (D9's first consequence, Kibble Drive step 5) |
| Free chest | unchanged | Already places a toolbox item; the reference's timed free chest is not a spawner in any capture |
| Weekly, monthly chests; Smile bundle | unchanged | Already place items (recirculation, modelled) |
| Album and event rewards | unchanged | No reference measurement |

**The ladder (proposal).** One sequence on the existing `dogTagExchangesToday` counter, so no new state:

| Purchase today | Today | Proposed | Tags per kibble |
|---|---|---|---|
| 1st | 15 → 100 kibble | 15 → 100 kibble | 0.15 |
| 2nd | 30 → 100 | 30 → 100 | 0.30 |
| 3rd | 60 → 100 | **36 → Kibble Crate (120)** | 0.30, ties rung 2 as the reference's chest #1 ties pack #2 |
| 4th | 60 → 100 | 60 → 100 | 0.60 |
| 5th, 7th, … | 60 → 100 | **72 → Kibble Crate (120)** | 0.60, ties the flat rung as chest #2+ ties pack #3+ |
| 6th, 8th, … | 60 → 100 | 60 → 100 | 0.60 |

Kibble available at the discounted rates rises from 200 a day to **320** (reference ~320 [M]; this said 340 until stage 4, when the rungs as built came to 320 and the owner accepted that on 25 Nov 2026, Q28). `DogTagKibbleExchange` (`AnimalSpecies.swift:1786-1809`) gains a rung kind (credit or crate) and the crate's tag price; the refill sheet's exchange row (`MergeBoardView.swift:1397-1430`) and the Shop's (`ShopView.swift:708-790`) show "Kibble Crate ×8" on a crate rung. The view-model, not `KibbleEngine`, performs a crate rung, because placement needs the board.

---

## 5. Economy

### 5.1 The card sink

- **Not in `grossDemand`.** The ratio model charges what the game *asks for* (orders, daily tasks, `EconomySimulation.swift:324-345`). A card purchase is elective and one-time per card, like the album faucet, which the model keeps outside `dailySupply` for the same reason (`albumKibblePerDay`, `EconomySimulation.swift:930-933`).
- **Add a matching term**, `albumCardKibbleSinkPerDay = rareCount × rareCardKibblePrice / amortisationDays` (10 a day at the proposal), next to `albumKibblePerDay`, and two tests in `AlbumSetRewardRampTests` or a new `CardKibblePurchaseTests`:
  1. `testTheAlbumStillPaysThePlayer`: the sink is at most 35% of `albumKibblePerDay` (the reference's upper estimate, 1,500 / 4,350). At the proposal: 10 / 43.3 = 23%.
  2. `testTheCardSinkIsAMinorDemand`: the sink is under 2% of `dailySupply(level: 5)`.
- **Effect on `testDemandSupplyRatioMatchesTheTargetCurve`** (`EconomyTests.swift:754-771`): **none**, because neither `row(level:)` nor `dailySupply` changes. Owner should know the margins anyway: under D14 level 30 already sits at 0.704 against its 0.70 bar, accepted by the owner (`Spec_HeldItemOrders.md`, Q21). If the owner wants the sink inside `grossDemand` instead (not recommended), +10 a day moves every ratio by about +0.014 at level 5 and the D12 assertion at level 30 must be re-checked first.
- **Coin and map tests:** unaffected. `kibbleIntoOrders` takes `min(grossDemand, supply + recirculation)` (`EconomySimulation.swift:955-958`); since the sink is outside both, `testMapBuildOutLandsInTheTargetWindow` (`EconomyTests.swift:442`) does not move. If the sink were put into `grossDemand`, the coin projection would rise slightly, a modelling artefact (buying a card earns no coins); another reason to keep it out.
- **In play:** the sink competes with board taps for kibble, which is the "second demand curve" `Findings_26July.md` §4 calls structural; §5c then argues it competes for attention rather than energy, because the album pays more than it costs. At 23% that remains true here.

### 5.2 The crate

- **Supply model:** `dailySupply` is pinned to measured reference values and contains no purchases (`EconomySimulation.swift:39-43`, `:101-105`; `testSupplyMatchesTheMeasuredReference`). The Dog Tag ladder is not in it today. So the crate changes **no modelled number**: no supply term, no `testDemandSupplyRatioMatchesTheTargetCurve` change.
- **What it does recirculate:** if it emits kibble pieces (Q8 a), nothing an order can use; it is kibble in a different wrapper plus a 5% merge bonus (126 vs 120). If it emitted animals (Q8 b), it would be a paid recirculation channel, and should then be added beside `recirculation(level:deepestTier:)` (`EconomySimulation.swift:465-509`) as a report-only line, since the model has no purchase frequency to multiply by.
- **New tests** (`EconomyTests`): `testAKibbleCrateNeverPaysLessThanItsPrice` (8 × `kibbleCurrencyValue(tier: 3)` ≥ 120); `testCrateRungsTieTheirNeighbouringPackRungs` (tags per kibble equal to rung 2 and to the flat rung); `testTheDiscountedDailyAllowanceStaysNearTheReference` (340, within 280–360 of the measured ~320).
- **Board space (congestion):** a crate holds one cell, and its pieces hold cells until collected. The congestion model (`EconomySimulation.swift:519` onwards) has no purchase term; a crate is transient and player-timed, so leave it out and say so in the model's comment.

### 5.3 Held-item orders (D14)

- Kibble pieces from a crate are currency items; no order or daily task asks for them, so **they never fill an order slot**. They do take cells, which is the reference's "buying energy costs board space" [M].
- If Q8 (b) is chosen, a crate's animals sit on the board and **do** fill order slots under D14, because orders count board items (`boardTaskCensus`, `MergeBoardViewModel.swift:747-754`). An animal that fell back to inventory does not count until placed.
- The IAP energy packs' legacy producers already spawn animals onto the board; under D14 those animals already fill order slots. Unchanged.
- A bought card has no board presence; no D14 interaction.

---

## 6. D9, D7, D3 and D13

### 6.1 D9 (retention outranks monetization)

Stated plainly, as D9 requires:
- **Kibble card purchase: revenue-leaning, small retention cost.** It adds a kibble sink, so a player who wants a rare card now meets the energy wall a little sooner, which is the indirect monetization path. Mitigations in this spec: optional; rares only; the album still returns about four times what buying every rare costs; nothing is taken away unless the owner retires jokers.
- **Retiring jokers (Q4 a or c) is the clearest revenue-at-retention-cost change here.** Today the last rare can be closed with stars a player already earned from duplicates; under full retirement it costs kibble. Q4's recommendation (c) keeps the Rare Joker for that reason.
- **Kibble Crate rungs: retention-positive, slightly revenue-negative.** The third purchase of the day drops from 60 tags for 100 kibble to 36 for 120, so the discounted allowance rises from 200 to 320 (the spec first said 340; owner accepted 320, 25 Nov 2026, Q28). The friction it adds (board space, eight taps) is the reference's design; the merge bonus and the zero cooldown keep it from being a pure cost.
- **Energy-pack kibble as a crate (Q7, answered 23 Nov): revenue-neutral on paper if each crate is never worth less than today's credit (Q14), but it changes a live paid SKU, which D9's first consequence says needs this argument.** It adds friction for a paying player (a cell and eight taps for kibble that used to arrive at once). The retention argument for it is the reference's ladder, and it rests on one title with the paid case unmeasured. The owner chose it; this note is here so the choice is on the record as a D9 trade-off, not an oversight.
- **Energy-pack full-board fix: retention-positive.** A paying player no longer loses a producer for 10 kibble.
- **Not done, because of D9:** no live paid SKU changes contents or price; nothing is tuned to make a card or crate convert better.

### 6.2 D7 gate, per new surface

| Surface | Gate |
|---|---|
| Kibble price on a missing rare | **Behind `isMonetizationUnlocked`** (recommended, Q5). It spends earned kibble, so it is not strictly a monetization surface, but the album is reachable in session one and a kibble sink there brings the first wall forward, which D7 exists to prevent. The reference's album opens at level 5 and pushes nothing (`Merge2_Reference_Blueprint.md` §9) |
| Crate rungs on the ladder | Already behind the gate: the refill sheet's exchange row (`MergeBoardView.swift:1304`) and the Shop (`:644`) |
| Energy-pack fallback fix | Already behind the gate (Shop) |
| Star Shop changes | None needed (stars only); unchanged |

### 6.3 D3 and D13

- Crates are bought through the existing ladder (`exchangeTagsForKibble`, `MergeBoardViewModel.swift:1994-1997`), extended to place the crate; no new Dog Tag price list. Fix in passing (Owner Q12): the ladder should report its Dog Tag spend through `updateAllAfterSpend(kind: .dogTags, …)` like every other Dog Tag spend, or the crate rung inherits the omission.
- No new Dog Tag item purchase is added, so D13's rule (buy shortcuts route through `purchaseDogTagStoreSlot`) is untouched.
- Cards are bought with kibble, not Dog Tags, through one new function; nothing routes around an existing purchase path.

---

## 7. Persistence

**Current schema on `origin/main`: v48 after stage 3** (was v46 when this was written; `GameStore.swift`). Open specs may claim the next numbers (#134 fifteen tiers; #135 context tutorial, v47). **The number below is written v(N), assigned at build time** to whatever follows `currentVersion` then.

| Stage | Persisted shape change | Bump? |
|---|---|---|
| Kibble card purchase (4.1) | none: writes `cardInventory`, which exists | no |
| Joker sale retired (Q4 a or c) | none: balances stay, `useJoker` still spends them | no |
| Joker balances **converted** (not recommended) | `jokerCards`/`rareJokerCards` rewritten at load | yes |
| Rotating offer subset (Q3 b, **chosen 23 Nov**) | none: the 3 are derived from the date (Q13 a, **chosen 23 Nov**) | no |
| **`ProducerLevel.kibbleCrate = 30`** | a save may now contain level 30 on the board or in storage | **yes** (rule 4: an older build cannot decode it) |
| Crate rungs on the ladder | none: same `dogTagExchangesToday` counter | no |
| Energy-pack fallback | none: storage already persists | no |

**The crate's migration, in the code's current pattern.** One line in the version dispatch, like v29 to v45 (`GameStore.swift:709-725`):

```swift
if version == N-1 { return migrateByInjecting(from: N-1, defaults: [:], into: data) }   // kibbleCrate is a new ProducerLevel case; no existing save holds it
```

No `additiveDefaultsSinceV8` entry (`GameStore.swift:762`): nothing new is non-Optional. `ProducerTile`'s own decoder (`AnimalSpecies.swift:587-609`) needs no change. Add the `vN` line to the version history comment above `currentVersion` (`GameStore.swift:397-401`).

**PersistenceTests cases (exact):**
1. `testV{N-1}toV{N}KeepsEveryProducerAsItWas`: encode `makeSampleState()` with a `rescueCrate` tile on the board (3 charges) and a `groomingBox` in `producerStorage`, set `version` to N−1, write, `GameStore.load()`; assert `version == currentVersion` and both tiles equal, charges included.
2. `testKibbleCrateTileRoundTrips`: a board cell holding `ProducerTile(level: .kibbleCrate, chargesRemaining: 5)` survives encode/decode with level and charges.
3. `testKibbleCrateRoundTripsThroughProducerStorage`: one crate in `producerStorage[30]` and one in an overflow slot both survive.
4. `testProducerLevelRawValuesArePinned`: `[1, 2, 3, 10, 11, 12, 20, 30]`, so a renumbering cannot silently corrupt saves.

Beside the existing producer tests (`PersistenceTests.swift:243-310`) and the v46 test pattern (`:1411-1421`).

---

## 8. Staged build plan

One task per session; each leaves the game playable and ships on its own.

| Stage | Task | Shippable because | Tests |
|---|---|---|---|
| **1** | `rareCardKibblePrice` constant; `purchaseCardWithKibble`; price button and confirmation on missing rare slots, D7-gated (Q5) | Additive: one new way to fill a rare; nothing removed | New `CardKibblePurchaseTests`: deducts and grants; completes a set and pays its rung; refuses owned, common, unaffordable; refuses before the D7 gate; reports a kibble spend to quests. `EconomySimulation.albumCardKibbleSinkPerDay` plus the two §5.1 tests |
| **2** | Star Shop per Q4 (remove the retired joker items from sale; keep `useJoker` for held balances; hide the "Use Joker" button when the balance is zero, as now) | Removes a shop row only | Star Shop sells exactly the chosen items; a held joker still fills a gap; no save change (existing persistence suite passes untouched) |
| **3** | `ProducerLevel.kibbleCrate` with every switch case; `CellView` face; storage slot; schema bump and migration; a `#if DEBUG` grant to place one | Nothing sells it yet; only the debug grant places it | The four `PersistenceTests` in §7; activating a crate places a tier-3 kibble piece, burns a charge, removes the tile at zero, costs nothing; board-full tap burns nothing; retire to storage and back |
| **4** | Ladder rung kinds; crate rungs at positions 3, 5, 7, …; `placeOrStoreProducer`; refill-sheet and Shop rows; Dog Tag spend reported (Q12) | Ladder still works; a crate is just a new rung | `testCrateRungsTieTheirNeighbouringPackRungs`, `testTheDiscountedDailyAllowanceStaysNearTheReference`, `testAKibbleCrateNeverPaysLessThanItsPrice`; full board and full storage charge nothing; the counter advances once per purchase; the daily reset still applies |
| **5** | Energy packs: route their producers through `placeOrStoreProducer`, last fallback the producer's value in kibble rather than 10 (Q9); retire the dead +10 path | Real-money path; behaviour only improves | `applyPurchase(.energyXL)` on a full board stores both Foster Homes; on full board and full storage credits the stated fallback. Real StoreKit flow joins the existing Xcode-Run item in `TODO.md` |
| **6** | Simulator pass with screenshots: album price button before and after the gate; a crate bought, tapped out, merged, collected; a full-board purchase | Verification only | Screens shown to the owner |

**Stage status.** Stage 1: **built** (24 Nov 2026). `rareCardKibblePrice` = 50 and `rareCardOffersPerDay` = 3 in `AnimalSpecies.swift`; `CardRegistry.offeredRareIDs` (seeded shuffle of the 12 rares by calendar day, Q3 b / Q13 a, no saved field); `purchaseCardWithKibble` and `offeredRareCardIDs` in the view-model; price pill plus confirmation dialog on missing offered rares in `AlbumDetailView`, beside "Use Joker"; `CardKibblePurchaseTests` (13). No schema change.

Stage 2: **built** (24 Nov 2026). `StarShopItem.jokerCard` is deleted, so the Star Shop sells the three packs and the Rare Joker only (Q4 c); `buyFromStarShop` and the shop grid follow from the enum; `useJoker` is untouched, so a held common Joker still fills a missing common; the "Jokers" count pill in the album now shows only while a held balance remains (nothing can add to it any more). `StarShopJokerRetirementTests` (8). No schema change; no persistence test touched.

Stage 3: **built** (24 Nov 2026). `ProducerLevel.kibbleCrate = 30` with every switch case (8 charges, tier-3 kibble, 0 s cooldown, no merge-up, storage from level 1); constants `kibbleCrateCharges` and `kibbleCrateTier` at the bottom of `AnimalSpecies.swift`; the crate reuses the supply-producer branch of `activateProducer` (free, burns a charge, tile removed at zero, board-full tap burns nothing) and the supply cell face; the selection line reads "Kibble Crate · Tap to open · free · N left" (the generic line said "costs N kibble"); the Inventory "Producers" tab gains a Kibble Crate slot; `#if DEBUG` `debugGrantKibbleCrate()` with a "Grant Kibble Crate (Debug)" button on the Profile sheet. **Schema v48** (`migrateByInjecting`, no default needed). `KibbleCrateTests` (12) and four `PersistenceTests` (§7).

Stage 4: **built** (25 Nov 2026). `DogTagKibbleExchange` gains `isCrate` and `rewardLabel`; the ladder reads credit 15, credit 30, **crate 36**, credit 60, then **crate 72** on every second purchase (5th, 7th, ...) and credit 60 between (6th, 8th, ...), on the existing `dogTagExchangesToday` counter. `KibbleEngine.exchangeTagsForKibble()` refuses a crate rung; `exchangeTagsForCrate(deliver:)` runs the delivery before deducting, so a full board and full storage charge nothing and the ladder does not advance. `MergeBoardViewModel.exchangeTagsForKibble()` performs either kind, toasts `.boardFull` when a crate has nowhere to go, and now reports the Dog Tag spend to quests (Q12); new `placeOrStoreProducer` (random empty cell, else the producer's storage slot, else an overflow slot). The refill sheet and Shop rows show "Kibble Crate ×8" with a crate icon on a crate rung, and the refill sheet stays open when a crate cannot be placed. No schema change. `KibbleCrateLadderTests` (14), and `EconomyTests` gains the three §5.2 tests while three ladder tests were updated for the new shape. **Spec arithmetic note:** §4 originally said the discounted allowance rises to 340 (now corrected to 320, owner-accepted 25 Nov 2026, Q28); rungs at or under 0.30 tags per kibble add up to 100 + 100 + 120 = **320**, still inside the 280–360 window and level with the reference's ~320, so the test asserts 320.

Stage 5: **built** (25 Nov 2026). The kibble in each IAP energy pack is delivered as Kibble Crates instead of credited (Q7). **Sizes (owner, 25 Nov 2026, Q14):** Small $0.99 = 100 kibble, Medium $2.99 = 300, Large $4.99 = 480, XL $9.99 = 1000, up from 25 / 60 / 120 / 250. Each is delivered as 7 × tier 3 (105), 5 × tier 5 (315), 8 × tier 5 (504), and two crates of 8 × tier 5 (1008): at least the owner's figure and at most 5% over. A crate now carries its own piece tier and charge count: `ProducerTile.pieceTier` and `.capacity` (both Optional; `emitTier` and `totalCharges` fall back to the level's defaults, so stage 3's unsized crate is unchanged), with the sizes in `energyPackCrates(_:)` at the bottom of `AnimalSpecies.swift`. **Schema v49** (version stamp only). `applyPurchase` places each crate through `placeProducerReward(_:fallbackKibble:)` (board, else storage, else the crate's whole raw value in kibble, never less); `hasRoomForSpawners` counts the pack's crates as well as its spawners, so the Shop still refuses before StoreKit charges. The board-to-storage fix for the spawner itself had already shipped on 22 Nov, so the "retire the +10 path" item does not apply: level-up supply producers still use it. The Shop pack row shows "Crate N" and its caption says so. `EnergyPackCrateTests` (13), four v49 `PersistenceTests`, and two older pack test files updated. **D9 note:** the new amounts are 4 to 5 times the old credits, so this is retention-positive and revenue-negative on four live paid SKUs, chosen by the owner; tier-5 pieces cannot be merged for a bonus. The kibble-only bags (60 / 180 / 600) and the Starter Bundle are unchanged. The real StoreKit purchase and the Shop's pack row are not seen on screen (no StoreKit configuration under `simctl`); they join the existing `TODO.md` Xcode Run item. Stage 6: **done** (25 Nov 2026), a Simulator pass with no code: the crate cycle (8 charges, free taps, tier-3 merge to tier 4 paying +31), the album price pill before and after the D7 gate, the Shop crate row, and a full-board crate purchase landing in producer storage with 36 tags charged. The StoreKit purchase and the pack row remain unseen (`TODO.md`).

Stages 1–2 and 3–5 are independent chains; either can go first. Stage 4 needs 3. Every stage runs `EconomyTests` and `PersistenceTests` before commit.

---

## 9. Out of scope

- Stars on the cards themselves (reference 1★–5★ per card; PawSanctuary has two rarities, Parity Audit §6). A rarity rework is its own spec.
- Album seasons, rotation, more sets, card art (`TODO.md`).
- The Star Shop's chest prizes at 100/200/500 stars (reference) and "restart the Collection".
- Changing any IAP product's price, contents or StoreKit configuration (D9; App Store registration in `TODO.md`).
- Contextual offers (triage row 17), the red-cart buy path on orders (D14, task 1.8), the D13 chain-viewer work, the discovery collection.
- Changing `dailySupply`, `miscKibblePerDay` or any measured supply constant.
- Fifteen tiers (#134): the kibble currency chain stays 6 tiers; if #134 changes it, the crate's tier and charges are re-derived from the same rule (raw value ≥ 120).
- The free chest's ungated skip (§11 item 4): reported, not fixed here.
- Card trading.

---

## 10. Owner decisions

Each has a recommendation; the first option listed is not always it.

- **Q1. Which cards can be bought with kibble?** (a) Rares only. (b) Rares and commons, commons cheaper. (c) None; keep star-only. **Recommend (a)**, the measured reference rule.
  **Answered 23 Nov 2026: (a) Rares only, as recommended.**
- **Q2. The price basis.** (a) 50 kibble flat. (b) 35 kibble flat. (c) Rising with the set ramp's completion order. **Recommend (a)**: the reference's top-rarity price, and 23% of the album's kibble return.
  **Answered 23 Nov 2026: (a) 50 kibble flat, as recommended.**
- **Q3. Which missing rares are offered.** (a) All of them. (b) A rotating subset, as the reference does (rotation unmeasured; schema bump). **Recommend (a)**: simpler, more generous (D9), no save change; revisit after an album recording.
  **Answered 23 Nov 2026: (b) a rotating subset, **against the recommendation**: 3 missing rares at a time, rotating daily (same day boundary as the Dog Tag ladder's daily reset). How the 3 are chosen, and whether a bought card's slot refills at once, is the new Q13. §4.1 item 3 and the §7 table are updated. Also answered 23 Nov in a follow-up: offer size 3, rotation daily.**
- **Q4. Stars and jokers.** (a) Stop selling both jokers. (b) Keep both. (c) Stop selling the common Joker; keep the Rare Joker for stars. Held balances stay usable in every case. **Recommend (c)**: converges on "commons come from packs" while keeping a non-energy route to the last rare, a D9 reason that survives re-reading (D14 rule 1).
  **Answered 23 Nov 2026: (c) Stop selling the common Joker, keep the Rare Joker for stars, as recommended. Held balances stay usable.**
- **Q5. Gate the kibble price behind D7?** (a) Yes, `isMonetizationUnlocked`. (b) No, show it whenever the album is open. **Recommend (a)**.
  **Answered 23 Nov 2026: (a) Yes, behind `isMonetizationUnlocked`, as recommended.**
- **Q6. Does a card purchase count as kibble spent for spend-goal quests?** (a) Yes. (b) No. **Recommend (a)**: it is real kibble spent, and the references count energy spent anywhere (Prize Rise, `Findings_26July.md` §5b).
  **Answered 23 Nov 2026: (a) Yes, as recommended.**
- **Q7. Which purchases become crates?** (a) The Dog Tag ladder only (the measured case). (b) (a), plus the energy packs' kibble paid as a crate instead of credited. (c) Every kibble-paying purchase. **Recommend (a)**; (b) and (c) change live paid SKUs and need the real-money bundle measured (R8) and a D9 argument.
  **Answered 23 Nov 2026: the Dog Tag ladder **and paid chests**, **against the recommendation**. Read as option (b): the Dog Tag ladder plus the energy packs' kibble delivered as a crate instead of credited. Kibble IAPs, Dog Tag IAPs and the Starter Bundle are not covered by (b); if the owner meant option (c), every kibble-paying purchase, say so. Because this changes live paid SKUs, §6.1 needs a D9 argument and the real-money bundle behaviour is still unmeasured (R8). Crate sizes per pack are open: Q14.**
- **Q8. What a crate emits.** (a) Kibble pieces (currency chain, tier 3). (b) Animals, like the legacy rescue producers. **Recommend (a)**, the reference's "mergeable energy items".
  **Answered 23 Nov 2026: (a) Kibble pieces, as recommended.**
- **Q9. The energy packs' legacy rescue producers.** (a) Keep them; fix the full-board fallback to storage. (b) Replace them with Kibble Crates. **Recommend (a)**: no content change to a paid SKU; the fix only stops a loss.
  **Answered 23 Nov 2026: (a) Keep the legacy rescue producers; fix the full-board fallback to producer storage, as recommended.**
- **Q10. Where a bought crate lands.** (a) The board, else producer storage, else refused before charging (Dog Tags) or credited as kibble (money). (b) Always into storage first, as the reference's holding slot. **Recommend (a)**: matches every other placement in the game.
  **Answered 23 Nov 2026: (a) The board, else producer storage, else refused before charging (Dog Tags) or credited as kibble (money), as recommended. The owner added: a bought crate disappears once its contents have fully spawned. That is what the design already does (the free, charged branch removes the tile at zero charges, §4.2).**
- **Q11. Crate cooldown between taps.** (a) None. (b) 25 s, like supply producers. **Recommend (a)** until a recording shows the reference's.
  **Answered 23 Nov 2026: (a) No cooldown, as recommended, until a recording shows the reference's.**
- **Q12. Report the Dog Tag ladder's spend to quests.** (a) Yes, in stage 4. (b) No, leave as is. **Recommend (a)**: every other Dog Tag spend reports, and the crate rung would otherwise inherit the gap.
  **Answered 23 Nov 2026: (a) Yes, report the Dog Tag ladder's spend to quests in stage 4, as recommended.**
- **Q13. How the 3 offered rares are chosen (new, from the Q3 answer).** (a) Derived from the date: shuffle the 12 rare IDs with a seed from today's date, offer the first 3 the player does not own. Stable all day, no saved field, no schema bump; a bought card is replaced by the next unowned one in the shuffle at once. (b) Stored: a saved list of today's 3 and the day it was picked, so a bought card stays "sold" until the next rotation; needs a schema bump, migration and `PersistenceTests` cases. **Recommend (a)**: no save change, and refilling at once is the more generous reading (D9). The owner should confirm the day boundary is the Dog Tag ladder's reset.
  **Answered 23 Nov 2026: (a) Derived from the date, as recommended: no saved field, no schema bump. The day boundary is the Dog Tag ladder's daily reset.**
- **Q14. Sizes of the paid Kibble Crates (new, from the Q7 answer).** The four energy packs credit 25, 60, 120 and 250 kibble today (`energyPackContents`, `AnimalSpecies.swift:1360-1381`). As crates they need a charge count and tier each, with raw value never below today's credit (the §5.2 rule). Options: (a) one Kibble Crate per pack with charges and tier chosen per pack, to be proposed in the stage-5 task for the owner to approve; (b) the same 8-charge tier-3 crate (120) repeated, which would over-pay the $0.99 pack and under-pay the $9.99 one, so not viable without a count change. **Recommend (a)** and that stage 5 starts by writing the table, not code. The real-money behaviour in the reference is unmeasured (R8), so this is a proposal, labelled as such.
  **Answered 25 Nov 2026 (after the stage 5 table): the packs deliver 100, 300, 480 and 1000 kibble, up from 25, 60, 120 and 250 (Small, Medium, Large, XL). Built as per-tile crate sizes; see the stage 5 status line.**
  **Answered 23 Nov 2026: (a) Stage 5 starts by writing the sizing table (charges and tier per pack, each crate never worth less than today's credit) for the owner to approve before any code, as recommended.**


---

## 11. Where the spec and the code disagree

1. **Row 16's "packs credit currency directly" is only partly true.** IAP energy packs already **place a charged producer tile** on the board (`AnimalSpecies.swift:1360-1381`; `MergeBoardViewModel.swift:4924`); only their kibble and Dog Tags are credited. `Feature_Parity_Audit.md`'s "Chest-as-purchased-spawner ❌" row says the same thing as the triage and misses this. Kibble IAPs, Dog Tag IAPs, the Starter Bundle and the Dog Tag ladder do credit directly.
2. **"The references agree" rests on one title per row.** The chest spawner is measured in Travel Town only; card prices in one album, attributed to Gossip Harbor by `Findings_26July.md` §5b and not re-confirmed from the frame (§3). Under D14's standing rule this is converging on one measured title, not on two that agree.
3. **A paid producer is lost on a full board.** `placeProducerReward` gives 10 kibble when no cell is free and never tries producer storage (`MergeBoardViewModel.swift:1999-2007`). A $9.99 XL pack bought on a full board turns two Foster Homes into 20 kibble.
4. **The free chest's skip is ungated and unconfirmed.** The tray tile's tap calls `claimOrSkipFreeChest()` (`TaskTrayView.swift:645-660`), which spends 10 Dog Tags when the chest is not ready (`MergeBoardViewModel.swift:4371-4381`), with no confirmation and no `isMonetizationUnlocked` check, while the family-spawner skip is gated (`:4332`). Pre-existing; out of scope here; reported for the owner.
5. **Purchases grant "superseded" producers.** The comment on `isShopProducer` says rescue-tier producers are superseded by family spawners (`AnimalSpecies.swift:405-407`), yet every energy pack still grants one, and the shop row advertises it (`ShopView.swift:949-951`).
6. **`ProducerLevel` is Int-raw** (`AnimalSpecies.swift:386`), against CLAUDE.md's "persisted enums use String raw values". It predates the rule; the new case follows Int so existing saves stay readable.
7. **The Dog Tag ladder does not report its spend** (`MergeBoardViewModel.swift:1994-1997`; `KibbleEngine.swift:151-160`), unlike the Dog Tag store, wildcard, producer shop and skips. Q12.
8. **Stale citations in the Parity Audit:** the energy packs' card packs are now at `AnimalSpecies.swift:1360-1381` (audit: `:927-939`); the Star Shop is at `CardSystem.swift:148-203` (audit: `:149-204`). Not corrected here (tracker edits are out of scope for this task).
9. **The reference source gives two figures for one chest:** "~120" on the offer and "full merge succession yields 100" (`Findings_26July.md` §5b). The proposal sizes the crate on 120 raw (126 merged), the more generous reading.
