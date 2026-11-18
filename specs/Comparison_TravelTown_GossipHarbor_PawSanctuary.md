# Three-way comparison — Travel Town, Gossip Harbor, PawSanctuary

**Status: findings only. No code was changed by this document and PawSanctuary was not run for it.** Everything about PawSanctuary comes from reading source and specs, as of `main` at `661e9e4`; nothing was playtested. **One finding has since been acted on:** the opening kibble was raised from 20 to 100 on 17 Nov 2026 (commit `4a739bd` on `tuning/starting-kibble-100`, all 885 tests passing, not yet merged). Where this document says `startingKibble = 20`, that is the state it was read in; §5-A has the outcome. It builds on the two bundle reviews (`TravelTown_Bundle_And_Live_Review.md`, `GossipHarbor_Bundle_And_Live_Review.md`) and does not repeat the feature-by-feature coverage already in `Feature_Parity_Audit.md`. The new axis here is **architecture and operating model**: where logic and content live, how events ship, how the first session and interruptions are handled.

**Does not reopen any recorded decision.** D1–D11 stand. In particular this does not revisit D2b (12-tier chains), D5 (event cadence and three event types), D10 (no chores) or D11 (no named characters or dialogue), even though both references do the opposite; §6 lists where each recorded decision meets a finding.

## 0. How to read the evidence tags

| Tag | Meaning |
|---|---|
| **[code]** | Read directly in PawSanctuary source (file and line cited) |
| **[spec]** | Stated in a PawSanctuary spec or the Alignment Plan, not re-verified in code |
| **[TT-bundle] / [GH-bundle]** | Read from the installed app's readable files |
| **[TT-live] / [GH-live]** | Seen in the live sessions (one profile each; see the bundle reviews for limits) |
| **[July]** | From your July Gossip Harbor FTUE analysis (v3.94.5), not re-measured |
| **[inferred]** | A conclusion drawn from names or structure, not directly observed |

Limits that apply throughout: both reference games' game logic is unreadable (encrypted executables; Gossip Harbor's Lua is packed), so "how the reference works" means "what its shipped assets, strings and behaviour show". Live observation covered a returning level-56 Travel Town save and about five minutes of a fresh Gossip Harbor profile.

## 1. Summary

Ranked by how much each is likely to matter, with the evidence behind each.

1. **PawSanctuary started the player with 20 kibble; Gossip Harbor starts at 100. Resolved 17 Nov 2026: raised to 100** (`4a739bd` on `tuning/starting-kibble-100`, not yet merged; see §5-A). As read: [code: `startingKibble = 20`, `AnimalSpecies.swift:1705`] [GH-live: 100] [July: 100]. The regen cap (100) and interval (120 s) match every reference measurement, but the opening balance does not. `Spec_SpawnerCooldown.md` says "at 20 starting kibble [the spawner cooldown] cannot realistically trigger in session one", which shows the number was weighed there, but no spec found records why 20 was chosen over 100, and the July finding that the genre leader's player never hit zero energy in 26 minutes bears on D1 and D7. This is the cheapest thing to check and the one most tied to a recorded decision. **Checked 17 Nov 2026 (static):** no rationale exists in history or specs; a player chasing row unlocks can reach zero inside session one; and D7's silence still holds, because the zero-kibble sheet hides every purchase rung until level 5. See §5-A.
2. **An item already on the board cannot fill an order in PawSanctuary; only a merge that produces it can.** [code: `updateOrdersAfterMerge`, with a doc comment at `MergeBoardViewModel.swift:734-745` calling this a deliberate difference]. In Gossip Harbor a held item fills an order: a Serve button appears once the item is on the board [GH-live]. This is decided in a code comment, not in the Alignment Plan's decision log, and it bears on D3's rationale ("the highest-converting purchase path... a player blocked on one specific item"). See §5-G.
3. **Every event, calendar and progress-track definition is compiled into the app.** About 3,000 of 30,000 lines (roughly 10%) are authored event content [code], and each 90-day calendar is its own spec, several tasks and an app release. Both references ship events as downloaded content [TT-bundle, GH-bundle]. This is the biggest operating-model difference, and it compounds with D5's "keep feeding the lattice" cost. See §5-B.
4. **No remote tuning, A/B capability or analytics SDK exists in the code** [code: no matches in source, and the project has no Swift package dependencies]. Travel Town ships two parallel energy configurations in one build [TT-bundle] and both references carry analytics, attribution and crash SDKs. The Alignment Plan §0 names "building without telemetry" as its one real risk; `PlaytestMetrics` is local only. See §5-C.
5. **No first-discovery collection or chain viewer exists.** The Blueprint specifies it (§18 and the collection list) and both references have one [July] [TT-bundle: item-collection assemblies and a "Collection Book" config]. No task in the Alignment Plan, TODO or Parity Audit tracks it. See §5-D.
6. **The first-launch tutorial is three steps; Travel Town ships about 60 context-triggered tutorials.** [code: `TutorialStep` rescue → merge → quest] [TT-bundle]. The first wall, a full board, bubbles and selling have no teaching moment in PawSanctuary. See §5-E.
7. **PawSanctuary already matches the references on most mechanics** (§4). The gaps are in operating model, not core loop.

