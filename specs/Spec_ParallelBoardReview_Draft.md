# PawSanctuary — Parallel Board review: Travel Town "Greek Fest" (draft)

**Status: draft, no code written yet.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Fifth in the reference-review series, after `Spec_PartyBoard_Draft.md`, `Spec_BoardAnimation_Draft.md`, `Spec_OrdersAndTasks_Draft.md` (closed), and `Spec_TravelTownReview_Draft.md`.

**Capture only.** The user's instruction for this pass: *"Only make note of their technical aspects and add to the plan for eventual implementation."* Nothing below is a proposal, a design decision, or an instruction to change `Spec_Phase6b_ParallelBoard.md` — which is already implemented and design-reviewed. The delta tables in §2 are "here is what the reference measurably does differently," recorded for whoever later decides whether Phase 6b should be revised.

## 0. Source material

`ScreenRecording_08-22-2026 21-33-09_1.MP4` — **Travel Town**, player level 50.

| | |
|---|---|
| Duration | 139.455 s (2:19) |
| Resolution | 1206 × 2622 |
| Frame rate | 59.811 fps |
| Size | 247.9 MB |

**Title identification** (the filename does not say which title): the main board is Travel Town's — orange checkerboard, palm-tree gold coin, the vertical left-hand task column, the L50 badge with a group photo, `wantedChainID`-style single orders with a starfish "11/12" bar. The event is Travel Town's **"Greek Fest"**, matching `Capture_Log.md`'s 23 Aug 2026 entry (findings 4–6): a Santorini-themed second merge board layered on the main game, ~31.5 h window. This is one continuous L50 session — the coin counter reads **15,083 unchanged** from 0 s to the end, on both boards.

