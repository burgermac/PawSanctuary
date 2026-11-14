# Feature-Parity Audit — PawSanctuary vs. Gossip Harbor / Travel Town / Tasty Travels

**Read from source 13 August 2026.** Requested in `TODO.md` under "Competitive analysis": the Gap Analysis docs (`PawSanctuary_Gap_Analysis.md`, `Gap_Analysis_Round2.md`) deliberately scoped themselves to *gameplay psychology* — the mechanisms driving return visits and spend — and explicitly did not enumerate feature-by-feature coverage. This is that enumeration.

**Sources:** `Merge2_Reference_Blueprint.md`, `Reference_Data_Extract.md`, `Findings_26July.md`, `Phase2_Economy_Model.md` (companion to `Phase2_Economy_Model.xlsx`), cross-checked against the current PawSanctuary source (`PawSanctuary/*.swift`).

**Updated 9 Oct 2026.** Rows marked "Re-checked 9 Oct 2026" were verified against the current source and changed; everything else is as read on 13 Aug. A section below lists what was built since.

**Updated 13 Nov 2026.** The five rows that were still unverified (terminal-tier messaging, days-per-level ramp, set-vs-album reward asymmetry, card purchase by rarity, price-ladder value curve) were re-read against the reference footage and the current source; each is marked "Re-checked 13 Nov 2026". Recordings examined are listed under "Rows still unverified" at the end.

**Legend:** ✅ present and functionally equivalent · 🟡 present but structurally thinner than the reference · 🚧 infrastructure exists, not player-facing · ❌ absent

---

## 1. Board & merge core

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Board geometry | 7×9 = 63 tiles, single screen | ✅ | Matches exactly — arrived at independently per the blueprint. |
| Chain depth | 8–13 tiers observed, up to 12+ | ✅ | 12 tiers (`animalChainTopTier = 11`), cut down from an original 15 (`ItemChain.swift`). |
| Tier number surfaced in UI (`Lv.9`) | Yes, called out as important — "converts an opaque exponential into a legible ladder" | ✅ **Built 9 Oct 2026** — a "Lv.N" badge in each ladder tile's bottom-left (animals, supplies, materials, toolbox, sub-objects; not currencies, power-ups or the wildcard). The selected-item info line already said "Level N" for animals, so only the always-visible badge was missing. Original finding: | `CellView.swift` shows only the tier's name (`shortLabel`, e.g. "Groomed"), never a numeric badge. Unexamined gap, not a decision — cheap to add. |
| Terminal-tier messaging | `"Max level reached for this item."` — in the **selected-item info bar**, not on the tile | ✅ | **Re-checked 13 Nov 2026.** **Reference:** Tasty Travels L102, `ScreenRecording_07-25-2026 15-45-15_1.MP4` at 15 s (Luxury Carry Bag, Lv.7) and 37 s (Royal Gazebo, Lv.7): the message appears only in the bottom info bar when the item is selected. The maxed tiles themselves carry no "MAX" badge, text or level number. The other Tasty Travels clips show the same thing (`15-53-20` at 3 s, `15-58-52` at 3 s, `16-03-48` at 3 s, `16-07-24` at 39–42 s, `16-13-50` at 3–6 s). Travel Town's parallel board uses the same pattern, with the hint bar reading "this item is at MAX level" (`ScreenRecording_08-22-2026 21-33-09_1.MP4` ~91 s, `Spec_ParallelBoardReview_Draft.md` §3.4). So the earlier claim that the reference shows persistent "maxed" text on tiles is **not supported by the footage**. **PawSanctuary:** the info line appends "· Ambassador — top tier" for any top-tier item (`MergeBoardViewModel.swift:716-717`). The tile has a persistent gold gradient ring (`CellView.swift:95-100`), and on the SF Symbol fallback the symbol turns yellow (`CellView.swift:176`). Reaching the top tier also fires `triggerTopTierCelebration` (`MergeBoardViewModel.swift:2331-2332`). **Verdict: matches**, and the persistent ring goes further than the reference. Gossip Harbor was not checked for this. |
| Sell any item, tier-scaled | Listed as a universal pressure valve | ✅ | `sellSelectedAnimal`, `sellValue(forTier:)`. |
| Splitter / reverse-a-merge | Store item, 50 gems, "reverses a merge one tier" | 🟡 | Exists as `applySplitterPiece` (Felines "Nine Lives" superpower), not a purchasable store item — same effect, different access path (earned/rolled vs. bought on demand). |
| Chores (soft-currency tasks paying XP) | Listed as "a second use for coins, parallel to orders" | ❌ | **Decided 9 Oct 2026: not adopted (Alignment Plan D10).** PawSanctuary's coins are not idle — the map's 291,900 coins are pinned to a 55–70-day build-out by a test — and a new XP source shifts the level-gated wall and monetization unlock. The reference data records one line and no numbers. Revisit only if playtest data shows coins accumulating unspent. |
| Cosmetic choice (no-cost color/theme) | "An ownership device, not a sink" | ✅ | **Re-checked 9 Oct 2026.** Five free **board themes** (Meadow, Seaside, Dusk; Autumn and Blossom unlocked by 3 and 6 built Sanctuary areas), offered once in session one and changeable from Profile (`Spec_BoardThemes.md`, schema v44). The reference does not say what it customises, so the scope is PawSanctuary's own. |

