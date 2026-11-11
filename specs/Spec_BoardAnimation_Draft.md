# PawSanctuary — Board Animation (draft)

**Status: §3 Tier A IMPLEMENTED (29 Aug 2026) and CI-screenshot-confirmed, including its §3a-correction cross-row `zIndex` fix's underlying burst/bloom mechanism (30 Aug 2026, after one false-negative run — see §3a). §5 (producer shimmer, 30 Aug 2026) was CI-screenshot-confirmed for its core function (see §5a/§5b), then **retimed 11 Sep 2026 against measured reference motion and confirmed moving on screen (see §5c)** — the earlier 0.5–0.8s and 2.6–3.6s timings were one structural bug at two speeds, and §5c also corrects §4's own reading of the reference's drift direction and lifetimes. A suspected real-device OOM traced to the shimmer's rendering was mitigated same-day, not yet retested (see §5a).** **§3 Tier B (merge phases 1–2): un-parked 10 Nov 2026; planned 11 Nov 2026 as a numbered task list in §8; task 8.1 (record the merge, no visible change) done 11 Nov 2026 at `c618995`; 8.2–8.7 not started.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Assembled at the implementation surface from reference-video review (26 Aug 2026). Companion to `Spec_PartyBoard_Draft.md`, still fully parked.

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

**CI-screenshot verification (30 Aug 2026) — confirmed, after one false negative.** `PawSanctuaryTests/BoardAnimationSnapshotTests.swift` (see §5b) hosts a mini 2×2 board reproducing this exact structure and screenshots it at four points across the merge's ~1.2s choreography. The *first* real-content run (`8a093b0`) came back showing a plain, unscaled grid with no visible burst at all, and this doc originally recorded that as a likely `drawHierarchy`-can't-capture-one-shot-animations limitation. **That theory turned out to be wrong.** Two later runs — `8f08f72` (a doc-only commit, no code changed) and `438fe97` — both show the burst clearly: `merge_burst_1_peak_overshoot` has the item visibly scaled up with 3–4 gold sparkle stars and a soft white halo; `merge_burst_2_mid_drift` shows the item back at resting size with two faint sparkles drifted well outside the grid and fading. Since no test or product code differed between the miss and the two hits, the real explanation is CI-runner timing variance against this test's fixed millisecond offsets (see §5b), not a capture-technique ceiling or a product bug — credit to a second Claude session also watching this PR for catching the contradiction and re-checking rather than letting the first (wrong) conclusion stand. **Not independently confirmed by these frames:** whether the overshoot specifically bleeds across the row boundary the `zIndex` correction targets — the scale-up in the captured frames reads as moderate at this test's 100pt cell size, not obviously breaching into the row below, though nothing in the frames contradicts the fix either. That one detail is still worth a direct look if convenient, but is no longer blocking.

**Not attempted:** Tier B (phases 1–2, the pre-merge slide/implode) — per this section's own recommendation, still deferred to `BoardStateManager` Phase D. (10 Nov 2026: Phase D was complete on 15 Aug, `3b060ea`; see §7 Q5. 11 Nov 2026: planned as §8.)

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

**Real-device OOM found and mitigated (30 Aug 2026).** A ~35-minute live play session on a real iPhone (not the Simulator) ended with the OS killing the app for excess memory (`IDEDebugSessionErrorDomain` code 11, "Terminated due to memory issue") — all memory-diagnostic sanitizers off, so not tooling overhead. Leading suspect: `SpawnerPuffView` stacked `.blur(radius: 0.5)` *and* `.shadow(color:radius:)`, both of which force an offscreen render pass, on a `.repeatForever` animation that runs continuously and simultaneously on every affordable family-spawner tile for as long as the app is open — on a board where kibble sits idle (routine, since it regenerates passively) several tiles can be affordable at once, each running 3 puffs through two expensive offscreen passes apiece, non-stop. That is a plausible source of steady memory growth over exactly the kind of timescale observed. `.blur(radius: 0.5)` was barely visible at this render size anyway and redundant with `.shadow`'s own softening, so it was removed as a low-risk first mitigation; `.shadow` was kept since it's load-bearing for the whole white-core-plus-glow legibility fix (§5a). **Not fully proven** — no on-device Instruments profiling was possible from this session — so this needs the same real-device retest as the rest of this spec's open items, watching specifically for whether memory still climbs over an extended session.

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

### 5c. Retimed against measured reference motion (11 Sep 2026) — §5a's timing was wrong twice

Shipped in `CellView.swift` only (`SpawnerPuff`, new `ShimmerCycle`, `SpawnerShimmerView`, `SpawnerPuffView`). No schema change, no view-model change, no new tuning constants outside the file — these are particle geometry, not game tuning.

**Raised from play, not from the spec:** the shimmer "lacks smoothness and often appears as if no movement is taking place at all, even though sufficient kibble exists." That is a third distinct verdict on this effect's timing. §5a shipped 0.5–0.8s; that read as *flashing*, and was retimed to 2.6–3.6s with `autoreverses: true`; that reads as *static*. Both retunes moved one number by feel. This pass measured the reference instead.

