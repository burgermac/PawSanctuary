# PawSanctuary — Travel Town review (draft)

**Status: draft, no code written yet.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Fourth in the reference-review series, after `Spec_PartyBoard_Draft.md`, `Spec_BoardAnimation_Draft.md`, and `Spec_OrdersAndTasks_Draft.md` (now closed).

## 0. Source material

`ScreenRecording_08-22-2026 21-30-06_1.MP4` — **Travel Town**. Analysed with `scripts/refvideo.swift`: contact-sheet triage, then targeted crops on the order strip, the left-hand track column, and a milestone claim.

Mostly this recording **confirms** work already shipped rather than surfacing new gaps: Travel Town independently runs the same per-order-token-plus-milestone-ladder split as Smile Points/Care Points (`Spec_OrdersAndTasks_Draft.md` §2/§4) — three of three reference titles now converge on that shape. Four genuinely new deltas were found; none implemented yet.

---

## 1. Confirms — the per-order-token + milestone-ladder split

Travel Town orders pay a per-order token that banks toward a longer milestone ladder, structurally the same split PawSanctuary now ships as Smile Points (per-order value, resetting bar, board-item payout) and Care Points (task-completion feeding a separate weekly ladder). No action needed here — recorded as independent validation that the shape shipped 27 Aug 2026 was the right one to build, not a PawSanctuary-specific invention.

## 2. Finding — orders pay five currencies at once, each with its own flight animation

A completed order in this recording pays out **coins, two distinct event-token types, a starfish token, and a milestone "bell" token** simultaneously — sometimes also a toolbox. Each currency gets its **own flight path** from the order card to its **own counter** in the top bar; five separate arcs on a single claim, not one lump-sum payout with a single icon.

PawSanctuary's order claims currently animate as a single reward burst. This folds naturally into `Spec_BoardAnimation_Draft.md`'s Tier A work (additive, no `BoardStateManager` Phase D dependency) as one more per-currency flight-path case rather than a separate feature — flagged here so it isn't lost, not proposed as standalone scope.

## 3. Finding — flagged as real UX debt, not a hunch: task-strip navigability

Travel Town keeps its live tracks in a **permanently visible vertical column on the left edge** of the board — always in view, no scrolling required to check progress on any of them.

PawSanctuary's `TaskStripView` is a **horizontal scroll** and now carries **15+ cards** (quests, daily challenges, weekly/monthly goals, Care Points, Smile Points, event tracks, Pass progress, and more layered in across this session's own work). This is not a speculative concern — it produced **direct first-hand friction while verifying Care Points and Smile Points earlier this session**: the swipe overshot and the wrong sheet opened, twice, while just trying to check on newly-shipped features.

**No fix chosen yet.** Options on the table, none evaluated against each other:

- Reprioritize — surface only the 3–4 most time-sensitive cards, push the rest behind a "more" affordance.
- Collapse-to-summary — a compact single-row summary card that expands to the full strip on tap.
- Two-row layout — trade horizontal scroll depth for a fixed grid, at the cost of vertical space.

This is a design decision, not an implementation task — raise with design authority before picking one.

## 4. Finding — the milestone ladder is a longer-horizon arc with a full-screen celebration

Travel Town's milestone ladder runs to **tens of thousands of points** — a far longer horizon than either Care Points (Bronze 120 / Silver 320 / Gold 520, weekly) or Smile Points (60, sub-daily). Reaching a new rung triggers a **full-screen "NEW MILESTONE!" takeover** that interrupts and darkens the board before returning play.

That's the same celebration grammar Tasty Travels uses for its own "Smile" banner (`Spec_OrdersAndTasks_Draft.md` §2, step 6) — **two of the three reference titles now interrupt the board** for a milestone claim. PawSanctuary's Care Points claim currently has **zero ceremony** — no banner, no board interrupt, just a bar filling and a reward grant.

Worth weighing against Care Points' own claim flow: does a weekly Bronze/Silver/Gold claim warrant a full-screen takeover, or is that overkill for a bar that resets every week rather than running to a five-figure lifetime total? Not resolved here — the two ladders may deserve different weights of ceremony given their different horizons.

## 5. Finding — a speech-bubble nudge from the customer as an order nears completion

As an order approaches completion, the customer's portrait shows an **"Almost there!"**-style speech bubble — a cheap, ambient nudge that doesn't require opening the order card to notice progress.

`AdoptionFamily` already carries names and portraits (used elsewhere for order-card identity), so this has somewhere to hang without new content. Cheap, on-theme, not yet built.

---

## 6. Open question — full starfish-bar payout is unobserved

The clip ends with the starfish bar at **11/12** — what a **full** bar actually pays is not visible in this capture. That's the direct analogue of Smile Points' bundle size, which was derived from the economy model alone (`Spec_OrdersAndTasks_Draft.md` §2a) rather than from a measured reference value. Worth specifically targeting if more Travel Town footage is captured — a measured comparison point for whether Smile Points' modelled bundle size is in the right range.

## 7. Suggested next step

§5 (customer nudge) is the most self-contained: no schema change, no economy exposure, hangs off data that already exists. §2 (reward-flight animation) is not standalone — fold it into `Spec_BoardAnimation_Draft.md`'s Tier A scope when that spec is picked up. §3 (task-strip redesign) needs a design decision before any code — raise the three options above with design authority rather than picking one unilaterally. §4 (milestone ceremony) is a smaller design call riding on the same question.
