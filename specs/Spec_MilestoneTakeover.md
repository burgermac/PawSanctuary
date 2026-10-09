# Spec — Milestone takeover

**Written 9 Oct 2026.** Closes `Spec_TravelTownReview_Draft.md` §4's second bullet: Travel Town and Tasty Travels both interrupt the board with a full-screen celebration when a milestone is crossed (Travel Town's "NEW MILESTONE!": dark overlay, the ladder with the crossed node ticked, one hero reward on a radiating glow). PawSanctuary's Care Points ladder pays Dog Tags, XP and a card pack with no ceremony at all.

## 1. Scope

**Care Points tiers only** (Bronze / Silver / Gold, weekly). They are the one ladder that is both a true milestone ladder and rare enough to interrupt for: three crossings a week at most.

Deliberately **not** covered, each for a reason:

- **Kibble Drive rungs.** Fifteen rungs in three days; a takeover per rung would be exactly the interruption D9 warns against. The Drive's own sheet and red dot already carry it. If it is ever wanted, only rungs 10 and 15 (the pack rungs) are candidates.
- **Smile bundles.** Several a day for an active player at higher levels.
- **Weekly / monthly goal tiers.** Claimed from their own panels; no crossing moment.

## 2. Behaviour

- When a Care Points award takes the weekly total across an unclaimed tier's threshold, a takeover appears immediately: dimmed board, **"NEW MILESTONE!"**, the three-tier ladder with crossed tiers ticked and the new one glowing, the tier's reward as the hero line, and two buttons — **Claim** and **Later**.
- **Claim** claims every claimable tier up to the one shown, then closes. **Later**, or a tap on the dimmed board, closes it; the tiers stay claimable in the Care Points panel exactly as before.
- If one award crosses several tiers, the **highest** is shown (one takeover, not a queue).
- A new crossing while one is already showing raises it to the higher tier; it never stacks.
- A success haptic plays on appearance.

## 3. Decisions made while writing this — flagged for review

1. **Claim on the takeover, rather than auto-granting.** Care Points are claimed manually today (`claimCarePointTier`); the takeover reuses that and changes no reward path. Travel Town grants on crossing. Auto-granting here would move the faucet's timing and bypass the claim chokepoint the Drive and tests key off, for a cosmetic gain.
2. **Not persisted.** The pending celebration is ephemeral. If the app closes before it is seen, the tier is simply still claimable in the panel. No schema change.
3. **"One hero item" is a line, not an icon.** Care Points pays three things (tags, XP, sometimes a pack), so the hero is the tier's crest with its reward line beneath, not a single item.
4. **No auto-dismiss.** It waits for a tap, because it carries a Claim button.

## 4. Tests

Crossing a threshold raises the takeover; staying under, or crossing an already-claimed tier, does not; a multi-tier jump shows the highest; a later crossing raises rather than stacks; Claim pays every claimable tier up to the one shown and clears it; Later leaves tiers claimable; a weekly reset or fresh game clears it.

## 5. Status

**Implemented 9 Oct 2026.** `MilestoneTakeoverView.swift` (new), `MergeBoardViewModel.swift` (`pendingMilestone`, `raiseMilestoneIfCrossed`, `dismissMilestone`, `claimMilestone`; hooked into `awardCarePoints`; cleared on fresh game and at the weekly reset), `MergeBoardView.swift` (the overlay), `MilestoneTakeoverTests.swift` (9). No schema change.

Seen on the Simulator with 115 Care Points and a finished Easy quest: claiming the quest raised the takeover (Bronze crest, three-node ladder, "5 Dog Tags · 40 XP", Claim / Later) and Claim took Dog Tags 9 → 14 and closed it.

**Not seen:** the Silver and Gold crests, a multi-tier jump, and Later. The first and last are unit-tested; the ladder's lower nodes show a check only when a higher tier is on screen. The board shows through the dim at 62%, so the ladder row overlaps busy tiles; legible, not elegant.

**A note on how I verified it.** Seeding a finished order produced a "Placing..." state rather than a claim: orders auto-claim at the merge that completes them, so a hand-edited save skips the real trigger. The quest claim path is real.
