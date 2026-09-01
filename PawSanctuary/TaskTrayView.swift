//
//  TaskTrayView.swift
//  PawSanctuary
//
//  The collapsing task tray that replaces TaskStripView's horizontal strip
//  (Spec_TaskTrayRedesign_Draft.md). A 3-wide grid of small tracker tiles that
//  collapses to 1-wide by horizontal translation, scrolling freely inside a
//  fixed two-row viewport.
//
//  Task 6.2 lands the tile primitive only. The container (6.3), the tile
//  content (6.4, 6.5) and the order lane (6.6) follow.
//

import SwiftUI

// ============================================================
// MARK: - GEOMETRY
// ============================================================

/// Edge of one tray tile. 40pt is not a taste call — it is what the vertical
/// budget allows. The board sits exactly at its own `csW`/`csH` crossover
/// (spec §2.1), so the tray is paid for entirely out of the header flattening
/// in Task 6.1, which freed ~19pt. Two rows of 40pt tiles plus padding come to
/// ~98pt against a ~116pt budget; the reference's own ~56pt tiles would need
/// ~150pt and would cost roughly 4pt off every board cell.
let trayTileSize: CGFloat = 40

/// Height of the status strip inset along the bottom of a tile.
private let trayStatusHeight: CGFloat = 7

/// A countdown at or below this share of its window counts as `.endingSoon`
/// for ordering (spec §3.12). A threshold rather than a continuous score is
/// the whole point — it is what stops tiles drifting past each other as bars
/// tick.
private let trayEndingSoonFraction: Double = 0.25

// ============================================================
// MARK: - TILE STATUS
// ============================================================

/// What a tile shows below its icon.
///
/// There is no countdown-as-text case, and that is deliberate. At 40pt a
/// legible inset label holds about four characters — enough for `7/12` or
/// `0/3`, nowhere near enough for `16h 29m`, which would need roughly 7pt
/// type. Rather than abbreviate to `16h` and lose the minutes, or give
/// countdown tiles a taller external pill and break the uniform grid that
/// makes collapse a single translation, countdowns render as a bar that
/// drains (spec §3.11).
enum TrayTileStatus: Equatable {
    /// No status strip — the icon alone.
    case none

    /// Progress being earned, filling left to right. `fraction` is clamped 0...1.
    case progress(Double)

    /// Time draining away, emptying right to left. `fraction` is the share of
    /// the interval **remaining**, clamped 0...1, so a full bar means the whole
    /// window is still ahead.
    ///
    /// Tinted differently from `.progress` on purpose: two adjacent tiles, one
    /// filling and one draining, should not speak the same visual language.
    case countdown(Double)

    /// At most four characters — `7/12`, `0/3`, `×3`. Longer strings scale down
    /// rather than truncate, but the caller should not be relying on that.
    case label(String)
}

// ============================================================
// MARK: - TILE
// ============================================================

/// One tray tile: an icon, an optional inset status strip, an optional badge.
///
/// Pure presentation — it takes plain values and holds no view-model
/// reference, so it can be laid out and reasoned about without the game
/// running. Tap handling belongs to whatever mounts it.
struct TrayTileView: View {
    let icon: String
    let tint: Color
    var status: TrayTileStatus = .none
    /// Red dot in the top-trailing corner — "there is something to collect here".
    var showsBadge: Bool = false
    /// Spoken description. The tile is icon-only by design, so without this it
    /// is silent to VoiceOver.
    let accessibilityText: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(tint.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1))

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(tint)
                Spacer(minLength: 0)
                statusStrip
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
        .frame(width: trayTileSize, height: trayTileSize)
        .overlay(alignment: .topTrailing) {
            if showsBadge {
                Circle()
                    .fill(Color(red: 0.85, green: 0.20, blue: 0.15))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .offset(x: 3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: Status strip

    @ViewBuilder
    private var statusStrip: some View {
        switch status {
        case .none:
            EmptyView()

        case .progress(let fraction):
            bar(fraction: fraction,
                fill: LinearGradient(colors: [tint.opacity(0.75), tint],
                                     startPoint: .leading, endPoint: .trailing))

        case .countdown(let fraction):
            // Amber, and draining rather than filling, so it does not read as
            // progress earned (spec §3.11).
            bar(fraction: fraction,
                fill: LinearGradient(
                    colors: [Color(red: 0.95, green: 0.72, blue: 0.20),
                             Color(red: 0.90, green: 0.55, blue: 0.10)],
                    startPoint: .leading, endPoint: .trailing))

        case .label(let text):
            Text(text)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity)
                .frame(height: 12)
                .background(Capsule().fill(tint.opacity(0.85)))
        }
    }

    private func bar(fraction: Double, fill: LinearGradient) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.12))
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * fraction.clampedToUnitInterval)
            }
        }
        .frame(height: trayStatusHeight)
        .animation(.easeInOut(duration: 0.3), value: fraction)
    }

    private var accessibilityValue: String {
        switch status {
        case .none:                  return ""
        case .progress(let f):       return "\(Int((f.clampedToUnitInterval * 100).rounded())) percent complete"
        case .countdown(let f):      return "\(Int((f.clampedToUnitInterval * 100).rounded())) percent of the time remaining"
        case .label(let text):       return text
        }
    }
}

