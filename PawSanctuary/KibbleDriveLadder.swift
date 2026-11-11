//
//  KibbleDriveLadder.swift
//  PawSanctuary
//
//  Kibble Drive (specs/Spec_KibbleDrive_Draft.md) §6 step 4 — the rung table.
//
//  Stored as `TrackMilestone`s per §2 so the rungs share a shape with the other
//  ladders, but with **`freeRewards` empty on every rung**: there is no free
//  lane. `threshold` is in Drive Points, `paidRewards` is what the rung pays
//  once the Drive is purchased and the player has earned the points.
//
//  The numbers are §3.3's, treated as final pending playtest. 540 kibble over
//  a 300-point top rung is 1.80 kibble per Drive Point, which is what §3.5's
//  safety margin is computed against — `KibbleDriveLadderTests` re-derives
//  that margin from `EconomySimulation` so a retune on either side fails
//  loudly rather than quietly opening the faucet.
//

import Foundation

enum KibbleDriveLadder {
    private static func rung(_ index: Int, _ threshold: Int, kibble: Int,
                             pack: CardPackType? = nil) -> TrackMilestone {
        var rewards = [OrderReward(kind: .kibble, amount: kibble)]
        if let pack {
            rewards.append(OrderReward(kind: .cardPack, amount: 1, payloadID: pack.rawValue))
        }
        return TrackMilestone(index: index, threshold: threshold,
                              freeRewards: [], paidRewards: rewards)
    }

    /// §3.3. Arithmetic-ramp thresholds; card packs on rungs 10 and 15.
    static let rungs: [TrackMilestone] = [
        rung(0, 10, kibble: 30),
        rung(1, 22, kibble: 30),
        rung(2, 35, kibble: 30),
        rung(3, 50, kibble: 30),
        rung(4, 66, kibble: 30),
        rung(5, 83, kibble: 30),
        rung(6, 102, kibble: 40),
        rung(7, 122, kibble: 40),
        rung(8, 144, kibble: 40),
        rung(9, 167, kibble: 40, pack: .star4),
        rung(10, 191, kibble: 40),
        rung(11, 216, kibble: 40),
        rung(12, 243, kibble: 40),
        rung(13, 271, kibble: 40),
        rung(14, 300, kibble: 40, pack: .star5),
    ]

    static var totalKibble: Int {
        rungs.flatMap(\.paidRewards).filter { $0.kind == .kibble }.reduce(0) { $0 + $1.amount }
    }

    static var topThreshold: Int { rungs.last?.threshold ?? 0 }
}
