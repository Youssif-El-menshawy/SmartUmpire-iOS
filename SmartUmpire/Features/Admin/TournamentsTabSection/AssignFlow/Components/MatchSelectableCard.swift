import SwiftUI

struct MatchSelectableCard: View {
    let match: Match
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {

                VStack(alignment: .leading, spacing: 10) {

                    HStack {
                        Text("\(match.player1) vs \(match.player2)")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        StatusPill(
                            text: match.round,
                            color: Color.purple.opacity(0.12),
                            textColor: .purple
                        )
                    }

                    HStack(spacing: 12) {
                        IconTextRow(systemName: "clock", text: match.time)
                        Text("•").foregroundColor(.textSecondary)
                        IconTextRow(systemName: "sportscourt", text: match.court)
                    }

                    Divider()

                    if let umpire = match.assignedUmpire {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundColor(.successGreen)
                            Text("Assigned: \(umpire)")
                                .font(.system(size: 14))
                        }
                    } else {
                        Text("No umpire assigned")
                            .foregroundColor(.errorRed)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
