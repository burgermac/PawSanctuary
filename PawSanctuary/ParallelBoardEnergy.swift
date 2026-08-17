//
//  ParallelBoardEnergy.swift
//  PawSanctuary
//
//  A lightweight regen pool for the Parallel Board event type (Phase 6b).
//  Not a second KibbleEngine: no player-level-tied bonus caps, no ad-refill
//  wall, no offline-progress catch-up — scoped to a single 3-4 day event,
//  not the whole game's economy. See specs/Spec_Phase6b_ParallelBoard.md §3.2.
//

import Foundation
import Observation

@Observable
@MainActor
final class ParallelBoardEnergy {
    var balance: Int = parallelBoardEnergyCap
    var secondsUntilNext: Int = parallelBoardEnergyRegenSecs

    func tick() {
        guard balance < parallelBoardEnergyCap else { return }
        secondsUntilNext -= 1
        if secondsUntilNext <= 0 {
            balance = min(parallelBoardEnergyCap, balance + 1)
            secondsUntilNext = parallelBoardEnergyRegenSecs
        }
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}
