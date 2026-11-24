//
//  TutorialMoments.swift
//  PawSanctuary
//
//  Context tutorial, task 4.3 stage 1 (specs/Spec_ContextTutorial.md §4, §6, §7).
//  The list of one-time tips, and the pure rule that decides which one is next.
//  Nothing here draws a bubble and no view calls it yet: stage 2 adds the coach
//  mark and wires the first moments.
//

import Foundation

// MARK: - The moments

/// One one-time tip. The raw value is stored in saves (`GameState.seenTutorialMoments`),
/// so it is never renamed or renumbered: the ids follow the spec's table (M1…M22;
/// M21 is deliberately absent, it is the existing skip alert and has no coach mark,
/// and M23 is not built). Declaration order is the priority order of the rule below.
enum TutorialMoment: String, CaseIterable, Codable {
    // Group A: session one, the core loop
    case firstSpawn        = "m01_first_spawn"
    case firstMerge        = "m02_first_merge"
    case orderOnHold       = "m03_order_on_hold"
    case firstDeliver      = "m04_first_deliver"
    case afterDeliver      = "m05_after_deliver"
    case firstQuestClaim   = "m06_first_quest_claim"
    case splitWarning      = "m07_split_warning"
    // Group B: the first friction moments
    case boardFull         = "m08_board_full"
    case firstItemStored   = "m09_first_item_stored"
    case spawnerResting    = "m10_spawner_resting"
    case outOfKibble       = "m11_out_of_kibble"
    case noMergesLeft      = "m12_no_merges_left"
    // Group C: discovering features
    case chainViewer       = "m13_chain_viewer"
    case firstDailyHandIn  = "m14_first_daily_hand_in"
    case toolbox           = "m15_toolbox"
    case mapAreaAffordable = "m16_map_area_affordable"
    case firstCardPack     = "m17_first_card_pack"
    case freeChest         = "m18_free_chest"
    case firstBubble       = "m19_first_bubble"
    case sellVsOrder       = "m20_sell_vs_order"
    // Group D: after the D7 gate opens
    case firstWildcard     = "m22_first_wildcard"

    enum Group { case core, friction, features, afterGate }

    var group: Group {
        switch self {
        case .firstSpawn, .firstMerge, .orderOnHold, .firstDeliver,
             .afterDeliver, .firstQuestClaim, .splitWarning:
            return .core
        case .boardFull, .firstItemStored, .spawnerResting, .outOfKibble, .noMergesLeft:
            return .friction
        case .chainViewer, .firstDailyHandIn, .toolbox, .mapAreaAffordable,
             .firstCardPack, .freeChest, .firstBubble, .sellVsOrder:
            return .features
        case .firstWildcard:
            return .afterGate
        }
    }

    /// What "Skip tips" marks seen (owner Q1): the whole of group A.
    static var coreGroup: [TutorialMoment] { allCases.filter { $0.group == .core } }

    /// The things a bubble points at (the "Points at" column of the spec's tables).
    var target: TutorialTarget {
        switch self {
        case .firstSpawn, .spawnerResting, .noMergesLeft: return .spawnerCell
        case .firstMerge:         return .mergePair
        case .orderOnHold:        return .orderHeldSlot
        case .firstDeliver:       return .deliverPill
        case .afterDeliver:       return .deliveredOrderCard
        case .firstQuestClaim:    return .questClaim
        case .splitWarning:       return .orderSlotThatDropped
        case .boardFull, .firstItemStored: return .basketButton
        case .outOfKibble:        return .refillOrderFooter
        case .chainViewer:        return .chainInfoButton
        case .firstDailyHandIn:   return .dailyTaskClaim
        case .toolbox:            return .toolboxCell
        case .mapAreaAffordable, .firstCardPack: return .mapButton
        case .freeChest:          return .freeChestTile
        case .firstBubble:        return .bubbledCell
        case .sellVsOrder:        return .none
        case .firstWildcard:      return .wildcardCell
        }
    }

