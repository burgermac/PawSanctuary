//
//  MergeBoardView.swift
//  PawSanctuary
//

import SwiftUI

// ============================================================
// MARK: - UTILITIES
// ============================================================

private extension View {
    /// Attaches a double-tap gesture **only** when `enabled` is true.
    /// When `enabled` is false no double-tap recogniser is installed, so
    /// single-tap recognition is instant on cells that don't need it.
    @ViewBuilder
    func onDoubleTapGesture(enabled: Bool, perform action: @escaping () -> Void) -> some View {
        if enabled {
            self.onTapGesture(count: 2, perform: action)
        } else {
            self
        }
    }
}

// ============================================================
// MARK: - MAIN VIEW
// ============================================================

struct MergeBoardView: View {
    /// @State instead of @StateObject — required with @Observable.
    @State private var viewModel    = MergeBoardViewModel()
    @State private var storeManager = StoreManager()
    @State private var notifManager = NotificationManager()
    @State private var activeRoute: SheetRoute?

    /// Used to flush a final save when the app leaves the foreground.
    @Environment(\.scenePhase) private var scenePhase

    /// dragOffset lives here, NOT in the ViewModel.
    /// With @Observable, keeping it in the VM would be fine too (only this view reads it),
    /// but @State is semantically cleaner and avoids any observation overhead.
    @State private var dragOffset: CGSize = .zero

    /// Global frame of the Storage basket button — updated via onGeometryChange.
    /// Used to detect when a board-drag lands on the basket for direct-to-storage drops.
    @State private var basketGlobalFrame: CGRect = .zero
    /// True while a board item is being dragged and the finger is currently over the basket.
    @State private var isDraggingOverBasket: Bool = false

    // Tutorial / onboarding
    @State private var tutorialStep: TutorialStep = {
        UserDefaults.standard.bool(forKey: "tutorialCompleted") ? .done : .rescue
    }()
    @State private var tutorialBoardFrame: CGRect    = .zero
    @State private var tutorialTaskFrame: CGRect     = .zero

    let cellSpacing: CGFloat = 4

    var body: some View {
        gameBody
            .onChange(of: viewModel.rescueCount) { _, count in
                if tutorialStep == .rescue && count > 0 {
                    withAnimation(.easeInOut(duration: 0.35)) { tutorialStep = .merge }
                }
            }
            .onChange(of: viewModel.mergeCount) { _, count in
                if tutorialStep == .merge && count > 0 {
                    withAnimation(.easeInOut(duration: 0.35)) { tutorialStep = .quest }
                }
            }
            .onChange(of: activeRoute) { _, route in
                if tutorialStep == .quest, let r = route, case .task(.quests) = r {
                    completeTutorial()
                }
            }
    }

