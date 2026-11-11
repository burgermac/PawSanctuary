# Kibble Drive §6h acceptance run — results (9 Oct 2026)

Build: `main` Debug, iPhone 17 Pro simulator (iOS 26.5), fresh install, run ~02:10–02:16 UTC with the window open (`2d 21h left`). Debug bundle ID was `com.timothyherburger.pawsanctuary1`, not `…pawsanctuary`.

| # | Result | What was seen |
|---|---|---|
| 1 | PASS | Cold launch, monetization locked (purple unlock button visible). Orange box tile in the tray, empty bar, no red dot. Tray starts collapsed to one column; the tile only shows after swiping it open. |
| 2 | PASS | Sheet: "Kibble Drive", `2d 21h left`, `0 / 300`, 15-segment bar, 15 rows reading "N more" (10, 22, 35, …), caption "Unclaimed rewards are lost when the Drive ends." present. |
| 3 | PASS | Banner "Earn up to 540 Kibble"; "Simulate purchase (Debug)" present; no price button. |
| 4 | PASS (Easy only) | Two Easy quests claimed. Each claim moved `kibbleDrive.points` and `carePointsThisWeek` by +8 together (0→8→16), read from `gameState.json`; tile bar not read by eye. Medium (15) not tested. |
| 5 | PASS | Seeded 20 pts, unpurchased: rung 1 shows a padlock, rung 2 reads "2 more". |
| 6 | PASS | At 20 pts the bonus line is correctly absent (ahead of par, ~9.7 at this hour). Seeded 4 pts: line reads "+2 bonus points on purchase", matching `kibbleDriveCatchUpGrant`. |
| 7 | PASS | Debug unlock, then Simulate purchase. 4 pts → 6 (bonus +2 applied). At 20 pts: banner gone, points unchanged (no bonus), rung 1 shows Claim!. Red dot before claiming not captured; seen at step 10. |
| 8 | PASS | Claim rung 1: kibble 111→141 (+30), row shows tick + "Claimed", red dot cleared. Pressing Claim a second time was not tried. |
| 9 | PASS | Terminate + cold launch: points 20, purchased true, claimedRungs `[0]` all unchanged; Drive not recreated. |
| 10 | PASS | Seeded 300 / purchased / `[]`: full tile bar + red dot, 15 × Claim!. After claiming all 15: kibble 141→681 (+540); `pendingCardPacks` `["star1"]` → `["star1","star4","star5"]`. |
| 11 | PASS (11 Nov 2026) | Run with a patched save after a real window had closed; see "Step 11 run" below. Drive state dropped on cold launch, no tile, no rewards paid out. |

## Step 11 run — forfeit on close (11 Nov 2026)

Build: `main` at `b900435`, Debug, built to derived data outside the project folder, iPhone 17 Pro simulator (iOS 26.5). Clock: 2026-11-11 16:28 UTC, so no Drive window is open (`kibble_drive_20261106` ended 2026-11-09 00:00 UTC; the next, `kibble_drive_20261204`, opens 2026-12-04).

**Setup.** With the app not running, the existing Simulator save (schema 44, kibble 100, no `kibbleDrive`) was copied aside, then patched to `kibbleDrive = {eventID: "kibble_drive_20261106", points: 150, claimedRungs: [0, 1], purchased: true}`: a purchased Drive from the window that ended two days earlier, with points banked and several reached rungs still unclaimed. Installing the new build kept the save (the data container moved to a new path but the file came across intact). Launched with `simctl launch` so it was not reinstalled.

**Result: PASS.**
- **Save after launch.** `gameState.json` was rewritten at launch. `kibbleDrive` is absent: the state was dropped outright, not kept or carried forward. `pendingCardPacks` stayed `[]` and `pendingKibbleDriveEventID` stayed absent.
- **No payout of unclaimed rungs.** Kibble went 100 to 110. The +10 is the daily login reward shown in the "Good Morning! Day 2 Reward, +10 Kibble" popup that opened at launch. The unclaimed rungs that 150 points had reached were not paid out.
- **What the player sees.** After dismissing the login popup and swiping the tray open, the tray held exactly nine tiles over three rows: free chest ("Open", red dot), trophy, refresh arrows, target `0/3`, checklist `0/3`, star, sparkles, smiley face, heart. That is the nine always-present tiles and nothing else. There is no orange Kibble Drive tile with a progress bar. No message, toast or popup mentions the Drive.
- **The "This Kibble Drive has ended." line was not seen, and cannot be reached this way.** With the Drive state gone, the tile is gone and nothing else opens the sheet. That line only shows if the sheet is already open when a window ends mid-session. That case was not tested, because the Simulator clock cannot be moved.

**Observation, not a defect:** the forfeit is silent. A player who bought the Drive and left rungs unclaimed is told nothing on their next launch. That matches §2 and the panel caption ("Unclaimed rewards are lost when the Drive ends."), so nothing was filed. Whether a one-line "Your Kibble Drive has ended" notice is wanted is a design question for the owner.

**Clean-up.** The original save was put back afterwards. A copy is kept at `/private/tmp/claude-501/-Users-timothyherburger-Documents-Claude-Claude-Code-PawSanctuary/4ba29701-3fff-4362-8193-69f643496285/scratchpad/gameState.original.json`. No app code changed.

## Layout and feedback judgements

- **Reward pills fail the one-line check at the default text size.** Rungs 10 and 15: "+40 Kibble" wraps to two lines beside the star-pack pill. With a Claim button showing, "4-Star Pack" / "5-Star Pack" wrap too. Rows with no pack pill are fine.
- **Largest Dynamic Type (accessibility-extra-extra-extra-large) fails badly.** Header wraps to "Kibble / Drive", "2d 21h / left", "300 / / 300"; "10 points" splits across two lines; "+30 Kibble" is clipped to "+3" or broken one character per line; "Claimed" clips to "Claime / d" and "Claim!" clips at the edge; a large blank gap appears above the header at the top of the sheet.
- **Scrolling is clean at default size.** The 15 rows scroll with no clipping.
- **A claim needs more feedback than the row flip.** A tick and "Claimed" is subtle and the kibble pill doesn't animate. Claiming a pack rung (10, 15) says nothing on the sheet about a pack being queued. Suggest a haptic or toast, plus a "pack added" note on those two rungs.

## Other things to know

- Debug bundle ID is `com.timothyherburger.pawsanctuary1` (the checklist said `…pawsanctuary`).
- The simulator had no prior `gameState.json`, so there was no original save to restore. A copy taken after step 4 is at `/tmp/gameState.postStep4.bak`; the simulator keeps its final seeded state. Text size reset to Large.
- Simulator screenshots lag the tap by about a second; several steps were confirmed from the save file instead.
- `claimedRungs` is 0-indexed in the save (rung 1 is stored as `0`).
- No app code changed and nothing committed.
