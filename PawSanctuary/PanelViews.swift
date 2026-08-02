//
//  PanelViews.swift
//  PawSanctuary
//
//  Login reward, spotlight banner, rescue requests, daily challenges, quests.
//

import SwiftUI

// ============================================================
// MARK: - LOGIN REWARD
// ============================================================

struct LoginRewardView: View {
    var viewModel: MergeBoardViewModel

    var rewardIndex: Int { max(0, min(viewModel.loginStreakDay - 1, loginDailyRewards.count - 1)) }
    var todayReward: (kibble: Int, dogTags: Int, label: String) { loginDailyRewards[rewardIndex] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Label("Good Morning!", systemImage: "sunrise.fill")
                    .font(.title.bold()).foregroundColor(.white)
                Text("Day \(viewModel.loginStreakDay) Reward")
                    .font(.subheadline).foregroundColor(.white.opacity(0.8))

                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { day in
                        let dayNum = day + 1
                        let isCur  = dayNum == viewModel.loginStreakDay
                        let isPast = dayNum  < viewModel.loginStreakDay
                        let reward = loginDailyRewards[day]
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isCur ? Color.yellow : isPast ? Color.green.opacity(0.7) : Color.white.opacity(0.2))
                                    .frame(width: 38, height: 38)
                                if isPast {
                                    Text("✓").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                } else if isCur {
                                    Image(systemName: "sparkles").font(.system(size: 16))
                                } else {
                                    Text("\(dayNum)").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.5))
                                }
                            }
                            Text(reward.label)
                                .font(.system(size: 7))
                                .foregroundColor(isCur ? .yellow : .white.opacity(0.5))
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("Today's Reward").font(.headline).foregroundColor(.white)
                    HStack(spacing: 20) {
                        if todayReward.kibble > 0 {
                            VStack {
                                Image(systemName: "pawprint").font(.title2)
                                Text("+\(todayReward.kibble) Kibble")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        if todayReward.dogTags > 0 {
                            VStack {
                                Image(systemName: "tag.fill").font(.title2)
                                Text("+\(todayReward.dogTags) Tags")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))

                Button(action: { viewModel.claimLoginReward() }) {
                    Text("Claim!")
                        .font(.headline.bold())
                        .foregroundColor(Color(red: 0.2, green: 0.45, blue: 0.3))
                        .padding(.horizontal, 50).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.white))
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.38, blue: 0.28),
                             Color(red: 0.28, green: 0.52, blue: 0.38)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.3), radius: 20))
            .padding(28)
        }
    }
}

// ============================================================
// MARK: - SPOTLIGHT BANNER
// ============================================================

struct SpotlightBannerView: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    let chain = ContentRegistry.shared.chain(viewModel.spotlightChainID)
                    let base  = chain?.tiers.first
                    Text("This Week:").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Image(systemName: base?.symbol ?? "pawprint.fill").font(.system(size: 13))
                        .foregroundColor(base?.tint ?? .brown)
                    Text(chain?.displayName ?? "").font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.42, green: 0.26, blue: 0.02))
                    Text("2x Score").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.8)))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.7))
                            .frame(width: geo.size.width * viewModel.spotlightProgressFraction)
                            .animation(.easeInOut(duration: 0.4), value: viewModel.spotlightProgressFraction)
                    }
                }.frame(height: 5)
            }
            Spacer()
            Text("\(viewModel.spotlightMergesThisWeek)/\(spotlightWeeklyGoal)")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 1.0, green: 0.96, blue: 0.85).opacity(0.9))
            .shadow(color: .black.opacity(0.06), radius: 3))
    }
}

// ============================================================
// MARK: - ADOPTION ORDER BOARD
// ============================================================

struct AdoptionOrderPanelView: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Urgent order (Task 5.2) — the one slot with a real clock and real
            // stakes; shown above the persistent board so it's never missed.
            VStack(alignment: .leading, spacing: 6) {
                Label("Urgent Order", systemImage: "bolt.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                if let urgent = viewModel.urgentOrder {
                    AdoptionOrderCard(
                        order: urgent,
                        canSkip: false,
                        onSkip: {},
                        showSkip: false,
                        timer: (viewModel.urgentOrderTimeRemaining, urgentOrderDuration)
                    )
                } else {
                    UrgentOrderCooldownCard(remaining: viewModel.urgentOrderCooldownRemaining)
                }
            }

            Divider()

            // Panel header
            HStack {
                Label("Adoption Board", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.7, green: 0.25, blue: 0.35))
                Spacer()
                Text("Families waiting for a pet")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }

            ForEach(Array(viewModel.adoptionOrders.enumerated()), id: \.element.id) { idx, order in
                AdoptionOrderCard(
                    order: order,
                    canSkip: viewModel.kibble >= adoptionSkipCost,
                    onSkip: { viewModel.skipOrder(at: idx) }
                )
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 1.0, green: 0.94, blue: 0.95).opacity(0.9))
            .shadow(color: .black.opacity(0.07), radius: 4))
    }
}

/// Shown in the urgent-order slot while it waits out its post-miss cooldown
/// (Task 5.2) — the visible consequence of letting one expire unfulfilled.
struct UrgentOrderCooldownCard: View {
    let remaining: Double