## 2. Architecture and operating model

| Concern | Travel Town | Gossip Harbor | PawSanctuary |
|---|---|---|---|
| Platform | Unity 2022.3.62f2, IL2CPP | Unity 2022.3.62f2, IL2CPP | SwiftUI, native |
| Where rules and logic live | C# in about 255 assemblies [TT-bundle] | Packed Lua downloaded as content, plus one C# assembly [GH-bundle] | Swift, one app target, 63 files, about 30,000 lines [code] |
| Largest single file | not measurable | not measurable | `MergeBoardViewModel` 4,817 lines (about 16% of all code) [code] |
| Composition | One assembly per feature, Zenject DI, per-capability modules (sell, skip cooldown, unlock chest) [TT-bundle] | Monolithic C# plus Lua modules for core, activity, config [GH-bundle] | `@Observable @MainActor` coordinators (`BoardStateManager`, `KibbleEngine`, `ParallelBoardCoordinator`, `InventoryStore`, order coordinator) orchestrated by `MergeBoardViewModel`; extraction Phases A–D complete [code] [spec] |
| Economy and tuning data | ScriptableObject configs in downloadable bundles, two A/B energy variants [TT-bundle] | Lua config bundle (unreadable) [GH-bundle] | Swift constants at the bottom of `AnimalSpecies.swift` [code] |
| Events and calendar | Event features as assemblies, content in Addressables, embedded JS engine for scripted live-ops [TT-bundle] [inferred] | 34+ activity modules, 21,865 Addressables entries, Lua activity bundle [GH-bundle] | 55 `EventDefinition` entries in `EventSystem.swift`, 1,628 lines of `ProgressTrackRegistry`, plus parallel-board (9) and kibble-drive (10) registries; all compiled in [code] |
| Event cadence | Many concurrent, remotely stood up | Many concurrent [July: four at level 5] | D5: one 3–4 day event a week plus a 30-day pass; calendar authored through 2027-08-30 (Calendar 4 in progress) [code] [spec] |
| First-session teaching | About 60 tutorial graphs with trigger conditions (no energy, board full, bubbled items, order overshoot, etc.) [TT-bundle] | Cinematic, then story dialogue, then a guided merge chain with a hint hand [GH-live] [July] | Three-step overlay (rescue, merge, claim a quest), skippable, then a one-time theme sheet [code] |
| Interruptions on return | About 24 consecutive screens on an idle save, about five of them purchase offers [TT-live] | None seen on a fresh profile [GH-live]; none expected in session one [July] | Independent flags: login reward, milestone overlay, unlock banner, theme sheet, one `activeRoute` sheet, a parallel-board cover [code]; no central queue |
| Telemetry, remote config, A/B | Firebase (remote config, crash, messaging), AppsFlyer, ad SDKs, an A/B config asset [TT-bundle] | AppsFlyer, ad mediation, Facebook, profiling and recorder assemblies [GH-bundle] | None in code; local `PlaytestMetrics` panel only [code] |
| Localisation | 16 languages [TT-bundle] | 10 languages [GH-bundle] | None found: no string catalogues and no `NSLocalizedString` use [code] |
| Tests | n/a | n/a | 885 `func test` across `PawSanctuaryTests`; a persistence suite guards the migration chain [code] |

