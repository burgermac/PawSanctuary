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

/// What each `OrderSlotState` looks like (`Spec_HeldItemOrders.md` §4).
///
/// Orders follow Travel Town's measured highlight (`Triage_ModelOnReferences.md`
/// §2.10 (d)): a muted olive green while a wanted item is held, a vivid lime on
/// every slot of a card whose items are all held. The board tiles that hold the
/// items use the same two greens (`CellView`), so a muted slot matches its muted
/// tile and a vivid slot its vivid tile. Daily hand-in tasks keep their blue.
/// Delivered stays the existing green "Adopted!".
///
/// A held slot also carries a check mark (`showsCheck`, Gossip Harbor's marker),
/// so the state never rests on colour alone.
///
/// Extracted so the lane's compact slot and the sheet's full-size
/// `OrderLineSlot` cannot drift apart. Only the colour logic is shared — the
/// two slots are deliberately different components, because a 26pt lane slot
/// that tried to carry the sheet's tier badge would render it at ~6pt type.
extension OrderSlotState {
    var background: Color {
        switch self {
        case .delivered: return Color.green.opacity(0.20)
        case .ready:     return orderReadyLime
        case .held:      return orderHeldMutedGreen.opacity(0.85)
        case .missing:   return Color.gray.opacity(0.10)
        }
    }

    var border: Color {
        switch self {
        case .delivered: return .green
        case .ready:     return orderReadyLimeBorder
        case .held:      return orderHeldOliveBorder
        case .missing:   return Color.gray.opacity(0.25)
        }
    }

    /// A copy the board does not hold reads back, not broken.
    var isDimmed: Bool { self == .missing }

    var borderWidth: CGFloat {
        switch self {
        case .ready:             return 2
        case .held, .delivered:  return 1.5
        case .missing:           return 1
        }
    }

    /// Held and ready slots wear a small check mark.
    var showsCheck: Bool { self == .held || self == .ready }

    /// Spoken after the item's name: each slot says held or missing.
    var accessibilitySuffix: String {
        switch self {
        case .delivered: return "delivered"
        case .ready:     return "held, ready to deliver"
        case .held:      return "held"
        case .missing:   return "missing"
        }
    }
}

// The order-highlight greens, measured from Travel Town's order cards
// (Triage_ModelOnReferences.md §2.10 (d), ±5 per channel): the slot while a
// wanted item is held is about #7EA23D, and every slot and tile turns about
// #C8F777 once the whole card is held. The three below them are not measured:
// darker edges and text so the pale lime and the olive stay legible on the
// cream card, and the Deliver pill, which the reference shows only as "green".
// Daily hand-in tasks keep their own blue (CellView, DailyTaskLaneView).
let orderHeldMutedGreen  = Color(red: 126.0 / 255, green: 162.0 / 255, blue: 61.0 / 255)   // #7EA23D
let orderReadyLime       = Color(red: 200.0 / 255, green: 247.0 / 255, blue: 119.0 / 255)  // #C8F777
let orderHeldOliveBorder = Color(red: 0.36, green: 0.49, blue: 0.14)
let orderReadyLimeBorder = Color(red: 0.40, green: 0.60, blue: 0.08)
/// Spoken-in-text green for "Ready to deliver!": dark enough on cream.
let orderReadyText       = Color(red: 0.20, green: 0.42, blue: 0.06)
/// The Deliver pill and the slot check mark.
let orderDeliverGreen    = Color(red: 0.16, green: 0.53, blue: 0.20)

/// The check mark a held slot wears in its top corner.
struct OrderSlotCheck: View {
    var size: CGFloat
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size, weight: .heavy))
            .foregroundColor(.white)
            .padding(size * 0.35)
            .background(Circle().fill(orderDeliverGreen))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 0.75))
    }
}

// ============================================================
// MARK: - DELIVER BUTTON (shared with the sheet)
// ============================================================

extension AdoptionOrder {
    /// What delivering this order pays, for the Deliver button's spoken label,
    /// e.g. "40 coins, 2 Dog Tags, 15 XP and 5 Smile Points".
    var deliveryRewardSummary: String {
        var parts: [String] = []
        if rewardCoins > 0 { parts.append("\(rewardCoins) coins") }
        if rewardDogTags > 0 { parts.append("\(rewardDogTags) Dog Tags") }
        parts.append("\(xpPerOrderFulfil) XP")
        if smileValue > 0 { parts.append("\(smileValue) Smile Points") }
        if let material = materialReward, material.amount > 0 {
            parts.append("\(material.amount) material")
        }
        guard parts.count > 1, let last = parts.last else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + last
    }
}