    private var timeText: String {
        let s = max(0, Int(remaining))
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Missed it — a new urgent order is on its way")
                    .font(.system(size: 11, weight: .semibold))
                Text("in \(timeText)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }
}

struct AdoptionOrderCard: View {
    let order: AdoptionOrder
    let canSkip: Bool
    let onSkip: () -> Void
    /// `nil` for a persistent order (no expiry, no bar shown). Populated for the
    /// urgent order with `(remaining, duration)` so the bar/countdown render.
    var showSkip: Bool = true
    var timer: (remaining: Double, duration: Double)? = nil

    private var timeFraction: Double {
        guard let timer else { return 1 }
        return timer.remaining / timer.duration
    }
    private var isUrgentCountdown: Bool {
        guard let timer else { return false }
        return timer.remaining < 120 && !order.isComplete
    }
    private var timeText: String {
        guard let timer else { return "" }
        let s = Int(timer.remaining)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60 > 0 ? "\(s % 60)s" : "")"
    }

    private var timerColor: Color {
        if order.isComplete { return .green }
        if isUrgentCountdown { return .red }
        return Color(red: 0.7, green: 0.25, blue: 0.35)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Family header row ─────────────────────────────────
            HStack(spacing: 10) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(order.family.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: order.family.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundColor(order.family.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(order.family.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text("is looking for…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Skip button — only shown when order is active; greyed out when unaffordable
                if showSkip && !order.isClaimed && !order.isComplete {
                    Button(action: { SoundManager.shared.playButtonTap(); HapticManager.shared.lightTap(); onSkip() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                            Image(systemName: "pawprint")
                                .font(.system(size: 8))
                            Text("\(adoptionSkipCost)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(canSkip ? Color(red: 0.4, green: 0.3, blue: 0.6) : .secondary)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Capsule().fill(
                            canSkip ? Color(red: 0.4, green: 0.3, blue: 0.6).opacity(0.10)
                                    : Color.gray.opacity(0.08)
                        ))
                    }
                    .disabled(!canSkip)
                }
            }

            // ── Requested animal ──────────────────────────────────
            HStack(spacing: 12) {
                // Animal icon + stage badge
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: order.iconSymbol)
                        .font(.system(size: 28))
                        .foregroundColor(order.iconTint)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(order.iconTint.opacity(0.10)))

                    Image(systemName: order.stageBadgeSymbol)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(order.stageColor))
                        .offset(x: 4, y: 4)
                }
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 4) {
                    // What they want
                    Text(order.orderDescription)
                        .font(.system(size: 13, weight: .semibold))

                    // Progress dots when count > 1
                    if order.wantedCount > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<order.wantedCount, id: \.self) { i in
                                Circle()
                                    .fill(i < order.fulfilled ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            Text("\(order.fulfilled)/\(order.wantedCount)")
                                .font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }

                    // Reward row
                    HStack(spacing: 8) {
                        (Text(Image(systemName: "tag.fill")) + Text(" +\(order.rewardDogTags)"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                        (Text(Image(systemName: "coin.fill")) + Text(" +\(order.rewardCoins)"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(red: 0.45, green: 0.28, blue: 0.02))
                        // Task 5.3 — the hard slot's material reward.
                        if let material = order.materialReward, let chainID = material.payloadID {
                            let symbol = ContentRegistry.shared.tier(chainID, material.payloadTier ?? 0)?.symbol
                                ?? "shippingbox.fill"
                            (Text(Image(systemName: symbol)) + Text(" +\(material.amount)"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.20))
                        }
                    }
                }

                Spacer()

                // State indicator
                if order.isClaimed {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                        Text("Adopted!").font(.system(size: 8, weight: .bold)).foregroundColor(.green)
                    }
                } else if order.isComplete {
                    VStack(spacing: 2) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.7, green: 0.25, blue: 0.35))
                            .symbolEffect(.pulse, options: .repeating)
                        Text("Placing...").font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 0.7, green: 0.25, blue: 0.35))
                    }
                }
            }
            .padding(.top, 8)

            // ── Timer bar — only for the urgent order; persistent slots have
            // no timer at all (Task 5.2), so they just state their status ──
            if timer != nil {
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 3).fill(timerColor.opacity(0.6))
                                .frame(width: geo.size.width * (order.isComplete ? 1.0 : timeFraction))
                                .animation(.linear(duration: 1.0), value: timeFraction)
                        }
                    }.frame(height: 4)

                    HStack {
                        Text(order.isComplete
                             ? "Ready for pickup!"
                             : isUrgentCountdown ? "Hurrying! \(timeText) left" : "\(timeText) remaining")
                            .font(.system(size: 9, weight: isUrgentCountdown ? .bold : .regular))
                            .foregroundColor(timerColor)
                        Spacer()
                    }
                }
                .padding(.top, 6)
            } else {
                HStack {
                    Text(order.isComplete ? "Ready for pickup!" : "Open — no rush")
                        .font(.system(size: 9))
                        .foregroundColor(order.isComplete ? .green : .secondary)
                    Spacer()
                }
                .padding(.top, 6)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(order.isClaimed ? 0.5 : 0.85))
            .shadow(color: .black.opacity(0.05), radius: 4))
        .opacity(order.isClaimed ? 0.7 : 1.0)
    }
}

// ============================================================
// MARK: - DAILY CHALLENGES
// ============================================================

