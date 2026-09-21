# PawSanctuary — TaskStripView redesign reference review (draft)

**Status: draft, no code written yet.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log. Requested as a check against a specific redesign idea before any design or implementation work starts.

**Headline finding: the footage does not show what it was expected to show.** This recording is not the user's own `TaskStripView` redesign prototype — it is already-catalogued **Tasty Travels** reference footage of a passive home-screen banner, and its actual on-screen structure only partially resembles the two-axis (horizontal quests + vertical thumbnail rail) design described going in. See §3 for the full comparison; do not skip to §4 or §5 without reading it.

## 0. Source material

`ScreenRecording_08-31-2026 12-30-46_1.MP4` (21.217s, 1206×2622 @ 59.873fps, 37.0MB) — confirmed **Tasty Travels**, not a PawSanctuary prototype and not footage of any of the three primary reference titles' in-play task rail.

This exact file already has a row in `Capture_Catalogue.md` (dated 08-31-2026, tags `event` `ui-chrome`, Deep dive: `—`), catalogued from a triage pass before this session. That row's one-line description — "home-screen banner stack made of three independently auto-rotating widgets" — is confirmed accurate by this frame-by-frame pass; this spec adds the detail a triage pass doesn't capture. **Action taken: the existing catalogue row's Deep dive column was updated to point at this spec rather than adding a duplicate row for the same file** (see §7 for why).

Analysed with `scripts/refvideo.swift`: `info` for duration/resolution/fps, a `sheet` contact sheet at 0.5s steps (43 thumbnails) for overall structure, then native-resolution `crop` sweeps at 1–2s steps on the HUD banner region (`0,60,1206,420`), the vertical page-dot indicator (`0,470,100,120`), the full-screen frame at two timestamps (`0,0,1206,2622`), and the mid-screen card band (`0,300,1206,450`) across the first 10 seconds.

---

## 1. What the clip actually is

A **static home/idle screen**, never entered from or returning to active board play within the 21.2s. Coins (8,320), gems (7) and energy (115) never change. The merge board fills the lower ~60% of the screen and is never tapped, never merges, never scrolls — it just sits there as backdrop. The final ~2s is iOS Control Center (the recording being stopped), confirming this is the entire captured session, not a clip excerpted from a longer one.

Everything of interest happens in a banner region roughly the top third of the screen (below the system status bar, above the board), made of **three distinct UI elements** occupying that space side by side / stacked:

1. A compact card, top-left, containing a **2-column × 3-row grid of small square badge icons**, each with its own progress readout, with a **vertical 3-dot page indicator** on its left edge.
2. A **fixed card cluster**, top-right: a "NEW!" gold pass-offer card (`0/5` progress bar, `+15`/`+3600` reward preview) beside a round dish/medal icon showing a live real-time countdown.
3. A **horizontally auto-scrolling row of larger character cards**, below/overlapping (1) and (2), spanning the full screen width and continuing past both edges (cards are visibly cut off left and right at any given instant).

Below all of this, the board itself carries no task strip, order rail, or any other UI at all — it is bare merge-item art on an idle board.

---

## 2. Detailed findings, by element

### 2.1 — Left widget: vertically-paged badge grid

A single rounded card holds six small square icons in a fixed 2×3 layout. In the portion of the paging cycle this pass captured (page 1, roughly the first ~12s), the six badges were:

| Position | Icon | Readout |
|---|---|---|
| Top-left | Gold trophy | A number that climbs over the clip: `33` (t=0.0s) → `37` (t=2.0s) → `38` (t=3–4s) → `39` (t=5s) → `40` (t≈10s), plus a `1d 16h` timer |
| Top-mid | Potion bottle | `03:59:31` (t=0s) → `03:59:16` (t=10s) — a real-time countdown |
| Top-right | Orange starfish | `7/12`, a green fraction bar, unchanged throughout |
| Bottom-left | Red "NEW" 3-star pass card | `1` over a blue progress bar, `16h 29m` |
| Bottom-mid | Chest/checklist | `0/3`, `16h 29m` |
| Bottom-right | Brown palm-frond medal | A blank maroon progress bar, `13h 59m` |

A **vertical** 3-dot indicator (confirmed by native-resolution crop at `0,470,100,120` — the dots are stacked top-to-bottom, not side-by-side) sits on the card's left edge. It read top-dot-lit at t=0s and t≈12s, and bottom-dot-lit by t≈16s — the card does advance through (at least) 3 pages over the clip, but this pass only directly captured page 1's contents; pages 2 and 3 were not sampled at a timestamp where they were legible. `Capture_Catalogue.md`'s original triage pass lists two badges not seen on page 1 here (a tiki-mask event reading `900` / `2d16h`, and a second medal reading `6d16h`), which is consistent with — but not confirmed as — content on the un-sampled pages.

