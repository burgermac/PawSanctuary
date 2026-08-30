import XCTest
import SwiftUI
import UIKit
@testable import PawSanctuary

/// Screenshots — not assertions — of the two `Spec_BoardAnimation_Draft.md`
/// changes this repo has no local Simulator to look at: the §3a merge burst
/// (plus its §3a-correction cross-row `zIndex` fix) and the §5 producer
/// shimmer. Xcode's `xcodebuild test` already boots a real Simulator on CI;
/// these tests just point a real `UIWindow`/`UIHostingController` at the
/// production views mid-animation and save what they actually look like,
/// via `FileManager.default.temporaryDirectory` — which, because
/// `PawSanctuaryTests` is a `TEST_HOST`-hosted bundle (it runs *inside* the
/// real `PawSanctuary.app` process, not a bare test runner), resolves to a
/// path CI can pull straight out of the Simulator with
/// `xcrun simctl get_app_container`. No pass/fail assertion is meaningful
/// here — a human (or a future Claude with the resulting PNGs) has to
/// actually look. Delete once this project has a Simulator to check by eye.
@MainActor
final class BoardAnimationSnapshotTests: XCTestCase {

    private let dogChain = ContentRegistry.animalChainID(.dog)
    private let catChain = ContentRegistry.animalChainID(.cat)

    // MARK: - Harness plumbing

    /// A bare `UIWindow(frame:)` never gets composited on iOS 13+ unless it's
    /// attached to a live `UIWindowScene` — first attempt at this omitted
    /// that and every resulting screenshot came back entirely blank white,
    /// confirmed against real CI output. The host app is already running
    /// (this bundle is `TEST_HOST`-hosted inside it), so its own foreground
    /// scene is grabbed and reused rather than trying to stand up a new one.
    private func hostAndShow<V: View>(_ view: V, size: CGSize) -> UIWindow {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            XCTFail("No foreground-active UIWindowScene available to host the snapshot window")
            return UIWindow(frame: CGRect(origin: .zero, size: size))
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1000  // above the host app's own real window
        window.backgroundColor = .white
        let host = UIHostingController(rootView: view)
        host.view.frame = window.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    /// `drawHierarchy(afterScreenUpdates:)` over raw `CALayer.render(in:)` —
    /// the latter can miss content that hasn't committed to the render
    /// server yet, which is exactly the in-flight-animation case this exists
    /// to capture.
    private func snapshot(_ window: UIWindow) -> UIImage {
        UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func save(_ image: UIImage, name: String) {
        guard let data = image.pngData() else {
            XCTFail("Failed to encode \(name) as PNG")
            return
        }

        // Explicit data + UTI, not XCTAttachment(image:) — its default
        // encoding isn't documented to be PNG, and CI's fallback extraction
        // (reading straight out of the .xcresult's Data store, in case the
        // simctl app-container copy below ever stops resolving) content-
        // sniffs for "PNG image data", so what's actually stored here has
        // to be real PNG bytes, not whatever format XCTest might pick.
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)

        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("BoardAnimationSnapshots", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent("\(name).png"))
        } catch {
            // Not XCTFail: the XCTAttachment above already preserved the image
            // inside the .xcresult, so a filesystem hiccup here shouldn't
            // fail the build — it only loses the belt-and-suspenders copy CI
            // pulls out via simctl.
            NSLog("BoardAnimationSnapshotTests: failed to write \(name).png to disk: \(error)")
        }
    }

    // MARK: - §3a / §3a-correction: merge burst + cross-row overshoot

    /// Mirrors `MergeBoardView.boardGridView`'s actual structure (VStack of
    /// HStacks, `zIndex` on both the per-cell wrapper and the per-row
    /// HStack) closely enough to exercise the cross-row `zIndex` fix for
    /// real, not just re-test `CellView` in isolation. The animating cell
    /// sits in the *top* row so its overshoot has to bleed *downward* into
    /// the row below — the direction the original Tier A fix didn't cover.
    private struct MergeBurstHarness: View {
        let dogChain: ChainID
        let catChain: ChainID
        let cellSize: CGFloat = 100
        @State private var isAnimating = false

