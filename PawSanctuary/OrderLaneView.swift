//
//  OrderLaneView.swift
//  PawSanctuary
//
//  The horizontal order lane that sits beside the task tray
//  (Spec_TaskTrayRedesign_Draft.md, Task 6.6).
//
//  This is the half of the redesign that decides what the band is *for*.
//  TaskStripView mixed orders in with a dozen trackers, so the one thing the
//  player acts on moment to moment competed for space with things they only
//  glance at. The trackers are tiles now; the lane carries orders alone.
//
//  One card per order, not the single "4 active orders" summary that used to
//  stand in for all of them (spec §3.4). Four base slots plus the urgent order
//  is a lane that works at the two-and-a-bit cards a phone shows.
//

import SwiftUI

// ============================================================
// MARK: - SLOT STYLING (shared with the sheet)
// ============================================================

/// The three states an order slot can be in, and what each looks like.
///
/// Extracted so the lane's compact slot and the sheet's full-size
/// `OrderLineSlot` cannot drift apart. Only the colour logic is shared — the
/// two slots are deliberately different components, because a 26pt lane slot
/// that tried to carry the sheet's tier badge and count pill would render them
/// at ~6pt type. Sharing the geometry would have made both worse.
enum OrderSlotState {
    case complete
    case mergeReady
    case waiting

    init(isComplete: Bool, isMergeReady: Bool) {
        self = isComplete ? .complete : (isMergeReady ? .mergeReady : .waiting)
    }

    var background: Color {
        switch self {
        case .complete:   return Color.green.opacity(0.20)
        case .mergeReady: return Color.green.opacity(0.12)
        case .waiting:    return Color.gray.opacity(0.10)
        }
    }

    var border: Color {
        switch self {
        case .complete:   return .green
        case .mergeReady: return Color.green.opacity(0.55)
        case .waiting:    return Color.gray.opacity(0.25)
        }
    }

    /// A line the player cannot act on yet reads back, not broken.
    var isDimmed: Bool { self == .waiting }

    var borderWidth: CGFloat { self == .waiting ? 1 : 1.5 }
}

// ============================================================
// MARK: - COMPACT SLOT
// ============================================================

/// One requested item, sized for the lane. Icon, tint and a completion tick —
/// no tier badge and no per-line count, both of which live in the sheet where
/// there is room to read them.
private struct CompactOrderSlot: View {
    let line: OrderLine
    let isMergeReady: Bool

    private var state: OrderSlotState {
        OrderSlotState(isComplete: line.isComplete, isMergeReady: isMergeReady)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: line.symbol)
                .font(.system(size: 15))
                .foregroundColor(state.isDimmed ? line.tint.opacity(0.45) : line.tint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(state.background))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(state.border, lineWidth: state.borderWidth))

            if line.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Circle().fill(Color.green))
                    .offset(x: 3, y: 3)
            } else if line.count > 1 {
                // The one case where a lane slot still needs a number: two of
                // the same item, where the icon alone cannot say how many are in.
                Text("\(line.fulfilled)/\(line.count)")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .offset(x: 5, y: 4)
            }
        }
        .accessibilityLabel(Text(line.lineDescription
                                 + (line.isComplete ? ", delivered"
                                    : isMergeReady ? ", ready to merge" : "")))
    }
}

// ============================================================
// MARK: - LANE CARD
// ============================================================

private let orderLaneCardWidth: CGFloat = 148

private struct OrderLaneCard: View {
    let order: AdoptionOrder
    let mergeReadyKeys: Set<ChainTierKey>
    /// `nil` for the persistent orders, which have no clock. Populated for the
    /// urgent one so its bar and countdown render.
    var timer: (remaining: Double, duration: Double)? = nil

    private var isReady: Bool { order.isComplete && !order.isClaimed }

    private var timeText: String {
        guard let timer else { return "" }
        let s = Int(max(0, timer.remaining))
        return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }

