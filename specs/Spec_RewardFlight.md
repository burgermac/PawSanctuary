# Spec — Per-currency reward flight

**Written and implemented 9 Oct 2026.** Closes `Spec_TravelTownReview_Draft.md` §2. A Travel Town order completion pays five currencies at once, each leaving the order card on its own arc to its own counter ("the counters are the choreography — nothing is a number that merely changes"). PawSanctuary already paid comparably many things per order but silently. This was a presentation gap, not an economy one.

## 1. Rule

- When an order is **auto-claimed** (the merge that completes it, persistent or urgent), its payout is recorded as a *burst*: the coins, the Dog Tags, and the XP.
- A short stream of sprites per currency leaves the order's card and arcs to that currency's HUD counter: **coins → the coin pill, Dog Tags → the Dog Tag pill, XP → the level badge.** Sprite counts scale with the payout (coins 3–6, Dog Tags up to 4, XP 3) and are capped.
- Each sprite fades in, shrinks slightly and fades out on arrival; a ring pulses at the counter as it lands. Sprites are staggered (0.07 s apart per currency, 0.12 s between currencies) and take 0.55 s.
- Nothing about the reward changes: it is applied at the moment of the claim, exactly as before. The burst is recorded afterwards and removed after 1.8 s.
- **Reduce Motion** skips it.

## 2. How it knows where things are

Both ends are measured, not assumed: the HUD pills and the order cards report their on-screen frames through preference keys (`HUDFrameKey`, `OrderCardFrameKey`), and the overlay converts them to its own space. If the claiming order's card is not laid out — the lane is lazy and may be scrolled — sprites start from the middle of the lane band instead.

## 3. Decisions made while building — flagged for review

1. **Only three currencies fly.** The reference's five include a starfish flying to a progress bar and a bell flying to a milestone ladder. PawSanctuary's equivalents — Smile points, Care Points — live in tray tiles that are usually collapsed, so there is no always-visible counter to fly to. Card packs, board items, materials and event tokens also do not fly. If the tray ever shows its progress bars permanently, those are the next two.
2. **Counters change at once, then the show arrives.** The reference ticks a counter up as the sprites land. Here the balance is already updated when the sprites leave, so a number changes ~0.5 s before its sprite arrives. Delaying the displayed balance would mean a second, display-only copy of each balance; not worth it for a cosmetic.
3. **Orders only.** Quest claims, daily-task claims, the Loyalty claim and the milestone takeover pay the same currencies and do not fly. Orders are the high-frequency one.
4. **Fallback origin.** Because the lane is lazy, the claiming card is often off-screen when the order completes (the merge happened on the board, and the order may be several cards along). In the recorded run the fallback was used, so the sprites rose from the lane's middle rather than from a specific card.

## 4. Verification

`RewardFlightTests` (5): a claim records coins / Dog Tags / XP with the right amounts; the flight does not change what is paid; an order paying only a card pack still flies its XP; the burst clears after the sprites land; sprite counts scale but stay capped. 698/698.

**Seen on the Simulator** by recording a real order completion and pulling frames: at 2.85 s coins and stars stream up from the lane with two Dog Tag sprites already at the tag pill; at 3.05 s coins are entering the coin pill with rings at both pills; at 3.25 s a star reaches the level badge and the coin ring fades. The first build showed rings but **no sprites**, because opacity was read off the state value (already 1 when the animation starts) instead of the animated one — caught only by the recording, since a still screenshot cannot see a 0.5 s flight.

**Not seen:** a flight starting from an on-screen card, the urgent order's claim, Reduce Motion.
