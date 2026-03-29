import SwiftUI

struct UmpireSelectableCard: View {
    let umpire: Umpire
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {

                CheckCircle(
                    isChecked: isSelected,
                    disabled: umpire.status == .unavailable
                )

                VStack(alignment: .leading, spacing: 6) {

                    HStack {
                        Text(umpire.name)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        StatusPill(
                            text: umpire.status.rawValue,
                            color: pillBackground,
                            textColor: pillText
                        )
                    }

                    HStack(spacing: 10) {
                        IconTextRow(
                            systemName: "star.fill",
                            text: String(format: "%.1f/5.0", umpire.rating)
                        )
                        Text("•").foregroundColor(.textSecondary)
                        IconTextRow(
                            systemName: "sportscourt",
                            text: "\(umpire.matchesCount) matches"
                        )
                        Text("•").foregroundColor(.textSecondary)
                        IconTextRow(
                            systemName: "rosette",
                            text: umpire.specialization
                        )
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                }
            }
            .padding(12)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.primaryBlue : Color.border,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
            .opacity(umpire.status == .unavailable ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var pillBackground: Color {
        switch umpire.status {
        case .available:
            return Color.successGreen.opacity(0.12)
        case .assigned:
            return Color.blue600.opacity(0.12)
        case .unavailable:
            return Color.textSecondary.opacity(0.1)
        }
    }

    private var pillText: Color {
        umpire.status == .unavailable ? .textSecondary : .textPrimary
    }
}