    @ViewBuilder private var gameBody: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.85, green: 0.95, blue: 0.85),
                         Color(red: 0.95, green: 0.88, blue: 0.75)],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            // Screen content — bottomBar is a safeAreaInset, not a sibling,
            // so the GeometryReader in boardSection measures the correct height.
            if viewModel.showInventory {
                InventoryScreenView(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.showMap {
                MapView(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                gameScrollContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.showLoginReward {
                LoginRewardView(viewModel: viewModel)
                    .transition(.scale.combined(with: .opacity))
            }

            if let milestone = MilestoneManager.shared.pendingMilestone,
               !viewModel.showLoginReward {
                MilestoneOverlayView(viewModel: viewModel, milestone: milestone)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }

            if viewModel.showUnlockBanner {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "lock.open.fill").font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Row Unlocked!").font(.headline).foregroundColor(.white)
                            Text("7 more spaces are now open for rescued animals!")
                                .font(.caption).foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.2, green: 0.55, blue: 0.35))
                        .shadow(color: .black.opacity(0.2), radius: 10))
                    .padding(.horizontal, 20).padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Single queue-driven toast. The .id modifier forces SwiftUI to rebuild
            // the view when the toast changes, giving each message its own
            // enter/exit animation rather than a cross-fade.
            if let toast = viewModel.currentToast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .onTapGesture { viewModel.dismissCurrentToast() }
            }

            // Level-up banner — slides up from bottom
            if viewModel.showLevelUpBanner {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.25))
                                .frame(width: 46, height: 46)
                            Text("Lv.\(viewModel.playerLevel)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(.yellow)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.levelUpBannerTitle)
                                .font(.headline).foregroundColor(.white)
                            Text(viewModel.levelUpBannerDetail)
                                .font(.caption).foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.20, green: 0.45, blue: 0.30),
                                     Color(red: 0.35, green: 0.60, blue: 0.40)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .black.opacity(0.2), radius: 10))
                    .padding(.horizontal, 20).padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(99)
            }

            // Area-built celebration banner
            if viewModel.showAreaBuiltBanner {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.72, green: 0.50, blue: 0.10).opacity(0.25))
                                .frame(width: 46, height: 46)
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.areaBuiltBannerTitle)
                                .font(.headline).foregroundColor(.white)
                            Text(viewModel.areaBuiltBannerDetail)
                                .font(.caption).foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.48, green: 0.32, blue: 0.08),
                                     Color(red: 0.65, green: 0.48, blue: 0.12)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .black.opacity(0.2), radius: 10))
                    .padding(.horizontal, 20).padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(98)
            }

            // Ambassador celebration — sits on top of everything
            if viewModel.showAmbassadorBanner {
                AmbassadorBannerView(chainID: viewModel.ambassadorBannerChainID) {
                    viewModel.dismissAmbassadorBanner()
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .zIndex(100)
            }

            // Tutorial overlay — shown above all game elements; hidden while the
            // login-reward modal is active so both don't compete for attention.
            if tutorialStep.isActive && !viewModel.showLoginReward {
                OnboardingOverlay(
                    step: tutorialStep,
                    boardCenter: CGPoint(x: tutorialBoardFrame.midX, y: tutorialBoardFrame.midY),
                    taskStripCenter: CGPoint(x: tutorialTaskFrame.midX, y: tutorialTaskFrame.midY),
                    onSkip: completeTutorial
                )
                .transition(.opacity)
                .zIndex(150)
            }
        }
        .animation(.easeInOut(duration: 0.3),  value: viewModel.showInventory)
        .animation(.easeInOut(duration: 0.3),  value: viewModel.showMap)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.showAreaBuiltBanner)
        .animation(.easeInOut(duration: 0.35), value: viewModel.showLoginReward)
        .animation(.spring(response: 0.45, dampingFraction: 0.68), value: MilestoneManager.shared.pendingMilestone != nil)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: viewModel.showAmbassadorBanner)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.showLevelUpBanner)
        .animation(.easeInOut(duration: 0.35), value: tutorialStep)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .sheet(item: $activeRoute) { route in routeContent(route) }
        .onChange(of: viewModel.showKibbleSheet) { _, show in
            if show { activeRoute = .kibbleRefill; viewModel.showKibbleSheet = false }
        }
        .onAppear {
            storeManager.onPurchaseComplete = { viewModel.applyPurchase($0) }
            viewModel.isPassActive = storeManager.isPassActive
            // Cancel stale notifications whenever the app becomes visible
            notifManager.cancelAll()
            // Request permission once the player has made some progress
            if viewModel.playerLevel > 1 {
                Task { await notifManager.requestPermission() }
            }
        }
        .onChange(of: storeManager.isPassActive) { _, active in
            viewModel.isPassActive = active
        }
        .onChange(of: viewModel.playerLevel) { _, level in
            // Ask for permission at the moment they first level up
            if level == 2 {
                Task { await notifManager.requestPermission() }
            }
            // Schedule the daily rewards reminder once we have permission
            if notifManager.isAuthorised { notifManager.scheduleDailyRewards() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                // Flush save
                viewModel.persist()
                // Schedule all re-engagement notifications
                scheduleAllNotifications()
            case .active:
                // Cancel everything — the player is here now
                notifManager.cancelAll()
            default:
                break
            }
        }
    }

    // MARK: Tutorial

    private func completeTutorial() {
        withAnimation(.easeOut(duration: 0.4)) { tutorialStep = .done }
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
    }

    // MARK: Notification scheduling

    /// Called whenever the app backgrounds. Schedules all contextually relevant notifications.
    private func scheduleAllNotifications() {
        guard notifManager.isAuthorised else { return }

        // 1. Kibble full
        let kibblePerTick = 1 + viewModel.activeBonuses.kibblePerRegen
        notifManager.scheduleKibbleFull(
            currentKibble:  viewModel.kibble,
            regenCap:       kibbleRegenCap,
            secsUntilNext:  viewModel.secondsUntilNextKibble,
            regenSecs:      kibbleRegenSecs,
            kibblePerTick:  kibblePerTick)

        // 2. Daily rewards (persistent daily — schedule once, keeps firing)
        notifManager.scheduleDailyRewards()

        // 3. Adoption order expiry warnings
        for order in viewModel.adoptionOrders where !order.isComplete && !order.isClaimed {
            notifManager.scheduleOrderExpiry(
                orderID:       order.id.uuidString,
                timeRemaining: order.timeRemaining,
                summary:       order.orderDescription)
        }

        // 4. Re-engagement nudge (48 hours)
        notifManager.scheduleReengagement()
    }

    // MARK: Game scroll content

    /// Top-level game layout — fixed, non-scrolling.
    var gameScrollContent: some View {
        VStack(spacing: 0) {
            // ── Fixed header ──────────────────────────────────────
            VStack(spacing: 6) {
                // Currency bar + Shop button
                HStack(spacing: 6) {
                    // Kibble card
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.28, green: 0.15, blue: 0.02))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.kibbleDisplayText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewModel.kibble == 0
                                                 ? Color(red: 0.75, green: 0.15, blue: 0.10)
                                                 : Color(red: 0.15, green: 0.15, blue: 0.15))
                            if viewModel.kibble < kibbleRegenCap {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 8, weight: .semibold))
                                    Text(viewModel.kibbleStatusText)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.kibble < kibbleRegenCap)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 1.0, green: 0.97, blue: 0.90)))

                    Spacer()

                    // Centre stats
                    VStack(spacing: 2) {
                        Text("Rescued: \(viewModel.rescueCount)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        (Text(Image(systemName: "medal.fill")) + Text(" Amb: \(viewModel.ambassadors)"))
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        HStack(spacing: 3) {
                            Image(systemName: "coin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                            Text("\(viewModel.coins)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                        }
                    }

                    Spacer()

                    // Dog Tags card
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.20, green: 0.40, blue: 0.65))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.dogTags)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                            if viewModel.isPassActive {
                                HStack(spacing: 2) {
                                    Image(systemName: "medal.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                                    Text("Pass Active")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                                }
                            } else {
                                Text("Dog Tags")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.40))
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isPassActive
                              ? Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.12)
                              : Color(red: 0.92, green: 0.95, blue: 1.0)))

                    // Shop button
                    Button(action: { activeRoute = .shop }) {
                        VStack(spacing: 2) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 18))
                            Text("Shop")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.3, green: 0.5, blue: 0.7)))
                    }
                }
                .padding(.horizontal)

                // Pass daily claim strip
                if viewModel.canClaimPassDaily {
                    PassDailyClaimView(viewModel: viewModel)
                        .padding(.horizontal)
                        .transition(.opacity)
                }

            }
            .padding(.top, 8)

            // ── Horizontal task strip ─────────────────────────────
            TaskStripView(viewModel: viewModel, activeSheet: Binding(
                get: { if case .task(let t) = activeRoute { return t } else { return nil } },
                set: { activeRoute = $0.map { .task($0) } }
            ))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                tutorialTaskFrame = $0
            }

            // ── Fixed board area ──────────────────────────────────
            boardSection
        }
    }

    /// Board area — cell size is derived from available screen width so the board fills
    /// the device horizontally with a small side clearance, on any screen size.
    private var boardSection: some View {
        GeometryReader { geo in
            // Side clearance: 8 pt each side keeps cells a comfortable distance from
            // the device edge and guarantees the board never clips the screen boundary.
            let sidePad:  CGFloat = 8
            let wSpacing  = CGFloat(viewModel.cols - 1) * cellSpacing
            let hSpacing  = CGFloat(viewModel.rows - 1) * cellSpacing
            // boardPad: the .padding() inside boardGridView adds 16 pt on each side.
            let boardPad: CGFloat = 32
            // Cell size from width — fills the board horizontally.
            let csW = floor((geo.size.width - sidePad * 2 - wSpacing) / CGFloat(viewModel.cols))
            // Cell size from height — prevents the board from ever growing into the bottom bar.
            let csH = floor((geo.size.height - hSpacing - boardPad - 8) / CGFloat(viewModel.rows))
            let cs         = max(32, min(csW, csH))
            // Explicit board width so SwiftUI centres it without any ambiguity.
            let boardWidth = cs * CGFloat(viewModel.cols) + wSpacing

            VStack(spacing: 6) {
                Spacer(minLength: 0)

                // Game board — pinned to its exact computed width and centred.
                boardGridView(cellSize: cs)
                    .frame(width: boardWidth)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        tutorialBoardFrame = $0
                    }

                // Level-based unlock progress bar — only shown while rows are still locked.
                if !viewModel.lockedCells.isEmpty {
                    VStack(spacing: 3) {
                        Text(viewModel.unlockHintText).font(.caption)
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        GeometryReader { bg in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(colors: [.green.opacity(0.7), .green],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: bg.size.width * viewModel.unlockProgress)
                                    .animation(.easeInOut(duration: 0.4), value: viewModel.unlockProgress)
                            }
                        }.frame(height: 8)
                    }
                    .frame(width: boardWidth)
                }

                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Full-panel sheet content for a tapped task card.
    @ViewBuilder
    private func routeContent(_ route: SheetRoute) -> some View {
        switch route {
        case .shop:
            ShopView(storeManager: storeManager, viewModel: viewModel)
        case .task(.event):
            if let event = viewModel.activeEvent {
                EventSheetView(viewModel: viewModel, event: event)
            }
        case .task(let sheet):
            NavigationStack {
                ScrollView { sheetBody(for: sheet) }
                .navigationTitle(sheet.title)
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { activeRoute = nil }
                    }
                }
                #endif
            }
        case .kibbleRefill:
            KibbleRefillSheet(viewModel: viewModel)
        case .mergeProgression(let chainID):
            MergeProgressionView(chainID: chainID)
        }
    }

    @ViewBuilder
    private func sheetBody(for sheet: TaskSheet) -> some View {
        switch sheet {
        case .adoptionOrders:
            AdoptionOrderPanelView(viewModel: viewModel).padding()
        case .dailyChallenges:
            DailyChallengePanelView(viewModel: viewModel).padding()
        case .quests:
            VStack(alignment: .leading, spacing: 12) {
                Label("Active Quests", systemImage: "target")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.08, green: 0.35, blue: 0.08))
                AmbassadorCollectionQuestCard(viewModel: viewModel)
                ForEach(viewModel.activeQuests) { quest in
                    QuestCardView(quest: quest) { viewModel.claimQuest(id: quest.id) }
                }
            }
            .padding()
        case .loyalty:
            LoyaltyClubPanelView(viewModel: viewModel).padding()
        case .invite:
            InvitePanelView(viewModel: viewModel).padding()
        case .weeklyGoal:
            WeeklyGoalPanelView(viewModel: viewModel).padding()
        case .monthlyGoal:
            MonthlyGoalPanelView(viewModel: viewModel).padding()
        case .event:
            EmptyView()
        }
    }

    // MARK: Board grid (extracted to limit re-render scope)

    /// Renders the merge board at the given cell size (computed dynamically from available space).
    func boardGridView(cellSize: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<viewModel.rows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<viewModel.cols, id: \.self) { col in
                        let cell        = viewModel.board[row][col]
                        let pos         = GridPosition(row: row, col: col)
                        let isDragging  = viewModel.draggingFrom == pos
                        let isSpotlight = cell.item?.chainID == viewModel.spotlightChainID

                        ZStack {
                            CellView(
                                cell: cell,
                                isSelected: viewModel.selectedCell == pos,
                                isAnimating: viewModel.animatingCell == pos,
                                isDragging: isDragging,
                                isNewlyUnlocked: viewModel.newlyUnlockedCell == pos,
                                isSpotlight: isSpotlight,
                                cellSize: cellSize
                            )
                            // Drag ghost — animal or producer icon follows the finger
                            if isDragging {
                                Group {
                                    if let item = cell.item {
                                        Image(systemName: item.def?.symbol ?? "questionmark")
                                            .foregroundColor(item.def?.tint ?? item.def?.color ?? .gray)
                                    } else if let producer = cell.producer {
                                        Image(systemName: producer.level.sfSymbol)
                                            .foregroundColor(producer.level.tintColor)
                                    }
                                }
                                .font(.system(size: 44))
                                .scaleEffect(1.2)
                                .shadow(color: .black.opacity(0.25), radius: 8)
                                .offset(dragOffset)
                                .allowsHitTesting(false).zIndex(99)
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                        .onTapGesture { viewModel.boardCellTapped(at: pos) }
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { v in
                                    if viewModel.draggingFrom == nil { viewModel.draggingFrom = pos }
                                    dragOffset = v.translation
                                    // Expand hit zone by 20 pt so the drop is easy to land
                                    isDraggingOverBasket = basketGlobalFrame
                                        .insetBy(dx: -20, dy: -20)
                                        .contains(v.location)
                                }
                                .onEnded { v in
                                    let droppedOnBasket = basketGlobalFrame
                                        .insetBy(dx: -20, dy: -20)
                                        .contains(v.location)
                                    isDraggingOverBasket = false
                                    if droppedOnBasket {
                                        // Route to correct storage by cell content
                                        if viewModel.board[pos.row][pos.col].producer != nil {
                                            viewModel.retireProducer(at: pos)
                                        } else {
                                            viewModel.sendBoardItemToInventory(from: pos)
                                        }
                                    } else {
                                        let rowOff = Int((v.translation.height / (cellSize + cellSpacing)).rounded())
                                        if pos.row + rowOff > viewModel.rows {
                                            viewModel.sendBoardItemToInventory(from: pos)
                                        } else {
                                            let colOff = Int((v.translation.width / (cellSize + cellSpacing)).rounded())
                                            let tgt = GridPosition(
                                                row: max(0, min(viewModel.rows - 1, pos.row + rowOff)),
                                                col: max(0, min(viewModel.cols - 1, pos.col + colOff)))
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                viewModel.attemptMergeOrMove(from: pos, to: tgt)
                                            }
                                        }
                                    }
                                    viewModel.draggingFrom = nil
                                    dragOffset             = .zero
                                }
                        )
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.5)).shadow(color: .black.opacity(0.1), radius: 8))
    }

    // MARK: Bottom bar

    var bottomBar: some View {
        HStack(alignment: .center, spacing: 0) {

            // Storage button — anchored left
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if viewModel.showInventory {
                        viewModel.showInventory = false
                        viewModel.selectedInventorySlot = nil
                    } else {
                        viewModel.showMap = false
                        viewModel.showInventory = true
                    }
                }
            }) {
                VStack(spacing: 3) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "basket.fill").font(.system(size: 28))
                        if viewModel.inventoryOccupied > 0 {
                            Text("\(viewModel.inventoryOccupied)")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                .padding(3)
                                .background(Circle().fill(Color(red: 0.7, green: 0.3, blue: 0.2)))
                                .offset(x: 8, y: -4)
                        }
                    }
                    Text(viewModel.showInventory ? "Close" : "Storage")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(red: 0.25, green: 0.12, blue: 0.04))
                }
                .frame(width: 64).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDraggingOverBasket
                              ? Color(red: 0.25, green: 0.65, blue: 0.35).opacity(0.35)
                              : (viewModel.showInventory
                                 ? Color(red: 0.08, green: 0.35, blue: 0.08).opacity(0.18)
                                 : Color.white.opacity(0.35)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(red: 0.25, green: 0.65, blue: 0.35)
                                          .opacity(isDraggingOverBasket ? 0.85 : 0),
                                      lineWidth: 2)
                )
                .scaleEffect(isDraggingOverBasket ? 1.15 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isDraggingOverBasket)
            }
            .foregroundColor(Color(red: 0.25, green: 0.12, blue: 0.04))
            .padding(.leading, 16)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                basketGlobalFrame = newFrame
            }

            // Centre info panel — fills available space
            ZStack {
                if let info = viewModel.selectedItemInfo {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        if info.chainID != nil {
                            Button(action: { activeRoute = info.chainID.map { .mergeProgression($0) } }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.28, green: 0.50, blue: 0.72))
                                        .frame(width: 15, height: 15)
                                    Text("i")
                                        .font(.system(size: 9, weight: .bold, design: .serif))
                                        .foregroundColor(.white)
                                        .offset(x: 0.5)
                                }
                            }
                            .offset(y: -4)
                        }
                        Text(info.text)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.22, green: 0.22, blue: 0.22))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.40)))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.18), value: viewModel.selectedItemInfo?.text)

            // Spawn multiplier — only visible when a producer is selected
            if viewModel.selectedCellHasProducer {
                SpawnMultiplierButton(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            // Map button — anchored right
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if viewModel.showMap {
                        viewModel.showMap = false
                    } else {
                        viewModel.showInventory = false
                        viewModel.selectedInventorySlot = nil
                        viewModel.showMap = true
                    }
                }
            }) {
                VStack(spacing: 3) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "map.fill").font(.system(size: 28))
                        let built = viewModel.completedAreaIDs.count
                        if built > 0 {
                            Text("\(built)")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                .padding(3)
                                .background(Circle().fill(Color(red: 0.45, green: 0.32, blue: 0.08)))
                                .offset(x: 8, y: -4)
                        }
                    }
                    Text(viewModel.showMap ? "Close" : "Map")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(red: 0.10, green: 0.28, blue: 0.06))
                }
                .frame(width: 64).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.showMap
                          ? Color(red: 0.28, green: 0.45, blue: 0.22).opacity(0.18)
                          : Color.white.opacity(0.35)))
            }
            .foregroundColor(Color(red: 0.10, green: 0.28, blue: 0.06))
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.selectedCellHasProducer)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.88, blue: 0.75).opacity(0),
                         Color(red: 0.95, green: 0.88, blue: 0.75)],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

