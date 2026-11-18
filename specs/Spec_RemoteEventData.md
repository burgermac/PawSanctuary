# PawSanctuary — Remote event data (task 7.1)

**Status: Draft, 18 Nov 2026, not reviewed, no code.** Written from a read of `origin/main` at `6d5a409`. Task 7.1 of `specs/Revision_Plan_ModelOnReferences.md` (W7, rows 10 and 11 of `specs/Triage_ModelOnReferences.md`). Task 7.2 (the build) is blocked on the owner reviewing this spec. Under `CLAUDE.md` rule 5 this is a structural change and runs as **its own sprint**: no code starts until the owner approves this spec and answers §12.

**Self-contained brief.** Assumes no prior conversation. Every code claim cites `file:line` at `6d5a409`. Line numbers drift as calendar tasks land, so re-find by symbol name, not by line.

---

## 0. What this changes, in plain language

Today every event (its dates, its milestone thresholds, its rewards) is typed into the app's source code. Adding a weekend event or changing one reward number means a new app release and App Store review. Each 90-day calendar is its own spec, a handful of tasks, and a release.

After this work, the app downloads one small file of event data. If the file is there and valid, its events are used. If the phone is offline, it is a first launch, or the file is broken, the app uses the calendar built into the app, exactly as it does today. The player sees no difference except that new events can appear without an update.

What stays in the app: every **kind** of event (weekly milestone track, 30-day pass, Parallel Board, Kibble Drive) and how it plays. The file can schedule and price existing kinds; it cannot invent a new one. That is the comparison's option 2 (`specs/Comparison_TravelTown_GossipHarbor_PawSanctuary.md` §5-B), not option 3 (downloaded scripting).