## 2. Energy / generators

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Regen rate | 2:00/unit (Travel Town, stated in-game) | 🟡 | Kibble regens 1/min — twice the reference rate, i.e. a more generous curve. Deliberate per the locked "mirror the segment leader, then be generous early" posture, not a gap. |
| Energy cap growth | ~100 at L46, ~1,435 at L100 — barely scales | 🟡 | Kibble cap is flat at 100 (150 at level 10+) — doesn't scale by level band at all. Simpler than the reference, arguably fine given kibble's much faster regen; not independently verified against PawSanctuary's own wall curve. |
| Power Boost / spawn multiplier | ×1/2/4/8/16, exactly energy-neutral by construction, dominant strategy | ✅ | `spawnMultiplier` (1/2/4/8), confirmed energy-neutral by `EconomyTests.testEveryMultiplierIsEnergyNeutral`. Matches the reference finding almost exactly, independently arrived at. |
| Bonus rolls gated to boosted taps | 0 events at ×1 vs. 12–15 at ×4 in a controlled sample | ✅ | `legendaryBonusShare` bonus layer on boosted spawns (Gap_Analysis_Round2 C-2, closed). |
| Currency-as-merge-chain on the board | "The single largest structural miss" in the original blueprint — coins/energy spawn and merge like any item | ✅ | `currency.kibble` / `currency.coin` chains spawn and merge on the board (Phase 4, Task 4.1) — this was explicitly adopted, not missed. |
| Generator cooldown class system | An order of magnitude spread: 2m44s to 30m, deliberately two classes (fast common / slow "return visit" premium) | 🟡 | **Re-checked 9 Oct 2026.** Family spawners now cool down for **30 s after every 150 kibble they spend**, per spawner, skippable for 2 Dog Tags (`Spec_SpawnerCooldown.md`) — built at Tim's direction, overruling an earlier recommendation of none. Legacy rescue producers and the shop supply boxes keep their 25–60 s per-tap cooldowns. There is still **no 30-minute "return-visit" class**: the Free Chest (4 h) and the Kibble Drive windows fill that role. Whether to add a premium long-cooldown generator is an open content decision, not a gap in the mechanism. |
| Chest-as-purchased-spawner | A bought energy chest doesn't credit currency directly — it becomes a board spawner that produces it over several taps | ❌ | PawSanctuary's Dog Tag / kibble IAP packs credit currency directly on purchase. The "purchase costs board space and taps too" mechanic doesn't exist. |
| Item purchase from chain inspector | "SEE IN STORE" button in the chain viewer, 14 gems mid-tier | 🟡 | Same *function* exists (buy a specific chain/tier for Dog Tags — `DogTagStore`), but it's a separate shop section, not a contextual button while inspecting a chain. |

## 3. Orders

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Concurrent slots | 4–5 | ✅ | 4 base slots + urgent order (`adoptionOrderCount`). |
| Reward-rider list (multiple currencies per order) | Every order carries a base coin payout plus 2+ event-currency riders | ✅ | `AdoptionOrder` rewards modeled as a list from Phase 0 per design intent; riders confirmed in `PanelViews.swift`'s `AdoptionOrderCard`. |
| Difficulty spread | Easy/medium/hard payout scale (14,500→46,000 coins observed) | ✅ | `orderSlotDifficultyPattern`, tier tables per difficulty (Gap_Analysis_Round2 C-5, closed). |
| Persistent vs. urgent split | — | ✅ | Standing slots never expire; urgent order has its own timer (Gap_Analysis_Round2 C-6, closed). |