// ============================================================
// MARK: - AMBASSADOR COLLECTION QUEST CARD
// ============================================================

private struct AmbassadorCollectionQuestCard: View {
    let viewModel: MergeBoardViewModel

    var body: some View {
        let goal     = viewModel.ambassadorQuestGoal
        let progress = min(viewModel.ambassadorQuestProgress, goal)
        let ready    = viewModel.ambassadorQuestReady

        HStack(spacing: 12) {
            // Icon
            Image(systemName: "medal.fill")
                .font(.system(size: 28))
                .foregroundColor(ready ? .white : Color(red: 0.72, green: 0.50, blue: 0.05))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ready
                              ? LinearGradient(colors: [Color(red: 0.75, green: 0.50, blue: 0.05),
                                                        Color(red: 0.95, green: 0.72, blue: 0.10)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.4),
                                                        Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.4)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Fully Merged Trio")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("STANDING")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.55, green: 0.35, blue: 0.02)))
                }
                Text("Merge 3 animals to Ambassador tier")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ready ? Color(red: 0.72, green: 0.50, blue: 0.05)
                                        : Color(red: 0.72, green: 0.50, blue: 0.05).opacity(0.6))
                            .frame(width: geo.size.width * (Double(progress) / Double(goal)))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }.frame(height: 5)

                HStack {
                    Text("\(progress)/\(goal) Ambassadors")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "coin.fill").font(.system(size: 9))
                            .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                        Text("+\(viewModel.ambassadorQuestCoinReward)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                    }
                }
            }

            if ready {
                Button(action: { viewModel.claimAmbassadorQuest() }) {
                    Text("Claim")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.72, green: 0.50, blue: 0.05)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(ready ? Color(red: 1.0, green: 0.96, blue: 0.82).opacity(0.95)
                        : Color.white.opacity(0.75))
            .shadow(color: .black.opacity(ready ? 0.08 : 0.04), radius: ready ? 5 : 3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ready ? Color(red: 0.72, green: 0.50, blue: 0.05).opacity(0.5)
                                    : Color.clear, lineWidth: 1.5)
        )
    }
}