struct DailyChallengePanelView: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Daily Challenges", systemImage: "list.clipboard.fill")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 12))
                        Text("\(viewModel.dailyChallengeStreak) day streak")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.52, green: 0.25, blue: 0.02))
                    }
                    Text(viewModel.dailyChallengeResetText)
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }

            ForEach(viewModel.dailyChallenges) { challenge in
                DailyChallengeCardView(challenge: challenge)
            }

            if viewModel.dailyChallengeBonusClaimed {
                HStack {
                    Text("All done today!").font(.system(size: 12, weight: .semibold)).foregroundColor(.green)
                    Spacer()
                    Text("Come back tomorrow for your streak bonus!")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            } else if !viewModel.dailyChallenges.isEmpty {
                let remaining    = viewModel.dailyChallenges.filter { !$0.isComplete }.count
                let nextStreakDay = ((viewModel.dailyChallengeStreak) % 7) + 1
                HStack {
                    Text("\(remaining) challenge\(remaining == 1 ? "" : "s") remaining")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text("Day \(nextStreakDay) of 7 streak")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.88, green: 0.93, blue: 1.0).opacity(0.85))
            .shadow(color: .black.opacity(0.07), radius: 4))
    }
}

struct DailyChallengeCardView: View {
    let challenge: DailyChallenge

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: challenge.goal.icon)
                .font(.system(size: 22))
                .foregroundColor(challenge.goal.iconColor)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(challenge.difficulty.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(challenge.goal.description).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(challenge.difficulty.rawValue)
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(challenge.difficulty.color))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(challenge.isComplete ? Color.green : challenge.difficulty.color.opacity(0.7))
                            .frame(width: geo.size.width * challenge.progressFraction)
                            .animation(.easeInOut(duration: 0.3), value: challenge.progressFraction)
                    }
                }.frame(height: 5)
            }

            Text(challenge.isComplete ? "✓" : challenge.progressText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(challenge.isComplete ? .green : .secondary)
                .frame(width: 32)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.04), radius: 3))
    }
}

// ============================================================
// MARK: - QUEST CARD
// ============================================================

struct QuestCardView: View {
    let quest: Quest
    let onClaim: () -> Void

    private var isLegendary: Bool { quest.difficulty.isLegendary }

    var body: some View {
        HStack(spacing: 12) {
            // Goal icon — legendary gets a larger frame with gradient background
            Image(systemName: quest.goal.icon)
                .font(.system(size: isLegendary ? 30 : 28))
                .foregroundColor(isLegendary ? .white : quest.goal.iconColor)
                .frame(width: isLegendary ? 50 : 44, height: isLegendary ? 50 : 44)
                .background(
                    isLegendary
                        ? AnyView(RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.6, green: 0.2, blue: 0.9),
                                         Color(red: 0.9, green: 0.6, blue: 0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                        : AnyView(RoundedRectangle(cornerRadius: 10)
                            .fill(quest.difficulty.color.opacity(0.15)))
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(quest.goal.description)
                        .font(.system(size: isLegendary ? 13 : 13, weight: isLegendary ? .bold : .semibold))
                        .foregroundColor(isLegendary ? Color(red: 0.4, green: 0.1, blue: 0.6) : .primary)
                    Spacer()
                    // Difficulty badge — legendary gets a gradient pill
                    if isLegendary {
                        HStack(spacing: 3) {
                            Image(systemName: "medal.fill").font(.system(size: 8))
                            Text(quest.difficulty.rawValue).font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            Capsule().fill(LinearGradient(
                                colors: [Color(red: 0.6, green: 0.2, blue: 0.9),
                                         Color(red: 0.9, green: 0.6, blue: 0.1)],
                                startPoint: .leading, endPoint: .trailing))
                        )
                    } else {
                        Text(quest.difficulty.rawValue)
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(quest.difficulty.color))
                    }
                }

                // Progress bar — legendary uses a gradient fill
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isLegendary
                                  ? LinearGradient(colors: [Color(red: 0.6, green: 0.2, blue: 0.9),
                                                            Color(red: 0.9, green: 0.6, blue: 0.1)],
                                                   startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [quest.difficulty.color.opacity(0.7),
                                                            quest.difficulty.color.opacity(0.7)],
                                                   startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * quest.progressFraction)
                            .animation(.easeInOut(duration: 0.3), value: quest.progressFraction)
                    }
                }.frame(height: isLegendary ? 7 : 6)