/// The Deliver button (`Spec_HeldItemOrders.md` §4): a green pill that sits on
/// the card's top edge, as Travel Town's GO does (`Triage` §2.10 (d)). The card
/// places it (`.overlay`); a card shows it only when every slot is held. It
/// disables itself the moment it is pressed so a double tap cannot pay twice (the
/// view model re-checks readiness anyway, and a delivered order cannot be
/// delivered again).
struct OrderDeliverButton: View {
    let order: AdoptionOrder
    var compact: Bool = true
    /// Returns whether the delivery went through.
    let onDeliver: () -> Bool

    @State private var isDelivering = false

    var body: some View {
        Button {
            guard !isDelivering else { return }
            isDelivering = true
            SoundManager.shared.playButtonTap()
            HapticManager.shared.lightTap()
            // Refused (the board changed under the card): re-arm, the card will
            // drop the button itself if it is no longer ready.
            if !onDeliver() { isDelivering = false }
        } label: {
            Text("Deliver")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, compact ? 10 : 16)
                .frame(minHeight: compact ? 17 : 24)
                .background(Capsule().fill(orderDeliverGreen.opacity(isDelivering ? 0.45 : 1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isDelivering)
        .accessibilityLabel(Text("Deliver to \(order.family.name). Pays \(order.deliveryRewardSummary)."))
    }
}

// ============================================================
// MARK: - COMPACT SLOT
// ============================================================

/// One requested copy, sized for the lane. Icon, tint and a completion tick —
/// no tier badge, which lives in the sheet where there is room to read it.
private struct CompactOrderSlot: View {
    let line: OrderLine
    let state: OrderSlotState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: line.symbol)
                .font(.system(size: 15))
                .foregroundColor(state.isDimmed ? line.tint.opacity(0.45) : line.tint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(state.background))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(state.border, lineWidth: state.borderWidth))

            if state == .delivered {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Circle().fill(Color.green))
                    .offset(x: 3, y: 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            if state.showsCheck {
                OrderSlotCheck(size: 6).offset(x: 4, y: -4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(line.tierName), \(state.accessibilitySuffix)"))
    }
}

// ============================================================
// MARK: - LANE CARD
// ============================================================

private let orderLaneCardWidth: CGFloat = 148

struct OrderLaneCard: View {
    let order: AdoptionOrder
    /// The live board census (`MergeBoardViewModel.boardTaskCensus`), computed
    /// once for the whole lane.
    let census: [ChainTierKey: Int]
    /// `nil` for the persistent orders, which have no clock. Populated for the
    /// urgent one so its bar and countdown render.
    var timer: (remaining: Double, duration: Double)? = nil
    let onDeliver: () -> Bool

    private var canDeliver: Bool { timer.map { $0.remaining > 0 } ?? true }
    private var slots: [OrderSlot] { order.slots(census: census, canDeliver: canDeliver) }
    /// Every copy held and still deliverable: vivid, and the button shows.
    private var isReady: Bool {
        !order.isClaimed && canDeliver && order.isReady(census: census)
    }

    private var timeText: String {
        guard let timer else { return "" }
        let s = Int(max(0, timer.remaining))
        return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }

    /// Under two minutes with the order still undelivered is the only state the
    /// lane shouts about.
    private var isExpiring: Bool {
        guard let timer else { return false }
        return timer.remaining < 120 && !order.isComplete
    }

    var body: some View {
        let slots = self.slots
        let isReady = self.isReady
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
                if order.isClaimed {
                    Text("Adopted!")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.green))
                }
            }
            // Leaves the top-trailing corner to the Deliver pill when it shows.
            .padding(.trailing, isReady ? 50 : 0)

