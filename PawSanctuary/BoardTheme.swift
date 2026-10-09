//
//  BoardTheme.swift
//  PawSanctuary
//
//  The player's free, always-changeable board look (specs/Spec_BoardThemes.md).
//  A theme colours the backdrop, the board panel and the empty cells -- never
//  item art, tile tints or any colour that carries state.
//

import SwiftUI

/// Persisted by raw value (`String`), per the project's enum convention.
enum BoardTheme: String, CaseIterable, Codable, Identifiable {
    case meadow, seaside, dusk, autumn, blossom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meadow:  return "Meadow"
        case .seaside: return "Seaside"
        case .dusk:    return "Dusk"
        case .autumn:  return "Autumn"
        case .blossom: return "Blossom"
        }
    }

    /// Built Sanctuary areas needed to unlock it; 0 for the starter themes.
    var areasRequired: Int {
        switch self {
        case .meadow, .seaside, .dusk: return 0
        case .autumn:                  return boardThemeAutumnAreas
        case .blossom:                 return boardThemeBlossomAreas
        }
    }

    func isUnlocked(builtAreas: Int) -> Bool { builtAreas >= areasRequired }

    /// The three offered in the one-time first-choice sheet.
    static let starters: [BoardTheme] = [.meadow, .seaside, .dusk]

    // MARK: Colours

    var backdropTop: Color {
        switch self {
        case .meadow:  return Color(red: 0.85, green: 0.95, blue: 0.85)
        case .seaside: return Color(red: 0.80, green: 0.91, blue: 0.98)
        case .dusk:    return Color(red: 0.66, green: 0.60, blue: 0.84)
        case .autumn:  return Color(red: 0.99, green: 0.89, blue: 0.70)
        case .blossom: return Color(red: 0.99, green: 0.86, blue: 0.91)
        }
    }

    var backdropBottom: Color {
        switch self {
        case .meadow:  return Color(red: 0.95, green: 0.88, blue: 0.75)
        case .seaside: return Color(red: 0.97, green: 0.93, blue: 0.80)
        case .dusk:    return Color(red: 0.96, green: 0.80, blue: 0.78)
        case .autumn:  return Color(red: 0.90, green: 0.68, blue: 0.48)
        case .blossom: return Color(red: 0.97, green: 0.95, blue: 0.84)
        }
    }

    /// The panel behind the grid.
    var panelFill: Color {
        switch self {
        case .meadow:  return Color.white.opacity(0.5)
        case .seaside: return Color(red: 0.90, green: 0.97, blue: 1.00).opacity(0.62)
        case .dusk:    return Color(red: 0.95, green: 0.90, blue: 0.98).opacity(0.60)
        case .autumn:  return Color(red: 1.00, green: 0.95, blue: 0.84).opacity(0.62)
        case .blossom: return Color(red: 1.00, green: 0.93, blue: 0.95).opacity(0.62)
        }
    }

    /// An empty, unlocked cell.
    var emptyCellFill: Color {
        switch self {
        case .meadow:  return Color.white.opacity(0.7)
        case .seaside: return Color(red: 0.93, green: 0.98, blue: 1.00).opacity(0.78)
        case .dusk:    return Color(red: 0.98, green: 0.94, blue: 1.00).opacity(0.78)
        case .autumn:  return Color(red: 1.00, green: 0.96, blue: 0.87).opacity(0.78)
        case .blossom: return Color(red: 1.00, green: 0.95, blue: 0.97).opacity(0.78)
        }
    }

    /// Backdrop as one shape style, for the screen and the swatches.
    var backdrop: LinearGradient {
        LinearGradient(colors: [backdropTop, backdropBottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: Environment

private struct BoardThemeKey: EnvironmentKey {
    static let defaultValue: BoardTheme = .meadow
}

extension EnvironmentValues {
    /// The active board theme, so a cell reads it without every call site
    /// threading a parameter through.
    var boardTheme: BoardTheme {
        get { self[BoardThemeKey.self] }
        set { self[BoardThemeKey.self] = newValue }
    }
}

// MARK: Picker

/// A row of theme swatches. Locked themes show a lock and what unlocks them.
struct BoardThemePicker: View {
    let selected: BoardTheme
    let builtAreas: Int
    var themes: [BoardTheme] = BoardTheme.allCases
    let onSelect: (BoardTheme) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(themes) { theme in
                let unlocked = theme.isUnlocked(builtAreas: builtAreas)
                Button(action: { if unlocked { onSelect(theme) } }) {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.backdrop)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(theme.panelFill)
                                        .padding(8))
                            if !unlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black.opacity(0.55))
                            }
                        }
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(theme == selected ? Color.green : Color.black.opacity(0.12),
                                              lineWidth: theme == selected ? 3 : 1))
                        .opacity(unlocked ? 1 : 0.6)

                        Text(theme.displayName)
                            .font(.system(size: 10, weight: theme == selected ? .bold : .regular))
                            .foregroundColor(.primary)
                        if !unlocked {
                            Text("\(theme.areasRequired) areas")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
                .accessibilityLabel(Text(unlocked
                    ? "\(theme.displayName)\(theme == selected ? ", selected" : "")"
                    : "\(theme.displayName), locked: build \(theme.areasRequired) areas"))
            }
        }
    }
}

/// The one-time "Make it yours" sheet offered once the tutorial is done.
struct BoardThemeChoiceSheet: View {
    var viewModel: MergeBoardViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Make it yours")
                .font(.title2.bold())
            Text("Pick a look for your sanctuary board. You can change it any time from your profile, and more unlock as you build.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            BoardThemePicker(selected: viewModel.boardTheme,
                             builtAreas: viewModel.completedAreaIDs.count,
                             themes: BoardTheme.starters) { viewModel.selectBoardTheme($0) }
            Button(action: onDone) {
                Text(viewModel.boardTheme == .meadow ? "Keep Meadow" : "Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.2, green: 0.5, blue: 0.3)))
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .presentationDetents([.height(340)])
    }
}
