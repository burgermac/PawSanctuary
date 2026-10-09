//
//  MilestoneTakeoverView.swift
//  PawSanctuary
//
//  The full-screen celebration for crossing a Care Points tier
//  (specs/Spec_MilestoneTakeover.md): dimmed board, the three-tier ladder with
//  crossed tiers ticked, the new tier's crest and reward, Claim or Later.
//

import SwiftUI

struct MilestoneTakeoverView: View {
    let tier: CarePointTier
    let onClaim: () -> Void
    let onLater: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onLater)

            VStack(spacing: 18) {
                Text("NEW MILESTONE!")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: tier.color.opacity(0.8), radius: 8)

                ladder

                crest

                VStack(spacing: 4) {
                    Text("\(tier.displayName) Care Points")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(rewardLine)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Button(action: onClaim) {
                        Text("Claim")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(tier.color))
                    }
                    Button(action: onLater) {
                        Text("Later")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
    }

    /// Three nodes, joined; the shown tier glows, lower ones are ticked, higher
    /// ones are still ahead.
    private var ladder: some View {
        HStack(spacing: 0) {
            ForEach(Array(CarePointTier.allCases.enumerated()), id: \.element) { i, t in
                if i > 0 {
                    Rectangle()
                        .fill(t.rawValue <= tier.rawValue ? tier.color : Color.white.opacity(0.25))
                        .frame(height: 3)
                }
                node(for: t)
            }
        }
        .padding(.horizontal, 6)
    }

    private func node(for t: CarePointTier) -> some View {
        let reached = t.rawValue <= tier.rawValue
        return ZStack {
            Circle()
                .fill(reached ? t.color : Color.white.opacity(0.15))
                .frame(width: 38, height: 38)
            if t.rawValue < tier.rawValue {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
            } else {
                Image(systemName: t.sfSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(reached ? .white : .white.opacity(0.4))
            }
        }
        .overlay {
            if t == tier {
                Circle().stroke(Color.white, lineWidth: 2).frame(width: 46, height: 46)
            }
        }
        .accessibilityLabel(Text("\(t.displayName), \(reached ? "reached" : "ahead")"))
    }

    /// The tier's crest on a soft radiating glow — the hero of the screen.
    private var crest: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tier.color.opacity(0.75), tier.color.opacity(0)],
                                     center: .center, startRadius: 6, endRadius: 90))
                .frame(width: 180, height: 180)
            Image(systemName: tier.sfSymbol)
                .font(.system(size: 64))
                .foregroundColor(.white)
                .shadow(color: tier.color, radius: 10)
        }
    }

    private var rewardLine: String {
        var parts = ["\(tier.dogTagReward) Dog Tags", "\(tier.xpReward) XP"]
        if tier.cardPack != nil { parts.append("a card pack") }
        return parts.joined(separator: " · ")
    }
}