                HStack {
                    Text(quest.progressText).font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    (Text(Image(systemName: "pawprint")) + Text(" +\(quest.kibbleReward)"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.05, green: 0.42, blue: 0.18))
                    (Text(Image(systemName: "tag.fill")) + Text(" +\(quest.dogTagReward)"))
                        .font(.system(size: 10, weight: isLegendary ? .bold : .medium))
                        .foregroundColor(isLegendary ? Color(red: 0.5, green: 0.1, blue: 0.8) : .blue)
                }
            }

            Button(action: onClaim) {
                Group {
                    if quest.isComplete { Text("Claim!") }
                    else { Image(systemName: "lock.fill") }
                }
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(quest.isComplete
                          ? (isLegendary
                              ? LinearGradient(colors: [Color(red: 0.6, green: 0.2, blue: 0.9),
                                                        Color(red: 0.9, green: 0.6, blue: 0.1)],
                                               startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [.green, .green],
                                               startPoint: .leading, endPoint: .trailing))
                          : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                                           startPoint: .leading, endPoint: .trailing)))
            }
            .disabled(!quest.isComplete)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isLegendary
                      ? Color(red: 0.97, green: 0.94, blue: 1.0)
                      : Color.white.opacity(0.75))
                .overlay(
                    isLegendary
                        ? RoundedRectangle(cornerRadius: 14)
                            .stroke(LinearGradient(
                                colors: [Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.5),
                                         Color(red: 0.9, green: 0.6, blue: 0.1).opacity(0.5)],
                                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        : nil
                )
                .shadow(color: isLegendary
                        ? Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.15)
                        : .black.opacity(0.06),
                        radius: isLegendary ? 8 : 4)
        )
    }
}

// ============================================================
// MARK: - WEEKLY GOAL PANEL
// ============================================================

struct WeeklyGoalPanelView: View {
    var viewModel: MergeBoardViewModel

    private var reached: (bronze: Bool, silver: Bool, gold: Bool) { viewModel.weeklyGoalReached }
    private var goldTarget: Int { viewModel.effectiveWeeklyGoldTarget }
    private var progress: Double {
        min(Double(viewModel.coinsEarnedThisWeek) / Double(goldTarget), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Weekly Goal", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "coin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                    Text("\(viewModel.coinsEarnedThisWeek)/\(goldTarget)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                }
            }

            // Coin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.18))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.72, green: 0.45, blue: 0.18),
                                     Color(red: 0.85, green: 0.68, blue: 0.10)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }.frame(height: 7)

            // Tier claim chips
            HStack(spacing: 8) {
                ForEach(WeeklyGoalTier.allCases, id: \.rawValue) { tier in
                    let isClaimed = viewModel.weeklyGoalBronzeClaimed && tier == .bronze
                        || viewModel.weeklyGoalSilverClaimed && tier == .silver
                        || viewModel.weeklyGoalGoldClaimed   && tier == .gold
                    let tierReached = (tier == .bronze && reached.bronze)
                        || (tier == .silver && reached.silver)
                        || (tier == .gold   && reached.gold)
                    let effectiveTarget = tier == .gold
                        ? goldTarget : tier.baseCoinsNeeded

                    Button(action: { viewModel.claimWeeklyGoal(tier: tier) }) {
                        VStack(spacing: 3) {
                            Image(systemName: isClaimed ? "checkmark.circle.fill" : tier.sfSymbol)
                                .font(.system(size: 16))
                                .foregroundColor(isClaimed ? .green : (tierReached ? tier.color : .gray.opacity(0.4)))
                            Text(tier.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isClaimed ? .green : (tierReached ? tier.color : .secondary))
                            Text(isClaimed ? "Claimed" : "\(effectiveTarget)💰")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(tierReached && !isClaimed
                                  ? tier.color.opacity(0.12)
                                  : Color.white.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(tierReached && !isClaimed ? tier.color.opacity(0.4) : Color.clear,
                                        lineWidth: 1.5)))
                    }
                    .disabled(isClaimed || !tierReached)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 1.0, green: 0.97, blue: 0.88).opacity(0.92))
            .shadow(color: .black.opacity(0.06), radius: 4))
    }
}

// ============================================================
// MARK: - MONTHLY GOAL PANEL
// ============================================================

struct MonthlyGoalPanelView: View {
    var viewModel: MergeBoardViewModel

    private var needed: Int  { viewModel.monthlyGoalWeeksRequired }
    private var reached: Bool { viewModel.monthlyGoalReached }
    private var progress: Double {
        min(Double(viewModel.weeklyGoldCompletions) / Double(needed), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Monthly Goal", systemImage: "star.circle.fill")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.35, green: 0.15, blue: 0.60))
                Spacer()
                Text("\(viewModel.weeklyGoldCompletions)/\(needed) gold weeks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.15, blue: 0.60))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.18))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.50, green: 0.20, blue: 0.85),
                                     Color(red: 0.75, green: 0.45, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }.frame(height: 7)

            HStack(spacing: 12) {
                // Week pip indicators
                HStack(spacing: 5) {
                    ForEach(0..<needed, id: \.self) { i in
                        let filled = i < viewModel.weeklyGoldCompletions
                        ZStack {
                            Circle()
                                .fill(filled
                                      ? Color(red: 0.85, green: 0.68, blue: 0.10)
                                      : Color.gray.opacity(0.18))
                                .frame(width: 22, height: 22)
                            if filled {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10)).foregroundColor(.white)
                            } else {
                                Text("\(i + 1)").font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                }

                Spacer()

                // Reward preview
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Reward:").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("+50 Kibble  +20 Tags  3 Toolboxes")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.15, blue: 0.60))
                }
            }

            if reached && !viewModel.monthlyGoalClaimed {
                Button(action: { viewModel.claimMonthlyGoal() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                        Text("Claim Monthly Reward!").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.50, green: 0.20, blue: 0.85),
                                     Color(red: 0.70, green: 0.40, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing)))
                }
            } else if viewModel.monthlyGoalClaimed {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Monthly reward claimed! Keep going for next month.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.96, green: 0.92, blue: 1.0).opacity(0.90))
            .shadow(color: .black.opacity(0.06), radius: 4))
    }
}