private extension Double {
    /// Bars are fed from live countdowns and progress counters, both of which
    /// can momentarily overshoot their own bounds (a timer read a tick after
    /// expiry, a counter past its goal before the claim lands). Clamp at the
    /// point of use rather than trusting every call site.
    var clampedToUnitInterval: Double {
        if isNaN { return 0 }
        return Swift.min(Swift.max(self, 0), 1)
    }
}

// ============================================================
// MARK: - TILE MODEL
// ============================================================

/// How much a tile wants looking at. Coarse on purpose — see `TrayTile.rank`.
enum TrayUrgency: Int {
    /// Something is waiting to be collected. Always paired with the badge.
    case claimable = 0
    /// A window is about to close.
    case endingSoon = 1
    /// Progress is under way but nothing is due.
    case active = 2
    /// Nothing is happening here.
    case idle = 3
}

/// One entry in the tray. A value plus its tap action, so the grid can be
/// built as data and the container stays free of per-tracker branching.
struct TrayTile: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    var status: TrayTileStatus = .none
    var showsBadge: Bool = false
    var urgency: TrayUrgency = .idle
    let accessibilityText: String
    let action: () -> Void

    /// The badge and the top rank are the same fact, so one derives from the
    /// other rather than each call site having to keep them in step.
    var rank: TrayUrgency { showsBadge ? .claimable : urgency }
}

// ============================================================
// MARK: - CONTAINER GEOMETRY
// ============================================================

private let trayColumns      = 3
private let trayTileSpacing:  CGFloat = 8
private let trayRowSpacing:   CGFloat = 6
private let trayPanelPadH:    CGFloat = 6
private let trayPanelPadV:    CGFloat = 6
/// The tab down the leading edge carrying the position dots — also the handle
/// that toggles the tray.
private let trayHandleWidth:  CGFloat = 14

private let trayVisibleRows = 2
private let trayColumnPitch  = trayTileSize + trayTileSpacing
private let trayGridWidth    = CGFloat(trayColumns) * trayTileSize
                             + CGFloat(trayColumns - 1) * trayTileSpacing
private let trayViewportH    = CGFloat(trayVisibleRows) * trayTileSize
                             + CGFloat(trayVisibleRows - 1) * trayRowSpacing

/// Total height of the tray band. ~98pt against the ~116pt the header
/// flattening freed (spec §2.2, §2.3) — the board pays nothing.
let trayBandHeight = trayViewportH + trayPanelPadV * 2

// ============================================================
// MARK: - CONTAINER
// ============================================================