## 4. Meta progression (map / building)

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Structure depth | building → level → task → multi-resource cost, 3+ distinct part types | ✅ | `SanctuaryArea` → `AreaUpgradeTier`, costs in coins + `MaterialCost` across wood/metal/cement — same shape, three part types. |
| Days-per-level ramp | ~1 day early → ~10 days at endgame, data-forced | 🚧 | **Re-checked 13 Nov 2026: still cannot be verified.** **Reference:** this is a **fitted** value, not a measured one. `Phase2_Economy_Model.md` (line 31, and the band table at lines 85–92) solves for the ramp from the measured ~290,000-coins-per-endgame-task anchor; it was never observed. The footage shows what a building step costs (for example Tasty Travels Spa "Level 6/7, Task 4", 290,000 coins, in `ScreenRecording_07-25-2026 16-07-24_1.MP4` at 3 s) but never how many days a level takes. Measuring that would need one account tracked over weeks, or telemetry. **PawSanctuary:** there is no per-level ramp. The economy is tuned to a whole-map total: 291,900 coins built out in 55–70 days for a player who sells (`EconomyTests.swift:442-451`, `:462-464`), from which `coinsPerKibbleOfOrder = 6.5` is derived (`AnimalSpecies.swift:2205-2210`). The earlier "order/sell ratio" note described the derived constant, not the anchor. **Verdict:** the two cannot be compared — the reference figure is a model fit, and PawSanctuary collects no per-level timing. Possible follow-up, owner decision: log days per area level in `PlaytestMetrics` once real players exist. |
| Forever-goal scale | ~8.3M coins for one endgame building | 🟡 | 291,900 coins across 61 map entries total (per `Gap_Analysis_Round2.md`'s own coin-economy note) — a smaller total forever-goal than the reference's per-building cost alone. Likely appropriate for a solo-dev game's realistic playtime horizon; flagged as a scale difference, not a defect. |

## 5. Live-ops & events

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Live-ops primitives (milestone track, parallel board, competitive, timed order, reward table) | 8 primitives cataloged, all observed in the wild | ✅ | **Re-checked 9 Oct 2026.** Every primitive is implemented and in use (Phase 6a–6c): milestone track, Pass, parallel board, a rolling 90-day calendar of 13 weekly events and 3 Passes. Since the audit two more live-ops shapes were added: the **Reward Ladder** (D8) and the **Kibble Drive** (a paid, activity-fed ladder). Only competitive events are absent, and that is deliberate (3.8). |
| Concurrent events | 6+ simultaneous timers observed, ranging 4 minutes to 29 days, layered | ✅ | **Re-checked 9 Oct 2026.** The single-active-event model was replaced in Phase 6c (`EventRegistry.activeEvents`). Weekly events, a Pass, parallel-board events and Kibble Drive windows now run at once, and the calendar deliberately overlaps them. This was the audit's "single largest structural gap". |
| Parallel board (a complete second mini-game, e.g. "Petal Talk") | Own board, generators, chain, currency, progress track, 36h duration | 🟡 | **Re-checked 9 Oct 2026.** Built (`Spec_Phase6b_ParallelBoard.md`): a full-screen second board with its own chain, energy, generator and progress track, verified on screen on its real opening day, 11 Sep. It is structurally thinner than the reference's Greek Fest (`Spec_ParallelBoardReview_Draft.md` §2): a smaller board, an in-grid generator rather than an off-grid pedestal, one progress track rather than a 27-set collection, and — the one that changes the design — **no main-board token faucet**: energy is a self-contained timer, whereas the reference feeds it from main-board orders and sells a booster on that flow. ~~Undecided.~~ **Faucet shipped 9 Oct 2026** (`Spec_ParallelOrderEnergy.md`, commit `8d05901`, PR #51): each main-board order claimed during a live event adds +1 parallel-board energy, bankable to 60; passive regen kept. No booster sold on it. |
| Competitive events (duels, tournaments, ranked races) | All three reference titles run them | ❌ | This is 3.8 in `Gap_Analysis_Round2.md` — deliberately deferred 2026-08-13 pending player population. `LiveOpsEngine` could host it. |
| Event Pass (paid lane) | — | ✅ | `Spec_Phase6b_Pass.md`, `passUnlockedEventIDs`. |
| Sanctuary Pass (recurring subscription) | — | ✅ | `IAPProduct.sanctuaryPass`, $4.99/mo per `TODO.md`'s pricing notes. |

## 6. Collectible albums / cards

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Album structure | 135–162 cards, 15–18 sets, 9 cards/set | 🟡 | 54 cards total (`CardSystem.swift`) — same structural shape (sets, rarity tiers, duplicates), smaller scale. Appropriate for game maturity; not a gap. |
| Rarity tiers | 1★–4★ | ✅ | Card rarity system present. |
| Duplicates → Stars → Star Shop | Chests at 100/200/500 stars | ✅ | `duplicateStars`, `starShopCost` (`CardSystem.swift`). |
| Set vs. album reward asymmetry | Set rewards ramp 100 → 500 energy; completing the whole album pays a separate grand prize | ❌ | **Re-checked 13 Nov 2026.** **Reference:** the "Water Wonders" album (135 cards, 32d 6h) offers 250 gems + 800 energy + 1 crystal + 1 avatar for "Collect all the card sets" (screenshot `Screen Shots/analyzed images/Screenshot 2026-07-26 at 2.09.57 PM.png`). Its last set, Undersea Party, pays 500 energy + 1 mystery box + 1 gem item (`…2.12.17 PM.png`). The set ramp (100 → 500, 6 of 15 sets measured) is in `Findings_26July.md` §5c. On that basis the grand prize is ~800 of the ~4,350 energy the album returns, plus all of its gems. The old row's "1,000 gems" comes from a different album (`Reference_Data_Extract.md` §11: album completion 1 wildcard + 1,000 gems + chest + 4 toolboxes, set completion 100–150 energy). Both titles put the value at completion. No recording shows an album screen. The nearest is an event-scoped item collection in Tasty Travels' "Pet Home" event (`ScreenRecording_10-09-2026 15-29-24_1.MP4` at 42–51 s), where a set pays 1 box + 30m timer + 1 card pack and a crystal is shown at the end of the 36-item bar. That is not the card album and is not counted here. **PawSanctuary:** the six "albums" are the reference's *sets* (9 cards each, `CardSystem.swift:248-297`). Their rewards ramp from 30 kibble + 5 tags (Rescue Profiles) to 100 kibble + 25 tags + 2,500 coins (Hall of Fame), 280 kibble in total. `checkAlbumCompletions` pays per album only (`MergeBoardViewModel.swift:2836-2847`), so there is **no reward for completing all six**. **Verdict: differs.** The set ramp is present (~3.3× on kibble against the reference's 5×), but the completion grand prize — where the reference puts the value — is absent. Possible follow-up, owner decision: add a whole-collection reward. That is a persisted-shape change and needs a schema bump. |
| Card purchase by rarity | 4★ = 35 energy, 5★ = 50 (3★ = 25 per `Findings_26July.md`) — only high-rarity purchasable, paid in **energy** | ❌ | **Re-checked 13 Nov 2026.** **Reference:** the Undersea Party set page (`Screenshot 2026-07-26 at 2.12.17 PM.png`) shows buy prices on missing cards: 35⚡ on a 4★ card, 50⚡ on three 5★ cards. The missing 3★ cards on the same page carry no price, so the 3★ = 25 figure is not visible in that frame (`Findings_26July.md` §5c records it, noting that only a subset is offered at once). This album also runs to 5★, against the 1★–4★ in `Reference_Data_Extract.md` §11, which is a different album. No recording examined shows a card purchase. **PawSanctuary:** single cards cannot be bought with kibble. The Star Shop (paid in duplicate stars) sells 1★/2★/3★ packs for 20/35/55 stars and jokers: a common joker for 40 stars fills any missing common, a rare joker for 120 fills any missing rare (`CardSystem.swift:159-214`; `buyFromStarShop` at `MergeBoardViewModel.swift:2865-2877`; `useJoker` at `:2820-2833`). Card rarity is only common/rare (`CardSystem.swift:14-19`). **Verdict: differs.** Rarity-tiered gap-filling exists (jokers), but it costs stars rather than energy, commons are buyable too, and there is no energy sink competing with the board. Possible follow-up, owner decision: whether the album should take kibble, which would be the "second demand curve for energy" `Findings_26July.md` §4 calls structural. |
| Trading exposed in-UI | Yes | ✅ | `CardTrading.swift`, Game Center + CloudKit-backed. |
| Card packs bundled with IAP | Every pack above $1.99 | ✅ | Every `EnergyPackContents` tier carries a `cardPack` (`AnimalSpecies.swift:927-939`). |