// ============================================================
// MARK: - SLIDE-UP CELEBRATION BANNER
// ============================================================

/// Shared "slides up from the bottom, auto-dismisses" celebration banner shell —
/// icon + title + detail line over a rounded, shadowed background. Used by the
/// unlock/level-up/area-built/superpower-unlock banners in MergeBoardView, which
/// previously repeated this VStack/HStack/background/transition markup verbatim (QA-06).
/// Each banner still owns its distinct icon styling and colors via the `icon` closure
/// and `background` style — only the shared scaffolding moved here.
struct BannerView<Icon: View>: View {
    let title: String
    let detail: String
    let background: AnyShapeStyle
    let bottomPadding: CGFloat
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                icon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(detail)
                        .font(.caption).foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(background)
                .shadow(color: .black.opacity(0.2), radius: 10))
            .padding(.horizontal, 20).padding(.bottom, bottomPadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// ============================================================
// MARK: - AMBASSADOR CELEBRATION BANNER
// ============================================================

struct AmbassadorBannerView: View {
    let chainID: ChainID
    let onDismiss: () -> Void

    private var chainName: String { ContentRegistry.shared.chain(chainID)?.displayName ?? "animal" }
    private var chainSymbol: String { ContentRegistry.shared.chain(chainID)?.tiers.first?.symbol ?? "pawprint.fill" }

    var body: some View {
        ZStack {
            // Scrim — tap anywhere to dismiss early
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Headline
                    VStack(spacing: 4) {
                        Text("Sanctuary Ambassador!")
                            .font(.title2.bold())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.80, blue: 0.10),
                                             Color(red: 1.00, green: 0.55, blue: 0.05)],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Your \(chainName) has earned the highest honour")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    // Species icon with golden ring
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.80, blue: 0.10).opacity(0.3),
                                         Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                        Circle()
                            .stroke(LinearGradient(
                                colors: [.yellow, Color(red: 1, green: 0.75, blue: 0.1), .yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 3)
                            .frame(width: 90, height: 90)
                        Image(systemName: chainSymbol)
                            .font(.system(size: 44))
                            .foregroundColor(.yellow)
                            .symbolEffect(.pulse, options: .repeating)
                        // Medal badge
                        Image(systemName: "medal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .offset(x: 32, y: -32)
                    }

                    // Bonus reward callout
                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Image(systemName: "pawprint").font(.title3).foregroundColor(.yellow)
                            Text("+20 Kibble")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        }
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)
                        VStack(spacing: 2) {
                            Image(systemName: "tag.fill").font(.title3).foregroundColor(.yellow)
                            Text("+5 Dog Tags")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))

                    // Dismiss button
                    Button(action: onDismiss) {
                        Text("Amazing!")
                            .font(.headline.bold())
                            .foregroundColor(Color(red: 0.4, green: 0.1, blue: 0.0))
                            .padding(.horizontal, 48).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 25)
                                .fill(LinearGradient(
                                    colors: [.yellow, Color(red: 1, green: 0.75, blue: 0.1)],
                                    startPoint: .leading, endPoint: .trailing)))
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.18, green: 0.08, blue: 0.30),
                                     Color(red: 0.35, green: 0.15, blue: 0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Color(red: 0.95, green: 0.80, blue: 0.10).opacity(0.4),
                                radius: 24, x: 0, y: 0)
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

// ============================================================
// MARK: - LOYALTY CLUB PANEL
// ============================================================

struct LoyaltyClubPanelView: View {
    let viewModel: MergeBoardViewModel

