# Spec — Context-triggered tutorial (revision task 4.2)

**Status: Draft, 22 Nov 2026, written cold, not reviewed, no code.** Task 4.2 of `Revision_Plan_ModelOnReferences.md` (W4, triage row 7). Task 4.3 (the build) stays blocked until the owner answers §9. All code citations are to `origin/main` at `a03ef58` (schema v46). Line numbers drift; search by name if one no longer lands.

**Read first:** `PawSanctuary_Alignment_Plan.md` D7, D9, D11, D14; `Triage_ModelOnReferences.md` row 7; `Spec_HeldItemOrders.md` §1 and §4 (the order rule this tutorial must teach).

Evidence tags: **[code]** read from the source here; **[measured]** seen on screen in a reference game and written down in the named document; **[names only]** an asset or config name read from a reference's app bundle, contents not read; **[inferred]** follows from evidence but was not seen.

---

## 0. What the player would experience, in one paragraph

Today a new player gets three dark-screen pop-ups (tap the spawner, merge, open quests) and is then on their own. After this change the screen stays clear. A small speech bubble with a pointing hand appears beside the thing that matters at the moment it matters: the spawner on first launch, a matching pair when one exists, an order card when it first has an animal "on hold", the green Deliver button the first time it appears, the basket when the board first fills, the spawner when it first needs a rest, and so on. Each bubble shows once, goes away when the player does the thing (or taps it away), never stops them playing, and never points at a shop, an offer, an ad or a Dog Tag spend before the game's monetization gate opens. A player who already knows the game is not re-taught: each bubble is skipped if the save shows the player has already done what it teaches.

---

## 1. Scope

In scope: a set of one-time, context-triggered teaching moments ("moments") with one shared presentation, a way to store which have been seen, and the replacement of the current three-step overlay by the first few moments.

Out of scope: see §8.

---

## 2. What PawSanctuary teaches today [code]

### 2.1 The three-step overlay

| Piece | Where | What it does |
|---|---|---|
| Step enum | `OnboardingView.swift:15-22` | `TutorialStep` = `rescue`, `merge`, `quest`, `done` (Int raw values, never persisted as such) |
| Overlay | `OnboardingView.swift:28-90` | Black scrim at 55% opacity that lets taps through (`:51-53`, `allowsHitTesting(false)`), a pulsing yellow ring on the target (`:56-62`), a speech bubble (`:95-143`), and a "Skip tutorial" button top right (`:68-82`) |
| Targets | `OnboardingView.swift:38-44` | Rescue and merge both point at the **centre of the whole board**; quest points at the **centre of the whole tray band** (tray + order lane, measured at `MergeBoardView.swift:701-703`; board frame at `:735-737`) |
| Initial state | `MergeBoardView.swift:75-77` | `.done` if `UserDefaults` `"tutorialCompleted"` is true, else `.rescue` |
| Rescue → merge | `MergeBoardView.swift:100-104` | `onChange(of: viewModel.rescueCount)`: any rise above 0 advances |
| Merge → quest | `MergeBoardView.swift:105-109` | `onChange(of: viewModel.mergeCount)`: any rise above 0 advances |
| Quest → done | `MergeBoardView.swift:110-114` | Opening the quests sheet (`activeRoute == .task(.quests)`) completes it. **Claiming is not required**, despite the title |
| Resume sync | `MergeBoardView.swift:383-392` | On appear, if not completed, jumps to `.quest` when `mergeCount > 0`, else `.merge` when `rescueCount > 0` |
| Completion | `MergeBoardView.swift:446-449` | `completeTutorial()` sets `.done` and writes `"tutorialCompleted" = true` to `UserDefaults`. Skip calls the same function |
| Hidden while | `MergeBoardView.swift:303` | the Good Morning login popup is showing |
| Theme sheet | `MergeBoardView.swift:42-45`, `:328-346` | The one-time "Make it yours" board-theme sheet waits for `tutorialStep == .done` and no other popup; it then sets the persisted `boardThemePrompted` (`GameStore.swift:133`, `MergeBoardViewModel.swift:4130`) |

Step texts (`OnboardingView.swift:174-206`):

| Step | Title (`:176-178`) | Body (`:186-190`) | Hint line (`:198-203`) |
|---|---|---|---|
| rescue | Rescue Your First Animal | "Tap the house icon (spawner tile) on the board to rescue your first animal. It costs 1 Kibble." | "Kibble regenerates 1 every 2 min · max 100" |
| merge | Perform Your First Merge | "Tap an animal to select it, then tap a matching one to merge them into a higher stage!" | "Merges are free · tap the spawner again for more animals" |
| quest | Claim Your Quest Reward | "Your rescue and merge counted toward a quest. Tap 'Quests' in the strip above the board to open it and claim your reward." | "Adoption orders pay the most Coins · selling an animal is quicker but pays less" |

**Pending fix, open PR #127** (`fix/tutorial-merge-is-drag`): changes the merge body to "Drag an animal onto a matching one to merge them into a higher stage!". Tapping only selects (`MergeBoardViewModel.swift:2055-2057`, "Tapping never moves, swaps, or merges"). The hint line under it was already fixed by PR #117 (it used to claim an auto-spawn after each merge). This spec assumes #127 merges; its wording is reused in §4, moment M2.

### 2.2 Every other first-time hint or teaching surface