/// The collapsing tray. Three tiles wide when open, one when shut, scrolling
/// freely through however many rows the tile list makes.
///
/// **Collapse is a translation, not a second view** (spec §1.2, §3.1). The
/// grid is always laid out at its full three-column width; collapsing shifts
/// it left by two column pitches and narrows the clip so column 3 lands at the
/// leading edge. That is what the reference does, and doing it any other way
/// means keeping two layouts in sync and losing the scroll position across the
/// transition.
///
/// **Column 1 survives, where the reference keeps column 3** (spec §3.1,
/// reversed by §8.6). Tiles are urgency-sorted, so the collapsed pair is
/// positions 1 and 4 — the two most wanting attention. Keeping column 3 put
/// positions 3 and 6 on screen, which meant a claimable, badged tile could sit
/// invisible while the tray was shut; the sort and the reference's collapse
/// were individually reasonable and jointly wrong.
struct TaskTrayView: View {
    var viewModel: MergeBoardViewModel
    @Binding var activeSheet: TaskSheet?
    /// Parallel Board presents full-screen rather than as a sheet — same
    /// reasoning as the card it replaces (Phase 6b, Task 3.7).
    @Binding var showParallelBoard: Bool
    /// The Reward Ladder tile taps through to the Shop, where the ladder
    /// actually lives (`RewardLadderSection`). `SheetRoute` is private to
    /// MergeBoardView.swift, so the caller supplies the hop.
    var onOpenShop: () -> Void

    /// Owned by `MergeBoardView` (as `@AppStorage`, so it is still a
    /// UserDefaults preference rather than a `GameState` field — spec §6.3,
    /// §7). It lives up there rather than here because touching the board has
    /// to be able to collapse the tray, and the board is the parent's.
    @Binding var isExpanded: Bool

    @State private var scrollOffset: CGFloat = 0

    private let scrollSpace = "taskTrayScroll"

