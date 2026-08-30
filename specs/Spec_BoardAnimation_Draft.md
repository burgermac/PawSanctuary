# PawSanctuary — Board Animation (draft)

**Status: §3 Tier A IMPLEMENTED (29 Aug 2026); its §3a-correction cross-row `zIndex` fix (30 Aug 2026) is NOT visually confirmed. §5 (producer shimmer, 30 Aug 2026) IS CI-screenshot-confirmed for its core function (see §5a/§5b) — motion itself unconfirmed.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Assembled at the implementation surface from reference-video review (26 Aug 2026). Companion to `Spec_PartyBoard_Draft.md`, still fully parked.

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

**Correction (30 Aug 2026, still no Simulator to confirm on screen, found by re-reading this code):** the per-cell `.zIndex` above only ever raises a cell over its *same-row* neighbours — SwiftUI scopes `zIndex` to siblings sharing an immediate parent, and each row is its own `HStack`, a sibling of every other row's `HStack` under the outer `VStack`, not of the cells inside them. Working out what that actually leaves broken: upward bleed into the row above already drew correctly even before this fix, for free, since a later-declared row already paints over an earlier one by default source order; rightward bleed into the next column needed the fix and got it, since columns *are* siblings within the row's own `HStack`; but downward bleed into the row below was never fixed — that row's `HStack` paints after the merging row's by default, so its own cell backgrounds would sit on top of, and hide, the overshoot. Fixed by also raising the enclosing per-row `HStack`'s own `zIndex` whenever it holds `animatingCell`. Reasoned from SwiftUI's z-ordering scoping rules, not watched — flagged in `TODO.md` alongside the original still-open on-screen check.

**CI-screenshot attempt (30 Aug 2026) — inconclusive, not a confirmation.** `PawSanctuaryTests/BoardAnimationSnapshotTests.swift` (see §5b for how this tooling works) hosts a mini 2×2 board reproducing this exact structure and screenshots it at four points across the merge's ~1.2s choreography. All four frames came back showing a plain, unscaled grid — no visible scale-overshoot on the animating cell (even at the frame captured while `isAnimating` was still provably `true` per the harness's own timing), no visible white bloom, and no clear sparkle burst beyond a single ambiguous bright pixel-cluster in the earliest frame. That is **not proof the animation is broken** — the leading suspect is a real limitation of this screenshot technique, `UIWindow.drawHierarchy(afterScreenUpdates:)`, for one-shot, `withAnimation`/implicit-animation-driven transitions: it can sample a layer's settled/model value rather than the live, spring-interpolated presentation value a person watching the screen would actually see. That theory is supported, not proven, by contrast with §5b: the shimmer's *continuous* `repeatForever` puffs **did** render visibly and correctly in the same test run using the same capture method, which argues the capture pipeline itself works — the gap is specific to short-lived, one-shot animated transitions like this one. Bottom line: **this piece still needs a human's own eyes on a real Simulator or device** — CI screenshots closed the gap for §5's shimmer but hit a real ceiling here.

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

### 5a. Shipped as §5 (30 Aug 2026) — implemented, CI-screenshot-confirmed (see §5b)

Built in `CellView.swift` (`SpawnerShimmerView`/`SpawnerPuffView`) and `MergeBoardViewModel.swift`, wired through `MergeBoardView.swift`. No schema change.

**Open questions 1–3 resolved before writing code, not guessed:**

1. **Affordability precision (Q1) — strict, including modifiers.** `MergeBoardViewModel` gained `spawnerTapCost(forTier:species:)`, folding in the Bask (Reptiles `.turtle`) half-price rule, and `canAffordSpawnerTap(species:)`, which picks the same clamped tier `activateProducer` uses and compares against `kibbleEngine.kibble`. `activateProducer`'s family-spawner branch was refactored to call `spawnerTapCost` too, instead of duplicating the Bask formula inline — the shimmer's gate and the real tap cost now share one implementation and cannot silently disagree.
2. **Scope (Q2) — family spawners only.** Supply producers already carry their own affordance signal (`.symbolEffect(.pulse)`, a cooldown ring, "Tap!" text); a second signal there would be redundant. `ProducerTileContent.isAffordable` is read only on the `familySpawnerContent` path.
3. **Non-mammal motif (Q3) — one universal tuft, tinted per species.** Matches this section's own recommended option and its own finding that shape is indistinguishable from feather/leaf/bubble at ~6–9pt render size — colour is the channel that reads. No per-family-category shape variants were built.

**What actually got built, and why it deviates from §5's literal spec text:**