            HStack(spacing: 5) {
                ForEach(slots.indices, id: \.self) { i in
                    CompactOrderSlot(line: order.lines[slots[i].lineIndex],
                                     state: slots[i].state)
                        .reportTutorialFrame(.orderHeldSlot(order.id),
                                             enabled: i == slots.firstHeldIndex)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if let timer {
                // The urgent clock keeps its bar whether or not the card is
                // ready: the Deliver pill sits on the top edge, not down here.
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
            } else if isReady {
                Text("Ready to deliver!")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(orderReadyText)
                    .lineLimit(1)
            } else if order.isAlmostThere(census: census) {
                // The family speaking (Spec_TravelTownReview_Draft.md §5): with
                // one item left to put on the board, the count is replaced by a
                // nudge in their colour. The slots above show which one is missing.
                Label("Almost there!", systemImage: "bubble.left.fill")
                    .font(.system(size: 9, weight: .bold))
                    .italic()
                    .foregroundColor(order.family.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if order.wantedCount > 1 && !order.isClaimed {
                // A basket's own description truncates to nonsense at this
                // width; the count is the part the slots cannot say at a glance.
                Text("\(slots.filter { $0.state != .missing }.count)/\(order.wantedCount) on the board")
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
        .reportOrderCardFrame(order.id)
        .background(
            // The cream base is always drawn, with the state tint over it: the
            // card's text is fixed dark, so a tint over a dark-mode background
            // alone would leave it unreadable.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 1.0, green: 0.94, blue: 0.95))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .fill(order.isClaimed ? Color.green.opacity(0.10)
                          : isReady ? orderReadyLime.opacity(0.35)
                          : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(order.isClaimed ? Color.green.opacity(0.55)
                                  : isReady ? orderReadyLimeBorder
                                  : Color(red: 0.7, green: 0.25, blue: 0.35).opacity(0.20),
                                  lineWidth: isReady ? 1.5 : 1))
        )
        // The Deliver pill on the card's top edge. Inside the card, flush with
        // the edge: the lane is a scroll view exactly as tall as its cards, so
        // anything hanging above the edge would be clipped.
        .overlay(alignment: .topTrailing) {
            if isReady {
                OrderDeliverButton(order: order, onDeliver: onDeliver)
                    .reportTutorialFrame(.deliverPill(order.id))
                    .id(order.id)
                    .padding(.top, 2)
                    .padding(.trailing, 7)
            }
        }
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
    /// The order a coach mark is about: the lane scrolls to it, because orders
    /// sit after the quest and daily cards and are usually off screen.
    var scrollToOrderID: UUID? = nil

    /// Computed once for the whole lane rather than per card — each card would
    /// otherwise rescan the board for itself. Daily tasks and orders read the
    /// same census: one rule for held items (D14).
    private var taskCensus: [ChainTierKey: Int] { viewModel.boardTaskCensus }

    var body: some View {
        let taskCensus = self.taskCensus
        ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
            // Lazy for the same reason the strip was: the lane grows with
            // Sanctuary Map upgrades, and only two cards are visible at once.
            LazyHStack(spacing: 8) {
                // Standing quests lead, claimable first, so they sit next to
                // the tray (Spec_QuestLaneCards_Draft.md). Claiming replaces
                // the quest in place, so there is no claimed state here.
                ForEach(laneOrderedQuests(viewModel.activeQuests)) { quest in
                    QuestLaneCard(
                        quest: quest,
                        onClaim: { viewModel.claimQuest(id: quest.id) },
                        onOpenSheet: { activeSheet = .quests })
                }
                // Daily tasks follow. They expire at midnight and are the only
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
                        // Keyed so a coach mark can scroll the lane to this card.
                        .id(task.id)
                }
                // The urgent order leads the orders, because it is the only one
                // that can be lost by not looking at it.
                if let urgent = viewModel.urgentOrder {
                    OrderLaneCard(order: urgent,
                                  census: taskCensus,
                                  timer: (viewModel.urgentOrderTimeRemaining, urgentOrderDuration),
                                  onDeliver: { viewModel.deliverUrgentOrder() })
                        // Keyed by order so a fresh urgent order gets a fresh
                        // (re-armed) Deliver button.
                        .id(urgent.id)
                        .onTapGesture { activeSheet = .adoptionOrders }
                }
                ForEach(viewModel.adoptionOrders) { order in
                    OrderLaneCard(order: order, census: taskCensus,
                                  onDeliver: { viewModel.deliverOrder(id: order.id) })
                        .id(order.id)
                        .onTapGesture { activeSheet = .adoptionOrders }
                }
            }
            .padding(.trailing, 8)
        }
        .onChange(of: scrollToOrderID) { _, id in
            guard let id else { return }
            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .center) }
        }
        }
        .frame(height: trayBandHeight)
    }
}