    var body: some View {
        HStack(spacing: 0) {
            handle
            grid
        }
        .frame(height: trayBandHeight)
        // Swipe left to shut, right to open, anywhere on the tray.
        //
        // `simultaneousGesture` rather than `gesture`: the grid inside scrolls
        // vertically, and claiming the drag outright would kill that. Both
        // recognisers see the touch, and the dominance test below decides which
        // one meant it — a swipe has to be twice as horizontal as it is
        // vertical to count, so a slightly slanted scroll does not slam the
        // tray shut mid-flick.
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    guard abs(dx) > abs(dy) * 2 else { return }
                    setExpanded(dx > 0)
                }
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.90, green: 0.93, blue: 0.90))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(red: 0.42, green: 0.52, blue: 0.42).opacity(0.28),
                                  lineWidth: 1))
        )
    }

    // MARK: Handle + position dots

    /// Every route in and out of the collapsed state goes through here — the
    /// handle, either swipe, and the board's auto-collapse — so they cannot
    /// drift apart on timing. The no-op guard keeps a swipe in the direction
    /// the tray is already in from replaying the animation.
    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(.easeInOut(duration: 0.28)) { isExpanded = expanded }
    }

    private var handle: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            VStack(spacing: 4) {
                if isExpanded && dotCount > 1 {
                    ForEach(0..<dotCount, id: \.self) { i in
                        Circle()
                            .fill(i == activeDot
                                  ? Color(red: 0.30, green: 0.62, blue: 0.35)
                                  : Color.black.opacity(0.18))
                            .frame(width: 5, height: 5)
                    }
                } else {
                    Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.42, green: 0.52, blue: 0.42))
                }
            }
            .frame(width: trayHandleWidth, height: trayBandHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse task tray" : "Expand task tray")
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(trayTileSize),
                                                         spacing: trayTileSpacing),
                                     count: trayColumns),
                      spacing: trayRowSpacing) {
                ForEach(tiles) { tile in
                    Button(action: tile.action) {
                        TrayTileView(icon: tile.icon,
                                     tint: tile.tint,
                                     status: tile.status,
                                     showsBadge: tile.showsBadge,
                                     accessibilityText: tile.accessibilityText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: trayGridWidth)
            // The project already uses onGeometryChange unguarded elsewhere
            // (MergeBoardView), so this follows existing practice rather than
            // reaching for the iOS 18 scroll-geometry APIs.
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .named(scrollSpace)).minY
            } action: { scrollOffset = $0 }
        }
        .coordinateSpace(.named(scrollSpace))
        .frame(width: trayGridWidth, height: trayViewportH)
        // Narrowing the frame with `.leading` alignment is what keeps column 1
        // on screen when shut: the grid holds its full three-column width and
        // overflows past the clip on the trailing side.
        //
        // Column 1, not the reference's column 3 (spec §3.1, reversed by §8.6).
        // Tiles are urgency-sorted, so position 1 is the thing most wanting
        // attention; collapsing to column 3 showed positions 3 and 6 and put
        // the badged, claimable tile off screen — the sort was defeated in the
        // state the tray is in most of the time. Column 1 makes the resting
        // pair positions 1 and 4.
        //
        // This deliberately does NOT use `.offset`. An offset moves rendering
        // only -- layout and hit-testing stay where they were -- so the
        // collapsed tray drew column 3 at the leading edge while its tap
        // target sat two columns to the right, and the invisible column 2
        // target answered touches over the visible tile. Frame alignment moves
        // the layout, so touches land where the tile is drawn.
        .frame(width: isExpanded ? trayGridWidth : trayTileSize, alignment: .leading)
        .clipped()
        // `.clipped()` clips drawing but not hit-testing, which would leave the
        // off-screen columns still touchable beside the collapsed tray.
        .contentShape(Rectangle())
        .padding(.vertical, trayPanelPadV)
        .padding(.trailing, trayPanelPadH)
    }

    // MARK: Scroll position

    private var rowCount: Int {
        max(1, Int(ceil(Double(tiles.count) / Double(trayColumns))))
    }

    /// One dot per resting position, not per page: `rows − visible + 1`
    /// (spec §1.4). Four rows in a two-row viewport gives three.
    private var dotCount: Int { max(1, rowCount - trayVisibleRows + 1) }

    private var activeDot: Int {
        let contentH = CGFloat(rowCount) * trayTileSize
                     + CGFloat(max(0, rowCount - 1)) * trayRowSpacing
        let maxScroll = contentH - trayViewportH
        guard maxScroll > 0, dotCount > 1 else { return 0 }
        let progress = min(max(-scrollOffset / maxScroll, 0), 1)
        return Int((progress * Double(dotCount - 1)).rounded())
    }

    // MARK: Tiles

    /// Every tile the tray can show (spec §5).
    ///
    /// Declaration order here is the tiebreak, so it doubles as the resting
    /// order when nothing is urgent. Keep it stable.
    ///
    /// Three groups, in order. The two **claim** tiles first — they are pure
    /// "collect this", they always rank `.claimable`, and they vanish the
    /// moment they are used. Then the **conditionals**, transient because an
    /// event or a Parallel Board window closes. Then the **standing**
    /// trackers, which will still be there tomorrow.
    private var catalogue: [TrayTile] {
        ([passDailyTile].compactMap { $0 } + trioTiles)
        + eventTiles
        + [parallelBoardTile, rewardLadderTile, loyaltyTile, inviteTile].compactMap { $0 }
        + [levelTile, freeChestTile, spotlightTile, questsTile, dailiesTile,
           smileTile, careTile, weeklyTile, monthlyTile]
    }

    // MARK: Claim tiles (Task 6.5)

    /// The Sanctuary Pass daily kibble.
    ///
    /// This used to be `PassDailyClaimView`, an entire conditional strip
    /// inserted between the HUD and the board. That was fine when the band
    /// below was a scrolling strip; it is not fine now that the band is a
    /// fixed height the board is budgeted against (spec §2), because the strip
    /// appearing would have pushed the board down every time the claim came
    /// up. As a tile it costs nothing — the grid already scrolls.
    private var passDailyTile: TrayTile? {
        guard viewModel.canClaimPassDaily else { return nil }
        return TrayTile(
            id: "passDaily",
            icon: "medal.fill",
            tint: Color(red: 0.6, green: 0.2, blue: 0.8),
            status: .label("+\(passDailyKibble)"),
            showsBadge: true,
            accessibilityText: "Sanctuary Pass daily kibble, \(passDailyKibble) to claim",
            action: { viewModel.claimPassDaily() })
    }

    /// One per exchangeable ambassador trio. The only tiles that act on the
    /// board rather than opening something, so tapping one claims it outright
    /// — which is also why they carry no progress: a trio either exists and is
    /// worth coins, or it is not in the list at all.
    private var trioTiles: [TrayTile] {
        viewModel.exchangeableTrios.map { trio in
            TrayTile(id: "trio-\(trio.id)",
                     icon: "medal.fill",
                     tint: Color(red: 0.85, green: 0.55, blue: 0.08),
                     status: .label("×\(trio.positions.count)"),
                     showsBadge: true,
                     accessibilityText: "Exchange \(trio.positions.count) ambassador "
                                      + "\(trio.species.name) for "
                                      + "\(viewModel.ambassadorTrioValue(trio)) coins",
                     action: { viewModel.exchangeAmbassadorTrio(trio) })
        }
    }

    /// Sorted by urgency (spec §3.12).
    ///
    /// Collapse keeps column 3, so the two tiles on screen at rest are
    /// whichever land in the trailing column — ordering is what decides the
    /// default view. Sorting is by the four coarse ranks rather than a
    /// continuous score, with declaration order breaking ties: a tile moves
    /// only when it crosses a rank boundary, which is a real change of state,
    /// instead of drifting every time a bar ticks under the player's thumb.
    private var tiles: [TrayTile] {
        catalogue.enumerated()
            .sorted { lhs, rhs in
                let a = lhs.element.rank.rawValue, b = rhs.element.rank.rawValue
                return a == b ? lhs.offset < rhs.offset : a < b
            }
            .map(\.element)
    }

    // MARK: Conditional tiles (Task 6.4)

    /// A tile carrying both a progress bar and a deadline gets the **bar**, and
    /// the deadline drives its rank instead.
    ///
    /// Events and the Parallel Board are the only tiles with both, and there is
    /// one status slot. Progress is the part the player can act on, so it takes
    /// the slot; the countdown is not lost, it just expresses itself by pushing
    /// the tile up the tray as the window closes (`.endingSoon`). A shown
    /// countdown would have been the more literal reading of the reference, but
    /// it would have hidden the only number the player can change.
    private func deadlineRank(remaining: TimeInterval, total: TimeInterval) -> TrayUrgency {
        guard total > 0 else { return .active }
        return remaining / total <= trayEndingSoonFraction ? .endingSoon : .active
    }

    private var eventTiles: [TrayTile] {
        viewModel.activeEvents.map { event in
            let maxTokens = ProgressTrackRegistry.tracks[event.id]?.last?.threshold ?? 1
            let earned = viewModel.progressTrack.progress(trackID: event.id)
            let window = event.endDate.timeIntervalSince(event.startDate)
            return TrayTile(
                id: "event-\(event.id)",
                icon: event.icon,
                tint: event.accentColor,
                status: .progress(Double(earned) / Double(max(1, maxTokens))),
                showsBadge: !viewModel.progressTrack.claimable(trackID: event.id,
                                                               paidLaneUnlocked: false).isEmpty,
                urgency: deadlineRank(remaining: event.timeRemaining, total: window),
                accessibilityText: "\(event.name), \(event.timerLabel)",
                action: { activeSheet = .event(event.id) })
        }
    }

    private var parallelBoardTile: TrayTile? {
        guard let coordinator = viewModel.activeParallelBoardEvent,
              let event = ParallelBoardEventRegistry.activeEvent(),
              event.id == coordinator.eventID else { return nil }
        let maxTokens = ProgressTrackRegistry.tracks[event.id]?.last?.threshold ?? 1
        let earned = coordinator.progressTrack.progress(trackID: event.id)
        let window = event.endDate.timeIntervalSince(event.startDate)
        return TrayTile(
            id: "parallelBoard-\(event.id)",
            icon: event.icon,
            tint: Color(red: 0.28, green: 0.44, blue: 0.68),
            status: .progress(Double(earned) / Double(max(1, maxTokens))),
            showsBadge: !coordinator.progressTrack.claimable(trackID: event.id,
                                                             paidLaneUnlocked: false).isEmpty,
            urgency: deadlineRank(remaining: event.timeRemaining, total: window),
            accessibilityText: "\(event.name), \(event.timerLabel)",
            action: { showParallelBoard = true })
    }

    private var rewardLadderTile: TrayTile? {
        guard viewModel.isRewardLadderAvailable else { return nil }
        let rungs = ProgressTrackRegistry.tracks[rewardLadderTrackID]?.count ?? 0
        let progress = viewModel.progressTrack.progress(trackID: rewardLadderTrackID)
        return TrayTile(
            id: "rewardLadder",
            icon: "arrow.up.right.square.fill",
            tint: Color(red: 0.55, green: 0.25, blue: 0.75),
            status: .label("\(progress)/\(max(1, rungs))"),
            showsBadge: !viewModel.progressTrack.claimable(trackID: rewardLadderTrackID,
                                                           paidLaneUnlocked: false).isEmpty,
            urgency: progress > 0 ? .active : .idle,
            accessibilityText: "Reward ladder, rung \(progress) of \(rungs)",
            action: onOpenShop)
    }

    private var loyaltyTile: TrayTile? {
        guard viewModel.isLoyaltyClubUnlocked else { return nil }
        let cycle = max(1, loyaltyClubCycle.count)
        let day = viewModel.loyaltyClubDayIndex % cycle
        return TrayTile(
            id: "loyalty",
            icon: "calendar.badge.plus",
            tint: Color(red: 0.20, green: 0.55, blue: 0.55),
            status: .label("\(day + 1)/\(cycle)"),
            showsBadge: viewModel.canClaimLoyaltyClub,
            // A streak is only worth something while it is unbroken, so a
            // running one ranks above an untouched cycle.
            urgency: viewModel.loyaltyClubStreak > 0 ? .active : .idle,
            accessibilityText: "Loyalty club, day \(day + 1) of \(cycle)",
            action: { activeSheet = .loyalty })
    }

    private var inviteTile: TrayTile? {
        guard viewModel.isInviteUnlocked else { return nil }
        let sent = viewModel.inviteProgress.invitesSent
        let target = inviteMilestones.map(\.invitesRequired).max() ?? 1
        return TrayTile(
            id: "invite",
            icon: "person.2.fill",
            tint: Color(red: 0.30, green: 0.50, blue: 0.80),
            status: .progress(Double(sent) / Double(max(1, target))),
            showsBadge: inviteMilestones.contains { viewModel.inviteProgress.canClaim($0) },
            urgency: sent > 0 ? .active : .idle,
            accessibilityText: "Invite friends, \(sent) of \(target) sent",
            action: { activeSheet = .invite })
    }

    // MARK: Always-present tiles

    private var levelTile: TrayTile {
        TrayTile(id: "level",
                 icon: "star.circle.fill",
                 tint: Color(red: 0.20, green: 0.55, blue: 0.30),
                 status: .progress(viewModel.xpProgressFraction),
                 urgency: viewModel.xpProgressFraction > 0 ? .active : .idle,
                 accessibilityText: "Level \(viewModel.playerLevel) progress",
                 action: { activeSheet = nil })
    }

    private var freeChestTile: TrayTile {
        let total = freeChestCooldownHours * 3600
        let remaining = viewModel.freeChestTimeRemaining / total
        return TrayTile(id: "freeChest",
                        icon: "shippingbox.fill",
                        tint: Color(red: 0.72, green: 0.52, blue: 0.15),
                        status: viewModel.isFreeChestReady
                                ? .label("Open")
                                : .countdown(remaining),
                        showsBadge: viewModel.isFreeChestReady,
                        // A chest nearly off cooldown is worth surfacing before
                        // it is claimable, so the player sees it coming rather
                        // than only after it has been sitting there.
                        urgency: remaining <= trayEndingSoonFraction ? .endingSoon : .idle,
                        accessibilityText: "Free chest",
                        action: { viewModel.claimOrSkipFreeChest() })
    }

    private var spotlightTile: TrayTile {
        TrayTile(id: "spotlight",
                 icon: "sparkles",
                 tint: Color(red: 0.78, green: 0.55, blue: 0.10),
                 status: .progress(viewModel.spotlightProgressFraction),
                 urgency: viewModel.spotlightProgressFraction > 0 ? .active : .idle,
                 accessibilityText: "Spotlight progress",
                 action: { activeSheet = .dailyChallenges })
    }

    /// One tile for the whole quest set, not one per quest — forced by the
    /// 40pt tile (spec §3.6), and what the reference does too (§1.6).
    private var questsTile: TrayTile {
        let done = viewModel.activeQuests.filter(\.isComplete).count
        let total = max(1, viewModel.activeQuests.count)
        return TrayTile(id: "quests",
                        icon: "target",
                        tint: Color(red: 0.18, green: 0.48, blue: 0.22),
                        status: .label("\(done)/\(total)"),
                        showsBadge: done > 0,
                        urgency: .active,
                        accessibilityText: "Quests, \(done) of \(total) complete",
                        action: { activeSheet = .quests })
    }

    private var dailiesTile: TrayTile {
        let done = viewModel.dailyChallenges.filter(\.isComplete).count
        let total = max(1, viewModel.dailyChallenges.count)
        return TrayTile(id: "dailies",
                        icon: "checklist",
                        tint: Color(red: 0.28, green: 0.44, blue: 0.68),
                        status: .label("\(done)/\(total)"),
                        showsBadge: done > 0,
                        urgency: .active,
                        accessibilityText: "Daily challenges, \(done) of \(total) complete",
                        action: { activeSheet = .dailyChallenges })
    }

    private var smileTile: TrayTile {
        TrayTile(id: "smile",
                 icon: "face.smiling.fill",
                 tint: Color(red: 0.90, green: 0.55, blue: 0.20),
                 status: .progress(Double(viewModel.smilePointsBanked) / Double(smilePointsGoal)),
                 showsBadge: viewModel.isSmileBundleReady,
                 urgency: viewModel.smilePointsBanked > 0 ? .active : .idle,
                 accessibilityText: "Smile points, \(viewModel.smilePointsBanked) of \(smilePointsGoal)",
                 action: { viewModel.claimSmileBundle() })
    }

    private var careTile: TrayTile {
        // Past Gold there is no next tier, so the bar reads full rather than
        // dividing by a threshold that no longer exists.
        let fraction: Double
        if let next = viewModel.nextCarePointTier {
            fraction = Double(viewModel.carePointsThisWeek) / Double(max(1, next.pointsNeeded))
        } else {
            fraction = 1
        }
        return TrayTile(id: "care",
                        icon: "heart.fill",
                        tint: Color(red: 0.80, green: 0.30, blue: 0.35),
                        status: .progress(fraction),
                        showsBadge: !viewModel.claimableCarePointTiers.isEmpty,
                        urgency: viewModel.carePointsThisWeek > 0 ? .active : .idle,
                        accessibilityText: "Care points, \(viewModel.carePointsThisWeek) this week",
                        action: { activeSheet = .carePoints })
    }

    private var weeklyTile: TrayTile {
        // `weeklyGoalReached` is a (bronze, silver, gold) tuple, so the badge
        // is "a tier is reached and still unclaimed" rather than the tuple
        // itself -- the badge means there is something to collect, not that a
        // threshold was passed at some point this week.
        let reached = viewModel.weeklyGoalReached
        let claimable = (reached.bronze && !viewModel.weeklyGoalBronzeClaimed)
                     || (reached.silver && !viewModel.weeklyGoalSilverClaimed)
                     || (reached.gold   && !viewModel.weeklyGoalGoldClaimed)
        return TrayTile(id: "weekly",
                        icon: "calendar",
                        tint: Color(red: 0.35, green: 0.45, blue: 0.75),
                        status: .progress(Double(viewModel.coinsEarnedThisWeek)
                                          / Double(max(1, viewModel.effectiveWeeklyGoldTarget))),
                        showsBadge: claimable,
                        urgency: viewModel.coinsEarnedThisWeek > 0 ? .active : .idle,
                        accessibilityText: "Weekly goal",
                        action: { activeSheet = .weeklyGoal })
    }

    private var monthlyTile: TrayTile {
        TrayTile(id: "monthly",
                 icon: "calendar.badge.clock",
                 tint: Color(red: 0.50, green: 0.35, blue: 0.70),
                 status: .label("\(viewModel.weeklyGoldCompletions)/\(viewModel.monthlyGoalWeeksRequired)"),
                 showsBadge: viewModel.monthlyGoalReached,
                 urgency: viewModel.weeklyGoldCompletions > 0 ? .active : .idle,
                 accessibilityText: "Monthly goal",
                 action: { activeSheet = .monthlyGoal })
    }
}
