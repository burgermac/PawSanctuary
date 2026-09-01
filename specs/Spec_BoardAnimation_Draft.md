# PawSanctuary — Board Animation (draft)

**Status: §3 Tier A IMPLEMENTED (29 Aug 2026). §5 (producer shimmer) still draft — open design questions unresolved.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Assembled at the implementation surface from reference-video review (26 Aug 2026). Companion to `Spec_PartyBoard_Draft.md`, still fully parked.

## 0. Source material

`ScreenRecording_08-08-2026 17-38-42_1.MP4` (18.4s, 1206×2622 @ 59.5fps) — a merge-2 reference title, player level 15. Analysed by extracting frames via AVFoundation at 0.5s for structure, then crop-zoomed at source resolution down to 0.03s steps (every 2nd frame) on the merge and producer moments. Two complete merges and one complete producer-tap→spawn are captured end to end.

Prior related finding: `Spec_PartyBoard_Draft.md` §0 covers the gacha prize board from the 08-01 recording. No reward-reveal animation appears in either recording yet.

---

## 1. Finding — merge animation choreography

The reference runs an identical five-phase sequence for every merge, **~1.0–1.1s end to end**:

| # | Phase | Duration | Detail |
|---|---|---|---|
| 1 | **Slide-together** | ~0.06s | The two source items visually slide into a single cell and briefly overlap side-by-side. They do not cut or teleport — both are on screen, co-located, for a beat. |
| 2 | **Implode** | ~0.06–0.12s | Both shrink and converge to a point (~25% scale at the tightest frame) while a soft cyan/teal glow halo blooms behind them. |
| 3 | **Burst** | ~0.06s | The new higher-tier item explodes outward from that point already glowing white-hot; gold/yellow four-pointed stars pop outward at the same instant. |
| 4 | **Elastic overshoot** | ~0.2–0.3s | The new item scales *past* its resting size — visibly larger than a normal cell item, overlapping neighbouring cells — with a white/cyan bloom washing out its colours, then springs back. |
| 5 | **Star drift & fade** | ~0.5s | 3–5 gold stars drift outward and upward, shrinking and fading. They **outlive the item's own animation by roughly half a second**, so the celebration lingers after the item has settled. |

Two supporting details: the selection brackets themselves glow and pulse during the burst, and the game deliberately lets the merged item breach its grid cell at peak overshoot rather than clipping it.

Separately, a **selected-item idle pulse**: while an item sits selected and idle, it breathes larger and back at roughly 0.5s per cycle.

## 2. What PawSanctuary has today

`CellView.swift:110` — `.scaleEffect(isAnimating ? 1.5 : 1.0)` with `.spring(response: 0.3, dampingFraction: 0.4)`, driven by `MergeBoardViewModel.animatingCell` and cleared after 600ms (e.g. `MergeBoardViewModel.swift:1423`).

That is **phase 4 alone**, and it is already the hardest phase to tune — `dampingFraction: 0.4` gives the same bouncy overshoot character as the reference. What's missing is the framing around it: the convergence before, and the particle life after.

## 3. Proposal — merge animation, in two tiers

**Tier A (additive, cheap, no architectural change).** Phases 3–5 only touch the *new* item and its particles, and the new item already exists in board state by the time `animatingCell` is set:

- Add a burst of 3–5 star/sparkle particles emitted on `isAnimating`, drifting outward-and-up, scaling down, fading over ~0.5s — **outlasting** the 600ms scale animation, per the reference. This needs its own timing independent of `animatingCell`'s 600ms clear.
- Add a brief white/tint bloom on the item at the peak of the overshoot (a `.shadow` or overlay at high opacity decaying fast), matching the reference's white-hot moment.
- Consider raising the merged cell's `zIndex` during animation so the overshoot overlaps neighbours instead of being occluded.

**Tier B (needs decoupling — flagged as real work, not a tweak).** Phases 1–2 are *not* additive under the current architecture. `attemptMergeOrMove` mutates board state and then sets `animatingCell`, so by the time any animation runs, the two source items are already gone from the model. Showing them slide together and implode requires the view to keep rendering the pre-merge state for ~0.15s after the model has moved on — i.e. an explicit animation-state object carrying the source items and their origin positions, not just a `GridPosition?`.

This overlaps the deferred `BoardStateManager` Phase D work (`attemptMergeOrMove` → `MergeResult`, see `BoardStateManager_Phase_D_Plan.md`), which would return a structured result describing what merged and from where. **Recommendation: don't build Tier B standalone.** If Phase D lands, Tier B becomes cheap; doing it first would mean building a parallel mechanism that Phase D then has to reconcile. Tier A stands alone and is worth doing regardless.

### 3a. Shipped as Tier A (29 Aug 2026)

Built to the three bullets above, all in `CellView.swift`, no view-model or schema changes — confirming the "additive, cheap" framing held.