// ============================================================
// MARK: - PASS DAILY CLAIM STRIP
// ============================================================

private struct PassDailyClaimView: View {
    let viewModel: MergeBoardViewModel

    var body: some View {
        Button(action: { viewModel.claimPassDaily() }) {
            HStack(spacing: 8) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                Text("Sanctuary Pass — Daily Kibble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.10, blue: 0.55))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "pawprint.fill").font(.system(size: 10))
                    Text("+\(passDailyKibble)").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color(red: 0.25, green: 0.55, blue: 0.35))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.25), lineWidth: 1)
                ))
        }
    }
}

// ============================================================
// MARK: - WATCH AD STRIP
// ============================================================

// ============================================================
// MARK: - KIBBLE REFILL SHEET
// ============================================================

/// Shown when a player tries to spawn without enough kibble.
/// Offers a rewarded-ad top-up (+25, up to 4x/day) and dog-tag exchanges.
private struct KibbleRefillSheet: View {
    let viewModel: MergeBoardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current kibble status
                    HStack(spacing: 10) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.28, green: 0.15, blue: 0.02))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You're out of kibble")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                            Text("\(viewModel.kibble) / \(kibbleRegenCap) — refills 1 every 2 min")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 1.0, green: 0.97, blue: 0.90)))

                    // Watch Ad section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Watch an Ad").font(.subheadline.bold())
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        if viewModel.remainingAdWatches > 0 {
                            Button(action: {
                                viewModel.watchRewardedAd()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 16))
                                    Text("Watch Ad for +\(viewModel.effectiveAdKibble) Kibble")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Text("\(viewModel.remainingAdWatches) left today")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.25, green: 0.55, blue: 0.35)))
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                                Text("No more ads available today")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.12)))
                        }
                    }

                    Divider()

                    // Dog Tag exchange section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exchange Dog Tags").font(.subheadline.bold())
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        ForEach(DogTagKibbleExchange.all, id: \.dogTagCost) { exchange in
                            let canAfford = viewModel.dogTags >= exchange.dogTagCost
                            Button(action: {
                                viewModel.exchangeTagsForKibble(exchange)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 14))
                                    Text("\(exchange.dogTagCost) Dog Tags")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    HStack(spacing: 3) {
                                        Image(systemName: "pawprint.fill")
                                            .font(.system(size: 11))
                                        Text("+\(exchange.kibbleGain) Kibble")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                                .foregroundColor(canAfford ? .white : Color(red: 0.50, green: 0.45, blue: 0.40))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(canAfford
                                          ? Color(red: 0.20, green: 0.40, blue: 0.65)
                                          : Color(red: 0.92, green: 0.88, blue: 0.78)))
                            }
                            .disabled(!canAfford)
                        }
                        if viewModel.dogTags == 0 {
                            Text("Earn Dog Tags by merging animals to the Ambassador tier.")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                                .padding(.top, 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Need More Kibble?")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            #endif
        }
        .presentationDetents([.medium, .large])
    }
}