## 7. Social

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Card trading | ✅ (album section above) | ✅ | |
| Invite/referral milestones | — | ✅ | `InviteSystem.swift`, `inviteMilestones`. |
| Named characters / scripted dialogue | Tasty Travels only, not Travel Town — a "light narrative spine" | ❌ | **Decided 9 Oct 2026: held (Alignment Plan D11).** Stay lean like Travel Town until retention data from real play says the lean version is thin — there is none yet. The "Almost there!" order nudge already gives families one line of voice. |
| Out-of-app loyalty surface | Web PWA, own auth, level 35+ | ❌ | 3.9 in `Gap_Analysis_Round2.md` — deliberately deferred 2026-08-13; this is separate infrastructure (own backend/hosting), not an in-app feature. |

## 8. Daily / weekly / monthly retention

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Weekly goal ladder | 5 point-weighted tasks, 170/420 pts for the reward | ✅ | **Re-checked 9 Oct 2026.** The coin-based Bronze/Silver/Gold weekly goal still exists, but the point-weighted task ladder the audit asked for is now **Care Points** (v38): 120 / 320 / 520 points a week fed by quest claims, daily-task sweeps and order claims, paying Dog Tags, XP and card packs. Crossing a tier raises a full-screen milestone takeover (`Spec_MilestoneTakeover.md`). |
| Daily rewards | 7-day cycle + slower "Total Days" milestone track underneath it | ✅ | **Re-checked 9 Oct 2026.** The **Total Days** track (v43, `Spec_TotalDaysTrack.md`) runs under the 7-day Good Morning cycle with milestones at the measured 8 / 15 / 22 / 30 in repeating 30-day cycles; it never resets on a gap. The thresholds are measured, **the rewards are not** (the reference extract records none). The reward is now paid when the day registers, so quitting before tapping the popup no longer loses it (`Spec_LoginGrantAtCheck.md`). |
| Daily challenges | Near-miss stagger (next challenge 60–90% done when current finishes) | 🟡 | **Re-checked 9 Oct 2026.** Dailies are no longer counted-event challenges: they are three **hand-in baskets** of specific creatures held on the board and surrendered for coins (`Spec_DailyHandInTasks.md`), matching how the reference titles' own daily tasks work. The near-miss stagger was deliberately **dropped for dailies** (a basket of mixed creatures cannot share an anchor); it still operates on standing quests and the order-slot spread (`Gap_Analysis_Round2.md` 3.1). |
| "Spend N currency" quest (a spend quota disguised as a quest) | Observed in Tasty Tasks — explicitly flagged as the most aggressive daily-system item | ✅ | **Re-checked 9 Oct 2026.** Adopted anyway (D6, `Spec_SpendQuotaDailies.md`), overriding the Alignment Plan's own "out" recommendation: `QuestGoal.spendCurrency` now exists. It reaches players through **standing quests** (`Spec_StandingQuestSpendGoals.md`); its daily-challenge half went away when dailies became hand-in baskets. |
| Monthly goal | — | ✅ | `monthlyGoalClaimed`, monthly variant of the weekly system. |

