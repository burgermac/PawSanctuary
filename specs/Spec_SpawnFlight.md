# Spec — Spawn flight

**Written and implemented 9 Oct 2026.** Closes `Spec_BoardAnimation_Draft.md` §7 open question 4 ("adopt the reference's fly-from-producer-to-cell arc?"). The behaviour was measured on two titles: Gossip Harbor (with "a bright magenta comet trail", §4) and Travel Town's parallel board (`Spec_ParallelBoardReview_Draft.md` §3.3: the new item appears at the generator, then **arcs across the board over intervening cells to its destination in ~80–120 ms**, landing as the hint bar updates). PawSanctuary placed spawned items directly in their cell.

## 1. Rule

- A family spawner tap that places an item records a **flight** from the spawner to the cell the item landed in. The item is already in board state — nothing about spawning, cost, XP, orders or persistence changes.
- The view draws the item arcing along a parabola from the spawner's cell to the destination over `spawnFlightDuration` = **0.11 s**, with two fainter copies lagging behind it as a short comet trail. The arc peaks a quarter of the trip high, capped at 0.9 of a cell.
- The destination cell **hides its item** while the flight is in the air, so there is no duplicate.
- The existing landing pop and sparkle burst (`animatingCell`) **start on arrival**, not at the tap.
- A free bonus spawn (Lucky / Legendary) flies from the same spawner, so a boosted tap shows two arcs.
- **Reduce Motion** skips it: the item simply appears, as before.

## 2. Decisions made while building — flagged for review

1. **Family spawners only.** Legacy rescue producers, order-bundle scatters, chest items and anything else placed through other paths still appear directly. The measured behaviour is a generator tap; the other paths have no producer to fly from, and the Smile bundle scatter (`Spec_OrdersAndTasks_Draft.md` §3) is a different, longer animation that was deliberately not built here.
2. **Trail colour is the item's own tint.** Still unresolved against the reference: Gossip Harbor's was a strong magenta, Travel Town's was too faint or too fast to resolve at 0.04 s sampling. Using the item's tint avoids picking a colour the evidence does not support.
3. **0.11 s, the middle of the measured range.** Slow enough to read as an arc, fast enough not to delay the next tap. Tapping again during a flight is fine: the item is already placed.
4. **Hidden-then-landing rather than a ghost placeholder.** The destination shows its empty tile for 0.11 s. A faint placeholder would read as the item being in two places.

## 3. Tests and verification

`SpawnFlightTests` (4): a tap records a flight from the spawner to the item's cell; the pop waits for the arc and the flight clears; a placement with no producer records none; the duration sits in the measured range. 693/693.

**Seen on the Simulator** by recording a spawner tap and pulling frames: at 2.02 s the item is mid-arc above the straight line with two ghost copies trailing; by 2.05 s it has landed with the pop sparkle. The video is not committed.

**Not seen:** the bonus-spawn double arc, Reduce Motion (both by construction), or the look on a real device at 120 Hz.

## 4. Still open

Flights for the other placement paths; the trail colour; and the reverse-direction collect stream the Parallel Board review noted for its energy items.