    private let gold   = Color(red: 0.55, green: 0.35, blue: 0.02)
    private let accent = Color(red: 0.40, green: 0.22, blue: 0.02)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "crown.fill").foregroundColor(gold)
                Text("Loyalty Club")
                    .font(.headline).foregroundColor(accent)
                Spacer()
                Text("Day \(viewModel.loyaltyClubDayIndex % loyaltyClubCycle.count + 1) of \(loyaltyClubCycle.count)")
                    .font(.caption).foregroundColor(.secondary)
                if viewModel.loyaltyClubStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").foregroundColor(.orange)
                        Text("\(viewModel.loyaltyClubStreak)").font(.caption.bold())
                    }
                }
            }

            // Today's reward
            let reward = viewModel.currentLoyaltyReward
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today — \(reward.label)")
                        .font(.subheadline.bold()).foregroundColor(accent)
                    HStack(spacing: 10) {
                        if reward.kibble > 0 {
                            Label("+\(reward.kibble) Kibble", systemImage: "pawprint.fill")
                                .font(.caption).foregroundColor(.green)
                        }
                        if reward.dogTags > 0 {
                            Label("+\(reward.dogTags) Tags", systemImage: "tag.fill")
                                .font(.caption).foregroundColor(.blue)
                        }
                        if let pack = reward.cardPack {
                            Label(pack.displayName, systemImage: pack.sfSymbol)
                                .font(.caption).foregroundColor(pack.accentColor)
                        }
                    }
                    if viewModel.isPassActive {
                        Text("Pass bonus: +\(viewModel.withPassBonus(reward.kibble) - reward.kibble) extra kibble")
                            .font(.caption2).foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                    }
                }
                Spacer()
                if viewModel.canClaimLoyaltyClub {
                    Button(action: { viewModel.claimLoyaltyClub() }) {
                        Text("Claim")
                            .font(.subheadline.bold()).foregroundColor(.white)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(gold))
                    }
                } else {
                    Text("Come back tomorrow")
                        .font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 80)
                }
            }

            // Upcoming 3 days preview
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { offset in
                    let idx = (viewModel.loyaltyClubDayIndex + offset) % loyaltyClubCycle.count
                    let r   = loyaltyClubCycle[idx]
                    VStack(spacing: 3) {
                        Text(r.label)
                            .font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        if r.cardPack != nil {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 12)).foregroundColor(gold)
                        } else if r.dogTags > 0 {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12)).foregroundColor(.blue.opacity(0.7))
                        } else {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 12)).foregroundColor(.green.opacity(0.7))
                        }
                        Text("+\(r.kibble)")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.5)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.97, blue: 0.87),
                             Color(red: 0.98, green: 0.93, blue: 0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: gold.opacity(0.2), radius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(gold.opacity(0.35), lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: - TASK STRIP
// ============================================================

/// Identifies which full-panel sheet the task strip opened.
enum TaskSheet: String, Identifiable {
    case adoptionOrders, dailyChallenges, quests, loyalty, invite, weeklyGoal, monthlyGoal, event
    var id: String { rawValue }
    var title: String {
        switch self {
        case .adoptionOrders:  return "Adoption Board"
        case .dailyChallenges: return "Daily Challenges"
        case .quests:          return "Active Quests"
        case .loyalty:         return "Loyalty Club"
        case .invite:          return "Invite Friends"
        case .weeklyGoal:      return "Weekly Goal"
        case .monthlyGoal:     return "Monthly Goal"
        case .event:           return "Active Event"
        }
    }
}

private let taskCardWidth:  CGFloat = 150
private let taskCardHeight: CGFloat = 85

/// Thin progress bar reused by all task cards.
private struct TaskProgressBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * CGFloat(min(fraction, 1.0))))
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 4)
    }
}

// MARK: Stage legend card

struct LevelProgressTaskCard: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Circular XP ring
            ZStack {
                Circle()
                    .stroke(Color(red: 0.08, green: 0.38, blue: 0.15).opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: viewModel.xpProgressFraction)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.30, green: 0.70, blue: 0.40),
                                     Color(red: 0.20, green: 0.55, blue: 0.30)],
                            startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: viewModel.xpProgressFraction)
                VStack(spacing: 0) {
                    Text("Lv.")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(Color(red: 0.08, green: 0.38, blue: 0.15))
                    Text("\(viewModel.playerLevel)")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color(red: 0.20, green: 0.45, blue: 0.28))
                }
            }
            .frame(width: 56, height: 56)

            // XP text
            VStack(alignment: .leading, spacing: 3) {
                Text("Level Up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.20, green: 0.45, blue: 0.28))
                Text("\(viewModel.playerXP) XP")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                Text("/ \(viewModel.xpToNextLevel)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.93, green: 0.97, blue: 0.93)))
    }
}

// MARK: Spotlight card

struct SpotlightTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let chain = ContentRegistry.shared.chain(viewModel.spotlightChainID)
        let base  = chain?.tiers.first
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.48, green: 0.28, blue: 0.02))
                Text("Spotlight").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.48, green: 0.28, blue: 0.02))
                Spacer()
                Text("2x").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.85)))
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: base?.symbol ?? "pawprint.fill")
                    .font(.system(size: 13)).foregroundColor(base?.tint ?? .brown)
                Text(chain?.displayName ?? "This Week")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .lineLimit(1)
            }
            TaskProgressBar(fraction: viewModel.spotlightProgressFraction,
                            color: Color.orange.opacity(0.7))
            Text("\(viewModel.spotlightMergesThisWeek)/\(spotlightWeeklyGoal) merges")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 1.0, green: 0.96, blue: 0.85)))
    }
}

// MARK: Event card

struct EventTaskCard: View {
    var viewModel: MergeBoardViewModel
    let event: EventDefinition
    var body: some View {
        // Phase 6b: sourced from ProgressTrackRegistry/ProgressTrack, not
        // event.milestones/eventProgress — see EventPanelView.swift.
        let maxTokens = (ProgressTrackRegistry.tracks[event.id]?.last?.threshold) ?? 1
        let earned = viewModel.progressTrack.progress(trackID: event.id)
        let fraction = Double(earned) / Double(max(1, maxTokens))
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: event.icon).font(.system(size: 11))
                    .foregroundColor(Color(red: 0.50, green: 0.18, blue: 0.00))
                Text("Event").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.50, green: 0.18, blue: 0.00))
                Spacer()
                Text(event.timerLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.05))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 1.0, green: 0.92, blue: 0.78)))
            }
            Spacer(minLength: 0)
            Text(event.name)
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: fraction,
                            color: Color(red: 0.85, green: 0.52, blue: 0.10).opacity(0.8))
            Text("\(earned)/\(maxTokens) coins")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 1.0, green: 0.96, blue: 0.87)))
    }
}

// MARK: Adoption orders card

