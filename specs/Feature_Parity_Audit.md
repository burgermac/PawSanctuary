# Feature-Parity Audit — PawSanctuary vs. Gossip Harbor / Travel Town / Tasty Travels

**Read from source 13 August 2026.** Requested in `TODO.md` under "Competitive analysis": the Gap Analysis docs (`PawSanctuary_Gap_Analysis.md`, `Gap_Analysis_Round2.md`) deliberately scoped themselves to *gameplay psychology* — the mechanisms driving return visits and spend — and explicitly did not enumerate feature-by-feature coverage. This is that enumeration.

**Sources:** `Merge2_Reference_Blueprint.md`, `Reference_Data_Extract.md`, `Findings_26July.md`, `Phase2_Economy_Model.md` (companion to `Phase2_Economy_Model.xlsx`), cross-checked against the current PawSanctuary source (`PawSanctuary/*.swift`).

**Legend:** ✅ present and functionally equivalent · 🟡 present but structurally thinner than the reference · 🚧 infrastructure exists, not player-facing · ❌ absent

---

## 1. Board & merge core

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Board geometry | 7×9 = 63 tiles, single screen | ✅ | Matches exactly — arrived at independently per the blueprint. |
| Chain depth | 8–13 tiers observed, up to 12+ | ✅ | 12 tiers (`animalChainTopTier = 11`), cut down from an original 15 (`ItemChain.swift`). |
| Tier number surfaced in UI (`Lv.9`) | Yes, called out as important — "converts an opaque exponential into a legible ladder" | ❌ | `CellView.swift` shows only the tier's name (`shortLabel`, e.g. "Groomed"), never a numeric badge. Unexamined gap, not a decision — cheap to add. |
| Terminal-tier messaging | `"Max level reached for this item."` | 🟡 | Top-tier items get a celebration banner (`triggerTopTierCelebration`) but board tiles don't show persistent "maxed" state text the way the reference does. |
| Sell any item, tier-scaled | Listed as a universal pressure valve | ✅ | `sellSelectedAnimal`, `sellValue(forTier:)`. |
| Splitter / reverse-a-merge | Store item, 50 gems, "reverses a merge one tier" | 🟡 | Exists as `applySplitterPiece` (Felines "Nine Lives" superpower), not a purchasable store item — same effect, different access path (earned/rolled vs. bought on demand). |
| Chores (soft-currency tasks paying XP) | Listed as "a second use for coins, parallel to orders" | ❌ | No equivalent system. |
| Cosmetic choice (no-cost color/theme) | "An ownership device, not a sink" | ❌ | No cosmetic customization anywhere in the codebase. |

## 2. Energy / generators

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Regen rate | 2:00/unit (Travel Town, stated in-game) | 🟡 | Kibble regens 1/min — twice the reference rate, i.e. a more generous curve. Deliberate per the locked "mirror the segment leader, then be generous early" posture, not a gap. |
| Energy cap growth | ~100 at L46, ~1,435 at L100 — barely scales | 🟡 | Kibble cap is flat at 100 (150 at level 10+) — doesn't scale by level band at all. Simpler than the reference, arguably fine given kibble's much faster regen; not independently verified against PawSanctuary's own wall curve. |
| Power Boost / spawn multiplier | ×1/2/4/8/16, exactly energy-neutral by construction, dominant strategy | ✅ | `spawnMultiplier` (1/2/4/8), confirmed energy-neutral by `EconomyTests.testEveryMultiplierIsEnergyNeutral`. Matches the reference finding almost exactly, independently arrived at. |
| Bonus rolls gated to boosted taps | 0 events at ×1 vs. 12–15 at ×4 in a controlled sample | ✅ | `legendaryBonusShare` bonus layer on boosted spawns (Gap_Analysis_Round2 C-2, closed). |
| Currency-as-merge-chain on the board | "The single largest structural miss" in the original blueprint — coins/energy spawn and merge like any item | ✅ | `currency.kibble` / `currency.coin` chains spawn and merge on the board (Phase 4, Task 4.1) — this was explicitly adopted, not missed. |
| Generator cooldown class system | An order of magnitude spread: 2m44s to 30m, deliberately two classes (fast common / slow "return visit" premium) | ❌ | All PawSanctuary producer cooldowns cluster in 25–60 **seconds** (`ProducerLevel.cooldown`, `AnimalSpecies.swift:337`) — no long-cooldown class exists at all. The reference's "30-min generator as the return-visit mechanic" has no PawSanctuary equivalent; the Free Chest timer (3.6, 4h) is the closest analog but isn't a board generator. Worth a decision, not obviously a gap — depends on whether the multi-hour Free Chest already fills that role. |
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
| Live-ops primitives (milestone track, parallel board, competitive, timed order, reward table) | 8 primitives cataloged, all observed in the wild | 🚧 | All 8 have infrastructure (`LiveOpsPrimitives.swift`, `LiveOpsEngine.swift`) — `TokenWallet`, `ProgressTrack`, `EventScheduler` — but most are unused by any shipped content. |
| Concurrent events | 6+ simultaneous timers observed, ranging 4 minutes to 29 days, layered | ❌ | PawSanctuary's model is explicitly single-active-event (`"the current single-active-event model"`, `MergeBoardViewModel.swift` comment). Only one event has ever been authored (`rescue_rush_jun2026`), and it's expired — nothing seasonal is currently live (`TODO.md`). This is the single largest structural gap in the audit: the reference's "permanent lattice of overlapping deadlines" has no PawSanctuary counterpart at all right now. |
| Parallel board (a complete second mini-game, e.g. "Petal Talk") | Own board, generators, chain, currency, progress track, 36h duration | 🚧 | `ParallelBoardStub` satisfies the protocol with **no real board grid, no chains, no energy regen** — explicitly deferred in its own doc comment ("its own spec, deferred to 6b"). |
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
| Named characters / scripted dialogue | Tasty Travels only, not Travel Town — a "light narrative spine" | ❌ | No character/dialogue system. Matches the *Travel Town* (leaner) reference more than Tasty Travels; the doc that made this call already noted Tasty Travels grew faster despite the added narrative, and left it as "worth revisiting if retention data says the lean version feels thin" — not yet revisited. |
| Out-of-app loyalty surface | Web PWA, own auth, level 35+ | ❌ | 3.9 in `Gap_Analysis_Round2.md` — deliberately deferred 2026-08-13; this is separate infrastructure (own backend/hosting), not an in-app feature. |