Not decided here: telemetry, analytics or A/B tests (triage row 12, the owner's pick, §2.7); event cadence and the D5 cap (task 7.3, blocked on recording R7).

---

## 1. Decisions and constraints this depends on

- **D5** (`specs/PawSanctuary_Alignment_Plan.md` §D5): one 3–4 day event per week, one 30-day pass running continuously; three event types. The validator in §5 enforces today's per-registry concurrency rules. **The cap stays unless the owner changes it**, which is task 7.3's job.
- **D7** (session-one monetization silence) and **D9** (retention outranks monetization) still bind. A remote file must not be able to create a new paid surface (§4.3, rule V9).
- **D14** §5: direction accepted for row 11. Row 12 stays the owner's pick.
- **Triage §2.6**: data only; event ids key saved state, so this needs a migration review (§7).
- **`CLAUDE.md` rule 4**: any persisted-shape change needs a version bump, a migration, and a `PersistenceTests.swift` case. Current schema is **v45** (`GameStore.swift:394`).
- **`CLAUDE.md` rule 5**: own sprint, owner approves first.
- **Launch-only lifecycle** (pre-existing): `checkEventLifecycle(at:)` runs once per launch from `loadGame` (`MergeBoardViewModel.swift:991-1015`, call at `:1015`; doc comment at `:4207-4226`). This spec keeps that, and it is why a downloaded file takes effect at the **next** launch (§5.4).

---

## 2. Today's architecture

### 2.1 Where the calendar lives

Five compiled data blocks, about **2,700 lines** together (the comparison's "about 3,000" includes the doc comments around them):

| Block | Type | Where | Lines | Entries |
|---|---|---|---|---|
| `EventRegistry.allEvents` | `[EventDefinition]` | `EventSystem.swift:96-999` | 904 | 55 (1 legacy coin event, 3 Phase 6b verification events, 12 Sanctuary Circle seasons, 19 Playtime Rush, 20 Rescue Relay) |
| `ProgressTrackRegistry.tracks` | `[String: [TrackMilestone]]` | `LiveOpsEngine.swift:115-1735` | 1,621 | 64 keys: one per track event above (54), 9 Second Chances, plus `reward_ladder` (`AnimalSpecies.swift:1796`, key at `LiveOpsEngine.swift:1709`) |
| `ParallelBoardEventRegistry.allEvents` | `[ParallelBoardEventDefinition]` | `ParallelBoardEvents.swift:109-184` | 76 | 9 |
| `KibbleDriveRegistry.allEvents` | `[KibbleDriveEventDefinition]` | `KibbleDriveEvents.swift:109-182` | 74 | 10 |
| `KibbleDriveLadder.rungs` | `[TrackMilestone]` | `KibbleDriveLadder.swift:33-49` | 17 | 15 rungs, one ladder shared by every Drive |

Dates are parsed by a private `date(_:)` helper in each registry, `ISO8601DateFormatter` with `.withFullDate`, i.e. midnight UTC, falling back to `.distantPast` on a typo (`EventSystem.swift:90-94`, `ParallelBoardEvents.swift:46-50`, `KibbleDriveEvents.swift:44-48`). `startDate` is inclusive, `endDate` exclusive (`LiveOpsEngine.swift:28-30`).

### 2.2 The types

- `EventDefinition` (`EventSystem.swift:37-83`): `id`, `name`, `tagline`, `startDate`, `endDate`, `milestones: [EventMilestone]` (legacy, empty on every event after Phase 6b, see comment at `:114-121`), `icon` (SF Symbol name), `accentColor: Color`, `gradientColors: [Color]`, `minLevel`, `priority`. Not `Codable` (it holds SwiftUI `Color`).
- `TrackMilestone` (`LiveOpsPrimitives.swift:36-41`): `index`, `threshold`, `freeRewards`, `paidRewards`. Already `Codable`.
- `OrderReward` (`AnimalSpecies.swift:980-985`) and `RewardKind` (`:963-972`): `dogTags`, `coins`, `kibble`, `xp`, `cardPack`, `boardItem`, `material`, `eventToken`. `Codable`, `String` raw values.
- `ParallelBoardEventDefinition` (`ParallelBoardEvents.swift:18-43`): `id`, `name`, `icon`, `chainID`, `startDate`, `endDate`. Only one chain exists for it: `ContentRegistry.parallelBoardSecondChancesChainID` (`ItemChain.swift:252`).
- `KibbleDriveEventDefinition` (`KibbleDriveEvents.swift:19-41`): `id`, `name`, `icon`, `startDate`, `endDate`.

### 2.3 Who reads the calendar

- `EventScheduler` defaults to `EventRegistry.allEvents` (`LiveOpsEngine.swift:24`); `EventRegistry.activeEvents` routes through it (`EventSystem.swift:1018-1029`); the view model exposes it (`MergeBoardViewModel.swift:262`).
- `EventRegistry.currentEvent` (`EventSystem.swift:1001-1003`) drives the legacy coin event (`MergeBoardViewModel.swift:4187-4205`).
- `ProgressTrack` **captures its registry at init** (`LiveOpsEngine.swift:1748-1750`). The view model's instance is created once, so any catalog change must be in place before the view model is built. This is the main technical reason a new file applies at the next launch.
- `checkEventLifecycle(at:)` (`MergeBoardViewModel.swift:4227-4303`) registers one `EventTokenRiderProvider` per active `EventRegistry` id (`:4228-4241`; provider at `EventSystem.swift:1048-1063`, 20 tokens at 0.33 frequency), creates or drops the Parallel Board coordinator (`:4246-4258`), and creates or **forfeits** the Kibble Drive state (`:4264-4291`).
- UI reads tracks directly: `EventPanelView.swift:33-35` (milestones), `:39-41` (`hasPaidLane` is derived from the data), `TaskTrayView.swift:526`, `:546`, `:570-572`, `ParallelBoardView.swift:125`, `KibbleDrivePanelView.swift:32`, `:66`, `:110`, `:152`, `PanelViews.swift:1364`.
- `RewardTableRegistry.defaultTables` is empty (`LiveOpsEngine.swift:1843`); nothing rolls a reward table today. `EventTimer` (`:1882-1902`), `TokenWallet` (`:68-100`) and `OfferHookRegistry` (`:1913-1930`) have no production instance.

### 2.4 How a calendar ships today

A cold spec per 90 days (`Spec_Phase6c_Calendar.md`, `Spec_Phase7_Calendar2/3/4.md`), several tasks that append array entries and dictionary keys, a running-total test pin bumped in the same commit (`EventSystemTests.swift:856-860`, value 55 at `:858`; `ParallelBoardEventsTests.swift:181`, value 9), and a release. `Spec_Phase6c_Calendar.md` §0 deliberately rejected a content system and accepted re-running the pass every ~90 days. This spec reopens that trade-off only for **data delivery**; it still adds no scheduler or recurrence engine.

---

## 3. Target shape

```
 bundled (compiled) calendar ─┐
                              ├─► merge (§5.3) ─► pins (§5.5) ─► EventCatalog.effective ─► registries
 cached remote file ──────────┘        ▲
       ▲ validated (§5.1)              │ applied once, at launch, before the view model is built
       │
 downloader (§5.4): HTTPS GET, signature check, write cache; never touches the running session
```

- A new `EventCatalog` value holds the **effective** lists. `EventRegistry.allEvents`, `ProgressTrackRegistry.tracks`, `ParallelBoardEventRegistry.allEvents` and `KibbleDriveRegistry.allEvents` read from it instead of from their literals. Their literals stay in the code, renamed to `compiled…`, as the fallback.
- The compiled calendar keeps shipping. Players on builds without 7.2 never download anything and need it; and it is the fallback for everyone else.

---

## 4. The file

### 4.1 Format (schema version 1)

One UTF-8 JSON file, at most **256 KB**. Unknown keys are ignored at every level, so additive fields need no new schema version.

```json
{
  "schemaVersion": 1,
  "revision": 7,
  "generatedAt": "2027-04-20T09:00:00Z",
  "minAppBuild": 0,
  "events": [
    {
      "id": "playtime_rush_20270604",
      "kind": "milestoneTrack",
      "name": "Playtime Rush",
      "tagline": "…",
      "icon": "figure.play",
      "accentColor": "#D9731A",
      "gradientColors": ["#FFEDCC", "#FCDDAD"],
      "start": "2027-06-04T00:00:00Z",
      "end":   "2027-06-08T00:00:00Z",
      "priority": 0,
      "minLevel": 0,
      "track": [
        { "index": 0, "threshold": 60,
          "free": [{ "kind": "kibble", "amount": 50 }],
          "paid": [] }
      ]
    },
    { "id": "second_chances_20270608", "kind": "parallelBoard", "name": "Second Chances",
      "icon": "arrow.triangle.2.circlepath", "chainID": "parallelboard.secondchances",
      "start": "2027-06-08T00:00:00Z", "end": "2027-06-11T00:00:00Z", "track": [ … ] },
    { "id": "kibble_drive_20270618", "kind": "kibbleDrive", "name": "Kibble Drive",
      "icon": "shippingbox.fill",
      "start": "2027-06-18T00:00:00Z", "end": "2027-06-21T00:00:00Z" },
    { "id": "rescue_relay_20270611", "cancelled": true }
  ]
}
```

(Example values are illustrative; the colour hexes are not taken from code.)

- `revision`: integer, increases with every published file. Each build compiles in `compiledCatalogRevision`; a cached file only overrides compiled entries if its `revision` is greater (§5.3).
- `minAppBuild`: a build lower than this ignores the file (lets the owner publish data that needs a newer build).
- `kind`: one of `milestoneTrack`, `pass`, `parallelBoard`, `kibbleDrive`. An unknown kind skips **that event only** (forward compatibility); it is not an error.
- `cancelled: true`: a tombstone. Removes a compiled or earlier event that **has not started** on this device (§5.5). Ignored for a started event.
- Reward objects are `OrderReward` with the same raw values (`kind`, `amount`, `payloadID`, `payloadTier`).
- A signature travels as a separate file (§8).

### 4.2 Data versus code

| Moves to the file (data) | Stays in code |
|---|---|
| Event id, kind, start, end | What each kind does: rider providers, coordinator, Drive lifecycle, UI (`MergeBoardViewModel.swift:4227-4303`, `EventPanelView.swift`, `ParallelBoardView.swift`, `KibbleDrivePanelView.swift`) |
| Name, tagline, icon, colours, priority, minLevel | Rider numbers (20 tokens, 0.33 frequency, `EventSystem.swift:1053`) — owner question Q5 |
| Track thresholds and free/paid reward lists for `milestoneTrack`, `pass`, `parallelBoard` | Kibble Drive ladder (`KibbleDriveLadder.swift:33-49`), tied to a $4.99 IAP and to `KibbleDriveLadderTests`' economy margin — Q5 |
| Parallel Board `chainID`, chosen from chains the build knows | Reward Ladder (`reward_ladder`, `LiveOpsEngine.swift:1709`), a standing IAP offer, not a calendar event |
| Cancelling an unstarted event | IAP product ids (`AnimalSpecies.swift:1168`, `:1174`, `:1180`); App Store Connect owns them |
| | New event kinds, new reward kinds, new chains, art: **new mechanics stay code** |
| | The legacy coin event shape (`EventMilestone`, `EventSystem.swift:30-35`) |
| | Concurrency rules and reward caps (§5.1), so a file cannot loosen them |

### 4.3 Why paid lanes are restricted

`EventSheetView` shows the Event Pass purchase whenever the track has any non-empty `paidRewards` (`EventPanelView.swift:39-41`, `:55-57`). So with data-driven tracks, a file could turn any weekly event into a paid offer. Rule V9 allows `paid` rewards only on `kind: "pass"`. See also discrepancy 9 (§13): no D7 check was found on that sheet.

---

## 5. Validation and fallback

### 5.1 Validation rules (all must pass, or the whole file is rejected)

- **V1** Parses as JSON; size ≤ 256 KB; `schemaVersion == 1`; `revision > 0`; signature valid if signing is adopted (Q2).
- **V2** Every `id` matches `^[a-z0-9_]{3,64}$`, is unique in the file, and does not collide with a compiled id of a **different** kind.
- **V3** `start < end`, both ISO 8601 with `Z`. Duration bounds per kind: `milestoneTrack` 1–7 days, `pass` 7–35 days, `parallelBoard` 1–7 days, `kibbleDrive` exactly 3 days (`KibbleDriveLifecycleTests.swift:46`).
- **V4** Track: 1–20 milestones, `index` contiguous from 0, `threshold` strictly increasing and > 0.
- **V5** Reward kinds allowed: `kibble`, `dogTags`, `coins`, `xp`, `cardPack` (payload must be a `CardPackType` raw value, `CardSystem.swift:64`), `boardItem` (chain must exist in `ContentRegistry`, tier in range). `eventToken` and `material` are rejected in v1.
- **V6** Caps: each reward `amount` ≥ 1 and ≤ a per-kind ceiling, and each track's total ≤ a per-kind ceiling, both set in 7.2 at 2× the largest compiled table of the same kind and stored with the tuning constants at the bottom of `AnimalSpecies.swift`. These bound the damage of a bad or hostile file.
- **V7** `parallelBoard.chainID` is a chain the build supports for Parallel Board (today only `parallelboard.secondchances`). `kibbleDrive` has no `track` (ladder stays code, Q5).
- **V8** Concurrency over the **merged** catalog, the per-registry rules the calendar tests already assert (`Spec_Phase7_Calendar4.md` §2.7): at most one `pass` and one `milestoneTrack` active at any instant (EventRegistry ≤ 2); Parallel Board ≤ 1; Kibble Drive ≤ 1. Overlap across registries stays allowed. This is where the D5 cap is enforced; changing it is 7.3.
- **V9** `paid` rewards only on `kind: "pass"`.
- **V10** The file breaks no pin (§5.5). A change to a pinned event is not an error; it is ignored for that event.

Not errors: unknown keys (ignored), unknown `kind` (event skipped), an `icon` that does not resolve (`UIImage(systemName:)` nil, falls back to a fixed symbol), a bad colour hex (falls back to the kind's compiled colour).

**Whole-file rejection** (Q6): one failed rule rejects the file and the previous good cache stays in use. Dropping single events can silently change concurrency and gaps, which is harder to reason about than "nothing changed".

### 5.2 Fallback order

1. Valid cached file, `revision > compiledCatalogRevision`, `minAppBuild` satisfied → merged over compiled.
2. Otherwise → compiled calendar only (offline, first launch, no cache, bad file, older file, newer `schemaVersion`).

A bad file never reaches `GameState`. The file is not part of the save, and loading it cannot throw into `loadGame`.

### 5.3 Merge rule

Start from compiled. For each file event: a new id is added; an existing id is replaced (unless pinned); a tombstone removes an unstarted one. Compiled events absent from the file stay. Then pins (§5.5) override. Then V8 runs on the result.

### 5.4 Fetch, cache and timing

- Fetch on launch and on foreground, at most once every 6 hours, `GET` over HTTPS, ephemeral `URLSession` (no cookies, no cache sharing), 10 s timeout, `If-None-Match` with the stored ETag.
- A fetched file is validated, then written atomically to `Application Support/PawSanctuary/eventCatalog.json` beside the save (not `Caches/`, which iOS may purge). Store `fetchedAt` and the ETag **inside** that JSON, not via file timestamps or extra `UserDefaults` keys (avoids a new required-reason API, §9).
- **A new file takes effect at the next launch** (Q8). It is read once at launch, before `MergeBoardViewModel` is built, because `ProgressTrack` captures its registry at init (`LiveOpsEngine.swift:1748-1750`) and the lifecycle is launch-only. A running session never sees its events change underneath it.
- No retry storm: failures wait for the next 6-hour slot.

### 5.5 Started events are pinned; unknown ids never destroy state

**Pin.** When `checkEventLifecycle` sees an event active, the app records a pin: `{id, kind, start, end, track}`. From then on, that event's dates and track come from the pin, whatever later files say. Cosmetic fields (name, tagline, icon, colours) may still change. Pins are pruned 7 days after their `end`. This is the "mid-event changes" rule (Q4 asks whether to allow end-date extensions).

**Unknown id never destroys state.** Two lifecycle branches today drop state when the id they hold is not active:
- Kibble Drive: `kibbleDrive = nil` when no Drive is active (`MergeBoardViewModel.swift:4264-4289`, the `nil` at `:4288`), **including a purchased one** (`KibbleDrive.swift:41-46`).
- Parallel Board: the coordinator is dropped and `parallelBoardState` is re-captured from it, so the saved board is lost on the next save (`MergeBoardViewModel.swift:4256-4258`, `:1329`).

7.2 changes both to forfeit only when the saved id is **known** (pinned or in the catalog) and its known `end` has passed. An id the catalog does not know (file pulled, cache lost, older build) leaves the state dormant until it is known again or its pin expires. This protects a purchase against a data mistake.

**Clock.** Activity is judged with the device clock, as today (`EventSystem.swift:64-67`, `LiveOpsEngine.swift:28-30`). A player who moves the clock can already open future events; this spec does not make that worse and does not add server time. Pins are keyed to dates in the file, not to when the device first saw them, so a clock change does not stretch a pinned window.

---

## 6. Hosting (owner decision, Q1)

A solo developer needs a static file at a stable HTTPS URL. Prices are approximate and should be checked at setup.

| Option | Cost | What the owner's hands do | Notes |
|---|---|---|---|
| **A. GitHub Pages** from a small public repo (e.g. `pawsanctuary-events`) | Free | Create the repo, turn on Pages, merge PRs that change the file | Edits go through the same PR flow as today; full history; served via GitHub's CDN with a short cache (minutes). Check GitHub's Pages usage terms at setup. The calendar is public (spoilers only). |
| **B. Cloudflare (Pages or R2)** | Free tier covers this traffic | Make an account, connect a repo or upload the file, possibly a payment card for R2 | Longer cache control and custom domain; one more account to keep. |
| **C. CloudKit public database** | Free within Apple's quotas | Turn on the iCloud capability and a container in Xcode and the developer portal, define a record type in CloudKit Dashboard, deploy the schema to production, upload records by hand | Data stays with Apple. The app's entitlements currently list only Game Center (`PawSanctuary.entitlements`), though `CardTrading.swift:219` already targets the public database. Editing by dashboard is clumsy, and the JSON pipeline would be replaced by records. |

**Recommendation: A.** No money, no new vendor, and the owner already merges PRs. The URL is compiled into the app, so choose a domain the owner controls long term; a custom domain on Pages lets the host change later without an app release.

---

## 7. Migration review

### 7.1 Every persisted field keyed by event id

| Field | Where | What happens with an unknown or vanished id today |
|---|---|---|
| `eventProgress.eventId` (legacy coin event) | `GameStore.swift:156`, `EventSystem.swift:15-25` | Reset to the current event when the id differs (`MergeBoardViewModel.swift:4187-4193`). Harmless; the file cannot create this kind. |
| `eventTokenWallets: [String: Int]` | `GameStore.swift:210` | Never written: no `TokenWallet` instance exists in the app. Stays empty. |
| `progressTracks: [String: TrackState]` (progress, claimed free/paid indices) | `GameStore.swift:212`, `LiveOpsEngine.swift:107-111` | Kept; an unknown key is inert. Claimed state is by **index**, so a threshold retune of a pinned event cannot re-open a claim. A file that reuses an old id would open with that id's progress, which V2 plus the "every window its own id" convention (`Spec_Phase7_Calendar4.md` §2.1) prevents. |
| `passUnlockedEventIDs: Set<String>` (a purchase) | `GameStore.swift:219`; written at `MergeBoardViewModel.swift:4729-4740` | Kept, but if the pass vanishes from the catalog mid-season the player loses access to what they paid for. Fixed by pinning (§5.5). |
| `parallelBoardState.eventID` (+ board, energy) | `GameStore.swift:252`, `ParallelBoardCoordinator.swift:27-32` | Dropped if the id is not active at launch (`MergeBoardViewModel.swift:4246-4258`, `:1329`). Fixed by §5.5. |
| `kibbleDrive.eventID` (+ points, claimed rungs, `purchased`) | `GameStore.swift:263`, `KibbleDrive.swift:29-47` | Forfeited outright when no Drive is active (`MergeBoardViewModel.swift:4264-4289`), purchase included. Fixed by §5.5. |
| `.eventToken` rewards on saved orders, `payloadID` = event id | `adoptionOrders[].rewards`, `urgentOrder` (`AnimalSpecies.swift:1046`); attached by `EventSystem.swift:1059-1062` | Delivered later, they advance that id's track (`MergeBoardViewModel.swift:3703-3707`). Harmless for an unknown id (an inert `progressTracks` entry). |

Not persisted but id-keyed: `activeEventRiderProviders`, `pendingEventPassEventID` (`MergeBoardViewModel.swift:224`), `pendingKibbleDriveEventID` (`:253`), and OS notification ids `pawsanctuary.event.expiry.<id>` (`NotificationManager.swift:27`, no production caller).

### 7.2 Old builds and new ids

- **A build without 7.2** never fetches; it runs its compiled calendar. Nothing changes for it.
- **A 7.2 build that meets an id it does not know** in a file: fine, ids are just strings to every field above. It meets a **kind** it does not know: that event is skipped (§4.1). It meets `schemaVersion` 2: the whole file is ignored (§5.2).
- **A saved id that disappears from the file**: inert for finished events; protected by pins and the "unknown id never destroys" rule for running ones.
- **iCloud restore on a second device**: the save syncs through `NSUbiquitousKeyValueStore` (`GameStore.swift:277`), the cached file does not. If pins live only on the first device, the second device can meet a running Drive or Pass it does not know. That decides Q3.

### 7.3 Is a schema bump needed?

**Only for pins, and only if they live in the save (Q3, recommended).** Proposal: **v45 → v46**, adding

```swift
/// Event definitions pinned when first seen active (Spec_RemoteEventData.md §5.5).
var eventPins: [String: EventPin] = [:]
```

where `EventPin` is `Codable` with `id`, `kind` (`String` raw value), `start`, `end`, `track: [TrackMilestone]?`.

Following the code's current pattern, not a named helper (see discrepancy 4):
- `static let currentVersion = 46` with a `/// v46:` history line (`GameStore.swift:285-394`).
- `"eventPins": [String: Any]()` in `additiveDefaultsSinceV8` (`GameStore.swift:754-822`), because the field is non-Optional.
- A dispatch line `if version == 45 { return migrateByInjecting(from: 45, defaults: [:], into: data) }` beside `GameStore.swift:702-717`. If the owner wants the `CLAUDE.md` naming kept, wrap it as `migrateV45toV46(_ data: Data) -> GameState?` that calls `migrateByInjecting`; behaviour is identical.
- `PersistenceTests.swift` cases, in the style of `testV44toV45StartsEveryTrophyPageEmpty` (`:1411`): `testV45toV46StartsWithNoEventPins`, `testEventPinsRoundTripOnAFreshSave`, and `testAPreV46SaveWithARunningKibbleDriveStillLoadsItsDrive`.

The cached file itself is never part of `GameState` and needs no migration.

---

## 8. Signing and integrity (Q2)

- HTTPS only; App Transport Security's defaults stay on.
- Recommended: an **Ed25519 signature** (CryptoKit `Curve25519.Signing`) over the exact file bytes, published as `events.json.sig`. The public key is compiled in; the private key stays on the owner's Mac, never in the hosting repo. A compromised GitHub account then cannot push rewards to players; the V6 caps bound the damage if the key itself leaks. Losing the key means shipping a new public key in an update; until then the app runs on compiled or cached data, which is safe.
- A small script (`scripts/eventcatalog.swift`, task 7.2.7) exports, validates with the same rules as the app, and signs.

---

## 9. Privacy

- **What the download sends**: a plain `GET` with no query string, no cookies, no identifiers. The host still sees the IP address and a `User-Agent` (app name, build, OS version), as any web request does. The app must not add a player id, install id, level or anything else: **the fetch is not a telemetry channel**. Telemetry is row 12, the owner's separate pick (Triage §2.7), and is out of scope here.
- **Privacy manifest** (`PawSanctuary/PrivacyInfo.xcprivacy`): today `NSPrivacyTracking` false, no tracking domains, no collected data types, one required-reason API (UserDefaults, `CA92.1`). The download needs **no change** if 7.2 keeps cache metadata inside the cache JSON (§5.4). Reading file modification dates would add `NSPrivacyAccessedAPICategoryFileTimestamp` (reason `C617.1`); avoid it. The host is not a tracking domain.
- **App Store privacy answers**: with no identifiers sent and nothing retained by the developer, this is generally not "data collected" under Apple's definition. The hosting provider's own server logs are the point to check; the owner confirms the answers in App Store Connect when 7.2 ships. If the owner later picks telemetry (row 12), those answers change for that reason, not this one.
- Side note, out of scope: the manifest declares no collected data while card trading sends `GKPlayer.gamePlayerID` to CloudKit (`CardTrading.swift:119`, `:219`). Whether that path ships enabled was not checked. Flagged for the owner, not part of this spec.

---

## 10. Implementation tasks (7.2, one per session)

**Own sprint (`CLAUDE.md` rule 5). Owner approves this spec and answers §12 first.** Each task: branch off `main`, one commit or PR, full test suite green, stop. The game stays playable at every commit.

1. **7.2.1 — Catalog seam, no behaviour change.** Add `EventCatalog` (compiled-only for now). Rename literals to `compiledEvents` / `compiledTracks` and make `allEvents` / `tracks` read through the catalog. Tests: every existing calendar test green unchanged; new `EventCatalogTests.testEffectiveCatalogEqualsCompiledWhenNoFileIsPresent`.
2. **7.2.2 — File model, decoder and validator (pure, no network, no I/O).** `RemoteEventFile` Codable types, V1–V9, hex colours, conversion to the existing definition types. Tests: one fixture per rule that must fail; a valid fixture; unknown keys ignored; unknown kind skipped; `schemaVersion: 2` rejected; a fixture generated from the compiled calendar passes.
3. **7.2.3 — Schema v46: `eventPins` (if Q3 = save).** Field, default, dispatch line, history comment; nothing writes it yet (the KibbleDrive step-1 pattern). Tests: the three `PersistenceTests` cases in §7.3; full migration suite green.
4. **7.2.4 — Merge, pins, tombstones, and the "unknown id never destroys state" rule.** Changes to `checkEventLifecycle` (`MergeBoardViewModel.swift:4246-4291`). Tests: a purchased running Drive whose id vanishes keeps its state; a running pass whose thresholds change keeps the pinned table; a tombstone removes an unstarted event and is ignored for a started one; the Parallel Board board survives an unknown id; pins prune 7 days after end.
5. **7.2.5 — Cache loader at launch.** Read `eventCatalog.json` before the view model is built; `revision` and `minAppBuild` rules; corrupt or truncated file falls back to compiled. Tests: corrupt cache, lower revision, higher schema version, missing file — each yields the compiled catalog; tests never touch a real network or a developer's real cache (inject the loader).
6. **7.2.6 — Downloader.** Ephemeral `URLSession`, 6-hour throttle, ETag, size cap, timeout, signature check (if Q2), atomic write; never applies mid-session. Tests with a `URLProtocol` stub: 200 valid, 304, 404, timeout, oversize, bad signature, valid-but-invalid-data. Assert the request has no query string and no cookies.
7. **7.2.7 — Authoring script.** `scripts/eventcatalog.swift`: export the compiled calendar to JSON, validate a file with the app's rules, sign it. The first published file is the export, so day one changes nothing for players. Test: export → validate round trip in the test target.
8. **7.2.8 — Owner hosting, privacy review and on-device check.** Owner creates hosting (Q1) and publishes the first file; check the privacy manifest and App Store answers (§9); a Simulator run covering offline first launch, good file, bad file, and a file published mid-event, with screenshots to the owner.

Running-total test pins (`EventSystemTests.swift:858`, `ParallelBoardEventsTests.swift:181`) keep pinning the **compiled** catalog. Remote content gets its own validator tests, not count pins.

---

## 11. Out of scope

- Any code (this task is the spec).
- Telemetry, analytics, A/B tests, remote tuning of non-event numbers (row 12).
- Changing event cadence or the D5 cap (7.3, blocked on R7).
- New event kinds or mechanics; downloaded scripting (§5-B option 3); competitive events (row 18).
- Moving the Kibble Drive ladder, the Reward Ladder or rider numbers into the file (unless Q5 says otherwise).
- Server time, anti-clock-cheat measures.
- Wiring `EventTimer` / expiry notifications (pre-existing gap).
- The remaining Calendar 4 tasks (`Spec_Phase7_Calendar4.md` §4.2–4.6), which stay on their own track (Q7).
- Cleaning up the stale comments listed in §13.

---

## 12. Open owner questions

1. **Q1 — Where is the file hosted?** (a) GitHub Pages, (b) Cloudflare Pages or R2, (c) CloudKit public database. **Recommend (a).**
2. **Q2 — How is the file protected?** (a) HTTPS only, (b) HTTPS plus an Ed25519 signature with the key on the owner's Mac, (c) HTTPS plus certificate pinning. **Recommend (b).**
3. **Q3 — Where do started-event pins live?** (a) in the save, schema v46, so they follow iCloud sync, (b) in a side file next to the save with no schema bump, (c) no pins, rely on validation only. **Recommend (a).**
4. **Q4 — May a running event be changed?** (a) frozen except text and colours, (b) end-date extensions also allowed, (c) anything may change. **Recommend (a)** for v1.
5. **Q5 — What does the file control in v1?** (a) event windows and track reward tables only, (b) also the Kibble Drive ladder, (c) also rider numbers. **Recommend (a).**
6. **Q6 — What happens to a partly bad file?** (a) reject the whole file and keep the last good one, (b) drop only the bad events. **Recommend (a).**
7. **Q7 — How does Calendar 4's remainder ship?** (a) compiled in as planned, before 2027-05-15, (b) as the first remote file. **Recommend (a)**: builds without 7.2 still need it, and the deadline should not depend on a new pipeline.
8. **Q8 — When does a downloaded file take effect?** (a) at the next launch, (b) immediately on foreground. **Recommend (a)**: matches the launch-only lifecycle and the way `ProgressTrack` is built.

---

## 13. Spec-vs-code discrepancies found while writing this

Where they disagree, the code was checked and this spec follows the code.

1. **The calendar does not run to 2027-08-30 on every layer.** `Comparison_TravelTown_GossipHarbor_PawSanctuary.md` §5-B option 1 says the calendar is "authored through 2027-08-30". In code only the continuous track reaches it (`sanctuary_circle_s12_20270731` ends 2027-08-30, `EventSystem.swift:986-997`). The weekly track ends 2027-06-01 (`rescue_relay_20270528`, `EventSystem.swift:936-948`), Parallel Board 2027-05-12 (`ParallelBoardEvents.swift:177-183`), Kibble Drive 2027-05-24 (`KibbleDriveEvents.swift:176-181`). This is consistent with `Spec_Phase7_Calendar4.md`'s status line (§4.2–4.6 not started).
2. **Schema version in calendar specs is stale.** `Spec_Phase7_Calendar4.md` §2.11 and `Spec_Phase7_Calendar2.md` §2.10 say v44 at `GameStore.swift:388`; the code is **v45** at `GameStore.swift:394`. (`Revision_Plan_ModelOnReferences.md` rule 4's "v45 to v46" is correct.)
3. **Line drift.** `Spec_Phase7_Calendar4.md` §1 cites `checkEventLifecycle(at:)` at `MergeBoardViewModel.swift:4153`; it is at `:4227`.
4. **Migration helper naming.** `CLAUDE.md` says helpers follow `migrateVNtoVN+1(_ data: Data) -> GameState?`. Every bump since v29 is a `migrateByInjecting(from:)` dispatch line plus an `additiveDefaultsSinceV8` entry (`GameStore.swift:702-717`, `:754-822`); the last named helper is `migrateV28toV29` (`:980`). §7.3 follows the code and offers a named wrapper if the owner wants the convention kept.
5. **Dispatch lines out of order.** v44 is checked before v43 (`GameStore.swift:716-717`). Harmless, since each is an equality test.
6. **Stale "not wired yet" comments.** `LiveOpsEngine.swift:6-7` ("nothing in the app calls into these yet") and `:1740-1741` (`ProgressTrack` "Not yet wired into MergeBoardViewModel"); `KibbleDrive.swift:26-28` and `GameStore.swift:262` ("Nothing reads or writes this yet"). All are used: `MergeBoardViewModel.swift:1329-1337`, `:1412-1419`, `:4264-4291`.
7. **`eventTokenWallets` is persisted but never written.** No `TokenWallet` instance exists; event tokens go straight to `progressTrack.advance` (`MergeBoardViewModel.swift:3703-3707`). The comment at `GameStore.swift:207-208` ("nothing writes to these yet") is true for the wallets and false for `progressTracks` beside it.
8. **"About 3,000 lines" of event content** (Comparison §1 item 3, Triage row 11): the data blocks are about 2,700 lines (§2.1); the estimate holds once their doc comments are counted. Not an error, recorded so the next reader does not recount.
9. **Possible D7 gap, not verified on device.** The Event Pass purchase appears in `EventSheetView` whenever a track has paid rewards (`EventPanelView.swift:39-41`, `:55-57`); there is no `isMonetizationUnlocked` check in `EventPanelView.swift`, and event tiles come straight from `activeEvents` (`TaskTrayView.swift:524-538`, sheet at `MergeBoardView.swift:783-785`). D7 says every offer surface is gated (`MergeBoardViewModel.swift:393-397`). Out of scope here; V9 keeps a remote file from widening it. Flagged for the owner.