        var body: some View {
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { col in
                            let animatingHere = row == 0 && col == 0 && isAnimating
                            CellView(
                                cell: BoardCell(
                                    position: GridPosition(row: row, col: col),
                                    item: BoardItem(chainID: (row == 0 && col == 0) ? dogChain : catChain, tier: 1),
                                    isUnlocked: true),
                                isSelected: false,
                                isAnimating: animatingHere,
                                isDragging: false,
                                isNewlyUnlocked: false,
                                isSpotlight: false,
                                cellSize: cellSize
                            )
                            .frame(width: cellSize, height: cellSize)
                            .zIndex(animatingHere ? 5 : 0)
                        }
                    }
                    .zIndex(row == 0 && isAnimating ? 5 : 0)
                }
            }
            .padding(30)
            .background(Color(white: 0.85))
            .task {
                // Matches MergeBoardViewModel's real set-then-600ms-clear
                // pattern (e.g. finishSpawn), so the scale-up spring actually
                // springs back down within this test's own capture window.
                try? await Task.sleep(for: .milliseconds(80))
                isAnimating = true
                try? await Task.sleep(for: .milliseconds(600))
                isAnimating = false
            }
        }
    }

    func testMergeBurstOvershootAcrossRows() async throws {
        let harness = MergeBurstHarness(dogChain: dogChain, catChain: catChain)
        let window = hostAndShow(harness, size: CGSize(width: 280, height: 280))
        defer { window.isHidden = true }

        // Frame 1 (~+230ms): near peak elastic overshoot (spec: 0.2-0.3s in),
        // white-hot bloom and sparkle burst both freshly triggered.
        try await Task.sleep(for: .milliseconds(230))
        save(snapshot(window), name: "merge_burst_1_peak_overshoot")

        // Frame 2 (~+480ms): item still enlarged (600ms clear hasn't fired
        // yet), bloom fully decayed (0.22s), sparkles mid-drift.
        try await Task.sleep(for: .milliseconds(250))
        save(snapshot(window), name: "merge_burst_2_mid_drift")

        // Frame 3 (~+780ms): scale has sprung back to normal, sparkles
        // (0.9s life from their ~80ms spawn) still fading/drifting outward.
        try await Task.sleep(for: .milliseconds(300))
        save(snapshot(window), name: "merge_burst_3_settled_sparkles_fading")

        // Frame 4 (~+1180ms): everything should be fully at rest again — a
        // sanity check that nothing gets stuck mid-animation.
        try await Task.sleep(for: .milliseconds(400))
        save(snapshot(window), name: "merge_burst_4_at_rest")
    }

    // MARK: - §5 / §5a: producer affordance shimmer

    /// Side-by-side afford/can't-afford family spawners, same species and
    /// size, so the shimmer's presence or absence is a direct visual diff
    /// between the two halves of one screenshot.
    private struct ShimmerHarness: View {
        let cellSize: CGFloat = 130
        var body: some View {
            HStack(spacing: 24) {
                labeled("Affordable") {
                    CellView(
                        cell: BoardCell(position: GridPosition(row: 0, col: 0),
                                        producer: ProducerTile(level: .familySpawner, species: .dog),
                                        isUnlocked: true),
                        isSelected: false, isAnimating: false, isDragging: false,
                        isNewlyUnlocked: false, isSpotlight: false,
                        cellSize: cellSize,
                        isFamilySpawnerAffordable: true
                    )
                }
                labeled("Not affordable") {
                    CellView(
                        cell: BoardCell(position: GridPosition(row: 0, col: 1),
                                        producer: ProducerTile(level: .familySpawner, species: .dog),
                                        isUnlocked: true),
                        isSelected: false, isAnimating: false, isDragging: false,
                        isNewlyUnlocked: false, isSpotlight: false,
                        cellSize: cellSize,
                        isFamilySpawnerAffordable: false
                    )
                }
            }
            .padding(30)
            .background(Color(white: 0.9))
        }

        @ViewBuilder
        private func labeled<Content: View>(_ text: String, @ViewBuilder content: () -> Content) -> some View {
            VStack(spacing: 6) {
                content().frame(width: cellSize, height: cellSize)
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(.black)
            }
        }
    }

    func testSpawnerShimmerAffordabilityContrast() async throws {
        let window = hostAndShow(ShimmerHarness(), size: CGSize(width: 400, height: 220))
        defer { window.isHidden = true }

        // Three timepoints spread across the puffs' staggered 0.5-0.8s
        // cycles (see SpawnerPuffView) so at least one frame should catch
        // more than zero puffs mid-flight on the affordable side.
        try await Task.sleep(for: .milliseconds(300))
        save(snapshot(window), name: "spawner_shimmer_1")

        try await Task.sleep(for: .milliseconds(400))
        save(snapshot(window), name: "spawner_shimmer_2")

        try await Task.sleep(for: .milliseconds(500))
        save(snapshot(window), name: "spawner_shimmer_3")
    }
}