**What the contrast says.** Both references have moved their rules and event content out of the shipped binary. PawSanctuary has chosen the opposite end: strong native structure and a large test suite, at the price that content changes need a release. That is a defensible solo-developer choice (it is the reason 885 tests can pin the economy), but it makes the content cadence in D5 an engineering cost rather than a content cost.

## 3. Gameplay architecture, row by row

Verdict key: **Aligned** (matches what the references show), **Differs, decided** (a recorded decision or a code comment says why), **Differs, unrecorded** (no recorded reason found), **Not comparable** (no data).

| Area | References | PawSanctuary | Verdict |
|---|---|---|---|
| Board geometry | 7×9 in both [TT-live] [GH-live] | `boardRows = 9`, 7 columns [code] | Aligned |
| Opening occupancy | About a third playable, the rest sealed [GH-live] [July] | "Bottom 6 rows start locked" (21 of 63 open, 33%) [code] | Aligned |
| Locked rows hold visible energy caches | 20/10/30/50/100 caches under padlocks [GH-live] | Locked cells hold kibble caches, richer deeper (Task 4.2) [spec] | Aligned |
| Energy cap and regen | 100, 1 per 120 s, over-cap allowed via rewards [TT-bundle] [GH-live] [July] | `kibbleRegenCap = 100`, `kibbleRegenSecs = 120` [code] | Aligned |
| Opening energy balance | 100 [GH-live] [July] | `startingKibble = 20` as read; **100** on `tuning/starting-kibble-100` [code] | **Was: differs, unrecorded. Resolved 17 Nov 2026** (raised to 100; no rationale had been recorded for 20; D7's gate held either way). Aligned once that branch merges (§5-A) |
| Cost per generator tap | 1 [GH-live] | Spawn cost shown in the info bar; neutral multiplier `2^tier` [code] [spec] | Aligned in principle (D2) |
| Generator cooldown | "Recharging" countdown with an inline gem skip [July]; a skip-cooldown capability module [TT-bundle] | Per-producer cooldown (25–60 s); family spawners start a 30 s cooldown after a kibble threshold; skip for **2 Dog Tags, flat** via a confirmation dialog, gated on D7 [code] | Aligned in mechanism; **flat price** differs from Gossip Harbor's price scaled to the remaining wait [July] |
| Idle merge hint | A hand appears after a few seconds and points at a valid merge [GH-live] | `mergeHintIdleDelay = 4 s`, pulse every 1.0 s on one pair [code] | Aligned |
| Info bar | `Name (Lvl N)` plus hint text [GH-live]; `Name. Merge to reach next level.` [TT-live] | `Level N · Name Chain · Merge two to reach <next name>` for animals, tier names for items [code] | Aligned (names the next tier, which neither reference does) |
| Order fulfilment | Gossip Harbor: a **Serve** button appears once the requested item is on the board; tapping it consumes the item and pays [GH-live]. The code comment below says the references fulfil by dragging the item onto the order; Travel Town's mechanism was not observed here | Orders fulfil **only as a side effect of a merge producing the wanted item** (`updateOrdersAfterMerge`), auto-claim, then a 2 s claim animation and a replacement slot. An item already on the board does nothing for an order [code: `MergeBoardViewModel.swift:734-745`, `autoClaimOrder`] | **Differs, decided in a code comment only** (not in the decision log). See §5-G |
| Order payout structure | One reward on the first order, +2 then +32 coins [GH-live]; five-currency stacks per card [TT-live] | Reward list with riders, Smile Points, Care Points, reward flights [code] [spec] | Aligned (Spec_RewardFlight and Spec_OrdersAndTasks already cover) |
| Sell | Universal, tier-scaled; trash vs sell icon on the info bar [GH-live] [TT-live] | `animalSellValue(tier:)` and a sell-vs-order nudge [code] | Aligned |
| Chains | 14+ tiers [July]; 15-tier chain [TT-bundle] | 12 tiers (Phase 2b) [spec] | **Differs, decided** (D2b) |
| Chain viewer / discovery collection | One UI for both [July]; collection-book config and assemblies [TT-bundle] | None found [code] | **Differs, unrecorded** (§5-D) |
| Cards / album | 33-day album, energy-priced cards, rotating seasonal sets [July] [GH-bundle] | 54 cards, six sets, star shop, no whole-collection prize [spec: Parity Audit] | Differs; already tracked in the audit |
| Concurrent events | Many [TT-live] [GH-bundle] | Concurrent weekly event plus pass, parallel board, reward ladder, kibble drive [spec] | Aligned in structure; smaller by decision (D5) |
| Weekly goals / daily challenge | 5-task weekly track to a 100-point reward; 8-task daily [TT-live] | Daily hand-in baskets, quests, Smile and Care Points [spec] | Aligned in kind |
| Monetization silence in session one | Observed on Gossip Harbor [GH-live] [July] | D7 gate: `isMonetizationUnlocked` needs a first wall and level 5 [code] | Aligned |
| Time-limited timer UI | Per-card timers [TT-live] | `EventDefinition.timerLabel` (`Xd Yh left`) [code] | Aligned |

## 4. Where PawSanctuary is already aligned

Worth stating plainly, because the headline items below are about operating model and could read as a larger gap than the mechanics show:

- The energy rules, the board shape, the opening-occupancy ratio and the locked-cache idea match the references measurement for measurement.
- The idle hint matches Gossip Harbor's behaviour almost exactly.
- The info bar is richer than either reference's.
- The monetization-silence gate (D7) is implemented in code, not just specified.
- The live-ops primitives (scheduler, token wallet, progress track, reward table, timer, offer hook) are real implementations behind protocols, which is the part of the references' event machinery that is genuinely generic.
- The test suite pins the economy, the migration chain and several UI behaviours, which neither reference could be shown to match (their tests are not inspectable).

## 5. Items for decision

Not recommendations to change code. Each is a question the references raise, with what would settle it.

### A. Opening kibble: 20 versus 100

> **Resolved 17 Nov 2026 (owner decision): option 1, raise to 100.** Commit `4a739bd` on `tuning/starting-kibble-100` (cut from `main`; 885 of 885 tests pass; not yet merged). Three files: the constant in `AnimalSpecies.swift`, the session-one wording in `Spec_SpawnerCooldown.md`, and a dated decision note under D4 in `PawSanctuary_Alignment_Plan.md`. New installs only, no migration. The analysis below is kept as the record of why. Still unmeasured: a real fresh-install session to the first "out of kibble" sheet, which would show whether 100 is the right value or only a better one than 20.

- **Evidence:** `startingKibble = 20` [code]; Gossip Harbor 100 [GH-live] [July]; July found the leader's player never hit zero in 26 minutes across five levels and treats that as deliberate.
- **Why it matters:** D1 ("generous supply, designed depletion") and D7 ("no monetization in session one") assume a player reaches a first wall around day 2–3. At 20 kibble and a neutral spawn cost, a new player has roughly 20 spawner taps before the first regen wait. Other faucets (locked-row caches, quest and login rewards) may cover the gap, but no spec found says so.
- **Cheapest way to settle it:** `PlaytestMetrics` already exists, and `EconomySimulation` models kibble flow. A first-session simulation, or one real fresh-install run timed to the first empty kibble counter, answers whether session one hits zero.
- **Risk if left:** the first wall could land inside the first session, which would contradict D7's intent without any code breaking.

**Check result (17 Nov 2026, static: source and specs read, game not run).**

*What was established:*
- **No recorded rationale.** `startingKibble = 20` came in with the initial commit (`233fb80`) and has never changed. The only spec that states it, `Spec_SpawnerCooldown.md`, reports it ("a new game starts with 20") rather than justifying it. No test asserts it, by name or as a literal 20.
- **D4's own reasoning assumes 100.** The Alignment Plan says "100 kibble at ×1 is a few minutes of tapping" to support the 2–4 minute session target. A new install holds a fifth of that.
- **Cost per tap is 1 at the base tier**, and a tier-`t` item costs `2^t` (`spawnCost(forTier:)`). Orders pay Dog Tags, coins and XP, not kibble ("kibble is intentionally NOT a merge reward", `autoClaimOrder`), and levels 1–14 pay no kibble (`levelUpReward`). So orders and level-ups do not refill the bag in the opening.

*What the opening budget looks like* (assumptions marked; this is arithmetic, not observed play):

| Source | Amount | Basis |
|---|---|---|
| Starting balance | 20 | [code] |
| Day 1 login reward | 5 | `loginDailyRewards[0]`; a popup is shown on first launch, the grant itself was not traced |
| Tutorial quest claim | 2 | assumed an Easy quest (`QuestDifficulty.easy.kibbleReward`); not traced |
| Regen | 1 per 120 s | [code] |
| Row-3 caches (unlock needs a tier-2 animal, 4 units) | +7 | `lockedRowCacheTier`, value curve `2^(t+1)−1`, 7 cells |
| Row-4 caches (tier 4, 16 units in total) | +7 | same |
| Row-5 caches (tier 6, 64 units in total) | +21 | same |

About 27 units are in hand at the start, and rows 3 and 4 return about 14 of the 16 units they cost, so roughly 40 units of play are available before regen matters. Reaching row 5 costs 64 units in total. **A player who chases the next row unlock can therefore reach zero inside session one; a player who only fills the easy orders probably cannot.** Whether a real first session gets there depends on tap rate and which orders are chosen, which only a run can show.

The locked caches total 210 kibble across the six rows (7, 7, 21, 21, 49, 105), which matches the "roughly 210 energy" the July analysis counted on Gossip Harbor's opening board, so they look sized from it [inferred]. They are not a faucet for the opening, though: after row 4 each unlock costs far more than its caches return.

*What reaching zero does:*
- The first failed spawn calls `recordWallEvent`, which sets `hasReachedFirstWall` (`MergeBoardViewModel.swift:1708-1714`) and opens the "Need More Kibble?" sheet.
- Before level 5 that sheet shows "You're out of kibble," the count, and "Kibble refills on its own — check back in a bit!", plus the nearest unfinished order. The ad, Dog Tag exchange and bundle rungs are all hidden behind `isMonetizationUnlocked`, which needs both a first wall and level 5 (`MergeBoardView.swift:1291-1302`).
- **So D7's silence holds even if zero comes early.** No offer appears in session one either way. What changes is the feel: an early wall with nothing to do except wait two minutes per kibble, and Dog Tags earned from orders cannot be exchanged until level 5.

*Verdict:* D7 is safe. D1's "generous supply" and D4's session length are the decisions in question. The reference's July finding (never hit zero in 26 minutes) is about feel and retention, and D9 puts retention ahead of monetization.

*Options for the owner, none implied:*
1. **Raise the start to 100 (chosen 17 Nov 2026)** (matches Gossip Harbor and D4's own wording). One constant, new installs only, so no migration; existing saves are unaffected because kibble is persisted. No test depends on 20.
2. **Keep 20 and record why**, so the number stops being unexplained. Reasonable if a small start is meant to make the first regen tick visible.
3. **Pick a middle value**, for example 50, and check it in a run.
4. **Measure first.** One timed fresh-install run to the first "out of kibble" sheet gives the real number. The static budget above brackets it but cannot pin it.

### B. Compile-time events versus downloaded content
- **Evidence:** about 3,000 of 30,000 lines are authored event content [code]; four 90-day calendars have been specified, each with its own spec, task list, tests and release [spec]; both references load events as content [TT-bundle] [GH-bundle].
- **Why it matters:** D5's cadence is a commitment to keep the lattice fed. At the current model, changing a reward number or adding a weekend event means a release.
- **Options, from smallest to largest:**
  1. Leave it. The calendar is authored through 2027-08-30, which is a long runway, and the test suite benefits from compile-time content.
  2. Move **data only** (event dates, milestone thresholds, reward tables) into a remote JSON file the app reads, falling back to the built-in copy. This is the closest safe analogue to the references' content bundles without downloading code.
  3. Embed scripting as the references do. Not recommended without checking current App Store guidance on downloaded executable code first; both references do it, but that is evidence about them, not about what a new submission will be permitted.
- **Constraint to respect:** `CLAUDE.md` rule 5 ("ask before large refactors") applies. Option 2 touches persistence-adjacent code (event ids key saved state) and would need a migration review.

### C. No remote tuning, A/B or analytics
- **Evidence:** no matches in code for remote config, A/B, or any analytics or crash SDK [code]; Travel Town ships two energy configs in one build [TT-bundle]; the Alignment Plan §0 names missing telemetry as its one real risk, mitigated by shipping a deliberately small event catalogue.
- **Why it matters:** the mitigation depends on learning post-launch which events work. Local `PlaytestMetrics` helps a developer; it does not show how real players behave.
- **What would settle it:** a decision on what the launch telemetry story is. That is a product and privacy question (the app ships a privacy manifest) and is the owner's to make, not something to infer from the references.

### D. First-discovery collection and chain viewer
- **Evidence:** specified in `Merge2_Reference_Blueprint.md` (the chain viewer and discovery collection as one UI; a gem for every first creation) and listed in its build order; no task, spec or TODO item found for it [code] [spec]; Gossip Harbor's chain viewer is described in July; Travel Town ships collection-book config and an item-collection assembly [TT-bundle].
- **Why it matters:** the Blueprint argues it is a completion drive at near-zero economy cost, and it is the one planned feature both references have that PawSanctuary has neither built nor deferred on the record.
- **Ask:** is it intentionally out (record it, like D10 and D11), or untracked (add it to the plan)?

### E. Teaching beyond the first three steps
- **Evidence:** `TutorialStep` has three states [code]; Travel Town's tutorial configs are keyed on situations such as no energy left, board full, bubbled items present, an order that could be overshot, no mergeable items [TT-bundle].
- **Why it matters:** PawSanctuary introduces several mechanics (bubbles, sell vs order, the wall, Dog Tag spend, events) without a contextual teaching moment, which D7's silence in session one makes more important once the gate opens.
- **Settle it with:** the playtest metrics panel, or a fresh-install walk to the first empty counter and the first bubble.

### G. The order-fulfilment rule and the Dog Tag store
- **Evidence:** PawSanctuary fulfils an order only when a merge produces the wanted item; "an item already sitting on the board does nothing for an order asking for that same item" [code, comment at `MergeBoardViewModel.swift:734-745`]. Gossip Harbor lets a held item fill an order via a Serve button [GH-live]. Separately, D3 allows Dog Tags to buy board items and gives as its main reason that it is "the highest-converting purchase path... a player blocked on one specific item" [spec: Alignment Plan D3], and the Parity Audit lists the contextual "SEE IN STORE" button as only partly matched.
- **The question, not a conclusion:** if a player buys the exact item an order wants, does it serve that order? Under the rule in the code comment it would not directly; it would have to be merged up or combined first. That may be intended (it keeps board-space pressure and the merge as the mechanic, which is how the daily hand-in tasks are described), but D3's reasoning reads as if purchase-to-serve works the way it does in the references.
- **Settle it with:** a single check of the purchase path against an open order, then either record the rule as a decision (so the comment is not the only home for it) or note the effect on D3's conversion argument. No code change implied.

### H. Minor differences worth a line, not a decision
- **Skip price:** a flat 2 Dog Tags [code] versus a price scaled to the remaining wait on Gossip Harbor [July]. Easy to adopt if wanted; not necessarily better.
- **Interruption handling:** PawSanctuary has six independent presenters and one `activeRoute` sheet, sequenced by ad hoc conditions (for example, the theme sheet waits for the tutorial, the login reward and any route to clear) [code]. Travel Town's roughly 24 consecutive screens on return show what that approach becomes without a central queue. Nothing is wrong today; it is the next place complexity will gather as events grow.
- **Localisation:** none found in code. Both references ship multiple languages. Whether it is in launch scope is an owner call; it is not part of the Alignment Plan as read.

## 6. How the findings meet recorded decisions

| Decision | Finding | Effect |
|---|---|---|
| D1 (generous supply, designed depletion) | §5-A, opening balance | Checked, and the opening balance raised from 20 to 100 (17 Nov 2026). The decision itself is unchanged |
| D2b (12 tiers) | References run 14–15 tiers | No change. Decided, with reasons recorded |
| D3 (Dog Tags buy board items) | §5-G, held items do not fill orders | Check the purchase path; no change to the decision itself |
| D5 (cadence, three event types) | §5-B operating cost; references run 34 activity folders and about 12 event assemblies | No change to scope; the cost of cadence is the thing to watch |
| D7 (silence in session one) | Gossip Harbor showed no prompts; Travel Town stacked about five offers among 24 screens on a returning save | Confirms D7's direction |
| D9 (retention outranks monetization) | Travel Town's offer density on return | Consistent with D9: PawSanctuary's lower density is a position, not an omission |
| D10 (no chores) | Gossip Harbor's chores confirmed in strings; `task_#` is its largest string group | No change. D10's reasoning (coins committed to the map, XP load-bearing) is independent of the reference |
| D11 (no named characters) | Gossip Harbor is story-led (cinematic, about 600 story entries, per-area character prefabs); Travel Town has 17 order characters | No change. D11's revisit trigger is retention data |

## 7. What was not compared

- **Economy numbers.** Gossip Harbor's are in unreadable Lua; Travel Town's were readable only for energy. No payout, price or curve was compared.
- **Run-time behaviour of PawSanctuary.** Not launched. Frame pacing, memory and the suspected shimmer OOM noted in `Spec_BoardAnimation_Draft.md` were not examined.
- **Mid-game systems of Gossip Harbor** beyond the first two orders; its level-5 live-ops layer is only as measured in July on a version eight releases older.
- **Monetization pricing and offers**, beyond what each live session showed.
- **Art, audio and haptics.** Travel Town ships Lofelt haptics; PawSanctuary has `HapticManager`. Not compared.

## 8. Suggested order of work

1. **§5-A, opening kibble: done 17 Nov 2026** (raised to 100, `4a739bd`, awaiting merge). What remains is optional: one timed fresh-install run to the first "out of kibble" sheet, to confirm 100 is right and to feed step 5.
2. **§5-G, order-fulfilment rule against D3.** One read of the Dog Tag purchase path against an open order, then record the rule in the decision log or note its effect on D3. No code change implied.
3. **§5-D, discovery collection.** One decision: record it as out, or add it to the plan. No code until decided.
4. **§5-C and §5-B together**, as one conversation about launch telemetry and content delivery, since remote tuning and remote content share the same plumbing and the same App Store and privacy questions.
5. **§5-E**, informed by whatever step 1's optional run shows about where a first-time player gets stuck.