**Method — particle tracks recovered from the recording, not read off it.** The tile art is static, so a per-pixel temporal-minimum plate over a frame run is the tile *without* its particles; subtracting it isolates the shimmer. Connected components above a threshold were then centroided with **excess luminance as the weight** (a plain pixel count conflates "brighter" with "bigger", which is exactly the pair that needed separating), and linked frame to frame into tracks. Frames the capture repeated verbatim were dropped first — the source recording stalls, and a stalled span reads as a particle hovering. Scripts are throwaway, in the session scratchpad, but the method is the reusable part and `scripts/refvideo.swift crop` does the extraction.

Sampled two producer tiles in `ScreenRecording_08-08-2026 17-38-42_1.MP4` (the coffee pot at source rect `1000,1580,180,180` and the grocery bag at `1007,1910,165,165`), every frame, cell pitch 162px.

**Two findings correct §4, which was written by eye:**

1. **The motes rise.** §4 records the stars drifting "a **short distance** (mostly down-left in the sample)", and §5 then proposed upward drift as a deliberate *departure* from the reference ("unlike the reference's downward-left"). Measured, **12 of 13 travelling tracks move up** — every one with `dy` negative and `dx` near zero. PawSanctuary's rising motes were already right; the spec's reason for them was wrong. Nothing in the code changes on this point, but the next person reading §4 would have been misled.
2. **Lifetimes are longer than §4's 0.3–0.5s.** Travelling motes live **0.4–1.9s**; a second population lives 0.3–1.2s. §4 undersold this, which is part of how 0.5–0.8s got shipped in the first place.

**And one finding §4 missed entirely: there are two particle classes, not one.** Alongside the four-pointed stars §4 describes, producer tiles carry **soft round glows** that travel much further — the clearest single example rises 48px (0.30 cell heights) up the coffee pot's body over ~0.66s, brightening then fading. Initially suspected to be baked-in steam, which §5a's own doghouse-chimney note warns about; ruled out by zooming the path at native resolution, where it is plainly a discrete round mote crossing the art rather than a plume. **Not built** — PawSanctuary has one class, and adding a second is a design change, not a retime. Recorded here as the next thing to consider if this effect is revisited.

**The measured envelope, and what PawSanctuary was doing against it:**

| | reference (measured) | shipped §5a (2.6–3.6s) | now |
|---|---|---|---|
| travel | 0.13–0.45 cell heights | 0.23–0.35 | 0.26–0.39 |
| speed | 0.10–0.49 cell/s, clustered ~0.22 | **0.06–0.14** | 0.16–0.32 |
| brightness peaks at | 0.41–1.00 of life | **0.0 — at rest, by construction** | 0.45–0.96 of life |

Travel distance was never the problem. **Speed was two to three times below anything in the reference**, and the brightness row is the real defect.

**The defect was structural, not a number.** Travel and opacity both hung off one `risen` flag, so opacity was pinned to position: full 0.9 at the resting origin, fully transparent at the far end of the travel. Under `easeInOut` a mote is slowest at both endpoints — so the only part of the cycle the eye could see was the part where the mote was barely moving, and the travel happened while it was faded out. No duration would have fixed that; at 0.5–0.8s the same coupling reads as a flash, at 2.6–3.6s as a light pulsing in place. Both prior verdicts were the same bug at two speeds.

**The fix: two animations, one period.** Position runs `.linear` and one-way, so the mote is never not moving and never changes speed. Brightness and scale run a separate half-period `autoreverses` cycle peaking at mid-life, where the reference's own motes peak. The two share a period, so opacity is exactly 0 at the instant position sawtooths back to its origin — which is what makes a one-way loop seamless. §5a reached for `autoreverses: true` on the *travel* to kill that seam; it does, at the cost of making the mote hover at both ends. Still `.repeatForever` throughout, so §6's no-per-frame-timer constraint holds — `KeyframeAnimator` would have expressed the bell directly but re-evaluates its closure every frame on every affordable spawner, which is the cost §6 exists to prevent.

**A second, separate defect found only by measuring the running app.** The first build phased the three motes at thirds *of their own* random 1.1–1.7s durations. That staggers them at t=0 and then lets the periods beat against each other: a screen recording of the running app showed a **0.6s window with the tile almost empty**, which is the original complaint surviving the fix. Motes now share one period per tile — randomised per tile, so neighbouring spawners don't pulse in lockstep — with phases at exact thirds and no jitter. Each mote is at half brightness or better for half the period, centred on its midpoint, so three at exact thirds cover the period with overlap to spare. This is now a property of the construction rather than something that happens to look right.

**Verified on screen, measured rather than eyeballed.** iPhone 17 Pro Simulator (iOS 26.5), Debug build, the real save's dog family spawner at row 2 col 0 with 105 kibble (affordable). The Simulator screen was **recorded to video and run through the same tracker as the reference**, so both sides are in identical units — a filmstrip alone would not have caught the phase-beating gap, and the two prior verdicts on this effect were both eyeball calls. Longest window with the tile visually quiet: **0.19s before, 0.00s after**; share of frames quiet **15% → 0%**, against the reference tile's own 0%. Note the 0.19s is conservative — the visibility floor counts a barely-visible ghost as lit, so the gap actually visible was longer than that number suggests. Filmstrips at 0.083s steps across the previously-dead window show a clearly moving mote in every frame. 585/585 tests green.