struct AdoptionOrdersTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let total  = viewModel.adoptionOrders.count
        let ready  = viewModel.adoptionOrders.filter { $0.isComplete && !$0.isClaimed }.count
        let active = viewModel.adoptionOrders.filter { !$0.isClaimed }.count
        let fraction = total > 0 ? Double(ready) / Double(total) : 0.0
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.7, green: 0.25, blue: 0.35))
                Text("Adoptions").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.25, blue: 0.35))
                Spacer()
                if ready > 0 {
                    Text("\(ready)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.7, green: 0.25, blue: 0.35)))
                }
            }
            Spacer(minLength: 0)
            Text(ready > 0
                 ? "\(ready) order\(ready == 1 ? "" : "s") ready!"
                 : "\(active) active order\(active == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: fraction,
                            color: Color(red: 0.7, green: 0.25, blue: 0.35).opacity(0.75))
            Text("\(active) order\(active == 1 ? "" : "s") open")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 1.0, green: 0.94, blue: 0.95)))
    }
}

// MARK: Daily challenge card

struct DailyChallengeTaskCard: View {
    let challenge: DailyChallenge
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "list.clipboard.fill").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                Text("Daily").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                Spacer()
                if challenge.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13)).foregroundColor(.green)
                } else {
                    Text(challenge.difficulty.rawValue)
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(challenge.difficulty.color))
                }
            }
            Spacer(minLength: 0)
            Text(challenge.goal.description)
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: challenge.progressFraction,
                            color: challenge.difficulty.color.opacity(0.75))
            Text(challenge.isComplete ? "Complete!" : challenge.progressText)
                .font(.system(size: 9))
                .foregroundColor(challenge.isComplete ? .green : .secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.88, green: 0.93, blue: 1.0)))
    }
}

// MARK: Quest card (compact strip version)

struct QuestTaskCard: View {
    let quest: Quest
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: quest.goal.icon).font(.system(size: 11))
                    .foregroundColor(quest.goal.iconColor)
                Text("Quest").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.08, green: 0.35, blue: 0.08))
                Spacer()
                if quest.isComplete {
                    Text("Claim!").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green))
                } else {
                    Text(quest.difficulty.rawValue)
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(quest.difficulty.color))
                }
            }
            Spacer(minLength: 0)
            Text(quest.goal.description)
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: quest.progressFraction,
                            color: quest.difficulty.color.opacity(0.75))
            Text(quest.isComplete ? "Ready to claim!" : quest.progressText)
                .font(.system(size: 9))
                .foregroundColor(quest.isComplete ? .green : .secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.92, green: 0.97, blue: 0.92)))
    }
}

// MARK: Weekly goal card

struct WeeklyGoalTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let goldTarget = viewModel.effectiveWeeklyGoldTarget
        let fraction   = min(Double(viewModel.coinsEarnedThisWeek) / Double(max(1, goldTarget)), 1.0)
        let reached    = viewModel.weeklyGoalReached
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                Text("Weekly").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                Spacer()
                if reached.gold {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "coin.fill").font(.system(size: 9))
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                Text("\(viewModel.coinsEarnedThisWeek)/\(goldTarget)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
            }
            TaskProgressBar(fraction: fraction, color: Color(red: 0.82, green: 0.58, blue: 0.12))
            Text(reached.gold
                 ? "Gold reached!"
                 : "\(goldTarget - viewModel.coinsEarnedThisWeek) coins to gold")
                .font(.system(size: 9))
                .foregroundColor(reached.gold ? Color(red: 0.40, green: 0.22, blue: 0.02) : .secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 1.0, green: 0.97, blue: 0.87)))
    }
}

// MARK: Monthly goal card

struct MonthlyGoalTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let needed   = viewModel.monthlyGoalWeeksRequired
        let fraction = min(Double(viewModel.weeklyGoldCompletions) / Double(max(1, needed)), 1.0)
        let reached  = viewModel.monthlyGoalReached
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "star.circle.fill").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.35, green: 0.15, blue: 0.60))
                Text("Monthly").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.15, blue: 0.60))
                Spacer()
                if reached {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                        .foregroundColor(.purple)
                }
            }
            Spacer(minLength: 0)
            Text("\(viewModel.weeklyGoldCompletions)/\(needed) gold weeks")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
            TaskProgressBar(fraction: fraction, color: Color(red: 0.55, green: 0.25, blue: 0.90))
            Text(reached
                 ? "Monthly goal reached!"
                 : "\(needed - viewModel.weeklyGoldCompletions) more gold weeks")
                .font(.system(size: 9))
                .foregroundColor(reached ? Color(red: 0.35, green: 0.15, blue: 0.60) : .secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.95, green: 0.91, blue: 1.0)))
    }
}

// MARK: Loyalty club card

struct LoyaltyTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let dayIdx   = viewModel.loyaltyClubDayIndex
        let streak   = viewModel.loyaltyClubStreak
        let canClaim = viewModel.canClaimLoyaltyClub
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.circle.fill").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.45))
                Text("Loyalty").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.45))
                Spacer()
                if canClaim {
                    Text("Claim!").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.3, green: 0.6, blue: 0.45)))
                }
            }
            Spacer(minLength: 0)
            Text("Day \(dayIdx + 1) reward")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: Double(dayIdx % 28) / 28.0,
                            color: Color(red: 0.3, green: 0.6, blue: 0.45))
            Text("\(streak) day streak")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.90, green: 0.97, blue: 0.93)))
    }
}