| Surface | Trigger | Text / behaviour | Stored | Citation |
|---|---|---|---|---|
| Sell-vs-order nudge | First selection of an animal at tier 3–8 (`sellVsOrderNudgeTierRange`, `AnimalSpecies.swift:2243`) that no open order wants | Toast: "No order wants this yet — sell for +N, or hold out for an order (+M)" | `UserDefaults` `"hasShownSellVsOrderNudge"` | `MergeBoardViewModel.swift:2063`, `:2069-2092` |
| Idle merge hint | 4 s with no board touch (`mergeHintIdleDelay`), a mergeable pair exists | The pair nudges toward each other once a second until the next touch. No hand, no text | Not stored (repeats every idle period) | `MergeBoardViewModel.swift:1250`, `:1261-1281`, pair search `:1293` |
| Board full toast | A spawn tap with no free cell | "Board is Full — merge a matching pair to make room" or "…sell an animal to make room", picked by whether a merge exists | Not stored (every time) | `MergeBoardViewModel.swift:51-55`, `:2863-2869`, call sites `:1803`, `:1881`, `:1908` |
| Inventory full toast | Storing with storage full | "Inventory Full — merge a matching pair on the board to make room" / "…sell an animal…" | Not stored | `MergeBoardViewModel.swift:56-59` |
| Out of kibble sheet | A spawn tap that cannot be paid; also records the first wall | "You're out of kibble"; before D7 opens, only "Kibble refills on its own — check back in a bit!" plus the nearest open order | Not stored | `MergeBoardViewModel.swift:1797-1800`, `:1769-1775`; sheet `MergeBoardView.swift:1293-1330`, footer `:1443-1460` |
| Info bar | Any selection | One or two lines naming the item and what to do ("Tap to rescue … costs N kibble"; "Drag off-board to move to storage" while dragging), with an "i" button that opens the chain viewer for chain items | Not stored | `MergeBoardViewModel.swift:703-735`; "i" button `MergeBoardView.swift:1091-1108` |
| Row-unlock bar | Rows still locked | "Merge an animal to Level N to unlock the next row (k levels away)" under the board | Not stored | `MergeBoardViewModel.swift:945-953`; `MergeBoardView.swift:739-742` |
| "New Row Unlocked!" banner | A row unlocks (deepest tier reaches `boardRowUnlockTiers`) | "7 more spaces are now open for rescued animals!" | Not stored | `MergeBoardViewModel.swift:2534-2547`; `MergeBoardView.swift:154-163`; tiers `AnimalSpecies.swift:1925` |
| "Almost there!" | An order basket of 2+ items is one item short on the board | Family-coloured caption on the lane card; "Almost there! k/n on the board" in the orders sheet | Not stored | `OrderLaneView.swift:306-315`; `PanelViews.swift:457`; rule `AnimalSpecies.swift:1204-1207` |
| Order card states (D14) | Live board census | Slots muted when held, vivid when every slot is held; green **Deliver** pill on the card's top edge only when ready; "Ready to deliver!" caption | Derived, not stored | `OrderLaneView.swift:216-361`, button `:140-176`; rule `AnimalSpecies.swift:1155-1201`; board tiles `MergeBoardViewModel.swift:817-842`; delivery `:3771-3796`, `:3818-` |
| Spawner rest ("Skip the wait?") | Tap on a resting family spawner | **Before D7 opens: nothing at all** (the tap just selects). After: an alert offering a 2 Dog Tag skip | Not stored | `MergeBoardViewModel.swift:1783-1787`, `:4273-4276`; alert `MergeBoardView.swift:355-370` |
| Banners and celebrations | Level up, area built, superpower unlock, Ambassador, milestones, login reward | Celebrations, not teaching | Various | `MergeBoardView.swift:142`, `:175`, `:196`, `:221`, `:293` |
| Theme sheet | After the tutorial, once | Pick a board theme | `boardThemePrompted` in the save | see §2.1 |

**Pattern today:** two one-time hints (tutorial, sell nudge), both stored in `UserDefaults`, not in the save. Everything else is shown every time or derived live.

---

## 3. What the references do

### 3.1 Gossip Harbor

Sources: `FTUE_Analysis_GossipHarbor.md` (July 2026, v3.94.5, six recordings, ~26 min from install; kept outside this repo at `~/Documents/Claude/Claude Code/`), and `GossipHarbor_Bundle_And_Live_Review.md` §4 (fresh profile on v4.12.0, ~5 min of actual play).

Opening, as timed in July [measured, FTUE §2]:

| Time | Event |
|---|---|
| 0:50 | Cinematic, no gameplay |
| 1:10 | Story dialogue |
| 1:45 | First board, with a line of dialogue about tidying up |
| 1:50 | First guided tap, then first merge |
| 2:10 | First order served |
| ~5:00 | Meta screen, renovation choice |
| ~7:00 | Level 2 |
| ~9:00 | New character, first chore |

Systems are introduced **one at a time, about twelve in twenty minutes**: merge, orders, generators, meta, coin chain, gems, chores, sell, chests, store, more order slots, day rollover [measured, FTUE §5; the minute marks are approximate in the source].

What the first minutes teach, on v4.12.0 [measured, Bundle review §4.1, §4.2, §4.6]:
- A tutorial **arrow** points at the Kitchen button on the meta map.
- The first board prompt: "Uncover a buried item by merging it."
- The **info bar** teaches by itself: "MERGE to reach its next level", plus "TAP to produce new items" for a generator, and "TAP an item to read its details here" with nothing selected.
- The first tap on a generator **selects** it; later taps produce.
- An **idle hint**: after a few seconds a pointing hand alternates between a pair that can merge.
- **Serving the first order:** a green Serve button appears when the item is on the board, with a guided hand and a line of dialogue ("We finished baking the bread! Let's Serve it to Olivia.").
- "Board Full" fired during the tutorial [measured, FTUE §4]; no toast was captured on v4.12.0 [measured: not seen].
- **No purchase offer, ad or store push in the first session** [measured in both captures; this is the basis of D7]. The shop icon is visible from about minute three and never pointed at [measured, FTUE §1].