**No swipe, tap, or other touch input was visible on this widget at any point in the clip.** The page change (if it is one) happens without visible user interaction — consistent with the "auto-rotating" framing in the existing catalogue entry, not a user-driven scroll.

### 2.2 — Fixed top-right cluster

The "NEW!" gold pass card (`0/5` progress) and the round dish/medal icon beside it are stable in position throughout. The dish icon's countdown ticks in real time, second-for-second: `16:29:13` (t=0s) → `16:29:11` (t=2s) → `16:29:10` (t=3s) → `16:29:09` (t=4s) → `16:29:08` (t=5–6s) → `16:29:04` (t≈10s). This reads as a literal H:MM:SS countdown to some deadline, not an animated flourish.

### 2.3 — Horizontal card carousel

This is the richest and most ambiguous element, and the one closest to what could plausibly be read as "quests arrayed along a horizontal axis." At t=0–2s it shows a single compact card (a red dragon icon, a folded-fabric icon, a safety-pin icon, `+15` lightning / `+3600` coin, a `15` medal count, and its own countdown — `29m 25s` at t=1s → `29m 16s` at t=10s, again a real-time countdown). From t≈3s onward, the same horizontal band instead shows **full-size character cards**, several visible at once and clearly different from one second to the next:

- t=3s: a man in a headband (`+20`/`+850`, comb icon, medal `12`) · a blond man with a moustache (`+3750`/`+240`/`+13000`, origami-crane icon, medal `65`) · a dark-haired man (`+650`/`+45`/`+1`, panda-mug icon, medal `12`)
- t=4s: a trophy card labelled `38`/`1d 16h` · a blonde woman in a bandana (`+2280`/`+150`/`+7750`, coffee-cup icon, medal `40`) · a mascot figure with a live `16:29:xx` countdown
- t=5–6s: a woman in a patriotic hat (`+1080`/`+70`/`+3700`, knight-figurine icon, medal `20`) alongside the same trophy/bandana-woman/mascot trio shifting position

At least **six distinct named characters** were observed cycling through this band across roughly 6 seconds of sampling, each carrying: a portrait, one or two currency-reward amounts (a tinted potion/ticket icon plus a coin icon), one item-icon reward, and an escalating "medal" count (12, 20, 40, 65 observed). One item icon (a red dress) carried a small shopping-cart badge, suggesting it may be shop-linked rather than a pure reward — not confirmed further in this pass.

Cards are visibly cropped at both screen edges at every sampled instant, confirming the row is wider than the viewport and is scrolling. **As with §2.1, no touch or swipe was visible anywhere in the clip** — the cards advance on their own. Whether this row is *also* user-swipeable (in addition to auto-advancing) cannot be determined from this footage, since no interaction of any kind occurs in the whole 21.2s.

None of these cards show an explicit goal string (no "Collect 5 X" / "Merge to level 4" style text) — only a portrait, reward amounts, one item icon, and a cumulative medal count. This reads closer to a **per-character loyalty/reward rail** than to task cards with a stated objective.

---

## 3. Comparison against the stated description — the actual deliverable

The brief described the expected footage as: *"Quests arrayed along the horizontal scroll axis, and the always present cards (smile/star awards, daily/weekly/monthly goals, parallel board games/challenges) scrolling vertically and accessed via smaller thumbnail icons, often with a small progress bar included in the thumbnail."*

**This does not match what the footage shows, on two levels — one about identity, one about structure.**

**Identity mismatch (the more important one).** This is not the user's own redesign prototype. It is pre-existing, already-catalogued Tasty Travels footage of a passive home screen, filed under `Capture_Catalogue.md` before this session with a description (auto-rotating banner widgets, no board interaction) that this deep dive confirms in full. If the intent was to review a mockup of the *proposed* PawSanctuary redesign, this is very likely the wrong file — worth checking with the user before treating anything below as evidence for or against their design.

**Structural comparison, taken at face value anyway:**