// MARK: Invite card

struct InviteTaskCard: View {
    var viewModel: MergeBoardViewModel
    var body: some View {
        let sent = viewModel.inviteProgress.invitesSent
        let next = inviteMilestones.first { !viewModel.inviteProgress.hasClaimed($0.id) }
        let fraction = next.map { min(Double(sent) / Double(max(1, $0.invitesRequired)), 1.0) } ?? 1.0
        let claimReady = next.map { sent >= $0.invitesRequired } ?? false
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "person.badge.plus").font(.system(size: 11))
                    .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.5))
                Text("Invite").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.5))
                Spacer()
                if claimReady {
                    Text("Claim!").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.0, green: 0.5, blue: 0.5)))
                }
            }
            Spacer(minLength: 0)
            Text(next == nil ? "All rewards claimed!" : "Invite friends for rewards")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineLimit(2)
            TaskProgressBar(fraction: fraction, color: Color(red: 0.0, green: 0.55, blue: 0.50))
            Text(next.map { "\(sent)/\($0.invitesRequired) invites" } ?? "Complete!")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: taskCardWidth, height: taskCardHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.88, green: 0.97, blue: 0.97)))
    }
}

// MARK: Task strip container

/// Horizontal scrolling strip of compact task cards, shown between HUD and board.
struct TaskStripView: View {
    var viewModel: MergeBoardViewModel
    @Binding var activeSheet: TaskSheet?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                LevelProgressTaskCard(viewModel: viewModel)
                SpotlightTaskCard(viewModel: viewModel)
                if let event = viewModel.activeEvent {
                    EventTaskCard(viewModel: viewModel, event: event)
                        .onTapGesture { activeSheet = .event }
                }
                AdoptionOrdersTaskCard(viewModel: viewModel)
                    .onTapGesture { activeSheet = .adoptionOrders }
                ForEach(viewModel.dailyChallenges) { challenge in
                    DailyChallengeTaskCard(challenge: challenge)
                        .onTapGesture { activeSheet = .dailyChallenges }
                }
                ForEach(viewModel.activeQuests) { quest in
                    QuestTaskCard(quest: quest)
                        .onTapGesture { activeSheet = .quests }
                }
                ForEach(viewModel.exchangeableTrios) { trio in
                    AmbassadorTrioTaskCard(trio: trio,
                                           coinValue: viewModel.ambassadorTrioValue(trio)) {
                        viewModel.exchangeAmbassadorTrio(trio)
                    }
                }
                ForEach(viewModel.retirableProducers) { retirable in
                    RetireProducerTaskCard(retirable: retirable) {
                        viewModel.retireProducer(at: retirable.position)
                    }
                }
                WeeklyGoalTaskCard(viewModel: viewModel)
                    .onTapGesture { activeSheet = .weeklyGoal }
                MonthlyGoalTaskCard(viewModel: viewModel)
                    .onTapGesture { activeSheet = .monthlyGoal }
                if viewModel.isLoyaltyClubUnlocked {
                    LoyaltyTaskCard(viewModel: viewModel)
                        .onTapGesture { activeSheet = .loyalty }
                }
                if viewModel.isInviteUnlocked {
                    InviteTaskCard(viewModel: viewModel)
                        .onTapGesture { activeSheet = .invite }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// ============================================================
// MARK: - AMBASSADOR TRIO EXCHANGE TASK CARD
// ============================================================

struct AmbassadorTrioTaskCard: View {
    let trio: ExchangeableTrio
    /// Phase 2c: derived from the trio's sell value rather than a flat constant,
    /// so the card can't advertise a number the exchange no longer pays.
    let coinValue: Int
    let onClaim: () -> Void

    var body: some View {
        Button(action: onClaim) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.08))
                    Text("Trio Exchange")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.05))
                    Spacer()
                    // "×3" badge
                    Text("×3")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.85, green: 0.55, blue: 0.08)))
                }

                Text("Ambassador \(trio.species.name)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "coin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                    Text("+\(coinValue) coins")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                    Spacer()
                    Text("Claim")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.05))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: taskCardWidth, height: taskCardHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 1.0, green: 0.97, blue: 0.82))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(red: 0.85, green: 0.68, blue: 0.08).opacity(0.55),
                                      lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - RETIRE PRODUCER TASK CARD
// ============================================================

struct RetireProducerTaskCard: View {
    let retirable: RetirableProducer
    let onRetire: () -> Void

    var body: some View {
        Button(action: onRetire) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: retirable.producer.level.sfSymbol)
                        .font(.system(size: 13))
                        .foregroundColor(retirable.producer.level.tintColor)
                    Text(retirable.producer.level.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.22, green: 0.22, blue: 0.22))
                        .lineLimit(1)
                }

                Text("No active quests need this producer.")
                    .font(.system(size: 9))
                    .foregroundColor(Color(red: 0.40, green: 0.45, blue: 0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 9))
                    Text("Retire to Storage")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.28, green: 0.44, blue: 0.68))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 150, height: 85, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.90, green: 0.94, blue: 1.00))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(red: 0.28, green: 0.44, blue: 0.68).opacity(0.35),
                                      lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
