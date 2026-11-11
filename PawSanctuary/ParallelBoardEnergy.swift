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

    /// True once the pool is topped up and `tick()` has nothing left to do —
    /// the gate for hiding the countdown, since `secondsUntilNext` stops
    /// moving here.
    var isFull: Bool { balance >= parallelBoardEnergyCap }

    /// Countdown to the next regen tick, `m:ss`. Same shape and the same home
    /// on the pool type as `KibbleEngine.kibbleStatusText`, which the main
    /// board's HUD reads for the identical job. Meaningless while `isFull`
    /// (it sits frozen at a whole regen interval), so don't show it then.
    var statusText: String {
        let m = secondsUntilNext / 60
        let s = secondsUntilNext % 60
        return String(format: "%d:%02d", m, s)
    }

    func tick() {
        guard balance < parallelBoardEnergyCap else { return }
        secondsUntilNext -= 1
        if secondsUntilNext <= 0 {
            balance = min(parallelBoardEnergyCap, balance + 1)
            secondsUntilNext = parallelBoardEnergyRegenSecs
        }
    }

    /// True while the balance sits above the regen cap — bonus energy from
    /// main-board orders that regen could not have produced.
    var isBanked: Bool { balance > parallelBoardEnergyCap }

    /// Adds order-bonus energy, banking above the regen cap up to
    /// `parallelBoardEnergyBankCap`. Returns how much was actually added (0 once
    /// the bank is full). Never lowers the balance, even if a restored save
    /// somehow holds more than the bank cap.
    @discardableResult
    func addBonus(_ amount: Int) -> Int {
        guard amount > 0, balance < parallelBoardEnergyBankCap else { return 0 }
        let added = min(amount, parallelBoardEnergyBankCap - balance)
        balance += added
        return added
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}