**Sparkle burst.** 3–5 `MergeSparkle` values (gold, `sparkle` SF Symbol) spawn into a `@State` array on `isAnimating` going true, each rendered by its own `MergeSparkleView` that runs a single `withAnimation(.easeOut(duration: 0.9))` drifting outward along a fixed random angle (biased to the upper hemisphere — never downward, per the reference) while shrinking and fading. This deliberately outlives `isAnimating`'s own 600ms clear, matching the reference's stars lingering after the item settles. No cleanup timer: the next merge on that cell just replaces the array, and SwiftUI drops the old (by then fully faded) sparkle views on its own — simpler than tracking burst identity for expiry, and sidesteps firing a delayed `Task` from inside a `View` struct to mutate `@State` (untested territory in this codebase — every existing delayed-`Task`-to-self-mutate pattern lives in `MergeBoardViewModel`, an `@MainActor` class, not a View).

**White-hot bloom.** A `.shadow(color: .white.opacity(mergeBloomOpacity), radius:)` on the item, spiked to 0.85 opacity on trigger and eased back to 0 over 0.22s — the "white-hot" flash from phase 3/4, cheap enough to be a single animated shadow rather than a separate overlay.

**Unclipped overshoot.** The bigger structural change: `CellView.body`'s single `.clipShape(RoundedRectangle(cornerRadius: 12))` covered background *and* content together, so the existing 1.5x scale-up was silently being clipped to the cell's own bounds the whole time — the "breach the grid cell" behaviour this section asks for was never actually possible under the old structure. Split into two clip domains: the rounded-rect background/border stack keeps its own clip, the item/producer/locked content and the new sparkle layer sit in a second, unclipped `ZStack`. Paired with `.zIndex(isAnimating ? 5 : 0)` on the per-cell wrapper in `MergeBoardView.swift`'s grid `ForEach`, so the overshooting cell draws over its neighbours rather than under them. No visual change to any idle cell — nothing in normal content ever reached the tile edge anyway.

**Not attempted:** Tier B (phases 1–2, the pre-merge slide/implode) — per this section's own recommendation, still deferred to `BoardStateManager` Phase D.

---

## 4. Finding — producer affordance shimmer

The single most transferable finding in this recording.

**White four-pointed stars twinkle continuously on producer tiles, and only on producer tiles.** Isolating one producer at 0.04s steps shows the mechanics precisely:

- Each star fades in at a **random point on the tile's art**, drifts a **short distance** (mostly down-left in the sample), scales up then down, and fades out over **~0.3–0.5s**.
- **1–3 stars are alive at once** with staggered, overlapping lifecycles, so the tile shimmers *continuously* rather than blinking on a beat.
- Stars stay **within the tile** — they do not fly off across the board.

In the same frames, adjacent non-producer items (flamingo float, anchor, lifebuoy, coins) carry **zero** sparkle.

**The gating is the point.** Per the project owner's own play knowledge of the reference title, this shimmer only runs **when the player has enough energy to actually activate that producer**. That makes it a pure affordance signal — an at-a-glance scan of what is tappable *right now*, so the player never taps a producer to discover they can't afford it. It is not decoration; it is the energy economy rendered onto the board.

Related, from the same recording (documented here for completeness, no proposal attached): the tap→spawn itself is ~0.15s — brackets briefly vanish as press feedback, the new item pops into existence *at the producer cell*, then **flies in a straight line to its destination cell with a bright magenta comet trail**, passing over occupied tiles as an overlay. The trail's magenta matches the energy badge on producer tiles, which reads as deliberate: the trail is visually "spending energy."

## 5. Proposal — pet-themed shimmer

The brief: keep the affordance function, replace the generic sparkle with something in keeping with PawSanctuary's animal theme. The suggestion on the table is **floating fur**.

**The instinct is good and I'd keep it**, with one correction. Soft, pale, slowly-rising fluff — backlit dust-mote or dandelion-seed feel — reads as warmth, softness and home, which sits squarely on the game's Warmth pillar in a way a generic star does not. It also *earns* its motion: fur drifting up off a warm sleeping-spot is a physically motivated idle, where a star is an arbitrary game-y glint.

**The correction — do not build this as per-family particle art.** Two reasons:

1. **It doesn't generalise.** Of the 15 species (`AnimalSpecies.swift:16-17`), only 8 are furred (dog, cat, rabbit, hamster, guineaPig, fox, ferret, pony). Three are feathered (bird, owl, parrot), two are scaled/shelled (turtle, lizard), one aquatic (fish), one spined (hedgehog). Fur drifting off a Heated Rock or a Decorative Birdhouse is wrong.
2. **It wouldn't read anyway.** These particles render inside a tile whose art is `cellSize * 0.78`, and `cellSize` defaults to 62pt. A particle is realistically 5–9pt. At that size a fur tuft, a feather and a leaf are all "small pale soft blob" — indistinguishable. Fifteen bespoke particle assets would be invisible effort.

