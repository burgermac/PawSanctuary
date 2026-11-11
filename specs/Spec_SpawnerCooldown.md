# Spec — Family spawner cooldown

**Decided 9 Oct 2026 (Tim).** Closes the "generator cooldown" question left open by `Feature_Parity_Audit.md` §2 and `Gap_Analysis_Round2.md` 3.10. My first recommendation was *no cooldown* (kibble already throttles family spawners, so a second throttle is retention-negative under D9); Tim overruled it on the grounds that the reference games run a cooldown on their main generators, far less often than the legacy supply producers do. This spec records the rule as decided and the choices made implementing it.

## 1. Rule

- Each **family spawner** counts the kibble it has spent. When that count reaches **150**, the spawner goes on a **30-second cooldown** and the count carries over (`spent -= 150`, not reset to 0, so costly ×8 taps are not rounded in the player's favour or against them).
- The counter is **per spawner**, not shared. Another spawner keeps working while one cools.
- While cooling, tapping the spawner offers a **skip for 2 Dog Tags**.
- Free bonus spawns (cost 0) add nothing to the counter.

Constants, all in `AnimalSpecies.swift` with the other tuning numbers: `familySpawnerCooldownKibble = 150`, `familySpawnerCooldownSeconds = 30`, `familySpawnerCooldownSkipDogTags = 2`.

## 2. Why these numbers sit where they do

- **Kibble regenerates at 1 per 120 s, caps at 100–150, and a new game starts with 20.** 150 kibble is about 5 hours of regen. The cooldown therefore only bites when a player is spending stockpiled or purchased kibble (an ad, a Drive rung, an exchange) in one sitting — exactly the moment the reference's cooldown is aimed at — and almost never on the regen trickle.
- **Per-spawner makes the cooldown a soft speed bump.** A player with several spawners rotates to another. That is deliberate: it keeps the friction light (D9) and makes the skip a convenience rather than a toll.
- **The skip price (2 tags) is a tuning guess, not a measurement.** Dog Tags exchange at 15 tags per 100 kibble on the first rung, so 2 tags is a small fraction of the 150 kibble that triggered the wait. Revisit once there is play data.

## 3. Decisions made while implementing — flagged for review

1. **No schema bump.** `ProducerTile` already owns a hand-written `Codable` that decodes older shapes locally (its own doc comment: "No GameStore schema version bump needed"). The new `kibbleSpentSinceCooldown` field is decoded with `decodeIfPresent`, defaulting to 0, so every older save still loads. `CLAUDE.md` rule 4 says a persisted-shape change needs a bump; this follows the type's established precedent instead and adds a `PersistenceTests` case. If you want a bump anyway, it is a one-line change plus a migration helper.
2. **The skip is gated on `isMonetizationUnlocked` (D7).** A Dog Tag spend prompt is a monetization surface, so it does not appear in session one. Before that gate opens the cooldown simply runs its 30 seconds. The cooldown itself is not gated: at 20 starting kibble it cannot realistically trigger in session one.
3. **Skip prompt is an alert, not an inline button.** A board cell is ~50 pt; there is no room for a labelled button on it. Tapping a cooling spawner raises "Skip the wait?" with the price. With too few tags the alert says what is needed and offers only OK.
4. **The skip counts as a Dog Tag spend** through `updateAllAfterSpend`, exactly as the Free Chest skip does, so spend-quota goals and the Kibble Drive see it consistently.
5. **The shimmer is hidden while cooling.** `SpawnerShimmerView` advertises "tap me". A one-off board refresh is scheduled for the moment the cooldown ends so the shimmer returns without waiting for the next unrelated board change. After an app relaunch that refresh is not re-scheduled, so a cooldown that expires while the app is closed can leave the shimmer off until the next board change; accepted as cosmetic.

## 4. Out of scope

- The legacy rescue producers and the shop supply boxes keep their existing 25–60 s per-tap cooldowns and charges, unchanged.
- No new "long-cooldown premium generator" class. Noted in the parity audit as a possible later content decision.
- No `EconomySimulation` change. The cooldown limits *when* kibble is spent in a burst, not how much is earned or spent per day.

## 5. Tests

`SpawnerCooldownTests.swift`: the threshold triggers a 30 s cooldown; the remainder carries over; spawners are independent; a free bonus spawn adds nothing; skip charges 2 tags and clears the wait; skip refuses with too few tags; skip is gated by monetization; `PersistenceTests` covers a tile saved before the field existed and a round trip with it set.

## 6. Verification

Seen on the Simulator 9 Oct 2026 (iPhone 17 Pro, iOS 26.5), with one spawner seeded at 149 kibble spent so a single tap crossed the threshold:

- The tap spawned one animal (kibble 681 → 680) and the spawner dimmed with a countdown ("29s").
- Tapping it while cooling raised "Skip the wait?" with the right text and "Skip for 2 Dog Tags" / "Wait".
- Skipping took Dog Tags 7 → 5 and the spawner returned to normal, selected.

**Not seen:** the shimmer returning after a cooldown simply runs out (needs a 30-second wait on a spawner with kibble to spare — the scheduled refresh is logic I did not watch fire), the too-few-tags alert variant (unit-tested only), and the pre-monetization silent path (unit-tested only). The progress ring around the countdown is drawn but hard to make out at the dimmed tile size; the number carries the meaning.

## 7. Status

**Implemented 9 Oct 2026.** `AnimalSpecies.swift` (constants, `ProducerTile.kibbleSpentSinceCooldown`, `recordKibbleSpent`), `MergeBoardViewModel.swift` (cooldown check, spend recording, skip, refresh), `CellView.swift` (`SpawnerCooldownOverlay`), `MergeBoardView.swift` (the alert), `SpawnerCooldownTests.swift` (12 tests). No schema change. 658/658 green.
