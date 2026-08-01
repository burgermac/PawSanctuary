//
//  EventSystem.swift
//  PawSanctuary
//
//  Time-limited event models and static event registry.
//

import SwiftUI
import Foundation

// ============================================================
// MARK: - PERSISTED STATE
// ============================================================

struct EventProgress: Codable, Equatable {
    var eventId: String = ""
    var coinsEarned: Int = 0
    var claimedMilestones: [Int] = []

    func hasClaimed(_ tier: Int) -> Bool { claimedMilestones.contains(tier) }

    func canClaim(_ milestone: EventMilestone) -> Bool {
        coinsEarned >= milestone.coinsRequired && !hasClaimed(milestone.id)
    }
}

// ============================================================
// MARK: - STATIC DEFINITIONS
// ============================================================

struct EventMilestone: Identifiable {
    let id: Int             // tier number (1, 2, 3)
    let coinsRequired: Int
    let kibbleReward: Int
    let dogTagsReward: Int
}

struct EventDefinition: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let startDate: Date
    let endDate: Date
    let milestones: [EventMilestone]
    let icon: String
    let accentColor: Color
    let gradientColors: [Color]
    /// Minimum player level to see/participate in this event. Phase 6a — EventScheduler.
    let minLevel: Int
    /// Which event wins a contested UI slot when several are active simultaneously.
    /// Higher wins; ties break by earliest startDate. Phase 6a — EventScheduler.
    let priority: Int

    init(id: String, name: String, tagline: String, startDate: Date, endDate: Date,
         milestones: [EventMilestone], icon: String, accentColor: Color, gradientColors: [Color],
         minLevel: Int = 0, priority: Int = 0) {
        self.id = id; self.name = name; self.tagline = tagline
        self.startDate = startDate; self.endDate = endDate
        self.milestones = milestones
        self.icon = icon; self.accentColor = accentColor; self.gradientColors = gradientColors
        self.minLevel = minLevel; self.priority = priority
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    var timeRemaining: TimeInterval { max(0, endDate.timeIntervalSinceNow) }

    var isUrgent: Bool { timeRemaining < 3600 }

    var timerLabel: String {
        let secs = Int(timeRemaining)
        let days  = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins  = (secs % 3600) / 60
        if days  > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h \(mins)m left" }
        return "\(mins)m left"
    }
}

// ============================================================
// MARK: - REGISTRY
// ============================================================

enum EventRegistry {

    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? .distantPast
    }

    static let allEvents: [EventDefinition] = [
        EventDefinition(
            id: "rescue_rush_jun2026",
            name: "Rescue Rush",
            tagline: "Merge animals and complete orders to earn event coins!",
            startDate: date("2026-06-01"),
            endDate:   date("2026-06-15"),
            milestones: [
                EventMilestone(id: 1, coinsRequired: 200, kibbleReward: 50,  dogTagsReward: 0),
                EventMilestone(id: 2, coinsRequired: 450, kibbleReward: 75,  dogTagsReward: 3),
                EventMilestone(id: 3, coinsRequired: 700, kibbleReward: 150, dogTagsReward: 8),
            ],
            icon: "hare.fill",
            accentColor: Color(red: 0.85, green: 0.45, blue: 0.10),
            gradientColors: [
                Color(red: 1.00, green: 0.93, blue: 0.80),
                Color(red: 0.99, green: 0.87, blue: 0.68),
            ]
        ),
    ]

    static var currentEvent: EventDefinition? {
        allEvents.first { $0.isActive }
    }
}
