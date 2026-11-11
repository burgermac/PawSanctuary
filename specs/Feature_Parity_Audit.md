# Feature-Parity Audit — PawSanctuary vs. Gossip Harbor / Travel Town / Tasty Travels

**Read from source 13 August 2026.** Requested in `TODO.md` under "Competitive analysis": the Gap Analysis docs (`PawSanctuary_Gap_Analysis.md`, `Gap_Analysis_Round2.md`) deliberately scoped themselves to *gameplay psychology* — the mechanisms driving return visits and spend — and explicitly did not enumerate feature-by-feature coverage. This is that enumeration.

**Sources:** `Merge2_Reference_Blueprint.md`, `Reference_Data_Extract.md`, `Findings_26July.md`, `Phase2_Economy_Model.md` (companion to `Phase2_Economy_Model.xlsx`), cross-checked against the current PawSanctuary source (`PawSanctuary/*.swift`).

**Updated 9 Oct 2026.** Rows marked "Re-checked 9 Oct 2026" were verified against the current source and changed; everything else is as read on 13 Aug. A section below lists what was built since.

**Legend:** ✅ present and functionally equivalent · 🟡 present but structurally thinner than the reference · 🚧 infrastructure exists, not player-facing · ❌ absent

---

## 1. Board & merge core

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Board geometry | 7×9 = 63 tiles, single screen | ✅ | Matches exactly — arrived at independently per the blueprint. |
| Chain depth | 8–13 tiers observed, up to 12+ | ✅ | 12 tiers (`animalChainTopTier = 11`), cut down from an original 15 (`ItemChain.swift`). |
| Tier number surfaced in UI (`Lv.9`) | Yes, called out as important — "converts an opaque exponential into a legible ladder" | ✅ **Built 9 Oct 2026** — a "Lv.N" badge in each ladder tile's bottom-left (animals, supplies, materials, toolbox, sub-objects; not currencies, power-ups or the wildcard). The selected-item info line already said "Level N" for animals, so only the always-visible badge was missing. Original finding: | `CellView.swift` shows only the tier's name (`shortLabel`, e.g. "Groomed"), never a numeric badge. Unexamined gap, not a decision — cheap to add. |
| Terminal-tier messaging | `"Max level reached for this item."` | 🟡 | Top-tier items get a celebration banner (`triggerTopTierCelebration`) but board tiles don't show persistent "maxed" state text the way the reference does. |
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
| Days-per-level ramp | ~1 day early → ~10 days at endgame, data-forced | 🚧 | Not independently modeled — PawSanctuary's coin sink scaling (`Phase2c` coin economy) targets a different anchor (order/sell ratio) rather than a measured days-per-building-level curve. Not verified either way; would need in-game telemetry PawSanctuary doesn't yet collect. |
| Forever-goal scale | ~8.3M coins for one endgame building | 🟡 | 291,900 coins across 61 map entries total (per `Gap_Analysis_Round2.md`'s own coin-economy note) — a smaller total forever-goal than the reference's per-building cost alone. Likely appropriate for a solo-dev game's realistic playtime horizon; flagged as a scale difference, not a defect. |

## 5. Live-ops & events

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Live-ops primitives (milestone track, parallel board, competitive, timed order, reward table) | 8 primitives cataloged, all observed in the wild | ✅ | **Re-checked 9 Oct 2026.** Every primitive is implemented and in use (Phase 6a–6c): milestone track, Pass, parallel board, a rolling 90-day calendar of 13 weekly events and 3 Passes. Since the audit two more live-ops shapes were added: the **Reward Ladder** (D8) and the **Kibble Drive** (a paid, activity-fed ladder). Only competitive events are absent, and that is deliberate (3.8). |
| Concurrent events | 6+ simultaneous timers observed, ranging 4 minutes to 29 days, layered | ✅ | **Re-checked 9 Oct 2026.** The single-active-event model was replaced in Phase 6c (`EventRegistry.activeEvents`). Weekly events, a Pass, parallel-board events and Kibble Drive windows now run at once, and the calendar deliberately overlaps them. This was the audit's "single largest structural gap". |
| Parallel board (a complete second mini-game, e.g. "Petal Talk") | Own board, generators, chain, currency, progress track, 36h duration | 🟡 | **Re-checked 9 Oct 2026.** Built (`Spec_Phase6b_ParallelBoard.md`): a full-screen second board with its own chain, energy, generator and progress track, verified on screen on its real opening day, 11 Sep. It is structurally thinner than the reference's Greek Fest (`Spec_ParallelBoardReview_Draft.md` §2): a smaller board, an in-grid generator rather than an off-grid pedestal, one progress track rather than a 27-set collection, and — the one that changes the design — **no main-board token faucet**: energy is a self-contained timer, whereas the reference feeds it from main-board orders and sells a booster on that flow. Undecided. |
| Competitive events (duels, tournaments, ranked races) | All three reference titles run them | ❌ | This is 3.8 in `Gap_Analysis_Round2.md` — deliberately deferred 2026-08-13 pending player population. `LiveOpsEngine` could host it. |
| Event Pass (paid lane) | — | ✅ | `Spec_Phase6b_Pass.md`, `passUnlockedEventIDs`. |
| Sanctuary Pass (recurring subscription) | — | ✅ | `IAPProduct.sanctuaryPass`, $4.99/mo per `TODO.md`'s pricing notes. |

## 6. Collectible albums / cards

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Album structure | 135–162 cards, 15–18 sets, 9 cards/set | 🟡 | 54 cards total (`CardSystem.swift`) — same structural shape (sets, rarity tiers, duplicates), smaller scale. Appropriate for game maturity; not a gap. |
| Rarity tiers | 1★–4★ | ✅ | Card rarity system present. |
| Duplicates → Stars → Star Shop | Chests at 100/200/500 stars | ✅ | `duplicateStars`, `starShopCost` (`CardSystem.swift`). |
| Set vs. album reward asymmetry | Set rewards deliberately trivial (100–500 energy) relative to album completion (1,000 gems) | 🚧 | Not independently verified — would need to compare PawSanctuary's per-set vs. per-album reward ratio directly; not confirmed either present or absent. |
| Card purchase by rarity | 3★ = 25 energy, 4★ = 35, 5★ = 50 — only high-rarity purchasable | 🚧 | Not confirmed either way from this pass — needs a direct read of the Star Shop's purchase paths. |
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
| Price ladder value curve | 2.0× value bottom-to-top, steepest gains $2→$20 | 🚧 | Not independently verified — would need PawSanctuary's actual App Store Connect pricing, which isn't set in-repo (`ShopItemPreviewRow` shows "Pricing set in App Store Connect"). |
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
- **Parallel Board token faucet** — main-board orders and milestones feeding the parallel board's energy (see its row above). The largest remaining design question.
- **Chest-as-purchased-spawner** and **contextual offers** — both monetization; both lower priority under D9.
- **Chores and named characters / dialogue** — both now **decided** (D10: chores not adopted; D11: characters held until retention data exists). Cosmetic choice was built as board themes.
- **A long-cooldown premium generator class** — a content decision (see the cooldown row).

**Deliberately held back:** competitive events (3.8) and the out-of-app loyalty surface (3.9), pending a player population; the Party Board, pending more reference footage; merge-animation Tier B, pending the `BoardStateManager` Phase D refactor.

**Rows still unverified** (unchanged from 13 Aug; they need a dedicated read, not a guess): the album set-vs-completion reward ratio, card purchase by rarity, the days-per-building-level ramp, the price-ladder value curve, and whether top-tier tiles should show persistent "maxed" text.

**Not code:** the real ad SDK behind the wall, Push Notifications, iCloud and Game Center capabilities, and the App Store submission items — see `TODO.md`.