    /// The bubble's words (the spec's "Message" column), plain and short. Nil
    /// until the stage that builds that tip adds its text. No text names or
    /// points toward a purchase (D7, D9).
    var coachMarkText: String? {
        switch self {
        case .firstSpawn:
            return "Tap the spawner to rescue an animal. Each rescue costs kibble; kibble refills by itself."
        case .firstMerge:
            return "Drag an animal onto a matching one to merge it into the next level."
        case .firstQuestClaim:
            return "Quest complete! Tap Claim for your reward. Quests count what you do; orders and daily tasks want animals you hold."
        case .orderOnHold:
            return "This family wants that animal. A soft highlight means you already have it on the board. Keep it there!"
        case .firstDeliver:
            return "Everything is on the board. Tap Deliver to send the animals home and collect your reward."
        case .afterDeliver:
            return "Delivered animals leave the board. A new family arrives in a moment."
        case .splitWarning:
            return "That animal was on hold for an order. Merging it moved it up a level, so the order needs another one."
        case .boardFull:
            return "No room left. Merge a pair, drag an animal to the basket to store it, or sell one from the info bar."
        case .firstItemStored:
            return "Stored animals are safe in the basket, but orders and daily tasks only count animals on the board."
        case .spawnerResting:
            // The spec says "in a few seconds"; the wait is 30, so the words stay vague.
            // Never "skip": before the D7 gate nothing here is for sale (spec §5).
            return "This spawner is resting. It will be ready again soon."
        case .outOfKibble:
            // Shown as a line inside the kibble sheet, never as an overlay bubble.
            return "Kibble refills on its own. Meanwhile, merge what you have or deliver an order."
        case .noMergesLeft:
            return "No matching pairs right now. Tap the spawner for more animals."
        case .chainViewer:
            return "Tap i to see every level this animal can grow into."
        case .firstDailyHandIn:
            return "You have everything for this task. Claim takes those animals off the board."
        case .toolbox:
            return "Tap the toolbox to collect building materials."
        case .mapAreaAffordable:
            return "You can build something on the Sanctuary Map!"
        case .firstCardPack:
            return "You earned a card pack. Open it in the Card Album on the map."
        case .freeChest:
            return "A free chest is ready. Tap to open it."
        case .firstBubble:
            // The free route only: never the pop sheet's paid buttons (spec §5, M19).
            return "A bubbled animal is still waiting to be rescued. Drag a matching animal onto it to free it, or leave it and it turns into coins."
        case .sellVsOrder:
            // Not a bubble: it stays the toast it always was, with its own wording.
            return nil
        case .firstWildcard:
            // Stage 6.
            return nil
        }
    }

    /// Seconds a short tip stays up before it closes itself and counts as seen
    /// (the spec's "Done when: shown 4 s / seen for 6 s"). Nil for a tip that
    /// waits for its action or the x.
    var autoCloseSeconds: Double? {
        switch self {
        case .orderOnHold, .splitWarning: return 6
        case .afterDeliver:               return 4
        case .firstItemStored, .spawnerResting: return 5
        default:                          return nil
        }
    }

    /// The seen moments this build knows, from the raw strings in a save. An id a
    /// later build wrote is skipped here; it stays in the stored array untouched.
    static func seenSet(from ids: [String]) -> Set<TutorialMoment> {
        Set(ids.compactMap(TutorialMoment.init(rawValue:)))
    }
}

/// Where a bubble can point. The `paid` cases are named so that no moment can
/// aim at one by accident: `TutorialTriggerTests` fails if a moment before the
/// D7 gate has a target with `isPaidSurface`. No moment uses them.
enum TutorialTarget: CaseIterable {
    case spawnerCell, mergePair, orderHeldSlot, deliverPill, deliveredOrderCard
    case questClaim, orderSlotThatDropped, basketButton, refillOrderFooter
    case chainInfoButton, dailyTaskClaim, toolboxCell, mapButton, freeChestTile
    case bubbledCell, wildcardCell, none
    // Paid surfaces (D7): never a target before the gate, and none is used.
    case shopButton, refillPaidRows, restingChestSkip, bubblePopSheetButtons, offerOrPass

    var isPaidSurface: Bool {
        switch self {
        case .shopButton, .refillPaidRows, .restingChestSkip, .bubblePopSheetButtons, .offerOrPass:
            return true
        default:
            return false
        }
    }
}

// MARK: - The rule

