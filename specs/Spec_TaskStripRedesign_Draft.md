# PawSanctuary — task tray reference clip: scroll timing and corrections (draft)

**Status: draft, no code written yet.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log. Capture-and-measure only; no design decision is made here.

This file replaces its own first version (`7d229ec`, PR #23), whose headline was wrong. §1 lists exactly what was wrong; §2 is the new measurement; §3 redoes the comparison against the described two-axis design.

## 0. Source material

`ScreenRecording_08-31-2026 12-30-46_1.MP4` (21.217s, 1206×2622 @ 59.873fps) — **Tasty Travels**, player level 50.

**This is the same clip `Spec_TaskTrayRedesign_Draft.md` §0 was built from, and that spec is fully implemented** (`TaskTrayView.swift`, `OrderLaneView.swift`). The first version of this file did not read that spec before concluding the clip was "the wrong recording"; it is the right one, and its design has already shipped. `TaskStripView` is superseded by the tray.

Measured with `scripts/refvideo.swift`: native-resolution crops of the order lane (`0,540,1206,230`) at 0.05s steps (≈3 source frames), horizontal 1D cross-correlation of the column-gradient profile over x=250–1010 (negative = content moves left), outliers (corr < 0.8) replaced by the local median; 0.05s sweeps of the tray edge across the collapse (2.0–2.75s) and expand (9.0–9.95s); 0.25s sheets of the left widget (10.5–19.5s) and the whole band (1.75–11.0s). **Vertical-axis cross-correlation was tried and discarded** — the tile rows repeat and the page jumps exceed any usable search window — so the vertical widget is described from 0.25s sheets only.

---

## 1. What the first version got wrong

| First version said | The footage shows |
|---|---|
| The clip is not footage of the intended design; wrong recording | It is the source clip of the already-built tray spec. The described design (horizontal lane + vertically scrolling thumbnail grid with embedded progress) *is* what this clip shows. |
| A passive home screen, "auto-rotating", "no touch visible" | **iOS screen recordings do not draw touches, so "no touch visible" was never evidence.** The board is untouched, but both scrollers are being driven; the kinematics in §2 are those of finger flicks (instant onset, exponential decay, hold-to-stop, direction reversals, rubber-band overshoot). The catalogue's "auto-rotating" label is wrong for the same reason. |
| A home-screen banner, not the in-play surface | It is the in-play task tray at the top of the main board screen. |
| A "fixed" NEW! pass card beside the lane | The "NEW! 0/5" gold pile is the header art of the **first lane card** (the dragon/fabric/pin order, `+15`/`+3600`, 29m timer). It scrolls with the lane — gone by 2.5s, back by 8.5s. The only fixed element at the right edge is the round Statue-of-Liberty icon with the H:MM:SS countdown. |
| Left widget "pages" through 3 pages of six on a timer | A **4-row × 3-column** tile list seen through a **2-row window**; the 3 dots are the 3 window positions (rows 1–2, 2–3, 3–4). Scrolled by hand. |
| Lane cards are a "loyalty rail", not orders | They are order cards. Each shows a portrait, a purple potion pill, a starfish `+N`, a green ticket `+N`, a coin `+N`, one or two item slots and a medal count. The medal value tracks the coin payout closely (≈170–240 coins per point on five of six cards: `850→5`, `3,600→15`, `3,700→20`, `7,750→40`, `13,000→65`), which is the per-order token value `Spec_OrdersAndTasks_Draft.md` §2 describes. |

---

## 2. Timing

### 2.1 Event timeline (t in seconds)

| t | Event |
|---|---|
| 0–2.05 | Static. Tray 3-wide; lane at its origin (pass-pile order first). |
| **2.10** | **Collapse + leftward lane flick start together.** Lane speed 0 → ~700 → 1,180 → 1,240 px/s inside 0.10s — no ease-in. |
| 2.10–2.45 | **Collapse: tray right edge ≈650 → ≈205px (~445px) in ≈0.35s at a near-constant 1,050–1,350 px/s, then stops dead.** No visible ease-in or ease-out (edge estimates read off sheets, ±20px). |
| 2.5–3.62 | Lane continues left and decays; exponential fit τ ≈ **0.47s** (22 samples). |
| 3.65 | One zero-velocity sample (0.05s), then 3.70 restarts at ~1,100 px/s — a second flick. |
| 3.70–5.10 | Second push, slower decay (τ ≈ 1.4s); stops at ≈5.1 with a ~9px opposite bounce. Left travel by flick: −1,281px, then −740px; **≈−2,050px total**. |
| 5.1–5.7 | Dwell at the far end (0.65s); last card (knight order) fully in view. |
| 5.75–10.4 | **Return, ≥6 separate pushes** restarting at 5.75, 6.45, 7.15, 7.80, 8.30, 9.15 (gaps 0.70, 0.70, 0.65, 0.50, 0.85s). Each restarts at 10–40 px/step and peaks at 36–89 px/step (≈700–1,800 px/s), then decays. **≈+2,110px — equal and opposite to the leftward travel within ~3%.** |
| **9.10–9.75** | **Expand: tray edge ≈225 → ≈650px (~425px) in ≈0.65s**, fast at first (~1,100 px/s over the first 0.2s) then decelerating to ~470 px/s — visibly ease-out. |
| 10.05–10.40 | Rubber-band overshoot past the origin, ≈55px, settling in ≈0.35s. |
| 10.45–11.2 | Static, tray expanded, lane at origin. |
| 11.25–18.2 | **Left widget scrolled vertically by hand** (§2.3). Lane untouched. |
| 18.25–19.5 | Static. (Final ~2s is iOS Control Center.) |

Lane extent ≈2,050px at a card pitch of ≈388px ≈ 5.3 pitches — **six order cards**, matching the six counted by eye.

### 2.2 What the kinematics say

Offered as consistent-with, not proof — the finger is invisible:

- **Instant onset, then exponential decay.** A scripted slide eases in; this does not. τ ≈ 0.47s is close to `UIScrollView`'s normal deceleration (0.998/ms ⇒ τ ≈ 0.5s), which SwiftUI's `ScrollView` shares.
- **Hold-to-stop at 3.65, direction reversal at 5.75, a restart every ~0.7s** — a person flicking again before the last flick has died.
- **Out-and-back over the same ~2,050px with a rubber-band bounce at the origin** — the list was driven to both ends.

### 2.3 Left widget, vertical (0.25s resolution only)

Three resting windows were seen: **W1** (rows 1–2) until 11.25 and again from 18.25; **W2** (rows 2–3) at 12.75–13.5, 14.5–15.25 and 17.25–17.75; **W3** (rows 3–4) at 15.5–17.0. Roughly nine window changes in ~7s, including a W3→W1→W3 round trip inside 13.75–14.25 (two-row jumps in ≤0.25s). Every dwell sampled was row-aligned, while mid-motion frames show rows clipped at both edges — so motion is continuous, and rests *look* snapped. One mid-scroll frame (as in the tray spec's §1.4) cannot distinguish "snaps on release" from "the user stopped on a row"; this clip cannot either. The dots: top lit at W1, middle at W2, bottom at W3.

### 2.4 Against what shipped

`TaskTrayView.setExpanded` animates collapse and expand identically: `.easeInOut(duration: 0.28)`.

| | Reference (this clip) | Shipped |
|---|---|---|
| Collapse | ≈0.35s, near-constant speed, no ease | 0.28s easeInOut |
| Expand | ≈0.65s, decelerating | 0.28s easeInOut |
| Symmetry | Expand ≈1.9× slower than collapse | Symmetric |

Caveat on interpretation: the reference collapse looks finger-tracked (constant speed, stops when the finger lifts) rather than a fixed-duration animation, so 0.35s is a swipe's duration, not necessarily a designed one. The expand is the cleaner animation sample. `Spec_TaskTrayRedesign_Draft.md` §0 says its expand sweep covered 10.6→12.4s; in this clip the tray is already fully expanded by 9.75s and 10.6–12.4s is the start of the vertical widget scroll, so that sweep window appears to be off by ≈1.5s.

---

## 3. Comparison against the described design

Described: *quests along the horizontal axis; always-present cards (smile/star awards, daily/weekly/monthly goals, parallel-board games) scrolling vertically as small thumbnails, often with a progress bar in the thumbnail.*

| Described | Observed | Verdict |
|---|---|---|
| Two scroll axes, one horizontal, one vertical | Yes — an order lane (horizontal) and a tile grid (vertical), both hand-scrolled | **Match** |
| Vertical element is small thumbnails | 40pt-class icon tiles, 3 across, 2 rows visible | **Match** |
| Progress bar embedded in the thumbnail | `7/12` bar, pass bar, `900` bar, `0/3` fraction inside the tile; countdowns on a pill below | **Match** |
| Vertical content: smile/star awards, daily goals | Starfish `7/12` (star award) and the `0/3` daily checklist are present | **Match** |
| Vertical content: weekly/monthly goals, parallel board | Not identifiable. Event tiles read `2d 16h` / `6d 16h` and a tiki tile carries a red dot; Tasty Travels has no parallel board in any capture | **Not shown** |
| **Horizontal content is quests** | **Horizontal content is orders.** The one quest-like tile (starfish `7/12`) is in the vertical grid | **Mismatch — the axes' contents are swapped** |
| (implied) a new design | This layout is what `TaskTrayView` already implements | **Already built** |

Relation to `Spec_TravelTownReview_Draft.md` §3's three options: this is not a fourth option — `Spec_TaskTrayRedesign_Draft.md` already records that none of the three is what it proposes, and chose this.

## 4. Open questions

1. **Is a redesign of the shipped tray still wanted?** If the described design is the tray, there may be nothing left to redesign — or the intent may be *quests* on the horizontal lane, which is a genuine departure from both the clip and the build.
2. **Should the expand be slower than the collapse, and decelerate?** §2.4 — a tuning question the clip raises, not answers.
3. **Is collapse triggered by the lane flick itself?** Collapse (2.10) and the lane's leftward flick start in the same 0.05s; the expand ends as the lane returns to origin. Touches are invisible, so a swipe-direction rule and a board tap cannot be told apart here.
4. **What is the floating trophy tile?** From ≈3.5–5.25s and 6.25–8.4s a trophy tile (rank `37→40`) sits to the right of the collapsed tray while the lane scrolls behind it, and is absent at 5.5–6.0s and 2.5–3.25s. Not explained by this pass.
5. **Do the vertical rests snap?** §2.3 cannot say.