## 9. Monetization surfaces

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Session-one silence | No monetization surface at all in session one | ✅ | Gap_Analysis_Round2 C-8, closed — `isMonetizationUnlocked` gate. |
| The wall (ad + gem choice) | Rewarded video offered *inside* the out-of-energy dialog, 3/day, free | 🟡 | `KibbleRefillSheet` is built around this exact structure and `watchRewardedAd()` lives at the wall (Gap_Analysis_Round2 C-7, closed) — but `AdProvider.swift`'s `StubAdProvider` just waits 1.5s and always succeeds; no real ad SDK is wired (`TODO.md`, blocked on an SDK/account decision). Structurally correct, not yet real. |
| Escalating daily purchase ladder | Gems: 10/20/40, resets daily | ✅ | `DogTagKibbleExchange.dailyLadder = [15, 30, 60]` — same doubling shape, independently arrived at. |
| Price ladder value curve | 2.0× value bottom-to-top, steepest gains $2→$20 | 🟡 | **Re-checked 13 Nov 2026.** **Reference:** gem shelf 80/$1.99 → 8,000/$99.99, value index 1.00 / 1.20 / 1.44 / 1.74 / 1.94 / 1.99 (`Reference_Data_Extract.md` §2). Not in the available footage: none of the recordings examined shows a gem store, so the figures rest on the July screenshots. **Provenance conflict:** `Reference_Data_Extract.md` §2 labels this shelf "Travel Town, US storefront", but `Capture_Log.md` (29 Jul entry, "Pricing — cannot be assessed") says it was measured in **Tasty Travels** and that Travel Town's shelf was never measured. **PawSanctuary:** contrary to the earlier note, prices *are* in the repo, in the StoreKit testing config `PawSanctuary/PawSanctuary.storekit` (lines 7–167). Live App Store Connect prices may still differ (`TODO.md`: product IDs are not yet registered). Amounts come from `AnimalSpecies.swift:1219-1258`. Kibble bags 60/$0.99, 180/$1.99, 600/$4.99 give index 1.00 / 1.49 / 1.98. Dog Tags 15/$0.99, 60/$2.99, 175/$6.99 give 1.00 / 1.32 / 1.65. Energy packs ($0.99/$2.99/$4.99/$9.99) are **flat** on currency: 25/20/24/25 kibble per $ and 8.1/6.7/8.0/8.0 tags per $, with value rising only through spawner tier and count and card-pack tier, which have no price. **Verdict: differs in shape.** The kibble ladder reaches the reference's ~2× within a 5× price span ($0.99–$4.99), much steeper than the reference's 2× over 50×. Dog Tags are shallower, energy packs are flat on currency, and nothing sits above $9.99. Possible follow-up, owner decision: check this against App Store Connect prices once they are set. The `energyLarge`/`energyXL` reposition is already deferred by decision (`Spec_KibbleDrive_Draft.md` §6g). |
| Contextual vs. rotating offer differentiation | Same price, different value density depending on player state | ❌ | No contextual-offer system — IAP packs are static regardless of player state. |
| Purchase-progress promotion (VIP ladder) | Purchases earn points toward a track/prize | ✅ | 3.7, closed this session. |
| First-purchase offer | Highest-leverage single offer in the game, visible only pre-first-purchase | ✅ | **Re-checked 9 Oct 2026.** The kibble-refill sheet shows a "Welcome Offer" (the Sanctuary Starter Pack) until the player's first purchase and the smallest energy pack afterwards (`commerce.hasEverPurchased`). It appears at the wall, not as a standing storefront banner. |
| Store item stock limits ("2 left") | Scarcity pressure on shop slots | ✅ | `DogTagStoreSlot`, stock 1 each, daily rotation. |
| Piggy bank | Passive accumulator, paid to crack | ✅ | 3.4, closed this session. |
| Timed free chests | Free with a wait, soft speed-up sink | ✅ | 3.6, closed this session. |
| Wildcard | Merges with anything | ✅ | 3.5, closed this session. |
| Bubble mechanic | Item locked, wait or pay to unlock, decays rather than destroyed | ✅ | `BubbleMechanicTests.swift`, `bubbleChance`/`bubbleMinTier`/decay (Gap_Analysis_Round2 C-4, closed — "the retune is better than my spec" per that doc). |

