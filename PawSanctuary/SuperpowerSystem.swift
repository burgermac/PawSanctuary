//
//  SuperpowerSystem.swift  —  Phase 6: Per-family superpower abilities
//  PawSanctuary
//
//  Each animal family has one Superpower — a passive or active ability that
//  unlocks the first time that family reaches Era 3 (Stage 7 = tier index 6).
//
//  Passives trigger automatically from hooks in MergeBoardViewModel.
//  Actives are triggered by a button strip in the board UI.
//

import SwiftUI

// ============================================================
// MARK: - SUPERPOWER KIND
// ============================================================

enum SuperpowerKind {
    case passive
    case active(cooldownSeconds: Double)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var cooldownSeconds: Double? {
        if case .active(let s) = self { return s }
        return nil
    }

    var cooldownLabel: String? {
        guard let s = cooldownSeconds else { return nil }
        let i = Int(s)
        if i < 60 { return "\(i)s" }
        return "\(i / 60)m"
    }
}

// ============================================================
// MARK: - SUPERPOWER
// ============================================================

struct Superpower {
    let species: AnimalSpecies
    let name: String
    let description: String    // one-liner for the UI strip
    let kind: SuperpowerKind
    let sfSymbol: String       // icon for the button

    /// 0-indexed tier at which the superpower unlocks (Stage 7 = Era 3).
    static let unlockTier = 6

    var isActive: Bool { kind.isActive }
    var cooldownSeconds: Double? { kind.cooldownSeconds }
    var cooldownLabel: String? { kind.cooldownLabel }

    /// The real badge icon (Assets.xcassets/Superpowers), or `nil` if not
    /// delivered — callers fall back to `sfSymbol` in that case. Active and
    /// Passive powers both get a badge; only Actives additionally use this as
    /// their board-piece art, via `MergeChain.artImage(forTier:)`.
    var badgeImage: Image? { species.superpowerBadgeImage(itemName: name) }
}

// ============================================================
// MARK: - REGISTRY  (extension on AnimalSpecies)
// ============================================================

extension AnimalSpecies {
    var superpower: Superpower {
        switch self {
        case .dog:
            return Superpower(species: self,
                name: "Fetch!",
                description: "Every 5th merge anywhere spawns a free Stage-1 Canine",
                kind: .passive, sfSymbol: "pawprint.fill")
        case .cat:
            return Superpower(species: self,
                name: "Nine Lives",
                description: "Undo your last merge",
                kind: .active(cooldownSeconds: 90), sfSymbol: "arrow.uturn.backward.circle.fill")
        case .rabbit:
            return Superpower(species: self,
                name: "Multiply",
                description: "Every 4th Lagomorph merge spawns two free Stage-1 Lagomorphs",
                kind: .passive, sfSymbol: "plus.circle.fill")
        case .bird:
            return Superpower(species: self,
                name: "Scout",
                description: "Spawner tiles preview whether the next rescue is an animal or sub-object",
                kind: .passive, sfSymbol: "eye.fill")
        case .hamster:
            return Superpower(species: self,
                name: "Hoard",
                description: "Rodent Spawner drops Stage-2 sub-objects instead of Stage-1",
                kind: .passive, sfSymbol: "cube.fill")
        case .turtle:
            return Superpower(species: self,
                name: "Bask",
                description: "Reptile family spawner costs half kibble to activate",
                kind: .passive, sfSymbol: "sun.max.fill")
        case .fox:
            return Superpower(species: self,
                name: "Antler Drop",
                description: "Cervid merges have a 25% chance to drop a bonus Stage-2 sub-object",
                kind: .passive, sfSymbol: "sparkles")
        case .owl:
            return Superpower(species: self,
                name: "Hibernate Bonus",
                description: "After 5 idle minutes, the next rescue anywhere spawns at Stage 3",
                kind: .passive, sfSymbol: "moon.zzz.fill")
        case .fish:
            return Superpower(species: self,
                name: "Current",
                description: "After any merge, adjacent sub-objects auto-slide toward the empty cell",
                kind: .passive, sfSymbol: "water.waves")
        case .lizard:
            return Superpower(species: self,
                name: "Leap",
                description: "Teleport any Amphibian to any empty board cell",
                kind: .active(cooldownSeconds: 120), sfSymbol: "arrow.up.right.circle.fill")
        case .ferret:
            return Superpower(species: self,
                name: "Pouch",
                description: "Store up to 2 animals off the board for 30 s, then they return",
                kind: .active(cooldownSeconds: 180), sfSymbol: "bag.fill")
        case .parrot:
            return Superpower(species: self,
                name: "Mimic",
                description: "Spawn a free Stage-1 animal of the last merged family",
                kind: .active(cooldownSeconds: 90), sfSymbol: "figure.stand.line.dotted.figure.stand")
        case .pony:
            return Superpower(species: self,
                name: "Sprint",
                description: "Doubles Kibble regen rate for 60 seconds",
                kind: .active(cooldownSeconds: 60), sfSymbol: "hare.fill")
        case .hedgehog:
            return Superpower(species: self,
                name: "Memory",
                description: "Pachyderm quest and challenge progress counts double",
                kind: .passive, sfSymbol: "memorychip.fill")
        case .guineaPig:
            return Superpower(species: self,
                name: "Stampede",
                description: "Instantly merge all same-family same-stage pairs on the board",
                kind: .active(cooldownSeconds: 180), sfSymbol: "bolt.horizontal.fill")
        }
    }
}
