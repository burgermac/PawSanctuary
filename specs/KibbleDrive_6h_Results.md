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
| 11 | SKIPPED, then **PARTIAL** (11 Nov 2026) | Skipped on 9 Oct: window not yet closed. Run on 11 Nov against the closed `kibble_drive_20261106` window: the save-level forfeit passes for both the unpurchased and the purchased-with-unclaimed-rungs case. The tile's absence was not confirmed by eye. See "Step 11 — forfeit on close" below. |

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

## Step 11 — forfeit on close (run 11 Nov 2026)

**Verdict: PARTIAL.** The forfeit itself passes. Both seeded cases lost their whole Drive state on a cold launch after the window closed, and nothing was granted. The step's on-screen half (the tray tile is gone) was not checked by eye.

**Setup.** Debug build of `main` at `b900435`, built with derived data in the session scratchpad (outside the synced folder). iPhone 17 Pro simulator, iOS 26.5, bundle `com.timothyherburger.pawsanctuary1`. The app was installed over an existing save, which was backed up first and restored byte-for-byte at the end. The run was at about 14:30 UTC on 2026-11-11.

**Window.** `KibbleDriveRegistry` (`PawSanctuary/KibbleDriveEvents.swift`) has `kibble_drive_20261106` running 2026-11-06 to 2026-11-09 (UTC, end exclusive). No Drive is active on 2026-11-11. The next window is `kibble_drive_20261204`.

**What forfeit means in code.** `MergeBoardViewModel.checkEventLifecycle(at:)` (`PawSanctuary/MergeBoardViewModel.swift`, the `else` branch at about line 4174) sets `kibbleDrive = nil` whenever `KibbleDriveRegistry.activeEvent(at:)` returns nil. There is no branch on `purchased` or `claimedRungs`. No points convert, no rung auto-claims and no refund or kibble is granted. Because `kibbleDrive` is Optional, the next autosave leaves the key out of `gameState.json`. The tray tile (`TaskTrayView.kibbleDriveTile`) returns nil when `viewModel.kibbleDrive` is nil, so the tile cannot show afterwards.

**Method.**
1. Launched once so a v44 save existed, then terminated the app.
2. Wrote a `kibbleDrive` object into `Library/Application Support/PawSanctuary/gameState.json` (with `version` left at 44), then ran `xcrun simctl launch` without reinstalling. Waited about 16 s, which covers the 5-tick autosave, then terminated the app and diffed the save against the seeded copy.
3. Ran it for two cases:
   - **A:** unpurchased, with points banked.
   - **B:** purchased, two rungs claimed, more rungs reached but unclaimed. This is the paid case.

**Case A — unpurchased.** Seeded:
```json
"kibbleDrive": {"eventID": "kibble_drive_20261106", "points": 120, "claimedRungs": [], "purchased": false}
```
Diff after the cold launch:
```
REMOVED /kibbleDrive: {"eventID": "kibble_drive_20261106", "points": 120, "claimedRungs": [], "purchased": false}
CHANGED /lastActiveDate               (normal autosave)
CHANGED /urgentOrderCooldownRemaining (normal timer)
```

**Case B — purchased, unclaimed rungs reachable.** Seeded:
```json
"kibbleDrive": {"eventID": "kibble_drive_20261106", "points": 250, "claimedRungs": [0, 1], "purchased": true}
```
Diff after the cold launch:
```
REMOVED /kibbleDrive: {"eventID": "kibble_drive_20261106", "points": 250, "claimedRungs": [0, 1], "purchased": true}
CHANGED /lastActiveDate               (normal autosave)
CHANGED /urgentOrderCooldownRemaining (normal timer)
```

In both cases `kibble` stayed at 110 (the HUD also read 110), and `pendingCardPacks`, `carePointsThisWeek` and every other field were unchanged. Case B behaved exactly like case A. A purchased player at 250 points with rungs 3 and up unclaimed loses them with no compensation. That matches §6c's decision ("unclaimed rungs are lost") and the panel caption "Unclaimed rewards are lost when the Drive ends." It is recorded here because it touches the paid product: there is no purchased-specific path, and §7's question 5 (refund exposure) still applies.

**Screenshots.** `xcrun simctl io booted screenshot` was taken after each launch. Both show the normal board, with the HUD showing 110 kibble and the tray collapsed to one column. The tray's visible box tile labelled "Open" is the **free chest**, which uses the same `shippingbox.fill` icon in a brown tint, not the Drive.

**Not checked.**
- **Tile absence by eye.** The tray starts collapsed, and the Drive tile only appears after swiping it open. Simulator input was not available in this dispatched session, so the tray could not be expanded or the sheet opened. The "This Kibble Drive has ended." text could not be reached either. The tile's absence follows from the code gate above and the nil state confirmed in the save.
- **A Medium-quest claim (step 4).** It needs a live Drive window. The next one is `kibble_drive_20261204` (2026-12-04 to 2026-12-07 UTC).
- **The real StoreKit purchase** and redelivery through `listenForTransactions()`. These are unchanged from earlier runs and still need an Xcode Run with a StoreKit configuration.
- **A Drive closing while the app stays open.** By design (§6c) the forfeit only runs on a cold launch, and this run only exercised the cold-launch path.

No defects found. No app code was changed. The simulator's save was restored to the pre-run backup.