- **Shape/asset:** SF Symbol `cloud.fill`, not a bespoke tuft/teardrop asset — cheapest thing that reads as a soft puff at small size, consistent with this project's SF-Symbol-placeholder convention for everything not yet illustrated (see `docs/PawSanctuary_Graphical_Element_Inventory.xlsx`).
- **Colour: white core + tinted `.shadow` glow, not a tinted fill.** §5 says "species `tintColor` at low saturation, or white-blended toward it." A straight tinted/gradient fill at the translucency this calls for blends into real board art (a doghouse's own browns and oranges, a birdhouse's blues) and stops reading as a particle at all. `foregroundColor(.white)` plus `.shadow(color: tint.opacity(0.95), radius: 3)` keeps a bright, legible core with the family colour showing only in the glow — satisfies the "hint of family colour" brief without the contrast failure. This is carried in code as a documented gotcha on `SpawnerPuffView` for future particle work on this cell type.
- **Positioning: `.offset` from the overlay's centre, never `.position(x:,y:)`.** Also documented on `SpawnerPuffView` — `.position` inside a `ZStack` with no other sized content collapses that stack's layout bounds toward zero, silently moving the particle off the tile it's meant to shimmer on. `.offset` doesn't participate in layout, so it can't do that. Every particle view in this file (`MergeSparkleView` included) now uses `.offset` for exactly this reason.
- **Count/lifecycle/motion:** 3 puffs, each 0.5–0.8s, random origin within ±28%/±22% of tile size from centre, 8–14pt upward drift with ±4pt wander, opacity 0.9→0, scale 0.7→1.15 — matches §5's numbers. Driven by `withAnimation(...).repeatForever(autoreverses: false).delay(...)` per puff, per §6's constraint (no `TimelineView`, no per-frame timer on this cell type) — the same `Bool`-driven idiom `MergeSparkleView` (§3a) and the existing `isLeapSource` ring already use in this file.

**Verified, with one real caveat (30 Aug 2026, see §5b for the how).** Implemented in a remote Linux session with no Xcode/Simulator, so a CI-based screenshot pipeline was built specifically to close §5's own "worth an on-screen check early rather than tuning blind" note. Confirmed from real screenshots: (a) the shimmer renders only on the affordable side and not on the unaffordable one — the core gating requirement — with a small doghouse-chimney-smoke detail baked into the base art itself on *both* sides that is not part of this feature and shouldn't be confused for it; (b) it reads as soft white puffs, not a clump or a "shedding" look, satisfying §5's own guard; (c) no visible collision with other decorations in the captured frames. **Not confirmed: actual rising motion.** Two frames captured ~400ms apart show the puffs in near-identical positions — most likely the same screenshot-technique limitation documented in §3a's own CI-screenshot note (a settled/model-value capture rather than a live mid-animation one), not evidence the motion itself is broken, but it means the "cosy drift" specifically is still going on the same must-be-watched-live list as the merge burst.

**Not attempted:** Q4 (spawn-flight arc/trail) and Q5 (Tier B sequencing, reconfirmed deferred to `BoardStateManager` Phase D) — both explicitly out of scope for this pass.

**Gating condition:** `kibbleEngine.kibble >= currentSpawnCost`. Both already exist — `currentSpawnCost` is a computed property on the view model (`MergeBoardViewModel.swift:589`) implementing the Task 2.1 `2^tier` rule. Note it explicitly *excludes* per-family modifiers such as Bask which are applied at the tap site, so a strict affordability check may need the same modifier applied here to avoid shimmering on a tile the player can't actually afford (or staying dark on one they can). **Flagged as an open question, not decided.**

### 5b. How it was actually verified — a CI screenshot pipeline, built for this

No Simulator existed anywhere in this session, so rather than ship §5a unverified, the verification step itself got built: `PawSanctuaryTests/BoardAnimationSnapshotTests.swift` hosts the real production views (`CellView`, `ProducerTileContent`) in a live `UIWindow`/`UIHostingController` and screenshots them, and `.github/workflows/tests.yml` pulls the images out and makes them retrievable. This took several real iterations, each one a genuine wrong guess corrected by the next run's own evidence, worth recording since the next person to need a CI screenshot from this project can skip straight to what worked:

