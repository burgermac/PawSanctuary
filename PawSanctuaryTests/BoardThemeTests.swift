//
//  BoardThemeTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_BoardThemes.md: five free themes; three from the start, two
//  unlocked by built Sanctuary areas; a locked theme can never be selected.
//

import XCTest
import SwiftUI
import UIKit
@testable import PawSanctuary

@MainActor
final class BoardThemeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    func testTheStarterThemesAreFreeFromTheStart() {
        for theme in BoardTheme.starters {
            XCTAssertTrue(theme.isUnlocked(builtAreas: 0), theme.displayName)
        }
        XCTAssertEqual(Set(BoardTheme.starters), [.meadow, .seaside, .dusk])
    }

    func testTheLaterThemesUnlockExactlyAtTheirAreaCounts() {
        XCTAssertFalse(BoardTheme.autumn.isUnlocked(builtAreas: boardThemeAutumnAreas - 1))
        XCTAssertTrue(BoardTheme.autumn.isUnlocked(builtAreas: boardThemeAutumnAreas))
        XCTAssertFalse(BoardTheme.blossom.isUnlocked(builtAreas: boardThemeBlossomAreas - 1))
        XCTAssertTrue(BoardTheme.blossom.isUnlocked(builtAreas: boardThemeBlossomAreas))
        XCTAssertLessThan(boardThemeAutumnAreas, boardThemeBlossomAreas)
        XCTAssertLessThanOrEqual(boardThemeBlossomAreas, sanctuaryAreas.count, "must be reachable")
    }

    func testANewGameIsOnMeadowAndUnprompted() {
        let vm = MergeBoardViewModel()
        XCTAssertEqual(vm.boardTheme, .meadow)
        XCTAssertFalse(vm.boardThemePrompted)
    }

    func testSelectingAnUnlockedThemeChangesItAndSavesIt() {
        let vm = MergeBoardViewModel()
        XCTAssertTrue(vm.selectBoardTheme(.seaside))
        XCTAssertEqual(vm.boardTheme, .seaside)
        vm.persistNow()
        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()
        XCTAssertEqual(relaunched.boardTheme, .seaside, "the choice must survive a relaunch")
    }

    func testSelectingALockedThemeIsRefusedAndChangesNothing() {
        let vm = MergeBoardViewModel()
        XCTAssertFalse(vm.selectBoardTheme(.autumn))
        XCTAssertEqual(vm.boardTheme, .meadow)
    }

    func testBuildingAreasUnlocksTheLaterThemes() {
        let vm = MergeBoardViewModel()
        vm.completedAreaIDs = Array(sanctuaryAreas.prefix(boardThemeAutumnAreas).map(\.id))
        XCTAssertTrue(vm.isBoardThemeUnlocked(.autumn))
        XCTAssertFalse(vm.isBoardThemeUnlocked(.blossom))
        XCTAssertTrue(vm.selectBoardTheme(.autumn))
    }

    func testThePromptIsRecordedOnceAndNeverUnset() {
        let vm = MergeBoardViewModel()
        vm.markBoardThemePrompted()
        XCTAssertTrue(vm.boardThemePrompted)
        vm.markBoardThemePrompted()
        XCTAssertTrue(vm.boardThemePrompted)
    }

    func testEveryThemeIsVisiblyDistinctFromMeadow() {
        // A theme that reads the same as the default is decoration, not choice.
        func rgb(_ c: Color) -> [CGFloat] {
            let ui = UIColor(c); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a); return [r, g, b]
        }
        let base = rgb(BoardTheme.meadow.backdropTop) + rgb(BoardTheme.meadow.backdropBottom)
        for theme in BoardTheme.allCases where theme != .meadow {
            let other = rgb(theme.backdropTop) + rgb(theme.backdropBottom)
            let distance = zip(base, other).map { abs($0 - $1) }.reduce(0, +)
            XCTAssertGreaterThan(distance, 0.25, "\(theme.displayName) is too close to Meadow")
        }
    }
}
