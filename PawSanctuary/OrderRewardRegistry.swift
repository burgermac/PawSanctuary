//
//  OrderRewardRegistry.swift
//  PawSanctuary
//
//  Rider injection hook (Phase 1, Task 1.2) — lets active events attach extra
//  rewards to newly generated adoption orders without editing AdoptionBoard.
//

import Foundation

/// A system that can attach extra rewards to newly generated adoption orders.
/// Events register providers; AdoptionBoard queries them at generation time.
protocol OrderRewardProvider: AnyObject {
    func riders(playerLevel: Int) -> [OrderReward]
}

@MainActor
enum OrderRewardRegistry {
    private(set) static var providers: [OrderRewardProvider] = []

    static func register(_ provider: OrderRewardProvider) {
        guard !providers.contains(where: { $0 === provider }) else { return }
        providers.append(provider)
    }

    static func unregister(_ provider: OrderRewardProvider) {
        providers.removeAll { $0 === provider }
    }

    static func riders(playerLevel: Int) -> [OrderReward] {
        providers.flatMap { $0.riders(playerLevel: playerLevel) }
    }
}