**Relationship to `Capture_Log.md`.** This exact file was triaged on 23 Aug 2026 (that entry's findings 4, 5, 6 — the Greek Fest board, a claimed second premium currency, a second merge-completion toast). This document is the deep frame-by-frame dive that triage flagged as worth doing. It extends finding 4 (collection structure), does **not** reproduce finding 5 (see §4.1), and does not resolve finding 6.

**Method.** `scripts/refvideo.swift`: contact sheet at 2 s for structure, then `frames`/`crop` sweeps down to 0.02 s steps on the board-to-board transition (13.1–15.8 s), the "Legendary!" merge (7.2–8.8 s), a Greek Fest generator tap (22.0–25.0 s), an energy collect (90.4–93.2 s), and a Greek Fest merge (33.0–35.2 s). Native-resolution crops on the HUD, the board grid, and the main-board event panel.

**What the recording contains, by time:**

| Window | Screen |
|---|---|
| 0 – ~2 s | iOS Control Center, then the main Travel Town board |
| ~2 – 13.30 s | Main-board play — merging toiletries (toothbrush → toothpaste), one high-tier merge firing a **"Legendary!"** banner (~7 s) |
| **13.30 → 13.32 s** | **Hard cut to the Greek Fest board** (see §1) |
| ~13.32 – 13.46 s | Greek Fest board populates in stages; an empty-state coach bubble is pinned to the generator |
| ~13.46 – 15.05 s | The **"1+1 Greek Fest"** IAP offer auto-presents on top (scale-in), then is dismissed |
| ~15.1 – ~128 s | Continuous Greek Fest play — generator taps, merges, energy-chain merges and collects, the board filling with wrapped items |
| ~129 – 137 s | The full-screen **"Event Collection"** panel (opened from the scroll's book icon) |
| ~137 – 139 s | iOS Control Center (recording ends) |

**No transition *back* to the main board is captured** — the recording ends inside a Greek Fest sub-panel, then Control Center. The red "X" in the Greek Fest HUD is the exit control and is never pressed on camera.

---

## 1. The switch into the parallel board — the primary focus of this pass

### 1.1 Trigger and sequence

The main board carries a persistent **Greek Fest event panel** in its left-hand task column (native crop at 4.0 s): the festival character (blonde, flower headband, sunglasses), a gem-filled cocktail glass, the `31:26:47` countdown, and a reward-preview strip — `+11` evil-eye token, `+1` starfish token, `+150` red-hex event-points badge, `+7750` coins. This panel is the only Greek Fest affordance on the main board, and the transition lands directly on the Greek Fest board with no intermediate menu, so the entry point is **that panel**. (No press/highlight state is legible in the frames immediately before the cut; inferred from there being no other route.)

Frame-accurate sequence:

| Time | State |
|---|---|
| 13.30 s | Main Travel Town board, fully interactive |
| **13.32 s** | Greek Fest board present — checkerboard, collection scroll skeleton, generator, ~6 items, coach bubble "Oh no, you're out of items!" pinned to the generator. No header event-timer, no "1+1" button, no bottom task-list button yet |
| 13.36 s | ~12 board items now present; collection scroll shows 1 target silhouette |
| 13.40 s | ~20 board items; scroll shows 3 silhouettes; **"1+1 / 31:26:37" button has faded into the header**; bottom task-list button is solid |
| 13.42 s | Board full (~22 items) |
| ~13.46–13.66 s | The "1+1 Greek Fest" offer modal **scales in from centre** (~150–200 ms) |
| 13.66 – 15.05 s | Offer modal held (two stacked red "X" close buttons = two popups queued) |
| 15.05 → 15.12 s | Offer dismissed — near-instant (≤1 step at 0.04 s), no slide/fade choreography visible |
| ~15.1 s | Settled Greek Fest board, interactive |

### 1.2 There is no transition animation

The main board → Greek Fest board change happens **within one 60 fps frame interval** (13.30 → 13.32 s, ≈17–33 ms). No wipe, fade, slide, zoom, iris, or push. The Santorini backdrop is already fully painted on the first Greek Fest frame. It reads as a **screen swap / route change**, not a transition.

This matches `Spec_Phase6b_ParallelBoard.md` §3.7's implementation choice — a `.fullScreenCover` driven by `showParallelBoard`, which is a plain SwiftUI cover with no custom transition. The reference gives no reason to add one.

### 1.3 The board reveal is staged (~120 ms), and looks like an async load rather than a flourish

Over 13.32 → 13.44 s the board assembles in a rough order: container + checkerboard + generator + collection-scroll frame first (with the coach bubble already pinned), then board items rez in over several frames roughly in reading order, then the collection-scroll target silhouettes populate one at a time, then the header "1+1" button fades in and the bottom task-list button solidifies. The staggered, reading-order appearance and the coach bubble being present from frame one read as **view construction**, not a designed intro sequence — but it is visible on camera and worth noting for whoever builds `ParallelBoardView`'s first-open path, since PawSanctuary's version currently has no equivalent (the cover either is or isn't mounted).

### 1.4 Entering the event auto-triggers the IAP offer

The "1+1 Greek Fest" offer (§4) is **not** already on screen when the player is on the main board (13.30 s) and **is** presented ~150 ms after the Greek Fest board finishes loading. So the offer is fired **by entering the event**, not encountered on the way in. The two stacked close buttons indicate the offer is one of at least two queued popups gated behind the event-open.

`Spec_Phase6b_ParallelBoard.md` §7 lists "Offers tied to the parallel board" as explicitly out of scope ("`OfferHooking` already exists… but wiring a parallel-board-specific offer isn't designed here"). The reference shows the offer is **entry-gated**, not board-embedded — relevant if that scope is ever picked up.

### 1.5 Exit

Not captured. The Greek Fest HUD's red "X" (top-right, §2.6) is the exit affordance; the recording ends before it is used. No inference possible about an exit transition.

---

## 2. Parallel-board presentation — deltas vs `Spec_Phase6b_ParallelBoard.md`

`Spec_Phase6b_ParallelBoard.md` was **written cold** (its own header says so) and its §4 numbers are flagged as "a placeholder for the design authority to replace, not a designed event." This section is the measured reference against which those placeholders can now be checked. Several are materially different from what shipped.

| Aspect | `Spec_Phase6b_ParallelBoard.md` (shipped) | Greek Fest (measured) | Delta |
|---|---|---|---|
| Board size | 5×5 = 25, fully unlocked (§4) | **7 wide × ~7 tall ≈ 49**, fully unlocked (7-wide is firm from item alignment in the native crop; 7-tall is a count from the fullest frames — treat as 7 ±1) | **~2× the cells** |
| Generator placement | an ordinary in-grid cell at a fixed `GridPosition(row: 0, col: 0)`, rendered with generator chrome (§3.3, §3.6) | a **large tile centred *below* the grid**, in its own pedestal slot, **not occupying a board cell** | Structural — the generator is off-board |
| Generator badge | — (energy lives only in `ParallelBoardEnergy`) | a **decrementing number on the generator tile** (seen 34 → 27 → 26 → 25 → 21 → 20 → 15 over the session), i.e. spendable energy is shown *on* the producer | Energy is surfaced at the point of spend |
| Generator output | one fixed base-tier item of the event's single chain (§3.3) | items on an evil-eye / Greek-jewellery chain; the tile art changes to show the next item it will dispense, and at least one tap produced a **tier-2** item ("Eyed Earrings"), not tier-1 — output tier may not be fixed | Output identity/tier less fixed than spec'd |
| **Energy model** | a **passive time-regen pool** — `ParallelBoardEnergy`, cap 30, +1 / 90 s, **no offline catch-up** (§3.2) | **energy is a board merge-chain.** "Broken Energy" → ⚡ → ⚡⚡ → ⚡⚡⚡ → max, merged up on the board like any other item; **tapping an energy item "collects" it** into the pool, value scaling with tier (**"Tap to collect 2⚡"** at low tier, **"Tap to collect 100⚡"** at max). No passive regen timer is visible anywhere in 2+ minutes on the board. | **Fundamentally different.** The reference makes energy an active cultivation loop on the board itself; the spec makes it a background timer. This is the largest single delta in this document. |
| Progress / reward track | one `ProgressTrack`, **free-lane only**, 8 linear milestones (steps of 20, 20…160), awarded a fixed amount per top-tier completion (§3.5, §5) | a **27-set "Event Collection" book** (see §2.3) — named sub-collections each requiring a specific item set, plus a linear per-item progress bar on the scroll with a marker, plus an on-board "0/3" card-pack meter. Sets pay **the main game's energy + gems** (110⚡+40💎, 75⚡, 100⚡, and a locked 200⚡+80💎 bonus tier observed). | The reference reward layer is a multi-set collection album that is a **net main-game resource source**, not a self-contained event track. Matches `Capture_Log.md` 23 Aug finding 4. |
| Chain content | a single 5-tier chain ("Second Chances", `parallelboard.secondchances`, reusing `.animal`) | **many concurrent chains**: evil-eye jewellery, Hermes/winged-helmet, laurel wreath / toga / sandals, caduceus, lyre / mandolin / harp, amphora, Poseidon trident, Zeus, "Diamond Shard" magenta crystals, coloured orbs, pegasus, plus the energy-bolt chain — and a whole **"wrapped" layer**: items sealed on a draped marble slab that must be merged to unwrap, exactly like the main board's cardboard-box items. Plus a "1/4" marble block chipped with a chisel. | The reference board is a **complete second content set**, not one chain |
| HUD | not specified | **stripped**: shared coins + shared gems only, **no energy, no level badge, no shop button, no "+" buttons on the currencies**, plus a red "X" to exit and the "1+1" offer button. Two independent timers — a header `hh:mm:ss` and a `1d 7h` on the scroll and task-list (roughly the same ~31.5 h window in two formats). | The parallel board deliberately hides most of the main HUD |
| Empty-board state | not specified | an explicit coach bubble **"Oh no, you're out of items!"** pinned to the generator when no merges are available | The reference has a dedicated no-moves prompt |
| Background / frame | "Second Chances" rescue theme | a Santorini/Aegean diorama — white cubic buildings, blue-domed church, sea, yacht — with the board sitting inside a ruins frame (broken columns, a toppled terracotta amphora, daisies) | Cosmetic, but the parallel board gets its **own full environment art**, not a reskinned main-board background |
| Entry point | `ParallelBoardTaskCard` in `TaskStripView`, gated on `activeParallelBoardEvent` (§3.7) | a persistent event panel in the main board's task column (character portrait + reward preview + timer), and entering **auto-fires an IAP offer** (§1.4) | Entry-gated offer is the notable addition |

### 2.1 The energy delta, expanded

This is worth stating plainly because it changes the shape of the mini-game. In `Spec_Phase6b_ParallelBoard.md` the loop is: *wait for `ParallelBoardEnergy` to tick up → spend it at the generator → merge*. In Greek Fest the loop is: *merge energy-bolt items up the energy chain → tap the top one to bank a large chunk → spend it at the generator → merge*. The reference's energy is a **resource you produce on the board**, with its own chain, its own tier curve, and its own tap-to-collect step — closer to a second producer output than to a countdown. There is no observable passive regen at all.

Consequences if the reference model were ever adopted (not proposed here, just noting what it would touch): `ParallelBoardEnergy`'s `tick()` / `secondsUntilNext` / cap model would not fit; energy would need to be a registered chain in `ContentRegistry`; `attemptMerge` would need a "this item is a collectible" branch (tap-to-collect, not tap-to-select); and the "no offline catch-up" simplification (§7, deliberately deferred) becomes moot because there is nothing regenerating offline.

### 2.2 The generator, expanded

Native crop (25.0 s) and the 22.0–25.0 s sweep:

- The generator is a rounded-square gold tile in a pedestal slot **below** the 7-wide grid, flanked by empty space, with the task-list tile to its right. It is not in the checkerboard.
- Its badge is a red circle with a number = **current spendable energy**.
- Its art shows the item it will dispense (evil-eye / earrings in most of the recording).
- One tap: badge **−1**, a new base item **materialises at the generator and arcs over intervening cells to a destination empty cell** (~80–120 ms), landing with the hint bar updating to the new item's name. See §3.3.
- When the board has no available merges, the "out of items" coach bubble points here (§2, empty-board row).

### 2.3 The "Event Collection" book, expanded

Opened from the book icon on the scroll (129–137 s). A parchment panel, blue "EVENT COLLECTION" banner, a coin/gem/scissors pile spilling over the top edge, red "X" close. Contents:

- A top progress bar: book icon + green bar reading **`20/27`** (later `23/27` as sets completed during play) + a "NEW!" tag + an "(i)".
- Named collection sets, each a titled group with a reward header:

| Set | Items | Reward |
|---|---|---|
| **Greek Grandeur** | ~13 shown + 2 locked "?" (evil-eye, evil-eye earrings, gold hoop, sandals, boots, laurel wreath, amphora, mandolin, lyre, toga dress, winged helmet, pegasus, ⚡) | 110⚡ + 40💎 + scissors |
| **Mystic Monuments** | 6 shown + 1 locked (green flame, green fibula, green croc, green caduceus, blue pegasus, ⚡) | 75⚡ |
| **Greek Cuisine** | 5 shown + 1 locked (dolma, hummus, stuffed pepper, gyro, greek salad) | 100⚡ |
| *BONUS SECTION* 🔒 → **Greek Statues** | 5 locked ⚡ + 1 "?" | 200⚡ + 80💎 (pink/premium-tier header) |

"Reach the BONUS SECTION to win EVEN MORE REWARDS!" gates the last tier. This corroborates `Capture_Log.md` 23 Aug finding 4 (21/27 sets, per-set energy payouts of 75/100⚡, a locked bonus section) and refines it: sets vary in size (~6 to ~15 items), the richest sets also pay gems and a utility item (scissors), and there is a scroll-level per-item bar **on top of** the per-set structure.

### 2.4 On-board reward meter

A small wooden stand at the board's right edge holds a card-pack icon reading **`0/3`** (later `1/3`), with a gold star. It fills as matching items are fed to it — a third progress surface, on the board itself, distinct from both the collection book and the scroll bar. Not analysed further.

---

## 3. Animations — new vs. reconfirm

Cross-referenced against `Spec_BoardAnimation_Draft.md` (§1 merge choreography, §3a shipped Tier A, §4 producer shimmer + spawn-flight) and `Spec_OrdersAndTasks_Draft.md` §3 (bubble delivery, per-merge currency callout). `Spec_TravelTownReview_Draft.md` §2 covers per-currency reward-flight arcs on the main board's order claims — not re-derived here (no order claim occurs in this recording).

### 3.1 Merge choreography — RECONFIRM

Both boards run the same five-phase sequence `Spec_BoardAnimation_Draft.md` §1 documented from Gossip Harbor: converge → cyan/teal glow → white-hot burst with gold four-point stars → elastic overshoot past resting size → stars drift and fade, outliving the item settle by ~0.5 s. Captured on the main board (the "Legendary!" merge tail, 7.2–7.5 s — soap dispenser visibly springing back from overshoot with residual white sparkles) and on the Greek Fest board (33.6 s — "Sunny Sandals", gold star burst).

This puts the choreography at **3 of 3 reference titles** (Gossip Harbor, Tasty Travels per `Spec_OrdersAndTasks_Draft.md` §3, now Travel Town). No new detail; it reconfirms that `Spec_BoardAnimation_Draft.md` §3a's shipped Tier A is aimed at the right target.

### 3.2 "Legendary!" tier-name word banner — NEW

On a high-tier / max-tier merge on the main board (~7.0 s, a hand-sanitiser bottle), a large playful blue word — **"Legendary!"** — appears centred over the board and lingers **~0.7 s+** after the merge settles, independent of the item's own animation. It is a **rarity/tier name**, not a toast.

This is distinct from:
- the shipped Tier A sparkle/bloom (`Spec_BoardAnimation_Draft.md` §3a) — that is per-cell; this is a board-centre text overlay;
- the "DING!" / "NEW MILESTONE!" toasts `Capture_Log.md` 23 Aug finding 6 noted on this same account — those are top/bottom toasts with icons; "Legendary!" is a centred word with no icon.

So Travel Town has **at least three separate merge-feedback surfaces**: per-cell particles, edge toasts, and this centred rarity-word banner. PawSanctuary has none of the third kind. Recorded, not proposed.

### 3.3 Generator spawn-flight arc — RECONFIRM (2nd title, and first on a parallel board)

Greek Fest generator tap (22.60–22.76 s, 0.04 s steps): energy badge −1, the new base item appears at the generator, then **arcs across the board over occupied cells to its destination empty cell** in ~80–120 ms, landing as the hint bar updates. This is the same fly-from-producer-to-cell arc `Spec_BoardAnimation_Draft.md` §4 recorded from Gossip Harbor (there with "a bright magenta comet trail") and listed as open question #4 ("adopt the reference's fly-from-producer-to-cell arc? PawSanctuary currently places spawned items directly").

New here: it is now seen in a **second title** and on the **parallel board specifically** — so if the parallel board ever adopts it, it is consistent with what the reference's own parallel board does. At 0.04 s sampling the arc is clear but a strong coloured trail is not resolvable — either fainter than Gossip Harbor's or too fast for this step. Still open question #4, now with a second data point.

### 3.4 Energy-collect particle stream — NEW

Collecting a maxed energy item on the Greek Fest board (90.9–92.3 s): the hint bar reads "Tap to collect 100⚡ — this item is at MAX level"; on tap, a **green "+100⚡" text callout** spikes at the item **and a spray of ~8 gold lightning-bolt particles arcs across the lower board** toward the generator / task-tracker area over ~0.5–0.9 s, depositing into the energy pool. The "+100" callout lingers unusually long (~0.9 s vs the quick drift-and-fade of a per-merge callout).

This is the parallel board's **own currency-flight animation**, structurally like `Spec_TravelTownReview_Draft.md` §2's per-currency reward arcs but sourced from a board tap rather than an order claim, and like `Spec_BoardAnimation_Draft.md` §4's spawn comet in reverse (board → producer instead of producer → board). New surface; recorded for the same "fold into Tier A's per-currency flight cases" bucket §2 of the Travel Town review used.

Caveat: the generator badge did **not** visibly increment from 15 during the 0.9 s the "+100" was on screen — either the deposit resolves after the callout clears, or the badge is not a simple running total. Pooling semantics unresolved from this capture.

### 3.5 Floating "+N" currency callout on merge/collect — RECONFIRM

Small green "+N" text drifting up from a merge or collect site and fading (~0.9 s). Same mechanic as `Spec_OrdersAndTasks_Draft.md` §3's "per-merge currency callout" (Tasty Travels, shell "+1"/"+2"). Here the values are larger (+100 seen) and the callout lingers longer than §3's description. PawSanctuary still surfaces no floating callout at the merge site.

### 3.6 Offer-modal present / dismiss — NEW (minor)

The "1+1 Greek Fest" modal **scales in from centre** over ~150–200 ms (13.46–13.66 s). Dismiss is near-instant — gone within one 0.04 s step (15.05 → 15.12 s), no reverse-scale or slide legible. Recorded only because modal choreography has not been characterised in any prior review; it is a fast scale-in, hard-cut-out.

### 3.7 Staged board-entry reveal — NEW

Covered in §1.3 — board elements rez in over ~120 ms in rough reading order, chrome fades in staggered. Whether designed or incidental, it is on camera and PawSanctuary's `.fullScreenCover` has no analogue.

### 3.8 Collection-book item reveal — NEW (note only)

In the Event Collection panel, a "?" slot (the pegasus in "Greek Grandeur") flips to a revealed icon between two 2 s samples. A per-item unlock pop exists; not sampled tightly enough to describe its choreography.

---

## 4. The "1+1 Greek Fest" offer — mostly reconfirm

Native crops at 13.5–15.0 s. Greek-temple-pediment frame on the Santorini backdrop, "1+1" title, "GREEK FEST", `31:26:37` timer pill, "BUY 1 & GET 1 FOR FREE!". Two identical columns:

| Contents (each column) | |
|---|---|
| Evil-eye amulet | ×50 |
| Gem (purple) | ×30 |
| Energy bolt | ×250 |
| Card pack (three-star) | ×1 |

Buttons: green **"$7.99"** (left) / pink **"FREE 🔒"** (right). Buying the left column unlocks the right for free.

This reconfirms `Capture_Log.md` 23 Aug finding 5's offer contents exactly ($7.99 → 50 evil-eye + 30 gem + 250 energy + 1 three-star pack, unlocking an identical free second bundle) and the 4th-shape-of-one-offer-engine framing (`Spec_PartyBoard_Draft.md`; `Capture_Log.md` 27 Jul / 29 Jul / 1 Aug). No new offer mechanic.

### 4.1 Does **not** reproduce finding 5's "second premium currency" claim

`Capture_Log.md` 23 Aug finding 5 states Greek Fest showed *"a purple 'diamond' currency (3 held) on the HUD alongside the game's standing ruby/gem currency (2 held) — two different premium currencies live at once."*

This deep dive **does not see that.** On the main board (0.5 s crop) and on the Greek Fest board (25 s crop) the HUD shows **one** premium currency — a purple gem reading **`3`** in both places — and the "1+1" offer sells "30" of that same purple gem. The evil-eye amulet ("×50" in the offer, "+11" in the main-board reward preview) is an **event token used for collections**, not a HUD currency. The red-hex "+150" badge in the reward preview is an event-points icon, also not a premium currency.

Not asserting finding 5 is wrong — it may have read a screen this recording doesn't contain — but flagging that a full frame-by-frame pass of this file found **a single, shared purple gem currency**, not two. Worth a targeted re-check of whatever frame finding 5 was drawn from before that observation is relied on.

---

## 5. Open questions

1. **Energy pooling semantics** (§3.4) — is the generator badge a running total that lags the collect animation, or is banked energy tracked elsewhere with the badge showing something else (charges? a cap-limited display)? Unresolved from this capture.
2. **Generator output tier** (§2.2) — the generator produced a tier-2 item ("Eyed Earrings") on at least one tap. Does it always dispense tier-1, cycle its output, or upgrade what it dispenses as the event progresses? Needs a longer look at consecutive taps.
3. **Board dimensions** (§2) — 7 wide is firm; 7 tall is a count, not a measurement. A frame with the whole grid empty would settle it.
4. **Exit transition** (§1.5) — never captured. Does leaving the parallel board animate, and does it return to where the player was on the main board?
5. **Collection-set-complete celebration** — sets completed during play (20/27 → 23/27) but no full-screen celebration was caught between samples. `Spec_TravelTownReview_Draft.md` §4 records that Travel Town's *main-board* milestone ladder uses a full-screen "NEW MILESTONE!" takeover; does the parallel board's collection do the same? Unknown.
6. **Second-premium-currency question** (§4.1) — reconcile with `Capture_Log.md` 23 Aug finding 5.
7. Spawn-flight trail colour (§3.3) — carried over from `Spec_BoardAnimation_Draft.md` §7 open question #4, still unresolved.

## 6. Suggested next step

Accumulate for the design phase alongside the other reference-review drafts. Nothing here is implementation-ready and none of it is a decision.

- **§2 (parallel-board deltas)** is for whoever decides whether the shipped `Spec_Phase6b_ParallelBoard.md` should be revised against measured reference data. The energy-model delta (§2.1) is the one that would change the mini-game's shape; the rest (board size, off-grid generator, collection-book reward layer) are contained.
- **§3.2 (the "Legendary!" banner)** and **§3.4 (energy-collect particle stream)** are the genuinely new animation findings. Per `Spec_TravelTownReview_Draft.md`'s precedent for its §2, the per-currency flight belongs folded into `Spec_BoardAnimation_Draft.md`'s Tier-A-style scope if that spec is reopened, rather than standing alone — but that is a note for the design pass, not done here.
- **§3.1 / §3.3 / §3.5** reconfirm existing findings and need no further action beyond the extra data point.
- **§4.1** should be raised against `Capture_Log.md` before finding 5's two-currency claim is used.