---

## Built since this audit (13 Aug – 9 Oct 2026)

None of this is a gap any more; it is listed so the table above can be read against it. Each links to its spec.

- **Orders and tasks:** order baskets, Smile Points, Care Points (`Spec_OrdersAndTasks_Draft.md`); hand-in dailies (`Spec_DailyHandInTasks.md`); the task tray and quest lane cards (`Spec_TaskTrayRedesign_Draft.md`, `Spec_QuestLaneCards_Draft.md`); the "Almost there!" nudge and per-currency reward flights (`Spec_TravelTownReview_Draft.md` §2, §5).
- **Retention:** the Total Days login track, pay-at-check login reward, and the Care Points milestone takeover.
- **Monetization (under D9, retention first):** the Reward Ladder (D8) and the Kibble Drive.
- **Board feel:** the Lv.N tier badge, the producer-to-cell spawn flight (`Spec_SpawnFlight.md`) and the family spawner cooldown (`Spec_SpawnerCooldown.md`), alongside the earlier merge burst and producer shimmer.
- **Live-ops:** the concurrent-event model, the 90-day calendar and the parallel board (Phase 6).

## What is still open

**Real gaps, awaiting a decision**
- ~~**Parallel Board token faucet** — main-board orders and milestones feeding the parallel board's energy (see its row above). The largest remaining design question.~~ **Closed 9 Oct 2026:** orders now feed it (`Spec_ParallelOrderEnergy.md`, `8d05901`, PR #51). Corrected 10 Nov 2026.
- **Chest-as-purchased-spawner** and **contextual offers** — both monetization; both lower priority under D9.
- **Chores and named characters / dialogue** — both now **decided** (D10: chores not adopted; D11: characters held until retention data exists). Cosmetic choice was built as board themes.
- **A long-cooldown premium generator class** — a content decision (see the cooldown row).

