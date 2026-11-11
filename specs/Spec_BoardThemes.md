# Spec — Board themes

**Written and implemented 9 Oct 2026.** Closes the "Cosmetic choice" row of `Feature_Parity_Audit.md` §1, from `Merge2_Reference_Blueprint.md` §29: *"colour/theme selection with no currency cost. An ownership device, not a sink"*, and the cold-install timeline's row *"5:00 — Meta screen, first customisation choice"*.

## 0. What the evidence is, and is not

Two lines. The reference has a free colour/theme choice, offered around minute 5 of the first session. **It does not record what is customised, how many options there are, or whether the choice can be changed.** Everything below beyond "free, early, a choice" is PawSanctuary's own design, not a reading.

## 1. Rule

- Five **board themes**, each a distinct backdrop gradient plus tinted board panel and empty cells: **Meadow** (the current look, the default), **Seaside**, **Dusk**, **Autumn**, **Blossom**.
- **Meadow, Seaside and Dusk are free from the start.** **Autumn unlocks at 3 built Sanctuary areas, Blossom at 6.** Unlocking costs nothing; it is a reward for meta progress (the blueprint's "endowed progress" reasoning), so there is **no currency anywhere in this** and no monetization surface.
- **First choice, session one:** once the tutorial is done, a one-time "Make it yours" sheet offers the starter themes. "Keep Meadow" dismisses it. It never returns by itself.
- **Always changeable:** a Board Theme row in Profile shows all five, with locked ones showing what unlocks them.
- The theme colours the screen's backdrop, the board panel behind the grid, and empty cells. It deliberately does **not** touch item art, tile tints, the HUD pills, banners or any state colour (selection, hand-in highlights, locked rows): those carry meaning.

## 2. Decisions made while building — flagged for review

1. **Board, not Map.** The board is the one screen seen constantly; the Map's areas are an icon and a colour today, so there is little there to restyle. A per-area look is a separate, later option.
2. **Unlock thresholds (3 and 6 areas) are mine.** No measurement behind them; chosen to be reachable (the map has 15 areas) without being session-one.
3. **Dusk is deliberately light.** A truly dark theme would fail the dark-on-light text the HUD, tray and captions use over the backdrop; Dusk is a muted violet-to-rose instead.
4. **Migrating saves also see the first-choice sheet once.** `boardThemePrompted` defaults to false, so a player who is already past the tutorial gets the sheet once, at their next launch after the update, when the login popup is not showing. One extra tap for existing players; the alternative (silently skipping them) means they never learn the feature exists.
5. **No theme on the Parallel Board screen.** It has its own gradient and is a separate full-screen surface; left alone.

## 3. Persistence

Schema **v44**: `boardTheme` (String-raw enum, default `meadow`) and `boardThemePrompted` (Bool, default false), both non-Optional, so both get `additiveDefaultsSinceV8` entries and a dispatch entry for v43. `PersistenceTests` covers the migration and a round trip.

## 4. Tests and verification

`BoardThemeTests` (8): the starter themes are free; Autumn and Blossom unlock exactly at their area counts and the counts are reachable; a new game is on Meadow and un-prompted; selecting an unlocked theme changes it and survives a real relaunch; a locked theme is refused; building areas unlocks the later ones; the prompt is recorded once; and **every theme's backdrop is measurably far from Meadow's**, so a theme cannot quietly be decoration. Two `PersistenceTests` cases cover the v43→v44 migration and a round trip. 722/722.

**Seen on the Simulator, in the running app:**
- Launching a real **v42 save** migrated forward and raised the **"Make it yours" sheet by itself** after about a second, offering Meadow, Seaside and Dusk with Meadow selected.
- Picking **Dusk** and confirming recoloured the screen: a violet-to-rose backdrop, a lavender board panel and lavender empty cells, with item art, tile tints, HUD pills and text unchanged and readable.
- Relaunching kept Dusk and **did not show the sheet again**.
- With six areas seeded as built, the Profile picker showed all five unlocked; **Autumn** gave a warm amber backdrop and cream cells.
- With none built, the Profile picker showed **Autumn "3 areas"** and **Blossom "6 areas"** faded with locks, and Meadow selected after "Keep Meadow".

**Not seen:** Seaside and Blossom on the board (their swatches render; the colours are built the same way), and the sheet appearing after a *fresh* tutorial rather than on an existing save.

## 5. Status

**Implemented 9 Oct 2026, schema v44.** `BoardTheme.swift` (new: the enum, colours, environment key, `BoardThemePicker`, `BoardThemeChoiceSheet`), `GameStore.swift` (v44), `MergeBoardViewModel.swift` (state, `selectBoardTheme`, `markBoardThemePrompted`, `builtAreaCount`), `MergeBoardView.swift` (backdrop, panel, the sheet), `CellView.swift` (empty cells), `ProfileView.swift` (the picker), `AnimalSpecies.swift` (the two thresholds).

**Still open:** whether a per-area look on the Map (option B) is wanted; and the unlock thresholds, which are mine and unmeasured.