/// What the rule needs to know, as plain values. The view model builds one from
/// live state in later stages; here it is only data, so the rule is testable
/// without a board. A flag named "just…" is an event: true only on the pass
/// that handles it.
struct TutorialSnapshot: Equatable {
    // Gates
    var isMonetizationUnlocked = false
    /// A sheet, popup, banner, takeover or the Parallel Board is up (§4.1 "Never over anything else").
    var isCoveredByOtherUI = false
    var secondsSinceLastMoment: Double = .infinity

    // Group A
    var hasFamilySpawnerOnBoard = false        // M1
    var hasMergeablePair = false               // M2
    var hasPartHeldOrder = false               // M3: held slot(s) but not ready
    var hasReadyOrder = false                  // M4: the Deliver pill is showing
    var justDelivered = false                  // M5
    var hasClaimableQuest = false              // M6
    var justUnheldAnOrderSlot = false          // M7

    // Group B
    var boardFullToastJustShown = false        // M8
    var itemJustStored = false                 // M9
    var restingSpawnerJustTapped = false       // M10
    var outOfKibbleSheetJustOpened = false     // M11
    var hasNoMergeablePairWithSpawnerReady = false   // M12

    // Group C
    var chainItemIsSelected = false            // M13
    var hasMergedOnce = false                  // M13 waits for this
    var hasClaimableDailyTask = false          // M14
    var hasToolboxOnBoard = false              // M15
    var hasAffordableArea = false              // M16
    var hasPendingCardPack = false             // M17
    var freeChestIsReady = false               // M18
    var hasBubbledItem = false                 // M19
    var sellVsOrderNudgeApplies = false        // M20

    // Group D
    var hasWildcardOnBoard = false             // M22
}

/// The one moment to show now, or nil. Pure: it reads the snapshot and the seen
/// set and changes neither, so a trigger that ended before its bubble showed is
/// simply not returned and is not marked (it can fire next time). At most one
/// moment at a time, in declaration order, and never while something else covers
/// the board. Moments after the opening lessons also wait out the gap after the
/// last bubble; the opening lessons (group A) do not, because spawn, merge and
/// claim are one sequence the player is already in the middle of.
func nextTutorialMoment(snapshot s: TutorialSnapshot, seen: Set<TutorialMoment>) -> TutorialMoment? {
    guard !s.isCoveredByOtherUI else { return nil }
    let gapElapsed = s.secondsSinceLastMoment >= tutorialMomentGapSeconds
    return TutorialMoment.allCases.first {
        !seen.contains($0) && ($0.group == .core || gapElapsed) && isTriggered($0, in: s)
    }
}

private func isTriggered(_ moment: TutorialMoment, in s: TutorialSnapshot) -> Bool {
    // D7: group D is only ever checked with the gate open, at fire time.
    if moment.group == .afterGate && !s.isMonetizationUnlocked { return false }
    switch moment {
    case .firstSpawn:         return s.hasFamilySpawnerOnBoard
    case .firstMerge:         return s.hasMergeablePair
    case .orderOnHold:        return s.hasPartHeldOrder
    case .firstDeliver:       return s.hasReadyOrder
    case .afterDeliver:       return s.justDelivered
    case .firstQuestClaim:    return s.hasClaimableQuest
    case .splitWarning:       return s.justUnheldAnOrderSlot
    case .boardFull:          return s.boardFullToastJustShown
    case .firstItemStored:    return s.itemJustStored
    // Only while the gate is closed: once it is open the skip alert explains itself (M21).
    case .spawnerResting:     return s.restingSpawnerJustTapped && !s.isMonetizationUnlocked
    case .outOfKibble:        return s.outOfKibbleSheetJustOpened
    case .noMergesLeft:       return s.hasNoMergeablePairWithSpawnerReady
    case .chainViewer:        return s.chainItemIsSelected && s.hasMergedOnce
    case .firstDailyHandIn:   return s.hasClaimableDailyTask
    case .toolbox:            return s.hasToolboxOnBoard
    case .mapAreaAffordable:  return s.hasAffordableArea
    case .firstCardPack:      return s.hasPendingCardPack
    case .freeChest:          return s.freeChestIsReady
    case .firstBubble:        return s.hasBubbledItem
    case .sellVsOrder:        return s.sellVsOrderNudgeApplies
    case .firstWildcard:      return s.hasWildcardOnBoard
    }
}