    /// Under two minutes with the order still unfilled is the only state the
    /// lane shouts about.
    private var isExpiring: Bool {
        guard let timer else { return false }
        return timer.remaining < 120 && !order.isComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: timer == nil ? "heart.fill" : "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundColor(timer == nil
                                     ? Color(red: 0.7, green: 0.25, blue: 0.35)
                                     : .orange)
                Text(order.family.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.20, blue: 0.25))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isReady {
                    Text("Ready")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.green))
                }
            }

            HStack(spacing: 5) {
                ForEach(order.lines.indices, id: \.self) { i in
                    CompactOrderSlot(
                        line: order.lines[i],
                        isMergeReady: mergeReadyKeys.contains(
                            ChainTierKey(chainID: order.lines[i].chainID,
                                         tier: order.lines[i].tier)))
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if let timer {
                VStack(alignment: .leading, spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.10))
                            Capsule()
                                .fill(isExpiring ? Color.red : Color.orange)
                                .frame(width: geo.size.width
                                       * min(max(timer.remaining / max(1, timer.duration), 0), 1))
                        }
                    }
                    .frame(height: 4)
                    Text(timeText)
                        .font(.system(size: 8, weight: isExpiring ? .bold : .regular))
                        .foregroundColor(isExpiring ? .red : .secondary)
                }
            } else if order.wantedCount > 1 {
                // A basket's own description truncates to nonsense at this
                // width -- "a Houndling + a Houndling + a..." tells the player
                // nothing the three slots above have not already shown. The
                // count is the part the slots cannot say at a glance.
                Text("\(order.fulfilled)/\(order.wantedCount) delivered")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(order.orderDescription)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(width: orderLaneCardWidth, height: trayBandHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isReady ? Color.green.opacity(0.10)
                              : Color(red: 1.0, green: 0.94, blue: 0.95))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isReady ? Color.green.opacity(0.55)
                                          : Color(red: 0.7, green: 0.25, blue: 0.35).opacity(0.20),
                                  lineWidth: 1))
        )
    }
}

// ============================================================
// MARK: - LANE
// ============================================================

/// Horizontal lane of daily hand-in tasks and adoption orders, right of the
/// task tray.
///
/// One scroll rather than two lanes (`Spec_DailyHandInTasks.md` D-D): the band
/// has no vertical slack to split, and both card types are things the player
/// acts on rather than glances at, which is exactly what this half of the band
/// is for.
struct OrderLaneView: View {
    var viewModel: MergeBoardViewModel
    @Binding var activeSheet: TaskSheet?

    /// Computed once for the whole lane rather than per card — each card would
    /// otherwise rescan the board and inventory for itself. Same reasoning as
    /// `AdoptionOrderPanelView`.
    private var mergeReadyKeys: Set<ChainTierKey> { viewModel.mergeReadyKeys }
    private var taskCensus: [ChainTierKey: Int] { viewModel.boardTaskCensus }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Lazy for the same reason the strip was: the lane grows with
            // Sanctuary Map upgrades, and only two cards are visible at once.
            LazyHStack(spacing: 8) {
                // Daily tasks lead. They expire at midnight and are the only
                // cards here that take pieces off the board, so they are the
                // ones worth planning the session around.
                //
                // Claimed tasks drop out of the lane entirely
                // (`unclaimedDailyTasks`) — see that property for why. The
                // sheet still shows the whole day.
                ForEach(viewModel.unclaimedDailyTasks) { task in
                    DailyTaskLaneCard(
                        task: task,
                        census: taskCensus,
                        onClaim: { viewModel.claimDailyTask(id: task.id) },
                        onOpenSheet: { activeSheet = .dailyChallenges })
                }
                // The urgent order leads the orders, because it is the only one
                // that can be lost by not looking at it.
                if let urgent = viewModel.urgentOrder {
                    OrderLaneCard(order: urgent,
                                  mergeReadyKeys: mergeReadyKeys,
                                  timer: (viewModel.urgentOrderTimeRemaining, urgentOrderDuration))
                        .onTapGesture { activeSheet = .adoptionOrders }
                }
                ForEach(viewModel.adoptionOrders) { order in
                    OrderLaneCard(order: order, mergeReadyKeys: mergeReadyKeys)
                        .onTapGesture { activeSheet = .adoptionOrders }
                }
            }
            .padding(.trailing, 8)
        }
        .frame(height: trayBandHeight)
    }
}