**Not addressed here:** the real-device OOM (`TODO.md`) is untouched — `.shadow` on a `repeatForever` animation still forces an offscreen pass per frame per mote, and this pass adds a second animation per mote without removing that. If the OOM retest still climbs, replacing `.shadow` with a `RadialGradient` circle is the obvious next move and would change the look, so it belongs with that investigation rather than here.

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
4. ~~**Spawn-flight animation** — adopt the reference's fly-from-producer-to-cell arc with a trail? PawSanctuary currently places spawned items directly. Not specified above; would need its own pass. Still open.~~ **Resolved 9 Oct 2026: shipped** as `Spec_SpawnFlight.md` (`SpawnFlightView.swift`, commit `d94169b`, PR #47). Corrected 10 Nov 2026.
5. **Merge Tier B sequencing** — confirm the recommendation to defer phases 1–2 until `BoardStateManager` Phase D, rather than building a parallel animation-state mechanism first. Reconfirmed at §5a's implementation pass; still deferred. **Update 10 Nov 2026: the precondition is met and was met before this spec was written.** Phase D finished 15 Aug 2026 (`3b060ea`; `BoardStateManager_Phase_D_Plan.md` status line; `attemptMergeOrMove` now computes a `MergeResult`, `MergeResult.swift`). The owner un-parked Tier B on 10 Nov 2026. **Update 11 Nov 2026: turned into a numbered task list — see §8 (tasks 8.1–8.7 in §8d, out-of-scope list §8e, owner questions §8f). Nothing built yet.**

## 8. Tier B — implementation plan (merge phases 1–2)

**Status: In progress. 8.1 done (11 Nov 2026, `c618995`): `MergeImplosion` record, `mergeImplosions` list and the four constants landed exactly as §8c proposes, with the five `MergeImplosionTests`; no visible change, schema still v44, full suite green (793 tests). §8a's code claims re-checked at `62f02ee` and still accurate. Next: 8.2.** Written 11 Nov 2026 from a read of the code at `b900435` (origin/main). Docs only; no Swift changed. Each task below is one session, one commit, per `CLAUDE.md` rule 1, and leaves the game playable.

**Goal, restated from §1/§3.** When two items merge, show phases 1–2 of the reference: the two source items sit side by side in the destination cell, slide together (~0.06s), then shrink toward a point at ~25% scale (~0.06–0.12s). Only then does the existing Tier A burst (§3a) fire on the new item. Total pre-burst window: ~0.15s. The model does not wait. Board state is written at once, exactly as today. The view keeps drawing the two sources for ~0.15s after the model has moved on.

### 8a. What the code gives Tier B today

**`MergeResult` (`PawSanctuary/MergeResult.swift:27–64`)** is the dispatch enum. Only one case is a merge:

- `.merge(MergeOutcome)` (`MergeResult.swift:42`). The other cases (`producerUpgrade`, `producerSwap`, `producerMove`, `producerBlocked`, `superpowerPieceSpent`, `itemSwap`, `itemMove`) are not Tier B's business (see §8e).

**`MergeOutcome` (`PawSanctuary/MergeOutcome.swift:40–59`)** carries:

| Field | Line | Useful to Tier B? |
|---|---|---|
| `from: GridPosition` | :41 | **Yes**: the source cell. |
| `to: GridPosition` | :42 | **Yes**: the destination cell, where the result lands. |
| `resultChainID`, `resultTier` | :43–44 | The result item, which is already on the board. |
| `mergedSpecies`, `scoreDelta`, `xpDelta`, `isTopTierCompletion`, `isBubbleEligible` | :48–58 | No. |

**What it does not carry:**

1. **The two source items.** For a normal merge both are `(resultChainID, resultTier − 1)` in practice. That is not true for a wildcard merge: one source is the wildcard, a different chain and tier (`MergeOutcome.swift:79–90`). To render the sources faithfully, Tier B needs the real `BoardItem`s.
2. **Any on-screen geometry.** Positions are grid cells only. There is no drop point and no drag offset. This is fine; see §8c.
3. **The merge's final fate.** `applyMergeOutcome` can still bubble the result, move it to Supplies (power-up or completed sub-object routing), or swap in a superpower piece, all after the board write (`MergeBoardViewModel.swift:2288–2358`). `MergeOutcome` is decided before any of that.
4. **A return value to the caller.** `attemptMergeOrMove` (`MergeBoardViewModel.swift:2154–2196`) returns `Void`. It computes and applies internally (`apply(.merge(outcome))` at :2185). The view cannot see the result.

**Where the source items are available:** `attemptMergeOrMove` has `srcItem` and `dstItem` in scope (:2168, :2171). Inside `applyMergeOutcome` (:2272), the board is still pre-merge until the write at :2280, so `boardState.item(at: outcome.from)` and `boardState.item(at: outcome.to)` both return the sources there. The Nine Lives snapshot already captures there for the same reason (:2277–2278).