Not known: whether Gossip Harbor's guided steps block other input. The capture says "guided tap" and "guided hand"; whether a tap elsewhere was refused was not tested [inferred: probably forced for the first merge, not shown either way]. The tutorial list itself is not readable (Lua and `novicetask` bundles) [names only, Bundle review §3 table].

### 3.2 Travel Town

Source: `TravelTown_Bundle_And_Live_Review.md` §2 ("Tutorials (names only)") and §3.4.

- **About 60 tutorial graphs** ship [names only]. A numbered onboarding series `BotG_00` to `BotG_17`, named for: merging and producer, board queue, merge producers, second producer, store unlocked, item communication, joker, energy crate, secondary producer, bubbled item, tool, coin collect [names only; the list in the review has twelve names for eighteen numbers, so some numbers were not listed].
- Feature tutorials named for: power boost, cards, pets, town fair, puzzle paints, flame cards, vanity, inventory, sell, stacking, no-energy, prevent order requirement overshoot [names only].
- The tutorial config's **trigger vocabulary** includes `NoEnergyLeft`, `BoardIsFull`, `HasBubbledItemsOnBoard`, `CanOvershootOrderRequirement`, `OrderCountCompleted`, `HasNoMergableItemsOnBoard` [names only]. That is the strongest evidence that Travel Town's tutorials fire on game situations rather than in a fixed sequence. **What each graph says or points at was not read** [not measured].
- One Travel Town tutorial was seen live: on the Travel Pass, a **forced** tutorial pointed at the VIP "Activate" (paid) button, with a Skip button only after pressing Escape [measured, §3.4]. That was a returning, high-level profile, not a first session.
- Travel Town's first session was not captured, so its step order, wording and timing are unknown [not measured].

### 3.3 What the two agree on, and where they differ

Agree [measured in Gossip Harbor, names only in Travel Town]: teach one thing at a time, at the moment it applies; a pointing hand or arrow at the target; teach order delivery with the delivery button itself.

Differ: Gossip Harbor teaches inside a story with characters; Travel Town shows no dialogue in the material seen. Story is out of scope here (§8, row 8). Travel Town pointed a tutorial at a paid button; Gossip Harbor never pointed at the shop in session one. D7 and D9 settle that one for PawSanctuary (§5).

---

## 4. The moments to add

### 4.1 One presentation for every moment