// ============================================================
// MARK: - WATCH AD STRIP (legacy — kept for potential reuse)
// ============================================================

private struct WatchAdStripView: View {
    let viewModel: MergeBoardViewModel

    var body: some View {
        Button(action: { viewModel.watchRewardedAd() }) {
            HStack(spacing: 8) {
                if viewModel.isWatchingAd {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Loading ad...")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("Watch Ad")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 2) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 10))
                        Text("+\(adKibbleReward)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("\(viewModel.remainingAdWatches) left today")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(viewModel.isWatchingAd
                      ? Color(red: 0.45, green: 0.45, blue: 0.45)
                      : Color(red: 0.25, green: 0.55, blue: 0.35)))
        }
        .disabled(viewModel.isWatchingAd)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isWatchingAd)
    }
}

// ============================================================
// MARK: - SPAWN MULTIPLIER BUTTON
// ============================================================

/// Cycles the global spawn multiplier (1X → 2X → 4X → 8X → 1X).
/// Higher tiers unlock at player levels 5 / 10 / 20.
/// Each tap of a board animal-spawner costs `spawnMultiplier` kibble
/// and produces a piece at tier `spawnMultiplier - 1`.
private struct SpawnMultiplierButton: View {
    let viewModel: MergeBoardViewModel

    private var label: String { "\(viewModel.spawnMultiplier)X" }
    private var isMaxUnlocked: Bool { viewModel.unlockedMultipliers.count == 4 }

