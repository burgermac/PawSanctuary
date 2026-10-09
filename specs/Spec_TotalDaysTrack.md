# Spec — Total Days login track

**Written 9 Oct 2026.** Closes the "Daily rewards" row of `Feature_Parity_Audit.md` §8: the reference runs a 7-day cycle **plus a slower "Total Days" milestone track underneath it**, with milestones at **8 / 15 / 22 / 30** (`Reference_Data_Extract.md`, line 219). PawSanctuary has only the 7-day cycle.

## 1. Why this one matters for retention (D9)

Today's free login streak (`QuestCoordinator.checkDailyLogin`) **resets to Day 1 after any single missed day**. A player who misses a Tuesday loses their week. The Total Days track is the counterweight: it counts days, not consecutive days, and a missed day costs nothing. That is the whole value of the mechanic — a reason to come back after a lapse rather than a punishment for having had one.

## 2. What was measured, and what was not

- **Measured:** the thresholds — 8, 15, 22, 30 — and that it runs underneath the 7-day cycle.
- **Not measured:** the rewards, whether the count is consecutive, and what happens after 30. The reference extract records none of them. Everything below on those points is a PawSanctuary design choice, not a reading.

## 3. Rule

- A counter, `loginTotalDays`, goes up by one on **each new calendar day the player opens the game** (the same moment the Good Morning popup is raised). It never goes down and a gap does not reset it.
- It runs in **30-day cycles**: the track shows `((total − 1) mod 30) + 1` of 30. Reaching day 30 and opening the game the next day starts a fresh cycle, so the milestones keep recurring. (Choice: the reference's behaviour after 30 is unknown.)
- When a day's count lands on a milestone, the Good Morning popup shows it as a bonus beside the normal day reward, and **Claim pays both** in one tap.
- The popup gains a progress strip: a bar of the 30 days with the four milestones marked, ticks for the ones already passed this cycle, and "Day N of 30".

| Day | Kibble | Dog Tags | Card pack |
|---|---|---|---|
| 8 | 40 | 5 | — |
| 15 | 60 | 10 | 1★ |
| 22 | 80 | 15 | — |
| 30 | 100 | 25 | 2★ |

**These rewards are my numbers, not the reference's.** A full cycle pays 280 kibble, 55 Dog Tags and two packs: about 9 kibble a day against a regen of 720 a day, so the kibble faucet is barely touched. Tags are the larger lever (55 a month against the 7-day cycle's ~20 a week), and are the thing to watch.

## 4. Decisions made while writing this — flagged for review

1. **Counts opening days, not claim taps.** The count moves when the popup is raised, so it matches the existing login bookkeeping. A player who force-quits before claiming loses that day's reward — **an existing behaviour** (`lastLoginDate` is already set at the check) that this does not fix and that a milestone day makes costlier. Worth a follow-up: grant at the check, or re-raise an unclaimed popup.
2. **Not gated on the Loyalty Club.** The Loyalty Club is a separate, level-gated system with its own cycle. This sits under the free Good Morning reward so every player has it.
3. **30-day cycle that repeats.** Unmeasured; chosen so the mechanic never "runs out" for a returning player.
4. **Schema v43.** `loginTotalDays` is a new non-optional `GameState` field, so it takes a version bump, an `additiveDefaultsSinceV8` entry and a `PersistenceTests` case.

## 5. Out of scope

The 7-day cycle itself, the Loyalty Club, and the forfeited-popup problem in decision 1.

## 6. Tests

The counter rises once per new day and not on a second open the same day; a gap does not reset it; the cycle day wraps at 30; milestones land on exactly 8/15/22/30 of a cycle; Claim pays the day reward plus the milestone and cannot pay twice; a v42 save migrates with the counter at 0.

## 7. Status

**Implemented 9 Oct 2026, schema v43.** `AnimalSpecies.swift` (cycle length, milestone table, `loginCycleDay`, `loginMilestone`), `QuestCoordinator.swift` (the counter, bumped on each new day), `GameStore.swift` (v43, additive default, dispatch entry), `MergeBoardViewModel.swift` (`loginMilestoneToday`; `claimLoginReward` now pays the bonus and refuses a second claim), `PanelViews.swift` (the strip and the bonus block). 689/689 tests, including 2 new `PersistenceTests` cases and `TotalDaysTests` (9).

Seen on the Simulator with the save seeded as "yesterday was login day 7": the popup raised on a real **v42 → v43 migration**, showed "Day 8 of 30" with the Day 8 marker lit and a "Day 8 bonus" block, and Claim took kibble 681 → 736 (+15 day, +40 bonus) and Dog Tags 7 → 12 (+5). The first screenshot showed the milestone numbers spaced evenly instead of under their markers; fixed by positioning them with the markers' own proportions.

**Not seen:** the 15 / 22 / 30 days, the card packs on 15 and 30, or the cycle wrapping. Day 15's pack is unit-tested.

**Test pitfall worth recording:** a fresh game runs the first-day login check immediately, so the counter reads 1 after a reset, not 0.

**Still open:** decision 1 above — a force-quit before Claim forfeits that day's reward, now including a milestone's.