## 8. Daily / weekly / monthly retention

| Feature | Reference (measured) | PawSanctuary | Note |
|---|---|---|---|
| Weekly goal ladder | 5 point-weighted tasks, 170/420 pts for the reward | 🟡 | Bronze/Silver/Gold coin-threshold tiers (`weeklyGoalBronzeCoins` etc.) — a simpler 3-tier ladder against one metric (coins earned), not 5 independently-weighted task types. |
| Daily rewards | 7-day cycle + slower "Total Days" milestone track underneath it | 🟡 | 7-day Loyalty Club cycle exists (`loyaltyClubCycle`); no second, slower long-run streak track alongside it. |
| Daily challenges | Near-miss stagger (next challenge 60–90% done when current finishes) | ✅ | 3.1, closed this session — explicitly calibrated to this exact mechanic. |
| "Spend N currency" quest (a spend quota disguised as a quest) | Observed in Tasty Tasks — explicitly flagged as the most aggressive daily-system item | ❌ | No `QuestGoal` case spends currency as an objective (`mergeAny`, `mergeInChain`, `reachTier`, `spawnBase` only). Absence matches the deliberately-conservative monetization posture chosen for 3.7 this session — consistent, not an oversight. |
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
| First-purchase offer | Highest-leverage single offer in the game, visible only pre-first-purchase | ❌ | No dedicated first-purchase offer construct found (`starterBundle` IAP exists but isn't gated to pre-first-purchase state specifically). |
| Store item stock limits ("2 left") | Scarcity pressure on shop slots | ✅ | `DogTagStoreSlot`, stock 1 each, daily rotation. |
| Piggy bank | Passive accumulator, paid to crack | ✅ | 3.4, closed this session. |
| Timed free chests | Free with a wait, soft speed-up sink | ✅ | 3.6, closed this session. |
| Wildcard | Merges with anything | ✅ | 3.5, closed this session. |
| Bubble mechanic | Item locked, wait or pay to unlock, decays rather than destroyed | ✅ | `BubbleMechanicTests.swift`, `bubbleChance`/`bubbleMinTier`/decay (Gap_Analysis_Round2 C-4, closed — "the retune is better than my spec" per that doc). |

---

## What this changes about the backlog

Cross-referencing against `Gap_Analysis_Round2.md`, most gaps found here were **already known and already decided** — this audit mostly confirms rather than discovers:

- Competitive events (§5) and the out-of-app loyalty surface (§7) are 3.8/3.9, both deliberately deferred today.
- The spend-quota quest and first-purchase offer (§8, §9) are consistent absences with the conservative monetization posture chosen for 3.7 — not oversights.

**Two items are genuinely new findings from this pass, worth a decision:**

1. **Tier numbers aren't shown in the UI** (§1). Cheap, low-risk, directly recommended by the reference research as something they omitted and should have added. A real candidate for a future small session.
2. **Generator cooldowns cluster at 25–60 seconds with no long-cooldown class** (§2). The reference's "30-minute generator as the return-visit mechanic" has no equivalent — unless the Free Chest (3.6) is judged to already fill that role, in which case this is resolved, not open. Worth a short conversation, not a unilateral build.

**Everything else marked 🚧 or 🟡 is either genuinely unverified from this pass** (album set-vs-completion reward ratio, card purchase-by-rarity gating, days-per-building-level ramp) — would need a dedicated read to confirm, not urgent — **or a defensible scale/maturity difference** (album size, forever-goal total) that doesn't call for action.

No absence found here reads as an accidental miss serious enough to warrant reopening on its own; the two flagged above are offered as options, not recommendations to build unprompted.