| Described | Observed | Verdict |
|---|---|---|
| A horizontal-scrolling row of **quest** cards | A horizontal, auto-advancing (not confirmed user-swipeable) row of **character/loyalty reward** cards — portrait + reward amounts + one item icon + a medal count, no visible goal text | **Partial match at best.** The axis and card format are right; calling these "quests" overstates what's on screen — nothing here shows a stated objective the way PawSanctuary's `Quest`/`DailyChallenge` cards do. |
| A **vertically-scrolling** element of **smaller thumbnail icons**, "often" carrying an embedded progress bar | A card that **pages** (via a vertical 3-dot indicator, not continuous scroll) through sets of six small square badges, most of which do carry a fraction, bar, or countdown | **Good match on form** (small thumbnails, embedded progress), **imprecise on mechanism** (discrete paging vs. continuous scroll — meaningfully different to implement and to use). |
| The vertical thumbnails represent "smile/star awards, daily/weekly/monthly goals, parallel board games/challenges" | The six captured badges are: a climbing rank/trophy number, a countdown potion, a star-quest fraction, a "NEW" pass card, a checklist fraction, and a medal countdown — **none of them are Smile Points, Care Points, or a Parallel-Board-style event card** in recognisable form | **Mismatch.** The specific content named doesn't appear; what's there instead is closer to a live-ops/event-and-rank tracker set. |
| (implicit) the two axes are part of one integrated **task-tray** UI, analogous to `TaskStripView` | Both axes sit in a **home-screen banner above a completely idle, non-interactive board** — there is no task strip, order rail, or any docked UI visible on the board itself anywhere in the clip | **Mismatch, and the most consequential one.** `TaskStripView`'s actual problem (per `Spec_TravelTownReview_Draft.md` §3) is a horizontal strip that's awkward to drive *while playing*. This footage never shows play at all — it can't speak to that surface. |

**Bottom line:** there's a real, confirmable structural feature in this footage — a compact vertically-paged badge card sitting beside a horizontally-scrolling reward-card row — but it is not a clean match for the description given, and it is not footage of an in-play task strip at all. Treating this clip as validation for the described two-axis `TaskStripView` redesign would be a mistake; at most it's a loose visual precedent for "small paged thumbnails + a scrolling card row," observed on the wrong screen, in the wrong game, doing a different job (live-ops/loyalty promo, not task/order management).

---

## 4. Relationship to `Spec_TravelTownReview_Draft.md` §3's options

§3 of that spec recorded three options for `TaskStripView`'s horizontal-scroll debt, left explicitly undecided: prioritise-by-urgency, collapse-to-summary, or a two-row layout. Given §3 above, this footage doesn't cleanly introduce a *fourth* option for that specific surface, because it isn't a task-strip at all — it's a different screen. If forced into that framing anyway, the closest fit is a **hybrid of collapse-to-summary and two-row**: the vertically-paged badge card *is* a collapsed summary (six always-on trackers folded into one card, paged rather than all visible), sitting in a second row alongside the horizontally-scrolling card. But this is a stretch — applying a home-screen live-ops banner's layout to an in-play task rail is a different design problem (constant board visibility, tap-to-fulfil interactions, per-order urgency) than what's shown here.

---

## 5. Open questions

1. **Is this the right recording at all?** The single most important thing to resolve before any design work. If the user has a different file in mind — one that actually shows a redesigned/prototyped `TaskStripView`, not Tasty Travels' home screen — that recording needs to be located and reviewed instead.
2. **Does the badge-grid card page via swipe, or purely on a timer?** No interaction of any kind occurs in this clip, so this is unresolved. A follow-up recording with an actual swipe on that widget would settle it.
3. **Is the horizontal character carousel user-scrollable, auto-advancing only, or both?** Same gap — nothing in this footage taps or swipes it.
4. **What are pages 2 and 3 of the badge grid?** Only page 1's six badges were captured at a legible timestamp.
5. **What is the horizontal carousel actually for?** The reward pattern (portrait + 2 currencies + 1 item + climbing medal count, no goal text) doesn't map cleanly onto "quests." A longer capture that includes a claim/tap interaction would clarify the mechanic.

## 6. Suggested next step

Confirm with the user whether this is the intended source clip before doing anything else. If it is not, locate and analyse the correct recording using the same `scripts/refvideo.swift` workflow. If it is — despite the mismatches in §3 — treat this spec's §2 as the accurate record of what it shows, and revisit the redesign description against that, since the two-axis idea as originally stated does not appear to be demonstrated here.

## 7. Note on `Capture_Catalogue.md`

This file was already catalogued (see §0) before this session, with an accurate one-line triage description and Deep dive status `—`. Rather than append a duplicate row for the same filename — which would fork the catalogue's single-source-of-truth structure and risk two rows drifting out of sync — this pass updated that existing row's Deep dive column to `done — Spec_TaskStripRedesign_Draft.md`, matching the convention used for every other file in the table. No new row was added.