A **coach mark**: a small speech bubble (reuse the current bubble's look, `OnboardingView.swift:116-143`) with a pointing hand or pulsing ring on the target, and **no full-screen scrim**.

- **Non-blocking.** The bubble and the hand ignore touches (`allowsHitTesting(false)`), except a small "×" on the bubble. The player can play straight through it. This fixes what the 17 Nov fresh-install run hit, where the current bubble hid part of the board and the tutorial had to be skipped (`Comparison_TravelTown_GossipHarbor_PawSanctuary.md` §5-A, "Live check").
- **Points at the real target,** not a region centre: a board cell, a card, a button. Targets report their frames the way `reportOrderCardFrame` and `reportHUDFrame` already do.
- **One at a time.** At most one moment visible. Others wait in a queue.
- **Never over anything else:** not while the login popup, any sheet (`activeRoute != nil`), the parallel board, a banner, or the milestone takeover is up. It waits, as the theme sheet does today (`MergeBoardView.swift:42-45`).
- **Spacing:** after a moment closes, the next non-urgent one waits at least a short gap. The gap is a tuning constant at the bottom of `AnimalSpecies.swift` (suggested start 20 s; this number is not from a reference and is there to be tuned).
- **Each moment shows once** and is marked seen when it is (a) completed by the action it teaches, (b) dismissed with "×", or (c) found already done from the save (§6.3). A moment whose trigger stops being true before it shows (for example the order card was delivered by another route) is dropped from the queue without being marked, so it can fire next time.
- **Skip all:** a "Skip tips" button inside the first bubble of the session marks every core moment (group A) seen. Owner question Q1.

### 4.2 The list

Every trigger below exists in the code today. "Ref" names the reference behaviour it is modelled on. All are non-blocking. "Done when" is what marks the moment seen besides "×".

**Group A — session one, the core loop** (replaces the three-step overlay)

| Id | Trigger [code] | Message (working text) | Points at | Done when | Ref |
|---|---|---|---|---|---|
| M1 first spawn | New game, a family spawner on the board, `rescueCount` not yet raised by a player tap (see §10 item 3 for why `rescueCount` alone cannot be used) | "Tap the spawner to rescue an animal. Each rescue costs kibble; kibble refills by itself." | The spawner cell (`activateProducer`, `MergeBoardViewModel.swift:1777`) | The player's first successful spawn tap (`finishSpawn`, `:1687`) | GH: "TAP to produce new items" info line and guided first tap [measured]; TT `BotG` "merging and producer" [names only] |
| M2 first merge | A mergeable pair exists (`findMergeableHintPair() != nil`, `:1293`) and no merge done yet | "Drag an animal onto a matching one to merge it into the next level." (PR #127's wording) | A hand that slides from the first to the second cell of that pair | First successful merge (`mergeCount` rises, `:2422`) | GH guided first merge and idle hand [measured]; TT "merging and producer" [names only] |
| M3 order on hold | An open order (persistent or urgent) first has at least one held slot but is not ready (`heldState(census:)`, `AnimalSpecies.swift:1155`) | "This family wants that animal. A soft highlight means you already have it on the board. Keep it there!" | The held slot on the card, and the matching board tile (the muted highlight, `heldItemHighlights`, `MergeBoardViewModel.swift:825`) | Seen for 6 s, or "×", or the card becomes ready (then M4 fires) | TT green slot and green board tile [measured, Triage §2.9, §2.10]; D14 muted highlight |
| M4 first Deliver | An order first becomes ready, so the Deliver pill appears (`OrderLaneView.swift:229-232`, `:352-358`) | "Everything is on the board. Tap Deliver to send the animals home and collect your reward." | The Deliver pill | The first successful delivery (`deliverOrder`, `:3771`, or `deliverUrgentOrder`, `:3818`) | GH Serve with guided hand and line [measured]; TT GO button [measured] |
| M5 after Deliver | The first delivery succeeds | "Delivered animals leave the board. A new family arrives in a moment." | The card that just delivered | Shown 4 s, auto-closes | GH "next order immediately" [measured, §4.6]; D14 (items leave the board) |
| M6 first quest claim | A standing quest first becomes claimable (its lane card shows Claim, `QuestLaneView.swift:90-91`) | "Quest complete! Tap Claim for your reward. Quests count what you do; orders and daily tasks want animals you hold." | The quest's Claim button in the lane, or the quests tile (`TaskTrayView.swift:675-686`) if the card is off screen | `claimQuest` succeeds (`MergeBoardViewModel.swift:3476`) | Replaces today's quest step; GH introduces orders before other systems [measured, FTUE §5] |
| M7 split warning (overshoot) | A merge consumes an item that was holding an order slot, and the slot goes back to missing (compare held state before and after `attemptMergeOrMove`, `:2248`) | "That animal was on hold for an order. Merging it moved it up a level, so the order needs another one." | The order slot that dropped | Shown once | TT `CanOvershootOrderRequirement` and "prevent order requirement overshoot" [names only] |

Group A in session one is at most seven bubbles, and only M1, M2 and M4 are certain to fire for every player. M3, M5 and M7 are short. Owner question Q3 asks whether all seven stay in session one.

**Group B — the first friction moments**

| Id | Trigger [code] | Message | Points at | Done when | Ref |
|---|---|---|---|---|---|
| M8 board full | First "Board is Full" toast (`triggerToast(.boardFull)`, `:2863-2868`) | "No room left. Merge a pair, drag an animal to the basket to store it, or sell one from the info bar." | The basket button (`MergeBoardView.swift:1036-1080`) | A merge, a store, or a sell after it, or "×" | TT `BoardIsFull` and "inventory" [names only]; GH Board Full in the tutorial [measured, FTUE §4] |
| M9 first item stored | First `sendBoardItemToInventory` (`:2488`) or `storeSelectedItemToInventory` (`:2502`) | "Stored animals are safe in the basket, but orders and daily tasks only count animals on the board." | The basket | Shown 5 s | TT "inventory" [names only]. The rule is PawSanctuary's own: `boardTaskCensus` excludes storage (`:740-753`) |
| M10 spawner resting | First tap on a resting family spawner while the D7 gate is closed (the branch at `:1783-1787` where `requestSpawnerSkip` returns without showing anything, `:4273-4276`) | "This spawner is resting. It will be ready again in a few seconds." | The spawner | Shown once | GH "Recharging" generator [measured, FTUE §6c]. **No skip mention before D7** (§5) |
| M11 out of kibble | First time the out-of-kibble sheet opens (`triggerToast(.noKibble)`, `:2867`) | A line added inside the sheet: "Kibble refills on its own. Meanwhile, merge what you have or deliver an order." | The nearest-order footer in the sheet (`MergeBoardView.swift:1318-1320`) | The sheet closes | TT `NoEnergyLeft`, "no-energy" [names only]. GH never ran out in 26 min [measured], so there is no GH model for the words |
| M12 no merges left | `findMergeableHintPair() == nil` for the first time while the spawner is ready and the player has kibble | "No matching pairs right now. Tap the spawner for more animals." | The spawner | A spawn | TT `HasNoMergableItemsOnBoard` [names only] |

**Group C — discovering features**

| Id | Trigger [code] | Message | Points at | Done when | Ref |
|---|---|---|---|---|---|
| M13 chain viewer | First selection of a chain item (`selectedItemInfo` has a `chainID`, `:703`), after M2 is done | "Tap i to see every level this animal can grow into." | The "i" button (`MergeBoardView.swift:1091-1108`) | The chain viewer opens (`.mergeProgression`) | GH chain viewer from the info bar [measured, Triage §2.8] |
| M14 first daily hand-in ready | A daily hand-in task first becomes claimable (`isDailyTaskStocked`, `:881`) | "You have everything for this task. Claim takes those animals off the board." | The task's Claim button (`DailyTaskLaneView.swift:87-`) | `claimDailyTask` succeeds (`:3641`) | Same lesson as M4; TT weekly/daily tasks [measured, TT review §3.4] |
| M15 toolbox | First toolbox on the board (a new game places one, `freshStart`, `:1124`; `placeToolbox`, `:3508`) | "Tap the toolbox to collect building materials." | The toolbox cell | `absorbToolbox` (`:3530`) | TT "tool" in `BotG` [names only] |
| M16 map area affordable | The next available Sanctuary area first becomes affordable (`canAffordArea`, `:4162`) | "You can build something on the Sanctuary Map!" | The Map button (`MergeBoardView.swift:1134-1160`) | The map opens | GH arrow at the Kitchen button and "Choose Diner Renovation" [measured] |
| M17 first card pack | `pendingCardPacks` first becomes non-empty (`earnCardPack`, `:2873`) | "You earned a card pack. Open it in the Card Album on the map." | The Map button, then the album entry (`MapView.swift:365-380`) | A pack is opened (`openNextCardPack`, `:2878`) | TT "cards" [names only]; GH album at level 5 [measured, FTUE §6a] |
| M18 free chest | The free chest tile first shows "Open" (`TaskTrayView.swift:645-662`) | "A free chest is ready. Tap to open it." | The chest tile | The chest is claimed | GH timed free chest "Welcome Gift" [measured, FTUE §6] |
| M19 first bubble | A merge first bubbles its result (`maybeBubbleMergedItem`, `:2600`) | "A bubbled animal is still waiting to be rescued. Drag a matching animal onto it to free it, or leave it and it turns into coins." | The bubbled cell | A merge onto it, or the bubble decays | TT `HasBubbledItemsOnBoard`, "bubbled item" [names only]. **Must not mention or point at the pop sheet's Ad or Dog Tag buttons before D7** (§5) |
| M20 sell vs order | Unchanged trigger (`maybeShowSellVsOrderNudge`, `:2075`) | Unchanged text | — | — | Moves its seen-flag into the shared store (§6) and its order check onto the full basket (§10 item 6) |

**Group D — after the D7 gate opens** (each one checks `isMonetizationUnlocked`, `MergeBoardViewModel.swift:399-401`, at fire time, not at queue time)

| Id | Trigger [code] | Message | Points at | Ref |
|---|---|---|---|---|
| M21 skip the wait | First resting-spawner tap once the gate is open | No coach mark: the existing alert already explains itself (`MergeBoardView.swift:355-370`). Listed so the builder does not add one | — | GH inline paid skip [measured] |
| M22 first wildcard | A wildcard first lands on the board (only buyable, `purchaseWildcard`, `:1977`) | "A wildcard merges with any animal. It does not fill an order slot." | The wildcard cell | TT "joker" [names only]; D14 Q18 (a) |
| M23 shop | — | **Not added** unless the owner chooses it (Q6). A coach mark on the shop button is a store push | — | GH never pointed at the shop [measured]; TT pointed at a paid button [measured] |

Not included because the code has no such moment: chores (D10), story or characters (D11, row 8), a coin chain, a discovery reward (D13), energy crates as board items, order-slot expansion.

### 4.3 The held-item order flow, taught end to end (D14)

M3, M4, M5 and M7 together teach the whole rule in `Spec_HeldItemOrders.md` §1:

1. One slot per wanted animal (M3 points at a slot).
2. A wanted animal on the board gives its slot and its tile a **muted** highlight (M3).
3. When every slot is held the highlight turns **vivid** and **Deliver** appears (M4).
4. A part-held card has no button and pays nothing (implied by M3, and M4 fires only on a ready card).
5. Delivering takes the animals off the board (M5).
6. Merging a held animal un-holds it (M7).
7. Stored animals do not count (M9).

The urgent order uses the same moments; its timer needs no tip (the bar and the countdown already speak, `OrderLaneView.swift:283-300`).

---

## 5. D7 and D9 checks

**D7 (no monetization before `isMonetizationUnlocked`).** No moment in groups A to C points at, names, or opens a purchase, the shop, an offer, an ad, the Pass, the Kibble Drive buy button, the Reward Ladder, or a Dog Tag spend. Moments that sit next to a monetization surface, and how each is kept clear:

| Moment | Nearby surface | How it stays clear |
|---|---|---|
| M10 spawner resting | Dog Tag skip alert | Fires only while the gate is closed, when no alert appears (`:4273-4276`). Text says "resting", never "skip" |
| M11 out of kibble | Ad, Dog Tag exchange, bundle rows in the sheet | Before the gate the sheet shows none of them (`MergeBoardView.swift:1304-1316`). The tip points at the order footer (`MergeBoardView.swift:1318-1320`). **Edge:** this same tap sets `hasReachedFirstWall` (`MergeBoardViewModel.swift:1769-1775`), so a player already at level 5 or above opens the gate on that tap and sees the paid rows. The tip must still point only at the footer and the refill line |
| M18 free chest | 10 Dog Tag skip on a resting chest (`:4313-4323`) | Fires only when the chest is ready (free). Never points at a resting chest |
| M19 bubble | "Watch Ad to Pop" and "Pop with N Dog Tags" in the pop sheet, **not gated** (§10 item 8) | The tip teaches the free route (merge onto it) and does not open or mention the sheet |
| M22, M23 | Wildcard purchase, shop | Group D only, gate checked at fire time |

Test: one unit test per moment asserting it never selects a monetization target while `isMonetizationUnlocked` is false (§7).

**D9 (retention outranks monetization).** The tutorial adds no faucet, sink, price or offer trigger. Every moment either helps a player keep playing (M8, M10, M11, M12 are friction moments that point at the free way through) or explains a reward. No moment is designed to raise conversion. M23 is left out by default for that reason. Nothing here needs a "revenue at a retention cost" flag.

---

## 6. Persistence

### 6.1 Today

`tutorialCompleted` and `hasShownSellVsOrderNudge` live in `UserDefaults` (`MergeBoardView.swift:76`, `:389`, `:448`; `MergeBoardViewModel.swift:2069-2088`). That means they are not in the save (`GameState`), not synced with the save to iCloud (the save is, `GameStore.swift:280`, `:407`), not reset by the debug "fresh game" (`MergeBoardViewModel.swift:1550-` clears save state only), and not coverable by `PersistenceTests`.

### 6.2 Options

- **(a) Keep `UserDefaults`,** one key per moment, as the sell nudge does. No schema change. Inherits all four problems above, multiplied by twenty.
- **(b) One new field in `GameState`. Recommended.** `var seenTutorialMoments: [String] = []`, holding `TutorialMoment` raw values (a `String`-backed enum, per the project's persisted-enum rule). Additive, non-Optional.
- **(c) Derive everything from existing save state,** with no "seen" record. Works for "has the player ever merged", but not for "has the player seen the tip" (a tip dismissed with "×" before the action would keep returning). Not enough on its own; used inside (b) for existing saves (§6.3).

### 6.3 The schema change for (b)

`GameStore.currentVersion` is **46** at `a03ef58` (`GameStore.swift:401`). Open PR #134 (fifteen tiers spec) expects to take v47 for its own build. **The build session takes `currentVersion + 1` from the `main` it branches from** and calls it **vN** below (v47 if nothing else lands first).

1. `GameState`: add `var seenTutorialMoments: [String] = []` beside `claimedCollectionPrizeIDs` (`GameStore.swift:139`).
2. Version history comment above `currentVersion` (`:298-400`): add the vN line. Set `currentVersion = N`.
3. `additiveDefaultsSinceV8` (`:762-832`): add `"seenTutorialMoments": [String](),` with a `// vN — context tutorial` comment, after the v46 entry (`:829-831`).
4. Dispatch (`:671-725`; the v45 line is `:725`): add `if version == N-1 { return migrateByInjecting(from: N-1, defaults: [:], into: data) }   // seenTutorialMoments covered by additiveDefaultsSinceV8`.
5. **Existing saves are inferred, not replayed** (Q4 recommendation). In `finishMigration` (`:843-858`), for every `sourceVersion < N`, call a new `inferSeenTutorialMoments(&json)` after the defaults are filled. It marks a moment seen when the save shows the player has already done it:

| Moment | Marked seen when the save has |
|---|---|
| M1, M2, M6 | `mergeCount > 0` (also covers M1: nobody merges without animals) |
| M3, M4, M5, M7 | `playerLevel >= 2` or any order with `isClaimed` (the save carries no delivery counter; level 2 is the closest proxy) |
| M8, M9 | any non-null entry in `inventory` |
| M13 | `playerLevel >= 2` (inferred: a player at level 2 has met the info bar) |
| M14 | `playtestMetrics.dailyTaskClaims > 0` |
| M15 | `playtestMetrics.toolboxesPlaced > 0` or `completedAreaIDs` non-empty |
| M16 | `completedAreaIDs` non-empty |
| M17 | `cardInventory` non-empty |
| M18 | `freeChestReadyAt` later than 2001-01-01 (the migration default, `:813-817`), meaning a chest was claimed |
| M19 | not inferable; left unseen (it is rare and harmless) |
| M10, M11, M12 | `commerce.hasReachedFirstWall` for M11; M10 and M12 left unseen |
| M20 | not inferable in the migration (its flag is in `UserDefaults`); see 6 |

6. **The `UserDefaults` flags** are read once by the view model at load (not in `GameStore`, which stays free of `UserDefaults`): if `"tutorialCompleted"` is true, mark group A seen; if `"hasShownSellVsOrderNudge"` is true, mark M20 seen. The keys are then left alone (not deleted), so a downgrade still works.
7. The theme sheet's gate (`MergeBoardView.swift:44`) changes from `tutorialStep == .done` to "M1 and M2 are seen, and no coach mark is showing", so it still waits for the opening lessons.

**PersistenceTests cases** (in `PawSanctuaryTests/PersistenceTests.swift`, beside the v45→v46 cases at `:1409-1440`):
- `testV46toVNStartsWithNoTutorialMomentsSeenForAFreshSave` — a v46 blob of `makeSampleState()` with `mergeCount = 0` loads with `seenTutorialMoments` empty and `version == currentVersion`.
- `testV46toVNInfersTheCoreLessonsFromMergeCount` — `mergeCount = 5` loads with M1, M2, M6 seen and nothing else.
- `testV46toVNInfersEachLessonFromItsOwnEvidence` — one save per row of the table in 5, each marking exactly its moments.
- `testV8SaveReachesVNWithInferredMoments` — the oldest supported path (flat dispatch) also runs the inference.
- `testSeenTutorialMomentsRoundTrip` — encode and decode keep order and contents, unknown raw values included (a later build may add moments).
- `testUnknownMomentIDsAreIgnoredNotDropped` — a raw value the enum does not know survives a load and save (forward compatibility).

---

## 7. Staged build plan (task 4.3)

One stage per session and per PR. Each leaves the game playable. Unit tests run in CI; Simulator checks are listed for the owner or a worker with the Simulator.

**Stage 1 — Storage and rules, no visible change.**
- `TutorialMoment: String, CaseIterable` enum; `seenTutorialMoments` in `GameState` and on the view model; schema vN, migration and inference (§6.3); legacy `UserDefaults` read.
- A pure function `nextTutorialMoment(snapshot:seen:) -> TutorialMoment?` over a small value snapshot (counts, flags, `isMonetizationUnlocked`, whether a sheet is up). No UI calls it yet.
- Tests: every `PersistenceTests` case in §6.3; `TutorialTriggerTests` with one case per moment's trigger (fires when its condition holds, not before, not after seen), the queue order, the "never over a sheet" rule, and `testNoMomentTargetsMonetizationBeforeTheGate` for every moment.
- Simulator: none needed (no visible change); CI green.

**Stage 2 — Coach mark view; replace the three-step overlay with M1, M2, M6.**
- New coach-mark view (non-blocking, §4.1); frame reporting for the spawner cell, a board pair, the quests tile and quest Claim buttons.
- Remove `OnboardingOverlay` and the `tutorialStep` state machine from `MergeBoardView`; keep the theme sheet waiting (§6.3 item 7).
- Tests: unit tests that M1→M2→M6 advance on the real view-model events (spawn, merge, claim) and that a save with `mergeCount > 0` shows none of them.
- Simulator, fresh install: M1 bubble at the spawner with the board fully tappable; first tap closes it; M2 hand slides between a real pair; first drag-merge closes it; M6 when a quest is claimable; "×" works; force-quit mid-way and relaunch resumes at the right moment; the theme sheet appears after. Existing save: no bubbles.

**Stage 3 — The order lesson: M3, M4, M5, M7.**
- Tests: M3 fires on the first part-held order only; M4 on the first ready card; M5 after a successful delivery and not after a refused one; M7 when a merge un-holds a slot and not when it merges an unwanted animal; the urgent order triggers the same moments.
- Simulator: screenshots of each bubble on a real card; a two-card shared item (Q18 b) does not show M4 twice.

**Stage 4 — Friction: M8 to M12.**
- Tests: each trigger; M10 never fires with the gate open; M11's tip never targets a refill row even when the same tap opens the gate.
- Simulator: fill the board (M8), store an animal (M9), exhaust a spawner's 150 kibble (M10, `familySpawnerCooldownKibble`, `AnimalSpecies.swift:2405`), run out of kibble (M11; the debug kibble setter, if any, may be needed).

**Stage 5 — Features: M13 to M20.**
- Tests: each trigger; M19's target is the cell, never the sheet; M20 keeps its old behaviour and reads its flag from the new store.
- Simulator: chain viewer, daily task, toolbox, map, card pack, chest.

**Stage 6 — Group D (M22, and M23 only if Q6 chooses it).**
- Tests: none fire with the gate closed; each fires once after.
- Simulator: use the debug "unlock monetization" button (`MergeBoardView.swift:654-670`, `MergeBoardViewModel.swift:1621`).

Each stage's PR body lists the moments it adds, so the owner can turn one off by not merging.

---

## 8. Out of scope

- Story, characters, dialogue, portraits (triage row 8 is the owner's pick; D11 holds).
- Localisation (row 13). Texts are written as plain English strings, like every other string in the app today.
- Telemetry, analytics, remote tuning (row 12). The tutorial records nothing beyond `seenTutorialMoments`. `PlaytestMetrics` is not extended.
- New monetization surfaces, prices, offers, or any coach mark on a purchase before the D7 gate.
- Fixing the pre-existing D7 gaps found while reading (§10 items 8 and 9); they need their own task.
- A central interruption queue for every popup (row 20, deferred). The coach mark only waits for the others; it does not reorder them.
- Changing any rule the moments teach (order rule, cooldown, bubble, storage census).
- Replaying tips from a settings screen (could be a later task; see Q4 option c).

---

## 9. Owner decisions

**Q1 — Can the player skip the tips?**
(a) Each tip has "×", and the first one also has "Skip tips", which marks group A seen. (b) Only "×" per tip, no skip-all. (c) No dismiss; tips close only when the action is done.
**Recommend (a).** Today's tutorial is "always skippable" (`OnboardingView.swift:6`), and a returning player on a new device should not have to tap through seven bubbles.

**Q2 — Blocking or not?**
(a) Never blocking: the player can tap anything while a tip shows. (b) Block only M1 and M2 (the first spawn and merge), like Gossip Harbor's guided first merge appears to [inferred]. (c) Block every group A step.
**Recommend (a).** The 17 Nov run had to skip the current tutorial because it hid the board; a blocked step also traps a player whose board has no target (for example no mergeable pair).

**Q3 — How many tips in session one?**
(a) Group A only (up to seven; M1, M2, M4 certain), with groups B and C firing whenever their trigger first happens, spaced by the gap in §4.1. (b) Group A cut to M1, M2, M4 and M6; M3, M5, M7 move to group C. (c) Everything as it triggers, no grouping.
**Recommend (a).** It matches Gossip Harbor's one-system-at-a-time pace [measured] and puts the D14 order rule, the newest and least familiar rule, in session one.

**Q4 — What do existing saves see?**
(a) Infer from the save: skip anything the player has evidently done (§6.3). (b) Mark everything seen: existing players get no tips at all. (c) Show every tip once to everyone.
**Recommend (a).** It is the only option that teaches an existing player the new order rule (M3 to M5 are inferred only from level 2 or a delivered order) without re-teaching merging. The game has not launched, so in practice this mostly affects the owner's own test saves; (b) is an acceptable simpler fallback.

**Q5 — Wording tone.**
(a) Plain and short, second person, as the current tutorial and toasts are. (b) Voiced by the order family ("The Murphys need a Pup!"), building on "Almost there!". (c) A named guide character.
**Recommend (a).** (c) is a character (row 8, out of scope). (b) is cheap but would make some tips family-specific and others not.

**Q6 — Point at the shop once monetization opens (M23)?**
(a) No. (b) Yes, one tip on the cart button the first time the gate opens. (c) Not a coach mark, but a one-line "The shop is open" toast.
**Recommend (a).** Gossip Harbor never pushed its shop [measured]; under D9 a store push needs a retention argument, and there is none.

**Q7 — Where do tips live in the code?**
(a) A small `TutorialCoordinator` (`@Observable @MainActor`, like the other coordinators) owned by `MergeBoardViewModel`. (b) Inline in `MergeBoardViewModel`. 
**Recommend (a).** `MergeBoardViewModel.swift` is already over 4,800 lines and is the W1 lane's file (revision plan rule 7); a separate type keeps the trigger tests independent of it. This is new code, not a refactor of existing code.

---

## 10. Where the spec and the code disagree

Found while reading for this spec. None is fixed here.

1. **The quest step's text names a strip that no longer exists.** "Tap 'Quests' in the strip above the board" (`OnboardingView.swift:190`). The strip was deleted in `7e4408a` (`Spec_TravelTownReview_Draft.md` header); quests are now an icon-only tray tile with no "Quests" label (`TaskTrayView.swift:675-686`) and lane cards with their own Claim button (`QuestLaneView.swift:90-91`).
2. **The quest step is titled "Claim Your Quest Reward" but completes on opening the sheet,** not on claiming (`MergeBoardView.swift:110-114`). Claiming straight from a lane card does not complete it at all; the overlay stays until the sheet is opened or Skip is pressed.
3. **Suspected: the rescue step may advance by itself on a fresh install.** `freshStart` calls `spawnAnimal()` three times (`MergeBoardViewModel.swift:1118`), and each call raises `rescueCount` (`:2015`). `loadGame` runs in `.task` (`MergeBoardView.swift:99`) after the view appears, so the `onChange(of: rescueCount)` at `:100-104` should see 0 → 3 and jump to the merge step before the player taps. The 17 Nov fresh-install run reports seeing the rescue step, which contradicts this reading. **Unverified; Stage 2's Simulator check settles it.** M1 must not use `rescueCount` as its signal for the same reason.
4. **Suspected: the resume sync reads the counts before they load.** The `onAppear` sync (`MergeBoardView.swift:383-392`) checks `mergeCount` and `rescueCount`, but those are filled by `loadGame` in `.task`, which runs after `onAppear`. On a relaunch mid-tutorial the sync likely sees zeros and does nothing; the `onChange` handlers then advance one step at most. Reading only, not run.
5. **The pointers point at region centres.** Rescue and merge point at the board's centre, not the spawner or a pair; quest points at the centre of the tray-and-lane band (`OnboardingView.swift:38-44`, `MergeBoardView.swift:701-703`, `:735-737`).
6. **The sell-vs-order nudge checks only the first item of a basket.** It compares against `wantedChainID`/`wantedTier` (`MergeBoardViewModel.swift:2080-2086`), which are the first line only (`AnimalSpecies.swift:1101-1102`). Since baskets (v37) an animal wanted by a second line still triggers "No order wants this yet". It also uses `!isComplete`, which since D14 means "not delivered" (`AnimalSpecies.swift:1114`, `markDelivered` `:1211-1214`); that part is harmless.
7. **Dead code:** the stored `AdoptionOrder.isAlmostThere` (`AnimalSpecies.swift:1120-1123`) can no longer fire under D14, as its replacement's own comment says (`:1201-1203`). Its doc comment still describes it as live.
8. **D7 gap, pre-existing: the bubble pop sheet is not gated.** It offers "Watch Ad to Pop" and "Pop with N Dog Tags" to any player (`MergeBoardView.swift:1540-1578`), reached by tapping any active bubble (`:960-963`). Bubbles start at tier 5 (`bubbleMinTier`, `AnimalSpecies.swift:2194`), so this can happen before level 5. Not a tutorial issue, but M19 must not lead a player into it.
9. **D7 gap, pre-existing: the free chest tile spends Dog Tags on a single tap while resting.** `claimOrSkipFreeChest` charges `freeChestSkipCostDogTags` (10) with no confirmation and no gate (`MergeBoardViewModel.swift:4313-4323`; tile `TaskTrayView.swift:645-662`). A new player has 0 Dog Tags, so the guard usually refuses; a player with Dog Tags before level 5 can spend them by accident.
10. **The GDD says rows unlock by player level;** the code unlocks them by deepest merged tier (`PawSanctuary_GDD.md:365`; `AnimalSpecies.swift:1919-1925`, `MergeBoardViewModel.swift:2534-2547`).
11. **The comparison doc is stale on two points.** It quotes the old auto-spawn hint at `OnboardingView.swift:199` (`Comparison_TravelTown_GossipHarbor_PawSanctuary.md` §5-A "A tutorial discrepancy", §5-E); PR #117 replaced that line. It also says orders auto-claim [code] (§5-A), which D14's build removed (`MergeBoardViewModel.swift:3748-3751`).
12. **The revision plan and triage cite `FTUE_Analysis_GossipHarbor.md` as if it were in the repo.** It is outside it (`~/Documents/Claude/Claude Code/`), as `GossipHarbor_Bundle_And_Live_Review.md:5` says. A worker without that folder cannot read §3.1's July figures.
13. **Travel Town's `BotG_00` to `BotG_17` is eighteen numbers with twelve names listed** (`TravelTown_Bundle_And_Live_Review.md` §2). Either some graphs share a name or the list is partial; the review does not say which.
14. **`OnboardingView.swift`'s header says the tutorial is "rescue → merge → claim quest"** (`:5`); the third step is "open the quests sheet" (item 2).