    // Next locked multiplier to hint at, or nil when all are unlocked
    private var nextLockedMultiplier: Int? {
        let all = [1, 2, 4, 8]
        return all.first { !viewModel.unlockedMultipliers.contains($0) }
    }

    var body: some View {
        Button(action: { viewModel.cycleSpawnMultiplier() }) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(multiplierColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Text(label)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(multiplierColor)
                }
                Text("Spawn")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(multiplierColor.opacity(0.8))
                if let next = nextLockedMultiplier {
                    Text("Lv.\(unlockLevel(for: next)) → \(next)X")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(multiplierColor.opacity(0.1)))
        }
    }

    private var multiplierColor: Color {
        switch viewModel.spawnMultiplier {
        case 2:  return Color(red: 0.20, green: 0.45, blue: 0.75)
        case 4:  return Color(red: 0.60, green: 0.32, blue: 0.75)
        case 8:  return Color(red: 0.75, green: 0.38, blue: 0.12)
        default: return Color(red: 0.30, green: 0.55, blue: 0.35)
        }
    }

    private func unlockLevel(for multiplier: Int) -> Int {
        switch multiplier {
        case 2: return 5
        case 4: return 10
        case 8: return 20
        default: return 0
        }
    }
}

// ============================================================
// MARK: - SHEET ROUTE
// ============================================================