**Deliberately held back:** competitive events (3.8) and the out-of-app loyalty surface (3.9), pending a player population; the Party Board, pending more reference footage. ~~Merge-animation Tier B, pending the `BoardStateManager` Phase D refactor.~~ Phase D was already complete on 15 Aug 2026 (`3b060ea`, `MergeResult.swift`), and the owner un-parked Tier B on 10 Nov 2026; an implementable spec is queued (`PROJECT_STATE.md`). Corrected 10 Nov 2026.

**Rows still unverified** — **re-read 13 Nov 2026** against the footage and the current source (details in each row):
- **Terminal-tier messaging:** matches. The reference shows "Max level reached" only in the selection info bar, never on the tile. PawSanctuary has the info-line equivalent plus a persistent gold ring.
- **Set vs. album reward ratio:** differs. PawSanctuary has the set ramp but no whole-collection completion prize.
- **Card purchase by rarity:** differs. PawSanctuary's gap-fillers are star-priced jokers (commons included); nothing is bought with kibble.
- **Price-ladder value curve:** differs in shape. It is now readable from `PawSanctuary.storekit`, not App Store Connect. The kibble ladder is ~2× over $0.99–$4.99; energy packs are flat on currency.
- **Days-per-building-level ramp:** **still unverifiable.** The reference figure is a model fit, not a measurement, and PawSanctuary collects no per-level timing. It needs telemetry, not more footage.

Any change suggested above is an owner decision, not part of this audit.

*Recordings examined (13 Nov 2026), triaged with `scripts/refvideo.swift sheet` at 3 s steps:* Tasty Travels `analyzed videos/ScreenRecording_07-25-2026` `15-45-15`, `15-53-20`, `15-56-25`, `15-58-52`, `16-03-48`, `16-07-24`, `16-08-41` (Petal Talk parallel board, not relevant) and `16-13-50`. Full frames were taken from `15-45-15` at 15 s and 37 s. Also `ScreenRecording_10-09-2026 15-29-24_1.MP4` (Tasty Travels "Pet Home" collection, cropped at 42 s and 51 s). `ScreenRecording_10-15-2026 10-35-02_1.MP4` is not game footage. None of these shows a card album, a card purchase or a gem shelf. The album and card-price readings rest on the 26 Jul screenshots (`Screen Shots/analyzed images/Screenshot 2026-07-26 at 2.09.57 PM.png`, `…2.12.17 PM.png`), and the Travel Town max-level hint on `Spec_ParallelBoardReview_Draft.md` §3.4. The Gossip Harbor FTUE recordings (`07-25-2026 20-09` to `20-45`) and the July 26 clips were not re-triaged. The FTUE capture reaches the album's opening at level 5 (`Merge2_Reference_Blueprint.md` §9, which says the 33-day album has opened by level 5), so it may hold an album screen not yet read.

**Not code:** the real ad SDK behind the wall (AdMob, decided 10 Nov 2026), iCloud and Game Center capabilities, and the App Store submission items — see `TODO.md`.