**Schema: unaffected.** `GameStore.currentVersion` is `44` (`GameStore.swift:388`). `animatingCell` (`MergeBoardViewModel.swift:165`) and `spawnFlights` (:1594) are plain view-model properties. Neither is in `GameState`, and the new state below follows the same pattern. Nothing in §8 touches a persisted shape, so no migration and no `PersistenceTests` case.

**The precedent to copy: spawn flight (PR #47, `d94169b`).** It solves the same problem: the item is already in board state, but the view must pretend otherwise for a moment. Its parts:

- `SpawnFlight` record and `spawnFlights: [SpawnFlight]` list (`MergeBoardViewModel.swift:1585–1594`).
- `finishSpawn` writes the board, appends the record, then schedules a `Task` that removes it after `spawnFlightDuration` and only then calls `popCell` (:1598–1620).
- `popCell` is the shared 600ms Tier A pulse (:1622–1629).
- The view hides the landed item with `isFlightLanding` → `opacity(0)` (`CellView.swift:120`; wired at `MergeBoardView.swift:913–914`). The view draws the motion in `SpawnFlightOverlay`, an overlay on the grid before padding (`MergeBoardView.swift:1002–1005`; `SpawnFlightView.swift`). Both are gated on `reduceMotion`.
- Tested in `PawSanctuaryTests/SpawnFlightTests.swift` with an `await Task.sleep` pattern.

Tier B is the same shape with a different overlay. Building it any other way would be the "parallel mechanism" §3 warned against.

### 8b. Where this spec disagrees with the code

1. **§2's line numbers are stale.** `CellView.swift:110` → the `scaleEffect(isAnimating ? 1.5 : 1.0)` is now at `CellView.swift:178–179`. `MergeBoardViewModel.swift:1423` → the merge's 600ms pulse is now at `MergeBoardViewModel.swift:2360–2364`, inside `applyMergeOutcome`. Spawns and passive tiles use `popCell` (:1622–1629) and `placeFreeTile` (:3078–3090).
2. **§3's Tier B paragraph names the wrong function.** It says "`attemptMergeOrMove` mutates board state and then sets `animatingCell`." Since Phase D, `attemptMergeOrMove` is pure dispatch (:2154–2196). The board write and the `animatingCell` set both happen in `applyMergeOutcome` (:2272–2366), reached through `apply(_:)` (:2209). The point §3 was making still holds: the sources are gone from the model before any animation runs.
3. **§3 expected Phase D to "return a structured result describing what merged and from where."** It half does. `MergeOutcome` describes *where* (from/to) and *what resulted*, but not the source items, and nothing returns it to the view (§8a items 1 and 4). So "Tier B becomes cheap" holds, with one extra step: capture the sources at apply time.
4. **Not in the spec at all: the drop is animated.** `MergeBoardView.swift:986–988` wraps `attemptMergeOrMove` in `withAnimation(.spring(response: 0.3, dampingFraction: 0.6))`. Every state change from a drag-merge therefore runs inside a spring transaction. Tier B has to opt out of that in two places (task 8.4); otherwise the hidden result fades out over ~0.3s instead of vanishing, and the overlay fades in instead of appearing.
5. **`BoardStateManager_Phase_D_Plan.md` §3.4 undercounts `animatingCell` writers.** It says three (producer upgrade, `applyMergeOutcome`, `placeFreeTile`). Today there are six assignment sites: `popCell` :1624, a supply-producer charge at :1808, `.producerUpgrade` :2214, `applyMergeOutcome` :2360, `placeFreeTile` :3083, and the family-unlock spawner placement at :3929. Same single-slot clobbering, more writers. Recorded here, not fixed (§8e).
6. **Minor, code only:** the doc comment at `MergeBoardViewModel.swift:1578–1581` ("Places a freshly-resolved spawn item…") belongs to `finishSpawn` but sits above `struct SpawnFlight`, because PR #47 inserted the struct between them. Cosmetic. Worth moving while task 8.1 is editing next to it, if the implementer is there anyway.
7. **Adjacent observation, not a disagreement:** the drag ghost always renders the SF Symbol, never the item's art (`MergeBoardView.swift:921–935`), while `CellView` and `SpawnFlightSprite` both prefer `artImage`. When the overlay below starts drawing art-based sources at release, the hand-off from ghost to source sprite will show a change of picture for items that have art. Out of scope for Tier B (§8e). Flagged because it will be visible in the Simulator check.

### 8c. Design

**A transient record, appended at apply time.** Proposed shape, in `MergeBoardViewModel.swift` beside `SpawnFlight`:

```swift
/// Merge phases 1–2 (Spec_BoardAnimation_Draft.md §8): the two source items,
/// already gone from board state, still drawn sliding together and imploding
/// in `to` until `mergeImplosionDuration` passes. Session-only, never persisted.
struct MergeImplosion: Identifiable, Equatable {
    let id = UUID()
    let from: GridPosition      // where the dragged source came from
    let to: GridPosition        // where both converge and the result lands
    let sourceItem: BoardItem   // the dragged item (may be a wildcard)
    let targetItem: BoardItem   // the item it was dropped on
}
var mergeImplosions: [MergeImplosion] = []
```

- **A list, not one slot**, for the same reason as `spawnFlights`: two quick merges in different cells overlap.
- **Captured in `applyMergeOutcome`, not threaded through `MergeOutcome`/`MergeResult`.** Read both cells at the top, beside the existing `preMergeBoard` capture (:2277), before the write at :2280. `MergeOutcome` stays the pure, `Equatable` decision type its 19 tests pin. Source items are rendering data, not merge-decision data, the same reasoning Phase D §3.3 used to keep the Nine Lives snapshot out of it.
- **Only `.merge` records one.** Swaps, moves, producer upgrades and superpower spends do not (§8e).
- **Removed by a `Task` after `mergeImplosionDuration`**, which then fires the Tier A pop. This is the `finishSpawn` pattern verbatim (:1612–1616).

**Where the sources start (no drop point needed).** Reference phase 1 has both items already co-located in the destination cell, side by side, before they slide together. That is where the player's finger released anyway: the drop rounds to the nearest cell (`MergeBoardView.swift:978–985`). So the overlay derives the start position from grid cells alone:

- The source sprite starts in `to`, offset toward `from` by `cellSize * 0.22`. That is the same magnitude `mergeHintOffset` already uses to nudge a mergeable pair together (`MergeBoardView.swift:863`), so the gesture reads as a continuation of a motion the game already shows.
- The target sprite starts at `to`'s own centre, so the item the player dropped onto does not jump on release.

Both converge to `to`'s centre. Whether the target should also slide is an owner feel question (§8f Q2). The record stays in grid units, like `SpawnFlight`, and the view model needs no `CGSize`.

**One animation per sprite, no timers.** Each source sprite runs a single `withAnimation(.linear(duration: mergeImplosionDuration)) { progress = 1 }` in `.onAppear`. A small `Animatable` view modifier then maps `progress` piecewise: slide over the first `mergeSlideDuration / mergeImplosionDuration` of the run, then scale `1 → mergeImplodeMinScale` and fade over the rest. This mirrors `SpawnArcEffect` (`SpawnFlightView.swift:86–104`). Per §6: no `TimelineView` and no per-frame timer. Nothing runs when no merge is in flight.

**Hiding the result.** `CellView` gains an `isMergeImploding: Bool = false` parameter. It ORs into the existing `isFlightLanding ? 0 : …` opacity at `CellView.swift:120`, and that opacity change must be non-animated (`.animation(nil, value:)` or a transaction override; see §8b item 4). Otherwise the drop's spring transaction fades the result out instead of hiding it, and it shows through the implosion. The overlay's sprites likewise need `.transition(.identity)`, or the same spring fades them in.

**Proposed new tuning constants** (bottom of `AnimalSpecies.swift`, next to `spawnFlightDuration` at :2255). These are proposals from §1's measured phase durations, for the owner to confirm (§8f Q1):

```swift
/// Merge phase 1 (Spec_BoardAnimation_Draft.md §1, §8): the two sources slide together.
let mergeSlideDuration = 0.06
/// Merge phase 2: both shrink toward a point. Reference measured 0.06–0.12s.
let mergeImplodeDuration = 0.09
/// The whole pre-burst window; the Tier A pop fires when it ends.
let mergeImplosionDuration = mergeSlideDuration + mergeImplodeDuration   // 0.15
/// Scale the sources shrink to at the tightest frame (reference: ~25%).
let mergeImplodeMinScale = 0.25
```

The 0.22-cell start offset is view geometry, not game tuning. It stays in the view file, following §5c's precedent for particle geometry.

**Effect on the whole merge.** Today the burst starts on release. With Tier B it starts 0.15s later, so the choreography runs ~0.15s + Tier A's ~0.9s of sparkle life. That is ≈1.05s, inside §1's measured 1.0–1.1s. Nothing about Tier A changes: `CellView`'s `.onChange(of: isAnimating)` (:132–141) fires the bloom and sparkles whenever `animatingCell` lands, regardless of when.

**Input during the animation.** The model is authoritative; the animation yields.

- *The source cell (`from`).* Empty in the model straight after the merge, so a drag starting there does nothing (`attemptMergeOrMove`'s `guard let srcItem` at :2168). A passive power may legitimately place a tile there (`placeFreeTile` picks from `emptyUnlockedCells`; Aquatics Current slides into `emptyPos == from`, :3092–3125). It renders normally, with the source sprite leaving over it. No rule needed.
- *The destination cell (`to`).* Holds the hidden result. If a new `attemptMergeOrMove` names a cell that an in-flight implosion targets, as either `from` or `to`, that implosion is **settled** first: removed from `mergeImplosions`, with its delayed pop cancelled. The new action then proceeds normally. Two cases this covers: dragging another matching item onto a result still imploding (a rapid chain merge), and dragging the hidden result away. In both, the earlier overlay vanishes and the board shows truth. The delayed `Task` must check that its record is still in the list before it pops, so a settled implosion never fires a stray burst. This is task 8.2.
- *Rapid merges in different cells.* Each gets its own record and overlay; they do not interact. Their Tier A pops still share the single `animatingCell`, which is the §3.4 quirk, below.
- *Taps on `to` during the window* (select, sell panel): harmless. They act on the real, hidden result. Not settled; 0.15s is shorter than a deliberate second tap.
- *Other board writers at `to` during the window* (send-to-Supplies drag, Nine Lives undo, bubble pop): not settled. The overlay finishes its remaining ≤0.15s over whatever the cell now holds, then the pop fires there. Purely cosmetic, and this is the same exposure spawn flight already accepts. Settling those too is listed in §8e.

**Interaction with the Phase D §3.4 `animatingCell` quirk (left unfixed by choice).** Today, on a merge that triggers a passive power, `applyPassivePowers` → `placeFreeTile` sets `animatingCell = P` (the free tile) and schedules a clear at +0.6s. In the same run-loop pass, `applyMergeOutcome` overwrites it with `animatingCell = to` and schedules its own clear. Tile P never visibly pops, and both clears land at about +0.6s.

Tier B defers only the merge's own pop, to +0.15s. Consequences:

1. **Tile P now visibly pops for 0.15s**, and because Tier A's sparkles outlive `isAnimating` (§3a), it gets its full sparkle burst. Arguably that is what `placeFreeTile` always meant to do.
2. **At +0.15s the merge pop overwrites P's**, so the merge cell gets its overshoot and burst as intended.
3. **At +0.6s, P's clear sets `animatingCell = nil`**, ending the merge cell's `isAnimating` after 0.45s instead of 0.6s. The spring (`response: 0.3`) has passed its overshoot peak by then, so the visible cost is an earlier spring-back. The burst sparkles are unaffected, because they run on their own clock.
4. **At +0.75s the merge's own clear fires.** Usually a no-op. It can cut short an unrelated pop that started in between, as rapid merges already can today.

No data or gameplay impact; the same cosmetic class §3.4 already accepted. **Tier B does not fix it and must not paper over it**, for example by special-casing the clear. A generation counter or `Set<GridPosition>` remains the real fix, as a separate owner decision. Task 8.3's tests pin only the merge's own pop timing on a board with no passive powers unlocked, so they do not encode the quirk as intended behaviour.

**Reduce Motion.** Follow the spawn-flight precedent exactly:

- The view passes `reduceMotion ? [] : viewModel.mergeImplosions` to the overlay, and gates `isMergeImploding` on `!reduceMotion`. With Reduce Motion on, no sources are drawn and the result is visible immediately.
- The view model does not know about Reduce Motion, so the Tier A pop still waits 0.15s. Spawn flight already does the same: its pop waits `spawnFlightDuration` with no flight drawn.
- Note Tier A itself is not gated on Reduce Motion today (`CellView` has no `reduceMotion`). Changing that is out of scope here (§8e); see §8f Q4.

**Memory and performance on device.** The shimmer OOM suspect (§5a, `TODO.md`) is offscreen passes from `.blur`/`.shadow` on always-running animations. Tier B is the opposite profile:

- Two sprites per merge, alive for 0.15s, then gone.
- Offset, scale and opacity only. **No `.blur`, no `.shadow`, no `.mask`, no `.compositingGroup`.** This is a hard rule for tasks 8.4 and 8.6.
- Art comes from the existing cached `artImage` (`ArtImageCacheTests` covers the cache), so no new image loads.
- The record holds two `BoardItem` values and a UUID, and is removed on a timer, so the list is bounded by merge rate × 0.15s.

The reference's phase 2 glow halo is the one part that would naturally reach for blur. It is split out as optional task 8.6, built from a `RadialGradient` fill, which costs no offscreen pass.

**Testability split.**

| Can be unit-tested in the view model (XCTest, no UI) | Needs a Simulator look (or CI frames, with §3a's timing caveat) |
|---|---|
| A merge appends exactly one `MergeImplosion` with the right `from`/`to`/source items, including a wildcard source | The sources read as side by side, then slide, then implode, at 0.15s total |
| Non-merge outcomes append none | No flash of the result before the burst (the spring-transaction gotcha, §8b item 4) |
| The record clears after `mergeImplosionDuration` | The burst lands where the implosion converged, with no visual seam |
| `animatingCell` stays `nil` until the implosion ends, then equals `to` | Reduce Motion on: no overlay, result visible at once |
| Settling: a second action on `to` removes the first record, and its pop never fires | Rapid chain merge on the same cell looks clean |
| Unrelated merges do not settle each other | Feel: the timing and offset questions in §8f |
| Constants sit inside the measured reference range | Long-session memory (part of the existing device retest, not new) |

### 8d. Task list

Each task is one commit and one session (`CLAUDE.md` rule 1), and keeps the game playable (rule 2). The universal **DoD for every task**:

- The `PawSanctuary` scheme builds with zero new warnings.
- The full test suite is green, with no existing test changed in meaning.
- `GameStore.currentVersion` is still 44, and no `GameState` field is added.
- This section's status line is updated to name the task done, with its commit.

Task-specific DoD below adds to that.

**8.1 — `MergeImplosion` record, no visual change.**

- Add the `MergeImplosion` struct and the `mergeImplosions` list (§8c), plus the four constants at the bottom of `AnimalSpecies.swift`.
- In `applyMergeOutcome`, read both source items before the write at :2280, append a record, and schedule its removal after `mergeImplosionDuration`.
- Leave the existing immediate `animatingCell = outcome.to` pulse exactly as it is. Nothing reads the list yet, so nothing on screen changes.
- Optionally move the misplaced `finishSpawn` doc comment (§8b item 6).

*New tests,* `PawSanctuaryTests/MergeImplosionTests.swift`, built on `SpawnFlightTests`' fixture pattern (an empty unlocked grid assigned to `vm.board`, no `loadGame()`):

- `testAMergeRecordsAnImplosionWithBothSourceItems`
- `testTheImplosionClearsAfterItsDuration` (async)
- `testSwapsMovesAndProducerActionsRecordNoImplosion`
- `testAWildcardMergeRecordsTheWildcardAsItsSource`
- `testTheImplosionTimingsSitInsideTheMeasuredReferenceRange`, which asserts `0.04 ≤ mergeSlideDuration ≤ 0.08` and `0.06 ≤ mergeImplodeDuration ≤ 0.12`, mirroring `testTheFlightDurationMatchesTheMeasuredReferenceRange`.

*Also check:* all 26 `AttemptMergeOrMoveCharacterizationTests` and all `MergeOutcomeTests`/`MergeResultTests` pass unchanged.

**8.2 — Settle-on-input rule, no visual change.**

- At the top of `attemptMergeOrMove`, after its guard at :2155–2158, remove any `MergeImplosion` whose `to` equals the new `from` or `to`.
- In 8.1's removal `Task`, nothing pops yet. Ensure the removal is by `id` and is a no-op if the record is already gone.

*New tests,* in `MergeImplosionTests.swift`:

- `testASecondMergeOntoAnImplodingCellSettlesTheFirst`
- `testMovingTheResultAwaySettlesItsImplosion`
- `testAnUnrelatedMergeLeavesAnInFlightImplosionAlone`

**8.3 — Defer the Tier A pop until the implosion ends.**

- In `applyMergeOutcome`, replace the inline pulse (:2360–2364) with the `finishSpawn` pattern. When the removal `Task` fires, if the record is still present, remove it and call `popCell(outcome.to)`. If it was settled, do nothing.
- Keep `preMoveSnapshot`'s assignment as the literal last statement (Phase D §3.3). It is not deferred.
- Visible change: the existing burst starts 0.15s after release. No overlay yet; the result is visible throughout, so the game reads as before with a barely perceptible beat.

*New tests:*

- `testTheMergePopWaitsForTheImplosion`: `animatingCell` is `nil` straight after the merge and equals `to` after `mergeImplosionDuration` + slack. Use a board with no superpowers unlocked, so the §3.4 quirk does not enter.
- `testASettledImplosionNeverFiresItsPop`.

*DoD addition:* re-read §8c's §3.4 interaction note against the final code, and correct it if the timeline differs.

**8.4 — The visible Tier B: overlay plus hidden result.**

- New file `PawSanctuary/MergeImplosionView.swift` holding `MergeImplosionOverlay` and its sprite. Shape it like `SpawnFlightOverlay`: positioned in the grid's own coordinate space, `.allowsHitTesting(false)`, `.accessibilityHidden(true)`, sprites with `.transition(.identity)`.
- Render the item with the same art-or-symbol logic as `SpawnFlightSprite.sprite`. Prefer extracting that into one shared `BoardItemSprite` view, internal, in `SpawnFlightView.swift`, over copying it.
- Mount it in `boardGridView` as a second `.overlay(alignment: .topLeading)` beside `SpawnFlightOverlay` (`MergeBoardView.swift:1002–1005`), gated on `reduceMotion`.
- Add `CellView.isMergeImploding`, non-animated (§8c), wired as `!reduceMotion && viewModel.mergeImplosions.contains { $0.to == pos }`.
- No `.blur`/`.shadow`/`.mask` anywhere in the new file.

*Tests:* if the start-offset maths is pulled into a pure function, for example `mergeImplosionStartOffset(from:to:cellSize:) -> CGSize`, add `testTheSourceStartsInTheTargetCellOffsetTowardItsOrigin`. Otherwise nothing new is unit-testable here.

*DoD addition, required:* a Simulator check, iPhone 17 Pro, Debug. Screen-record a drag-merge and step through it frame by frame, as in §5c. Confirm:

- (a) both sources visible in `to` at release, then converging, then shrinking;
- (b) no frame shows the result before the burst;
- (c) the burst starts where they converged;
- (d) Reduce Motion on → no overlay, result shown at once;
- (e) a rapid second merge onto the same cell is clean;
- (f) a merge in the top and bottom rows and the edge columns is not clipped.

Record what was seen in this section.

**8.5 — CI frames for Tier B.** Optional but cheap, since the pipeline exists (§5b).

- Extend `BoardAnimationSnapshotTests` with a `MergeImplosionHarness` and `testMergeImplosionSlideAndCollapse`.
- Capture frames at about +30ms (side by side), +100ms (mid-implode) and +200ms (burst begun).
- Expect the same CI timing variance §3a hit with fixed millisecond offsets. One run that misses a phase is not evidence of a bug; it took three runs to confirm Tier A.

*DoD addition:* frames retrieved from `ci-snapshots/latest`, and the verdict recorded here, including any misses.

**8.6 — Phase 2 halo.** Only if the owner says yes (§8f Q5).

- A soft glow disc behind the converging sources, growing as they shrink and handing off to Tier A's white bloom.
- Built as a `Circle().fill(RadialGradient(...))` animated on scale and opacity only. **No `.blur`, no `.shadow`.**
- Colour per §8f Q5.

*DoD addition:* a Simulator look, plus a short Instruments Allocations pass over ~50 merges, confirming no growth that persists after the merges stop. Device retest piggybacks on the existing OOM retest in `TODO.md`.

**8.7 — Close-out.**

- Update this spec's top status header and §3/§3a to say Tier B shipped, with commits.
- Strike §8b items 1–2 by correcting §2 and §3's text in place.
- Add the on-screen-check record from 8.4, and from 8.5 if run.
- Add `TODO.md` lines for anything left unverified on a real device. That task may edit `TODO.md`; this planning PR does not.

*DoD:* docs only, suite still green.

### 8e. Out of scope for Tier B

- **Fixing the Phase D §3.4 `animatingCell` single-slot quirk.** No `Set<GridPosition>`, no generation counter, no special-casing of the clears. §8c describes the interaction; fixing it is its own owner decision.
- **Any change to `MergeOutcome`, `computeMergeOutcome`, `MergeResult` or `apply(_:)`'s dispatch**, beyond `applyMergeOutcome`'s own body.
- **Tier B for other outcomes:** `.producerUpgrade` (two producers merging also pulses today, :2214), `.superpowerPieceSpent`, swaps and moves.
- **The Parallel Board.** `ParallelBoardCoordinator.attemptMerge` (`ParallelBoardCoordinator.swift:95`) and `ParallelBoardView` have their own merge and drag path. Tier B there is a follow-on, if wanted.
- **The drag ghost's SF-Symbol-only rendering** (§8b item 7).
- **Moving merge sound, haptic, score toast or top-tier celebration timing** to the burst. They fire at release today (:2282–2289). Owner question §8f Q3; unchanged unless answered.
- **§1's other supporting details:** selection brackets glowing during the burst, and the selected-item idle pulse.
- **Gating Tier A itself on Reduce Motion.**
- **Settling implosions on non-merge board writes at `to`** (send-to-Supplies, Nine Lives undo, bubble pop, board reload). These are cosmetic and ≤0.15s.
- **Any persisted-state change.** Schema stays v44.
- **The shimmer OOM investigation and §5c's second particle class.**

### 8f. Open questions for the owner

1. **Timings.** Is 0.06s slide + 0.09s implode = 0.15s right, with the burst therefore starting 0.15s after release? §1 measured phase 2 at 0.06–0.12s; 0.09s is its middle. Is a 25% minimum scale right? These are guesses until seen; 8.4's Simulator check is the place to tune them.
2. **Does the target item slide too, or only the source?** The plan has only the source slide (from a 0.22-cell offset), so the item the player dropped onto never jumps. The reference shows both moving. The alternative splits the offset ±0.11 cell between them.
3. **Merge sound and haptic: at release, or at the burst?** Today they fire at release. Release keeps drop feedback instant; moving them makes the "pop" land with the visual. The same question applies to the top-tier Ambassador celebration starting while the sources are still imploding.
4. **Reduce Motion.** The plan follows spawn flight: no overlay, but the pop still waits 0.15s. Acceptable, or should the pop fire immediately when Reduce Motion is on? That would need the view model to read `UIAccessibility.isReduceMotionEnabled`. Separately, should Tier A's own overshoot and sparkles respect Reduce Motion? (Out of scope here either way.)
5. **Build the phase 2 halo (task 8.6)?** If yes: the reference's cyan/teal, or the merged species' `tintColor`, matching how §5 handled the shimmer?
6. **Source start position.** The plan uses a fixed in-cell offset, not the finger's actual release point. Using the real drop point would mean the view handing `attemptMergeOrMove` a visual offset, which leaks view geometry into the view model. Fixed offset unless the owner wants it.

## 9. Suggested next step

**§8 (Tier B): 8.1 done; next is task 8.2 (settle-on-input rule, no visible change).** Earlier status, kept for the record:

**§3 Tier A is done and CI-screenshot-confirmed (see §3a). §5 is done and CI-screenshot-confirmed for its core function (see §5a/§5b).** The CI screenshot pipeline (§5b) ended up closing the loop on both — the merge burst's one false-negative run was CI-timing flakiness, not a real gap, corrected once a later run (and a second Claude session's catch) showed it working. Two narrower things are still worth five minutes of a human's own eyes when convenient, not blocking: whether the overshoot visibly bleeds across the row boundary specifically (the frames captured read as a moderate scale-up, not an obvious cross-row breach, though nothing contradicts the fix), and whether the shimmer's puffs visibly rise over time (two frames 400ms apart looked near-identical). Also outstanding: a real-device OOM hit during a long play session on this branch, mitigated same-day (removed a redundant `.blur()` on the shimmer) but not yet retested — see §5a. Beyond that, remaining open items are Q4 (spawn-flight arc, since shipped 9 Oct 2026, see §7) — a self-contained follow-on, not blocking — and `Spec_PartyBoard_Draft.md`, still fully parked pending more reference footage, unrelated to this spec's own progress.