private enum SheetRoute: Identifiable, Equatable {
    case shop
    case task(TaskSheet)
    case kibbleRefill
    case mergeProgression(String)

    var id: String {
        switch self {
        case .shop:                       return "shop"
        case .task(let t):                return "task-\(t.rawValue)"
        case .kibbleRefill:               return "kibbleRefill"
        case .mergeProgression(let cid):  return "progression-\(cid)"
        }
    }
}

// ============================================================
// MARK: - MERGE PROGRESSION VIEW
// ============================================================

private struct MergeProgressionView: View {
    let chainID: String

    var body: some View {
        let chain = ContentRegistry.shared.chain(chainID)
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array((chain?.tiers ?? []).enumerated()), id: \.offset) { index, tier in
                        // Tier row
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((tier.tint ?? tier.color).opacity(0.12))
                                    .frame(width: 52, height: 52)
                                Image(systemName: tier.symbol)
                                    .font(.system(size: 26))
                                    .foregroundColor(tier.tint ?? tier.color)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tier.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                                Text("Tier \(index + 1) of \(chain?.tiers.count ?? 0)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if index == (chain?.maxTier ?? 0) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.10))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        // Arrow connector between tiers
                        if index < (chain?.maxTier ?? 0) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray.opacity(0.35))
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("\(chain?.displayName ?? "Item") Chain")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.88, green: 0.96, blue: 0.88),
                             Color(red: 0.97, green: 0.92, blue: 0.80)],
                    startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
        }
    }
}