1. **Pulling `FileManager.default.temporaryDirectory` out of the Simulator's app-container sandbox** via `simctl get_app_container <udid> <bundle-id> data` — failed twice. `xcodebuild test` doesn't leave its simulator booted afterward (every device shows `Shutdown`), and scanning every UDID on the runner for one with the app installed found nothing either, root cause never pinned down.
2. **Sniffing the `.xcresult` bundle's `Data/` directory by hand for raw PNG blobs** (content-addressed blob storage, the layout older Xcode versions used) — also came up empty, most likely because this project's Xcode version (`objectVersion 77`) no longer lays attachments out that way.
3. **`xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`, no `--test-id` filter at all** — this is what actually works. It exports every attachment across the whole bundle in one call, skipping tests with none, and writes a `manifest.json` mapping each export's random UUID filename back to the `XCTAttachment.name` set in code.
4. **A separate, real gotcha inside the test code itself:** `XCTAttachment(image: UIImage)`'s on-disk encoding isn't documented to be PNG, which matters if anything downstream (as in step 2/3 above) is sniffing for that specifically — switched to `XCTAttachment(data: pngData, uniformTypeIdentifier: "public.png")`, built from `image.pngData()` explicitly, so what's stored is guaranteed.
5. **Getting the PNGs out of this session's own reach**, separately from making CI produce them: this session's outbound proxy denies `*.blob.core.windows.net` by policy, which is where `actions/upload-artifact`'s content actually lives — a real, non-workaroundable block, not a bug. Fixed by also force-pushing the same PNGs to a `ci-snapshots/latest` branch (`contents: write` had to be granted explicitly — the repo's default `GITHUB_TOKEN` is read-only), readable back through the ordinary GitHub API instead.
6. **The first real screenshots that came back were entirely blank white** — a `UIWindow(frame:)` with no `windowScene` attached never gets composited on iOS 13+, so `drawHierarchy` had nothing to draw. Fixed by grabbing the host app's own foreground-active `UIWindowScene` (the test bundle is `TEST_HOST`-hosted inside the real running app, so one always exists) and using `UIWindow(windowScene:)`.

Once all six were fixed, real content came back — see §5a's own verdict above and §3a's CI-screenshot note for what it did and didn't manage to confirm.

## 6. Implementation constraint — do not use a per-cell timer

This is load-bearing and would be easy to get wrong.

`CellView.swift:351-361` (line numbers as of the §3a Tier A commit, which added ~65 lines above this point — was `:273-283` when this section was first written) records a deliberate past decision: family spawners are **not** wrapped in a `TimelineView` the way `supplyProducerContent` is, explicitly because "family spawners are the most common producer on the board, so giving every one of them a standing per-second timer... would reintroduce a smaller version of the exact per-second cost this change removes." An earlier approach of mutating the whole board array every second to force redraws was already removed for the same reason.

A shimmer built on `TimelineView(.animation)` — which drives a redraw every frame, far worse than every second — would directly reverse that decision on the exact cell type it was made for. Tier A's own sparkle burst (§3a) deliberately avoided this same trap for a different reason — see its note on why a delayed `Task` mutating `@State` was dropped in favour of plain array replacement.

**Build it on `.repeatForever` SwiftUI animations with staggered delays instead.** Those are handed to Core Animation and run without re-evaluating the view body per frame. `familySpawnerContent` already uses this class of effect: the fallback symbol path carries `.symbolEffect(.pulse, options: .repeating, isActive: true)` (`CellView.swift:382`) — though note that path only runs when art is *missing*, so today a spawner with real art has **no idle animation at all**. The shimmer would fill exactly that gap.

Also note the shimmer must coexist with the existing golden `speedBurstActive` glow ring (`CellView.swift:387`) and the three stacked buff badges (bolt/star/eye, `CellView.swift:403-433`) without visual collision.

## 7. Open questions

1. ~~**Affordability precision**~~ — **Resolved, see §5a.** Strict: the true per-tap cost including per-family modifiers, via a shared `spawnerTapCost(forTier:species:)` helper `activateProducer` now also calls.
2. ~~**Does the shimmer extend to other producer types**~~ — **Resolved, see §5a.** Family spawners only.
3. ~~**Non-mammal motif**~~ — **Resolved, see §5a.** One universal tuft, tinted per species — matches this section's own recommended option.
4. **Spawn-flight animation** — adopt the reference's fly-from-producer-to-cell arc with a trail? PawSanctuary currently places spawned items directly. Not specified above; would need its own pass. Still open.
5. **Merge Tier B sequencing** — confirm the recommendation to defer phases 1–2 until `BoardStateManager` Phase D, rather than building a parallel animation-state mechanism first. Reconfirmed at §5a's implementation pass; still deferred.

## 8. Suggested next step

**§3 Tier A is done (see §3a); its cross-row `zIndex` correction is not visually confirmed. §5 is done and CI-screenshot-confirmed for its core function (see §5a/§5b).** The one piece an actual human still needs to watch live: the merge burst's choreography and the shimmer's rising motion — a CI screenshot pipeline (§5b) closed most of the gap but hit a real ceiling on these two specifically, both one-shot/continuous animated transitions that a `drawHierarchy`-based capture likely can't see mid-flight. That's a five-minute Simulator check (merge two items in the bottom board row; watch one spawner tile with kibble above its cost), not new work. Beyond that, remaining open items are Q4 (spawn-flight arc) — a self-contained follow-on, not blocking — and `Spec_PartyBoard_Draft.md`, still fully parked pending more reference footage, unrelated to this spec's own progress.
