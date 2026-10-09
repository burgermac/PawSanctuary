# Spec — Pay the Good Morning reward at the check

**Written and implemented 9 Oct 2026.** Fixes a bug that long predates the Total Days track and that `Spec_TotalDaysTrack.md` §4 decision 1 flagged because Total Days made it costlier.

## 1. The bug

`QuestCoordinator.checkDailyLogin()` registers a visit by setting `lastLoginDate` to today the moment the game opens. The reward, though, was only paid when the player tapped **Claim** on the Good Morning popup. The visit date is saved by the next ordinary save (a merge, a claim, backgrounding); the reward was not saved because it had not been paid. So **force-quitting between the open and the tap left "already logged in today" on disk with no reward ever paid** — on relaunch the check saw today as registered and raised no popup. Lost for good, until tomorrow.

Total Days made it costlier: a milestone day (8 / 15 / 22 / 30) carries a bonus on top, so the forfeit now cost up to 100 kibble, 25 Dog Tags and a card pack.

## 2. The fix

`MergeBoardViewModel.checkDailyLogin()` now **pays the day reward and any milestone bonus the moment a new day registers** (`grantLoginReward`). The date and the balance change together, so they are saved together or not at all; a relaunch after a quit can never see one without the other. The popup remains, as the celebration: its button is now **"Got it!"** and only dismisses (`dismissLoginReward`), because it no longer pays anything.

No schema change and no persisted flag: the alternative (a "pending reward" boolean that re-raises an unclaimed popup) would have needed a version bump and a migration, and still left the popup open to be abandoned. Paying at the check needs neither.

## 3. Decisions made while building — flagged for review

1. **The HUD moves before the popup is dismissed.** Kibble and Dog Tags are already higher behind the Good Morning popup. That is the honest state — they have been paid — but it differs from the old flow where the number jumped on the tap.
2. **The button says "Got it!", not "Claim!".** A Claim button that claims nothing would be a lie; and a player who sees it paid and taps it has lost nothing.
3. **A hard kill before any save pays once on the next launch, not twice.** Both the date and the balance live in the same save; if neither reached disk, the next launch sees yesterday and pays that day once.
4. **Pass bonus not applied.** The old claim did not apply `withPassBonus` to the day reward either; unchanged.

## 4. Tests and verification

`LoginGrantAtCheckTests` (2) drives a real relaunch — `persistNow()`, then a second view model's `loadGame()` — and asserts the reward survives and is not paid again, and that a relaunch the same day raises no popup. The old claim tests in `TotalDaysTests` were rewritten to assert payment at the check, a second check paying nothing, and dismissal paying nothing. 701/701.

**Seen on the Simulator:** with the save seeded as yesterday's login and 100 kibble, launching showed the popup with the balance already **115** behind it and a "Got it!" button. Force-quitting without tapping it and relaunching showed **115 and no second popup** — under the old code the same steps leave 100 and no popup.
