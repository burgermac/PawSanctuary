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
            .task { viewModel.loadGame() }
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

            // Gated on isLoaded: the board and most of the panel/task-strip
            // view layer scan board[r][c] for r/c up to viewModel.rows/.cols,
            // which already hold their real values before loadGame() has
            // actually populated board — rendering this content one frame
            // early is an out-of-bounds crash, not just an empty frame.
            if viewModel.isLoaded {
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
                BannerView(
                    title: "New Row Unlocked!",
                    detail: "7 more spaces are now open for rescued animals!",
                    background: AnyShapeStyle(Color(red: 0.2, green: 0.55, blue: 0.35)),
                    bottomPadding: 70
                ) {
                    Image(systemName: "lock.open.fill").font(.system(size: 32))
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
                BannerView(
                    title: viewModel.levelUpBannerTitle,
                    detail: viewModel.levelUpBannerDetail,
                    background: AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.20, green: 0.45, blue: 0.30),
                                 Color(red: 0.35, green: 0.60, blue: 0.40)],
                        startPoint: .leading, endPoint: .trailing)),
                    bottomPadding: 80
                ) {
                    ZStack {
                        Circle().fill(Color.yellow.opacity(0.25)).frame(width: 46, height: 46)
                        Text("Lv.\(viewModel.playerLevel)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.yellow)
                    }
                }
                .zIndex(99)
            }

            // Area-built celebration banner
            if viewModel.showAreaBuiltBanner {
                BannerView(
                    title: viewModel.areaBuiltBannerTitle,
                    detail: viewModel.areaBuiltBannerDetail,
                    background: AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.48, green: 0.32, blue: 0.08),
                                 Color(red: 0.65, green: 0.48, blue: 0.12)],
                        startPoint: .leading, endPoint: .trailing)),
                    bottomPadding: 80
                ) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.72, green: 0.50, blue: 0.10).opacity(0.25))
                            .frame(width: 46, height: 46)
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                    }
                }
                .zIndex(98)
            }

            // Superpower unlock celebration banner — a one-time heads-up, not a
            // persistent UI element. Actives no longer get a button strip; they
            // become findable as board pieces (see superpowerUnlockBannerDetail).
            if viewModel.showSuperpowerUnlockBanner, let sp = viewModel.superpowerUnlockBannerSpecies {
                BannerView(
                    title: "Superpower Unlocked!",
                    detail: viewModel.superpowerUnlockBannerDetail(for: sp),
                    background: AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.35, green: 0.10, blue: 0.55),
                                 Color(red: 0.55, green: 0.25, blue: 0.75)],
                        startPoint: .leading, endPoint: .trailing)),
                    bottomPadding: 80
                ) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.25)).frame(width: 46, height: 46)
                        Image(systemName: sp.superpower.sfSymbol)
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                    }
                }
                .zIndex(97)
            }

            // Leap mode overlay hint — armed by merging a Leap piece onto a target
            // (see applyLeapPiece), so leapSourceCell is always already set here;
            // this is purely "pick the destination" now, no source-selection step.
            if viewModel.leapMode {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Tap an empty cell for the destination")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Button("Cancel") {
                                viewModel.leapMode = false
                                viewModel.leapSourceCell = nil
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .zIndex(95)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.showSuperpowerUnlockBanner)
        .animation(.easeInOut(duration: 0.25), value: viewModel.leapMode)
        .animation(.easeInOut(duration: 0.35), value: tutorialStep)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .sheet(item: $activeRoute) { route in routeContent(route) }
        .alert("Save Not Restored", isPresented: $viewModel.showIncompatibleSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your save is from an older version of the app and could not be restored. A new game has been started.")
        }
        .onChange(of: viewModel.showKibbleSheet) { _, show in
            if show { activeRoute = .kibbleRefill; viewModel.showKibbleSheet = false }
        }
        .onAppear {
            storeManager.onPurchaseComplete = { viewModel.applyPurchase($0, priceUSD: $1) }
            viewModel.isPassActive = storeManager.isPassActive
            // The tutorial step above only initialized from the completion flag, never
            // from actual progress — onChange only fires on a later *change* in
            // rescueCount/mergeCount, not on the initial load. A force-quit between
            // tutorial steps (completion flag not yet set) would otherwise replay
            // "rescue your first animal" for a player who already has animals and
            // has merged. Sync it once here against the real, persisted counts.
            if !UserDefaults.standard.bool(forKey: "tutorialCompleted") {
                if viewModel.mergeCount > 0 { tutorialStep = .quest }
                else if viewModel.rescueCount > 0 { tutorialStep = .merge }
            }
            // Cancel stale notifications whenever the app becomes visible
            NotificationManager.shared.cancelAll()
            // Request permission once the player has made some progress
            if viewModel.playerLevel > 1 {
                Task { await NotificationManager.shared.requestPermission() }
            }
        }
        .onChange(of: storeManager.isPassActive) { _, active in
            viewModel.isPassActive = active
        }
        .onChange(of: viewModel.playerLevel) { _, level in
            // Ask for permission at the moment they first level up
            if level == 2 {
                Task { await NotificationManager.shared.requestPermission() }
            }
            // Schedule the daily rewards reminder once we have permission
            if NotificationManager.shared.isAuthorised { NotificationManager.shared.scheduleDailyRewards() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Mark when we left, so returning to .active can credit regen
                // that the (now-suspended) live timer missed.
                viewModel.appDidEnterBackground()
                // Flush save synchronously — a detached Task.detached save may never
                // get scheduled before iOS suspends the process from here.
                viewModel.persistNow()
                // Schedule all re-engagement notifications
                scheduleAllNotifications()
            case .inactive:
                // Transient (Control Centre, a notification banner, app switcher
                // preview, or the moment on the way back to .active) — not the real
                // suspension point, so an async flush is fine and avoids a
                // synchronous main-thread encode on every one of these.
                viewModel.appDidEnterBackground()
                viewModel.persist()
                scheduleAllNotifications()
            case .active:
                // Catch up on kibble regen / producer cooldowns / adoption
                // orders for the time spent backgrounded.
                viewModel.appDidBecomeActive()
                // Cancel everything — the player is here now
                NotificationManager.shared.cancelAll()
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
        guard NotificationManager.shared.isAuthorised else { return }

        // 1. Kibble full
        let kibblePerTick = 1 + viewModel.activeBonuses.kibblePerRegen
        NotificationManager.shared.scheduleKibbleFull(
            currentKibble:  viewModel.kibble,
            regenCap:       kibbleRegenCap,
            secsUntilNext:  viewModel.secondsUntilNextKibble,
            regenSecs:      kibbleRegenSecs,
            kibblePerTick:  kibblePerTick)

        // 2. Daily rewards (persistent daily — schedule once, keeps firing)
        NotificationManager.shared.scheduleDailyRewards()

        // 3. Urgent order expiry warning — the persistent slots have no timer
        // (Phase 5, Task 5.2), so there's exactly one order left that can expire.
        if let urgent = viewModel.urgentOrder, !urgent.isComplete && !urgent.isClaimed {
            NotificationManager.shared.scheduleOrderExpiry(
                orderID:       urgent.id.uuidString,
                timeRemaining: viewModel.urgentOrderTimeRemaining,
                summary:       urgent.orderDescription)
        }

        // 4. Re-engagement nudge (48 hours)
        NotificationManager.shared.scheduleReengagement()
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
                            Image(systemName: "dollarsign.circle.fill")
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

                    // Shop button — hidden until the D7 monetization gate flips
                    // (Task 3.4): a fresh account sees no store push at all.
                    if viewModel.isMonetizationUnlocked {
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
                EventSheetView(viewModel: viewModel, event: event, storeManager: storeManager)
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
            KibbleRefillSheet(viewModel: viewModel, storeManager: storeManager)
        case .mergeProgression(let chainID):
            MergeProgressionView(chainID: chainID)
        case .bubblePop(let pos):
            BubblePopSheet(viewModel: viewModel, position: pos)
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

    /// A small directional offset for `pos`, toward its partner in
    /// `viewModel.mergeHintPair`, while the hint is in its "nudged toward
    /// each other" phase. `.zero` for every other cell.
    private func mergeHintOffset(for pos: GridPosition, cellSize: CGFloat) -> CGSize {
        guard viewModel.mergeHintPulsedIn, let (a, b) = viewModel.mergeHintPair else { return .zero }
        let partner: GridPosition
        if pos == a { partner = b } else if pos == b { partner = a } else { return .zero }
        let dRow = Double(partner.row - pos.row)
        let dCol = Double(partner.col - pos.col)
        let length = (dRow * dRow + dCol * dCol).squareRoot()
        guard length > 0 else { return .zero }
        let magnitude = cellSize * 0.22
        return CGSize(width: dCol / length * magnitude, height: dRow / length * magnitude)
    }

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
                        let mergeHintOffset = mergeHintOffset(for: pos, cellSize: cellSize)

                        ZStack {
                            CellView(
                                cell: cell,
                                isSelected: viewModel.selectedCell == pos,
                                isAnimating: viewModel.animatingCell == pos,
                                isDragging: isDragging,
                                isNewlyUnlocked: viewModel.newlyUnlockedCell == pos,
                                isSpotlight: isSpotlight,
                                cellSize: cellSize,
                                unlockedSuperpowerSpecies: viewModel.unlockedSuperpowerSpecies,
                                isLeapSource: viewModel.leapSourceCell == pos,
                                mergeHintOffset: mergeHintOffset
                            )
                            .animation(.easeInOut(duration: 0.55), value: viewModel.mergeHintPulsedIn)
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
                        .onTapGesture {
                            if viewModel.isActiveBubble(at: pos) {
                                activeRoute = .bubblePop(pos)
                            } else {
                                viewModel.boardCellTapped(at: pos)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { v in
                                    if viewModel.draggingFrom == nil {
                                        viewModel.draggingFrom = pos
                                        viewModel.noteBoardInteraction()
                                    }
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
            } else if viewModel.selectedCellHasAnimalItem {
                SellAnimalButton(viewModel: viewModel)
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
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.selectedCellHasAnimalItem)
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
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: 9))
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

/// The designed wall moment (Phase 3, Tasks 3.1/3.3/3.4): shown when a player
/// tries to spawn without enough kibble. Pre-gate (D7 session-one silence)
/// it's just the status card and the nearest unfinished order — no ad, no
/// exchange, no bundle. Post-gate it's the full ladder: rewarded ad first
/// (free, capped), then the Dog Tag exchange, then a paid bundle — followed
/// by the nearest unfinished order either way, so the player leaves seeing
/// what's still open rather than just what they bought.
private struct KibbleRefillSheet: View {
    let viewModel: MergeBoardViewModel
    let storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    kibbleStatusCard

                    if viewModel.isMonetizationUnlocked {
                        watchAdSection
                        Divider()
                        dogTagExchangeSection
                        Divider()
                        KibbleRefillBundleRow(viewModel: viewModel, storeManager: storeManager)
                    } else {
                        Text("Kibble refills on its own — check back in a bit!")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    if let (order, timeText) = viewModel.nearestIncompleteOrder {
                        nearestOrderFooter(order, timeText: timeText)
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

    private var kibbleStatusCard: some View {
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
    }

    @ViewBuilder
    private var watchAdSection: some View {
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
    }

    private var dogTagExchangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exchange Dog Tags").font(.subheadline.bold())
                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
            // One rung at a time: each exchange makes the next dearer,
            // and the ladder resets tomorrow (Task 2.4).
            let exchange = viewModel.currentTagExchange
            let canAfford = viewModel.dogTags >= exchange.dogTagCost
            Button(action: {
                viewModel.exchangeTagsForKibble()
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
            Text(exchange.isAtFlatRate
                 ? "Today's discounts are used up — the rate is flat until tomorrow."
                 : "Today's price. The next exchange costs more; resets tomorrow.")
                .font(.caption)
                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
            if viewModel.dogTags == 0 {
                Text("Earn Dog Tags by merging animals to the Ambassador tier.")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                    .padding(.top, 2)
            }
        }
    }

    private func nearestOrderFooter(_ order: AdoptionOrder, timeText: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: order.iconSymbol)
                .font(.system(size: 18))
                .foregroundColor(order.iconTint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(order.family.name) is still waiting for \(order.orderDescription)")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                Text(timeText.map { "\($0) left" } ?? "Open — no rush")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.98, green: 0.94, blue: 0.90)))
    }
}

/// The "bundle" rung of the Task 3.1 ladder: the Starter Bundle framed as a
/// welcome offer before the player's first purchase (Task 3.4's first-purchase
/// offer), the smallest Energy Pack afterward.
private struct KibbleRefillBundleRow: View {
    let viewModel: MergeBoardViewModel
    let storeManager: StoreManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.commerce.hasEverPurchased {
                Text("Or Refill With a Bundle").font(.subheadline.bold())
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                if let contents = IAPProduct.energySmall.energyPackContents {
                    EnergyPackRow(iap: .energySmall, contents: contents, storeManager: storeManager)
                }
            } else {
                Label("Welcome Offer", systemImage: "gift.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(red: 0.75, green: 0.35, blue: 0.15))
                if let product = storeManager.products.first(where: { $0.id == IAPProduct.starterBundle.rawValue }) {
                    ShopItemRow(product: product, iap: .starterBundle, storeManager: storeManager)
                } else {
                    ShopItemPreviewRow(product: .starterBundle)
                }
            }
        }
    }
}

// ============================================================
// MARK: - BUBBLE POP SHEET
// ============================================================

/// Shown when the player taps a still-active bubble (Phase 4, Task 4.4).
/// "Converts a moment of success into a decision at the instant the player
/// feels good" (Merge2_Reference_Blueprint.md §23) — pop now for the full
/// item via ad or Dog Tags, or close this and let it decay into a smaller,
/// guaranteed coin reward later.
private struct BubblePopSheet: View {
    let viewModel: MergeBoardViewModel
    let position: GridPosition
    @Environment(\.dismiss) private var dismiss

    private var item: BoardItem? { viewModel.board[position.row][position.col].item }

    private var decayedValue: Int {
        guard let item else { return 0 }
        return max(1, Int((Double(animalSellValue(tier: item.tier)) * bubbleDecayFloor).rounded()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let item, let def = item.def {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.cyan.opacity(0.18)).frame(width: 84, height: 84)
                            Image(systemName: def.symbol)
                                .font(.system(size: 34))
                                .foregroundColor(def.tint ?? def.color)
                        }
                        Text("🫧 Bubbled: \(def.name)")
                            .font(.headline)
                        Text("Pop it now for the full reward, or leave it — it decays into +\(decayedValue) Coins after \(Int(bubbleDecaySeconds / 60)) minutes.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 10) {
                        if viewModel.remainingAdWatches > 0 {
                            Button(action: {
                                viewModel.popBubbleWithAd(at: position)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("Watch Ad to Pop")
                                    Spacer()
                                    Text("\(viewModel.remainingAdWatches) left today")
                                        .font(.caption).foregroundColor(.white.opacity(0.85))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.25, green: 0.55, blue: 0.35)))
                            }
                        }

                        let cost = bubblePopDogTagCost(tier: item.tier)
                        let canAfford = viewModel.dogTags >= cost
                        Button(action: {
                            viewModel.popBubbleWithDogTags(at: position)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "tag.fill")
                                Text("Pop with \(cost) Dog Tags")
                                Spacer()
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
                    .padding(.horizontal)
                } else {
                    Text("This bubble is gone.").foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Bubble")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not Now") { dismiss() }
                }
            }
            #endif
        }
        .presentationDetents([.medium])
    }
}

// ============================================================
// MARK: - SPAWN MULTIPLIER BUTTON
// ============================================================

/// Cycles the global spawn multiplier (1X → 2X → 4X → 8X → 1X).
/// Higher tiers unlock at player levels 5 / 10 / 20.
/// The multiplier selects the tier produced (1/2/4/8 → tier 0/1/2/3); each tap
/// costs `2^tier` kibble, which is energy-neutral against merging it by hand.
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
// MARK: - SELL ANIMAL BUTTON
// ============================================================

/// Appears in the bottom bar when an animal cell is selected.
///
/// Shows both halves of the Phase 2c decision: what selling pays now, and what an
/// adoption order would pay for the same animal. Selling is always available but
/// always worse (~2.4×), and a choice the player cannot see is not a choice —
/// before this, only the sell price was on screen.
private struct SellAnimalButton: View {
    let viewModel: MergeBoardViewModel

    private var selectedItem: BoardItem? {
        guard let pos = viewModel.selectedCell,
              pos.row < viewModel.board.count,
              pos.col < (viewModel.board.first?.count ?? 0) else { return nil }
        return viewModel.board[pos.row][pos.col].item
    }

    private let sellTint = Color(red: 0.55, green: 0.35, blue: 0.02)

    var body: some View {
        if let item = selectedItem {
            let value      = viewModel.sellValue(forTier: item.tier)
            let orderValue = viewModel.orderValue(forTier: item.tier)
            Button(action: { viewModel.sellSelectedAnimal() }) {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(sellTint.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(sellTint)
                    }
                    Text("Sell")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(sellTint.opacity(0.8))
                    Text("+\(value)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.02))
                    // The road not taken: what an order would pay for this animal.
                    Text("order \(orderValue)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 70).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(sellTint.opacity(0.10)))
            }
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
    case bubblePop(GridPosition)

    var id: String {
        switch self {
        case .shop:                       return "shop"
        case .task(let t):                return "task-\(t.rawValue)"
        case .kibbleRefill:               return "kibbleRefill"
        case .mergeProgression(let cid):  return "progression-\(cid)"
        case .bubblePop(let pos):         return "bubble-\(pos.row)-\(pos.col)"
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
