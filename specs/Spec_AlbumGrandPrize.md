# PawSanctuary — Album Grand Prize and Set-Reward Ramp

**Status update, 26 Nov 2026 (from git):** all four implementation tasks are merged (#130, #131, #132, #133). *The earlier status line follows as written.*

**Status (22 Nov 2026): owner answers in §12. Task 1 (schema v46) is merged, PR #130. Task 2 (grand prize rule) is PR #132 and task 4 (set-reward ramp) is PR #131, both in review. Task 3 (banner) is not yet a PR.** Originally: Draft, 18 Nov 2026, not reviewed, no code. Written cold from a read of the code on `origin/main` (`6d5a409`) on 18 Nov 2026, to carry out task **6.1** of `Revision_Plan_ModelOnReferences.md` (W6, triage row 14). Four implementation tasks, one per session, in §11.

**Self-contained brief.** Assumes no prior conversation. Every code claim is cited `file:line` as read on 18 Nov 2026; line numbers drift, so search by name if a number no longer lands.

---

## 0. What this is, and what it is not

Two changes to the card album, both from the same reference reading:

- **(a) A whole-collection grand prize,** paid once, when every set in the album is complete. Today there is none.
- **(b) A set-reward ramp** that rises roughly from 100 to 500 across the sets, as the reference does. Today the set rewards rise only loosely, and not at all on some currencies.

**Words.** The code calls each 9-card group an "album" (`CardAlbumDefinition`, `completedAlbumIDs`). The reference calls that group a **set** and the whole book the **album**. This spec follows the reference: a **set** is one `CardAlbumDefinition`; the **collection** (or album) is all six. Code identifiers keep their existing names.

**Not in this spec:** any code (this is the spec); card purchase price or currency (W8); the first-discovery collection (held by D13); events; a new star-shop sink (see §10).

---

## 1. Decisions this spec answers to

- **D14 (18 Nov 2026).** Where the references agree, converge; a difference needs a recorded reason. Triage row 14 says **Converge (schema bump)**, accepted in D14 §5.
- **D9.** Retention outranks monetization; a change that raises revenue at a retention cost must say so. §6.
- **D7.** Session-one monetization silence behind `isMonetizationUnlocked` (`MergeBoardViewModel.swift:396`). §7.
- **D13.** Applies to "any spec touching ... a collection or a first-time reward". It holds the *first-discovery* collection and notes that "its measured gap is cheaper": the card album's missing whole-collection prize. This spec is that cheaper gap. It adds no discovery state and no per-item reward. D13's caution about unsized Dog Tag faucets applies to the grand prize contents (§5.2, Q2).
- **PROJECT_STATE Q15 (i).** Owner was offered "PM writes a draft spec for a whole-collection prize" (recommended). This is that spec.

---

## 2. Current behaviour (code, 18 Nov 2026)

### 2.1 Content

- A set is `CardAlbumDefinition` with three reward fields, `rewardKibble`, `rewardDogTags`, `rewardCoins` (`CardSystem.swift:49-58`). There is no collection-level definition.
- Six sets, 9 cards each (7 common, 2 rare), 54 cards (`CardSystem.swift:238-287`, cards at `:294-361`). Their rewards, in registry order:

| # | Set (`id`) | Kibble | Dog Tags | Coins |
|---|---|---|---|---|
| 1 | Rescue Profiles (`album.rescue`) | 30 | 5 | 0 |
| 2 | Sanctuary Friends (`album.sanctuary`) | **0** | 8 | 500 |
| 3 | Animal Kingdom (`album.wildlife`) | 40 | 10 | 1,000 |
| 4 | Vet Records (`album.vet`) | 50 | 12 | **750** |
| 5 | Adventures Abroad (`album.adventures`) | 60 | 15 | 1,500 |
| 6 | Hall of Fame (`album.fame`) | 100 | 25 | 2,500 |
| | **Total** | **280** | **75** | **6,250** |

  Kibble is not monotonic (set 2 pays none), coins are not monotonic (set 4 pays less than set 3). Dog Tags already ramp 5 to 25, a 5× ratio.
- **Every set is equally hard to finish.** `drawCards` picks uniformly from all commons or all rares across every set (`CardSystem.swift:371-386`). Sets therefore complete in an order set by luck, not by registry position, so a ramp keyed to registry position does not reach the player as "rising" (see §4.2).

### 2.2 Completion and payout

- State: `cardInventory`, `starCount`, `completedAlbumIDs`, `pendingCardPacks`, jokers (`MergeBoardViewModel.swift:340-346`); a FIFO `albumCompleteQueue` for the celebration (`:350-355`).
- `checkAlbumCompletions()` (`MergeBoardViewModel.swift:2855-2867`): for each registered set not in `completedAlbumIDs`, if every card is owned, it appends the ID, adds `withPassBonus(rewardKibble)` to kibble (`:2861`; `withPassBonus` multiplies by the Pass's 1.5, `:917`, `AnimalSpecies.swift:1751`), adds Dog Tags (`:2862`), calls `earnCoins` (`:2863`; which also feeds the weekly goal, the event coin track and the piggy bank, `:4080-4090`), and queues the celebration (`:2864-2865`). It does **not** call `persist()` itself; every caller does, right after.
- Callers: `openNextCardPack` (`:2817-2837`), `useJoker` (`:2839-2853`), `claimIncomingTrade` (`:2947-2976`). **There is no check for "all sets complete" and no collection reward.**
- `loadGame` does not call `checkAlbumCompletions` (`:991-1022`).
- Collection is monotonic: no path takes an owned card below one copy. `sendDuplicateCard` requires `> 1` (`:2918`); `convertAllDuplicatesToStars` sets extras back to 1 (`:2979-2990`).
- Card pack sources (for context; none changes here): level-up rewards (`:2646`), login milestones (`:3645`), event rewards (`:3687`, `:3888`), a reward tier (`:4616`), the star shop (`:2888`), and IAP energy packs (`applyPurchase`, `:4715-4723`).

### 2.3 UI

- The album list is `albumsContent`: header, pack queue, set grid, star shop (`CardAlbumView.swift:126-133`). No collection-level row or progress ("3 of 6 sets").
- A set row shows owned/total and a gold seal when done (`CardAlbumView.swift:676-677`). The set detail sheet shows a "Complete to earn:" banner from the three reward fields (`:766-787`).
- The "Album Complete!" toast (`AlbumCompleteOverlay`, `CardAlbumView.swift:1085-1117`) is rendered only as an overlay on `CardAlbumView` (`:64-71`), and its 4-second dismiss timer starts at completion time (`MergeBoardViewModel.swift:2865`, `:2873-2883`). Today every completion happens while the album is on screen (pack opening `CardAlbumView.swift:170`, joker `:829`, trade claim `:355`), so this is fine; a completion fired anywhere else (for example on load) would never be seen.

### 2.4 Persistence

- `GameState` holds `cardInventory` and `completedAlbumIDs` (`GameStore.swift:90-95`). **`static let currentVersion = 45`** (`GameStore.swift:394`), v45 being `trophyCounts` (`:391-393`).
- The migration table is flat: each old version dispatches straight to the current one (`readValid`, `GameStore.swift:662-727`). Every non-Optional field added since v8 must be listed in `additiveDefaultsSinceV8` (`:740-821`), or older saves fail to decode and are discarded. `finishMigration` applies those defaults and any version-gated rewrites (`:826-841`).
- Recent additive bumps (v29 onward, latest v43–v45 at `:714-717`) dispatch to `migrateByInjecting(from:defaults:into:)` (`:731-737`) with no dedicated helper. Dedicated `migrateVNtoVN+1` helpers exist only where a rewrite was needed, for example `migrateV27toV28` (`:968`), `migrateV28toV29` (`:980`).
- `load()` reads local, backup and iCloud key-value copies and keeps the one with the latest `lastActiveDate` (`GameStore.swift:577-604`, `mostRecent` at `:1380-1388`). The whole `GameState` wins as a unit.
- `persist()` snapshots the whole state (`captureState`, `MergeBoardViewModel.swift:1265`; save at `:1438`).

### 2.5 Economy model

- `EconomySimulation` amortises album **coins** over 60 days into `otherCoinIncome` (`PawSanctuaryTests/EconomySimulation.swift:635-636`, `:661`, `:701`). Album **kibble** and **Dog Tags** are in no model: `dailySupply` is regen + ads + a measured misc figure (`:39-43`, `:68-73`), pinned at 695 (L5) and 745 (L20) by `testSupplyMatchesTheMeasuredReference` (`EconomyTests.swift:780-784`).
- Scale anchors: daily kibble supply 695 below L10; regen cap 100 (`AnimalSpecies.swift:1703`); one Dog Tag exchange buys 100 kibble (`:1674`); an ad pays 25 (`:1718`); the login ladder pays 80 kibble and 10 Dog Tags a week (`:2445-2453`); a wildcard costs 100 Dog Tags (`:2195`); the map costs 291,900 coins (`EconomyTests.swift:463`).

---

## 3. What the references show, and what is unmeasured

All from `Feature_Parity_Audit.md` row "Set vs. album reward asymmetry" (re-checked 13 Nov 2026) and `Merge2_Reference_Blueprint.md` §6. This spec did not re-read the footage.

**Measured:**
- One album ("Water Wonders", 135 cards, 15 sets, 32d 6h) pays **250 gems + 800 energy + 1 crystal + 1 avatar** for "Collect all the card sets" (screenshot `Screenshot 2026-07-26 at 2.09.57 PM.png`).
- Its last set pays 500 energy + 1 mystery box + 1 gem item (`…2.12.17 PM.png`). The set ramp **100 to 500 energy** rests on 6 of its 15 sets (`Findings_26July.md` §5c).
- A second album (`Reference_Data_Extract.md` §11) pays 1 wildcard + 1,000 gems + chest + 4 toolboxes on completion, 100 to 150 energy per set.
- **Both titles put the value at completion.** On the first album the grand prize is ~800 of ~4,350 energy returned, plus all of the gems.

**Not measured:**
- How the grand prize is claimed (button or automatic). No recording shows an album screen.
- Whether the reference's set ramp follows set order because later sets are harder (higher-star cards), or is fixed regardless.
- How long a player takes to finish an album. PawSanctuary has no card-pack income model either.
- Whether the album resets with a new season. The reference albums carry a timer (32d 6h); PawSanctuary's collection is permanent, so its grand prize is once per save, not once per season.

**Every number in §5 is a design proposal sized against PawSanctuary's own economy, not a reference reading.**

---

## 4. Target behaviour

### 4.1 Grand prize (a)

1. The collection is complete when **every set in `CardRegistry.albums`** is in `completedAlbumIDs`. IDs in `completedAlbumIDs` that no longer match a registered set do not count, and do not block.
2. A complete, unclaimed collection makes the grand prize **claimable**. Claiming pays the prize (§5.2), records the claim in the save, and plays a celebration. (Q3 covers button vs automatic; the rest of this section assumes the recommended button.)
3. **Claim-once.** A recorded claim can never pay again: not on a second tap, not after save and load, not after migration, not after reinstall from iCloud (§9).
4. The album list gains a **collection banner** above the set grid: "Collect all 6 sets", progress "N of 6 sets", the prize contents, and a Claim button when claimable; a "Claimed" state afterwards.
5. The prize is keyed by a **collection ID** (`"collection.1"`), not a Bool, so a later album could carry its own prize without another schema bump (Q5).

### 4.2 Set-reward ramp (b)

Rewards rise roughly 100 to 500 kibble across the sets, a 5× ratio, as the reference does, and every currency rises monotonically. Because PawSanctuary's sets are all equally hard (§2.1), the recommended way to make the rise reach the player is to **pay by completion order** (the first set completed pays the first rung, the sixth pays 500), not by set identity (Q1, Q6). This departs from the reference's mechanism (fixed per set), and per D14 that needs a recorded reason: the reference's later sets may be harder, PawSanctuary's are not, so a per-set ramp here would pay 500 to whichever set luck finishes first.

---

## 5. Proposed numbers (design proposals, not measured)

### 5.1 Set ramp (Q1)

**Recommended (Q1 a): the reference's numbers, 1:1 with kibble.** The units are close: PawSanctuary's regen cap and starting balance (100) match Gossip Harbor's measured opening (Alignment Plan D4, 17 Nov 2026).

| Completion rung | 1 | 2 | 3 | 4 | 5 | 6 | Total |
|---|---|---|---|---|---|---|---|
| Kibble | 100 | 180 | 260 | 340 | 420 | 500 | **1,800** (today 280) |
| Dog Tags | 5 | 8 | 10 | 12 | 15 | 25 | 75 (unchanged) |
| Coins | 0 | 500 | 750 | 1,000 | 1,500 | 2,500 | 6,250 (unchanged; rungs 3 and 4 swapped so they rise) |

Sizing: 1,800 kibble is ~2.6 days of supply (695/day). Amortised over `EconomySimulation`'s 60-day album horizon, it is 30 kibble/day, ~4.3% of daily supply (today ~4.7/day, 0.7%). It lowers wall pressure a little; see D9 in §6. Pass holders get 1.5× on kibble as today (`withPassBonus`).

Alternatives: (b) keep today's scale and fix only the shape: 20, 30, 45, 60, 80, 100 kibble (335 total), same Dog Tags and reordered coins. (c) Leave set rewards as they are and ship the grand prize alone.

### 5.2 Grand prize (Q2)

**Recommended (Q2 a): 800 kibble + 100 Dog Tags + 5,000 coins.**

- **800 kibble**: the reference's figure, 1:1. ~1.2 days of supply, once per save. Through `withPassBonus`, like the set kibble.
- **100 Dog Tags**: stands in for the reference's gems (the premium currency). 100 = exactly one wildcard (`wildcardCostDogTags`), ~10 weeks of login Dog Tags. D13 warns that Dog Tags have no economy term; a one-time, bounded 100 is the smallest grant that reads as "the premium prize", and is far below the 180 D13 rejected as an ongoing faucet.
- **5,000 coins**: 1.7% of the 291,900-coin map. Through `earnCoins`, so it also counts toward the weekly goal, event coin track and piggy bank, as set coins do today. Amortised over 60 days, +83 coins/day in `otherCoinIncome`.

Alternatives: (b) the above plus one wildcard board item (the second reference album's prize; `Merge2_Reference_Blueprint.md` §6 also lists a wildcard). That needs `placeOrBankItem` (`MergeBoardViewModel.swift:2085-2094`), which fails when board and inventory are full, so the claim must refuse rather than half-pay. (c) A smaller prize, 300 kibble + 50 Dog Tags + 2,500 coins.

No avatar or crystal: PawSanctuary has neither. A cosmetic (for example a fourth board theme) would need art and is out of scope (§10).

### 5.3 Where the numbers live

CLAUDE.md puts new tuning numbers at the bottom of `AnimalSpecies.swift`. The grand prize amounts, and the completion-order ramp if Q6 (a) is chosen, go there (`albumCollectionPrizeKibble`, `albumCollectionPrizeDogTags`, `albumCollectionPrizeCoins`, `albumSetRewardRamp`). If Q6 (b) (per-set) is chosen, the set numbers stay in `CardRegistry.albums` where they are now, since they are content.

---

## 6. D9 check (retention vs monetization)

- **Retention:** a once-per-save prize at completion is a long-horizon goal, and it puts visible, claimable progress ("4 of 6 sets") in the album. Both are the retention side of D9.
- **Monetization:** none of this adds a purchase surface. The Blueprint (§6) notes the reference concentrates value at completion because "the last few cards" are when a player pays. PawSanctuary sells no single cards (out of scope, W8); the only paid card path is the card pack inside IAP energy packs (`MergeBoardViewModel.swift:4715-4723`), which already exists. A bigger completion prize may lift that slightly. Nothing here is tuned to make it do so.
- **The one cost:** the extra kibble (1,520 more from the ramp, 800 from the prize) reduces wall pressure by a few percent over two months. That is a small revenue cost in exchange for retention, which D9 accepts. **No change here raises revenue at a retention cost.**

## 7. D7 check

The prize and the ramp are rewards, not offers. Nothing shows a price, a store link or an IAP, so no `isMonetizationUnlocked` gate is needed. The banner must not carry a "buy packs" shortcut; if one is ever wanted it is a monetization surface and goes behind the D7 gate in its own spec. A session-one player cannot complete 54 cards, so the prize cannot appear in session one either way.

---

## 8. Persisted-shape change

### 8.1 Field

```swift
/// Collection-level prizes already paid (v46, specs/Spec_AlbumGrandPrize.md).
/// Holds collection IDs, e.g. "collection.1". Never cleared.
var claimedCollectionPrizeIDs: [String] = []
```

On `GameState`, next to `completedAlbumIDs` or after `trophyCounts` (`GameStore.swift:136` precedent: non-Optional with a default value). Mirrored on the view model next to `completedAlbumIDs` (`MergeBoardViewModel.swift:343`), written in `captureState` (`:1281`) and read in `apply` (`:1370`).

The set ramp needs **no** persisted change: set rewards are content, and the completion order is already the append order of `completedAlbumIDs`.

### 8.2 Version

**v45 to v46**, from `currentVersion = 45` on `origin/main` today (`GameStore.swift:394`). Other branches in flight (W1, W5) may also claim v46. **The number is assigned when this is built**: the build session takes `currentVersion + 1` from the code it branches from, and renames the tests in §8.4 to match.

### 8.3 Migration

- Add `"claimedCollectionPrizeIDs": [String]()` to `additiveDefaultsSinceV8` (`GameStore.swift:740-821`) with a `// v46` comment. Because the table is flat, this one entry covers every source version v8 to v45.
- Dispatch: `if version == 45 { return migrateByInjecting(from: 45, defaults: [:], into: data) }   // claimedCollectionPrizeIDs covered by additiveDefaultsSinceV8`, next to the v43/v44 lines (`:714-717`).
- Add the v46 line to the version history comment (`:391-394`) and set `currentVersion = 46`.
- **Helper name.** CLAUDE.md's convention is `migrateVNtoVN+1(_ data: Data) -> GameState?`, so the name is **`migrateV45toV46`**. The code has not created a dedicated helper for a purely additive bump since v29; it uses `migrateByInjecting`. This change is purely additive (no rewrite), so the code precedent applies and no helper is needed. If the owner's answer to Q4 is (b) (mark existing complete saves as claimed), the migration has a rewrite and **does** get `migrateV45toV46`, called as a `sourceVersion < 46` step in `finishMigration` so every older source version gets it.
- Migration never pays anything; `GameStore` has no access to the economy.

### 8.4 `PersistenceTests.swift` cases

Add under a `// MARK: v45 → v46 (Album grand prize)` heading, mirroring `testV44toV45StartsEveryTrophyPageEmpty` (`PersistenceTests.swift:1410-1421`):

1. `testV45toV46StartsWithNoCollectionPrizeClaimed`: encode `makeSampleState()`, remove `claimedCollectionPrizeIDs`, set `version` 45, write, `GameStore.load()`; assert `version == GameStore.currentVersion` and the list is empty.
2. `testV45SaveWithEverySetCompleteKeepsItsSetsAndIsUnclaimed`: as above, but with `completedAlbumIDs` set to all six IDs and every card in `cardInventory`; assert both survive unchanged and the claimed list is empty (under Q4 a). Under Q4 (b) it instead asserts `["collection.1"]`.
3. `testClaimedCollectionPrizeIDsRoundTripOnAFreshSave`: set `["collection.1"]`, encode/decode, assert equal.
4. `testPreV10SaveMigratesWithNoCollectionPrizeClaimed`: a v9 blob (cards did not exist yet) loads with an empty list. Guards the flat-table path.

---

## 9. Claim-once guarantee

1. **One mutation.** `claimCollectionPrize()` checks `isCollectionComplete && !claimedCollectionPrizeIDs.contains(id)`, then in the same synchronous `@MainActor` call appends the ID, pays, and calls `persist()`. No `await` between check and payout, so no double tap can slip in.
2. **No half-payment.** If the prize ever includes a board item (Q2 b), the item is placed first and the claim refuses (no ID appended, nothing paid) if `placeOrBankItem` returns false.
3. **Save and load.** The ID is in the same `GameState` blob as the cards. A crash before the write lands loses the payout and the ID together, because `persist()` snapshots the whole state.
4. **Migration.** A migrated save starts unclaimed (§8.3). Migration never pays.
5. **Reinstall.** `load()` picks a whole state by `lastActiveDate` from local, backup or iCloud (`GameStore.swift:577-604`, `:1380-1388`). A reinstall restored from iCloud brings the ID back with the cards. A reinstall without iCloud is a fresh game with no cards, so the prize can only be earned again by collecting all 54 again, which is a new game, not a duplicate.
6. **Two devices.** If two devices diverge, the newer whole state wins and the other is discarded, ID and all. There is at most one paid claim per surviving state. Accepted; same as every other one-time reward in the save.
7. **Completion cannot go backwards** (§2.2), so "claimable" can only become true once.

---

## 10. Out of scope

- Any code in this task (6.1).
- Card purchase price or currency, selling missing cards for kibble (W8).
- The first-discovery collection, `?` slots, per-item rewards (held by D13).
- Events, seasonal or timed albums, resetting the collection.
- New cards, new sets, a seventh album.
- Cosmetic prizes (avatar, board theme): need art.
- A sink for stars after the collection is complete. Once every card is owned, packs only produce stars and the star shop only sells packs and jokers (`CardSystem.swift:149-204`), so stars become useless. Noted, not fixed here.
- Changing the `AlbumCompleteOverlay` timing quirk (§2.3) beyond what task 3 needs.
- `Feature_Parity_Audit.md` corrections other than the row this closes.

---

## 11. Implementation tasks (one per session)

### Task 1 — Schema v46 (persistence only)

- Field, view-model mirror, `captureState`/`apply`, `additiveDefaultsSinceV8`, dispatch line, version comment, `currentVersion` (§8).
- No behaviour, no UI. Game plays exactly as before.
- **Tests:** the four `PersistenceTests` cases in §8.4; full suite green.

### Task 2 — Grand prize rule and payout

- `CardRegistry.collectionPrizeID = "collection.1"` in `CardSystem.swift`; prize amounts in `AnimalSpecies.swift` (§5.3).
- View model: `isCollectionComplete` (every registered set in `completedAlbumIDs`), `isCollectionPrizeClaimable`, `claimCollectionPrize() -> Bool` per §9. Kibble via `withPassBonus`, coins via `earnCoins`, Dog Tags added directly as set rewards are.
- `EconomySimulation.otherCoinIncome`: add the prize coins to the amortised album term (`EconomySimulation.swift:701`).
- **Tests (new `AlbumGrandPrizeTests.swift`, pattern of `TrophyPageTests.swift`):** not claimable at 5 of 6; claimable at 6 of 6; claim pays exact kibble/Dog Tags/coins (and 1.5× kibble with the Pass active); second claim returns false and pays nothing; an unknown ID in `completedAlbumIDs` neither counts nor blocks; claimed state survives `captureState`/`apply`. Re-run `EconomyTests` (`testMapBuildOutLandsInTheTargetWindow`, `:442-451`).

### Task 3 — Collection banner and celebration

- Banner in `albumsContent` above `albumsGrid` (`CardAlbumView.swift:126-133`, `:205`): "N of 6 sets", prize pills (reuse the set banner's pill style, `:789`), Claim button, Claimed state.
- Celebration on claim, shown in `CardAlbumView` (the claim happens there, so §2.3's quirk does not bite).
- **Tests:** a view-model test that the banner's inputs (`completedSetCount`, claimable, claimed) are right in each state. **Simulator check** (owner or a session with the Simulator): banner at 0/6, at 6/6 with Claim, after claim, after relaunch still Claimed.

### Task 4 — Set-reward ramp

- Per Q1 and Q6: either the completion-order ramp (`albumSetRewardRamp` in `AnimalSpecies.swift`, `checkAlbumCompletions` pays rung `completedAlbumIDs.count` before appending; the set detail banner shows the next rung's reward) or new per-set numbers in `CardRegistry.albums`. Fix the coin order either way.
- Already-paid sets are not back-paid.
- `EconomySimulation`: add an `albumKibblePerDay` figure (ramp + prize kibble ÷ 60) **outside** `dailySupply`, which is pinned to measured values (`EconomyTests.swift:780-784`), and a test that it stays under 7% of `dailySupply(level: 5)` (originally 5%; raised 22 Nov 2026, see §12).
- Docs: `Feature_Parity_Audit.md` row to ✅ with the new citations; mark W6 done in `Revision_Plan_ModelOnReferences.md`.
- **Tests:** ramp is monotonic in every currency; rung N pays rung N whichever set completes; total equals the table; `EconomyTests` green, including `testDemandSupplyRatioMatchesTheTargetCurve` (`:754-771`), which this does not touch because `dailySupply` is unchanged.

Task 4 has no dependency on 1 to 3 and can go first if the owner prefers.

**Task 4 as built (22 Nov 2026, in review).** Three choices the bullets above left open:
- The per-set `rewardKibble`/`rewardDogTags`/`rewardCoins` fields were **removed** from `CardAlbumDefinition` and `CardRegistry.albums`, since nothing pays them any more and leaving them would show the wrong numbers. Not persisted; no save change.
- The set detail banner reads `viewModel.nextAlbumSetReward` and says "Next set completed earns:", with kibble shown after the Pass bonus (what will actually land). A finished set shows "Reward claimed!" with no amounts, because saves completed before the ramp were paid the old per-set numbers and the rung cannot be recovered honestly.
- `EconomySimulation.albumKibblePerDay` counted **ramp kibble only** when task 4 shipped (1,800 ÷ 60 = 30/day, 4.3% of L5 supply); task 2 added the grand prize kibble (43.3/day, 6.2%), under the 7% guard decided in §12. The album coin term now sums the ramp (same 6,250 total).
- Not done here: W6 in `Revision_Plan_ModelOnReferences.md` stays open (Tasks 1–3).

---

## 12. Open questions for the owner

**Decided 22 Nov 2026 (owner, option a, relayed by the coordinating session): the album kibble guard is 7%, not 5%, and the grand prize keeps its 800 kibble.** Found when task 2 was merged with task 4: counting the prize as §11 Task 4 asked, album kibble amortised over 60 days is (1,800 + 800) ÷ 60 = 43.3 a day, 6.2% of the level-5 supply of 695, so the spec's own 5% limit and its own Q2 (a) prize contradicted each other. Options were (a) raise the guard to 7% and keep the prize, (b) keep 5% and cut the prize kibble to about 280, (c) count the one-time prize outside the daily figure. Reasons for (a): the prize is paid once, at the end of the collection, and `testDemandSupplyRatioMatchesTheTargetCurve` does not read this figure. The guard is `albumKibbleGuardShareOfDailySupply` in `EconomySimulation.swift`.

**Resolved 18 Nov 2026: the owner answered "the way the project manager recommends" (relayed by the coordinating session), so every recommendation below stands:** Q1 (a) the reference's 100 to 500 kibble; Q2 (a) 800 kibble + 100 Dog Tags + 5,000 coins; Q3 (a) a Claim button on a collection banner; Q4 (a) saves that already finished all six sets may claim once; Q5 (a) keyed by collection ID (`"collection.1"`); Q6 (a) the ramp follows completion order (a recorded difference from the reference under D14). Build task 6.2 is now unblocked by the spec but **not started**; it needs its own session and the schema number assigned at build time.

1. **Q1. Set-reward numbers?** (a) The reference's 100 to 500 kibble (1,800 total); (b) today's scale with a fixed shape, 20 to 100 kibble (335); (c) leave as is. **Recommend (a):** the units match 1:1 and the extra is ~4% of daily kibble over two months.
2. **Q2. Grand prize contents?** (a) 800 kibble + 100 Dog Tags + 5,000 coins; (b) (a) plus a wildcard board item; (c) smaller, 300 kibble + 50 Dog Tags + 2,500 coins. **Recommend (a):** close to the reference, bounded, and no board-space failure case.
3. **Q3. How is the prize paid?** (a) A Claim button on a collection banner in the album; (b) automatically, like sets today. **Recommend (a):** a visible, claimable goal, and it works the same for saves that are already complete.
4. **Q4. Saves that already finished all six sets?** (a) They can claim the prize once; (b) migration marks it claimed without paying. **Recommend (a):** the game is pre-launch, so these are test saves, and they did earn it.
5. **Q5. Key the prize by a collection ID or a single yes/no?** (a) Collection ID (`"collection.1"`), so a future album can add its own prize without a schema bump; (b) a Bool. **Recommend (a):** same cost now, saves a migration later.
6. **Q6. Does the ramp follow set identity or completion order?** (a) Completion order: the first set you finish pays 100, the sixth 500; (b) fixed per set, as the reference does. **Recommend (a):** PawSanctuary's sets are equally hard (packs draw uniformly), so a fixed ramp would pay 500 to whichever set luck finishes first; this is a recorded difference under D14.

---

## 13. Spec vs code and doc discrepancies found

1. **Stale citation.** `Feature_Parity_Audit.md` row "Set vs. album reward asymmetry" cites `checkAlbumCompletions` at `MergeBoardViewModel.swift:2836-2847`; it is at `:2855-2867`. The next row's `buyFromStarShop :2865-2877` and `useJoker :2820-2833` have also drifted (now `:2884-2896` and `:2839-2853`).
2. **"Ramp" overstated.** The same row says set rewards ramp 30 to 100 kibble (~3.3×). Kibble is not monotonic: Sanctuary Friends pays 0 (`CardSystem.swift:253`). Coins are not monotonic either (Vet Records 750 < Animal Kingdom 1,000, `:261`, `:269`). Dog Tags already ramp 5× (5 to 25).
3. **Reference prize described two ways.** `Merge2_Reference_Blueprint.md` §6 says the grand prize is "250 gems + 800 energy + a wildcard"; the re-checked audit row reads the same screenshot as "250 gems + 800 energy + 1 crystal + 1 avatar", and attributes the wildcard to a different album (`Reference_Data_Extract.md` §11). The audit is the later reading; the Blueprint line looks merged from two albums.
4. **Migration convention vs practice.** CLAUDE.md says migration helpers follow `migrateVNtoVN+1`; since v29 every additive bump has used `migrateByInjecting` with no helper (`GameStore.swift:702-717`). Not a bug; this spec follows the code for additive changes (§8.3).
5. **Tuning-constant convention.** CLAUDE.md puts tuning numbers at the bottom of `AnimalSpecies.swift`; the set rewards live inline in `CardRegistry.albums` (`CardSystem.swift:245-285`). Treated as content here (§5.3), not moved.
6. **Ramp order is meaningless today.** Sets are equally hard (`CardSystem.swift:371-386`), so the registry-order ramp is not experienced as rising. Not stated anywhere in the docs.
7. **Album kibble and Dog Tags are outside the economy model.** `EconomySimulation` amortises only album coins (`:701`); the triage and audit do not mention it.
8. **Dispatch order.** `readValid` checks v44 before v43 (`GameStore.swift:716-717`). Harmless (each line is an equality test), noted only so the v45 line is not placed by pattern-matching on order.
