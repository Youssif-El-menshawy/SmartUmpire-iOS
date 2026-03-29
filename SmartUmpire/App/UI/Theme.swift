import SwiftUI

// MARK: (Dark-mode ready)
extension SwiftUI.Color {
    // Brand (unchanged)
    static let primaryBlue   = Color(red: 37/255, green: 99/255,  blue: 235/255)   // #2563EB
    static let blue600       = Color(red: 37/255, green: 99/255,  blue: 235/255)   // #2563EB
    static let blue700       = Color(red: 29/255, green: 78/255,  blue: 216/255)   // #1D4ED8

    // Surfaces (dynamic)
    static let appBackground   = Color(.systemGroupedBackground)     // replaces .background
    static let cardBackground  = Color(.secondarySystemBackground)   // replaces Color.white

    // Text (dynamic)
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary

    // Borders / separators (dynamic)
    static var border: Color { Color(.separator).opacity(0.6) }

    // Status
    static let successGreen  = Color(red: 16/255, green: 185/255, blue: 129/255)   // #10B981
    static let warningYellow = Color(red: 245/255, green: 158/255, blue: 11/255)   // #F59E0B
    static let errorRed      = Color(red: 239/255, green: 68/255,  blue: 68/255)   // #EF4444
    static let purple        = Color(red: 139/255, green: 92/255,  blue: 246/255)  // #8B5CF6
}

// MARK: (tuned for both schemes)
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: (scheme == .dark ? .black.opacity(0.35) : .black.opacity(0.06)),
                radius: (scheme == .dark ? 10 : 4),
                x: 0, y: (scheme == .dark ? 6 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