**Recommended instead: one universal soft-tuft particle, tinted per species.** `familySpawnerContent` already has `let tint = sp?.tintColor` in hand (`CellView.swift:289`). Colour is the one channel that *does* read at 6pt. That gives each family its own identity in the shimmer — warm ginger drifting off the Antique Dog House, cool blue off the Decorative Birdhouse — with a single shape asset and no per-species art delivery.

Proposed particle spec, matching the reference's timing but softened:

- **Shape:** a soft-edged tuft/fluff (a small blurred teardrop or 3-lobe puff), not a hard-edged star. Translucent — peak opacity ~0.5–0.7, never solid.
- **Count:** 2–3 alive at once, staggered so the tile shimmers continuously.
- **Lifecycle:** ~0.5–0.8s each — fade in, drift, fade out. Slightly slower than the reference's 0.3–0.5s; fur should float, not twinkle.
- **Motion:** slow **upward** drift (rising, unlike the reference's downward-left) with slight horizontal wander, 8–14pt of travel. Scale up then down across the life.
- **Colour:** species `tintColor` at low saturation, or white-blended toward it, so it reads as "warm light with a hint of the family's colour" rather than a coloured blob.
- **Origin:** random point within the tile's art bounds.

**Guard against the failure mode:** fur can read as *shedding/dirty* rather than *cosy*. The difference is entirely in restraint — few particles, pale, translucent, slow, soft-edged, rising. If it ever looks like a clump or a cloud, it has gone wrong. This is worth an on-screen check early rather than tuning blind.

**Gating condition:** `kibbleEngine.kibble >= currentSpawnCost`. Both already exist — `currentSpawnCost` is a computed property on the view model (`MergeBoardViewModel.swift:589`) implementing the Task 2.1 `2^tier` rule. Note it explicitly *excludes* per-family modifiers such as Bask which are applied at the tap site, so a strict affordability check may need the same modifier applied here to avoid shimmering on a tile the player can't actually afford (or staying dark on one they can). **Flagged as an open question, not decided.**

## 6. Implementation constraint — do not use a per-cell timer

This is load-bearing and would be easy to get wrong.

`CellView.swift:351-361` (line numbers as of the §3a Tier A commit, which added ~65 lines above this point — was `:273-283` when this section was first written) records a deliberate past decision: family spawners are **not** wrapped in a `TimelineView` the way `supplyProducerContent` is, explicitly because "family spawners are the most common producer on the board, so giving every one of them a standing per-second timer... would reintroduce a smaller version of the exact per-second cost this change removes." An earlier approach of mutating the whole board array every second to force redraws was already removed for the same reason.

A shimmer built on `TimelineView(.animation)` — which drives a redraw every frame, far worse than every second — would directly reverse that decision on the exact cell type it was made for. Tier A's own sparkle burst (§3a) deliberately avoided this same trap for a different reason — see its note on why a delayed `Task` mutating `@State` was dropped in favour of plain array replacement.

**Build it on `.repeatForever` SwiftUI animations with staggered delays instead.** Those are handed to Core Animation and run without re-evaluating the view body per frame. `familySpawnerContent` already uses this class of effect: the fallback symbol path carries `.symbolEffect(.pulse, options: .repeating, isActive: true)` (`CellView.swift:382`) — though note that path only runs when art is *missing*, so today a spawner with real art has **no idle animation at all**. The shimmer would fill exactly that gap.

Also note the shimmer must coexist with the existing golden `speedBurstActive` glow ring (`CellView.swift:387`) and the three stacked buff badges (bolt/star/eye, `CellView.swift:403-433`) without visual collision.

## 7. Open questions

1. **Affordability precision** — should the shimmer gate on raw `currentSpawnCost`, or on the true per-tap cost including per-family modifiers (Bask etc.) applied at the tap site? The strict version is more honest but requires lifting modifier logic into the cell.
2. **Does the shimmer extend to other producer types** (supply producers, toolbox), or family spawners only? Supply producers are already cooldown-gated with their own ring, so double-signalling may be noise.
3. **Non-mammal motif** — is a single tinted tuft genuinely acceptable for Avians/Reptiles/Aquatics, or do those three warrant one alternate shape each (feather / leaf / bubble)? Three shapes is far cheaper than fifteen and might survive the legibility objection.
4. **Spawn-flight animation** — adopt the reference's fly-from-producer-to-cell arc with a trail? PawSanctuary currently places spawned items directly. Not specified above; would need its own pass.
5. **Merge Tier B sequencing** — confirm the recommendation to defer phases 1–2 until `BoardStateManager` Phase D, rather than building a parallel animation-state mechanism first.

## 8. Suggested next step

**§3 Tier A is done (see §3a).** The §5 shimmer remains the natural next piece — self-contained, but blocked on real design decisions first: §7's open questions 1–3 (affordability precision, which producer types it applies to, and whether non-mammal families need their own motif) all have real tradeoffs and should go through the same `AskUserQuestion` pattern this project uses for decisions like this, not be guessed at implementation time. `Spec_PartyBoard_Draft.md` remains fully parked pending more reference footage, unrelated to this spec's own progress.
